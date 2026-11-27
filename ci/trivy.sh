#!/bin/sh
# Escaneo de seguridad con Trivy (código abierto, sin cuenta).
#   sh ci/trivy.sh fs              -> dependencias (package-lock.json) y configuración (Dockerfile)
#   sh ci/trivy.sh imagen <imagen> -> paquetes del sistema operativo y de Node.js dentro de la imagen
# Falla (código 1) con hallazgos de severidad ALTA o CRÍTICA que tengan corrección disponible.
# Deja el reporte en reportes/trivy-fs.txt o reportes/trivy-imagen.txt.
# Funciona en Jenkins (--volumes-from) y en cualquier equipo con Docker (MONTAR_DIRECTORIO=1).
set -eu

IMAGEN_TRIVY="${IMAGEN_TRIVY:-aquasec/trivy:latest}"
modo="${1:?uso: sh ci/trivy.sh fs | imagen <imagen>}"
mkdir -p reportes

if [ "${MONTAR_DIRECTORIO:-0}" = "1" ]; then
  volumen="-v $PWD:$PWD"
else
  volumen="--volumes-from $HOSTNAME"
fi
# La base de vulnerabilidades queda en un volumen para no descargarla en cada ejecución.
comunes="--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress"

set +e
case "$modo" in
  fs)
    reporte=reportes/trivy-fs.txt
    # shellcheck disable=SC2086
    docker run --rm $volumen -w "$PWD" -v trivy-cache:/root/.cache \
      "$IMAGEN_TRIVY" fs --scanners vuln,misconfig $comunes \
      --skip-dirs node_modules --skip-dirs jenkins . > "$reporte" 2>&1
    ;;
  imagen)
    reporte=reportes/trivy-imagen.txt
    imagen="${2:?falta la imagen a escanear}"
    # shellcheck disable=SC2086
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
      "$IMAGEN_TRIVY" image --scanners vuln $comunes "$imagen" > "$reporte" 2>&1
    ;;
  *)
    echo "Modo desconocido: $modo"
    exit 2
    ;;
esac
estado=$?
set -e

cat "$reporte"
if [ "$estado" -ne 0 ]; then
  echo "Trivy ($modo): hay hallazgos ALTOS o CRÍTICOS con corrección disponible (detalle arriba)."
fi
exit "$estado"
