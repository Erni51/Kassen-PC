# Neuer Kassen-PC – Einrichtung

Lieperts Café · Dinner · Rooms. Stand 30.09.2026.
Grundlage sind die Übergaben aus Google Drive › Claude-Ablage › *Tagesblatt Druck und Tischplan*
(`UEBERGABE-Kassen-PC-Tagesblatt-23-09-2026.md`, `UEBERGABE-Druck-und-Tischzuweisung-19-09-2026.md`,
`KASSEN-PC-Anleitung-Cron.md`, `BEFUND-Cron-steht-19-09-2026.md`) und die Liste deiner geplanten Aufgaben.

---

## 1 · Was wo läuft

| Was | Wo | Am neuen PC zu tun? |
|---|---|---|
| **Kassa (kassenGeist)** | Linux-Mini-PC im Haus, `192.168.178.200` | nein – der Kassen-PC zeigt sie nur im Chrome an |
| **Tagesblatt-Druck** (16:30 Abend, 07:30 Früh) | Kassen-PC, geplante Aufgabe | **ja** |
| **Cron-Starter** (alle 5 Min. `wp-cron.php`: Google-Abgleich, Feratel-Zimmerimport, Erinnerungsmails) | Kassen-PC, geplante Aufgabe | **ja** – ohne ihn bleiben diese Abläufe liegen |
| **Cloud-Aufgaben** (Buchhaltung, Einkauf, Veranstaltungen …) | Claude-Cloud | nein – laufen ohne PC, siehe Abschnitt 7 |

Das Tagesblatt kommt von `https://www.lieperts.at/?lrv8_tagesblatt=1`, dieselbe Datenquelle wie die App:
Seite 1 = App-Druck (Frühstück, Mittag, Fine Dining/Abend, Events, **Zimmer**, Hinweise), Seite 2 = Zettel „Tische eintragen“.

**Drucktage** (gleich wie im Plugin, v30.990 / v31.015):

| | Mo | Di | Mi | Do | Fr | Sa | So |
|---|---|---|---|---|---|---|---|
| **16:30 Abend** | ✔ | ✔ | – | – | ✔ | ✔ | – |
| **07:30 Früh** | – | – | – | – | ✔ | ✔ | ✔ |

---

## 2 · Vorher: den alten PC sichern (5 Minuten)

Das alte Druckskript `DRUCK-tagesblatt-v2.ps1` liegt **nur** auf dem alten Kassen-PC – nicht in Drive.
Darin steht der Schlüssel, mit dem der PC das Tagesblatt abholen darf. Deshalb zuerst sichern:

1. Die Datei [`alter-pc/SICHERN-alter-kassen-pc.cmd`](alter-pc/SICHERN-alter-kassen-pc.cmd) auf einen USB-Stick kopieren.
2. Stick am **alten** PC einstecken.
3. `Windows-Taste` → `cmd` tippen → `Enter`.
4. Tippen (Laufwerksbuchstabe des Sticks, meist `E:`):
   ```
   E:\SICHERN-alter-kassen-pc.cmd
   ```
   `Enter`. Am Ende steht „Fertig“, dann eine Taste drücken.

Auf dem Stick liegt jetzt `Kassen-PC-Sicherung` mit allen „Lieperts“-Aufgaben, dem Skriptordner und der Druckerliste.
Am alten PC wird dabei nichts verändert.

> Ist der alte PC schon kaputt: weiter mit Abschnitt 3. Das Einrichten fragt dann nach Kopfzeilen-Name und
> Schlüssel (`LRV8_KASSA_KEY` in der `wp-config.php`) – beides weiß der Bau-Chat bzw. steht im Plugin
> in `lrv8_v30724_zugang_ok()`.

---

## 3 · Neuer PC: Grundeinrichtung (einmalig)

1. **Benutzer**: Windows-Konto `User.Kassa` anlegen und für die Einrichtung **Administrator** lassen
   (die Druck-Aufgaben werden für den Benutzer angelegt, der das Einrichten startet).
2. **Automatisch anmelden** (damit nach Stromausfall alles von selbst wieder läuft):
   `Windows-Taste + R` → `netplwiz` → `Enter` → Häkchen „Benutzer müssen Benutzernamen und Kennwort eingeben“
   mit `Tab`/`Leertaste` entfernen → `Enter` → Kennwort zweimal.
   (Unter Windows 11 zuerst: Einstellungen › Konten › Anmeldeoptionen › „Nur Windows Hello-Anmeldung zulassen“ aus.)
3. **Netzwerk**: Kabel ins Kassen-Netz. Kontrolle: im Chrome `http://192.168.178.200` öffnen – die Kassa muss erscheinen.
4. **Google Chrome** installieren.
5. **Drucker** installieren und als **Standarddrucker** setzen (Einstellungen › Drucker › „Windows verwaltet Standarddrucker“ aus).
   Welcher es am alten PC war, steht in `Kassen-PC-Sicherung\drucker.txt` (Zeile mit `TRUE`).

---

## 4 · Neuer PC: alles automatisch einrichten

### Weg A – mit USB-Stick (einfachster Weg)

1. An irgendeinem PC: <https://github.com/Erni51/Kassen-PC> → Branch `claude/neuer-kassen-pc-setup-rkekre`
   → **Code › Download ZIP** → ZIP auf den Stick (zur `Kassen-PC-Sicherung`) und dort entpacken.
2. Stick am neuen PC einstecken, im entpackten Ordner `kassen-pc\START.cmd` starten → Rückfrage mit **Ja**.

### Weg B – direkt am neuen PC aus dem Internet

`Windows-Taste` → `powershell` tippen → **`Strg + Umschalt + Enter`** (= als Administrator) → Ja.
Dann diese **eine** Zeile (Stick mit der Sicherung vorher einstecken, `E:` ggf. anpassen):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force; [Net.ServicePointManager]::SecurityProtocol='Tls12'; $z="$env:TEMP\kpc.zip"; Invoke-WebRequest 'https://github.com/Erni51/Kassen-PC/archive/refs/heads/claude/neuer-kassen-pc-setup-rkekre.zip' -OutFile $z -UseBasicParsing; Expand-Archive $z "$env:TEMP\kpc" -Force; $d=(Get-ChildItem "$env:TEMP\kpc" -Directory)[0].FullName; & "$d\kassen-pc\EINRICHTEN.ps1" -Sicherung 'E:\Kassen-PC-Sicherung'
```

### Was das Einrichten macht

| Schritt | Ergebnis |
|---|---|
| Ordner | `C:\Lieperts` mit Skripten, `Archiv\` (jedes Tagesblatt als HTML, 90 Tage), Protokollen |
| Zugang | `C:\Lieperts\kassa-zugang.txt` – aus dem alten Skript übernommen oder abgefragt. **Nie weitergeben.** |
| Aufgabe `Lieperts Cron` | alle 5 Minuten, als SYSTEM, auch ohne Anmeldung |
| Aufgabe `Lieperts-Tagesblatt-1630` | täglich 16:30 → `DRUCK-tagesblatt-v3.ps1 -Lauf abend` |
| Aufgabe `Lieperts-Tagesblatt-Frueh-0730` | täglich 07:30 → `DRUCK-tagesblatt-v3.ps1 -Lauf frueh` |
| Nachholen | war der PC zur Druckzeit aus, druckt er sofort nach dem Einschalten |
| Energie | PC schläft nie ein (Bildschirm darf ausgehen) |
| Autostart | Chrome öffnet beim Anmelden die Kassa `http://192.168.178.200` im Vollbild |
| Probelauf | Cron einmal gestartet, Tagesblatt einmal geholt (ohne Druck) |

Das Skript entscheidet selbst über den Wochentag; an Mi/Do wird nichts gedruckt, außer es reist wirklich jemand an oder ab.
Gedruckt wird nur, wenn die Antwort „Lieperts Tagesblatt“ enthält – sonst steht im Protokoll „BLATT NICHT ERHALTEN“.

Läuft die Kassa unter einer anderen Adresse (Port o. Ä.), beim Starten `-KassaUrl http://192.168.178.200:PORT` anhängen.

---

## 5 · Probedruck und Kontrolle

In der Administrator-PowerShell:

```powershell
C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test     # holt und druckt jetzt sofort
C:\Lieperts\PRUEFEN.ps1                            # Aufgaben, Protokolle, Standarddrucker
```

`PRUEFEN.ps1` soll zeigen:
- alle drei Aufgaben vorhanden, Ergebnis `0`
- Cron: alle 5 Minuten eine Zeile `OK 200`
- Tagesblatt: `GEDRUCKT (mshtml)` bzw. an freien Tagen `Heute ist kein Lauf vorgesehen.`
- der richtige Drucker mit `[STANDARD]`

**Wichtig beim ersten Ausdruck:** Das Papier kommt aus der Internet-Explorer-Maschine (`mshtml`) und sieht anders aus
als die Chrome-Vorschau. Die neue Gäste-Info-Zeile (seit v31.073) wurde auf Papier noch nie angesehen – bitte einmal prüfen.

Erscheint beim Druck ein Druckdialog am Bildschirm (manche Windows-11-Stände): einmal `Enter`.
Kommt er jedes Mal, im Protokoll steht dann „WARNUNG: Druck nach 3 Minuten nicht fertig“ – dem Bau-Chat melden.

---

## 6 · Den alten PC abschalten

Erst wenn am neuen PC `PRUEFEN.ps1` grün ist und ein Blatt gedruckt wurde:
am alten PC die Aufgaben entfernen, damit nicht doppelt gedruckt und doppelt Cron gerufen wird:

```
schtasks /Delete /TN "Lieperts-Tagesblatt-1630" /F
schtasks /Delete /TN "Lieperts-Tagesblatt-Sonntag-0730" /F
schtasks /Delete /TN "Lieperts Cron" /F
```
(Namen stehen in `Kassen-PC-Sicherung\alle-aufgaben.txt`.)

Rückweg am neuen PC: `C:\Lieperts\ENTFERNEN.ps1` als Administrator.

---

## 7 · Deine geplanten Cloud-Aufgaben (laufen ohne Kassen-PC)

Diese laufen in der Claude-Cloud und brauchen am neuen PC **nichts**:

| Aufgabe | Wann | Status |
|---|---|---|
| Monatslauf Buchhaltung Liepert KG | 4. und 9. jedes Monats, 04:30 | aktiv |
| Einkauf: HOGAST-Preise auffrischen | Mo 07:00 | aktiv |
| Einkauf: Shop-Preise und Suchaufträge | Mo 07:30 | aktiv |
| Einkauf: Lidl-Flugblatt und Hofer | Do 07:00 | aktiv |
| Einkauf: Auffrisch-Wache | stündlich 06–19 Uhr | aktiv |
| Einkauf: Rechnungshistorie nachziehen | 7. jedes Monats | aktiv |
| Veranstaltungen Südsteiermark | Mo 05:46 | aktiv |
| Wöchentliche Wächter-Kontrolle | Mo 05:00 | aktiv – **Teil A braucht deinen Rechner** (Chrome, bei lieperts.at angemeldet) |
| Google-API: Kontingent prüfen | einmal 01.10. | aktiv |
| Meta-Zugang „Lieperts Status“ neu verbinden | einmal 05.10. | aktiv |
| Nächtigungsabgabe: Vorbereitung | einmal 24.11. | aktiv |
| Ab-Preis 7,0 → 7,6 zum 1.12. | einmal 30.11. | aktiv |

Abgeschaltet (bleiben aus): Gäste-Leck-Kontrolle, DMARC-Berichte, Donnerstags-Beitrag, alte ersetzte Läufe.

Die Wächter-Kontrolle öffnet `wp-admin/tools.php?page=lieperts_waechter` im Browser deines Rechners. Soll das künftig der
neue Kassen-PC sein: dort Chrome mit der Claude-Erweiterung installieren und bei lieperts.at als Verwalter anmelden.
Sonst macht sie nur Teil B (Kalender) und meldet Teil A als „nicht erreichbar“.

---

## 8 · Offen / zu klären

- **„Was die Gäste zu bezahlen haben“ automatisch in die Kassa:** Im Gedächtnis (Drive-Übergaben) gibt es dafür
  **keine** fertige Schnittstelle zum kassenGeist. Gebaut ist: das Tagesblatt zeigt Zimmer, Reservierungen und Hinweise
  und wird gedruckt und im `Archiv` abgelegt. Eine echte Übergabe von Beträgen in den kassenGeist (Import oder API) wäre
  ein neuer Bau – dafür zuerst klären, ob kassenGeist einen Import (CSV) oder eine Schnittstelle anbietet.
- **Zimmergast-Frühstück auf dem Früh-Blatt** fehlt noch (Patch v31.076 aus der Übergabe vom 23.09. vorbereitet).
- **Name der Kopfzeile für den Schlüssel** stand nie in Drive – er wird aus dem alten Skript übernommen.
  Liegt die Sicherung vor, gehört `Kassen-PC-Sicherung\skriptordner\DRUCK-tagesblatt-v2.ps1` zusätzlich in
  Drive › Claude-Ablage › *Tagesblatt Druck und Tischplan* (Übergabe 23.09.: „einmal in die Claude-Ablage legen“).

---

## Dateien

| Datei | Zweck |
|---|---|
| `alter-pc/SICHERN-alter-kassen-pc.cmd` | alten PC auf USB-Stick sichern (Windows 7, nur lesen) |
| `kassen-pc/START.cmd` | Einrichtung starten (holt Admin-Rechte, findet den Stick) |
| `kassen-pc/EINRICHTEN.ps1` | richtet alles ein |
| `kassen-pc/DRUCK-tagesblatt-v3.ps1` | holt und druckt das Tagesblatt |
| `kassen-pc/CRON-lieperts-v1.ps1` | ruft alle 5 Minuten `wp-cron.php` auf |
| `kassen-pc/PRUEFEN.ps1` | Kontrolle |
| `kassen-pc/ENTFERNEN.ps1` | Rückweg |

Der Schlüssel (`kassa-zugang.txt`) liegt **nur** am Kassen-PC – dieses Repository ist öffentlich.
