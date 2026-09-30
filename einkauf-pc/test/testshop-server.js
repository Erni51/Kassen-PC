// Übungs-Shop für den Test: Anmeldung per Cookie, Suche (HTML), Produktseiten, Warenkorb.
'use strict';
const http = require('http');
const ARTIKEL = [
  {nr:'3795887', name:'Quality Balsamico Glace 500ml', preis:'7,70 €', gp:'1 l = 15,40 €'},
  {nr:'1332998', name:'Kotanyi Balsamico Glace Classic 500 ml', preis:'10,39 €', gp:''},
  {nr:'5645', name:'Crema di Balsamico weiß 6 x 0,5 l', preis:'8,34 €', gp:''},
  {nr:'317925', name:'De Nigris Balsamico bianco 5 l', preis:'15,32 €', gp:''},
  {nr:'999', name:'Balsamico Glace Probierset', preis:'4,90 €', gp:''},
];
const korb = {};
const angemeldet = (req) => /sitzung=ok/.test(req.headers.cookie || '');
const seite = (req, inhalt) => '<!doctype html><html><body><header>' +
  (angemeldet(req) ? '<span class="kunde">Lieperts KG</span> <span id="korbzahl">' + Object.values(korb).reduce((a,b)=>a+b,0) + '</span>' : '<form action="/login" method="post"><input type="password" name="pw"><button>Anmelden</button></form>') +
  '</header>' + inhalt + '</body></html>';
const s = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (u.pathname === '/login' && req.method === 'POST') { res.writeHead(302, {'Set-Cookie':'sitzung=ok; Path=/', Location:'/'}); return res.end(); }
  if (u.pathname === '/suche') {
    const q = (u.searchParams.get('q') || '').toLowerCase().split(/\s+/);
    const t = ARTIKEL.filter(a => q.every(w => a.name.toLowerCase().includes(w)));
    return res.end(seite(req, '<ul>' + t.map(a => '<li class="produkt"><a href="/p/' + a.nr + '"><img src="/b/' + a.nr + '.png"><h3>' + a.name + '</h3></a><span class="nr">' + a.nr + '</span><span class="preis">' + a.preis + '</span><span class="gp">' + a.gp + '</span></li>').join('') + '</ul>'));
  }
  if (u.pathname.startsWith('/p/')) {
    const a = ARTIKEL.find(x => x.nr === u.pathname.slice(3));
    return res.end(seite(req, '<h1>' + a.name + '</h1><input class="anzahl" value="1"><button class="in-korb" onclick="fetch(\'/korb?nr=' + a.nr + '&m=\'+document.querySelector(\'.anzahl\').value,{method:\'POST\'}).then(()=>{document.body.insertAdjacentHTML(\'beforeend\',\'<div class=ok>Im Warenkorb</div>\')})">In den Warenkorb</button><button class="bestellen">Jetzt bestellen</button>'));
  }
  if (u.pathname === '/korb' && req.method === 'POST') {
    if (!angemeldet(req)) { res.writeHead(403); return res.end(); }
    korb[u.searchParams.get('nr')] = (korb[u.searchParams.get('nr')] || 0) + Number(u.searchParams.get('m'));
    return res.end('ok');
  }
  if (u.pathname === '/korb.json') { res.setHeader('Content-Type','application/json'); return res.end(JSON.stringify(korb)); }
  res.end(seite(req, '<h1>Startseite</h1>'));
});
s.listen(8899, '127.0.0.1');
