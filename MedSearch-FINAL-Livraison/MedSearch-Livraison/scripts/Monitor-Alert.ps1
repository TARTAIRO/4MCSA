<#
.SYNOPSIS
    Surveillance CPU et RAM avec alertes email et EventLog
.DESCRIPTION
    Tourne en permanence (tâche planifiée SYSTEM).
    Vérifie toutes les 60 secondes le CPU et la RAM.
    En cas de dépassement de seuil : écrit dans EventLog + envoie un email.
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
    Seuils  : CPU > 80%, RAM > 90%
    EventID : 1001 (CPU), 1002 (RAM)
#>

# Configuration
$seuil_cpu = 80          # Pourcentage CPU max
$seuil_ram = 90          # Pourcentage RAM max
$intervalle = 60         # Secondes entre chaque vérification
$smtp_server = "localhost"
$email_admin = "admin@medsearch.local"
$email_from  = "monitoring@medsearch.local"

# Créer la source d'événement si elle n'existe pas
if (-not [System.Diagnostics.EventLog]::SourceExists("MedSearch-Monitor")) {
    New-EventLog -LogName Application -Source "MedSearch-Monitor"
}

Write-Host "MedSearch Monitor démarré - Surveillance CPU/RAM active" -ForegroundColor Green
Write-Host "Seuils : CPU > $seuil_cpu% | RAM > $seuil_ram% | Intervalle : ${intervalle}s" -ForegroundColor Cyan

while ($true) {
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    # Mesure CPU
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

    # Mesure RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $ram_pct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)

    # Alerte CPU
    if ($cpu -gt $seuil_cpu) {
        $message = "CPU a $cpu% sur SRV-CAEN - $timestamp"

        # EventLog
        Write-EventLog -LogName Application -Source "MedSearch-Monitor" -EventId 1001 -EntryType Warning -Message $message

        # Email
        try {
            Send-MailMessage `
                -To $email_admin `
                -From $email_from `
                -Subject "[ALERTE CPU] SRV-CAEN - $cpu%" `
                -Body "ALERTE PERFORMANCE`n`nServeur : SRV-CAEN`nMetrique : CPU`nValeur : $cpu%`nSeuil : $seuil_cpu%`nDate : $timestamp`n`n-- MedSearch Monitor" `
                -SmtpServer $smtp_server `
                -ErrorAction SilentlyContinue
        } catch {}

        Write-Host "[$timestamp] ALERTE CPU : $cpu%" -ForegroundColor Red
    }

    # Alerte RAM
    if ($ram_pct -gt $seuil_ram) {
        $message = "RAM a $ram_pct% sur SRV-CAEN - $timestamp"

        # EventLog
        Write-EventLog -LogName Application -Source "MedSearch-Monitor" -EventId 1002 -EntryType Warning -Message $message

        # Email
        try {
            Send-MailMessage `
                -To $email_admin `
                -From $email_from `
                -Subject "[ALERTE RAM] SRV-CAEN - $ram_pct%" `
                -Body "ALERTE PERFORMANCE`n`nServeur : SRV-CAEN`nMetrique : RAM`nValeur : $ram_pct%`nSeuil : $seuil_ram%`nDate : $timestamp`n`n-- MedSearch Monitor" `
                -SmtpServer $smtp_server `
                -ErrorAction SilentlyContinue
        } catch {}

        Write-Host "[$timestamp] ALERTE RAM : $ram_pct%" -ForegroundColor Red
    }

    Start-Sleep -Seconds $intervalle
}
