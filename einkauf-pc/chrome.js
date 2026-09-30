// ============================================================
// Chrome fernsteuern — ohne Zusatzpakete (Node 22 hat WebSocket eingebaut)
//
// Das Programm startet ein EIGENES Chrome mit eigenem Profil
// (C:\Lieperts\chrome-einkauf). Darin meldet sich Manuel einmal bei den
// Shops an; die Anmeldung bleibt im Profil. Gesucht und in den Warenkorb
// gelegt wird IM Tab des Shops — dort gelten seine Anmeldung und die
// Regeln des Shops, als ob er selbst klickt.
// Der Steuer-Anschluss (Port 9223) hört nur auf 127.0.0.1.
// ============================================================
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');

const warte = (ms) => new Promise((r) => setTimeout(r, ms));

class Tab {
  constructor(info) {
    this.id = info.id;
    this.url = info.url;
    this.ws = null;
    this.nr = 0;
    this.offen = new Map();
    this.hoerer = new Set();
  }

  verbinden(wsUrl) {
    return new Promise((ok, fehler) => {
      const ws = new WebSocket(wsUrl);
      ws.onopen = () => { this.ws = ws; ok(this); };
      ws.onerror = (e) => fehler(new Error('Keine Verbindung zum Chrome-Tab: ' + (e.message || 'Fehler')));
      ws.onclose = () => {
        this.ws = null;
        for (const [, p] of this.offen) p.fehler(new Error('Chrome-Tab geschlossen'));
        this.offen.clear();
      };
      ws.onmessage = (m) => {
        const d = JSON.parse(typeof m.data === 'string' ? m.data : m.data.toString());
        if (d.id && this.offen.has(d.id)) {
          const p = this.offen.get(d.id);
          this.offen.delete(d.id);
          if (d.error) p.fehler(new Error(d.error.message || 'CDP-Fehler'));
          else p.ok(d.result);
        } else if (d.method) {
          for (const h of this.hoerer) { try { h(d.method, d.params || {}); } catch (e) { /* weiter */ } }
        }
      };
    });
  }

  senden(methode, params = {}, zeitMs = 45000) {
    if (!this.ws) return Promise.reject(new Error('Chrome-Tab nicht verbunden'));
    const id = ++this.nr;
    return new Promise((ok, fehler) => {
      const t = setTimeout(() => { this.offen.delete(id); fehler(new Error('Chrome antwortet nicht (' + methode + ')')); }, zeitMs);
      this.offen.set(id, {
        ok: (r) => { clearTimeout(t); ok(r); },
        fehler: (e) => { clearTimeout(t); fehler(e); },
      });
      this.ws.send(JSON.stringify({ id, method: methode, params }));
    });
  }

  auf(h) { this.hoerer.add(h); return () => this.hoerer.delete(h); }

  /* Eine Funktion IM Shop ausführen. fn wird als Text übergeben, args als JSON.
     Promise-Ergebnisse werden abgewartet. */
  async ausfuehren(fn, ...args) {
    const ausdruck = '(' + fn.toString() + ')(...' + JSON.stringify(args) + ')';
    const r = await this.senden('Runtime.evaluate', {
      expression: ausdruck, awaitPromise: true, returnByValue: true, userGesture: true,
    }, 60000);
    if (r.exceptionDetails) {
      const t = r.exceptionDetails.exception && r.exceptionDetails.exception.description;
      throw new Error('Fehler im Shop-Tab: ' + (t || r.exceptionDetails.text));
    }
    return r.result ? r.result.value : undefined;
  }

  async gehe(url, zeitMs = 30000) {
    await this.senden('Page.enable');
    const fertig = new Promise((ok) => {
      const aus = this.auf((m) => { if (m === 'Page.loadEventFired') { aus(); ok(); } });
      setTimeout(() => { aus(); ok(); }, zeitMs);
    });
    await this.senden('Page.navigate', { url });
    await fertig;
    await warte(400);
  }

  async adresse() {
    return this.ausfuehren(() => location.href);
  }

  /* Warten, bis ein Element da ist (oder Zeit um). */
  async warteAuf(selektor, zeitMs = 15000) {
    const ende = Date.now() + zeitMs;
    while (Date.now() < ende) {
      const da = await this.ausfuehren((s) => !!document.querySelector(s), selektor).catch(() => false);
      if (da) return true;
      await warte(300);
    }
    return false;
  }

  schliessen() { try { this.ws && this.ws.close(); } catch (e) { /* egal */ } }
}

class Chrome {
  constructor({ pfad, profil, port = 9223, kopflos = false }) {
    this.pfad = pfad;
    this.profil = profil;
    this.port = port;
    this.kopflos = kopflos;
    this.proz = null;
    this.tabs = new Map(); // Name -> Tab
  }

  basis() { return 'http://127.0.0.1:' + this.port; }

  async laeuft() {
    try {
      const r = await fetch(this.basis() + '/json/version', { signal: AbortSignal.timeout(1500) });
      return r.ok;
    } catch (e) { return false; }
  }

  /* Chrome starten, falls es nicht schon läuft (z. B. nach einem Programm-Neustart). */
  async starten() {
    if (await this.laeuft()) return;
    if (!fs.existsSync(this.pfad)) throw new Error('Chrome nicht gefunden: ' + this.pfad);
    const args = [
      '--remote-debugging-port=' + this.port,
      '--remote-debugging-address=127.0.0.1',
      '--user-data-dir=' + this.profil,
      '--no-first-run', '--no-default-browser-check',
      // Hintergrund-Tabs nicht einfrieren — sonst bleibt die Suche hängen
      '--disable-background-timer-throttling',
      '--disable-renderer-backgrounding',
      '--disable-backgrounding-occluded-windows',
      '--start-minimized',
    ];
    if (this.kopflos) args.push('--headless=new', '--no-sandbox');
    args.push('about:blank');
    this.proz = spawn(this.pfad, args, { detached: true, stdio: 'ignore' });
    this.proz.unref();
    for (let i = 0; i < 60; i++) {
      if (await this.laeuft()) return;
      await warte(250);
    }
    throw new Error('Chrome ist nicht angesprungen');
  }

  async liste() {
    const r = await fetch(this.basis() + '/json/list');
    return (await r.json()).filter((t) => t.type === 'page');
  }

  /* Je Shop ein fester Tab. Gibt es ihn schon (auch nach Neustart des Programms), wird er wiederverwendet. */
  async tab(name, startUrl) {
    const alt = this.tabs.get(name);
    if (alt && alt.ws) return alt;
    await this.starten();
    const host = new URL(startUrl).host;
    let info = (await this.liste()).find((t) => { try { return new URL(t.url).host === host; } catch (e) { return false; } });
    if (!info) {
      const r = await fetch(this.basis() + '/json/new?' + encodeURI(startUrl), { method: 'PUT' });
      info = await r.json();
      await warte(1500);
    }
    const tab = new Tab(info);
    await tab.verbinden(info.webSocketDebuggerUrl);
    await tab.senden('Runtime.enable');
    this.tabs.set(name, tab);
    return tab;
  }
}

module.exports = { Chrome, Tab, warte };
