#!/bin/sh
# Análisis estático de código con SonarQube Community Build, sin cuentas ni servicios externos.
# Levanta un servidor SonarQube temporal en un contenedor, analiza el proyecto con sonar-scanner
# (incluida la cobertura de reportes/lcov.info, generada antes por las pruebas) y descarga los resultados.
# Al terminar elimina el servidor y su red. Los topes se aplican después con ci/revisar-sonarqube.js.
#
# Deja en reportes/: sonarqube-medidas.json, sonarqube-issues.json y sonarqube-hotspots.json.
# Funciona en Jenkins (comparte el workspace con --volumes-from) y en cualquier equipo con Docker
# (con MONTAR_DIRECTORIO=1 monta la carpeta actual), igual que ci/gitleaks.sh.
# Uso desde la raíz:  MONTAR_DIRECTORIO=1 sh ci/sonarqube.sh
set -eu

IMAGEN_SONARQUBE="${IMAGEN_SONARQUBE:-sonarqube:community}"
IMAGEN_SCANNER="${IMAGEN_SCANNER:-sonarsource/sonar-scanner-cli:latest}"
IMAGEN_CURL="${IMAGEN_CURL:-curlimages/curl:latest}"

mkdir -p reportes
proyecto=$(sed -n 's/^sonar.projectKey=//p' sonar-project.properties | tr -d '[:space:]')
red="sonarqube-$$"
servidor="sonarqube-$$"

limpiar() {
  docker rm -f "$servidor" >/dev/null 2>&1 || true
  docker network rm "$red" >/dev/null 2>&1 || true
}
trap limpiar EXIT

# Llama a la API de SonarQube desde un contenedor en la misma red (Jenkins no publica puertos).
# Es un servidor efímero y aislado: se usan las credenciales iniciales de administrador solo para
# crear el token del análisis.
api() {
  metodo=$1
  ruta=$2
  shift 2
  docker run --rm --network "$red" "$IMAGEN_CURL" -s -f -u admin:admin -X "$metodo" "http://sonarqube:9000$ruta" "$@"
}

docker network create "$red" >/dev/null
# SONAR_ES_BOOTSTRAP_CHECKS_DISABLE evita exigir vm.max_map_count al equipo anfitrión.
docker run -d --name "$servidor" --network "$red" --network-alias sonarqube \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true "$IMAGEN_SONARQUBE" >/dev/null

echo "Esperando a que SonarQube arranque..."
intentos=0
until [ "$(api GET /api/system/status 2>/dev/null | sed -n 's/.*"status":"\([A-Z_]*\)".*/\1/p')" = "UP" ]; do
  intentos=$((intentos + 1))
  if [ "$intentos" -gt 72 ]; then
    echo "SonarQube no arrancó en 6 minutos. Últimas líneas del servidor:"
    docker logs --tail 40 "$servidor"
    exit 1
  fi
  sleep 5
done
echo "SonarQube listo ($(api GET /api/server/version))."

token=$(api POST /api/user_tokens/generate -d name=pipeline -d type=GLOBAL_ANALYSIS_TOKEN | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "No se pudo crear el token de análisis."; exit 1; }

if [ "${MONTAR_DIRECTORIO:-0}" = "1" ]; then
  volumen="-v $PWD:$PWD"
else
  volumen="--volumes-from $HOSTNAME"
fi

# shellcheck disable=SC2086
docker run --rm --network "$red" $volumen -w "$PWD" -u "$(id -u):$(id -g)" \
  -e SONAR_HOST_URL=http://sonarqube:9000 \
  -e SONAR_TOKEN="$token" \
  -e SONAR_USER_HOME="$PWD/.sonar" \
  -e HOME=/tmp \
  "$IMAGEN_SCANNER" \
  -Dsonar.projectBaseDir="$PWD"   -Dsonar.working.directory="$PWD/.scannerwork" \
  -Dsonar.qualitygate.wait=true \
  -Dsonar.qualitygate.timeout=300

# Descarga resultados probando alternativas: los nombres de métricas y parámetros cambian entre versiones.
consultar() {
  salida=$1
  shift
  for ruta in "$@"; do
    cuerpo=$(docker run --rm --network "$red" "$IMAGEN_CURL" -s -u admin:admin -w '\n%{http_code}' "http://sonarqube:9000$ruta")
    codigo=$(printf '%s' "$cuerpo" | tail -n 1)
    if [ "$codigo" = "200" ]; then
      printf '%s' "$cuerpo" | sed '$d' > "$salida"
      return 0
    fi
    echo "Aviso: $ruta respondió $codigo: $(printf '%s' "$cuerpo" | sed '$d' | head -c 300)"
  done
  echo "No se pudo obtener $salida"
  return 1
}

clasicas="bugs,vulnerabilities,security_hotspots,code_smells,coverage,duplicated_lines_density,ncloc"
nuevas="software_quality_reliability_issues,software_quality_security_issues,software_quality_maintainability_issues,security_hotspots,coverage,duplicated_lines_density,ncloc"
consultar reportes/sonarqube-medidas.json   "/api/measures/component?component=$proyecto&metricKeys=$clasicas"   "/api/measures/component?component=$proyecto&metricKeys=$nuevas"
consultar reportes/sonarqube-issues.json   "/api/issues/search?components=$proyecto&resolved=false&ps=500"   "/api/issues/search?componentKeys=$proyecto&resolved=false&ps=500"
consultar reportes/sonarqube-hotspots.json   "/api/hotspots/search?project=$proyecto&ps=500"   "/api/hotspots/search?projectKey=$proyecto&ps=500"
echo "Resultados de SonarQube en reportes/sonarqube-*.json"
