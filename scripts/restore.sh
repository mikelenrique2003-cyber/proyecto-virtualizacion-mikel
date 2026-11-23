#!/usr/bin/env bash
# =====================================================================
#  restore.sh  -  Restaura UN servicio desde una copia.
#  Uso:  ./scripts/restore.sh <carpeta-copia> <joomla|glpi|nextcloud>
#  Ej.:  ./scripts/restore.sh /var/backups/pyme/2026-12-01_0230 joomla
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

COPIA="${1:?Indica la carpeta de la copia}"
SERV="${2:?Indica el servicio: joomla, glpi o nextcloud}"

case "$SERV" in
  joomla)    APP=joomla;    BD=db-joomla;    VOL=joomla_web ;;
  glpi)      APP=glpi;      BD=db-glpi;      VOL=glpi_datos ;;
  nextcloud) APP=nextcloud; BD=db-nextcloud; VOL=nextcloud_web ;;
  *) echo "Servicio no válido"; exit 1 ;;
esac

echo ">> Comprobando integridad de la copia"
( cd "$COPIA" && sha256sum -c --ignore-missing SHA256SUMS )

read -rp "Se SOBRESCRIBIRÁN los datos actuales de $SERV. Escribe SI para continuar: " r
[[ "$r" == "SI" ]] || exit 1

echo ">> Parando $APP"
docker compose stop "$APP"
[[ "$SERV" == nextcloud ]] && docker compose stop nextcloud-cron

echo ">> Restaurando volumen $VOL"
docker run --rm -v "pyme_${VOL}:/destino" -v "$COPIA:/copia:ro" alpine \
  sh -c "find /destino -mindepth 1 -delete && tar xzf /copia/${VOL}.tar.gz -C /destino"

echo ">> Restaurando base de datos ($BD) desde cero"
docker compose exec -T "$BD" sh -c \
  'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MARIADB_DATABASE\`; CREATE DATABASE \`$MARIADB_DATABASE\`;"'
gunzip -c "$COPIA/${BD}.sql.gz" | docker compose exec -T "$BD" sh -c \
  'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"'

echo ">> Arrancando $APP"
docker compose start "$APP"
if [[ "$SERV" == nextcloud ]]; then
  docker compose start nextcloud-cron
  sleep 10
  docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off
  docker compose exec -T -u www-data nextcloud php occ files:scan --all
fi
echo "Restauración de $SERV completada."
