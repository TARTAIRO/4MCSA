<#
.SYNOPSIS
    Enregistre toutes les tâches planifiées MedSearch au démarrage
.DESCRIPTION
    A executer UNE FOIS sur SRV-CAEN apres installation.
    Configure :
    - MedSearch-Monitor : surveillance CPU/RAM
    - MedSearch-API     : API REST dashboard port 8081
    - MedSearch-IIS     : watchdog IIS (redemarrage automatique)
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
    Requis  : Windows Server 2022, droits administrateur
#>

$scriptsPath = "C:\scripts"

# Verifier que les scripts existent
if (-not (Test-Path "$scriptsPath\Monitor-Alert.ps1"))   { Write-Error "Monitor-Alert.ps1 manquant dans $scriptsPath"; exit 1 }
if (-not (Test-Path "$scriptsPath\API-Dashboard.ps1"))   { Write-Error "API-Dashboard.ps1 manquant dans $scriptsPath"; exit 1 }

Write-Host "=== Configuration des taches planifiees MedSearch ===" -ForegroundColor Cyan

# ── Tache 1 : Monitor-Alert ──────────────────────────────────────────────────
$action    = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\Monitor-Alert.ps1"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-Monitor" -Action $action -Trigger $trigger `
    -Principal $principal -Force | Out-Null
Write-Host "[OK] Tache MedSearch-Monitor enregistree" -ForegroundColor Green

# ── Tache 2 : API-Dashboard ──────────────────────────────────────────────────
$action    = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\API-Dashboard.ps1"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-API" -Action $action -Trigger $trigger `
    -Principal $principal -Force | Out-Null
Write-Host "[OK] Tache MedSearch-API enregistree" -ForegroundColor Green

# ── Tache 3 : Watchdog IIS ───────────────────────────────────────────────────
$action    = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-Command `"Start-Service W3SVC -ErrorAction SilentlyContinue`""
$trigger   = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -Once -At (Get-Date)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-IIS-Watchdog" -Action $action -Trigger $trigger `
    -Principal $principal -Force | Out-Null
Write-Host "[OK] Tache MedSearch-IIS-Watchdog enregistree" -ForegroundColor Green

# ── Source EventLog ───────────────────────────────────────────────────────────
New-EventLog -LogName Application -Source "MedSearch-Monitor" -ErrorAction SilentlyContinue
Write-Host "[OK] Source EventLog MedSearch-Monitor creee" -ForegroundColor Green

# ── Demarrage immediat ────────────────────────────────────────────────────────
Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\Monitor-Alert.ps1"
Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\API-Dashboard.ps1"
Write-Host "[OK] Services demarres" -ForegroundColor Green

Write-Host ""
Write-Host "=== TERMINE ===" -ForegroundColor Cyan
Write-Host "Verifications :"
Write-Host "  Get-ScheduledTask | Where-Object {`$_.TaskName -like 'MedSearch*'}"
Write-Host "  Invoke-RestMethod -Uri http://localhost:8081/api/stats"
