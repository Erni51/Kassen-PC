# ============================================================
# Neuer Kassen-PC - alles in einem Durchgang einrichten
#
# Muss als Administrator laufen (Titelzeile "Administrator").
# Tut nur Dinge, die sich mit ENTFERNEN.ps1 wieder rueckgaengig machen lassen.
#
#   1. Ordner C:\Lieperts anlegen, Skripte hineinkopieren
#   2. Zugang fuer das Tagesblatt (kassa-zugang.txt) uebernehmen oder abfragen
#   3. Drei geplante Aufgaben anlegen:
#        Lieperts Cron                  alle 5 Minuten, wp-cron.php
#        Lieperts-Tagesblatt-1630       taeglich 16:30, -Lauf abend
#        Lieperts-Tagesblatt-Frueh-0730 taeglich 07:30, -Lauf frueh
#      (das Skript entscheidet selbst ueber den Wochentag)
#   4. Energiesparen aus - der PC darf nie einschlafen
#   5. Optional: Kassa (kassenGeist) beim Anmelden automatisch im Chrome oeffnen
#   6. Probelauf: Cron einmal, Tagesblatt holen (ohne Druck)
#
# Parameter:
#   -Sicherung D:\Kassen-PC-Sicherung   Ordner mit der Sicherung vom alten PC
#   -KassaUrl  http://192.168.178.200   Adresse der Kassa fuer den Autostart
#   -OhneAutostart                      Kassa-Autostart nicht anlegen
# ============================================================

param(
    [string]$Sicherung = '',
    [string]$KassaUrl = 'http://192.168.178.200',
    [switch]$OhneAutostart
)

$Ziel = 'C:\Lieperts' # ohne Leerzeichen lassen (wird in /TR ohne Anfuehrungszeichen verwendet)
$Quelle = Split-Path -Parent $MyInvocation.MyCommand.Path

function Schritt($t) { Write-Host ''; Write-Host "=== $t" -ForegroundColor Cyan }
function Gut($t)     { Write-Host "  OK  $t" -ForegroundColor Green }
function Achtung($t) { Write-Host "  !!  $t" -ForegroundColor Yellow }

# --- 0. Administrator? --------------------------------------------------------
$ich = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $ich.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Bitte als Administrator starten (Windows-Taste, "powershell" tippen, Strg+Umschalt+Enter).' -ForegroundColor Red
    exit 1
}
$Benutzer = $env:USERDOMAIN + '\' + $env:USERNAME
Write-Host "Richte ein fuer Benutzer: $Benutzer" -ForegroundColor Cyan
Write-Host '(Das muss der Benutzer sein, der an der Kassa immer angemeldet ist.)'

# --- 1. Ordner und Skripte ----------------------------------------------------
Schritt '1. Ordner C:\Lieperts'
New-Item -ItemType Directory -Force -Path $Ziel, (Join-Path $Ziel 'Archiv') | Out-Null
foreach ($f in 'DRUCK-tagesblatt-v3.ps1', 'CRON-lieperts-v1.ps1', 'PRUEFEN.ps1', 'ENTFERNEN.ps1') {
    Copy-Item (Join-Path $Quelle $f) $Ziel -Force
    Gut $f
}
if ($Sicherung -and (Test-Path $Sicherung)) {
    $alt = Join-Path $Ziel 'vom-alten-PC'
    New-Item -ItemType Directory -Force -Path $alt | Out-Null
    Copy-Item (Join-Path $Sicherung '*') $alt -Recurse -Force
    Gut "Sicherung vom alten PC nach $alt kopiert"
}

# --- 2. Zugang fuer das Tagesblatt --------------------------------------------
Schritt '2. Zugang fuer das Tagesblatt'
$zugang = Join-Path $Ziel 'kassa-zugang.txt'
if (-not (Test-Path $zugang)) {
    # a) liegt schon eine fertige kassa-zugang.txt in der Sicherung?
    if ($Sicherung -and (Test-Path (Join-Path $Sicherung 'kassa-zugang.txt'))) {
        Copy-Item (Join-Path $Sicherung 'kassa-zugang.txt') $zugang
    }
}
if (-not (Test-Path $zugang)) {
    # b) aus dem alten Skript v2 herauslesen
    $v2 = $null
    if ($Sicherung) { $v2 = Get-ChildItem $Sicherung -Recurse -Filter 'DRUCK-tagesblatt-v2.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($v2) {
        $text = Get-Content $v2.FullName -Raw
        $h = ''; $k = ''
        if ($text -match "Headers\.Add\(\s*['""]([^'""]+)['""]\s*,\s*['""]([^'""]+)['""]") { $h = $Matches[1]; $k = $Matches[2] }
        elseif ($text -match "@\{\s*['""]?([A-Za-z0-9_-]+)['""]?\s*=\s*['""]([^'""]+)['""]") { $h = $Matches[1]; $k = $Matches[2] }
        if ($h -and $k -and $k -notmatch '^\$') {
            Set-Content -Path $zugang -Value @("HEADER=$h", "SCHLUESSEL=$k") -Encoding ASCII
            Gut "Zugang aus dem alten Skript uebernommen (Kopfzeile: $h)"
        } else {
            Achtung 'Im alten Skript keinen Schluessel automatisch gefunden. Diese Zeilen stehen dort:'
            Select-String -Path $v2.FullName -Pattern 'Header|KEY|Schluessel|key' | ForEach-Object { Write-Host ('    ' + $_.Line.Trim()) }
        }
    }
}
if (-not (Test-Path $zugang)) {
    # c) von Hand eintippen
    Achtung 'Bitte Kopfzeilen-Namen und Schluessel eintippen (steht im alten Skript bzw. als LRV8_KASSA_KEY in der wp-config.php).'
    $h = Read-Host '  Name der Kopfzeile (HEADER)'
    $k = Read-Host '  Schluessel'
    if ($h -and $k) {
        Set-Content -Path $zugang -Value @("HEADER=$h", "SCHLUESSEL=$k") -Encoding ASCII
        Gut 'Zugang gespeichert'
    } else {
        Achtung 'Kein Zugang - das Tagesblatt wird erst gedruckt, wenn C:\Lieperts\kassa-zugang.txt existiert.'
    }
} else {
    Gut 'kassa-zugang.txt vorhanden'
}

# --- 3. Geplante Aufgaben -----------------------------------------------------
Schritt '3. Geplante Aufgaben'
$ps = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File'

schtasks /Create /F /TN 'Lieperts Cron' /SC MINUTE /MO 5 /RU SYSTEM /RL HIGHEST `
    /TR "$ps $Ziel\CRON-lieperts-v1.ps1" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Lieperts Cron (alle 5 Minuten, laeuft auch ohne Anmeldung)' } else { Achtung 'Lieperts Cron NICHT angelegt' }

# Druck laeuft ohne /RU als der angemeldete Benutzer (nur wenn angemeldet),
# damit er den Standarddrucker sieht und kein Kennwort gebraucht wird.
schtasks /Create /F /TN 'Lieperts-Tagesblatt-1630' /SC DAILY /ST 16:30 `
    /TR "$ps $Ziel\DRUCK-tagesblatt-v3.ps1 -Lauf abend" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Lieperts-Tagesblatt-1630 (Abendblatt Mo, Di, Fr, Sa)' } else { Achtung 'Abend-Aufgabe NICHT angelegt' }

schtasks /Create /F /TN 'Lieperts-Tagesblatt-Frueh-0730' /SC DAILY /ST 07:30 `
    /TR "$ps $Ziel\DRUCK-tagesblatt-v3.ps1 -Lauf frueh" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Lieperts-Tagesblatt-Frueh-0730 (Fruehblatt Fr, Sa, So)' } else { Achtung 'Frueh-Aufgabe NICHT angelegt' }

# Verpasste Laeufe nachholen (z. B. PC war um 16:30 kurz aus)
foreach ($n in 'Lieperts-Tagesblatt-1630', 'Lieperts-Tagesblatt-Frueh-0730', 'Lieperts Cron') {
    try {
        $t = Get-ScheduledTask -TaskName $n -ErrorAction Stop
        $t.Settings.StartWhenAvailable = $true
        $t.Settings.DisallowStartIfOnBatteries = $false
        $t.Settings.StopIfGoingOnBatteries = $false
        $t.Settings.ExecutionTimeLimit = 'PT10M'
        Set-ScheduledTask -InputObject $t | Out-Null
    } catch { }
}

# --- 4. Energiesparen aus -----------------------------------------------------
Schritt '4. Energiesparen aus'
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /hibernate off
Gut 'PC schlaeft nie ein (Bildschirm darf ausgehen)'

# --- 5. Kassa beim Anmelden oeffnen -------------------------------------------
if (-not $OhneAutostart) {
    Schritt '5. Kassa-Autostart'
    $chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") |
              Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($chrome) {
        $startup = [Environment]::GetFolderPath('Startup')
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startup 'Kassa kassenGeist.lnk'))
        $lnk.TargetPath = $chrome
        $lnk.Arguments = "--start-fullscreen --new-window $KassaUrl"
        $lnk.Save()
        Gut "Chrome oeffnet beim Anmelden $KassaUrl im Vollbild (F11 beendet Vollbild)"
    } else {
        Achtung 'Chrome nicht gefunden - erst Chrome installieren, dann EINRICHTEN.ps1 noch einmal starten.'
    }
}

# --- 6. Probelauf -------------------------------------------------------------
Schritt '6. Probelauf'
schtasks /Run /TN 'Lieperts Cron' | Out-Null
Start-Sleep -Seconds 15
if (Test-Path "$Ziel\cron-lieperts.log") { Get-Content "$Ziel\cron-lieperts.log" -Tail 1 } else { Achtung 'Cron-Protokoll noch leer - in 5 Minuten mit PRUEFEN.ps1 nachsehen' }

if (Test-Path $zugang) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Ziel\DRUCK-tagesblatt-v3.ps1" -Lauf test -OhneDruck
}

Write-Host ''
Write-Host 'Fertig. Druckprobe:  C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test' -ForegroundColor Cyan
Write-Host 'Kontrolle jederzeit: C:\Lieperts\PRUEFEN.ps1' -ForegroundColor Cyan
