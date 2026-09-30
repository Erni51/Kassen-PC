// ============================================================
// Einen Shop erkunden — nur lesen.
//
//   node erkunden.js transgourmet balsamico            (sucht selbst über die Startseite, falls such-URL bekannt)
//   node erkunden.js transgourmet balsamico --sekunden 120
//
// Öffnet den Shop im Einkaufs-Chrome und schreibt 90 Sekunden lang mit,
// welche Anfragen der Shop macht (Adresse, Art, Status, bei JSON/HTML die
// Antwort). In der Zeit im Chrome-Fenster von Hand suchen, einen Artikel
// öffnen und den Warenkorb-Knopf ANSEHEN (nicht bestellen).
// Am Ende: erkundet\<shop>-<zeit>\anfragen.json und seite.html,
// dazu eine Liste der Antworten, in denen der Suchbegriff vorkommt.
//
// Keine Kopfzeilen, keine Cookies, keine Formulardaten werden gespeichert.
// ============================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { Chrome, warte } = require('./chrome');

const shopId = process.argv[2];
const begriff = process.argv[3] || '';
const sek = Number((process.argv[process.argv.indexOf('--sekunden') + 1]) || 0) || 90;
if (!shopId) { console.log('Aufruf: node erkunden.js <shop> <suchbegriff> [--sekunden 90]'); process.exit(1); }

const E = JSON.parse(fs.readFileSync(path.join(__dirname, 'einstellungen.json'), 'utf8').replace(/^\uFEFF/, ''));
const shop = require(path.join(__dirname, 'shops', shopId + '.js'));

(async () => {
  const chrome = new Chrome({
    pfad: E.chrome || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    profil: E.profil || 'C:\\Lieperts\\chrome-einkauf', port: E.chromePort || 9223,
  });
  const tab = await chrome.tab(shopId, shop.start);
  const ziel = path.join(__dirname, 'erkundet', shopId + '-' + new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19));
  fs.mkdirSync(ziel, { recursive: true });

  const anfragen = new Map();
  await tab.senden('Network.enable', { maxTotalBufferSize: 50e6, maxResourceBufferSize: 5e6 });
  tab.auf((m, p) => {
    if (m === 'Network.requestWillBeSent') {
      anfragen.set(p.requestId, { url: p.request.url, methode: p.request.method, art: p.type });
    } else if (m === 'Network.responseReceived') {
      const a = anfragen.get(p.requestId);
      if (a) { a.status = p.response.status; a.mime = p.response.mimeType; }
    } else if (m === 'Network.loadingFinished') {
      const a = anfragen.get(p.requestId);
      if (!a || !/json|html|javascript\+json|text\/plain/.test(a.mime || '') || /\.(js|css)(\?|$)/.test(a.url)) return;
      tab.senden('Network.getResponseBody', { requestId: p.requestId }).then((b) => {
        const t = b.base64Encoded ? '' : b.body;
        a.antwort = t.length > 300000 ? t.slice(0, 300000) + '…[gekürzt]' : t;
      }).catch(() => {});
    }
  });

  await tab.senden('Page.bringToFront');
  await tab.gehe(shop.start);
  console.log('Chrome ist offen. Jetzt ' + sek + ' Sekunden lang von Hand: nach "' + begriff + '" suchen, einen Artikel öffnen,');
  console.log('den Warenkorb ansehen. NICHT bestellen. Mitschrift läuft…');
  await warte(sek * 1000);

  const html = await tab.ausfuehren(() => document.documentElement.outerHTML).catch(() => '');
  fs.writeFileSync(path.join(ziel, 'seite.html'), html);
  fs.writeFileSync(path.join(ziel, 'adresse.txt'), await tab.adresse().catch(() => ''));
  const liste = [...anfragen.values()].filter((a) => !/google|facebook|doubleclick|hotjar|matomo|analytics|cookiebot|usercentrics/i.test(a.url));
  fs.writeFileSync(path.join(ziel, 'anfragen.json'), JSON.stringify(liste, null, 1));

  const b = begriff.toLowerCase();
  console.log('\nGespeichert in ' + ziel);
  console.log(liste.length + ' Anfragen. Mit dem Suchbegriff in der Antwort:');
  liste.filter((a) => b && a.antwort && a.antwort.toLowerCase().includes(b))
    .forEach((a) => console.log('  ' + a.methode + ' ' + a.status + ' ' + (a.mime || '') + '  ' + a.url.slice(0, 160)));
  tab.schliessen();
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
