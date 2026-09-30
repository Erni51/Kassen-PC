# Neuer Kassen-PC – Einrichtung

Lieperts Café · Dinner · Rooms. Stand 30.09.2026, nach
`UEBERGABE-Kassen-PC-NEU-Einrichtung-30-09-2026.md`.

Der neue PC (HP ProDesk 400 G6 Mini, Windows 11 Pro, iiyama-Touchschirm) ist der **Bote** zwischen
lieperts.at und der Kassa (kassenGeist, `http://192.168.178.200/kasse/`): Er holt die Tagesdaten,
schreibt die Zimmerpreise in die Kassa und druckt das Tagesblatt. Kein USB-Stick nötig – alles kommt
direkt aus dem Internet.

Ausführlicher Windows-Aufbau (Konten, Programme): [GRUNDEINRICHTUNG.md](GRUNDEINRICHTUNG.md).

---

## Reihenfolge

### 0 · Quick-Login erneuern (in der Kassa)
**VERWALTUNG → Quick-Login → NEUE ADMIN-URL** und **NEUE KASSE-URL**. Die neue Kasse-URL gleich
bereithalten (sie wird in Schritt 4 eingefügt). Alte Lesezeichen am Handy/Tablet danach neu setzen.

### 1 · Windows
- Bildschirm: **HDMI und USB** (USB = Touch), Netzwerk, Strom.
- Lokales Konto `Kassa` (kein Microsoft-Konto), Windows-Updates komplett durchlaufen lassen.
- Automatische Anmeldung: `Windows + R` → `netplwiz` → Häkchen „Benutzer müssen … Kennwort eingeben“ weg.
  (Windows 11: vorher Einstellungen › Konten › Anmeldeoptionen › „Nur Windows Hello …“ aus.)

### 2 · Netzwerk und Drucker
- Chrome installieren, `http://192.168.178.200/kasse/` muss aufgehen.
- Netzwerkdrucker: Einstellungen › Drucker › Drucker hinzufügen › „nicht aufgeführt“ › IP-Adresse.
  Testseite, dann **als Standard festlegen**.

### 3 · Dateien holen und einrichten
`Windows-Taste` → `powershell` → **`Strg + Umschalt + Enter`** → Ja. Diese **eine** Zeile einfügen, Enter:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force; [Net.ServicePointManager]::SecurityProtocol='Tls12'; $z="$env:TEMP\kpc.zip"; Invoke-WebRequest 'https://github.com/Erni51/Kassen-PC/archive/refs/heads/claude/neuer-kassen-pc-setup-rkekre.zip' -OutFile $z -UseBasicParsing; Expand-Archive $z "$env:TEMP\kpc" -Force; $d=(Get-ChildItem "$env:TEMP\kpc" -Directory)[0].FullName; & "$d\kassen-pc\EINRICHTEN.ps1"
```

(Oder die ZIP-Datei aus dem Chat herunterladen, entpacken, `START.cmd` doppelklicken.)

### 4 · Während das Einrichten läuft
1. Es erzeugt den **Schlüssel** und legt die Zeile `define('LRV8_KASSA_KEY', '…');` in die
   Zwischenablage → auf lieperts.at in die `wp-config.php` einfügen (eine vorhandene Zeile ersetzen).
2. Es fragt die **neue Kasse-URL** aus Schritt 0 → mit `Strg + V` einfügen, Enter.

Danach sind angelegt:

| Aufgabe | Zeit | Was |
|---|---|---|
| **Kassa früh** | täglich 07:15 | Preise schreiben → Tagesblatt, wenn Früh-Tag |
| **Kassa abend** | täglich 16:15 | Preise schreiben → Tagesblatt, wenn Abend-Tag |
| **Lieperts Cron** | alle 5 Min. | `wp-cron.php` (Google-Abgleich, Feratel, Erinnerungsmails) |

Dazu: nie schlafen, Bildschirm nie aus, Update-Neustarts nur 00–06 Uhr, Standarddrucker bleibt fest,
Kassa startet im Chrome-Kiosk (`--kiosk --app=http://192.168.178.200/kasse/menu`, beenden mit `Alt + F4`).

### 5 · Den Bau-Chat beauftragen
Den Inhalt von [`kassen-pc/AUFTRAG-Bau-Chat-kassa-tagesdaten.txt`](kassen-pc/AUFTRAG-Bau-Chat-kassa-tagesdaten.txt)
in den Bau-Chat einfügen. Er baut den Abrufpunkt `/wp-json/lieperts/v1/kassa-tagesdaten`.
**Bis der live ist**, druckt der PC das Tagesblatt nach den bekannten Drucktagen und schreibt keine Preise
(Protokoll: „Tagesdaten-Schnittstelle gibt es … noch nicht“).

### 6 · Preise scharf schalten (erst wenn Schritt 5 live ist)
In PowerShell (Administrator):

```powershell
C:\Lieperts\HELFER-kasse-zimmerpreise.ps1 -Erkunden
```
Liest die sechs Kassa-Artikel **nur**, legt sie nach `C:\Lieperts\erkundet\` und zeigt die Zahlenfelder.
Dann `notepad C:\Lieperts\kassa-einstellungen.txt` und eintragen:

```
PREISFELD=<Feldname mit dem Bruttopreis>
NETTOFELD=<Feldname mit dem Nettopreis>
```
Probelauf: `C:\Lieperts\HELFER-kasse-zimmerpreise.ps1 -Lauf abend -OhneDruck` → im Protokoll steht, was
geschrieben **würde**. Stimmt alles: `SCHREIBEN=ja` setzen, noch einmal laufen lassen, in der Kassa die
vier Zimmer-Buttons prüfen.

### 7 · Testlauf
1. `C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test` → kommt das Blatt aus dem Drucker?
2. `C:\Lieperts\PRUEFEN.ps1` → alle drei Aufgaben da, Cron `OK 200`.
3. PC neu starten, nichts anfassen → Kassa erscheint im Vollbild.
4. Am nächsten Morgen nach 07:15 wieder `PRUEFEN.ps1`.

---

## Was der Helfer nie tut
Nur die vier festen Zimmer-Artikel · nie 0 · nie 179 · über 5.000 € bricht er ganz ab · Eigenbelegung,
Sperre, Storno werden übersprungen · keine Bons, Umsätze, Rechnungen (RKSV) · nach jedem Schreiben
zurücklesen. Nächtigungsabgabe (€ 2,50) und Infrastrukturbeitrag (€ 1,00) bucht ihr an der Kassa als
**Menge** – der Helfer schreibt die Anzahl (Erwachsene × Nächte) ins Protokoll.

## Wenn morgens etwas nicht stimmt
Erst `C:\Lieperts\PRUEFEN.ps1`, Protokolle: `kassa-helfer.log`, `tagesblatt.log`, `cron-lieperts.log`.

| Bild | Ursache |
|---|---|
| kein Preis auf einem Zimmer | keine Buchung oder Sperre – steht im Protokoll |
| gar keine Preise | Kassa nicht erreichbar oder Quick-Login abgelaufen → `SETUP-schluessel-erzeugen.ps1` erneut, neue URL |
| kein Protokolleintrag | Aufgabe nicht gelaufen – PC aus oder nicht angemeldet |
| Tagesblatt kommt nicht | Drucker offline / falscher Standarddrucker |
| falsche Beträge | nicht am PC suchen – die Zahlen kommen aus lieperts.at |

## Dateien (`kassen-pc/`)

| Datei | Zweck |
|---|---|
| `START.cmd` | Doppelklick → holt Admin-Rechte, startet `EINRICHTEN.ps1` |
| `EINRICHTEN.ps1` | richtet alles ein |
| `SETUP-schluessel-erzeugen.ps1` | Schlüssel + Quick-Login, nur lokal gespeichert |
| `HELFER-kasse-zimmerpreise.ps1` | Preise in die Kassa, dann Druck |
| `DRUCK-tagesblatt-v3.ps1` | holt und druckt das Tagesblatt |
| `CRON-lieperts-v1.ps1` | alle 5 Min. `wp-cron.php` |
| `PRUEFEN.ps1` / `ENTFERNEN.ps1` | Kontrolle / Rückweg |
| `AUFTRAG-Bau-Chat-kassa-tagesdaten.txt` | zum Einfügen in den Bau-Chat |

Schlüssel und Quick-Login-URL liegen **nur** am Kassen-PC (`C:\Lieperts\kassa-zugang.txt`,
`kassa-einstellungen.txt`) – dieses Repository ist öffentlich.
