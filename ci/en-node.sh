#!/bin/sh
# Ejecuta un comando en un contenedor de Node.js sobre el workspace de Jenkins.
# Jenkins no tiene Node instalado: usa el motor Docker del equipo anfitrión y comparte sus volúmenes
# (--volumes-from), de modo que el contenedor ve el mismo workspace y deja allí los reportes.
# Uso:  sh ci/en-node.sh "npm ci && npm test"
# Variables opcionales: IMAGEN_NODE (por defecto node:24-alpine) y PASAR_VARIABLES, una lista de
# nombres de variables de entorno que se pasan al contenedor (por ejemplo "RESULTADO RAMA").
set -eu

IMAGEN_NODE="${IMAGEN_NODE:-node:24-alpine}"
extra=""
for nombre in ${PASAR_VARIABLES:-}; do
  extra="$extra -e $nombre"
done

# shellcheck disable=SC2086  # $extra se separa en argumentos a propósito
exec docker run --rm \
  --volumes-from "$HOSTNAME" \
  -w "$PWD" \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e npm_config_cache=/tmp/.npm \
  $extra \
  "$IMAGEN_NODE" sh -c "$1"
