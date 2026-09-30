// ============================================================
// Der allgemeine Shop-Treiber: alles, was ein Shop braucht, steht als
// Einstellung in shops/<shop>.js (Adressen und CSS-Selektoren).
// Selektor-Schreibweise:  "css"        -> Text des Elements
//                          "css@attr"   -> Attribut (z. B. "a.produkt@href")
//                          "@attr"      -> Attribut der Kachel selbst
// Gearbeitet wird IM Tab des Shops, mit Manuels Anmeldung.
// Nie "Bestellung absenden" — nur Warenkorb.
// ============================================================
'use strict';
const { warte } = require('../chrome');
const { aufbereiten } = require('../inhalt');

/* Läuft im Shop-Tab: Kacheln aus einem Dokument lesen. */
function lesenImShop(html, s, basis) {
  const doc = html ? new DOMParser().parseFromString(html, 'text/html') : document;
  const hol = (el, sel) => {
    if (!sel || !el) return '';
    let css = sel, attr = null;
    const at = sel.lastIndexOf('@');
    if (at >= 0) { css = sel.slice(0, at); attr = sel.slice(at + 1); }
    const z = css ? el.querySelector(css) : el;
    if (!z) return '';
    const v = attr ? (z.getAttribute(attr) || '') : (z.textContent || '');
    return v.replace(/\s+/g, ' ').trim();
  };
  const voll = (u) => { try { return u ? new URL(u, basis).href : ''; } catch (e) { return ''; } };
  return Array.from(doc.querySelectorAll(s.kachel)).slice(0, s.max || 60).map((k) => ({
    name: hol(k, s.name),
    artnr: hol(k, s.artnr),
    preis: hol(k, s.preis),
    grundpreisText: hol(k, s.grundpreis),
    inhaltText: hol(k, s.inhalt),
    vkeh: hol(k, s.vkeh),
    url: voll(hol(k, s.link)),
    bild: voll(hol(k, s.bild)),
  })).filter((t) => t.name);
}

/* Läuft im Shop-Tab: Menge setzen und Warenkorb-Knopf drücken. */
async function korbImShop(k, menge) {
  const warte = (ms) => new Promise((r) => setTimeout(r, ms));
  const feld = k.menge ? document.querySelector(k.menge) : null;
  if (feld) {
    const setzer = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setzer.call(feld, String(menge));
    feld.dispatchEvent(new Event('input', { bubbles: true }));
    feld.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const vorher = k.zaehler && document.querySelector(k.zaehler) ? document.querySelector(k.zaehler).textContent.trim() : null;
  const knopf = document.querySelector(k.knopf);
  if (!knopf) return { ok: false, hinweis: 'Warenkorb-Knopf nicht gefunden' };
  if (/bestell|kaufen\s*$|checkout|kasse/i.test(knopf.textContent || '') && !/warenkorb|korb|cart/i.test(knopf.textContent || '')) {
    return { ok: false, hinweis: 'Knopf sieht nach Bestellen aus — nicht gedrückt' };
  }
  knopf.click();
  for (let i = 0; i < 30; i++) {
    await warte(300);
    if (k.bestaetigt && document.querySelector(k.bestaetigt)) return { ok: true };
    if (vorher !== null && document.querySelector(k.zaehler) && document.querySelector(k.zaehler).textContent.trim() !== vorher) return { ok: true };
  }
  return { ok: !k.bestaetigt && vorher === null, hinweis: 'Keine Bestätigung vom Shop gesehen — bitte im Shop nachsehen' };
}

function treiber(cfg) {
  return {
    id: cfg.id,
    name: cfg.name,
    start: cfg.start,
    fertig: !!cfg.fertig,

    async anmeldung(tab) {
      const a = cfg.anmeldung;
      await tab.gehe(a.url);
      await warte(800);
      const r = await tab.ausfuehren((ja, nein) => ({
        ja: ja ? !!document.querySelector(ja) : false,
        nein: nein ? !!document.querySelector(nein) : false,
      }), a.angemeldet, a.abgemeldet);
      if (r.ja && !r.nein) return { angemeldet: true };
      if (r.nein) return { angemeldet: false, hinweis: 'Anmeldemaske sichtbar' };
      return { angemeldet: null, hinweis: 'Weder angemeldet noch Anmeldemaske erkannt — Selektoren prüfen' };
    },

    async suche(tab, begriff) {
      const s = cfg.suche;
      const url = s.url.replace('{q}', encodeURIComponent(begriff));
      let roh;
      if (s.art === 'fetch') {
        const html = await tab.ausfuehren(async (u) => {
          const r = await fetch(u, { credentials: 'include' });
          return r.ok ? r.text() : '';
        }, url);
        roh = await tab.ausfuehren(lesenImShop, html, s, url);
      } else {
        await tab.gehe(url);
        await tab.warteAuf(s.kachel, s.wartenMs || 10000);
        if (s.nachladenMs) await warte(s.nachladenMs);
        roh = await tab.ausfuehren(lesenImShop, null, s, url);
      }
      return roh.map((t) => aufbereiten(Object.assign(t, {
        shop: cfg.id, shopName: cfg.name, jeStueck: s.jeStueck !== false, netto: !!cfg.netto,
      })));
    },

    async inKorb(tab, zeile) {
      const k = cfg.korb;
      if (!k) return { ok: false, hinweis: 'Warenkorb für ' + cfg.name + ' noch nicht eingerichtet' };
      const menge = Math.max(1, Math.round(Number(zeile.menge) || 1));
      if (k.art === 'schnell') {
        await tab.gehe(k.url);
        await tab.warteAuf(k.nummer, 10000);
        return tab.ausfuehren(async (k2, artnr, menge2) => {
          const warte = (ms) => new Promise((r) => setTimeout(r, ms));
          const setz = (sel, w) => {
            const f = document.querySelector(sel); if (!f) return false;
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(f, String(w));
            f.dispatchEvent(new Event('input', { bubbles: true })); f.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          };
          if (!setz(k2.nummer, artnr)) return { ok: false, hinweis: 'Nummernfeld nicht gefunden' };
          await warte(600);
          if (k2.menge) setz(k2.menge, menge2);
          const kn = document.querySelector(k2.knopf);
          if (!kn) return { ok: false, hinweis: 'Knopf nicht gefunden' };
          const kt = kn.textContent || kn.value || '';
          if (/bestell|kaufen\s*$|checkout|kasse/i.test(kt) && !/warenkorb|korb|cart/i.test(kt)) {
            return { ok: false, hinweis: 'Knopf sieht nach Bestellen aus - nicht gedrueckt' };
          }
          kn.click();
          for (let i = 0; i < 30; i++) { await warte(300); if (!k2.bestaetigt || document.querySelector(k2.bestaetigt)) return { ok: true }; }
          return { ok: false, hinweis: 'Keine Bestätigung vom Shop' };
        }, k, zeile.artnr, menge);
      }
      // Standard: Produktseite öffnen, Menge setzen, Knopf
      if (!zeile.url) return { ok: false, hinweis: 'Keine Produktseite bekannt' };
      await tab.gehe(zeile.url);
      await tab.warteAuf(k.knopf, 10000);
      return tab.ausfuehren(korbImShop, k, menge);
    },
  };
}

module.exports = { treiber, lesenImShop };
