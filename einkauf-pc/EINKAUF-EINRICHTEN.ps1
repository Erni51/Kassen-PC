# ============================================================
# Lieperts Einkauf (live) am Kassen-PC einrichten
#
# Als der Benutzer starten, der an der Kassa immer angemeldet ist, mit
# Administrator-Rechten (nur fuer die Firewall-Freigabe im WLAN).
# Rueckweg: EINKAUF-ENTFERNEN.ps1
#
#   1. Ordner C:\Lieperts\einkauf, Programm hineinkopieren
#   2. Node.js (tragbar, nur in diesem Ordner, von nodejs.org, Pruefsumme geprueft)
#   3. einstellungen.json mit eigenem Schluessel (nur hier gespeichert)
#   4. Firewall: Port 8787 im privaten Netz (Restaurant-WLAN)
#   5. Aufgabe "Lieperts Einkauf": startet beim Anmelden, startet neu, wenn es abstuerzt
#   6. Starten und den Handy-Link zeigen
# ============================================================

param([int]$Port = 8787)

$Ziel   = 'C:\Lieperts\einkauf'
$Quelle = Split-Path -Parent $MyInvocation.MyCommand.Path

function Schritt($t) { Write-Host ''; Write-Host "=== $t" -ForegroundColor Cyan }
function Gut($t)     { Write-Host "  OK  $t" -ForegroundColor Green }
function Achtung($t) { Write-Host "  !!  $t" -ForegroundColor Yellow }

$ich = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $ich.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Bitte als Administrator starten (Windows-Taste, "powershell" tippen, Strg+Umschalt+Enter).' -ForegroundColor Red
    exit 1
}
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$ProgressPreference = 'SilentlyContinue'

# --- 1. Programm ---------------------------------------------------------------
Schritt '1. Programm nach C:\Lieperts\einkauf'
New-Item -ItemType Directory -Force -Path $Ziel, "$Ziel\shops", "$Ziel\public", "$Ziel\erkundet" | Out-Null
# alte Instanz anhalten, damit die Dateien frei sind
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$Ziel\server.js*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
foreach ($f in 'server.js', 'chrome.js', 'inhalt.js', 'erkunden.js', 'EINKAUF-LAUF.ps1', 'EINKAUF-START.vbs', 'EINKAUF-ENTFERNEN.ps1') {
    Copy-Item (Join-Path $Quelle $f) $Ziel -Force; Gut $f
}
Copy-Item (Join-Path $Quelle 'public\index.html') "$Ziel\public\" -Force; Gut 'public\index.html'
Get-ChildItem (Join-Path $Quelle 'shops') -Filter *.js | ForEach-Object {
    $neu = Join-Path "$Ziel\shops" $_.Name
    # Einen Shop, den Claude am PC schon fertig eingerichtet hat, nicht ueberschreiben
    if ((Test-Path $neu) -and (Select-String -Path $neu -Pattern 'fertig:\s*true' -Quiet) -and
        -not (Select-String -Path $_.FullName -Pattern 'fertig:\s*true' -Quiet)) {
        Achtung "shops\$($_.Name) bleibt (am PC schon eingerichtet)"
    } else {
        Copy-Item $_.FullName $neu -Force; Gut "shops\$($_.Name)"
    }
}

# --- 2. Node.js ----------------------------------------------------------------
Schritt '2. Node.js'
$node = "$Ziel\node\node.exe"
if (Test-Path $node) {
    Gut ("vorhanden: " + (& $node -v))
} else {
    $basis = 'https://nodejs.org/dist/latest-v22.x'
    $summen = (Invoke-WebRequest "$basis/SHASUMS256.txt" -UseBasicParsing).Content -split "`n"
    $zeile = $summen | Where-Object { $_ -match 'node-v22\.[\d.]+-win-x64\.zip$' } | Select-Object -First 1
    if (-not $zeile) { Write-Host 'Node.js-Version nicht gefunden.' -ForegroundColor Red; exit 1 }
    $soll, $datei = ($zeile.Trim() -split '\s+')
    $zip = "$env:TEMP\$datei"
    Invoke-WebRequest "$basis/$datei" -OutFile $zip -UseBasicParsing
    $ist = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($ist -ne $soll.ToLower()) { Write-Host 'Pruefsumme von Node.js stimmt nicht - abgebrochen.' -ForegroundColor Red; exit 1 }
    Expand-Archive $zip "$env:TEMP\node-ausgepackt" -Force
    $innen = Get-ChildItem "$env:TEMP\node-ausgepackt" -Directory | Select-Object -First 1
    if (Test-Path "$Ziel\node") { Remove-Item "$Ziel\node" -Recurse -Force }
    Move-Item $innen.FullName "$Ziel\node"
    Remove-Item $zip, "$env:TEMP\node-ausgepackt" -Recurse -Force -ErrorAction SilentlyContinue
    Gut ("installiert: " + (& $node -v) + " (Pruefsumme stimmt)")
}

# --- 3. Einstellungen ----------------------------------------------------------
Schritt '3. Einstellungen'
$einst = "$Ziel\einstellungen.json"
if (Test-Path $einst) {
    Gut 'einstellungen.json vorhanden (Schluessel bleibt)'
} else {
    $chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $chrome) { Write-Host 'Chrome nicht gefunden.' -ForegroundColor Red; exit 1 }
    $zeichen = [char[]]'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 24; $rng.GetBytes($bytes)
    $schluessel = -join ($bytes | ForEach-Object { $zeichen[$_ % $zeichen.Length] })
    $e = [ordered]@{
        port = $Port; schluessel = $schluessel; chrome = $chrome
        profil = 'C:\Lieperts\chrome-einkauf'; chromePort = 9223
        shops = @('transgourmet'); protokoll = "$Ziel\einkauf.log"; still = $true
    }
    $e | ConvertTo-Json | Set-Content $einst -Encoding UTF8
    Gut "einstellungen.json angelegt (Chrome: $chrome)"
}
$E = Get-Content $einst -Raw | ConvertFrom-Json

# --- 4. Firewall ---------------------------------------------------------------
Schritt '4. Firewall (nur privates Netz)'
Get-NetFirewallRule -DisplayName 'Lieperts Einkauf' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'Lieperts Einkauf' -Direction Inbound -Protocol TCP -LocalPort $E.port `
    -Action Allow -Profile Private | Out-Null
Gut "Port $($E.port) im privaten Netz offen"
$netz = Get-NetConnectionProfile | Select-Object -First 1
if ($netz.NetworkCategory -ne 'Private') {
    Achtung "Das Netz '$($netz.Name)' ist als '$($netz.NetworkCategory)' eingestuft - fuer das Handy im WLAN auf 'Privat' stellen:"
    Achtung "  Set-NetConnectionProfile -InterfaceIndex $($netz.InterfaceIndex) -NetworkCategory Private"
}

# --- 5. Aufgabe ----------------------------------------------------------------
Schritt '5. Aufgabe "Lieperts Einkauf" (beim Anmelden)'
schtasks /Create /F /TN 'Lieperts Einkauf' /SC ONLOGON /RL LIMITED `
    /TR "wscript.exe `"$Ziel\EINKAUF-START.vbs`"" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'angelegt' } else { Achtung 'NICHT angelegt' }

# --- 6. Starten ----------------------------------------------------------------
Schritt '6. Starten'
Start-Process wscript.exe -ArgumentList "`"$Ziel\EINKAUF-START.vbs`""
Start-Sleep -Seconds 6
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' } |
       Select-Object -First 1).IPAddress
try {
    $r = Invoke-WebRequest "http://127.0.0.1:$($E.port)/api/status" -Headers @{ 'X-Schluessel' = $E.schluessel } -UseBasicParsing -TimeoutSec 20
    Gut 'laeuft'
} catch { Achtung ('antwortet noch nicht - Protokoll: ' + "$Ziel\einkauf.log") }

$link = "http://$($ip):$($E.port)/?k=$($E.schluessel)"
Set-Content "$Ziel\handy-link.txt" $link -Encoding UTF8
Write-Host ''
Write-Host 'Diesen Link EINMAL am Handy (im Restaurant-WLAN) oeffnen und als Lesezeichen speichern:' -ForegroundColor Cyan
Write-Host "  $link" -ForegroundColor White
Write-Host '(steht auch in C:\Lieperts\einkauf\handy-link.txt - nicht weitergeben)' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Jetzt im Einkaufs-Chrome (eigenes Fenster) einmal bei Transgourmet anmelden,' -ForegroundColor Cyan
Write-Host '"Angemeldet bleiben" anhaken. Chrome darf das Passwort speichern.' -ForegroundColor Cyan
