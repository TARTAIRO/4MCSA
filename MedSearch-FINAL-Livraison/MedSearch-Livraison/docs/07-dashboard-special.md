# Dashboard Web — Requête spéciale IT

## 1. Objectif

L'administrateur IT souhaite une vue d'ensemble de l'infrastructure via une page web accessible depuis n'importe où, affichant :
- Carte des serveurs avec indicateurs visuels (ping, alertes)
- 5 derniers événements warning/critical de chaque serveur
- Bouton d'envoi email helpdesk pour chaque warning

---

## 2. Architecture technique

```
Navigateur
    |
    | HTTP :8080
    v
+------------------+         +------------------+
|   IIS Dashboard  |         |   API REST PS    |
|   Site :8080     |-------->|   :8081          |
|   index.html     |  fetch  |                  |
|   (HTML/JS/CSS)  |         | /api/ping        |
+------------------+         | /api/stats       |
                             | /api/events/caen |
                             | /api/events/sc   |
                             +------------------+
                                     |
                    +----------------+----------------+
                    |                                 |
             Windows EventLog                  ForwardedEvents
             (SRV-CAEN local)                  (WEF - SRV-SC)
```

---

## 3. Composants déployés

### 3.1 Site IIS Dashboard (port 8080)
```powershell
New-WebAppPool -Name "Dashboard"
New-Website -Name "Dashboard" -PhysicalPath "C:\Sites\Dashboard" -Port 8080 -ApplicationPool "Dashboard"
```

### 3.2 API REST PowerShell (port 8081)
Script `API-Dashboard.ps1` utilisant `System.Net.HttpListener` :

| Endpoint | Données retournées |
|----------|-------------------|
| `/api/ping` | Status online + latence des 2 serveurs |
| `/api/stats` | CPU%, RAM%, Uptime de SRV-CAEN |
| `/api/stats/srvsaintceneri` | Stats SRV-SAINTCENERI via remoting |
| `/api/events/srvcaen` | 5 derniers events Warning/Error/Critical |
| `/api/events/srvsaintceneri` | Events WEF ForwardedEvents |

### 3.3 Tâche planifiée API
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\API-Dashboard.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "MedSearch-API" -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest) -Force
```

---

## 4. Fonctionnalités du dashboard

### Carte de l'infrastructure
- Affichage visuel des 2 serveurs avec leurs rôles
- Indicateur ping en temps réel (vert = en ligne, rouge = hors ligne)
- Latence réseau affichée en ms
- Barres CPU et RAM en temps réel
- VNet Peering visualisé

### Événements en temps réel
- Lecture directe des Windows Event Logs
- Filtrage automatique sur Level <= 3 (Warning, Error, Critical)
- Source + EventID affiché
- Horodatage précis
- Code couleur : Warning (orange), Error/Critical (rouge), Info (vert)

### Bouton Email Helpdesk
- Clic sur "Email Helpdesk" → modal de confirmation
- Prévisualisation du mail (De, À, Sujet, Corps)
- Confirmation → notification toast "Email envoyé"

### Auto-refresh
- Actualisation automatique toutes les 30 secondes
- Barre de progression visuelle indiquant le prochain refresh

---

## 5. Données réelles affichées

### Test de l'API stats
```powershell
Invoke-RestMethod -Uri "http://localhost:8081/api/stats"
```
```
cpu      : 7
ramPct   : 31.1
ramFree  : 5.5
ramTotal : 7.9
uptime   : 00j 00h 05m
```

### Test de l'API ping
```powershell
Invoke-RestMethod -Uri "http://localhost:8081/api/ping"
```
```
latency  ip        name             online
-------  --        ----             ------
0        10.1.0.4  SRV-CAEN         True
1        10.0.0.4  SRV-SAINTCENERI  True
```

### Events réels capturés
```
EventID : 1001 | Warning  | CPU à 86% sur SRV-CAEN (MedSearch-Monitor)
EventID : 1001 | Warning  | CPU à 100% sur SRV-CAEN (MedSearch-Monitor)
EventID : 1801 | Error    | Secure Boot certificates (TPM-WMI)
EventID : 10154| Warning  | WinRM SPN creation failed (WinRM)
```

---

## 6. Accès au dashboard

- **URL :** `http://20.82.143.72:8080`
- **Accessible :** depuis n'importe quel navigateur
- **Authentification :** aucune (accès réseau suffisant)
- **Refresh :** automatique toutes les 30s

---

## 7. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| Emojis affichés `???` | Encodage UTF-8 sans BOM | `[System.Text.UTF8Encoding]::new($false)` |
| Accents cassés | Encodage PowerShell | Suppression des accents dans le HTML |
| API non accessible après redémarrage | Process PowerShell tué | Tâche planifiée SYSTEM au démarrage |
| JSON cassé par messages Event Log | Caractères spéciaux dans messages | `-replace '"',''` sur les messages |
| Stats SRV-SAINTCENERI inaccessibles | Authentification Kerberos bloquée inter-VNet | Affichage "Stats via RDS - accès local" avec note explicative |
| Port 8081 bloqué | NSG Azure | Règle Allow-API-8081 ajoutée |
| Dashboard Erreur events | Messages trop longs avec `\n` | Troncature à 120 caractères + nettoyage |
