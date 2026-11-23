#!/usr/bin/env bash
# =====================================================================
#  01-seguridad.sh  -  Firewall, SSH endurecido y Fail2ban.
#  Uso:  sudo ./scripts/01-seguridad.sh <usuario-admin>
# =====================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecuta con sudo"; exit 1; }
USUARIO="${1:?Falta el usuario administrador}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

# Seguro anti-bloqueo: no quitamos las contraseñas si no hay clave
if [[ ! -s "/home/$USUARIO/.ssh/authorized_keys" ]]; then
  echo "ERROR: /home/$USUARIO/.ssh/authorized_keys está vacío. Ejecuta antes 00-preparar-host.sh"
  exit 1
fi

echo ">> 1/3 Firewall UFW: denegar todo lo entrante salvo SSH, HTTP y HTTPS"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp comment 'SSH (limitado)'
ufw allow 80/tcp  comment 'HTTP -> redirige a HTTPS'
ufw allow 443/tcp comment 'HTTPS proxy inverso'
ufw --force enable
ufw status verbose

echo ">> 2/3 SSH: solo clave, sin root"
sed "s/__ADMIN_USER__/${USUARIO}/" "$RAIZ/config/ssh/01-hardening.conf" \
  > /etc/ssh/sshd_config.d/01-hardening.conf
chmod 644 /etc/ssh/sshd_config.d/01-hardening.conf
sshd -t                         # si la sintaxis falla, el script se detiene
systemctl restart ssh
echo "   Valores efectivos:"
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|allowusers)'

echo ">> 3/3 Fail2ban para SSH"
cp "$RAIZ/config/fail2ban/jail.local" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban
sleep 2
fail2ban-client status sshd

echo
echo "Hecho. NO cierres esta sesión hasta comprobar en otra terminal que"
echo "sigues entrando por SSH con tu clave."
