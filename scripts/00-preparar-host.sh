#!/usr/bin/env bash
# =====================================================================
#  00-preparar-host.sh  -  Ejecutar UNA vez en la VM recién instalada.
#  - Actualiza el sistema y activa actualizaciones automáticas
#  - Instala Docker Engine + Compose (repositorio oficial de Docker)
#  - Crea el usuario administrador no root con acceso SSH por clave
#
#  Uso:  sudo ./scripts/00-preparar-host.sh <usuario> "<clave pública SSH>"
#  Ej.:  sudo ./scripts/00-preparar-host.sh adminpyme "ssh-ed25519 AAAA... alumno@pc"
# =====================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecuta con sudo"; exit 1; }
USUARIO="${1:?Falta el nombre de usuario}"
CLAVE_PUB="${2:?Falta la clave pública SSH entre comillas}"

echo ">> 1/4 Actualizando el sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y full-upgrade
apt-get -y install ca-certificates curl gnupg ufw fail2ban python3-systemd \
                   unattended-upgrades openssl git

echo ">> 2/4 Actualizaciones de seguridad automáticas"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

echo ">> 3/4 Instalando Docker"
. /etc/os-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

echo ">> 4/4 Usuario administrador '${USUARIO}'"
if ! id "$USUARIO" &>/dev/null; then
  adduser --disabled-password --gecos "" "$USUARIO"
fi
usermod -aG sudo,docker "$USUARIO"
install -d -m 700 -o "$USUARIO" -g "$USUARIO" "/home/$USUARIO/.ssh"
echo "$CLAVE_PUB" >> "/home/$USUARIO/.ssh/authorized_keys"
sort -u -o "/home/$USUARIO/.ssh/authorized_keys" "/home/$USUARIO/.ssh/authorized_keys"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.ssh/authorized_keys"
chmod 600 "/home/$USUARIO/.ssh/authorized_keys"

echo
echo "Hecho. ANTES de seguir: abre OTRA terminal y comprueba que entras con"
echo "   ssh ${USUARIO}@<IP-de-la-VM>"
echo "y que 'sudo -v' funciona (pon una contraseña con: sudo passwd ${USUARIO})."
echo "Después ejecuta: sudo ./scripts/01-seguridad.sh ${USUARIO}"
