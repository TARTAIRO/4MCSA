# MedSearch — Infrastructure Microsoft Windows Server 2022

## Informations du projet

| Champ | Valeur |
|-------|--------|
| Client | MedSearch (Caen + Saint-Cénéri-le-Gérei) |
| Environnement | Microsoft Azure (Windows Server 2022 Datacenter) |
| Domaine | medsearch.local |
| Administrateur | hugod1 |
| Date de livraison | Mai 2026 |

---

## Accès à l'infrastructure

| Service | Adresse | Port |
|---------|---------|------|
| Dashboard monitoring | http://20.82.143.72:8080 | 8080 |
| Site IIS ProjetAlpha | http://20.82.143.72 | 80 |
| RDP SRV-CAEN | 20.82.143.72 | 3389 |
| RDP SRV-SAINTCENERI | 20.238.18.250 | 3389 |
| VPN SSTP | 20.82.143.72 | 443 |
| API Monitoring | http://20.82.143.72:8081 | 8081 |

---

## Serveurs déployés

### SRV-CAEN (Datacenter principal - Caen)
- **IP privée :** 10.1.0.4
- **IP publique :** 20.82.143.72
- **Rôles :** AD DS, DNS, IIS, RRAS VPN, Failover Clustering, WEF Collecteur, Dashboard

### SRV-SAINTCENERI (Site distant - Saint-Cénéri)
- **IP privée :** 10.0.0.4
- **IP publique :** 20.238.18.250
- **Rôles :** AD DS (replica), RDS, Failover Clustering

---

## Structure des livrables

```
MedSearch-Livraison/
├── README.md                          ← Ce fichier
├── docs/
│   ├── 01-justification-globale.md    ← Choix techniques et architecture
│   ├── 02-haute-disponibilite.md      ← Hyper-V Cluster + S2D
│   ├── 03-iis-deploiement.md         ← IIS + script Deploy-Site.ps1
│   ├── 04-monitoring.md              ← Alertes + WEF + Dashboard
│   ├── 05-remote-access.md           ← RRAS VPN + RDS
│   ├── 06-sites-communication.md     ← VNet Peering + VPN SSTP
│   └── 07-dashboard-special.md       ← Requête spéciale dashboard web
├── scripts/
│   ├── Deploy-Site.ps1               ← Déploiement IIS automatisé
│   ├── Monitor-Alert.ps1             ← Alertes CPU/RAM
│   ├── API-Dashboard.ps1             ← API REST backend dashboard
│   └── MiniAPI-Stats.ps1             ← API stats SRV-SAINTCENERI
├── configs/
│   └── WEF-Subscription.xml          ← Abonnement WEF centralisation logs
└── dashboard/
    └── index.html                    ← Dashboard web infrastructure
```

---

## Scripts — Usage rapide

### Déployer un nouveau site IIS
```powershell
.\Deploy-Site.ps1 -SiteName "ProjetBeta" -IPAddress "10.1.0.4" -ZipPath "C:\sites\projetbeta.zip"
```

### Vérifier le monitoring
```powershell
Get-ScheduledTask -TaskName "MedSearch-Monitor"
Get-WinEvent -LogName Application -Source "MedSearch-Monitor" -MaxEvents 5
```

### Vérifier le cluster
```powershell
Get-Cluster
Get-ClusterNode
```
