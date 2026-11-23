#!/usr/bin/env bash
# =====================================================================
#  backup.sh  -  Copia completa: 3 bases de datos + volúmenes de datos.
#  Lo lanza a diario el temporizador systemd pyme-backup.timer (02:30).
#  Resultado: $BACKUP_DIR/AAAA-MM-DD_HHMM/ con .sql.gz, .tar.gz y SHA256SUMS
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DESTINO="${BACKUP_DIR}/$(date +%F_%H%M)"
mkdir -p "$DESTINO"
chmod 700 "$BACKUP_DIR"
log() { echo "[$(date '+%F %T')] $*"; }

# --- 1. Bases de datos (con el usuario de cada aplicación, nunca root) --
volcar_bd() {   # $1 = servicio de BD
  log "Volcando $1"
  docker compose exec -T "$1" sh -c \
    'mariadb-dump -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" --single-transaction --routines --triggers "$MARIADB_DATABASE"' \
    | gzip > "$DESTINO/$1.sql.gz"
}

# Nextcloud en modo mantenimiento para que BD y ficheros cuadren
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --on
trap 'docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off' EXIT

volcar_bd db-joomla
volcar_bd db-glpi
volcar_bd db-nextcloud

# --- 2. Volúmenes de ficheros -----------------------------------------
copiar_volumen() {   # $1 = volumen sin prefijo
  log "Copiando volumen $1"
  docker run --rm -v "pyme_$1:/origen:ro" -v "$DESTINO:/destino" alpine \
    tar czf "/destino/$1.tar.gz" -C /origen .
}
for v in joomla_web glpi_datos nextcloud_web kuma_datos; do copiar_volumen "$v"; done

# --- 3. Configuración del despliegue (incluye .env: carpeta protegida) -
tar czf "$DESTINO/config.tar.gz" .env proxy/certs docker-compose.yml proxy/conf.d config

# --- 4. Integridad y retención ----------------------------------------
( cd "$DESTINO" && sha256sum * > SHA256SUMS )
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"${BACKUP_RETENCION_DIAS}" -exec rm -rf {} +

log "Copia terminada en $DESTINO ($(du -sh "$DESTINO" | cut -f1))"
