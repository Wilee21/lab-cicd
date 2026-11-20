#!/bin/sh
# Primera etapa del pipeline: frena la ejecución si la configuración introduce algo que pueda generar
# costos o exponer Jenkins fuera del equipo. Regla del laboratorio: todo debe ser gratuito y local.
# Se ejecuta a mano desde la raíz con:  sh ci/revisar-costos.sh
set -eu

fallas=0
falla() { echo "COSTOS: $1"; fallas=$((fallas + 1)); }

# 1. Solo plugins aprobados (gratuitos, de código abierto y sin servicios externos).
aprobados="configuration-as-code job-dsl workflow-aggregator workflow-multibranch git credentials-binding
timestamper pipeline-stage-view pipeline-graph-view junit warnings-ng htmlpublisher matrix-auth"
while IFS= read -r plugin; do
  plugin=$(echo "$plugin" | sed 's/[:#].*//' | tr -d '[:space:]')
  [ -z "$plugin" ] && continue
  echo " $aprobados " | tr '\n' ' ' | grep -q " $plugin " || falla "plugin no aprobado en jenkins/plugins.txt: $plugin"
done < jenkins/plugins.txt

# 2. Nada de agentes o servicios en la nube que cobren por las máquinas que crean.
if grep -niE 'ec2|azure|google-compute|gce|amazon|aws|digitalocean|kubernetes' jenkins/plugins.txt jenkins/casc.yaml; then
  falla "jenkins/ menciona un agente o servicio en la nube"
fi

# 3. Jenkins publicado solo en este equipo (127.0.0.1), no en la red.
if ! grep -qE '"127\.0\.0\.1:\$\{JENKINS_PORT' jenkins/docker-compose.yml; then
  falla "jenkins/docker-compose.yml debe publicar Jenkins solo en 127.0.0.1"
fi

# 4. Imágenes base esperadas (oficiales y gratuitas).
grep -q '^FROM jenkins/jenkins:lts' jenkins/Dockerfile || falla "jenkins/Dockerfile debe partir de jenkins/jenkins:lts"
[ "$(grep -c '^FROM node:24-alpine' Dockerfile)" -ge 1 ] || falla "Dockerfile debe partir de node:24-alpine"
if grep '^FROM' Dockerfile | grep -vq 'node:24-alpine'; then
  falla "Dockerfile usa una imagen base distinta de node:24-alpine"
fi

# 5. GitHub Actions solo con los ejecutores gratuitos estándar.
if grep -nE 'runs-on:' .github/workflows/*.yml | grep -vE 'runs-on: ubuntu-latest$'; then
  falla "un workflow usa un ejecutor distinto de ubuntu-latest (los más grandes tienen costo)"
fi

if [ "$fallas" -gt 0 ]; then
  echo "Revisión de costos: $fallas problema(s). Confirmar que es gratuito antes de aprobarlo aquí."
  exit 1
fi
echo "Revisión de costos: sin problemas."
