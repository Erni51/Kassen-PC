# ============================================================
# Neuer Kassen-PC - alles in einem Durchgang einrichten
# (nach UEBERGABE-Kassen-PC-NEU-Einrichtung-30-09-2026)
#
# Als der Benutzer starten, der an der Kassa immer angemeldet ist (z. B. "Kassa"),
# mit Administrator-Rechten. Alles laesst sich mit ENTFERNEN.ps1 zuruecknehmen.
#
#   1. Ordner C:\Lieperts, Skripte hineinkopieren
#   2. Schluessel und Quick-Login (SETUP-schluessel-erzeugen.ps1)
#   3. Geplante Aufgaben:
#        Kassa frueh    taeglich 07:15  HELFER -Lauf frueh  (Preise, dann Tagesblatt)
#        Kassa abend    taeglich 16:15  HELFER -Lauf abend  (Preise, dann Tagesblatt)
#        Lieperts Cron  alle 5 Minuten  wp-cron.php
#   4. Energie: nie schlafen, Bildschirm nach 15 Min. aus; Nutzungszeit 06-24 Uhr
#   5. Standarddrucker nicht mehr automatisch umstellen
#   6. Kassa im Chrome-Kiosk beim Anmelden
#   7. Probelauf (ohne Druck, ohne Schreiben in die Kassa)
# ============================================================

param(
    [string]$KassaUrl = 'http://192.168.178.200/kasse/menu',
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
Write-Host "Richte ein fuer Benutzer: $env:USERNAME" -ForegroundColor Cyan

# --- 1. Ordner und Skripte ----------------------------------------------------
Schritt '1. Ordner C:\Lieperts'
New-Item -ItemType Directory -Force -Path $Ziel, (Join-Path $Ziel 'Archiv') | Out-Null
foreach ($f in 'HELFER-kasse-zimmerpreise.ps1', 'DRUCK-tagesblatt-v3.ps1', 'CRON-lieperts-v1.ps1',
               'SETUP-schluessel-erzeugen.ps1', 'PRUEFEN.ps1', 'ENTFERNEN.ps1') {
    Copy-Item (Join-Path $Quelle $f) $Ziel -Force
    Gut $f
}

# --- 2. Schluessel und Quick-Login --------------------------------------------
Schritt '2. Schluessel und Quick-Login'
& (Join-Path $Ziel 'SETUP-schluessel-erzeugen.ps1')

# --- 3. Geplante Aufgaben -----------------------------------------------------
Schritt '3. Geplante Aufgaben'
$ps = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File'

# alte Namen aus der ersten Fassung wegraeumen
foreach ($alt in 'Lieperts-Tagesblatt-1630', 'Lieperts-Tagesblatt-Frueh-0730') {
    schtasks /Query /TN $alt 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { schtasks /Delete /TN $alt /F | Out-Null; Gut "alte Aufgabe $alt entfernt" }
}

schtasks /Create /F /TN 'Lieperts Cron' /SC MINUTE /MO 5 /RU SYSTEM /RL HIGHEST `
    /TR "$ps $Ziel\CRON-lieperts-v1.ps1" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Lieperts Cron (alle 5 Minuten, auch ohne Anmeldung)' } else { Achtung 'Lieperts Cron NICHT angelegt' }

# Ohne /RU: laeuft als dieser Benutzer, solange er angemeldet ist (automatische
# Anmeldung ist an). So sieht das Skript den Standarddrucker, und es braucht kein Kennwort.
schtasks /Create /F /TN 'Kassa frueh' /SC DAILY /ST 07:15 `
    /TR "$ps $Ziel\HELFER-kasse-zimmerpreise.ps1 -Lauf frueh" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Kassa frueh (07:15)' } else { Achtung 'Kassa frueh NICHT angelegt' }

schtasks /Create /F /TN 'Kassa abend' /SC DAILY /ST 16:15 `
    /TR "$ps $Ziel\HELFER-kasse-zimmerpreise.ps1 -Lauf abend" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Kassa abend (16:15)' } else { Achtung 'Kassa abend NICHT angelegt' }

# Minibar/Preise zwischendurch: alle 30 Minuten, ohne Druck
schtasks /Create /F /TN 'Kassa Minibar' /SC MINUTE /MO 30 `
    /TR "$ps $Ziel\HELFER-kasse-zimmerpreise.ps1 -Lauf abend -OhneDruck" | Out-Null
if ($LASTEXITCODE -eq 0) { Gut 'Kassa Minibar (alle 30 Minuten, ohne Druck)' } else { Achtung 'Kassa Minibar NICHT angelegt' }

foreach ($n in 'Kassa frueh', 'Kassa abend', 'Kassa Minibar', 'Lieperts Cron') {
    try {
        $t = Get-ScheduledTask -TaskName $n -ErrorAction Stop
        $t.Settings.StartWhenAvailable = $true          # verpassten Lauf nachholen
        $t.Settings.DisallowStartIfOnBatteries = $false
        $t.Settings.StopIfGoingOnBatteries = $false
        $t.Settings.ExecutionTimeLimit = 'PT30M'        # Helfer wiederholt selbst 3x im Abstand von 5 Min.
        Set-ScheduledTask -InputObject $t | Out-Null
    } catch { }
}

# --- 4. Energie und Nutzungszeit ----------------------------------------------
Schritt '4. Energie und Updates'
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 15   # Bildschirm nach 15 Min. aus, Beruehren weckt ihn
powercfg /change disk-timeout-ac 0
powercfg /hibernate off
# USB nie schlafen legen (Touch des Bildschirms haengt an USB)
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
# nach dem Aufwachen kein Kennwort verlangen
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
powercfg /setactive SCHEME_CURRENT
# Netzwerkkarte nicht abschalten (sonst laeuft der Cron nicht)
Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object { Disable-NetAdapterPowerManagement -Name $_.Name -NoRestart -ErrorAction SilentlyContinue }
Gut 'PC schlaeft nie, Bildschirm nach 15 Min. aus, USB und Netzwerk bleiben wach, kein Kennwort beim Aufwachen'
# Windows erlaubt hoechstens 18 Stunden Nutzungszeit: 06:00 bis 24:00 -> Neustarts nur nachts
$wu = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
New-Item -Path $wu -Force | Out-Null
Set-ItemProperty -Path $wu -Name ActiveHoursStart -Value 6 -Type DWord
Set-ItemProperty -Path $wu -Name ActiveHoursEnd -Value 0 -Type DWord
Set-ItemProperty -Path $wu -Name SmartActiveHoursState -Value 0 -Type DWord
Gut 'Nutzungszeit 06:00-24:00 (Update-Neustarts nur nachts)'

# --- 5. Standarddrucker festhalten --------------------------------------------
Schritt '5. Standarddrucker'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name LegacyDefaultPrinterMode -Value 1 -Type DWord
Gut 'Windows stellt den Standarddrucker nicht mehr selbst um'
$std = Get-CimInstance Win32_Printer | Where-Object Default
if ($std) { Gut "Standarddrucker jetzt: $($std.Name)" } else { Achtung 'Noch kein Standarddrucker - Drucker einrichten und als Standard setzen.' }

# Chrome druckt sonst in Graustufen und ohne Hintergruende: per Richtlinie Farbe,
# Hintergrundgrafiken an, keine Kopf-/Fusszeilen (gilt fuer den Tagesblatt-Direktdruck).
$pol = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
New-Item -Path 'HKLM:\SOFTWARE\Policies\Google' -Force | Out-Null
New-Item -Path $pol -Force | Out-Null
Set-ItemProperty -Path $pol -Name PrintingColorDefault -Value 'color' -Type String
Set-ItemProperty -Path $pol -Name PrintingBackgroundGraphicsDefault -Value 'enabled' -Type String
Set-ItemProperty -Path $pol -Name PrintHeaderFooter -Value 0 -Type DWord
Gut 'Chrome druckt in Farbe, mit Hintergruenden, ohne Kopf-/Fusszeile'

# --- 6. Kassa im Kiosk --------------------------------------------------------
if (-not $OhneAutostart) {
    Schritt '6. Kassa beim Anmelden'
    $chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") |
              Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($chrome) {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($ort in [Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('Desktop')) {
            $lnk = $shell.CreateShortcut((Join-Path $ort 'Kassa.lnk'))
            $lnk.TargetPath = $chrome
            # eigenes Profil fuer die Kassa, damit das normale Chrome (Claude-Erweiterung) daneben laufen kann
            $lnk.Arguments = "--user-data-dir=`"$Ziel\chrome-kassa`" --kiosk --app=$KassaUrl"
            $lnk.Save()
        }
        Gut "Kassa-Verknuepfung auf dem Desktop und im Autostart ($KassaUrl, Kiosk; beenden mit Alt+F4)"
        # normales Chrome (Claude-Erweiterung, Portale) beim Anmelden minimiert starten
        $n = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Chrome Claude.lnk'))
        $n.TargetPath = $chrome; $n.Arguments = '--restore-last-session'; $n.WindowStyle = 7; $n.Save()
        Gut 'Normales Chrome startet beim Anmelden minimiert (fuer die Claude-Erweiterung)'
    } else {
        Achtung 'Chrome nicht gefunden - erst Chrome installieren, dann EINRICHTEN.ps1 noch einmal starten.'
    }
}

# --- 7. Probelauf -------------------------------------------------------------
Schritt '7. Probelauf'
schtasks /Run /TN 'Lieperts Cron' | Out-Null
& (Join-Path $Ziel 'HELFER-kasse-zimmerpreise.ps1') -Lauf abend -OhneDruck
Start-Sleep -Seconds 5
if (Test-Path "$Ziel\cron-lieperts.log") { Get-Content "$Ziel\cron-lieperts.log" -Tail 1 }

Write-Host ''
Write-Host 'Fertig. Naechste Schritte:' -ForegroundColor Cyan
Write-Host '  C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test       Druckprobe'
Write-Host '  C:\Lieperts\HELFER-kasse-zimmerpreise.ps1 -Erkunden   Kassa-Artikel lesen (nur lesen)'
Write-Host '  C:\Lieperts\PRUEFEN.ps1                               Kontrolle'
