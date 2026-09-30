# Neuer Kassen-PC – von Grund auf einrichten

> **Stand 30.09. abends – geht vor:** Es gilt die [README](README.md) (nach der Übergabe vom 30.09.).
> Abweichend von unten: Konto heißt `Kassa`, **kein USB-Stick** (alles aus dem Internet), Aufgaben
> „Kassa früh“ 07:15 und „Kassa abend“ 16:15, Kassa im Kiosk `http://192.168.178.200/kasse/menu`,
> und **Claude Desktop kommt auf den PC** (Übergabe Schritt 4), damit Claude Skripte und Protokolle
> aus der Ferne ansehen kann. Der Rest (Programme, Chrome ohne Google-Konto, Neustart-Probe) gilt weiter.

Stand 30.09.2026. Ergänzt die [README](README.md): Hier steht, **wie der PC grundsätzlich aufgebaut wird**.
Die Lieperts-Automatik (Tagesblatt-Druck, Cron) kommt in Phase 5 mit `START.cmd` dazu.

---

## Grundsatz: ein schlanker Arbeitsplatz, der nur einen Zweck hat

Der Kassen-PC ist **kein Büro-PC**. Die eigentliche Kassa (kassenGeist, Registrierkasse) läuft auf dem Linux-Mini-PC
`192.168.178.200`. Der Windows-PC ist nur der Bildschirm dazu, druckt das Tagesblatt und hält die Webseite am Laufen (Cron).
Je weniger darauf ist, desto weniger kann kaputtgehen, und desto weniger sieht das Team, was es nicht sehen soll.

| Auf den PC | Wofür |
|---|---|
| **Windows 11 Pro** (bzw. was vorinstalliert ist) | Grundsystem, Windows Defender als Virenschutz reicht |
| **Google Chrome** | Kassa (kassenGeist), Lieperts-App, Tagesblatt-Vorschau |
| **SumatraPDF** | PDF ansehen und drucken – klein, schnell, ohne Werbung und Konto |
| **Druckertreiber** | für den Tagesblatt-Drucker |
| **Outlook** – nur wenn das Team dort Mails lesen soll | siehe Hinweis unten |
| `C:\Lieperts` (aus `START.cmd`) | Tagesblatt-Druck und Cron |

| **Nicht** auf den PC | Warum |
|---|---|
| Claude-App, Claude-Erweiterung | Du arbeitest am Handy; die Cloud-Aufgaben brauchen den PC nicht |
| Office-Paket, Spiele, private Konten, OneDrive-Sync privater Ordner | unnötig, Datenschutz |
| gespeicherte Kennwörter für Bank, ELBA, Buchhaltung, WordPress-Verwalter | der PC steht an der Theke, jeder kann ran |
| Fernwartungs-Programme „auf Vorrat“ | nur wenn wirklich jemand von außen helfen soll |

**Zu Outlook:** Im Postfach `office@lieperts.at` liegen auch Rechnungen und Buchhaltungs-Mails. Ist Outlook an der Theke
offen, kann das ganze Team mitlesen. Meine Empfehlung: **weglassen**, wenn Reservierungen ohnehin über die App kommen.
Brauchst du es doch, nimm das bei Windows 11 schon vorhandene „Outlook (new)“ und sperre den PC mit `Windows + L`,
wenn du weggehst.

**Zwei Windows-Konten:**
- `Lieperts-Admin` – nur zum Einrichten und für Updates, mit Kennwort.
- `User.Kassa` – das Konto, in dem der PC den ganzen Tag läuft; meldet sich automatisch an. Am Ende **Standardbenutzer**
  (keine Administratorrechte), damit niemand an der Theke versehentlich etwas installiert.

---

## Phase 0 · Vorbereiten (am Vortag oder vor dem Auspacken)

1. Den **alten** PC sichern – README, Abschnitt 2 (`SICHERN-alter-kassen-pc.cmd` vom USB-Stick). Danach läuft er normal weiter.
2. Auf einem anderen PC die [GitHub-Seite](https://github.com/Erni51/Kassen-PC) öffnen, Branch
   `claude/neuer-kassen-pc-setup-rkekre` → **Code › Download ZIP** → auf denselben Stick entpacken.
3. Bereitlegen: Druckermodell (steht in `Kassen-PC-Sicherung\drucker.txt`), ein Kennwort für `Lieperts-Admin`,
   ein Kennwort für `User.Kassa`, falls gewünscht die Zugangsdaten für Outlook.
4. Für die Einrichtung eine **USB-Maus** oder -Tastatur mit Touchpad leihen – das spart viel Zeit. Im Betrieb geht es
   danach wieder nur mit Tastatur und Touchscreen.

---

## Phase 1 · Windows zum ersten Mal starten (ca. 20 Min.)

1. PC per **Netzwerkkabel** anschließen (nicht WLAN – die Kassa und der Drucker sind im Kabelnetz).
2. Einschalten. Region **Österreich**, Tastatur **Deutsch**.
3. Windows will ein **Microsoft-Konto**. Für einen Kassen-PC besser ein **lokales Konto**:
   - Windows 11 ab 24H2: bei der Kontoabfrage `Umschalt + F10` → im schwarzen Fenster `start ms-cxh:localonly` → Enter.
   - ältere Stände: `Umschalt + F10` → `oobe\bypassnro` → Enter, PC startet neu, dann „Ich habe kein Internet“.
   - Klappt beides nicht: mit einem Microsoft-Konto einrichten und `Lieperts-Admin` danach als lokales Konto anlegen.
4. Kontoname **`Lieperts-Admin`**, Kennwort vergeben.
5. Alle Datenschutz-Schalter (Standort, Diagnose, Werbung, „maßgeschneiderte Erfahrungen“) auf **Nein**.

## Phase 2 · Windows auf Stand bringen (30–60 Min., läuft meist von selbst)

1. `Windows-Taste` → „Windows Update“ → **Nach Updates suchen**, so oft neu starten, bis nichts mehr kommt.
   Dort auch „Erweiterte Optionen › Optionale Updates“ → Treiber installieren.
2. Windows Update › Erweiterte Optionen › **Nutzungszeit** manuell auf **06:00–23:00** – dann startet Windows
   nie während des Betriebs von selbst neu.
3. Werbe-Apps entfernen, die nicht gebraucht werden (optional): Einstellungen › Apps › Installierte Apps.

## Phase 3 · Programme installieren (10 Min.)

In **PowerShell als Administrator** (`Windows-Taste` → `powershell` → `Strg + Umschalt + Enter`):

```powershell
winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements
winget install -e --id SumatraPDF.SumatraPDF --accept-package-agreements
```

Danach:
1. **SumatraPDF als Standard für PDF:** Einstellungen › Apps › Standard-Apps › `.pdf` → SumatraPDF.
2. **Chrome als Standardbrowser:** Einstellungen › Apps › Standard-Apps › Google Chrome › „Als Standard festlegen“.
3. **Drucker** anschließen/installieren (Treiber vom Hersteller oder Windows Update), Testseite drucken.
   Einstellungen › Bluetooth und Geräte › Drucker: **„Windows verwaltet Standarddrucker“ aus**, dann den Tagesblatt-Drucker
   › „Als Standard festlegen“.
4. **Outlook** nur, wenn du dich oben dafür entschieden hast.

## Phase 4 · Konto `User.Kassa` anlegen (5 Min.)

In derselben Administrator-PowerShell (Kennwort statt `KENNWORT` eintippen):

```powershell
net user User.Kassa KENNWORT /add
net localgroup Administratoren User.Kassa /add
```

(Administrator nur vorübergehend – wird in Phase 7 wieder weggenommen.)

Abmelden (`Strg + Alt + Entf` → Abmelden) und als **`User.Kassa`** anmelden. Ab hier alles in diesem Konto.

## Phase 5 · Lieperts-Automatik (5 Min.)

1. USB-Stick mit `Kassen-PC-Sicherung` und dem entpackten ZIP einstecken.
2. Im entpackten Ordner `kassen-pc\START.cmd` starten → Rückfrage **Ja**.
3. Durchlaufen lassen. Legt `C:\Lieperts`, Cron (alle 5 Min.), Tagesblatt 16:30 und 07:30, Energie „nie schlafen“ und
   den Kassa-Autostart im Chrome an. Einzelheiten: README, Abschnitt 4.
4. Druckprobe: in PowerShell `C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test`, dann `C:\Lieperts\PRUEFEN.ps1`.

## Phase 6 · Chrome einrichten (10 Min.)

1. Chrome öffnen – **ohne** Google-Anmeldung (sonst landen deine privaten Lesezeichen und Kennwörter an der Theke).
2. Einstellungen › Autofill und Passwörter › Passwortmanager › **„Speichern von Passwörtern anbieten“ aus**.
3. Lesezeichenleiste einblenden (`Strg + Umschalt + B`) und drei Lesezeichen anlegen (`Strg + D`):
   - **Kassa** – `http://192.168.178.200` (genau die Adresse wie am alten PC)
   - **Lieperts-App** – `https://www.lieperts.at/lieperts-app/` – mit einem **Team-Zugang**, nicht als Verwalter
   - **Tagesblatt-Archiv** – `file:///C:/Lieperts/Archiv/`
4. Einstellungen › Beim Start › „Bestimmte Seiten öffnen“ → Kassa. (Der Autostart aus Phase 5 öffnet sie ohnehin.)

## Phase 7 · Abschließen (10 Min.)

1. **Automatisch anmelden** als `User.Kassa`: Einstellungen › Konten › Anmeldeoptionen › „Nur Windows Hello-Anmeldung
   zulassen“ **aus** → `Windows + R` → `netplwiz` → `User.Kassa` markieren → Häkchen
   „Benutzer müssen Benutzernamen und Kennwort eingeben“ weg → OK → Kennwort zweimal.
2. **Adminrechte wegnehmen** – als `Lieperts-Admin` anmelden, PowerShell als Administrator:
   ```powershell
   net localgroup Administratoren User.Kassa /delete
   ```
   Die Druck-Aufgaben laufen weiter (sie brauchen keine Adminrechte), der Cron läuft als SYSTEM.
3. **Neustart-Probe** – das ist die wichtigste Kontrolle:
   PC ganz ausschalten, einschalten, **nichts anfassen**. Es muss von selbst passieren:
   `User.Kassa` meldet sich an → Chrome zeigt die Kassa im Vollbild. Nach 5 Minuten zeigt `C:\Lieperts\PRUEFEN.ps1`
   eine neue Zeile `OK 200` beim Cron.
4. Im BIOS/UEFI (optional, je nach Gerät): „Restore on AC Power Loss“ / „Nach Stromausfall einschalten“ auf **On** –
   dann startet der PC nach einem Stromausfall von allein.

## Phase 8 · Umstellen

1. Am **ersten Drucktag** (Fr, Sa, So früh oder Mo, Di, Fr, Sa 16:30) prüfen, ob das Blatt kommt und gut aussieht.
2. Erst dann am **alten** PC die Aufgaben löschen (README, Abschnitt 6) und ihn abbauen.
3. Die Sicherung `Kassen-PC-Sicherung\skriptordner\DRUCK-tagesblatt-v2.ps1` nach Drive › Claude-Ablage ›
   *Tagesblatt Druck und Tischplan* legen.

---

## Im Alltag

| Was | Wie |
|---|---|
| Weggehen | `Windows + L` (sperrt, Druck und Cron laufen weiter) |
| Kassa-Vollbild verlassen/zurück | `F11` |
| Läuft alles? | PowerShell → `C:\Lieperts\PRUEFEN.ps1` |
| Blatt nochmal drucken | PowerShell → `C:\Lieperts\DRUCK-tagesblatt-v3.ps1 -Lauf test` |
| altes Blatt ansehen | Chrome-Lesezeichen „Tagesblatt-Archiv“ |
| Updates | einmal im Monat als `Lieperts-Admin` Windows Update laufen lassen |
| PC ausschalten | möglichst nie – der Cron braucht ihn; Bildschirm darf aus |
