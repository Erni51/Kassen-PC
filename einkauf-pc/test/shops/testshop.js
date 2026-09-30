'use strict';
const { treiber } = require('../../shops/allgemein');
module.exports = treiber({
  id: 'testshop', name: 'Testshop', start: 'http://127.0.0.1:8899/', netto: true, fertig: true,
  anmeldung: { url: 'http://127.0.0.1:8899/', angemeldet: '.kunde', abgemeldet: 'input[type="password"]' },
  suche: { art: 'fetch', url: 'http://127.0.0.1:8899/suche?q={q}', kachel: 'li.produkt', name: 'h3', artnr: '.nr',
           preis: '.preis', grundpreis: '.gp', link: 'a@href', bild: 'img@src', jeStueck: true },
  korb: { art: 'produktseite', menge: '.anzahl', knopf: '.in-korb', bestaetigt: '.ok' },
});
