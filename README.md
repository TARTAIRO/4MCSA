# MedSearch — Infrastructure Microsoft Windows Server 2022

> Projet d'infrastructure de base pour MedSearch, société de recherche médicale implantée sur deux sites (Caen et Saint-Cénéri-le-Gérei). Déployé sur Microsoft Azure avec Windows Server 2022 Datacenter.

**Auteurs :** Arthur Yang & Hugo Dutreuil  
**Date de livraison :** Mai 2026  
**Domaine :** `medsearch.local`

---

## Sommaire

- [Informations du projet](#informations-du-projet)
- [Accès à l'infrastructure](#accès-à-linfrastructure)
- [Serveurs déployés](#serveurs-déployés)
- [Services déployés](#services-déployés)
- [Structure des livrables](#structure-des-livrables)
- [Scripts — Usage rapide](#scripts--usage-rapide)
- [Commandes de vérification](#commandes-de-vérification)
- [Identifiants](#identifiants)

---

## Informations du projet

| Champ | Valeur |
|-------|--------|
| Client | MedSearch (Caen + Saint-Cénéri-le-Gérei) |
| Environnement | Microsoft Azure — Windows Server 2022 Datacenter |
| Domaine Active Directory | medsearch.local |
| Administrateurs | hugod1, arthuryd1 |
| Cluster | CLUSTER-MEDSEARCH (2 nœuds + Cloud Witness Azure) |
| Date de livraison | Mai 2026 |

---

## Accès à l'infrastructure

| Service | URL / Adresse | Port | Authentification |
|---------|--------------|------|-----------------|
| Dashboard monitoring | http://20.82.143.72:8080 | 8080 | Aucune |
| API REST monitoring | http://20.82.143.72:8081 | 8081 | Aucune |
| Site IIS ProjetAlpha | http://20.82.143.72 | 80 | Aucune |
| VPN SSTP | 20.82.143.72 | 443 | medsearch\vpnuser |
| RDP SRV-CAEN | 20.82.143.72 | 3389 | medsearch\hugod1 |
| RDP SRV-SAINTCENERI | 20.238.18.250 | 3389 | medsearch\hugod1 |
| DFS Namespace | \\medsearch.local\MedSearch | SMB | Compte domaine |

---

## Serveurs déployés

### SRV-CAEN — Datacenter principal (Caen)

| Propriété | Valeur |
|-----------|--------|
| IP privée | 10.1.0.4 |
| IP publique | 20.82.143.72 |
| VNet | SRV-CAEN-vnet (10.1.0.0/24) |
| Taille Azure | Standard_E2s_v3 |

**Rôles installés :**
- Active Directory Domain Services (DC principal)
- DNS Server
- IIS — Sites ProjetAlpha + Dashboard
- RRAS — VPN SSTP port 443
- Failover Clustering (nœud N1)
- Windows Event Forwarding (collecteur)
- CA d'entreprise MedSearch-CA
- DFS Namespace
- API REST :8081 + Dashboard :8080

---

### SRV-SAINTCENERI — Site distant (Saint-Cénéri)

| Propriété | Valeur |
|-----------|--------|
| IP privée | 10.0.0.4 |
| IP publique | 20.238.18.250 |
| VNet | MedSearch-VNet (10.0.0.0/16) |
| Taille Azure | Standard_D2s_v3 |

**Rôles installés :**
- Active Directory Domain Services (réplica)
- DNS Server (secondaire)
- Remote Desktop Services (Session Host + Licensing)
- Failover Clustering (nœud N2)
- DFS Target (réplication bidirectionnelle)
- MiniAPI Stats :8082
- Client VPN SSTP

---

## Services déployés

| Service | Statut | Description |
|---------|--------|-------------|
| Failover Cluster | ✅ Opérationnel | 2 nœuds Up + Cloud Witness Azure |
| VPN SSTP | ✅ Opérationnel | Port 443, certificat MedSearch-CA |
| CA MedSearch | ✅ Opérationnel | Enterprise Root CA, valide jusqu'en 2031 |
| IIS + Deploy-Site | ✅ Opérationnel | Script 3 paramètres, site ProjetAlpha actif |
| Dashboard web | ✅ Opérationnel | CPU/RAM/Events temps réel, auto-refresh 30s |
| RDS | ✅ Opérationnel | Session Host sur SRV-SAINTCENERI |
| DFS Namespace | ✅ Opérationnel | 2 cibles Online, réplication bidirectionnelle |
| VNet Peering | ✅ Opérationnel | Fully Synchronized, latence < 1ms |
| WEF | ✅ Configuré | RunTimeStatus Active, LastError 0 |
| Monitoring alertes | ✅ Opérationnel | CPU > 80% / RAM > 90% → EventLog + Email |

---

## Structure des livrables

```text
4MCSA/
├── README.md                              ← Ce fichier
├── docs/
│   ├── 01-justification-globale.md        ← Choix techniques et architecture
│   ├── 02-haute-disponibilite.md          ← Failover Cluster + Cloud Witness
│   ├── 03-iis-deploiement.md              ← IIS + script Deploy-Site.ps1
│   ├── 04-monitoring.md                   ← Alertes CPU/RAM + WEF + Dashboard
│   ├── 05-remote-access.md                ← RRAS VPN SSTP + CA + RDS
│   ├── 06-sites-communication.md          ← VNet Peering + VPN inter-sites
│   ├── 07-dashboard-special.md            ← Dashboard web temps réel
│   └── 08-dfs-replication.md              ← DFS Namespace + Réplication
├── scripts/
│   ├── Deploy-Site.ps1                    ← Déploiement IIS automatisé (3 params)
│   ├── Monitor-Alert.ps1                  ← Surveillance CPU/RAM + EventLog
│   ├── API-Dashboard.ps1                  ← API REST backend port 8081
│   ├── MiniAPI-Stats.ps1                  ← Stats SRV-SAINTCENERI port 8082
│   ├── Install-ScheduledTasks.ps1         ← Installation tâches planifiées
│   └── Install-MiniAPI-SaintCeneri.ps1    ← Installation MiniAPI sur SRV-SC
├── dashboard/
│   └── index.html                         ← Dashboard web infrastructure
├── configs/
│   └── WEF-Subscription.xml               ← Abonnement WEF centralisation logs
├── Capture/
│   ├── Cluster/                           ← Captures Failover Cluster + Witness
│   ├── IIS/                               ← Captures IIS + Deploy-Site
│   ├── Monitoring/                        ← Captures Dashboard + Alertes
│   ├── RDAS/                              ← Captures RRAS VPN + RDS
│   ├── VPN/                               ← Captures connexion VPN + CA
│   └── DFS/                               ← Captures DFS Namespace + Réplication
└── Shéma/
    └── MedSearch-Infrastructure.xml       ← Schéma draw.io infrastructure Azure
```

---

## Scripts — Usage rapide

### Déployer un nouveau site IIS
```powershell
.\Deploy-Site.ps1 -SiteName "ProjetBeta" -IPAddress "10.1.0.4" -ZipPath "C:\sites\projetbeta.zip"
```

### Installer toutes les tâches planifiées (première installation)
```powershell
.\Install-ScheduledTasks.ps1
```

### Installer la MiniAPI sur SRV-SAINTCENERI
```powershell
.\Install-MiniAPI-SaintCeneri.ps1
```

---

## Commandes de vérification

### Cluster
```powershell
Get-ClusterNode | Select-Object Name, State
Get-ClusterGroup | Select-Object Name, OwnerNode, State
```

### VPN SSTP
```powershell
Get-Service RemoteAccess | Select-Object Name, Status
netstat -an | findstr "0.0.0.0:443"
Get-RemoteAccess | Select-Object VpnStatus, RoutingStatus
```

### Certificat CA MedSearch
```powershell
Get-Service CertSvc | Select-Object Name, Status
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Issuer -like "*MedSearch*"} | Select-Object -First 1
Write-Host "Emetteur : $($cert.Issuer) | Valide jusqu'au : $($cert.NotAfter)"
```

### Dashboard et API
```powershell
Invoke-RestMethod -Uri "http://localhost:8081/api/stats"
Invoke-RestMethod -Uri "http://localhost:8081/api/ping"
```

### DFS
```powershell
Get-DfsnRootTarget -Path "\\medsearch.local\MedSearch"
```

### Monitoring
```powershell
Get-ScheduledTask | Where-Object {$_.TaskName -like "MedSearch*"} | Select-Object TaskName, State
Get-WinEvent -LogName Application -Source "MedSearch-Monitor" -MaxEvents 5
```

---

## Identifiants

> ⚠️ Ces identifiants sont uniquement valables pour l'environnement de démonstration.

| Compte | Mot de passe | Usage |
|--------|-------------|-------|
| medsearch\hugod1 | *(confidentiel)* | Administrateur principal |
| medsearch\arthuryd1 | *(confidentiel)* | Administrateur secondaire |
| medsearch\vpnuser | MedSearch2024! | Connexion VPN SSTP |

---

*Infrastructure déployée dans le cadre d'un projet 4MCSA étudiant —SUPINFO — 2026*