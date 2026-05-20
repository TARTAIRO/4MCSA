# Monitoring — Alertes et centralisation des logs

## 1. Objectifs

- Alertes automatiques CPU et RAM sur les hôtes Hyper-V
- Envoi d'email à l'administrateur IT en cas de dépassement de seuil
- Centralisation des logs de tous les serveurs sur SRV-CAEN
- Solution simple à maintenir pour un seul administrateur

---

## 2. Alertes CPU et RAM — Monitor-Alert.ps1

### Fonctionnement
Un script PowerShell tourne en arrière-plan en permanence (tâche planifiée SYSTEM au démarrage). Il vérifie toutes les 60 secondes :

| Métrique | Seuil d'alerte | Action |
|----------|---------------|--------|
| CPU | > 80% | Email + EventLog Warning (EventID 1001) |
| RAM | > 90% | Email + EventLog Warning (EventID 1002) |

### Installation de la tâche planifiée
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Monitor-Alert.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-Monitor" -Action $action -Trigger $trigger -Principal $principal -Force
```

### Résultat
```
TaskPath  TaskName          State
--------  --------          -----
\         MedSearch-Monitor Ready
```

### Vérification des alertes déclenchées
```powershell
Get-WinEvent -LogName Application -Source "MedSearch-Monitor" -MaxEvents 5
```

Exemple de log généré :
```
EventID : 1001
Level   : Warning
Message : CPU à 86% sur SRV-CAEN - 05/20/2026 22:30:30
Source  : MedSearch-Monitor
```

---

## 3. Centralisation des logs — Windows Event Forwarding (WEF)

### Architecture WEF

```
SRV-SAINTCENERI (Source)          SRV-CAEN (Collecteur)
+----------------------+           +----------------------+
| Windows Event Log    |  WinRM    | ForwardedEvents Log  |
| System (Warning+)    |---------> | Tous les events des  |
| Application (Error+) |  Port     | serveurs sources     |
| Security (Critical+) |  5985     |                      |
+----------------------+           +----------------------+
```

### Configuration du collecteur (SRV-CAEN)
```powershell
# Activer le service WEF
winrm quickconfig -quiet
wecutil qc -quiet

# Créer l'abonnement
wecutil cs "C:\WEF-Subscription.xml"
```

### Configuration de la source (SRV-SAINTCENERI)
```powershell
winrm quickconfig -quiet
net localgroup "Event Log Readers" "Network Service" /add

# Pointer vers le collecteur
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager"
New-Item -Path $regPath -Force
Set-ItemProperty -Path $regPath -Name "1" -Value "Server=http://10.1.0.4:5985/wsman/SubscriptionManager/WEC,Refresh=60"
```

### Vérification abonnement WEF
```powershell
wecutil gs MedSearch-Logs
```
```
Subscription Id: MedSearch-Logs
SubscriptionType: SourceInitiated
Enabled: true
ConfigurationMode: MinLatency
DeliveryMode: Push
LogFile: ForwardedEvents
```

---

## 4. Windows Admin Center

Windows Admin Center a été installé sur SRV-CAEN (port 443) pour fournir une interface graphique unifiée de monitoring :

```powershell
msiexec /i C:\WindowsAdminCenter.msi /qn SME_PORT=443 SSL_CERTIFICATE_OPTION=generate
```

Fonctionnalités disponibles :
- Vue CPU/RAM en temps réel
- Gestion des services Windows
- Event Viewer intégré
- Gestion des disques et réseau
- Connexion à tous les serveurs du domaine

---

## 5. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| WEF pas de logs reçus | Firewall bloquant WinRM | `Enable-PSRemoting -Force` sur source |
| Tâche planifiée non démarrée | Script en mémoire seulement | Sauvegarde dans fichier + ScheduledTask SYSTEM |
| WAC installation lente | MSI 45MB téléchargé | Attente ~10 min pour installation complète |
