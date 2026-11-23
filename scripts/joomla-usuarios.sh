#!/usr/bin/env bash
# Crea en Joomla los perfiles editor y lector (el Super User se crea al instalar).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

J() { docker compose exec -T -u www-data joomla php cli/joomla.php "$@"; }

J user:add -n --username=editorweb --name="Editora Web" \
  --email=editor@${DOMINIO} --password="${JOOMLA_PASS_EDITOR}" --usergroup=Editor || true
J user:add -n --username=lectorweb --name="Lector Registrado" \
  --email=lector@${DOMINIO} --password="${JOOMLA_PASS_LECTOR}" --usergroup=Registered || true

J user:list
