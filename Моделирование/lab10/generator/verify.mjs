// Independent connectivity verifier: rebuild nets from a .bdf purely from geometry.
import { pathToFileURL } from 'node:url';
const S = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/sexpr.mjs').href);

export function netlistFromBdf(text) {
  const ast = S.parse(text);
  const ports = [];
  for (const nd of ast) {
    const h = S.head(nd);
    if (h !== 'symbol' && h !== 'pin') continue;
    const rc = S.rectOf(nd);
    if (!rc) continue;
    if (h === 'pin') {
      let dir = null;
      for (const c of nd) { const ch = S.head(c); if (ch === 'input' || ch === 'output' || ch === 'bidirectional' || ch === 'tristate') { dir = ch; break; } }
      const names = S.kids(nd, 'text').filter((t) => S.isStr(t[1])).map((t) => t[1].str);
      const nm = names.find((v) => v !== 'INPUT' && v !== 'OUTPUT' && v !== 'VCC' && v !== 'GND');
      const pt = S.ptOf(nd);
      if (pt) ports.push({ ref: nm, dir, x: rc[0] + pt[0], y: rc[1] + pt[1], kind: 'pin' });
    } else {
      const ents = S.kids(nd, 'text').filter((t) => S.isStr(t[1])).map((t) => t[1].str);
      const ent = ents[0], inst = ents[1] || 'inst';
      for (const p of S.kids(nd, 'port')) {
        const pt = S.ptOf(p);
        if (!pt) continue;
        let dir = 'io';
        for (const c of p) { const ch = S.head(c); if (ch === 'input' || ch === 'output' || ch === 'bidirectional' || ch === 'tristate') { dir = ch; break; } }
        let label = null;
        for (const c of p) if (S.head(c) === 'text' && S.isStr(c[1])) { label = c[1].str; break; }
        ports.push({ ref: inst + '.' + label, dir, x: rc[0] + pt[0], y: rc[1] + pt[1], kind: 'symbol', entity: ent });
      }
    }
  }
  const pts = new Map();
  const key = (x, y) => x + ',' + y;
  const segs = [];
  for (const nd of ast) {
    if (S.head(nd) !== 'connector') continue;
    const ps = nd.filter((c) => S.head(c) === 'pt').map((c) => c.slice(1).map(Number));
    if (ps.length < 2) continue;
    segs.push(ps);
    for (const [x, y] of ps) { if (!pts.has(key(x, y))) pts.set(key(x, y), { x, y, ends: 0 }); pts.get(key(x, y)).ends++; }
  }
  const jun = new Set(ast.filter((n) => S.head(n) === 'junction').map((n) => { const p = S.ptOf(n); return p ? key(p[0], p[1]) : ''; }));
  const parent = new Map();
  const find = (a) => { while (parent.get(a) !== a) { parent.set(a, parent.get(parent.get(a))); a = parent.get(a); } return a; };
  const union = (a, b) => { if (!parent.has(a)) parent.set(a, a); if (!parent.has(b)) parent.set(b, b); const ra = find(a), rb = find(b); if (ra !== rb) parent.set(ra, rb); };
  for (const ps of segs) {
    for (const [x, y] of ps) { const k = key(x, y); if (!parent.has(k)) parent.set(k, k); }
    for (let i = 0; i < ps.length - 1; i++) union(key(ps[i][0], ps[i][1]), key(ps[i + 1][0], ps[i + 1][1]));
  }
  for (const [k, v] of pts) if (v.ends >= 3 || jun.has(k)) { /* junction points already unified by shared key */ }
  const groups = new Map();
  for (const p of ports) {
    const k = key(p.x, p.y);
    if (!parent.has(k)) parent.set(k, k);
    const root = find(k);
    if (!groups.has(root)) groups.set(root, []);
    groups.get(root).push(p);
  }
  const dangling = [];
  for (const v of pts.values()) {
    const k = key(v.x, v.y);
    if (!parent.has(k)) continue;
    const g = groups.get(find(k));
    if (!g || g.length === 0) dangling.push({ x: v.x, y: v.y });
  }
  const crossCheck = [];
  for (const [k, v] of pts) {
    if (v.ends < 3 && !jun.has(k)) continue;
    const root = find(k);
    const g = groups.get(root) || [];
    crossCheck.push({ point: k, ends: v.ends, ports: g.map((p) => p.ref) });
  }
  return { ports, segs, groups, dangling, junctions: [...jun], crossCheck };
}

export function compareWithSpec(nl, spec) {
  const par = new Map();
  const find = (a) => { if (!par.has(a)) par.set(a, a); while (par.get(a) !== a) { par.set(a, par.get(par.get(a))); a = par.get(a); } return a; };
  const uni = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) par.set(ra, rb); };
  for (const [a, b] of spec.connect || []) uni(a, b);
  const wantGroups = new Map();
  for (const [a, b] of spec.connect || []) for (const r of [a, b]) {
    const root = find(r);
    if (!wantGroups.has(root)) wantGroups.set(root, new Set());
    wantGroups.get(root).add(r);
  }
  const dirOf = new Map();
  for (const pt of nl.ports) dirOf.set(pt.ref, pt.dir);
  const geoGroups = new Map();
  for (const [g, plist] of nl.groups) geoGroups.set(g, new Set(plist.map((p) => p.ref)));
  const norm = (s) => [...s].sort().join(',');
  const wantSets = [...wantGroups.values()].map(norm).sort();
  // A singleton group whose only member is an output port is an intentionally unconnected
  // sub-design output (legal in Quartus, and required by the lab for the En pins of U1-U3).
  // A singleton group on an INPUT port is a real defect: Quartus refuses undriven inputs.
  const danglingInputs = [];
  const danglingOutputs = [];
  const geoSets = [];
  for (const [, s] of geoGroups) {
    if (s.size === 1) {
      const only = [...s][0];
      const d = dirOf.get(only);
      if (d === 'output' || d === 'tristate') { danglingOutputs.push(only); continue; }
      if (d === 'input') { danglingInputs.push(only); continue; }
    }
    geoSets.push(norm(s));
  }
  geoSets.sort();
  const errs = [];
  for (const di of danglingInputs) errs.push('undriven input port ' + di);
  const missing = wantSets.filter((x) => geoSets.indexOf(x) < 0);
  const extra = geoSets.filter((x) => wantSets.indexOf(x) < 0);
  if (missing.length) errs.push('expected nets not formed: ' + missing.join(' | '));
  if (extra.length) errs.push('unexpected nets formed: ' + extra.join(' | '));
  if (nl.dangling.length) errs.push('dangling wire endpoints: ' + nl.dangling.slice(0, 8).map((d) => d.x + ',' + d.y).join(' '));
  for (const [, g] of geoGroups) {
    const seen = new Set();
    for (const r of g) { if (seen.has(r)) errs.push('duplicate port ' + r + ' in one net'); seen.add(r); }
  }
  return errs;
}