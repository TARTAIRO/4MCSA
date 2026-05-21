<#
.SYNOPSIS
    Installe la MiniAPI sur SRV-SAINTCENERI
.DESCRIPTION
    A executer UNE FOIS sur SRV-SAINTCENERI.
    Configure la tache planifiee MiniAPI-Stats sur port 8082.
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
#>

$scriptsPath = "C:\scripts"

if (-not (Test-Path "$scriptsPath\MiniAPI-Stats.ps1")) {
    Write-Error "MiniAPI-Stats.ps1 manquant dans $scriptsPath"
    exit 1
}

Write-Host "=== Installation MiniAPI SRV-SAINTCENERI ===" -ForegroundColor Cyan

# Tache planifiee
$action    = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\MiniAPI-Stats.ps1"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-MiniAPI" -Action $action -Trigger $trigger `
    -Principal $principal -Force | Out-Null
Write-Host "[OK] Tache MedSearch-MiniAPI enregistree" -ForegroundColor Green

# Regle firewall
New-NetFirewallRule -DisplayName "Allow MiniAPI 8082" -Direction Inbound `
    -Protocol TCP -LocalPort 8082 -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
Write-Host "[OK] Port 8082 ouvert dans le firewall" -ForegroundColor Green

# Autorisation HTTP
netsh http add urlacl url=http://+:8082/ user=Everyone 2>$null
Write-Host "[OK] URL ACL configuree" -ForegroundColor Green

# Demarrage immediat
Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptsPath\MiniAPI-Stats.ps1"
Start-Sleep -Seconds 3

# Test
$test = Invoke-RestMethod -Uri "http://localhost:8082" -ErrorAction SilentlyContinue
if ($test) {
    Write-Host "[OK] MiniAPI repond : CPU=$($test.cpu)% RAM=$($test.ramPct)%" -ForegroundColor Green
} else {
    Write-Host "[WARN] MiniAPI ne repond pas encore, verifier dans 10s" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== TERMINE ===" -ForegroundColor Cyan
Write-Host "N'oubliez pas d'ouvrir le port 8082 sur le NSG Azure de SRV-SAINTCENERI !"
