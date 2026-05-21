param(
    [Parameter(Mandatory=$true)][string]$SiteName,
    [Parameter(Mandatory=$true)][string]$IPAddress,
    [Parameter(Mandatory=$true)][string]$ZipPath
)

<#
.SYNOPSIS
    Deploiement automatise d'un site IIS pour MedSearch
.DESCRIPTION
    Cree un site IIS complet (dossier + AppPool + Website) a partir d'un fichier ZIP.
    Paramètres requis : nom du site, IP d'écoute, chemin vers le ZIP.
.EXAMPLE
    .\Deploy-Site.ps1 -SiteName "ProjetAlpha" -IPAddress "10.1.0.4" -ZipPath "C:\sites\alpha.zip"
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
    Requis  : Windows Server 2022, IIS installe, droits administrateur
#>

# Verification des pre-requis
if (-not (Get-Module -ListAvailable -Name WebAdministration)) {
    Write-Error "IIS n'est pas installe. Lancez : Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
    exit 1
}

if (-not (Test-Path $ZipPath)) {
    Write-Error "Le fichier ZIP n'existe pas : $ZipPath"
    exit 1
}

Write-Host "Deploiement du site '$SiteName' sur $IPAddress..." -ForegroundColor Cyan

# Etape 1 : Creation du dossier
$sitePath = "C:\Sites\$SiteName"
New-Item -ItemType Directory -Path $sitePath -Force | Out-Null
Write-Host "[1/4] Dossier cree : $sitePath" -ForegroundColor Green

# Etape 2 : Extraction du ZIP
Expand-Archive -Path $ZipPath -DestinationPath $sitePath -Force
Write-Host "[2/4] Site extrait dans $sitePath" -ForegroundColor Green

# Etape 3 : Creation de l'Application Pool
Import-Module WebAdministration
if (-not (Get-WebAppPoolState -Name $SiteName -ErrorAction SilentlyContinue)) {
    New-WebAppPool -Name $SiteName | Out-Null
    Write-Host "[3/4] AppPool '$SiteName' cree" -ForegroundColor Green
} else {
    Write-Host "[3/4] AppPool '$SiteName' existant (conserve)" -ForegroundColor Yellow
}

# Etape 4 : Creation du site IIS
if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
    New-Website -Name $SiteName -PhysicalPath $sitePath -IPAddress $IPAddress -Port 80 -ApplicationPool $SiteName | Out-Null
    Write-Host "[4/4] Site IIS '$SiteName' cree sur $IPAddress:80" -ForegroundColor Green
} else {
    Write-Host "[4/4] Site '$SiteName' existant (mise a jour du chemin)" -ForegroundColor Yellow
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $sitePath
}

# Verification finale
$site = Get-Website -Name $SiteName
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  DEPLOIEMENT REUSSI !" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Nom     : $($site.Name)"
Write-Host "  Etat    : $($site.State)"
Write-Host "  Chemin  : $($site.PhysicalPath)"
Write-Host "  URL     : http://$IPAddress"
Write-Host "=======================================" -ForegroundColor Cyan
