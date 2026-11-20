# Avisos de Windows del laboratorio: consulta la API de Jenkins con el usuario "lector" (solo lectura) y
# muestra una notificación solo cuando algo cambia: una rama o las pruebas en vivo fallan, o vuelven a verde.
# Lo ejecuta cada minuto la tarea programada "Lab CICD avisos" (instalar-avisos.ps1).
# Probar a mano el aviso de la última ejecución de una rama:
#   powershell -ExecutionPolicy Bypass -File jenkins\avisos\avisar.ps1 -Probar main
param([string]$Probar)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'secretos\Secretos.ps1')

$carpeta = Join-Path $env:LOCALAPPDATA 'lab-cicd'
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
$archivoEstado = Join-Path $carpeta 'avisos-estado.json'
$registro = Join-Path $carpeta 'avisos.log'
function Anotar($texto) { Add-Content -Path $registro -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $texto" -Encoding UTF8 }

# Puerto de Jenkins desde jenkins\.env (no contiene secretos).
$puerto = '8080'
$archivoEnv = Join-Path (Split-Path $PSScriptRoot -Parent) '.env'
if (Test-Path $archivoEnv) {
    $linea = Get-Content $archivoEnv | Where-Object { $_ -match '^JENKINS_PORT=(\d+)' } | Select-Object -First 1
    if ($linea -match '^JENKINS_PORT=(\d+)') { $puerto = $Matches[1] }
}
$jenkins = "http://localhost:$puerto"

$clave = Leer-Secreto 'JENKINS_LECTOR_PASSWORD'
if (-not $clave) { Anotar 'Falta JENKINS_LECTOR_PASSWORD en el Administrador de credenciales.'; exit 1 }
$par = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("lector:$clave"))
$cabeceras = @{ Authorization = "Basic $par" }
function Pedir($url) { Invoke-RestMethod -Uri $url -Headers $cabeceras -TimeoutSec 20 }

function Ejecuciones {
    $lista = @()
    $ramas = Pedir "$jenkins/job/catalogo-cursos/api/json?tree=jobs[name,lastCompletedBuild[number,result,url,description]]"
    foreach ($j in $ramas.jobs) { $lista += [pscustomobject]@{ nombre = [uri]::UnescapeDataString($j.name); ejecucion = $j.lastCompletedBuild; resumen = $true } }
    try {
        $nocturno = Pedir "$jenkins/job/pruebas-en-vivo/api/json?tree=lastCompletedBuild[number,result,url,description]"
        $lista += [pscustomobject]@{ nombre = 'Pruebas en vivo'; ejecucion = $nocturno.lastCompletedBuild; resumen = $false }
    } catch { }
    $lista | Where-Object { $_.ejecucion }
}

# Motivo de la falla: los <li> de <ul class="motivos"> de la página Resumen, o la descripción.
function Motivo($item) {
    if ($item.resumen) {
        try {
            # htmlpublisher muestra Resumen/ dentro de un marco; el contenido está en Resumen/index.html.
            $pagina = Invoke-WebRequest -Uri "$($item.ejecucion.url)Resumen/index.html" -Headers $cabeceras -UseBasicParsing -TimeoutSec 20
            if ([Text.Encoding]::UTF8.GetString($pagina.RawContentStream.ToArray()) -match '(?s)<ul class="motivos">(.*?)</ul>') {
                $motivos = [regex]::Matches($Matches[1], '<li>(.*?)</li>') | ForEach-Object { [Net.WebUtility]::HtmlDecode($_.Groups[1].Value) }
                if ($motivos) { return ($motivos -join ' ') }
            }
        } catch { }
    }
    if ($item.ejecucion.description) { return $item.ejecucion.description }
    return "Resultado: $($item.ejecucion.result)"
}

function Avisar($titulo, $texto, $url) {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $e = { param($s) [Security.SecurityElement]::Escape([string]$s) }
    $xml = @"
<toast activationType="protocol" launch="$(& $e $url)">
  <visual><binding template="ToastGeneric">
    <text>$(& $e $titulo)</text>
    <text>$(& $e $texto)</text>
  </binding></visual>
  <actions><action content="Abrir en Jenkins" activationType="protocol" arguments="$(& $e $url)"/></actions>
</toast>
"@
    $documento = New-Object Windows.Data.Xml.Dom.XmlDocument
    $documento.LoadXml($xml)
    # Se muestra como notificación de Windows PowerShell, sin registrar una aplicación propia.
    $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show([Windows.UI.Notifications.ToastNotification]::new($documento))
    Anotar "Aviso: $titulo | $texto"
}

function Destino($item) { if ($item.resumen) { "$($item.ejecucion.url)Resumen/" } else { "$($item.ejecucion.url)console" } }

$items = @(Ejecuciones)

if ($Probar) {
    $item = $items | Where-Object { $_.nombre -eq $Probar } | Select-Object -First 1
    if (-not $item) { "No hay ejecuciones terminadas de '$Probar'."; exit 1 }
    Avisar "$($item.nombre) #$($item.ejecucion.number): $($item.ejecucion.result)" (Motivo $item) (Destino $item)
    exit 0
}

$primeraVez = -not (Test-Path $archivoEstado)
$estado = @{}
if (-not $primeraVez) {
    (Get-Content $archivoEstado -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $estado[$_.Name] = $_.Value }
}

foreach ($item in $items) {
    $antes = $estado[$item.nombre]
    $ahora = $item.ejecucion
    if (-not $primeraVez -and (-not $antes -or $antes.number -ne $ahora.number)) {
        $fallaAhora = $ahora.result -ne 'SUCCESS'
        $fallabaAntes = $antes -and $antes.result -ne 'SUCCESS'
        if ($fallaAhora) {
            Avisar "$($item.nombre) #$($ahora.number) falló" (Motivo $item) (Destino $item)
        } elseif ($fallabaAntes) {
            Avisar "$($item.nombre) #$($ahora.number) se arregló" 'La ejecución volvió a pasar.' (Destino $item)
        }
    }
    $estado[$item.nombre] = [pscustomobject]@{ number = $ahora.number; result = $ahora.result }
}

$estado | ConvertTo-Json | Set-Content -Path $archivoEstado -Encoding UTF8
if ($primeraVez) { Anotar 'Primera ejecución: se guardó el estado sin avisar.' }
