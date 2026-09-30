# ============================================================
# Kassen-PC: Kontrolle - laeuft alles?
# Zeigt die drei Aufgaben, die letzten Protokollzeilen und den Standarddrucker.
# ============================================================

$Ziel = 'C:\Lieperts'

Write-Host '=== Geplante Aufgaben' -ForegroundColor Cyan
foreach ($n in 'Lieperts Cron', 'Lieperts-Tagesblatt-1630', 'Lieperts-Tagesblatt-Frueh-0730') {
    try {
        $i = Get-ScheduledTaskInfo -TaskName $n -ErrorAction Stop
        $farbe = if ($i.LastTaskResult -eq 0 -or $i.LastTaskResult -eq 267011) { 'Green' } else { 'Yellow' }
        Write-Host ("{0,-32} zuletzt {1}  Ergebnis {2}  naechster {3}" -f $n, $i.LastRunTime, $i.LastTaskResult, $i.NextRunTime) -ForegroundColor $farbe
    } catch {
        Write-Host "$n FEHLT" -ForegroundColor Red
    }
}
Write-Host '(Ergebnis 0 = gut; 267011 = noch nie gelaufen)'

Write-Host ''
Write-Host '=== Cron (soll alle 5 Minuten "OK 200" zeigen)' -ForegroundColor Cyan
if (Test-Path "$Ziel\cron-lieperts.log") { Get-Content "$Ziel\cron-lieperts.log" -Tail 3 } else { Write-Host 'noch kein Protokoll' }

Write-Host ''
Write-Host '=== Tagesblatt' -ForegroundColor Cyan
if (Test-Path "$Ziel\tagesblatt.log") { Get-Content "$Ziel\tagesblatt.log" -Tail 6 } else { Write-Host 'noch kein Protokoll' }
if (-not (Test-Path "$Ziel\kassa-zugang.txt")) { Write-Host 'kassa-zugang.txt FEHLT - es wird nichts gedruckt!' -ForegroundColor Red }

Write-Host ''
Write-Host '=== Drucker' -ForegroundColor Cyan
Get-CimInstance Win32_Printer | Sort-Object Default -Descending |
    ForEach-Object { '{0} {1}' -f $(if ($_.Default) { '[STANDARD]' } else { '          ' }), $_.Name }
