#!/usr/bin/env bash
# Sustituye cada CAMBIAME del .env por una contraseña aleatoria distinta
# (32 caracteres alfanuméricos) y deja el fichero legible solo por el dueño.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || cp .env.example .env

aleatoria() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

TMP="$(mktemp)"
while IFS= read -r linea; do
  if [[ "$linea" == *=CAMBIAME ]]; then
    echo "${linea%CAMBIAME}$(aleatoria)"
  else
    echo "$linea"
  fi
done < .env > "$TMP"
mv "$TMP" .env
chmod 600 .env

echo "Secretos generados en .env (permisos 600). Quedan sin rellenar:"
grep -c '=CAMBIAME' .env || true
echo "Guárdalos en un gestor de contraseñas: .env NO se sube a Git."
