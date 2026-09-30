# ============================================================
# HELFER Kassa: Zimmerpreise in die Kassa + Tagesblatt drucken
#
# Ein Skript, zwei Aufgaben ("Kassa frueh" 07:15, "Kassa abend" 16:15):
#   1. Tagesdaten von lieperts.at holen
#      (GET /wp-json/lieperts/v1/kassa-tagesdaten, Kopfzeile X-Lieperts-Kassa-Key)
#   2. Ueber den Quick-Login in der Kassa anmelden
#   3. Je Zimmer den Betrag in den festen Artikel schreiben
#      (POST /kasse/api/Product/<id>?limit=15000 mit dem VOLLSTAENDIGEN Artikelobjekt)
#   4. Jeden Artikel zuruecklesen und pruefen
#   5. Tagesblatt drucken, wenn WordPress "drucken" sagt
#   6. Eine Zeile je Schritt ins Protokoll C:\Lieperts\kassa-helfer.log
#
# Aufrufe:
#   HELFER-kasse-zimmerpreise.ps1 -Lauf frueh|abend    normaler Lauf
#   HELFER-kasse-zimmerpreise.ps1 -Erkunden            NUR LESEN: holt die 6 Artikel
#        als JSON nach C:\Lieperts\erkundet\ und zeigt die Zahlenfelder -
#        daraus PREISFELD und NETTOFELD in kassa-einstellungen.txt eintragen
#   HELFER-kasse-zimmerpreise.ps1 -Lauf abend -OhneDruck
#
# Solange in kassa-einstellungen.txt SCHREIBEN=nein steht (Vorgabe), wird
# NICHTS in die Kassa geschrieben - das Protokoll zeigt nur, was es taete.
#
# Grenzen (Uebergabe 30.09.2026, Abschnitt 5) - NICHT lockern:
#   nur die festen Artikel-IDs, nie 0, nie 179, hoechstens 5000 EUR,
#   gesperrte Zeitraeume ueberspringen, keine Bons/Umsaetze/Rechnungen,
#   nach jedem Schreiben zuruecklesen.
# ============================================================

param(
    [ValidateSet('frueh', 'abend')]
    [string]$Lauf = 'abend',
    [switch]$Erkunden,
    [switch]$Rohdaten,      # zeigt die rohe Antwort der Tagesdaten (nur lesen)
    [switch]$OhneDruck
)

$Ordner = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log    = Join-Path $Ordner 'kassa-helfer.log'
$TagesdatenUrl = 'https://www.lieperts.at/wp-json/lieperts/v1/kassa-tagesdaten'

# --- feste Werte (Uebergabe, Abschnitt 7) -------------------------------------
$Artikel = [ordered]@{
    'Salbei'   = '6a8cad5a1ee83eff191160a7'
    'Muskat'   = '6a8cad671ee83eff191160b4'
    'Pfeffer'  = '6a8cad701ee83eff191160bd'
    'Rosmarin' = '6a8cad8c1ee83eff191160c6'
}
$Abgaben = [ordered]@{
    'Naechtigungsabgabe'   = '623ecdf4c169040354fd6864'
    'Infrastrukturbeitrag' = '695629a5805b8a541599ffbb'
}
# Die 12 Kassa-Artikel der Gruppe "ZIMMER TEST" (je Zimmer: Zimmer, Naechtigungsabgabe,
# Infrastrukturbeitrag) - gemessen 30.09.2026 aus /wp-json/lieperts/v1/kassa-tagesdaten.
# NUR diese Kennungen werden je beschrieben.
$Erlaubt = @(
    '6a8cad5a1ee83eff191160a7', '6a8e174f1ee83eff19118b64', '6a8e174f1ee83eff19118b6c',   # Salbei
    '6a8cad671ee83eff191160b4', '6a8e174f1ee83eff19118b74', '6a8e174f1ee83eff19118b7c',   # Muskat
    '6a8cad701ee83eff191160bd', '6a8e17501ee83eff19118b84', '6a8e17501ee83eff19118b8c',   # Pfeffer
    '6a8cad8c1ee83eff191160c6', '6a8e17501ee83eff19118b94', '6a8e17501ee83eff19118b9c'    # Rosmarin
)
$Obergrenze = 5000
$Platzhalter = 179
$SperrMuster = 'Eigenbelegung|Wartung|Sperre|gesperrt|Storno|storniert|cancel|closed|blocked'
$Versuche = 3; $Pause = 300   # bei Netzfehler: 3 Versuche im Abstand von 5 Minuten

function Schreib($text) {
    $zeile = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " [$script:Marke] " + $text
    Add-Content -Path $Log -Value $zeile -Encoding UTF8
    Write-Output $zeile
}

function Lies-Datei($pfad) {
    $h = @{}
    if (Test-Path $pfad) {
        foreach ($z in Get-Content $pfad) {
            if ($z -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*(#.*)?$') { $h[$Matches[1]] = $Matches[2] }
        }
    }
    return $h
}

function Mit-Wiederholung([scriptblock]$tu, $was) {
    for ($i = 1; $i -le $Versuche; $i++) {
        try { return & $tu }
        catch {
            Schreib ("$was - Versuch $i von $Versuche gescheitert: " + $_.Exception.Message)
            if ($i -lt $Versuche) { Start-Sleep -Seconds $Pause }
        }
    }
    return $null
}

$script:Marke = $Lauf
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zugang = Lies-Datei (Join-Path $Ordner 'kassa-zugang.txt')
$einst  = Lies-Datei (Join-Path $Ordner 'kassa-einstellungen.txt')
$Kassa  = if ($einst['KASSA']) { $einst['KASSA'].TrimEnd('/') } else { 'http://192.168.178.200/kasse' }

# --- Kassa-Anmeldung ----------------------------------------------------------
$script:Sitzung = $null
function Kassa-Anmelden {
    if (-not $einst['QUICKLOGIN']) { throw 'QUICKLOGIN fehlt in kassa-einstellungen.txt (SETUP-schluessel-erzeugen.ps1)' }
    $null = Invoke-WebRequest -Uri $einst['QUICKLOGIN'] -UseBasicParsing -SessionVariable s -TimeoutSec 30
    $script:Sitzung = $s
}

function Artikel-Holen($id) {
    $r = Invoke-WebRequest -Uri "$Kassa/api/Product/$id" -UseBasicParsing -WebSession $script:Sitzung -TimeoutSec 30
    $text = [string]$r.Content
    if ($text.TrimStart().StartsWith('<')) { throw "Artikel ${id}: Kassa liefert HTML statt Daten (Anmeldung abgelaufen?)" }
    return $text
}

# --- Erkunden: nur lesen ------------------------------------------------------
if ($Erkunden) {
    $script:Marke = 'erkunden'
    try { Kassa-Anmelden } catch { Schreib ('Anmeldung gescheitert: ' + $_.Exception.Message); exit 1 }
    $dir = Join-Path $Ordner 'erkundet'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    # Alle Artikel einmal lesen und die Zimmer-Artikel (Zimmer, Infrastrukturbeitrag,
    # Naechtigungsabgabe) mit Kennung und Namen auflisten - nur lesen.
    try {
        $r = Invoke-WebRequest -Uri "$Kassa/api/Product?limit=15000" -UseBasicParsing -WebSession $script:Sitzung -TimeoutSec 60
        $roh = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
        if ($roh.TrimStart().StartsWith('<')) { throw 'Kassa liefert HTML statt Daten (Anmeldung?)' }
        Set-Content -Path (Join-Path $dir 'alle-artikel.json') -Value $roh -Encoding UTF8
        $alle = $roh | ConvertFrom-Json
        if ($alle -isnot [array]) { foreach ($f in 'items', 'data', 'products', 'rows') { if ($alle.$f) { $alle = $alle.$f; break } } }
        $zimmer = @($alle | Where-Object { [string]$_.name -match 'Zimmer|Infrastruktur|chtigung' })
        Schreib ("Alle Artikel gelesen: $(@($alle).Count), davon Zimmer-Artikel: $($zimmer.Count)")
        foreach ($a in ($zimmer | Sort-Object { [string]$_.name })) {
            $id = if ($a._id) { $a._id } elseif ($a.id) { $a.id } else { '?' }
            Write-Output ("  {0}  {1}" -f $id, $a.name)
        }
        if ($zimmer.Count -gt 0) {
            Write-Output ''; Write-Output 'Felder eines Zimmer-Artikels (Name = Wert):'
            $zimmer[0].PSObject.Properties | ForEach-Object { Write-Output ("    {0} = {1}" -f $_.Name, (($_.Value | ConvertTo-Json -Compress -Depth 3) -replace '^(.{0,80}).*$', '$1')) }
        }
    } catch { Schreib ('Artikelliste nicht lesbar: ' + $_.Exception.Message) }
    Write-Output ''
    foreach ($e in (@($Artikel.GetEnumerator()) + @($Abgaben.GetEnumerator()))) {
        try {
            $text = Artikel-Holen $e.Value
            Set-Content -Path (Join-Path $dir ($e.Key + '.json')) -Value $text -Encoding UTF8
            $o = $text | ConvertFrom-Json
            Schreib ("$($e.Key): gelesen, Zahlenfelder:")
            $o.PSObject.Properties | Where-Object { $_.Value -is [double] -or $_.Value -is [int] -or $_.Value -is [long] -or $_.Value -is [decimal] } |
                ForEach-Object { Write-Output ("    {0} = {1}" -f $_.Name, $_.Value) }
        } catch { Schreib ("$($e.Key): " + $_.Exception.Message) }
    }
    Write-Output ''
    Write-Output "Die Dateien liegen in $dir. Den Feldnamen mit dem Bruttopreis als PREISFELD, den Nettopreis als NETTOFELD in kassa-einstellungen.txt eintragen."
    exit 0
}

# --- Rohdaten: nur anzeigen, was lieperts.at liefert ---------------------------
if ($Rohdaten) {
    $kopf = if ($zugang['HEADER']) { $zugang['HEADER'] } else { 'X-Lieperts-Kassa-Key' }
    try {
        $r = Invoke-WebRequest -Uri $TagesdatenUrl -UseBasicParsing -Headers @{ $kopf = $zugang['SCHLUESSEL'] } -TimeoutSec 60
        $t = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
        Write-Output ("Status $($r.StatusCode), $($t.Length) Zeichen:")
        try { ($t | ConvertFrom-Json | ConvertTo-Json -Depth 6) } catch { $t.Substring(0, [Math]::Min(2500, $t.Length)) }
    } catch { Write-Output ('Fehler: ' + $_.Exception.Message) }
    exit 0
}

# --- 1. Tagesdaten holen ------------------------------------------------------
$daten = $null
if (-not $zugang['SCHLUESSEL']) {
    Schreib 'FEHLER: kassa-zugang.txt fehlt - erst SETUP-schluessel-erzeugen.ps1 laufen lassen.'
} else {
    $kopf = if ($zugang['HEADER']) { $zugang['HEADER'] } else { 'X-Lieperts-Kassa-Key' }
    $daten = Mit-Wiederholung {
        try {
            $r = Invoke-WebRequest -Uri $TagesdatenUrl -UseBasicParsing -Headers @{ $kopf = $zugang['SCHLUESSEL'] } -TimeoutSec 60
        } catch {
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return 'fehlt' }
            throw
        }
        $utf8 = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
        return ($utf8 | ConvertFrom-Json)
    } 'Tagesdaten holen'
    if ($daten -eq 'fehlt') {
        Schreib 'Tagesdaten-Schnittstelle gibt es auf lieperts.at noch nicht (404) - Preise uebersprungen.'
        $daten = $null
    } elseif ($null -eq $daten) {
        Schreib 'Tagesdaten nicht erhalten - Preise uebersprungen.'
    } else {
        Schreib ("Tagesdaten fuer $($daten.datum): $(@($daten.zimmer).Count) Zimmer-Eintraege, drucken=$($daten.drucken)")
    }
}

# --- 2.-4. Preise schreiben ---------------------------------------------------
# lieperts.at entscheidet je Zimmer: "schreiben" (Abreisetag: Name mit Gast + Betrag),
# "zuruecksetzen" (Knopf leeren: Name ohne Gast, 0,00), sonst nichts anfassen.
# Welche Artikel und Betraege: Liste "kassa" (artikel_id, label, betrag, menge, ust).
if ($daten) {
    $schreiben = ($einst['SCHREIBEN'] -eq 'ja') -and -not ($daten.trockenlauf -eq $true) -and -not ($daten.test -eq $true)
    $preisFeld = $einst['PREISFELD']; $nettoFeld = $einst['NETTOFELD']
    $nameFeld = if ($einst['NAMEFELD']) { $einst['NAMEFELD'] } else { 'name' }
    if ($schreiben -and -not $preisFeld) {
        Schreib 'SCHREIBEN=ja, aber PREISFELD leer - erst -Erkunden laufen lassen. Nur Probelauf.'
        $schreiben = $false
    }

    # Minibar: Eintraege aus dem Gaeste-Formular je Zimmer zu einem kurzen Text
    # ("2x Bier, 1x Chips") zusammenfassen. Er kommt als Hinweis an den Zimmer-Knopf -
    # gebucht wird an der Kassa mit den normalen Knoepfen (richtige USt).
    $minibarText = @{}; $minibarSumme = @{}
    # Getraenke (20 %) und Snacks (10 %) getrennt - je eigener Knopf mit eigenem Steuersatz
    $SnackMuster = 'Chips|Haribo|Erdn|Nuss|N.ss|Snack|Riegel|Schoko|Nachos|Brezel'
    foreach ($m in @($daten.minibar)) {
        if ($null -eq $m) { continue }
        $roh = $m | ConvertTo-Json -Compress -Depth 8
        $zim = ([regex]::Match($roh, 'Salbei|Muskat|Pfeffer|Rosmarin')).Value
        if (-not $zim) { Schreib ('MINIBAR ohne erkennbares Zimmer: ' + $roh); continue }
        $script:mbPos = New-Object System.Collections.ArrayList
        function Sammle($o) {
            if ($null -eq $o) { return }
            if ($o -is [array]) { foreach ($x in $o) { Sammle $x }; return }
            if ($o -isnot [pscustomobject]) { return }
            $n = $null; $q = $null; $ep = $null
            foreach ($f in 'name', 'artikel', 'label', 'produkt', 'titel', 'item') { if ($o.$f -is [string] -and $o.$f) { $n = $o.$f; break } }
            foreach ($f in 'menge', 'anzahl', 'qty', 'quantity', 'stueck') { if ($null -ne $o.$f -and "$($o.$f)" -match '^\d+$') { $q = [int]$o.$f; break } }
            foreach ($f in 'preis', 'einzelpreis', 'price', 'betrag') { if ($null -ne $o.$f -and "$($o.$f)" -match '^\d+([.,]\d+)?$') { $ep = [double]("$($o.$f)" -replace ',', '.'); break } }
            if ($n -and $q -gt 0 -and $n -notmatch '^(Salbei|Muskat|Pfeffer|Rosmarin)$') {
                $null = $script:mbPos.Add([pscustomobject]@{ Name = $n; Menge = $q; Preis = $ep })
            }
            foreach ($pr in $o.PSObject.Properties) { if ($pr.Value -is [array] -or $pr.Value -is [pscustomobject]) { Sammle $pr.Value } }
        }
        Sammle $m
        if ($script:mbPos.Count -eq 0) { $minibarText["$zim|g"] = 'siehe Team-Board'; $minibarSumme["$zim|g"] = -1; continue }
        foreach ($pos in $script:mbPos) {
            $gr = if ($pos.Name -match $SnackMuster) { 's' } else { 'g' }
            $k = "$zim|$gr"; $t = "$($pos.Menge)*$($pos.Name)"
            $minibarText[$k] = if ($minibarText[$k]) { $minibarText[$k] + ', ' + $t } else { $t }
            if ($null -eq $pos.Preis) { $minibarSumme[$k] = -1 }
            elseif (-not $minibarSumme.ContainsKey($k)) { $minibarSumme[$k] = $pos.Menge * $pos.Preis }
            elseif ($minibarSumme[$k] -ge 0) { $minibarSumme[$k] += $pos.Menge * $pos.Preis }
        }
        Schreib ("MINIBAR ${zim}: " + (($script:mbPos | ForEach-Object { "$($_.Menge)x $($_.Name)" }) -join ', '))
    }

    # Plan aufstellen und pruefen, bevor irgendetwas geschrieben wird
    $plan = New-Object System.Collections.ArrayList
    $artJe = @{}
    $abbruch = $false
    foreach ($z in @($daten.zimmer)) {
        $zn = [string]$z.zimmer
        if ($z.schreiben -eq $true) { $art = 'schreiben' }
        elseif ($z.zuruecksetzen -eq $true -or $z.leer -eq $true) { $art = 'zuruecksetzen' }
        else { Schreib ("${zn}: nichts zu tun" + $(if ($z.bemerkung) { ' - ' + $z.bemerkung } else { '' })); continue }

        if ($art -eq 'schreiben' -and ((([string]$z.status) + ' ' + ([string]$z.gast) + ' ' + ([string]$z.lage)) -match $SperrMuster)) {
            Schreib "${zn}: gesperrt/Eigenbelegung/Storno - uebersprungen."; continue
        }
        foreach ($k in @($z.kassa)) {
            $id = [string]$k.artikel_id
            if ($Erlaubt -notcontains $id) { Schreib "${zn}: Artikel $id ist nicht freigegeben - uebersprungen."; continue }
            $menge = [int]$k.menge
            if ($art -eq 'zuruecksetzen') {
                $betrag = 0.0; $name = [string]$k.label
            } else {
                $betrag = [double]$k.betrag
                $istZimmer = ([string]$k.label) -match '^Zimmer'
                if ($betrag -le 0) { Schreib "${zn}: $($k.label) ohne Betrag - nichts geschrieben."; continue }
                if ($istZimmer -and [math]::Abs($betrag - $Platzhalter) -lt 0.005) { Schreib "${zn}: Platzhalter 179 - nichts geschrieben."; continue }
                if ($betrag -gt $Obergrenze) { Schreib "ABBRUCH: ${zn} $($k.label) $betrag EUR ueber $Obergrenze - es wird NICHTS geschrieben."; $abbruch = $true; break }
                $name = ([string]$k.label) + ' - ' + ([string]$z.gast) + $(if (-not $istZimmer) { " (${menge}x)" } else { '' })
            }
            $ust = [double]$k.ust
            $null = $plan.Add([pscustomobject]@{ Zimmer = $zn; Id = $id; Name = $name; Brutto = [math]::Round($betrag, 2); Netto = [math]::Round($betrag / (1 + $ust / 100), 2) })
        }
        $artJe[$zn] = $art
        if ($abbruch) { break }
    }
    if ($abbruch) { $plan.Clear() }
    # Minibar-Knoepfe "Minibar <Zimmer>" (Getraenke) und "Minibar Snacks <Zimmer>" (Snacks),
    # von Manuel in der Kassa angelegt; Kennung wird beim Schreiben ueber den Namen gesucht.
    # Offene Minibar -> sofort Liste (+ Summe), sonst leeren, wenn das Zimmer heute
    # ohnehin beschrieben/zurueckgesetzt wird.
    if (-not $abbruch) {
        foreach ($zn in 'Salbei', 'Muskat', 'Pfeffer', 'Rosmarin') {
            foreach ($gr in 'g', 's') {
                $basis = if ($gr -eq 'g') { 'Minibar ' + $zn } else { 'Minibar Snacks ' + $zn }
                $k = "$zn|$gr"; $mbName = $basis; $mbPreis = 0.0
                if ($minibarText[$k]) {
                    $mbName = $basis + ' - ' + $minibarText[$k]
                    if ($mbName.Length -gt 120) { $mbName = $mbName.Substring(0, 117) + '...' }
                    if ($einst['MINIBAR_PREIS'] -eq 'ja' -and $minibarSumme[$k] -gt 0) { $mbPreis = [math]::Round($minibarSumme[$k], 2) }
                } elseif (-not $artJe[$zn]) { continue }
                $null = $plan.Add([pscustomobject]@{ Zimmer = $zn; Id = ''; Suche = $basis; Gruppe = $gr; Liste = $minibarText[$k]; Name = $mbName; Brutto = $mbPreis; Netto = $null })
            }
        }
    }
    foreach ($p in $plan) { Schreib ("  plan: {0} -> {1:N2} EUR | {2}" -f $(if ($p.Id) { $p.Id.Substring(18) } else { 'Minibar' }), $p.Brutto, $p.Name) }

    if ($plan.Count -gt 0 -and -not $schreiben) {
        Schreib 'Probelauf (SCHREIBEN=nein oder Trockenlauf) - nichts in die Kassa geschrieben.'
    }
    elseif ($plan.Count -gt 0) {
        $ok = Mit-Wiederholung { Kassa-Anmelden; $true } 'Kassa-Anmeldung'
        if (-not $ok) { Schreib 'Kassa nicht erreichbar oder Quick-Login abgelaufen - keine Preise.' }
        else {
            $mbIds = @{}
            if (@($plan | Where-Object { -not $_.Id }).Count -gt 0) {
                try {
                    $r = Invoke-WebRequest -Uri "$Kassa/api/Product?limit=15000" -UseBasicParsing -WebSession $script:Sitzung -TimeoutSec 60
                    $alle = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
                    if ($alle -isnot [array]) { foreach ($f in 'items', 'data', 'products', 'rows') { if ($alle.$f) { $alle = $alle.$f; break } } }
                    foreach ($such in @($plan | Where-Object { -not $_.Id } | ForEach-Object { $_.Suche } | Select-Object -Unique)) {
                        $treffer = @($alle | Where-Object { [string]$_.name -match ('^' + [regex]::Escape($such) + '(\s|$)') })
                        if ($treffer.Count -eq 1) { $mbIds[$such] = [string]$treffer[0]._id }
                        elseif ($treffer.Count -gt 1) { Schreib "${such}: $($treffer.Count) Artikel mit diesem Namen - keiner beschrieben." }
                    }
                } catch { Schreib ('Minibar-Artikel nicht gefunden: ' + $_.Exception.Message) }
            }
            # Fehlt der Snacks-Knopf, kommen die Snacks als Hinweis auf den Getraenke-Knopf (ohne Preis).
            foreach ($sp in @($plan | Where-Object { $_.Gruppe -eq 's' -and $_.Liste -and -not $mbIds[$_.Suche] })) {
                $gp = $plan | Where-Object { $_.Gruppe -eq 'g' -and $_.Zimmer -eq $sp.Zimmer } | Select-Object -First 1
                if ($gp) { $gp.Name = $gp.Name + ' + Snacks einzeln: ' + $sp.Liste; if ($gp.Name.Length -gt 120) { $gp.Name = $gp.Name.Substring(0, 117) + '...' } }
                Schreib "$($sp.Suche) fehlt in der Kassa - Snacks bitte einzeln buchen: $($sp.Liste)"
            }
            foreach ($p in $plan) {
                if (-not $p.Id) {
                    if ($mbIds[$p.Suche]) { $p.Id = $mbIds[$p.Suche] } else { if ($p.Gruppe -ne 's') { Schreib "$($p.Suche): kein Artikel in der Kassa (bitte anlegen) - uebersprungen." }; continue }
                }
                try {
                    $obj = (Artikel-Holen $p.Id) | ConvertFrom-Json
                    foreach ($f in @($preisFeld, $nettoFeld, $nameFeld) | Where-Object { $_ }) {
                        if (-not ($obj.PSObject.Properties.Name -contains $f)) { throw "Feld '$f' gibt es im Artikel nicht" }
                    }
                    $obj.$preisFeld = $p.Brutto
                    if ($nettoFeld) {
                        $netto = if ($null -ne $p.Netto) { $p.Netto } else { [math]::Round($p.Brutto / (1 + [double]$obj.taxRate / 100), 2) }
                        $obj.$nettoFeld = $netto
                    }
                    $obj.$nameFeld = $p.Name
                    $body = [System.Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 20 -Compress))
                    $null = Invoke-WebRequest -Uri "$Kassa/api/Product/$($p.Id)`?limit=15000" -Method Post -Body $body `
                        -ContentType 'application/json; charset=utf-8' -UseBasicParsing -WebSession $script:Sitzung -TimeoutSec 30
                    $zurueck = (Artikel-Holen $p.Id) | ConvertFrom-Json
                    if ([math]::Abs([double]$zurueck.$preisFeld - $p.Brutto) -lt 0.005 -and [string]$zurueck.$nameFeld -eq $p.Name) {
                        Schreib ("OK {0:N2} EUR - {1}" -f $p.Brutto, $p.Name)
                    } else {
                        Schreib ("NICHT bestaetigt: {0} - Kassa zeigt {1} / '{2}'" -f $p.Name, $zurueck.$preisFeld, $zurueck.$nameFeld)
                    }
                } catch {
                    Schreib ("FEHLER beim Schreiben {0}: {1}" -f $p.Name, $_.Exception.Message)
                }
            }
        }
    }
}

# --- 5. Tagesblatt ------------------------------------------------------------
if ($OhneDruck) { Schreib 'OhneDruck - Tagesblatt uebersprungen.'; exit 0 }
$druck = Join-Path $Ordner 'DRUCK-tagesblatt-v3.ps1'
if ($daten -and $null -ne $daten.drucken) {
    if ($daten.drucken -eq $true -or [string]$daten.drucken -eq 'ja') {
        Schreib 'WordPress sagt drucken - Tagesblatt wird gedruckt.'
        & $druck -Lauf $Lauf -Immer
    } else {
        Schreib 'WordPress sagt heute kein Druck.'
    }
} else {
    # Solange die Tagesdaten-Schnittstelle fehlt: Drucktage wie im Plugin
    & $druck -Lauf $Lauf
}
exit 0
