// Orthogonal grid router for Quartus II BDF wiring.
// Connectivity model verified against authentic Quartus-authored BDF files:
//   - wires connect only where segment ENDPOINTS coincide, or at an explicit junction
//   - perpendicular interior crossing = NOT connected (438 real cases, 0 junctions there)
//   - same-direction overlap of two nets = short circuit (forbidden)
//   - an endpoint of net X lying strictly inside a run of net Y = illegal T (forbidden)
//   - junction is emitted only at a non-port point where >=3 endpoints of ONE net meet
const U = 8;
const DX = [1, -1, 0, 0], DY = [0, 0, 1, -1];
const isH = (d) => d === 0 || d === 1;
const OUTD = { r: 0, l: 1, d: 2, u: 3 };

export function route(req) {
  const gw = Math.ceil(req.width / U) + 2;
  const gh = Math.ceil(req.height / U) + 2;
  const N = gw * gh;
  const ci = (x, y) => y * gw + x;
  const px = (c) => (c % gw) * U;
  const py = (c) => Math.floor(c / gw) * U;

  const blocked = new Uint8Array(N);
  for (const o of req.obstacles || []) {
    const x0 = Math.floor(Math.min(o.x0, o.x1) / U), x1 = Math.ceil(Math.max(o.x0, o.x1) / U);
    const y0 = Math.floor(Math.min(o.y0, o.y1) / U), y1 = Math.ceil(Math.max(o.y0, o.y1) / U);
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (x >= 0 && y >= 0 && x < gw && y < gh) blocked[ci(x, y)] = 1;
  }
  const portCell = new Uint8Array(N);
  for (const p of req.ports || []) {
    const x = Math.round(p.x / U), y = Math.round(p.y / U);
    if (x >= 0 && y >= 0 && x < gw && y < gh) portCell[ci(x, y)] = 1;
  }
  const hard = new Uint8Array(N);
  for (const p2 of req.ports || []) {
    const x = Math.round(p2.x / U), y = Math.round(p2.y / U);
    if (x >= 0 && y >= 0 && x < gw && y < gh) hard[ci(x, y)] = 1;
  }
  const occH = new Int32Array(N).fill(-1);
  const occV = new Int32Array(N).fill(-1);
  const segs = [];
  const errors = [];
  const netIds = (req.nets || []).map((n, i) => i);

  const seenSeg = new Set();
  function claim(s, ni) {
    const sk = s.net + '|' + Math.min(s.x1, s.x2) + '|' + Math.min(s.y1, s.y2) + '|' + Math.max(s.x1, s.x2) + '|' + Math.max(s.y1, s.y2) + '|' + s.dir;
    if (seenSeg.has(sk)) return true;
    seenSeg.add(sk);
    const ax = Math.min(s.x1, s.x2) / U, bx = Math.max(s.x1, s.x2) / U;
    const ay = Math.min(s.y1, s.y2) / U, by = Math.max(s.y1, s.y2) / U;
    for (let y = ay; y <= by; y++) for (let x = ax; x <= bx; x++) {
      const k = ci(x, y);
      if (s.dir === 'H') { if (occH[k] >= 0 && occH[k] !== ni) { errors.push('net ' + s.net + ' H-overlaps net ' + occH[k] + ' at ' + x + ',' + y); return false; } occH[k] = ni; }
      else { if (occV[k] >= 0 && occV[k] !== ni) { errors.push('net ' + s.net + ' V-overlaps net ' + occV[k] + ' at ' + x + ',' + y); return false; } occV[k] = ni; }
    }
    segs.push(s);
    return true;
  }

  // Reserve the single cell directly outside every sink port for its own net.
  // Without this, a neighbouring net can consume the approach lane and the port
  // becomes unreachable even though the sheet has free space.
  const ACC = { l: [DX[1], DY[1]], r: [DX[0], DY[0]], u: [DY[3], DX[3]], d: [DY[2], DX[2]] };
  // Reserve the approach lane, not just the single cell outside the port. A neighbouring
  // net whose driver sits on the same row would otherwise consume that row as a highway and
  // leave the port reachable only through cells reserved by third nets (dead end).
  const CORRIDOR = 4;
  netIds.forEach((ni) => {
    const net = req.nets[ni];
    for (const s of net.sinks) {
      const dir = s.in || 'l';
      const v = ACC[dir] || ACC.l;
      for (let step = 1; step <= CORRIDOR; step++) {
        const cx = Math.round((s.x + v[0] * U * step) / U), cy = Math.round((s.y + v[1] * U * step) / U);
        if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) break;
        const k = ci(cx, cy);
        if (blocked[k] || portCell[k]) break;
        if (occH[k] < 0) occH[k] = ni;
        if (occV[k] < 0) occV[k] = ni;
      }
    }
  });

  // route wide fan-out nets first so they get corridor space
  const order = netIds.slice().sort((a, b) => (req.nets[b].sinks.length - req.nets[a].sinks.length) || (a - b));

  // Pass 1: reserve fan-out stubs for every multi-sink net.
  const stubs = new Map();
  netIds.forEach((ni) => {
    const net = req.nets[ni];
    const drv = net.driver;
    if (net.sinks.length < 2) { stubs.set(ni, drv); return; }
    const d = OUTD[drv.out || 'r'];
    const o = { x: drv.x + DX[d] * U, y: drv.y + DY[d] * U };
    if (o.x < 0 || o.y < 0 || o.x > req.width || o.y > req.height) { errors.push('net ' + net.id + ': stub off-sheet'); stubs.set(ni, drv); return; }
    stubs.set(ni, o);
    const hx = Math.round(o.x / U), hy = Math.round(o.y / U);
    if (hx >= 0 && hy >= 0 && hx < gw && hy < gh) hard[ci(hx, hy)] = 1;
    claim({ net: net.id, x1: drv.x, y1: drv.y, x2: o.x, y2: o.y, dir: isH(d) ? 'H' : 'V' }, ni);
  });

  function astar(ni, start, goal) {
    const gx = Math.round(goal.x / U), gy = Math.round(goal.y / U);
    const sx = Math.round(start.x / U), sy = Math.round(start.y / U);
    const gk = ci(gx, gy), sk = ci(sx, sy);
    const cost = new Float64Array(N).fill(Infinity);
    const prev = new Int32Array(N).fill(-1);
    const dir = new Int8Array(N).fill(-1);
    const heap = [];
    const swap = (i, j) => { const t = heap[i]; heap[i] = heap[j]; heap[j] = t; };
    const push = (node, f) => { heap.push([f, node]); let i = heap.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; swap(p, i); i = p; } };
    const pop = () => { const top = heap[0]; const last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let b = i; if (l < heap.length && heap[l][0] < heap[b][0]) b = l; if (r < heap.length && heap[r][0] < heap[b][0]) b = r; if (b === i) break; swap(b, i); i = b; } } return top[1]; };
    const h = (x, y) => Math.abs(x - gx) + Math.abs(y - gy);
    cost[sk] = 0;
    push(sk, h(sx, sy));
    let pops = 0;
    while (heap.length) {
      const c = pop();
      if (c === gk) break;
      if (++pops > 400000) { errors.push('net ' + req.nets[ni].id + ': search overflow'); return null; }
      const x = c % gw, y = (c - x) / gw;
      const cd = dir[c], cc = cost[c];
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
        const nk = ci(nx, ny);
        const isGoal = nk === gk;
        if (blocked[nk] && !isGoal) continue;
        if ((portCell[nk] || hard[nk]) && !isGoal && nk !== sk) continue;
        const horiz = isH(d);
        const own = horiz ? occH[nk] : occV[nk];
        if (own >= 0 && own !== ni && !isGoal) continue;
        const perp = horiz ? occV[nk] : occH[nk];
        let f = cc + 1;
        if (cd >= 0 && d !== cd) f += 3;
        if (own === ni) f -= 0.75;
        if (perp >= 0 && perp !== ni) f += 4;
        if (isGoal) f += 0;
        if (f < cost[nk]) { cost[nk] = f; prev[nk] = c; dir[nk] = d; push(nk, f + h(nx, ny)); }
      }
    }
    if (cost[gk] === Infinity) return null;
    const cells = [];
    let c = gk, guard = 0;
    while (c >= 0 && guard++ < 50000) { cells.push(c); if (c === sk) break; c = prev[c]; }
    if (cells[cells.length - 1] !== sk) return null;
    cells.reverse();
    return cells;
  }

  function emit(ni, cells) {
    const out = [];
    for (let i = 0; i < cells.length - 1;) {
      let j = i;
      const h = py(cells[i + 1]) === py(cells[i]);
      while (j + 1 < cells.length && (h ? py(cells[j + 1]) === py(cells[i]) : px(cells[j + 1]) === px(cells[i]))) j++;
      out.push({ net: req.nets[ni].id, x1: px(cells[i]), y1: py(cells[i]), x2: px(cells[j]), y2: py(cells[j]), dir: h ? 'H' : 'V' });
      i = j;
    }
    return out;
  }

  order.forEach((ni) => {
    const net = req.nets[ni];
    const origin = stubs.get(ni);
    for (const sink of net.sinks) {
      const path = astar(ni, origin, sink);
      if (!path) { errors.push('net ' + net.id + ': cannot reach sink ' + sink.x + ',' + sink.y); continue; }
      for (const s of emit(ni, path)) claim(s, ni);
    }
  });

  const deg = new Map();
  const bump = (x, y, net) => {
    const k = x + ',' + y;
    const e = deg.get(k) || { x, y, n: 0, nets: new Set() };
    e.n++; e.nets.add(net);
    deg.set(k, e);
  };
  for (const s of segs) { bump(s.x1, s.y1, s.net); bump(s.x2, s.y2, s.net); }
  for (const e of deg.values()) if (e.nets.size > 1) errors.push('two nets share endpoint ' + e.x + ',' + e.y + ' (short)');
  const junctions = [];
  for (const e of deg.values()) {
    if (e.n < 3) continue;
    const k = ci(e.x / U, e.y / U);
    if (portCell[k]) errors.push('fan-out on port point ' + e.x + ',' + e.y);
    else junctions.push({ x: e.x, y: e.y });
  }
  for (const s of segs) {
    const minX = Math.min(s.x1, s.x2), maxX = Math.max(s.x1, s.x2);
    const minY = Math.min(s.y1, s.y2), maxY = Math.max(s.y1, s.y2);
    for (const e of deg.values()) {
      if (e.nets.size === 1 && e.nets.has(s.net)) continue;
      const inside = s.dir === 'H' ? (e.y === s.y1 && e.x > minX && e.x < maxX) : (e.x === s.x1 && e.y > minY && e.y < maxY);
      if (inside) errors.push('foreign endpoint ' + e.x + ',' + e.y + ' inside run of net ' + s.net);
    }
  }
  return { segments: segs, junctions, errors, occH, occV, gw, gh };
}