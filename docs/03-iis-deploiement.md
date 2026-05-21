# IIS — Déploiement simplifié de sites web

## 1. Contexte

MedSearch déploie un site web pour chaque nouveau projet de recherche. Ces sites :
- Sont créés par un prestataire externe (livré sous forme de ZIP)
- Sont utilisés temporairement (durée du projet uniquement)
- Doivent être déployés facilement par **un seul administrateur IT**

### Contraintes du projet
- Pas d'installation système ou configuration lourde
- Seulement 3 paramètres : nom, IP, import du site
- Empreinte OS minimale sur les hôtes Hyper-V

---

## 2. Solution retenue

### Script Deploy-Site.ps1

Un script PowerShell de déploiement automatisé qui encapsule toutes les opérations IIS en **3 paramètres uniquement** :

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `-SiteName` | Nom du site et de l'AppPool | `ProjetAlpha` |
| `-IPAddress` | IP d'écoute du site | `10.1.0.4` |
| `-ZipPath` | Chemin vers le ZIP du site | `C:\sites\alpha.zip` |

### Usage
```powershell
.\Deploy-Site.ps1 -SiteName "ProjetAlpha" -IPAddress "10.1.0.4" -ZipPath "C:\Temp\ProjetAlpha.zip"
```

### Ce que fait le script automatiquement
1. Crée le dossier `C:\Sites\NomSite`
2. Extrait le ZIP dans ce dossier
3. Crée un **Application Pool** dédié (isolation)
4. Crée le **site IIS** avec les bindings IP:80
5. Démarre le site

---

## 3. Installation IIS

```powershell
Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-Scripting-Tools -IncludeManagementTools
```

Résultat :
```
Success : True
Restart Needed : No
Feature Result : Common HTTP Features, Default Document, HTTP Errors, Static Content,
                 HTTP Logging, Static Content Compression, Request Filtering,
                 IIS Management Console, IIS Management Scripts and Tools
```

---

## 4. Démonstration — Site ProjetAlpha

### Création du site test
```powershell
# Créer le contenu HTML
$html = "<html><body><h1>MedSearch - Projet Alpha</h1><p>Site de recherche en cours</p></body></html>"
New-Item -ItemType Directory -Path "C:\Temp\TestSite" -Force
$html | Out-File "C:\Temp\TestSite\index.html"
Compress-Archive -Path "C:\Temp\TestSite\*" -DestinationPath "C:\Temp\ProjetAlpha.zip" -Force

# Déployer
.\Deploy-Site.ps1 -SiteName "ProjetAlpha" -IPAddress "10.1.0.4" -ZipPath "C:\Temp\ProjetAlpha.zip"
```

### Résultat IIS
```
Name         : ProjetAlpha
ID           : 2
State        : Started
PhysicalPath : C:\Sites\ProjetAlpha
Bindings     : http 10.1.0.4:80:
```

### Accès navigateur
- URL : `http://20.82.143.72`
- Résultat : page "MedSearch - Projet Alpha" affichée ✅

---

## 5. Vérification des sites déployés

```powershell
Get-Website | Select-Object Name, State, PhysicalPath
```

```
Name             State   PhysicalPath
----             -----   ------------
Default Web Site Started %SystemDrive%\inetpub\wwwroot
ProjetAlpha      Started C:\Sites\ProjetAlpha
Dashboard        Started C:\Sites\Dashboard
```

---

## 6. Pour supprimer un site en fin de projet

```powershell
# Suppression propre d'un site IIS
Remove-Website -Name "ProjetAlpha"
Remove-WebAppPool -Name "ProjetAlpha"
Remove-Item -Path "C:\Sites\ProjetAlpha" -Recurse -Force
```

---

## 7. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| Site IIS non accessible depuis navigateur | Port 80 fermé sur NSG Azure | Ajout règle inbound Allow-HTTP port 80 |
| Site écoute sur IP privée seulement | Binding `10.1.0.4:80` | Le Default Web Site écoute sur `*:80` pour l'accès public |
| Firewall Windows bloquait port 80 | Règle absente | `New-NetFirewallRule -LocalPort 80` |
