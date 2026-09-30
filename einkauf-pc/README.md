# Lieperts Einkauf (live) – Programm am Kassen-PC

Stand 30.09.2026 · Probe mit Transgourmet (Abschnitte 1–4 der freigegebenen Blaupause).

Ein kleines Programm am Kassen-PC. Handy, Laptop oder Tablet öffnen eine Webseite. Das Programm sucht
**live** in den Shops, rechnet auf **€/kg bzw. €/l** um, zeigt den **Günstigsten oben** und legt mit dem
**Plus** direkt in den **echten Shop-Warenkorb**. Bestellen (abschicken) tust du selbst im Shop.
**Kein Claude und kein Nutzungslimit** im Alltag.

```
Handy / Laptop ──WLAN──▶ Kassen-PC :8787 ──▶ eigenes Chrome (angemeldet) ──▶ Transgourmet, Rungis, …
```

Warum über den Kassen-PC? Eine Webseite darf nicht mit deiner Anmeldung in einem anderen Shop suchen
(Browser-Sperre). Das Chrome am Kassen-PC ist angemeldet und sucht dort, als ob du selbst klickst.

## Einrichten

1. Den Inhalt von [`AUFTRAG-Claude-am-Kassen-PC-Einkauf.txt`](AUFTRAG-Claude-am-Kassen-PC-Einkauf.txt) an Claude
   am Kassen-PC geben. Er holt das Programm und startet `START-EINKAUF.cmd`.
2. Am Ende steht der **Handy-Link** am Bildschirm (`http://192.168.…:8787/?k=…`). Einmal am Handy im
   Restaurant-WLAN öffnen und als Lesezeichen speichern. Danach merkt sich das Gerät den Schlüssel.
3. Im Einkaufs-Chrome (eigenes Fenster) einmal bei Transgourmet anmelden, „angemeldet bleiben“ anhaken.
4. Claude am Kassen-PC erkundet den Shop und macht `shops/transgourmet.js` fertig (bis dahin steht
   Transgourmet in der App grau als „noch nicht eingerichtet“).

## Im Alltag

| Was | Wie |
|---|---|
| Anmelde-Stand | oben in der App: ✓ angemeldet · ✗ abgemeldet · ? unklar. Wird alle 30 Min. und beim Antippen geprüft |
| Abgemeldet | ✗ antippen → der Shop kommt am Kassen-PC nach vorne → dort anmelden |
| Suchen | Begriff eingeben → alle Treffer, je kg/l, Günstigster oben im goldenen Kasten |
| Plus | Menge wählen, Plus → liegt im Shop-Warenkorb (grüner Haken) oder rotes „!“ mit Grund |
| Bestellen | im Shop selbst, wie immer |

Der Kassen-PC muss laufen. Von außerhalb des WLANs geht es erst nach Abschnitt 7 (Zugang von außen).

## Dateien

| Datei | Zweck |
|---|---|
| `START-EINKAUF.cmd` | Doppelklick → Admin-Rechte → `EINKAUF-EINRICHTEN.ps1` |
| `EINKAUF-EINRICHTEN.ps1` | Ordner `C:\Lieperts\einkauf`, Node.js (tragbar, Prüfsumme), Schlüssel, Firewall (nur privates Netz), Aufgabe beim Anmelden |
| `EINKAUF-ENTFERNEN.ps1` | Rückweg (Ordner und Chrome-Profil bleiben) |
| `server.js` | das Programm (Webseite + Schnittstelle, Port 8787) |
| `chrome.js` | steuert das eigene Chrome (Profil `C:\Lieperts\chrome-einkauf`, Steuer-Port 9223 nur lokal) |
| `inhalt.js` | Preis je kg/l, gleiche Regeln wie die Einkaufs-App (nichts raten) |
| `shops/allgemein.js` | Shop-Treiber: Suche, Anmelde-Check, Warenkorb nach Einstellungen |
| `shops/transgourmet.js` | Transgourmet – **noch zu erkunden** (`fertig: false`) |
| `erkunden.js` | schreibt mit, wie ein Shop Suche und Warenkorb baut (nur lesen) |
| `public/index.html` | die App für Handy und Laptop |
| `test/` | Übungs-Shop und Ende-zu-Ende-Test: `node test/test.js` |

Schlüssel und Handy-Link liegen **nur** am Kassen-PC (`C:\Lieperts\einkauf\einstellungen.json`,
`handy-link.txt`) – dieses Repository ist öffentlich.

## Was das Programm nie tut

Kein „Bestellen“/„Bestellung absenden“ (der Treiber verweigert Knöpfe, die danach aussehen) · kein Passwort
tippen oder speichern · nur Positionen in den Warenkorb, die du mit dem Plus schickst · nichts in der Kassa.

## Stand

- 30.09.2026: Programm, App, Einrichtung und Test fertig. Ende-zu-Ende-Test gegen den Übungs-Shop grün
  (Schlüssel-Sperre, An-/Abmeldung erkannt, Suche mit Umrechnung – 6 × 0,5 l je Stück → €/l, Grundpreis vom
  Shop übernommen, Plus legt 3 Stück in den Warenkorb, „Jetzt bestellen“ unberührt).
- Offen: Transgourmet erkunden und einstellen (Claude am Kassen-PC), dann Rungis, R&S, hollu (Abschnitt 5),
  Katalog aus der Einkaufs-App übernehmen (6), Zugang von außen (7), Preise nachts auffrischen (8).
