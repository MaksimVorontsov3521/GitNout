// Parse a Quartus II simulation .vwf and check outputs against an expected table.
// Quartus 5.0 compresses transition lists with nested  NODE { REPEAT = k; ... }  blocks, so the
// walker is recursive: a nested block expands to its content repeated k times. Ignoring REPEAT
// truncates a channel's timeline and invents phantom mismatches (it made a correct dtm look wrong,
// and it is the real explanation for the earlier MUX4 "20 of 64" mystery).
const NL = String.fromCharCode(10);

function tokenize(body) {
  const out = [];
  const re = /NODE|REPEAT|LEVEL|FOR|[{}]|-?\d+(?:\.\d+)?|[01XZH]/g;
  let m;
  while ((m = re.exec(body)) !== null) {
    const s = m[0];
    if (s === '{' || s === '}') out.push({ kw: s });
    else if (s === 'NODE' || s === 'REPEAT' || s === 'LEVEL' || s === 'FOR') out.push({ kw: s });
    else if (/^-?[\d.]/.test(s)) out.push({ num: parseFloat(s) });
    else out.push({ lvl: s });
  }
  return out;
}

// Parse a sequence of items; stops at the matching '}' (consumes it when consume is true).
function parseSeq(tk, i, consume) {
  const items = [];
  while (i < tk.length) {
    const t = tk[i];
    if (t.kw === '}') { return { items, next: consume ? i + 1 : i, closed: true }; }
    if (t.kw === 'NODE') {
      i++;
      if (tk[i] && tk[i].kw === '{') i++;
      let repeat = 1;
      if (tk[i] && tk[i].kw === 'REPEAT') { i++; if (tk[i] && tk[i].num != null) { repeat = tk[i].num; i++; } }
      const inner = parseSeq(tk, i, true);
      for (let r = 0; r < repeat; r++) items.push(...inner.items);
      i = inner.next;
      continue;
    }
    if (t.kw === 'LEVEL') {
      i++;
      let level = 'X';
      if (tk[i] && tk[i].lvl != null) { level = tk[i].lvl; i++; }
      else if (tk[i] && tk[i].num != null) { level = String(tk[i].num); i++; }
      let dur = 0;
      if (tk[i] && tk[i].kw === 'FOR') {
        i++;
        if (tk[i] && tk[i].num != null) { dur = tk[i].num; i++; }
      }
      items.push({ level, dur });
      continue;
    }
    i++;
  }
  return { items, next: i, closed: false };
}

export function parseVwf(text) {
  const t = text.replace(/\r/g, '');
  const out = {};
  const re = /TRANSITION_LIST\("([^"]+)"\)\s*\{([\s\S]*?)\n\}/g;
  let m;
  while ((m = re.exec(t)) !== null) {
    const name = m[1];
    const tk = tokenize(m[2]);
    const { items } = parseSeq(tk, 0, false);
    const segs = [];
    let cur = 0;
    for (const it of items) { segs.push({ t0: cur, t1: cur + it.dur, level: it.level }); cur += it.dur; }
    out[name] = { segs, end: cur };
  }
  return out;
}

export function sampleAt(tl, name, t) {
  const e = tl[name];
  if (!e) return undefined;
  for (const s of e.segs) if (t >= s.t0 && t < s.t1) return s.level;
  return e.segs.length ? e.segs[e.segs.length - 1].level : undefined;
}

export function checkSim(vwfText, spec, sampleFrac) {
  const frac = sampleFrac == null ? 0.5 : sampleFrac;
  const tl = parseVwf(vwfText);
  const inputs = spec.inputs || [];
  const n = inputs.length;
  const rows = spec.vectors ? spec.vectors : Array.from({ length: 1 << n }, (_, i) => {
    const row = {};
    inputs.forEach((p, k) => { row[p] = (i >> (n - 1 - k)) & 1; });
    return row;
  });
  const period = Number(spec.period || 40);
  const errs = [];
  const got = {};
  for (const [sig, exp] of Object.entries(spec.expect || {})) {
    got[sig] = [];
    if (!tl[sig]) { errs.push('signal ' + sig + ' absent in simulation output'); continue; }
    rows.forEach((row, i) => {
      const t = i * period + period * frac;
      const v = sampleAt(tl, sig, t);
      got[sig].push(v);
      const want = String(exp[i]);
      if (v !== want) {
        const inp = inputs.map((p) => p + '=' + row[p]).join(' ');
        errs.push('row ' + i + ' (' + inp + '): ' + sig + ' expected ' + want + ', got ' + v);
      }
    });
  }
  return { errs, got, rows: rows.length };
}