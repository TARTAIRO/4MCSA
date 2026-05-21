# Remote Access — RRAS VPN SSTP et RDS

## 1. Objectif

L'administrateur unique de MedSearch doit pouvoir gérer l'infrastructure depuis n'importe quel endroit. Deux options complémentaires sont proposées :

| Option | Cas d'usage | Avantage |
|--------|-------------|----------|
| **RRAS VPN SSTP** | Accès réseau sécurisé complet | Port 443, transparent, aucune config client |
| **RDS Session Host** | Bureau Windows à distance | Interface graphique complète |

---

## 2. Option 1 — RRAS VPN SSTP

### Pourquoi SSTP (Secure Socket Tunneling Protocol)

- Utilise le **port HTTPS 443** → passe tous les firewalls sans configuration
- **Aucune configuration côté client** — connexion VPN native Windows
- Chiffrement SSL/TLS garanti par un certificat CA MedSearch
- Compatible Windows 7/8/10/11 nativement

### 2.1 Installation des rôles RRAS

```powershell
Install-WindowsFeature -Name Routing -IncludeManagementTools
Install-WindowsFeature -Name DirectAccess-VPN -IncludeManagementTools
Install-WindowsFeature -Name NPAS -IncludeManagementTools
```

Résultat :
```
Success : True
Feature Result : RAS Connection Manager Administration Kit,
                 DirectAccess and VPN (RAS), Routing,
                 Network Policy and Access Services
```

### 2.2 Enregistrement dans le domaine

```powershell
netsh ras add registeredserver
Set-Service -Name RemoteAccess -StartupType Automatic
Start-Service -Name RemoteAccess
```

Résultat :
```
Registration completed successfully:
Remote Access Server : SRV-CAEN
Domain              : medsearch.local
```

### 2.3 Autorité de Certification MedSearch

Pour que le certificat VPN soit approuvé par les clients sans manipulation, une CA d'entreprise a été déployée.

```powershell
# Installation de la CA
Install-WindowsFeature -Name AD-Certificate, ADCS-Cert-Authority -IncludeManagementTools

# Configuration CA racine d'entreprise
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCA `
    -CACommonName "MedSearch-CA" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 10 `
    -Force
```

Résultat :
```
Service CertSvc : Running
CA              : MedSearch-CA
Domaine         : medsearch.local
```

### 2.4 Génération du certificat VPN

```powershell
# Certificat signé par MedSearch-CA
$ca   = Get-ChildItem Cert:\LocalMachine\CA | Where-Object {$_.Subject -like "*MedSearch*"} | Select-Object -First 1
$cert = New-SelfSignedCertificate `
    -DnsName "20.82.143.72", "SRV-CAEN.medsearch.local" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyUsage KeyEncipherment, DigitalSignature `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(5) `
    -Signer $ca

Set-RemoteAccess -SslCertificate $cert
```

Validation :
```
Sujet    : CN=20.82.143.72
Emetteur : CN=MedSearch-CA, DC=medsearch, DC=local
Valide   : 05/21/2031
```

### 2.5 Configuration NPS (Network Policy Server)

Une politique NPS `MedSearch-VPN-Policy` a été créée pour autoriser les connexions VPN :

| Paramètre | Valeur |
|-----------|--------|
| Condition | NAS Port Type = Virtual (VPN) |
| Accès | Grant Access |
| Authentification | MS-CHAP v2 |
| Protocole | PPP Framed |

### 2.6 Pool d'adresses IP VPN

```powershell
netsh ras ip add range from=192.168.200.1 to=192.168.200.10
netsh ras ip set addrassign method=pool
```

Résultat :
```
Assignment method : pool
Pool              : 192.168.200.1 to 192.168.200.10
```

### 2.7 Utilisateur VPN

```powershell
net user vpnuser MedSearch2024! /add /domain
net localgroup "Remote Desktop Users" vpnuser /add
```

### 2.8 Validation RRAS

```powershell
Get-Service -Name RemoteAccess | Select-Object Name, Status, StartType
Get-RemoteAccess | Select-Object VpnStatus, VpnS2SStatus, RoutingStatus
netstat -an | findstr "0.0.0.0:443"
```

Résultat attendu :
```
Name         Status  StartType
----         ------  ---------
RemoteAccess Running Automatic

VpnStatus    : Installed
VpnS2SStatus : Installed
RoutingStatus: Installed

TCP  0.0.0.0:443  0.0.0.0:0  LISTENING
```

### 2.9 Connexion VPN depuis SRV-SAINTCENERI

```powershell
# Créer la connexion
Add-VpnConnection -Name "MedSearch-VPN" -ServerAddress "20.82.143.72" `
    -TunnelType Sstp -EncryptionLevel Required `
    -AuthenticationMethod MSChapv2 -RememberCredential -Force

# Importer le certificat CA
Import-Certificate -FilePath "C:\MedSearch-CA.cer" `
    -CertStoreLocation "Cert:\LocalMachine\Root"

# Se connecter
rasdial "MedSearch-VPN" vpnuser MedSearch2024!
```

Résultat :
```
Connecting to MedSearch-VPN...
Verifying username and password...
Registering your computer on the network...
Successfully connected to MedSearch-VPN.
Command completed successfully.
```

Vérification :
```powershell
ipconfig | findstr "PPP"
```
```
PPP adapter MedSearch-VPN:
   IPv4 Address : 192.168.200.2
   Subnet Mask  : 255.255.255.255
```

Test de connectivité via VPN :
```powershell
ping 10.1.0.4
```
```
Reply from 10.1.0.4: bytes=32 time<1ms TTL=127
```

### 2.10 Ports ouverts sur Azure NSG SRV-CAEN

| Port | Protocole | Nom | Usage |
|------|-----------|-----|-------|
| 443 | TCP | Allow-SSTP-VPN | VPN SSTP |
| 3389 | TCP | RDP | Administration |
| 80 | TCP | Allow-HTTP | Sites IIS |
| 8080 | TCP | Allow-Dashboard | Dashboard |
| 8081 | TCP | Allow-API-8081 | API REST |

---

## 3. Option 2 — Remote Desktop Services (RDS)

### Pourquoi RDS

RDS permet aux employés de Saint-Cénéri d'accéder à un bureau Windows complet hébergé sur SRV-SAINTCENERI, avec accès à toutes les ressources du datacenter de Caen via le VNet Peering.

**Avantages pour MedSearch :**
- Données sensibles restent sur les serveurs (jamais sur le poste client)
- Aucune installation logicielle requise côté employé
- Accès via `mstsc.exe` natif Windows

### 3.1 Installation sur SRV-SAINTCENERI

```powershell
Install-WindowsFeature -Name RDS-RD-Server, RDS-Licensing -IncludeManagementTools
```

Résultat :
```
Success        : True
Restart Needed : Yes
Feature Result : Remote Desktop Session Host, Remote Desktop Licensing
```

### 3.2 Validation RDS

```powershell
Get-WindowsFeature -Name RDS-RD-Server, RDS-Licensing | Select-Object DisplayName, InstallState
```

```
DisplayName                  InstallState
-----------                  ------------
Remote Desktop Session Host  Installed
Remote Desktop Licensing     Installed
```

```powershell
# RDP autorisé : 0 = autorisé
(Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
# Résultat : 0
```

```powershell
Get-Service -Name TermService | Select-Object Name, Status, StartType
```
```
Name        Status  StartType
----        ------  ---------
TermService Running Manual
```

### 3.3 Connexion RDS

- **Depuis Windows :** `mstsc.exe` → adresse `20.238.18.250`
- **Credentials :** `medsearch\hugod1`
- **Port :** 3389 (ouvert sur NSG Azure)

### 3.4 Ports ouverts sur Azure NSG SRV-SAINTCENERI

| Port | Protocole | Nom | Usage |
|------|-----------|-----|-------|
| 3389 | TCP | RDP | Remote Desktop |
| 3343 | Any | Allow-Cluster-Heartbeat | Failover Cluster |
| 8082 | TCP | Allow-MiniAPI-8082 | Stats API |
| ICMPv4 | ICMP | Allow-ICMP | Ping inter-serveurs |

---

## 4. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| Port 443 SSTP non en LISTENING | RRAS mal configuré | Réinstallation propre avec `Install-RemoteAccess -VpnType Vpn` |
| Erreur 812 connexion VPN | Policy NPS manquante | Création manuelle `MedSearch-VPN-Policy` dans NPS GUI |
| Erreur 720 connexion VPN | Pool IP non configuré | `netsh ras ip add range` + `method=pool` |
| Certificat non approuvé | CA auto-signée | Déploiement CA entreprise MedSearch-CA + import sur clients |
| RDS installé mauvais serveur | Confusion sessions RDP | Désinstallation SRV-CAEN, réinstallation SRV-SAINTCENERI |
| Groupe RDP inexistant FR | Nom localisé | Utilisation nom anglais `Remote Desktop Users` |
