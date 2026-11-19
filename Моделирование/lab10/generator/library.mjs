// Harvest authentic symbol/pin templates from real Quartus II 5.0 BDF files.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const S = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/sexpr.mjs').href);

export function portInfo(sym) {
  return S.kids(sym, 'port').map((p) => {
    const pt = S.ptOf(p);
    let dir = 'io';
    for (const c of p) { const h = S.head(c); if (h === 'input') { dir = 'input'; break; } if (h === 'output') { dir = 'output'; break; } if (h === 'bidirectional') { dir = 'bidirectional'; break; } if (h === 'tristate') { dir = 'tristate'; break; } }
    let label = null;
    for (const c of p) if (S.head(c) === 'text' && 'text' === S.head(c) && S.isStr(c[1])) { label = c[1].str; break; }
    return { label, dir, dx: pt ? pt[0] : 0, dy: pt ? pt[1] : 0 };
  });
}

export function sigOf(name, w, h, ports) {
  return name + '#' + w + 'x' + h + '#' + ports.map((p) => p.dir[0] + ':' + p.label + '@' + p.dx + ',' + p.dy).sort().join('|');
}

function walk(d) {
  if (!fs.existsSync(d)) return [];
  return fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(d, e.name)) : (e.name.toLowerCase().endsWith('.bdf') ? [path.join(d, e.name)] : []));
}

// tiers: lower rank = more trusted source
export function harvest(tiers, opts) {
  const o = opts || {};
  const best = {};
  const stats = {};
  tiers.forEach((tier, idx) => {
    const files = walk(tier.dir);
    stats[tier.name] = { files: files.length, taken: 0 };
    for (const f of files) {
      let ast;
      try { ast = S.parse(fs.readFileSync(f, 'latin1')); } catch (e) { continue; }
      for (const nd of ast) {
        const h = S.head(nd);
        if (h === 'symbol') {
          const rc = S.rectOf(nd);
          if (!rc) continue;
          const name = S.firstText(nd);
          if (!name) continue;
          const w = rc[2] - rc[0], hh = rc[3] - rc[1];
          const ports = portInfo(nd);
          if (!ports.length) continue;
          const orient = ports.every((p) => p.dy % 1 === 0) && (w <= hh && ports.some((p) => p.dx === Math.floor(w / 2) && (p.dy === 0 || p.dy === hh))) ? 'v' : 'h';
          const sig = sigOf(name, w, hh, ports);
          const rec = { name, w, h: hh, ports, node: nd, src: f, tier: tier.name, rank: idx, kind: 'primitive', orient };
          if (!best[sig]) { best[sig] = rec; stats[tier.name].taken++; }
        } else if (h === 'pin' && o.pins) {
          const rc = S.rectOf(nd);
          if (!rc) continue;
          let dir = null;
          for (const c of nd) { const ch = S.head(c); if (ch === 'input' || ch === 'output' || ch === 'bidirectional' || ch === 'tristate') { dir = ch; break; } }
          if (!dir) continue;
          const pt = S.ptOf(nd);
          const rot = nd.some((c) => S.head(c) === 'rotate90') ? 'v' : 'h';
          const w = rc[2] - rc[0], hh = rc[3] - rc[1];
          const key = 'pin#' + dir + '#' + rot + '#' + w + 'x' + hh + '#' + (pt ? pt.join(',') : '-');
          if (!best[key]) { best[key] = { name: dir, dir, rot, w, h: hh, pt, node: nd, src: f, tier: tier.name, rank: idx, kind: 'pin' }; stats[tier.name].taken++; }
        }
      }
    }
  });
  return { lib: best, stats };
}

export function pickPrimitives(lib) {
  const out = {};
  for (const rec of Object.values(lib)) {
    if (rec.kind !== 'primitive') continue;
    const cur = out[rec.name];
    const better = !cur || rec.orient === 'h' && cur.orient !== 'h' ||
      (rec.orient === cur.orient && (rec.ports.length > cur.ports.length || (rec.ports.length === cur.ports.length && rec.rank < cur.rank)));
    if (better) out[rec.name] = rec;
  }
  return out;
}

export function pickPins(lib, dir, rot) {
  const cands = Object.values(lib).filter((r) => r.kind === 'pin' && r.dir === dir && (!rot || r.rot === rot));
  cands.sort((a, b) => a.rank - b.rank || a.w * a.h - b.w * b.h);
  return cands[0] || null;
}
