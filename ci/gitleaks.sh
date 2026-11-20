#!/bin/sh
# Busca secretos (contraseñas, tokens, llaves) en todo el historial de Git con Gitleaks.
# Deja el reporte SARIF en reportes/gitleaks.sarif y sale con código 1 si encuentra alguno.
# Funciona en Jenkins (comparte el workspace con --volumes-from) y en cualquier equipo con Docker
# (con MONTAR_DIRECTORIO=1 monta la carpeta actual).
set -eu

IMAGEN_GITLEAKS="${IMAGEN_GITLEAKS:-ghcr.io/gitleaks/gitleaks:v8.28.0}"
mkdir -p reportes

if [ "${MONTAR_DIRECTORIO:-0}" = "1" ]; then
  volumen="-v $PWD:$PWD"
else
  volumen="--volumes-from $HOSTNAME"
fi

# shellcheck disable=SC2086
docker run --rm $volumen -w "$PWD" -u "$(id -u):$(id -g)" \
  -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
  "$IMAGEN_GITLEAKS" git "$PWD" \
  --redact --no-banner \
  --report-format sarif --report-path "$PWD/reportes/gitleaks.sarif"
