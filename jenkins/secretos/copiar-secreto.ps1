# Copia un secreto al portapapeles sin mostrarlo en pantalla (por ejemplo, para iniciar sesión en Jenkins).
# Uso:  powershell -ExecutionPolicy Bypass -File jenkins\secretos\copiar-secreto.ps1 JENKINS_ADMIN_PASSWORD
param([Parameter(Mandatory = $true)][string]$Nombre)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Secretos.ps1')

$valor = Leer-Secreto $Nombre
if (-not $valor) { throw "$Nombre no está guardado. Ejecutar guardar-secretos.ps1." }
Set-Clipboard -Value $valor
Write-Host "$Nombre quedó en el portapapeles."
