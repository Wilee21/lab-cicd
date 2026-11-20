# Inicia (o recrea) Jenkins y el registro local con los secretos del Administrador de credenciales de
# Windows. Reemplaza a "docker compose up -d": los secretos no están en .env.
# Uso, desde la raíz del repositorio:
#   powershell -ExecutionPolicy Bypass -File jenkins\arrancar-jenkins.ps1          # aplica cambios
#   powershell -ExecutionPolicy Bypass -File jenkins\arrancar-jenkins.ps1 -Build   # además reconstruye la imagen
# Los valores solo pasan por la memoria de este proceso y de docker compose.
param([switch]$Build)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'secretos\Secretos.ps1')

$obligatorios = @('JENKINS_ADMIN_PASSWORD', 'JENKINS_LECTOR_PASSWORD')
$faltan = @()
foreach ($nombre in $LabSecretos) {
    $valor = Leer-Secreto $nombre
    if ($valor) { Set-Item -Path "env:$nombre" -Value $valor }
    elseif ($obligatorios -contains $nombre) { $faltan += $nombre }
}
if ($faltan) {
    throw "Faltan en el Administrador de credenciales: $($faltan -join ', '). Ejecutar jenkins\secretos\guardar-secretos.ps1"
}

Push-Location $PSScriptRoot
try {
    if ($Build) { docker compose up -d --build } else { docker compose up -d }
    if ($LASTEXITCODE -ne 0) { throw "docker compose terminó con código $LASTEXITCODE" }
} finally {
    Pop-Location
    foreach ($nombre in $LabSecretos) { Remove-Item -Path "env:$nombre" -ErrorAction SilentlyContinue }
}
