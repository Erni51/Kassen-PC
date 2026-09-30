# ============================================================
# Rueckweg: nimmt die drei geplanten Aufgaben und den Kassa-Autostart wieder weg.
# Der Ordner C:\Lieperts (Protokolle, Archiv, Zugang) bleibt stehen.
# Als Administrator starten.
# ============================================================

foreach ($n in 'Lieperts Cron', 'Kassa frueh', 'Kassa abend', 'Kassa Minibar', 'Lieperts-Tagesblatt-1630', 'Lieperts-Tagesblatt-Frueh-0730') {
    schtasks /Delete /TN $n /F
}
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Kassa.lnk'
if (Test-Path $lnk) { Remove-Item $lnk; Write-Host 'Kassa-Autostart entfernt' }
Write-Host 'Energiespar-Einstellung zurueck (falls gewuenscht): powercfg /restoredefaultschemes'
