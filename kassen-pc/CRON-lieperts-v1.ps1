# ============================================================
# Lieperts Cron-Starter v1
# Ruft alle 5 Minuten wp-cron.php auf.
#
# Warum: WordPress startet seine geplanten Aufgaben nur, wenn
# jemand die Seite oeffnet. Gemessen am 19.09.2026 um 21:47 Uhr
# waren der Reservierungs-Reminder und der Zimmer-ICS-Import
# 87 Minuten ueberfaellig. Dieser Aufruf startet sie zuverlaessig
# (Google-Kalender-Abgleich, Feratel-Zimmerimport, Erinnerungsmails).
#
# Die Aufgabe "Lieperts Cron" legt EINRICHTEN.ps1 an.
# ============================================================

$Url  = 'https://www.lieperts.at/wp-cron.php'
$Log  = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'cron-lieperts.log'
$Zeit = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 120
    Add-Content -Path $Log -Value "$Zeit OK $($r.StatusCode)"
}
catch {
    Add-Content -Path $Log -Value "$Zeit FEHLER $($_.Exception.Message)"
}

# Protokoll kurz halten: hoechstens die letzten 1000 Zeilen behalten
if (Test-Path $Log) {
    $zeilen = Get-Content $Log
    if ($zeilen.Count -gt 2000) { $zeilen[-1000..-1] | Set-Content $Log }
}
