<#
.SYNOPSIS
    Script d'installation complète de l'infrastructure MedSearch
.DESCRIPTION
    A lancer sur SRV-CAEN après installation Windows Server 2022 et promotion AD DS.
    Configure tous les rôles, services et tâches planifiées.
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Pré-requis : Windows Server 2022, AD DS promu, exécuté en tant qu'Admin
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  INSTALLATION INFRASTRUCTURE MEDSEARCH" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ============================================================
# ETAPE 1 — IIS
# ============================================================
Write-Host "`n[1/6] Installation IIS..." -ForegroundColor Yellow
Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-Scripting-Tools -IncludeManagementTools | Out-Null
Write-Host "IIS installe !" -ForegroundColor Green

# ============================================================
# ETAPE 2 — RRAS VPN
# ============================================================
Write-Host "`n[2/6] Installation RRAS..." -ForegroundColor Yellow
Install-WindowsFeature -Name Routing, DirectAccess-VPN -IncludeManagementTools | Out-Null
netsh ras add registeredserver | Out-Null
Set-Service -Name RemoteAccess -StartupType Automatic
Start-Service -Name RemoteAccess -ErrorAction SilentlyContinue
Write-Host "RRAS installe et demarre !" -ForegroundColor Green

# ============================================================
# ETAPE 3 — Failover Clustering
# ============================================================
Write-Host "`n[3/6] Installation Failover Clustering..." -ForegroundColor Yellow
Install-WindowsFeature -Name Failover-Clustering, Hyper-V-Tools, RSAT-Clustering -IncludeManagementTools | Out-Null
Write-Host "Failover Clustering installe !" -ForegroundColor Green

# ============================================================
# ETAPE 4 — Monitoring
# ============================================================
Write-Host "`n[4/6] Configuration Monitoring..." -ForegroundColor Yellow
New-EventLog -LogName Application -Source "MedSearch-Monitor" -ErrorAction SilentlyContinue

$monitorAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\scripts\Monitor-Alert.ps1"
$monitorTrigger = New-ScheduledTaskTrigger -AtStartup
$monitorPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-Monitor" -Action $monitorAction -Trigger $monitorTrigger -Principal $monitorPrincipal -Force | Out-Null
Write-Host "Monitoring configure !" -ForegroundColor Green

# ============================================================
# ETAPE 5 — WEF Centralisation logs
# ============================================================
Write-Host "`n[5/6] Configuration WEF..." -ForegroundColor Yellow
winrm quickconfig -quiet 2>$null
wecutil qc -quiet 2>$null
if (Test-Path "C:\configs\WEF-Subscription.xml") {
    wecutil cs "C:\configs\WEF-Subscription.xml"
    Write-Host "WEF configure !" -ForegroundColor Green
} else {
    Write-Host "WEF-Subscription.xml manquant, config manuelle requise" -ForegroundColor Yellow
}

# ============================================================
# ETAPE 6 — Dashboard + API
# ============================================================
Write-Host "`n[6/6] Configuration Dashboard..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "C:\Sites\Dashboard" -Force | Out-Null

Import-Module WebAdministration -ErrorAction SilentlyContinue
if (-not (Get-WebAppPoolState -Name "Dashboard" -ErrorAction SilentlyContinue)) {
    New-WebAppPool -Name "Dashboard" | Out-Null
}
if (-not (Get-Website -Name "Dashboard" -ErrorAction SilentlyContinue)) {
    New-Website -Name "Dashboard" -PhysicalPath "C:\Sites\Dashboard" -Port 8080 -ApplicationPool "Dashboard" | Out-Null
}

# Copier le dashboard
if (Test-Path "C:\dashboard\index.html") {
    Copy-Item "C:\dashboard\index.html" "C:\Sites\Dashboard\" -Force
}

# Firewall
New-NetFirewallRule -DisplayName "Allow HTTP 80" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Allow Dashboard 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Allow API 8081" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Allow SSTP VPN 443" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# Demarrer l'API
$apiAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\scripts\API-Dashboard.ps1"
$apiTrigger = New-ScheduledTaskTrigger -AtStartup
$apiPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-API" -Action $apiAction -Trigger $apiTrigger -Principal $apiPrincipal -Force | Out-Null
Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\scripts\API-Dashboard.ps1"

Write-Host "Dashboard configure !" -ForegroundColor Green

# ============================================================
# BILAN FINAL
# ============================================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  INSTALLATION TERMINEE !" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dashboard    : http://$(hostname):8080" -ForegroundColor White
Write-Host "API          : http://$(hostname):8081/api/stats" -ForegroundColor White
Write-Host "VPN SSTP     : $(hostname):443" -ForegroundColor White
Write-Host ""
Write-Host "Prochaines etapes manuelles :" -ForegroundColor Yellow
Write-Host "  1. Joindre SRV-SAINTCENERI au domaine" -ForegroundColor White
Write-Host "  2. Installer RDS sur SRV-SAINTCENERI" -ForegroundColor White
Write-Host "  3. Creer le cluster : New-Cluster -Name CLUSTER-MEDSEARCH -Node SRV-CAEN,SRV-SAINTCENERI" -ForegroundColor White
Write-Host "  4. Configurer le Cloud Witness Azure" -ForegroundColor White
