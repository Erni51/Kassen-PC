# ============================================================
# Schluessel und Kassa-Zugang am neuen Kassen-PC anlegen (einmalig)
#
# 1. Erzeugt einen neuen Schluessel (48 Zeichen Zufall) und schreibt ihn
#    nach C:\Lieperts\kassa-zugang.txt (Kopfzeile X-Lieperts-Kassa-Key).
# 2. Legt die Zeile fuer die wp-config.php in die Zwischenablage.
# 3. Fragt die NEUE Kasse-URL (Quick-Login) ab und speichert sie in
#    C:\Lieperts\kassa-einstellungen.txt.
#
# Schluessel und Quick-Login-URL bleiben NUR auf diesem PC.
# Nie in einen Chat, eine Mail oder ein Dokument kopieren.
# ============================================================

param([switch]$NeuerSchluessel)

$Ziel = 'C:\Lieperts'
New-Item -ItemType Directory -Force -Path $Ziel | Out-Null
$zugang = Join-Path $Ziel 'kassa-zugang.txt'
$einst  = Join-Path $Ziel 'kassa-einstellungen.txt'

# --- 1. Schluessel ------------------------------------------------------------
if ((Test-Path $zugang) -and -not $NeuerSchluessel) {
    Write-Host 'kassa-zugang.txt gibt es schon - Schluessel bleibt. (Neu erzeugen: -NeuerSchluessel)' -ForegroundColor Yellow
    $key = ((Get-Content $zugang) -match '^SCHLUESSEL=' | Select-Object -First 1) -replace '^SCHLUESSEL=', ''
} else {
    $zeichen = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $bytes = New-Object byte[] 48
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $key = -join ($bytes | ForEach-Object { $zeichen[$_ % $zeichen.Length] })
    Set-Content -Path $zugang -Value @('HEADER=X-Lieperts-Kassa-Key', "SCHLUESSEL=$key") -Encoding ASCII
    Write-Host 'Neuer Schluessel erzeugt und in kassa-zugang.txt gespeichert.' -ForegroundColor Green
}

$zeile = "define('LRV8_KASSA_KEY', '$key');"
try { Set-Clipboard -Value $zeile; $inAblage = $true } catch { $inAblage = $false }
Write-Host ''
Write-Host 'Diese Zeile gehoert in die wp-config.php auf lieperts.at' -ForegroundColor Cyan
Write-Host '(eine bestehende Zeile LRV8_KASSA_KEY ERSETZEN, nicht doppelt eintragen):' -ForegroundColor Cyan
if ($inAblage) { Write-Host '  -> liegt in der Zwischenablage, dort mit Strg+V einfuegen.' -ForegroundColor Green }
else { Write-Host "  $zeile" }
Write-Host ''

# --- 2. Quick-Login -----------------------------------------------------------
$vorhanden = @{}
if (Test-Path $einst) {
    foreach ($z in Get-Content $einst) { if ($z -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $vorhanden[$Matches[1]] = $Matches[2] } }
}
Write-Host 'Neue Kasse-URL aus kassenGeist (VERWALTUNG -> Quick-Login -> NEUE KASSE-URL).' -ForegroundColor Cyan
Write-Host 'Einfuegen mit Strg+V, Enter. Leer lassen = bisherige behalten.'
$ql = Read-Host '  Kasse-URL'
if ($ql) { $vorhanden['QUICKLOGIN'] = $ql.Trim() }

$standard = [ordered]@{
    QUICKLOGIN = ''
    KASSA      = 'http://192.168.178.200/kasse'
    PREISFELD  = ''      # Feldname des Brutto-Preises im Artikelobjekt - nach "HELFER -Erkunden" eintragen
    NETTOFELD  = ''      # Feldname des Netto-Preises - ebenso
    SCHREIBEN  = 'nein'  # erst auf ja, wenn der Probelauf stimmt
}
$aus = foreach ($k in $standard.Keys) {
    $w = if ($vorhanden.ContainsKey($k)) { $vorhanden[$k] } else { $standard[$k] }
    "$k=$w"
}
Set-Content -Path $einst -Value $aus -Encoding UTF8
Write-Host ''
Write-Host "Gespeichert: $einst" -ForegroundColor Green
if (-not $vorhanden['QUICKLOGIN']) { Write-Host 'Achtung: noch keine Kasse-URL - Preise werden erst geschrieben, wenn sie drinsteht.' -ForegroundColor Yellow }
