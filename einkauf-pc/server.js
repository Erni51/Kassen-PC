// ============================================================
// Lieperts Einkauf — Programm am Kassen-PC
//
// Eine kleine Webseite (Port 8787) für Handy und Laptop. Sie sucht LIVE in
// den Shops, rechnet auf €/kg bzw. €/l um, zeigt den Günstigsten oben und
// legt mit dem Plus in den echten Shop-Warenkorb. Bestellen tut Manuel selbst.
// Kein Claude nötig, kein Nutzungslimit.
//
//   node server.js                      (Einstellungen: einstellungen.json daneben)
//   node server.js --einstellungen <datei>
//
// Zugriff nur mit Schlüssel (?k=… einmal, dann merkt es sich das Gerät).
// ============================================================
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Chrome } = require('./chrome');
const { sortieren } = require('./inhalt');

const ORDNER = __dirname;
const argEinst = process.argv.indexOf('--einstellungen');
const EINST_DATEI = argEinst > 0 ? process.argv[argEinst + 1] : path.join(ORDNER, 'einstellungen.json');
const E = JSON.parse(fs.readFileSync(EINST_DATEI, 'utf8').replace(/^\uFEFF/, ''));
const PORT = E.port || 8787;
const LOG = E.protokoll || path.join(ORDNER, 'einkauf.log');

function log(t) {
  const z = new Date().toISOString().replace('T', ' ').slice(0, 19) + '  ' + t;
  try { fs.appendFileSync(LOG, z + '\n'); } catch (e) { /* egal */ }
  if (!E.still) console.log(z);
}

if (!E.schluessel || String(E.schluessel).length < 12) {
  console.error('In ' + EINST_DATEI + ' fehlt "schluessel" (mindestens 12 Zeichen).');
  process.exit(1);
}

// ---- Shops laden ----
const SHOP_ORDNER = E.shopOrdner ? path.resolve(path.dirname(EINST_DATEI), E.shopOrdner) : path.join(ORDNER, 'shops');
const SHOPS = {};
(E.shops || ['transgourmet']).forEach((id) => {
  try { SHOPS[id] = require(path.join(SHOP_ORDNER, id + '.js')); }
  catch (e) { log('Shop ' + id + ' nicht geladen: ' + e.message); }
});

const chrome = new Chrome({
  pfad: E.chrome || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  profil: E.profil || 'C:\\Lieperts\\chrome-einkauf',
  port: E.chromePort || 9223,
  kopflos: !!E.kopflos,
});

// Je Shop läuft immer nur eine Sache gleichzeitig im Tab (Suche ODER Warenkorb).
const schlange = {};
function nacheinander(id, arbeit) {
  const vorher = schlange[id] || Promise.resolve();
  const jetzt = vorher.catch(() => {}).then(arbeit);
  schlange[id] = jetzt.catch(() => {});
  return jetzt;
}
async function mitTab(id, arbeit) {
  const s = SHOPS[id];
  return nacheinander(id, async () => {
    const tab = await chrome.tab(id, s.start);
    return arbeit(tab, s);
  });
}

// ---- Anmelde-Stand ----
const stand = {}; // id -> {angemeldet, hinweis, geprueft}
async function anmeldungPruefen(id) {
  const s = SHOPS[id];
  if (!s.fertig) { stand[id] = { angemeldet: null, hinweis: 'noch nicht eingerichtet', geprueft: new Date().toISOString() }; return stand[id]; }
  try {
    const r = await mitTab(id, (tab, shop) => shop.anmeldung(tab));
    stand[id] = Object.assign({ geprueft: new Date().toISOString() }, r);
  } catch (e) {
    stand[id] = { angemeldet: null, hinweis: e.message, geprueft: new Date().toISOString() };
  }
  log('Anmeldung ' + id + ': ' + (stand[id].angemeldet === true ? 'ja' : stand[id].angemeldet === false ? 'NEIN' : '?') + (stand[id].hinweis ? ' (' + stand[id].hinweis + ')' : ''));
  return stand[id];
}
async function alleAnmeldungen() {
  await Promise.all(Object.keys(SHOPS).map(anmeldungPruefen));
}

function statusListe() {
  return Object.keys(SHOPS).map((id) => Object.assign(
    { id, name: SHOPS[id].name, start: SHOPS[id].start, fertig: SHOPS[id].fertig }, stand[id] || {}));
}

// ---- Suche ----
async function suchen(begriff) {
  const ids = Object.keys(SHOPS).filter((id) => SHOPS[id].fertig);
  const fehler = {};
  const teile = await Promise.all(ids.map(async (id) => {
    if (stand[id] && stand[id].angemeldet === false) { fehler[id] = 'abgemeldet'; return []; }
    try {
      return await mitTab(id, (tab, shop) => shop.suche(tab, begriff));
    } catch (e) { fehler[id] = e.message; log('Suche ' + id + ' "' + begriff + '": ' + e.message); return []; }
  }));
  const { liste, erst } = sortieren([].concat(...teile));
  log('Suche "' + begriff + '": ' + liste.length + ' Treffer' + (Object.keys(fehler).length ? ', Fehler: ' + JSON.stringify(fehler) : ''));
  return { begriff, erst, treffer: liste, fehler, nichtEingerichtet: Object.keys(SHOPS).filter((id) => !SHOPS[id].fertig).map((id) => SHOPS[id].name) };
}

// ---- Warenkorb ----
async function inKorb(z) {
  const s = SHOPS[z.shop];
  if (!s) return { ok: false, hinweis: 'Unbekannter Shop' };
  if (!s.fertig) return { ok: false, hinweis: s.name + ' ist noch nicht eingerichtet' };
  try {
    const r = await mitTab(z.shop, (tab, shop) => shop.inKorb(tab, z));
    log('Warenkorb ' + z.shop + ' ' + (z.artnr || '') + ' "' + (z.name || '') + '" x' + z.menge + ': ' + (r.ok ? 'OK' : 'NEIN ' + (r.hinweis || '')));
    return r;
  } catch (e) {
    log('Warenkorb ' + z.shop + ' Fehler: ' + e.message);
    return { ok: false, hinweis: e.message };
  }
}

// ---- Webseite ----
function schluesselOk(req, url) {
  const k = req.headers['x-schluessel'] || url.searchParams.get('k') || '';
  return k.length === String(E.schluessel).length && require('crypto').timingSafeEqual(Buffer.from(k), Buffer.from(String(E.schluessel)));
}
function json(res, code, daten) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(daten));
}
function koerper(req) {
  return new Promise((ok) => {
    let d = '';
    req.on('data', (c) => { d += c; if (d.length > 1e5) req.destroy(); });
    req.on('end', () => { try { ok(JSON.parse(d || '{}')); } catch (e) { ok({}); } });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  try {
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      return res.end(fs.readFileSync(path.join(ORDNER, 'public', 'index.html')));
    }
    if (!url.pathname.startsWith('/api/')) { res.writeHead(404); return res.end(); }
    if (!schluesselOk(req, url)) return json(res, 401, { fehler: 'Schlüssel fehlt oder falsch' });

    if (url.pathname === '/api/status') {
      if (url.searchParams.get('neu')) await alleAnmeldungen();
      return json(res, 200, { shops: statusListe() });
    }
    if (url.pathname === '/api/suche') {
      const q = (url.searchParams.get('q') || '').trim().slice(0, 80);
      if (q.length < 2) return json(res, 400, { fehler: 'Suchbegriff zu kurz' });
      return json(res, 200, await suchen(q));
    }
    if (url.pathname === '/api/korb' && req.method === 'POST') {
      const z = await koerper(req);
      return json(res, 200, await inKorb({
        shop: String(z.shop || ''), artnr: String(z.artnr || '').slice(0, 40), url: String(z.url || '').slice(0, 500),
        name: String(z.name || '').slice(0, 200), menge: Math.min(99, Math.max(1, parseInt(z.menge, 10) || 1)),
      }));
    }
    if (url.pathname === '/api/anmelden' && req.method === 'POST') {
      // Holt den Shop am Kassen-PC nach vorne — dort meldet sich Manuel an.
      const z = await koerper(req);
      const s = SHOPS[z.shop];
      if (!s) return json(res, 400, { fehler: 'Unbekannter Shop' });
      await mitTab(z.shop, async (tab) => { await tab.gehe(s.start); await tab.senden('Page.bringToFront'); });
      return json(res, 200, { ok: true });
    }
    json(res, 404, { fehler: 'Unbekannt' });
  } catch (e) {
    log('Fehler ' + url.pathname + ': ' + e.message);
    json(res, 500, { fehler: e.message });
  }
});

server.listen(PORT, E.adresse || '0.0.0.0', async () => {
  log('Einkauf läuft auf Port ' + PORT + ' — Shops: ' + Object.keys(SHOPS).join(', '));
  try { await chrome.starten(); } catch (e) { log('Chrome: ' + e.message); }
  await alleAnmeldungen();
  setInterval(alleAnmeldungen, (E.pruefenMinuten || 30) * 60000);
});
