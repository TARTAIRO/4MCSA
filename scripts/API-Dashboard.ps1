<#
.SYNOPSIS
    API REST backend pour le Dashboard MedSearch
.DESCRIPTION
    Expose des endpoints HTTP sur le port 8081 :
    /api/ping                    - Status ping des 2 serveurs
    /api/stats                   - CPU/RAM/Uptime de SRV-CAEN
    /api/stats/srvsaintceneri    - CPU/RAM de SRV-SAINTCENERI via MiniAPI
    /api/events/srvcaen          - 5 derniers events Warning/Error/Critical
    /api/events/srvsaintceneri   - Events WEF ou fallback local
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 2.0
    Requis  : Windows Server 2022, droits SYSTEM
    Lancer  : PowerShell -ExecutionPolicy Bypass -File C:\scripts\API-Dashboard.ps1
#>

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:8081/")
$listener.Start()

Write-Host "API MedSearch demarree sur port 8081..." -ForegroundColor Green

while ($listener.IsListening) {
    $context  = $listener.GetContext()
    $request  = $context.Request
    $response = $context.Response
    $response.Headers.Add("Access-Control-Allow-Origin", "*")
    $response.ContentType = "application/json"
    $path = $request.Url.LocalPath

    # ── /api/ping ───────────────────────────────────────────────────────────
    if ($path -eq "/api/ping") {
        $r1 = Test-Connection -ComputerName 10.1.0.4 -Count 1 -Quiet -ErrorAction SilentlyContinue
        $l1 = if ($r1) { (Test-Connection -ComputerName 10.1.0.4 -Count 1 -ErrorAction SilentlyContinue).ResponseTime } else { 0 }
        $r2 = Test-Connection -ComputerName 10.0.0.4 -Count 1 -Quiet -ErrorAction SilentlyContinue
        $l2 = if ($r2) { (Test-Connection -ComputerName 10.0.0.4 -Count 1 -ErrorAction SilentlyContinue).ResponseTime } else { 0 }
        $json = "[{`"name`":`"SRV-CAEN`",`"ip`":`"10.1.0.4`",`"online`":$($r1.ToString().ToLower()),`"latency`":$l1}," +
                "{`"name`":`"SRV-SAINTCENERI`",`"ip`":`"10.0.0.4`",`"online`":$($r2.ToString().ToLower()),`"latency`":$l2}]"
    }

    # ── /api/stats (SRV-CAEN local) ─────────────────────────────────────────
    elseif ($path -eq "/api/stats") {
        $cpu    = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os     = Get-CimInstance Win32_OperatingSystem
        $ramPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
        $uptime = ((Get-Date) - $os.LastBootUpTime).ToString("dd\j\ hh\h\ mm\m")
        $json   = "{`"cpu`":$cpu,`"ramPct`":$ramPct,`"uptime`":`"$uptime`"}"
    }

    # ── /api/stats/srvsaintceneri (via MiniAPI port 8082) ───────────────────
    elseif ($path -eq "/api/stats/srvsaintceneri") {
        try {
            $r    = Invoke-RestMethod -Uri "http://10.0.0.4:8082" -TimeoutSec 5 -ErrorAction Stop
            $json = "{`"cpu`":$($r.cpu),`"ramPct`":$($r.ramPct)}"
        } catch {
            $json = "{`"cpu`":0,`"ramPct`":0}"
        }
    }

    # ── /api/events/srvcaen ─────────────────────────────────────────────────
    elseif ($path -eq "/api/events/srvcaen") {
        $evts = Get-WinEvent -LogName "System","Application" -MaxEvents 100 -ErrorAction SilentlyContinue |
                Where-Object { $_.Level -le 3 } |
                Select-Object -First 5
        if ($evts) {
            $arr  = $evts | ForEach-Object {
                $msg = $_.Message.Substring(0,[Math]::Min(120,$_.Message.Length)) -replace '"','' -replace '\r\n',' ' -replace '\n',' '
                $lvl = switch($_.Level){1{"Critical"}2{"Error"}3{"Warning"}default{"Info"}}
                "{`"id`":$($_.Id),`"level`":`"$lvl`",`"message`":`"$msg`",`"time`":`"$($_.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss'))`",`"source`":`"$($_.ProviderName)`"}"
            }
            $json = "[" + ($arr -join ",") + "]"
        } else { $json = "[]" }
    }

    # ── /api/events/srvsaintceneri ──────────────────────────────────────────
    elseif ($path -eq "/api/events/srvsaintceneri") {
        # Essaie d'abord les ForwardedEvents (WEF)
        $evts = Get-WinEvent -LogName "ForwardedEvents" -MaxEvents 5 -ErrorAction SilentlyContinue
        # Fallback : events locaux si WEF vide (limitation inter-VNet Azure)
        if (-not $evts) {
            $evts = Get-WinEvent -LogName "System","Application" -MaxEvents 100 -ErrorAction SilentlyContinue |
                    Where-Object { $_.Level -le 3 } |
                    Select-Object -First 5
        }
        if ($evts) {
            $arr  = $evts | ForEach-Object {
                $msg = $_.Message.Substring(0,[Math]::Min(120,$_.Message.Length)) -replace '"','' -replace '\r\n',' ' -replace '\n',' '
                $lvl = switch($_.Level){1{"Critical"}2{"Error"}3{"Warning"}default{"Info"}}
                "{`"id`":$($_.Id),`"level`":`"$lvl`",`"message`":`"$msg`",`"time`":`"$($_.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss'))`",`"source`":`"$($_.ProviderName)`"}"
            }
            $json = "[" + ($arr -join ",") + "]"
        } else {
            $json = "[{`"id`":0,`"level`":`"Info`",`"message`":`"Aucun evenement WEF recu`",`"time`":`"$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')`",`"source`":`"WEF`"}]"
        }
    }

    # ── 404 ─────────────────────────────────────────────────────────────────
    else {
        $json = "{`"error`":`"endpoint not found`"}"
        $response.StatusCode = 404
    }

    $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.ContentLength64 = $buf.Length
    $response.OutputStream.Write($buf, 0, $buf.Length)
    $response.OutputStream.Close()
}
