// ============================================================
// Transgourmet Österreich — shop.transgourmet.at
//
// STAND: NOCH NICHT ERKUNDET (fertig: false).
// Aus der Cloud kommt man an den Shop nicht heran. Die Selektoren unten sind
// Platzhalter. Claude am Kassen-PC füllt sie aus, nachdem er mit
//   node erkunden.js transgourmet balsamico
// angesehen hat, wie der Shop die Suche, den Preis und den Warenkorb baut
// (siehe AUFTRAG-Claude-am-Kassen-PC-Einkauf.txt). Erst dann fertig: true.
//
// Bekannt aus der Einkaufs-App (Runbook): Schnellerfassung unter
//   https://shop.transgourmet.at/ctx:L2NhdGFsb2cy/quickadd
// ============================================================
'use strict';
const { treiber } = require('./allgemein');

module.exports = treiber({
  id: 'transgourmet',
  name: 'Transgourmet',
  start: 'https://shop.transgourmet.at/',
  netto: true,           // B2B-Shop: Preise ohne MwSt. — beim Erkunden bestätigen
  fertig: false,

  anmeldung: {
    url: 'https://shop.transgourmet.at/',
    angemeldet: 'TODO-selektor-nur-sichtbar-wenn-angemeldet',   // z. B. Kundenname / "Abmelden"
    abgemeldet: 'input[type="password"]',
  },

  suche: {
    art: 'navigieren',   // 'fetch' ist schneller, geht aber nur, wenn die Treffer im HTML stehen
    url: 'TODO-such-adresse-mit-{q}',
    kachel: 'TODO-selektor-je-artikel',
    name: 'TODO',
    artnr: 'TODO',
    preis: 'TODO',
    grundpreis: '',      // falls der Shop "1 l = …" anzeigt
    inhalt: '',
    vkeh: '',
    link: 'a@href',
    bild: 'img@src',
    jeStueck: true,      // gilt der Preis je Flasche/Stück? (beim Erkunden prüfen)
  },

  korb: {
    art: 'schnell',
    url: 'https://shop.transgourmet.at/ctx:L2NhdGFsb2cy/quickadd',
    nummer: 'TODO-feld-artikelnummer',
    menge: 'TODO-feld-menge',
    knopf: 'TODO-knopf-in-den-warenkorb',
    bestaetigt: '',
  },
});
