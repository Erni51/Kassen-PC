// Ende-zu-Ende: Übungs-Shop + Programm + echtes Chrome (kopflos)
'use strict';
const { spawn } = require('child_process');
const path = require('path');
const { Chrome } = require('../chrome');
const warte = (ms) => new Promise(r => setTimeout(r, ms));
const K = 'test-schluessel-123456', B = 'http://127.0.0.1:8788';
const api = (p, d) => fetch(B + p, { method: d ? 'POST' : 'GET', headers: { 'X-Schluessel': K, 'Content-Type': 'application/json' }, body: d ? JSON.stringify(d) : undefined }).then(r => r.json());
let fehler = 0;
const pruefe = (ok, t) => { console.log((ok ? 'OK    ' : 'FEHLER') + ' ' + t); if (!ok) fehler++; };
async function chromeZu() {
  try {
    const v = await (await fetch('http://127.0.0.1:9333/json/version')).json();
    const ws = new WebSocket(v.webSocketDebuggerUrl);
    await new Promise(r => { ws.onopen = () => { ws.send(JSON.stringify({ id: 1, method: 'Browser.close' })); setTimeout(r, 800); }; ws.onerror = r; });
  } catch (e) {}
}
(async () => {
  await chromeZu();
  require('fs').rmSync(require('./einstellungen-test.json').profil, { recursive: true, force: true });
  const shop = spawn('node', [path.join(__dirname, 'testshop-server.js')], { stdio: 'inherit' });
  const srv = spawn('node', [path.join(__dirname, '..', 'server.js'), '--einstellungen', path.join(__dirname, 'einstellungen-test.json')], { stdio: 'inherit' });
  try {
    await warte(5000);
    pruefe((await fetch(B + '/api/status')).status === 401, 'ohne Schlüssel gesperrt');
    let st = await api('/api/status');
    pruefe(st.shops[0].angemeldet === false, 'abgemeldet erkannt');
    const s1 = await api('/api/suche?q=balsamico');
    pruefe(s1.fehler.testshop === 'abgemeldet', 'Suche meldet: abgemeldet');
    // Manuel meldet sich am Kassen-PC an (hier: Formular im Chrome-Tab abschicken)
    const c = new Chrome({ port: 9333 });
    const tab = await c.tab('testshop', 'http://127.0.0.1:8899/');
    await tab.ausfuehren(() => document.querySelector('form').submit());
    await warte(1500);
    st = await api('/api/status?neu=1');
    pruefe(st.shops[0].angemeldet === true, 'nach Anmeldung: angemeldet');
    const s2 = await api('/api/suche?q=balsamico');
    console.log(s2.treffer.map(t => '   ' + t.name + ' | ' + (t.vergleich ? t.vergleich.wert.toFixed(2) + '/' + t.vergleich.einheit + ' (' + t.vergleich.quelle + ')' : '-')).join('\n'));
    pruefe(s2.treffer.length === 5, '5 Treffer');
    pruefe(s2.treffer[0].name.startsWith('De Nigris') && s2.treffer[1].name.startsWith('Quality'), 'Günstigster oben: De Nigris 3,06 €/l, dann Quality 15,40 €/l (Grundpreis vom Shop)');
    pruefe(s2.treffer.find(t => t.artnr === '5645').vergleich.wert.toFixed(2) === '16.68', '6 x 0,5 l je Stück -> 16,68 €/l');
    pruefe(s2.treffer[s2.treffer.length - 1].vergleich.einheit === 'Stk', 'ohne Inhalt: je Stück, hinten');
    const q = s2.treffer[1];
    const k = await api('/api/korb', { shop: q.shop, artnr: q.artnr, url: q.url, name: q.name, menge: 3 });
    pruefe(k.ok === true, 'Plus: im Warenkorb (' + JSON.stringify(k) + ')');
    const korb = await (await fetch('http://127.0.0.1:8899/korb.json')).json();
    console.log('   Shop-Warenkorb:', JSON.stringify(korb));
    pruefe(korb['3795887'] === 3, 'Shop-Warenkorb enthält 3 x 3795887');
  } catch (e) { console.log('ABBRUCH', e); fehler++; }
  await chromeZu();
  srv.kill(); shop.kill();
  console.log(fehler ? fehler + ' Fehler' : 'Alles OK');
  process.exit(fehler ? 1 : 0);
})();
