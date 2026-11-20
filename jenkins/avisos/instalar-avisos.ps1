# Instala la tarea programada "Lab CICD avisos": ejecuta avisar.ps1 cada minuto, sin ventana, con la
# sesión del usuario actual (las notificaciones solo se ven con la sesión iniciada). No requiere administrador.
# Uso, desde la raíz del repositorio:
#   powershell -ExecutionPolicy Bypass -File jenkins\avisos\instalar-avisos.ps1
# Quitarla:  Unregister-ScheduledTask -TaskName 'Lab CICD avisos' -Confirm:$false
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'avisar.ps1'

$accion = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""
$disparador = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
$usuario = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName 'Lab CICD avisos' -Action $accion -Trigger $disparador `
    -Principal $usuario -Settings $ajustes -Description 'Avisos de Windows del Jenkins del laboratorio de CI/CD' -Force | Out-Null
Write-Host "Tarea 'Lab CICD avisos' instalada. Registro: $env:LOCALAPPDATA\lab-cicd\avisos.log"
