<#
.SYNOPSIS
    Surveillance CPU et RAM avec alertes EventLog + Email
.DESCRIPTION
    Tourne en permanence via une tâche planifiée SYSTEM au démarrage.
    Vérifie toutes les 60 secondes CPU et RAM.
    Si seuil dépassé : écrit un Warning dans l'EventLog ET envoie un email.
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
    Seuils  : CPU > 80%, RAM > 90%
    EventID : 1001 (CPU), 1002 (RAM)
    Source  : MedSearch-Monitor
#>

# ── Configuration ────────────────────────────────────────────────────────────
$seuil_cpu   = 80           # Pourcentage CPU max avant alerte
$seuil_ram   = 90           # Pourcentage RAM max avant alerte
$intervalle  = 60           # Secondes entre chaque verification
$smtp_server = "localhost"
$email_admin = "admin@medsearch.local"
$email_from  = "monitoring@medsearch.local"

# ── Initialisation source EventLog ───────────────────────────────────────────
if (-not [System.Diagnostics.EventLog]::SourceExists("MedSearch-Monitor")) {
    New-EventLog -LogName Application -Source "MedSearch-Monitor"
}

Write-Host "MedSearch Monitor demarre — CPU > $seuil_cpu% | RAM > $seuil_ram% | Intervalle : ${intervalle}s" -ForegroundColor Green

# ── Boucle de surveillance ───────────────────────────────────────────────────
while ($true) {
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    # Mesure CPU
    $cpu     = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

    # Mesure RAM
    $os      = Get-CimInstance Win32_OperatingSystem
    $ram_pct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)

    # ── Alerte CPU ───────────────────────────────────────────────────────────
    if ($cpu -gt $seuil_cpu) {
        $msg = "CPU a $cpu% sur SRV-CAEN - $timestamp"

        Write-EventLog -LogName Application -Source "MedSearch-Monitor" `
            -EventId 1001 -EntryType Warning -Message $msg

        try {
            Send-MailMessage `
                -To      $email_admin `
                -From    $email_from `
                -Subject "[ALERTE CPU] SRV-CAEN - $cpu%" `
                -Body    "ALERTE PERFORMANCE`n`nServeur  : SRV-CAEN`nMetrique : CPU`nValeur   : $cpu%`nSeuil    : $seuil_cpu%`nDate     : $timestamp`n`n-- MedSearch Monitor" `
                -SmtpServer $smtp_server `
                -ErrorAction SilentlyContinue
        } catch {}

        Write-Host "[$timestamp] ALERTE CPU : $cpu%" -ForegroundColor Red
    }

    # ── Alerte RAM ───────────────────────────────────────────────────────────
    if ($ram_pct -gt $seuil_ram) {
        $msg = "RAM a $ram_pct% sur SRV-CAEN - $timestamp"

        Write-EventLog -LogName Application -Source "MedSearch-Monitor" `
            -EventId 1002 -EntryType Warning -Message $msg

        try {
            Send-MailMessage `
                -To      $email_admin `
                -From    $email_from `
                -Subject "[ALERTE RAM] SRV-CAEN - $ram_pct%" `
                -Body    "ALERTE PERFORMANCE`n`nServeur  : SRV-CAEN`nMetrique : RAM`nValeur   : $ram_pct%`nSeuil    : $seuil_ram%`nDate     : $timestamp`n`n-- MedSearch Monitor" `
                -SmtpServer $smtp_server `
                -ErrorAction SilentlyContinue
        } catch {}

        Write-Host "[$timestamp] ALERTE RAM : $ram_pct%" -ForegroundColor Red
    }

    Start-Sleep -Seconds $intervalle
}
