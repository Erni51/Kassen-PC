// ============================================================
// Preis je kg / je l — aus dem, was der Shop anzeigt.
// Dieselben Regeln wie in der Einkaufs-App (Artefakt, Version 44):
// Mehrfachpackungen nur, wenn der Preis sicher je Stück gilt; nichts raten.
// ============================================================
'use strict';

const EH = {
  kg: ['kg', 1], kgm: ['kg', 1], g: ['kg', 1e-3], gr: ['kg', 1e-3], grm: ['kg', 1e-3],
  l: ['l', 1], ltr: ['l', 1], lt: ['l', 1], ml: ['l', 1e-3], mlt: ['l', 1e-3],
  cl: ['l', 1e-2], clt: ['l', 1e-2], dl: ['l', 0.1],
};
const zahl = (s) => parseFloat(String(s).replace(/\s/g, '').replace(/\.(?=\d{3}(\D|$))/g, '').replace(',', '.'));

/* "12,90 €", "€ 1.234,50", "12.90" -> Zahl */
function preisAusText(t) {
  const m = String(t || '').replace(/ /g, ' ').match(/(\d{1,3}(?:[.\s]\d{3})*(?:,\d{1,2})|\d+(?:[.,]\d{1,2})?)/);
  return m ? zahl(m[1]) : null;
}

/* Grundpreis, wenn der Shop ihn selbst angibt: "1 l = 15,40 €", "15,40 €/kg", "€ 15,40 je Liter" */
function grundpreisAusText(t) {
  const s = String(t || '').replace(/ /g, ' ');
  let m = s.match(/1\s*(kg|l|liter|kilo)\s*=\s*(?:€\s*)?(\d+(?:[.,]\d+)?)/i);
  if (m) return { wert: zahl(m[2]), einheit: /^k/i.test(m[1]) ? 'kg' : 'l' };
  m = s.match(/(\d+(?:[.,]\d+)?)\s*€?\s*(?:\/|je|pro)\s*(kg|l|liter|kilo)\b/i);
  if (m) return { wert: zahl(m[1]), einheit: /^k/i.test(m[2]) ? 'kg' : 'l' };
  return null;
}

/* Inhalt EINES Stücks aus der Bezeichnung. "6 x 0,5 l" -> 0,5 l nur, wenn jeStueck. */
function inhaltAusText(t, jeStueck) {
  const s = String(t || '');
  const mal = s.match(/(\d{1,3})\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*-?\s*(kg|g|gr|grm|l|ltr|lt|ml|cl|dl)\b/i);
  if (mal) {
    const e = EH[mal[3].toLowerCase()];
    const v = zahl(mal[2]) * e[1];
    return jeStueck ? { e: e[0], v } : { e: e[0], v: v * parseInt(mal[1], 10) };
  }
  const werte = [];
  const re = /(?<![\d.,\/x×])(\d+(?:[.,]\d+)?)\s*-?\s*(kg|g|gr|grm|kgm|l|ltr|lt|ml|mlt|cl|dl)\b(?!\s*[x×\/]\s*\d)/gi;
  let m;
  while ((m = re.exec(s))) {
    const e = EH[m[2].toLowerCase()];
    werte.push({ e: e[0], v: zahl(m[1]) * e[1] });
  }
  if (!werte.length) return null;
  for (const w of werte) {
    if (w.e !== werte[0].e || Math.abs(w.v - werte[0].v) > 0.02 * werte[0].v) return null; // widersprüchlich
  }
  return werte[0].v > 0 ? werte[0] : null;
}

/* Einen Treffer fertig machen: Vergleichspreis je kg/l, sonst je Stück. */
function aufbereiten(t) {
  const r = Object.assign({}, t);
  r.preis = typeof t.preis === 'number' ? t.preis : preisAusText(t.preis);
  const gp = grundpreisAusText(t.grundpreisText);
  if (gp && gp.wert > 0) {
    r.vergleich = { wert: gp.wert, einheit: gp.einheit, quelle: 'shop' };
  } else if (r.preis > 0) {
    const inh = inhaltAusText([t.name, t.inhaltText].filter(Boolean).join(' '), t.jeStueck !== false);
    if (inh && r.preis / inh.v >= 0.2) {
      r.inhalt = inh;
      r.vergleich = { wert: r.preis / inh.v, einheit: inh.e, quelle: 'gerechnet' };
    } else {
      r.vergleich = { wert: r.preis, einheit: 'Stk', quelle: 'stueck' };
    }
  } else {
    r.vergleich = null;
  }
  return r;
}

/* Alle Treffer aller Shops: kg bzw. l (die häufigere Einheit zuerst), dann Stück, dann ohne Preis. */
function sortieren(liste) {
  const n = { kg: 0, l: 0 };
  liste.forEach((t) => { if (t.vergleich && n[t.vergleich.einheit] !== undefined) n[t.vergleich.einheit]++; });
  const erst = n.l > n.kg ? 'l' : 'kg';
  const rang = (t) => !t.vergleich ? 3 : t.vergleich.einheit === erst ? 0 : (t.vergleich.einheit === 'Stk' ? 2 : 1);
  liste.sort((a, b) => rang(a) - rang(b) || ((a.vergleich ? a.vergleich.wert : 0) - (b.vergleich ? b.vergleich.wert : 0)));
  return { liste, erst };
}

module.exports = { preisAusText, grundpreisAusText, inhaltAusText, aufbereiten, sortieren };
