#!/usr/bin/env bash
# Genera un certificado autofirmado (10 años) válido para todos los nombres.
set -euo pipefail
cd "$(dirname "$0")/.."
D="${1:-pyme.lan}"
openssl req -x509 -nodes -newkey rsa:4096 -days 3650 \
  -keyout proxy/certs/pyme.key -out proxy/certs/pyme.crt \
  -subj "/C=ES/O=PYME Soluciones/CN=*.${D}" \
  -addext "subjectAltName=DNS:${D},DNS:www.${D},DNS:soporte.${D},DNS:nube.${D},DNS:estado.${D}"
chmod 600 proxy/certs/pyme.key
openssl x509 -in proxy/certs/pyme.crt -noout -subject -ext subjectAltName
