#!/usr/bin/env bash
# =====================================================================
#  Configura Nextcloud como repositorio documental del proyecto:
#   - 2 grupos: direccion, tecnicos
#   - 2 usuarios además del admin: ana (direccion), luis (tecnicos)
#   - 2 carpetas compartidas (app Team folders / groupfolders):
#       Documentacion-Proyecto  direccion=total     tecnicos=solo lectura
#       Soporte-TI              tecnicos=total      direccion=solo lectura
#  Es idempotente: se puede ejecutar varias veces.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

occ() { docker compose exec -T -u www-data nextcloud php occ "$@"; }
occ_env() { docker compose exec -T -u www-data -e OC_PASS="$1" nextcloud php occ "${@:2}"; }

echo ">> Esperando a que Nextcloud termine de instalarse..."
until occ status 2>/dev/null | grep -q 'installed: true'; do sleep 5; done

echo ">> Ajustes generales"
occ config:system:set default_phone_region --value=ES
occ config:system:set maintenance_window_start --type=integer --value=1
occ background:cron
occ app:install groupfolders 2>/dev/null || occ app:enable groupfolders

echo ">> Grupos"
for g in direccion tecnicos; do occ group:add "$g" 2>/dev/null || true; done

echo ">> Usuarios"
occ_env "$NC_PASS_ANA"  user:add --password-from-env --display-name="Ana (Dirección)" -g direccion ana  2>/dev/null || true
occ_env "$NC_PASS_LUIS" user:add --password-from-env --display-name="Luis (Técnico)"  -g tecnicos  luis 2>/dev/null || true

echo ">> Carpetas compartidas con permisos"
crear_carpeta() {   # $1 = nombre
  local id
  # Si ya existe, se reutiliza su ID (columna 1 de la tabla de groupfolders:list)
  id=$(occ groupfolders:list | awk -F'|' -v n="$1" '{g=$3; gsub(/ /,"",g)} g==n {gsub(/ /,"",$2); print $2}')
  [[ -n "$id" ]] || id=$(occ groupfolders:create "$1" | tr -dc '0-9')
  echo "$id"
}
DOC=$(crear_carpeta "Documentacion-Proyecto")
SOP=$(crear_carpeta "Soporte-TI")

# Permisos válidos: read, write (crear+modificar), share, delete. Sin nada = solo lectura.
occ groupfolders:group "$DOC" direccion read write share delete
occ groupfolders:group "$DOC" tecnicos  read
occ groupfolders:group "$SOP" tecnicos  read write share delete
occ groupfolders:group "$SOP" direccion read

occ groupfolders:list
occ user:list
