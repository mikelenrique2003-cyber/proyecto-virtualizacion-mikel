#!/usr/bin/env bash
# Pruebas de funcionamiento rápidas. Ejecutar en la VM.
# Uso: ./scripts/comprobar.sh [IP-de-la-VM]
set -uo pipefail
cd "$(dirname "$0")/.."
IP="${1:-127.0.0.1}"
D=pyme.lan
ok()  { echo "  [OK]    $*"; }
mal() { echo "  [FALLO] $*"; }

echo "1) Contenedores"
docker compose ps --format 'table {{.Name}}\t{{.Status}}'

echo "2) Acceso por nombre y HTTPS"
for n in www soporte nube estado; do
  c=$(curl -sk -o /dev/null -w '%{http_code}' --resolve "$n.$D:443:$IP" "https://$n.$D/")
  [[ "$c" =~ ^(200|301|302|303)$ ]] && ok "https://$n.$D -> $c" || mal "https://$n.$D -> $c"
done

echo "3) HTTP redirige a HTTPS"
c=$(curl -s -o /dev/null -w '%{http_code}' --resolve "www.$D:80:$IP" "http://www.$D/")
[[ "$c" == 301 ]] && ok "http -> 301" || mal "http -> $c"

echo "4) Las bases de datos NO están publicadas"
for p in 3306 6379; do
  if timeout 2 bash -c "</dev/tcp/$IP/$p" 2>/dev/null; then mal "puerto $p abierto"; else ok "puerto $p cerrado"; fi
done
docker compose ps --format '{{.Name}} {{.Ports}}' | grep -E 'db-|redis' | grep -q '0.0.0.0' \
  && mal "alguna BD publica puertos" || ok "ninguna BD publica puertos"

echo "5) Red interna sin salida (db-joomla no llega a Internet)"
docker compose exec -T db-joomla sh -c 'timeout 3 bash -c "</dev/tcp/1.1.1.1/443"' 2>/dev/null \
  && mal "db-joomla tiene salida" || ok "db-joomla aislada"

echo "6) Seguridad del host"
sudo ufw status | head -1
sudo sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication) '
sudo fail2ban-client status sshd | grep -E 'Currently|Total'
