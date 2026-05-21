# Monitoring — Alertes CPU/RAM et Centralisation des logs

## 1. Objectif

- Alertes automatiques CPU et RAM sur les serveurs
- Ecriture dans l'EventLog Windows (EventID 1001/1002)
- Centralisation des logs via Windows Event Forwarding (WEF)
- Dashboard web temps reel accessible depuis n'importe ou

---

## 2. Alertes CPU et RAM — Monitor-Alert.ps1

### Fonctionnement

Un script PowerShell tourne en permanence via une tache planifiee SYSTEM.
Il verifie toutes les 60 secondes :

| Metrique | Seuil | Action |
|----------|-------|--------|
| CPU | > 80% | EventLog Warning EventID 1001 + Email |
| RAM | > 90% | EventLog Warning EventID 1002 + Email |

### Installation tache planifiee

```powershell
$action    = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\scripts\Monitor-Alert.ps1"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MedSearch-Monitor" -Action $action `
    -Trigger $trigger -Principal $principal -Force
```

Résultat :
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
Source  : MedSearch-Monitor
Message : CPU a 100% sur SRV-CAEN - 05/21/2026 11:12:40
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

### Configuration collecteur (SRV-CAEN)

```powershell
winrm quickconfig -quiet
wecutil qc -quiet
wecutil cs "C:\configs\WEF-Subscription.xml"
```

### Configuration source (SRV-SAINTCENERI)

```powershell
winrm quickconfig -quiet
net localgroup "Event Log Readers" "Network Service" /add

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager"
New-Item -Path $regPath -Force
Set-ItemProperty -Path $regPath -Name "1" `
    -Value "Server=http://10.1.0.4:5985/wsman/SubscriptionManager/WEC,Refresh=60"
```

### Vérification abonnement WEF

```powershell
wecutil gs MedSearch-Logs
```

```
Subscription Id   : MedSearch-Logs
SubscriptionType  : SourceInitiated
Enabled           : true
ConfigurationMode : MinLatency
DeliveryMode      : Push
LogFile           : ForwardedEvents
RunTimeStatus     : Active
LastError         : 0
```

### Limitation inter-VNet Azure

En environnement Azure avec 2 VNets distincts, l'authentification Kerberos
necessaire au WEF est bloquee entre les VNets.

**Justification :** En production sur un LAN physique (ou VPN site-a-site),
le WEF fonctionnerait normalement. L'abonnement est configure et actif
(RunTimeStatus: Active, LastError: 0). La limitation est propre a l'environnement
de demonstration Azure avec comptes etudiants.

---

## 4. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| WEF pas de logs recus | Kerberos bloque entre VNets Azure | Documente, RunTimeStatus Active confirme la config |
| Tache planifiee non demarree | Script en memoire seulement | Sauvegarde fichier + ScheduledTask SYSTEM |
| EventLog source inexistante | Premiere execution | `New-EventLog -Source MedSearch-Monitor` |
