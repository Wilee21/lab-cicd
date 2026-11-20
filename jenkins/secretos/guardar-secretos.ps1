# Guarda los secretos del laboratorio en el Administrador de credenciales de Windows.
# - Si alguno todavía está en jenkins\.env, lo mueve: lo guarda cifrado y lo borra del archivo.
# - Las contraseñas de Jenkins que falten se generan al azar (no se muestran; ver copiar-secreto.ps1).
# - El token de Docker Hub solo se pide si REGISTRY_HOST=docker.io; se escribe sin mostrarse.
# Uso, desde la raíz del repositorio:
#   powershell -ExecutionPolicy Bypass -File jenkins\secretos\guardar-secretos.ps1
#   powershell -ExecutionPolicy Bypass -File jenkins\secretos\guardar-secretos.ps1 -Cambiar DOCKERHUB_TOKEN
param([string]$Cambiar)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Secretos.ps1')

$archivoEnv = Join-Path (Split-Path $PSScriptRoot -Parent) '.env'
$lineas = if (Test-Path $archivoEnv) { @(Get-Content $archivoEnv -Encoding UTF8) } else { @() }
$config = @{}
foreach ($l in $lineas) { if ($l -match '^\s*([A-Z_]+)\s*=(.*)$') { $config[$Matches[1]] = $Matches[2].Trim() } }

function Nueva-Clave {
    $bytes = New-Object byte[] 18
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [Convert]::ToBase64String($bytes).Replace('+', 'A').Replace('/', 'B')
}

function Pedir-Oculto([string]$Nombre) {
    $seguro = Read-Host "Valor de $Nombre (no se muestra)" -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($seguro))
}

$nombres = if ($Cambiar) { @($Cambiar) } else { $LabSecretos }
foreach ($nombre in $nombres) {
    if ($LabSecretos -notcontains $nombre) { throw "Secreto desconocido: $nombre. Válidos: $($LabSecretos -join ', ')" }
    $valor = $null
    if ($config.ContainsKey($nombre) -and $config[$nombre]) {
        $valor = $config[$nombre]
        Write-Host "$nombre se movió desde .env."
    } elseif ($Cambiar -or -not (Leer-Secreto $nombre)) {
        if ($nombre -eq 'DOCKERHUB_TOKEN') {
            if ($config['REGISTRY_HOST'] -eq 'docker.io' -or $Cambiar) { $valor = Pedir-Oculto $nombre }
            else { Write-Host "DOCKERHUB_TOKEN no hace falta con el registro local ($($config['REGISTRY_HOST']))."; continue }
        } else {
            $valor = Nueva-Clave
            Write-Host "$nombre se generó al azar."
        }
    } else {
        Write-Host "$nombre ya estaba guardado."
        continue
    }
    Guardar-Secreto $nombre $valor
    if ((Leer-Secreto $nombre) -ne $valor) { throw "No se pudo comprobar $nombre en el Administrador de credenciales." }
}

# Quitar de .env los secretos que se movieron.
$restantes = $lineas | Where-Object { -not ($_ -match '^\s*([A-Z_]+)\s*=' -and $LabSecretos -contains $Matches[1]) }
if ($restantes.Count -ne $lineas.Count) {
    $utf8 = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllLines($archivoEnv, [string[]]$restantes, $utf8)
    Write-Host '.env ya no contiene secretos.'
}
Write-Host 'Listo. Para aplicar los cambios: jenkins\arrancar-jenkins.ps1'
