# Nimmt "Lieperts Einkauf" zurueck: Aufgabe, Firewall-Freigabe, laufendes Programm.
# Der Ordner C:\Lieperts\einkauf (mit Schluessel und Protokoll) und das Chrome-Profil
# C:\Lieperts\chrome-einkauf (mit den Shop-Anmeldungen) bleiben - loeschen macht Manuel selbst.
schtasks /Delete /TN 'Lieperts Einkauf' /F 2>$null | Out-Null
Get-NetFirewallRule -DisplayName 'Lieperts Einkauf' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*C:\Lieperts\einkauf\*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host 'Lieperts Einkauf angehalten und abgemeldet. Ordner und Chrome-Profil sind noch da.' -ForegroundColor Green
