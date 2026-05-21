<#
.SYNOPSIS
    Mini API REST locale sur SRV-SAINTCENERI — expose CPU et RAM
.DESCRIPTION
    Ecoute sur le port 8082 et retourne les stats CPU/RAM en JSON.
    Appelee par API-Dashboard.ps1 sur SRV-CAEN via http://10.0.0.4:8082
.NOTES
    Auteur  : Equipe Infrastructure MedSearch
    Version : 1.0
    Requis  : Windows Server 2022, droits SYSTEM
    Lancer  : PowerShell -ExecutionPolicy Bypass -File C:\scripts\MiniAPI-Stats.ps1
    Port    : 8082 (NSG Azure + Firewall Windows requis)
#>

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:8082/")
$listener.Start()

Write-Host "MiniAPI SRV-SAINTCENERI demarree sur port 8082..." -ForegroundColor Green

while ($listener.IsListening) {
    $context  = $listener.GetContext()
    $response = $context.Response
    $response.Headers.Add("Access-Control-Allow-Origin", "*")
    $response.ContentType = "application/json"

    # Mesures CPU et RAM locales
    $cpu    = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $os     = Get-CimInstance Win32_OperatingSystem
    $ramPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    $uptime = ((Get-Date) - $os.LastBootUpTime).ToString("dd\j\ hh\h\ mm\m")

    $json = "{`"cpu`":$cpu,`"ramPct`":$ramPct,`"uptime`":`"$uptime`"}"

    $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.ContentLength64 = $buf.Length
    $response.OutputStream.Write($buf, 0, $buf.Length)
    $response.OutputStream.Close()
}
