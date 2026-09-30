# Haelt das Einkaufs-Programm am Laufen: stuerzt es ab, startet es nach 10 Sekunden neu.
$Ziel = 'C:\Lieperts\einkauf'
Set-Location $Ziel
while ($true) {
    & "$Ziel\node\node.exe" "$Ziel\server.js" 2>> "$Ziel\einkauf-fehler.log"
    Add-Content "$Ziel\einkauf.log" ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  Programm beendet - Neustart in 10 s')
    Start-Sleep -Seconds 10
}
