# DFS — Namespace et Réplication inter-sites

## 1. Objectif

Mettre en place un espace de partage de fichiers unifié accessible depuis les
deux sites (Caen et Saint-Cénéri) avec réplication automatique bidirectionnelle.

| Besoin | Solution |
|--------|----------|
| Accès fichiers unifié | DFS Namespace `\\medsearch.local\MedSearch` |
| Réplication automatique | DFS Replication (DFSR) bidirectionnel |
| Haute disponibilité fichiers | 2 cibles (SRV-CAEN + SRV-SAINTCENERI) |

---

## 2. Installation

Sur les **2 serveurs** :

```powershell
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools
```

Résultat :
```
Success : True
Feature Result : DFS Namespaces, DFS Replication, DFS Management Tools
```

---

## 3. Configuration du Namespace DFS

### 3.1 Création du partage sur SRV-CAEN

```powershell
New-Item -ItemType Directory -Path "C:\DFS-MedSearch" -Force
New-SmbShare -Name "MedSearch-DFS" -Path "C:\DFS-MedSearch" -FullAccess "Everyone"
```

### 3.2 Création du namespace de domaine

```powershell
New-DfsnRoot -Path "\\medsearch.local\MedSearch" `
    -TargetPath "\\SRV-CAEN\MedSearch-DFS" `
    -Type DomainV2 `
    -EnableSiteCosting $true
```

Résultat :
```
Path                        Type      Properties   State
----                        ----      ----------   -----
\\medsearch.local\MedSearch Domain V2 Site Costing Online
```

### 3.3 Création du partage sur SRV-SAINTCENERI

```powershell
New-Item -ItemType Directory -Path "C:\DFS-MedSearch" -Force
New-SmbShare -Name "MedSearch-DFS" -Path "C:\DFS-MedSearch" -FullAccess "Everyone"
```

### 3.4 Ajout de la 2ème cible

```powershell
New-DfsnRootTarget -Path "\\medsearch.local\MedSearch" `
    -TargetPath "\\SRV-SAINTCENERI\MedSearch-DFS"
```

### 3.5 Vérification des 2 cibles

```powershell
Get-DfsnRootTarget -Path "\\medsearch.local\MedSearch"
```

```
Path                        TargetPath                                       State
----                        ----------                                       -----
\\medsearch.local\MedSearch \\SRV-CAEN.medsearch.local\MedSearch-DFS        Online
\\medsearch.local\MedSearch \\SRV-SAINTCENERI.medsearch.local\MedSearch-DFS Online
```

---

## 4. Configuration de la Réplication DFS (DFSR)

### 4.1 Création du groupe de réplication

```powershell
New-DfsReplicationGroup -GroupName "MedSearch-Replication"
Add-DfsrMember -GroupName "MedSearch-Replication" -ComputerName "SRV-CAEN"
Add-DfsrMember -GroupName "MedSearch-Replication" -ComputerName "SRV-SAINTCENERI"
New-DfsReplicatedFolder -GroupName "MedSearch-Replication" -FolderName "MedSearch-Data"
```

### 4.2 Configuration des chemins locaux

```powershell
# SRV-CAEN = membre primaire (source initiale)
Set-DfsrMembership -GroupName "MedSearch-Replication" -FolderName "MedSearch-Data" `
    -ComputerName "SRV-CAEN" -ContentPath "C:\DFS-MedSearch" -PrimaryMember $true -Force

# SRV-SAINTCENERI = membre secondaire
Set-DfsrMembership -GroupName "MedSearch-Replication" -FolderName "MedSearch-Data" `
    -ComputerName "SRV-SAINTCENERI" -ContentPath "C:\DFS-MedSearch" -Force
```

### 4.3 Connexion de réplication bidirectionnelle

```powershell
Add-DfsrConnection -GroupName "MedSearch-Replication" `
    -SourceComputerName "SRV-CAEN" `
    -DestinationComputerName "SRV-SAINTCENERI"
```

Résultat :
```
GroupName               : MedSearch-Replication
SourceComputerName      : SRV-CAEN
DestinationComputerName : SRV-SAINTCENERI
Enabled                 : True
RdcEnabled              : True    (compression delta)

GroupName               : MedSearch-Replication
SourceComputerName      : SRV-SAINTCENERI
DestinationComputerName : SRV-CAEN
Enabled                 : True
RdcEnabled              : True
```

---

## 5. Test de réplication

### Test CAEN → SAINTCENERI

Sur **SRV-CAEN** :

```powershell
"Fichier test DFS - $(Get-Date) - Cree sur SRV-CAEN" | Out-File "C:\DFS-MedSearch\test-replication.txt"
```

Apres 30-60 secondes, vérification sur **SRV-SAINTCENERI** :

```powershell
Get-Content "C:\DFS-MedSearch\test-replication.txt"
```

Résultat :
```
Fichier test DFS - 05/21/2026 11:22:29 - Cree sur SRV-CAEN
```

### Accès via le namespace unifié

```powershell
Get-ChildItem "\\medsearch.local\MedSearch\"
```

```
Mode    LastWriteTime     Name
----    -------------     ----
-a----  21/05/2026 11:22  test-replication.txt
```

---

## 6. Avantages pour MedSearch

| Avantage | Description |
|----------|-------------|
| Accès unifié | `\\medsearch.local\MedSearch` depuis les 2 sites |
| Réplication auto | Fichiers synchronisés en < 60 secondes |
| Haute disponibilité | Si SRV-CAEN tombe, SRV-SAINTCENERI prend le relais |
| Compatible futur | Prêt pour ajout de nouveaux sites |
| Delta compression | RDC activé = seules les modifications sont transférées |

---

## 7. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| `New-DfsnRootTarget` erreur object exists | Cible déjà créée automatiquement | Ignoré, vérification avec `Get-DfsnRootTarget` |
| Service DFS non démarré | Premier démarrage | `Restart-Service -Name Dfs` |
| Réplication lente | Latence inter-VNet | Normal, synchronisation en 30-60s |
