# Remote Access — RRAS VPN et RDS

## 1. Objectif

L'administrateur unique de MedSearch doit pouvoir gérer l'infrastructure depuis n'importe quel endroit. Deux options complémentaires sont proposées :

| Option | Cas d'usage | Avantage |
|--------|-------------|----------|
| **RRAS VPN SSTP** | Accès réseau sécurisé complet | Transparent, port 443 |
| **RDS Session Host** | Bureau à distance Windows | Interface graphique complète |

---

## 2. Option 1 — RRAS VPN SSTP

### Pourquoi SSTP (Secure Socket Tunneling Protocol)
- Utilise le **port HTTPS 443** → passe tous les firewalls sans configuration
- **Aucune configuration côté client** autre qu'une connexion VPN Windows native
- Chiffrement SSL/TLS natif
- Compatible Windows 7/8/10/11 nativement

### Installation RRAS
```powershell
Install-WindowsFeature -Name Routing -IncludeManagementTools
Install-WindowsFeature -Name DirectAccess-VPN -IncludeManagementTools
```

Résultat :
```
Success : True
Feature Result : RAS Connection Manager Administration Kit, DirectAccess and VPN (RAS), Routing
```

### Configuration RRAS
```powershell
# Enregistrement dans le domaine
netsh ras add registeredserver

# Activation du service
Set-Service -Name RemoteAccess -StartupType Automatic
Start-Service -Name RemoteAccess
```

### Validation RRAS
```powershell
Get-RemoteAccess
```
```
VpnStatus    : Installed
VpnS2SStatus : Installed
RoutingStatus: Installed
```

```powershell
netsh ras show registeredserver
```
```
Remote Access Server : SRV-CAEN
Domain              : medsearch.local
```

### Création utilisateur VPN
```powershell
net user vpnuser MedSearch2024! /add /domain
net localgroup "Remote Desktop Users" vpnuser /add
```

### Connexion VPN depuis un poste client
```powershell
Add-VpnConnection -Name "MedSearch-VPN" -ServerAddress "20.82.143.72" -TunnelType Sstp -EncryptionLevel Required -AuthenticationMethod MSChapv2 -RememberCredential
```

### Ports ouverts sur Azure NSG
| Port | Protocol | Usage |
|------|----------|-------|
| 443 | TCP | VPN SSTP + Windows Admin Center |
| 1723 | TCP | PPTP (fallback) |

---

## 3. Option 2 — Remote Desktop Services (RDS)

### Architecture
RDS est installé sur **SRV-SAINTCENERI** pour offrir un bureau Windows à distance aux employés du site de Saint-Cénéri accédant aux ressources de Caen.

### Rôles installés
```powershell
Install-WindowsFeature -Name RDS-RD-Server, RDS-Licensing -IncludeManagementTools
```

Résultat :
```
Success : True
Restart Needed : Yes
Feature Result : Remote Desktop Session Host, Remote Desktop Licensing
```

### Validation RDS
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
# RDP autorisé (0 = autorisé, 1 = bloqué)
(Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
# Résultat : 0 (RDP autorisé)
```

### Connexion RDS
- **Depuis Windows :** `mstsc.exe` → adresse `20.238.18.250`
- **Depuis Mac/Linux :** Microsoft Remote Desktop
- **Credentials :** `medsearch\hugod1`

### Avantages de RDS pour MedSearch
- Les employés de Saint-Cénéri accèdent aux applications Caen via une session Windows
- Données sensibles restent sur SRV-CAEN (ne transitent pas sur le poste client)
- Aucune installation logicielle sur les postes employés

---

## 4. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| RDS installé sur le mauvais serveur | Confusion entre les 2 sessions RDP | Désinstallation sur SRV-CAEN, réinstallation sur SRV-SAINTCENERI |
| Erreur NPS Policy manquante | Policy CRP corrompue | Non bloquant pour démonstration, à recréer avec `Add-NpsRadiusClient` en production |
| Port 443 non ouvert | NSG Azure par défaut | Ajout règle Allow-SSTP-VPN |
| Groupe RDP local inexistant en français | Nom du groupe localisé | Utilisation de `Remote Desktop Users` (en anglais) |
