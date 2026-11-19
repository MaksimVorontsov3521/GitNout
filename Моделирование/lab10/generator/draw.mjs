// Turn .bdf sheets and Quartus simulation .vwf files into a neutral draw model (JSON) that a
// rasteriser can paint. Geometry comes straight from the files, so the picture is the design
// Quartus itself parsed - not a re-drawing from memory.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const S = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/sexpr.mjs').href);
const C = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/simcheck.mjs').href);

const rectOf = (n) => { const r = S.kid(n, 'rect'); return r && r.length >= 5 ? [Number(r[1]), Number(r[2]), Number(r[3]), Number(r[4])] : null; };
const ptsOf = (n) => S.kids(n, 'pt').filter((p) => p.length >= 3).map((p) => [Number(p[1]), Number(p[2])]);
const dirOf = (n) => { for (const c of n) { const h = S.head(c); if (['input', 'output', 'bidirectional', 'tristate'].includes(h)) return h; } return null; };
const txts = (n) => S.kids(n, 'text').filter((t) => S.isStr(t[1])).map((t) => ({ s: t[1].str, rect: rectOf(t) }));

export function bdfModel(bdfText) {
  const ast = S.parse(bdfText);
  const nodes = Array.isArray(ast) ? ast : [ast];
  const shapes = [];
  let maxX = 0, maxY = 0;
  const track = (x, y) => { if (x > maxX) maxX = x; if (y > maxY) maxY = y; };
  for (const nd of nodes) {
    const h = S.head(nd);
    if (h === 'symbol') {
      const rc = rectOf(nd); if (!rc) continue;
      const [x0, y0, x1, y1] = rc;
      track(x1, y1);
      shapes.push({ kind: 'rect', x: x0, y: y0, w: x1 - x0, h: y1 - y0, fill: '#fffdf5', stroke: '#909090' });
      const dr = S.kid(nd, 'drawing');
      if (dr) for (const c of dr) {
        const ch = S.head(c);
        if (ch === 'rectangle') { const r = rectOf(c); if (r) shapes.push({ kind: 'rect', x: x0 + r[0], y: y0 + r[1], w: r[2] - r[0], h: r[3] - r[1], fill: null, stroke: '#1a1a1a', wpx: 2 }); }
        else if (ch === 'line') { const p = ptsOf(c); if (p.length === 2) shapes.push({ kind: 'line', x1: x0 + p[0][0], y1: y0 + p[0][1], x2: x0 + p[1][0], y2: y0 + p[1][1], stroke: '#1a1a1a', wpx: 2 }); }
        else if (ch === 'circle') { const r = rectOf(c); if (r) shapes.push({ kind: 'circle', cx: x0 + (r[0] + r[2]) / 2, cy: y0 + (r[1] + r[3]) / 2, rad: (r[2] - r[0]) / 2, fill: '#ffffff', stroke: '#1a1a1a', wpx: 2 }); }
      }
      txts(nd).forEach((t, i) => {
        if (!t.rect) return;
        shapes.push({ kind: 'text', x: x0 + t.rect[0], y: y0 + t.rect[1] + 11, s: t.s, size: i === 0 ? 13 : 10, colour: i === 0 ? '#0b3d91' : '#666', bold: i === 0 });
      });
      for (const p of S.kids(nd, 'port')) {
        const pp = ptsOf(p); if (!pp.length) continue;
        const d = dirOf(p);
        shapes.push({ kind: 'dot', cx: x0 + pp[0][0], cy: y0 + pp[0][1], rad: 3, colour: d === 'input' ? '#0a7d33' : d === 'output' ? '#b3300f' : '#777' });
      }
    } else if (h === 'pin') {
      const rc = rectOf(nd); if (!rc) continue;
      const [x0, y0, x1, y1] = rc;
      track(x1, y1);
      const d = dirOf(nd);
      shapes.push({ kind: 'rect', x: x0, y: y0, w: x1 - x0, h: y1 - y0, fill: d === 'input' ? '#eaf6ff' : '#fff1ea', stroke: d === 'input' ? '#2477b8' : '#b3542a', wpx: 2 });
      for (const t of txts(nd)) {
        if (['INPUT', 'OUTPUT', 'VCC', 'GND'].includes(t.s) || !t.rect) continue;
        shapes.push({ kind: 'text', x: x0 + t.rect[0], y: y0 + t.rect[1] + 12, s: t.s, size: 12, colour: '#102a43', bold: true });
      }
    } else if (h === 'connector') {
      const p = ptsOf(nd);
      for (const q of p) track(q[0], q[1]);
      const bus = S.kids(nd, 'bus').length > 0;
      for (let i = 0; i + 1 < p.length; i++) shapes.push({ kind: 'line', x1: p[i][0], y1: p[i][1], x2: p[i + 1][0], y2: p[i + 1][1], stroke: '#111111', wpx: bus ? 3 : 2, dash: bus ? [7, 3] : null });
      const lbl = txts(nd)[0];
      if (lbl && lbl.rect) shapes.push({ kind: 'text', x: lbl.rect[0], y: lbl.rect[1] + 12, s: lbl.s, size: 11, colour: '#7a007a', bold: true });
    } else if (h === 'junction') {
      const p = ptsOf(nd)[0];
      if (p) { track(p[0], p[1]); shapes.push({ kind: 'dot', cx: p[0], cy: p[1], rad: 4, colour: '#111111' }); }
    }
  }
  return { width: maxX, height: maxY, shapes };
}

function vwfSections(text) {
  const t = text.replace(/\r/g, '');
  const out = { signals: new Map(), groups: [], order: [] };
  const reS = /SIGNAL\("([^"]+)"\)\s*\{([\s\S]*?)\n\}/g;
  let m;
  while ((m = reS.exec(t)) !== null) {
    const body = m[2];
    const kv = (k) => { const r = body.match(new RegExp(k + '\\s*=\\s*"([^"]*)"|' + k + '\\s*=\\s*([A-Za-z0-9_]+)')); return r ? (r[1] !== undefined ? r[1] : r[2]) : null; };
    out.signals.set(m[1], { type: kv('SIGNAL_TYPE'), width: Number(kv('WIDTH') || 1), dir: kv('DIRECTION'), parent: kv('PARENT') || '' });
  }
  const reG = /GROUP\("([^"]+)"\)\s*\{([\s\S]*?)\n\}/g;
  while ((m = reG.exec(t)) !== null) {
    const mem = (m[2].match(/"([^"]+)"/g) || []).map((s) => s.slice(1, -1));
    out.groups.push({ name: m[1], members: mem });
  }
  const reD = /DISPLAY_LINE\s*\{([\s\S]*?)\n\}/g;
  while ((m = reD.exec(t)) !== null) {
    const ch = m[1].match(/CHANNEL\s*=\s*"([^"]+)"/);
    const rad = m[1].match(/RADIX\s*=\s*(\w+)/);
    const lvl = m[1].match(/TREE_LEVEL\s*=\s*(\d+)/);
    if (ch) out.order.push({ name: ch[1], radix: rad ? rad[1] : 'Binary', level: Number(lvl ? lvl[1] : 0) });
  }
  return out;
}

function busValue(segs, members, t, radix) {
  const bits = members.map((m) => { const e = segs[m]; if (!e) return null; for (const s of e.segs) if (t >= s.t0 && t < s.t1) return s.level; return e.segs.length ? e.segs[e.segs.length - 1].level : null; });
  if (bits.some((b) => b === null || b === 'X' || b === 'Z' || b === 'H' || b === 'U')) return 'XXXX';
  const v = bits.reduce((acc, b) => acc * 2 + Number(b), 0);
  if (radix === 'Hex') return v.toString(16).toUpperCase().padStart(Math.ceil(members.length / 4), '0');
  if (radix === 'Unsigned' || radix === 'Signed') return String(v);
  return bits.join('');
}

export function vwfModel(vwfText, opts) {
  const o = opts || {};
  const sec = vwfSections(vwfText);
  const tl = C.parseVwf(vwfText);
  const end = Math.max(...Object.values(tl).map((e) => e.end), 1);
  const rows = [];
  const memberOf = new Map();
  for (const [, e] of sec.signals) if (e.parent) { if (!memberOf.has(e.parent)) memberOf.set(e.parent, []); memberOf.get(e.parent).push(e.name); }
  for (const d of sec.order) {
    const info = sec.signals.get(d.name);
    const kids = memberOf.get(d.name);
    if (info && info.type === 'BUS' && kids && kids.length) {
      const marks = [];
      let t = 0;
      while (t < end) {
        const val = busValue(tl, kids, t + 0.001, d.radix);
        let t1 = t + 1;
        while (t1 < end && busValue(tl, kids, t1 + 0.001, d.radix) === val) t1++;
        marks.push({ t0: t, t1, val });
        t = t1;
      }
      rows.push({ name: d.name, kind: 'bus', radix: d.radix, marks, dir: info.dir });
    } else if (tl[d.name]) {
      rows.push({ name: d.name, kind: 'bit', segs: tl[d.name].segs, dir: info ? info.dir : 'OUTPUT', level: d.level });
    }
  }
  return { end, rows, groups: sec.groups };
}

if (process.argv[1] && process.argv[1].endsWith('draw.mjs')) {
  const mode = process.argv[2], inF = process.argv[3], outF = process.argv[4];
  const model = mode === 'bdf' ? bdfModel(fs.readFileSync(inF, 'latin1')) : vwfModel(fs.readFileSync(inF, 'latin1'), {});
  fs.writeFileSync(outF, JSON.stringify(model));
  console.log('model ' + mode + ' ' + inF + ' -> ' + outF + ' (' + (model.shapes ? model.shapes.length : model.rows.length) + ' items)');
}
