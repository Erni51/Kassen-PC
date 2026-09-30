# ============================================================
# Lieperts Tagesblatt-Druck v3  (Nachfolger von DRUCK-tagesblatt-v2.ps1)
#
# Holt https://www.lieperts.at/?lrv8_tagesblatt=1 und druckt es still auf dem
# Standarddrucker (Edge/Chrome -> PDF -> SumatraPDF), Rueckfall mshtml wie v2.
#
# Aufruf (macht die Aufgabenplanung):
#   powershell -NoProfile -ExecutionPolicy Bypass -File DRUCK-tagesblatt-v3.ps1 -Lauf abend
#   powershell -NoProfile -ExecutionPolicy Bypass -File DRUCK-tagesblatt-v3.ps1 -Lauf frueh
# Zum Ausprobieren (ignoriert den Wochentag):
#   ... -Lauf test               holt und druckt
#   ... -Lauf test -OhneDruck    holt nur und legt die Datei ins Archiv
#
# Zugang: Datei kassa-zugang.txt im selben Ordner, zwei Zeilen:
#   HEADER=X-Lieperts-Kassa-Key
#   SCHLUESSEL=<LRV8_KASSA_KEY aus der wp-config.php>
# Legt SETUP-schluessel-erzeugen.ps1 an.
# Diese Datei NIE ins Internet, nach GitHub oder in einen Chat stellen.
# ============================================================

param(
    [ValidateSet('abend', 'frueh', 'test')]
    [string]$Lauf = 'abend',
    [switch]$OhneDruck,
    [switch]$Immer          # Wochentag nicht pruefen (WordPress hat schon "drucken: ja" gesagt)
)

# --- Drucktage (gleich wie im Plugin, v30.990 / v31.015) --------------------
# 0 = Sonntag, 1 = Montag ... 6 = Samstag
$Abend = @(1, 2, 5, 6)   # Montag, Dienstag, Freitag, Samstag - 16:15
$Frueh = @(5, 6, 0)      # Freitag, Samstag, Sonntag          - 07:15
$Ruhe  = @(3, 4)         # Mittwoch, Donnerstag               - nichts

$Url    = 'https://www.lieperts.at/?lrv8_tagesblatt=1'
$Ordner = Split-Path -Parent $MyInvocation.MyCommand.Path
$Archiv = Join-Path $Ordner 'Archiv'
$Log    = Join-Path $Ordner 'tagesblatt.log'

function Schreib($text) {
    $zeile = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " [$Lauf] " + $text
    Add-Content -Path $Log -Value $zeile
    Write-Output $zeile
}

# --- 1. Ist heute ein Lauf vorgesehen? ---------------------------------------
$tag = [int](Get-Date).DayOfWeek
if (-not $Immer -and $Lauf -eq 'abend' -and $Abend -notcontains $tag) { Schreib 'Heute ist kein Lauf vorgesehen.'; exit 0 }
if (-not $Immer -and $Lauf -eq 'frueh' -and $Frueh -notcontains $tag) { Schreib 'Heute ist kein Lauf vorgesehen.'; exit 0 }

# --- 2. Zugang lesen ----------------------------------------------------------
$zugangDatei = Join-Path $Ordner 'kassa-zugang.txt'
$Header = ''; $Schluessel = ''
if (Test-Path $zugangDatei) {
    foreach ($z in Get-Content $zugangDatei) {
        if ($z -match '^\s*HEADER\s*=\s*(.+?)\s*$')     { $Header = $Matches[1] }
        if ($z -match '^\s*SCHLUESSEL\s*=\s*(.+?)\s*$') { $Schluessel = $Matches[1] }
    }
}
if (-not $Header) { $Header = 'X-Lieperts-Kassa-Key' }
if (-not $Schluessel) {
    Schreib 'FEHLER: kassa-zugang.txt fehlt oder ist unvollstaendig - nichts gedruckt.'
    exit 2
}

# --- 3. Blatt holen -----------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Hol($adresse) {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add($Header, $Schluessel)
    $wc.Headers.Add('User-Agent', 'Lieperts-Kassen-PC/3')
    return $wc.DownloadString($adresse)
}

# Die Drucktage bestimmt DIESES Skript ($Abend/$Frueh oben; Manuel 30.09.:
# Freitag und Samstag auch morgens). Das Plugin (v30.990) kennt frueh nur den
# Sonntag - &trotzdem=1 holt das Blatt trotzdem. Vor 11 Uhr kommt es mit Fruehstueck.
$Abruf = $Url + '&trotzdem=1'
try {
    $html = Hol $Abruf
} catch {
    Schreib ('BLATT NICHT ERHALTEN: ' + $_.Exception.Message)
    exit 1
}

# Webseite sagt: heute kein Druck - kein Fehler
if ($html -match 'Kein Druck heute') {
    $kurz = ($html -replace '\s+', ' ').Trim()
    Schreib ('Webseite: ' + $kurz.Substring(0, [Math]::Min(120, $kurz.Length)))
    exit 0
}

# Sicherung 1: ohne "Lieperts Tagesblatt" kein Druck
if (-not $html -or $html -notmatch 'Lieperts Tagesblatt') {
    Schreib 'BLATT NICHT ERHALTEN (Antwort ohne "Lieperts Tagesblatt") - nichts gedruckt.'
    exit 1
}

# Sicherung 2: an Ruhetagen nur, wenn wirklich jemand an- oder abreist
if ($Ruhe -contains $tag -and $html -match 'Heute reist niemand ab' -and $html -match 'Heute kommt niemand an') {
    Schreib 'Ruhetag ohne An- und Abreise - nichts gedruckt.'
    exit 0
}

# --- 4. Ablegen ---------------------------------------------------------------
if (-not (Test-Path $Archiv)) { New-Item -ItemType Directory -Path $Archiv | Out-Null }
$datei = Join-Path $Archiv ('tagesblatt-' + (Get-Date -Format 'yyyy-MM-dd') + '-' + $Lauf + '.html')
[System.IO.File]::WriteAllText($datei, $html, (New-Object System.Text.UTF8Encoding($true)))
Schreib ('Blatt erhalten, ' + $html.Length + ' Zeichen -> ' + $datei)

# Archiv klein halten: aelter als 90 Tage weg
Get-ChildItem $Archiv -Filter 'tagesblatt-*.html' |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } |
    Remove-Item -ErrorAction SilentlyContinue

if ($OhneDruck) { Schreib 'OhneDruck gesetzt - nicht gedruckt.'; exit 0 }

# --- 5. Drucken ---------------------------------------------------------------
# Weg 1 (still, ohne Dialog): Edge/Chrome macht ein PDF, SumatraPDF druckt es
#         auf den Standarddrucker. Braucht SumatraPDF (winget install SumatraPDF.SumatraPDF).
# Weg 2 (Rueckfall): mshtml wie v2 - zeigt unter Windows 11 einen Druckdialog.
# Weg 3 (Notnagel): Textfassung ueber Out-Printer.
function Finde($pfade) { $pfade | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1 }
$browser = Finde @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                   "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
                   "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                   "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")
$sumatra = Finde @("$env:LOCALAPPDATA\SumatraPDF\SumatraPDF.exe",
                   "$env:ProgramFiles\SumatraPDF\SumatraPDF.exe",
                   "${env:ProgramFiles(x86)}\SumatraPDF\SumatraPDF.exe")

if ($browser -and $sumatra) {
    try {
        $pdf = [IO.Path]::ChangeExtension($datei, '.pdf')
        if (Test-Path $pdf) { Remove-Item $pdf -Force }
        $prof = Join-Path $env:TEMP 'lieperts-druck-profil'
        $arg = @('--headless=new', '--disable-gpu', '--no-pdf-header-footer', "--user-data-dir=`"$prof`"",
                 "--print-to-pdf=`"$pdf`"", ('"file:///' + ($datei -replace '\\', '/') + '"'))
        $b = Start-Process -FilePath $browser -ArgumentList $arg -PassThru -WindowStyle Hidden
        if (-not $b.WaitForExit(90000)) { try { $b.Kill() } catch {} }
        if (-not (Test-Path $pdf) -or (Get-Item $pdf).Length -lt 1000) { throw 'PDF nicht erzeugt' }
        $d = Start-Process -FilePath $sumatra -ArgumentList @('-print-to-default', '-silent', "`"$pdf`"") -PassThru -WindowStyle Hidden
        if (-not $d.WaitForExit(120000)) { throw 'SumatraPDF nach 2 Minuten nicht fertig' }
        Schreib 'GEDRUCKT (PDF, still).'
        exit 0
    } catch {
        Schreib ('Stiller Druck gescheitert: ' + $_.Exception.Message + ' - Rueckfall mshtml.')
    }
} else {
    Schreib 'Hinweis: SumatraPDF fehlt - Druck ueber mshtml (mit Druckdialog). Abhilfe: winget install SumatraPDF.SumatraPDF'
}

try {
    $p = Start-Process -FilePath 'rundll32.exe' -ArgumentList ('mshtml.dll,PrintHTML "' + $datei + '"') -PassThru
    # Haengt der Druck (Dialog wartet auf Enter), nach 3 Minuten melden.
    if (-not $p.WaitForExit(180000)) {
        Schreib 'WARNUNG: Druck nach 3 Minuten nicht fertig - wartet ein Druckdialog am Bildschirm?'
        exit 4
    }
    if ($p.ExitCode -ne 0) { throw "rundll32 Rueckgabe $($p.ExitCode)" }
    Schreib 'GEDRUCKT (mshtml).'
} catch {
    Schreib ('mshtml-Druck gescheitert: ' + $_.Exception.Message + ' - Rueckfall Textfassung.')
    try {
        $text = Hol ($Abruf + '&format=text')
        $text | Out-Printer
        Schreib 'GEDRUCKT (Textfassung).'
    } catch {
        Schreib ('FEHLER: auch Textfassung nicht gedruckt: ' + $_.Exception.Message)
        exit 3
    }
}
exit 0
