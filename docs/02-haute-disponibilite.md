# Haute disponibilité — Hyper-V Cluster MedSearch

## 1. Solution proposée

### Choix : Windows Server 2022 Hyper-V + Failover Clustering

La solution de virtualisation retenue est **Microsoft Hyper-V** avec **Windows Server Failover Cluster (WSFC)**, pour les raisons suivantes :

| Critère | Hyper-V | VMware vSphere |
|---------|---------|---------------|
| Coût licence | Inclus WS2022 | Très élevé |
| Intégration Windows | Native | Tierce |
| Gestion AD/GPO | Native | Complexe |
| Compétences requises | Microsoft (déjà maîtrisé) | Spécifique |
| Support WSUS/WDS | Natif | Via plugin |

---

## 2. Architecture cluster proposée (production)

```
+------------------+     Heartbeat      +------------------+
|   NODE1-CAEN     |<==================>|   NODE2-CAEN     |
|   Hyper-V Host   |                    |   Hyper-V Host   |
|                  |                    |                  |
|   VMs actives    |   Live Migration   |   VMs standby    |
+------------------+                    +------------------+
         |                                       |
         +---------------+  +--------------------+
                         |  |
                 +--------+--------+
                 |  Storage Spaces  |
                 |  Direct (S2D)    |
                 |  CSV Volume      |
                 +------------------+
                         |
              +----------+----------+
              | Cloud Witness Azure  |
              | (Quorum)            |
              +---------------------+
```

---

## 3. Réseaux séparés (3 réseaux)

La haute disponibilité nécessite l'isolation des flux réseau :

| Réseau | Plage IP | Usage | Justification |
|--------|----------|-------|---------------|
| Management | 192.168.10.0/24 | Administration Hyper-V | Isoler le trafic admin |
| Storage | 192.168.20.0/24 | iSCSI / SMB Direct | Performance I/O maximale |
| VM Traffic | 192.168.30.0/24 | Trafic machines virtuelles | Pas d'impact sur storage |



---

## 4. Stockage — Storage Spaces Direct (S2D)

### Pourquoi S2D
- **Natif Windows Server 2022** → pas de SAN externe coûteux
- Redondance automatique des données (mirroring sur 2+ nœuds)
- En cas de panne disque : reconstruction automatique
- Volume CSV (Cluster Shared Volume) accessible par tous les nœuds

### Configuration S2D
```powershell
# Activation S2D sur le cluster
Enable-ClusterS2D

# Création du pool de stockage
New-StoragePool -FriendlyName "MedSearch-Pool" -StorageSubSystemFriendlyName "*Cluster*" -PhysicalDisks (Get-PhysicalDisk -CanPool $true)

# Création du volume CSV
New-Volume -StoragePoolFriendlyName "MedSearch-Pool" -FriendlyName "CSV-MedSearch" -FileSystem CSVFS_ReFS -Size 500GB
```

---

## 5. Clustering des hôtes

### Fonctionnement du Failover Cluster
- **Heartbeat** entre les nœuds toutes les secondes
- Si un nœud ne répond plus → **bascule automatique en < 30 secondes**
- **Live Migration** : déplacement de VMs sans interruption de service
- **Quorum Cloud Witness** : tiebreaker via Azure Storage (évite le split-brain)

### Commandes de déploiement production
```powershell
# Installation des rôles
Install-WindowsFeature -Name Failover-Clustering, Hyper-V -IncludeManagementTools -Restart

# Validation du cluster (obligatoire avant création)
Test-Cluster -Node NODE1-CAEN, NODE2-CAEN -Include "Storage", "Network", "System Configuration"

# Création du cluster
New-Cluster -Name CLUSTER-MEDSEARCH -Node NODE1-CAEN, NODE2-CAEN -StaticAddress 192.168.10.100

# Activation S2D
Enable-ClusterS2D

# Cloud Witness (quorum Azure)
Set-ClusterQuorum -CloudWitness -AccountName "medsearchquorum" -AccessKey "XXXX"
```

---

## 6. Implémentation démontrée (Azure)

### Ce qui a été réalisé
```powershell
# Installation Failover Clustering sur SRV-CAEN
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
Install-WindowsFeature -Name Hyper-V-Tools, RSAT-Clustering

# Validation du cluster
Test-Cluster -Node "SRV-CAEN" -Include "System Configuration","Network","Inventory"
# Résultat : ClusterValidation.htm généré (398KB)

# Création du cluster avec les 2 nœuds
New-Cluster -Name "CLUSTER-MEDSEARCH" -Node "SRV-CAEN","SRV-SAINTCENERI" -StaticAddress "10.1.0.10" -NoStorage
```

### Installation sur SRV-SAINTCENERI
```
Success : True
Restart Needed : No
Feature Result : Failover Clustering, Hyper-V GUI Management Tools
```

---

## 7. IIS sur Hyper-V — Conteneurs Windows (sans installation OS)

### Problématique
Le projet demande un déploiement IIS **sans installation système**, **minimal OS footprint**.

### Solution : Windows Server Core + Containers

En production Hyper-V, la solution retenue est :
- **Windows Server 2022 Core** (pas d'interface graphique → 4GB RAM minimum vs 8GB)
- **Containers Windows** via Docker pour les sites IIS temporaires
- Chaque projet = 1 container IIS → destruction après le projet

### Avantages
| Critère | VM classique | Container IIS |
|---------|-------------|---------------|
| Temps de déploiement | 30-60 min | < 1 min |
| Consommation RAM | 4-8 GB | 256-512 MB |
| OS footprint | Complet | Minimal |
| Isolation | Complète | Partielle |

### Commande de déploiement container
```powershell
# Sur l'hôte Hyper-V
docker run -d -p 80:80 --name ProjetAlpha mcr.microsoft.com/windows/servercore/iis
```

> En environnement de démonstration Azure (sans Hyper-V physique), le déploiement IIS est réalisé via le script `Deploy-Site.ps1` directement sur SRV-CAEN.

---

## 8. Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| VMs sur VNets différents | Création automatique Azure | VNet Peering bidirectionnel |
| Ping inter-VNet bloqué | Firewall Windows + NSG Azure | Règles ICMPv4 + NSG Allow-ICMP |
| Remoting PowerShell Access Denied | Authentification Kerberos entre VNets | API REST locale sur chaque serveur |
| Cluster sur VNets différents | Contrainte Azure gratuit | Cluster créé avec `-NoStorage` |
