// Generate Quartus II 5.0 Block Diagram Files (.bdf) from a declarative spec.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const S = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/sexpr.mjs').href);
const RT = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/router.mjs').href);
const LIB = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/library.mjs').href);
const BSF = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/bsf.mjs').href);

// A project-owned block (entity defined by another .bdf/.vhd in the same project) is
// placed as a plain (symbol ...) node whose name text is the entity name - that is how
// the authentic Laboratory 9 cmp4bit sheet references its CMP_2bit child.
export function userTemplate(def, name) {
  const t = BSF.templateFor(name, def.inputs, def.outputs);
  const parsed = S.parse(t.lines.join(String.fromCharCode(10)));
  const node = Array.isArray(parsed) && parsed.length === 1 ? parsed[0] : parsed;
  return { name, w: t.w, h: t.h, ports: t.ports, node, user: true, src: 'project entity ' + name };
}

const U = 8;

export function loadLibrary(jsonPath) {
  const raw = JSON.parse(fs.readFileSync(jsonPath, 'latin1'));
  const prim = LIB.pickPrimitives(raw);
  const pins = { input: LIB.pickPins(raw, 'input', 'h'), output: LIB.pickPins(raw, 'output', 'h'), bidirectional: LIB.pickPins(raw, 'bidirectional', 'h'), tristate: LIB.pickPins(raw, 'tristate', 'h') };
  return { raw, prim, pins };
}

function clone(n) { return JSON.parse(JSON.stringify(n)); }

function setRect(node, x, y) {
  const rc = S.kid(node, 'rect');
  if (!rc || rc.length < 5) throw new Error('node has no usable rect');
  const x0 = Number(rc[1]), y0 = Number(rc[2]), x1 = Number(rc[3]), y1 = Number(rc[4]);
  const w = x1 - x0, h = y1 - y0;
  if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) throw new Error('bad rect geometry: ' + [x0, y0, x1, y1].join(' '));
  rc[1] = x; rc[2] = y; rc[3] = x + w; rc[4] = y + h;
  return { w, h };
}

function renamePin(node, name) {
  const texts = S.kids(node, 'text');
  for (const t of texts) {
    if (!S.isStr(t[1])) continue;
    const v = t[1].str;
    if (v === 'INPUT' || v === 'OUTPUT' || v === 'VCC' || v === 'GND') continue;
    t[1] = { str: name };
    return;
  }
}

function renameInstance(node, name) {
  const texts = S.kids(node, 'text');
  if (texts.length >= 2 && S.isStr(texts[1][1])) texts[1][1] = { str: name };
}

export function build(spec, lib, opts) {
  const o = opts || {};
  const raw = Object.assign({ IN_X: 24, START_Y: 48, COL_GAP: 208, ROW_GAP: 56, PIN_ROW_GAP: 40, MARGIN: 96, DENSITY: 0 }, spec.layout || {});
  const snap = (v) => Math.max(U, Math.ceil(v / U) * U);
  const cfg = {
    IN_X: snap(raw.IN_X), START_Y: snap(raw.START_Y), COL_GAP: snap(raw.COL_GAP),
    ROW_GAP: snap(raw.ROW_GAP), PIN_ROW_GAP: snap(raw.PIN_ROW_GAP), MARGIN: snap(raw.MARGIN),
    DENSITY: snap(raw.DENSITY || 0),
  };
  const IN_X = cfg.IN_X, START_Y = cfg.START_Y, COL_GAP = cfg.COL_GAP, ROW_GAP = cfg.ROW_GAP;
  const inputs = spec.inputs || [];
  const inTpl_h = lib.pins.input ? lib.pins.input.h : 16;
  const outputs = spec.outputs || [];
  const insts = spec.instances || [];
  const conn = spec.connect || [];

  const byId = {};
  for (const it of insts) {
    const tpl = lib.prim[it.type]
      || (spec.userSymbols && spec.userSymbols[it.type] ? userTemplate(spec.userSymbols[it.type], it.type) : null);
    if (!tpl) throw new Error('unknown primitive: ' + it.type + ' (have ' + Object.keys(lib.prim).length + ' library names and ' + Object.keys(spec.userSymbols || {}).length + ' project blocks)');
    const ports = {};
    for (const p of tpl.ports) ports[p.label] = p;
    byId[it.id] = { ...it, tpl, ports, kind: 'inst' };
  }

  const drivers = {}, sinks = {};
  const epInfo = (ref) => {
    const dot = ref.indexOf('.');
    if (dot < 0) {
      if (inputs.indexOf(ref) >= 0) return { type: 'in', pin: ref, dir: 'output' };
      if (outputs.indexOf(ref) >= 0) return { type: 'out', pin: ref, dir: 'input' };
      throw new Error('unknown top-level port in connect: ' + ref);
    }
    const iid = ref.slice(0, dot), pl = ref.slice(dot + 1);
    const inst = byId[iid];
    if (!inst) throw new Error('unknown instance: ' + iid);
    const p = inst.ports[pl];
    if (!p) throw new Error('instance ' + iid + ' (' + inst.type + ') has no port ' + pl + ' (has ' + Object.keys(inst.ports).join(',') + ')');
    return { type: 'inst', iid, port: pl, dir: p.dir, inst };
  };

  const netOf = new Map();
  let netSeq = 0;
  const find = (k) => { for (;;) { const v = netOf.get(k); if (!v || v === k) return k; k = v; } };
  const union = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) netOf.set(ra, rb); return find(ra); };
  for (const [a, b] of conn) { for (const r of [a, b]) if (!netOf.has(r)) netOf.set(r, r); union(a, b); }

  const nets = {};
  for (const [a, b] of conn) {
    const root = union(a, b);
    nets[root] = nets[root] || { id: 'n' + (netSeq++), members: [] };
    const ia = epInfo(a), ib = epInfo(b);
    for (const [ref, info] of [[a, ia], [b, ib]]) {
      const rec = nets[root].members.find((m) => m.ref === ref);
      if (rec) continue;
      nets[root].members.push({ ref, info });
    }
  }
  for (const key of Object.keys(nets)) {
    const m = nets[key].members;
    const drv = m.filter((x) => x.info.dir === 'output');
    const snk = m.filter((x) => x.info.dir === 'input');
    if (drv.length !== 1) throw new Error('net ' + nets[key].id + ' has ' + drv.length + ' drivers: ' + m.map((x) => x.ref).join(' <-> '));
    nets[key].driver = drv[0];
    nets[key].sinks = snk;
  }

  const level = {};
  for (const p of inputs) level['IN:' + p] = 0;
  for (const it of insts) level['I:' + it.id] = it.level != null ? it.level : 0;
  for (let pass = 0; pass < insts.length + 2; pass++) {
    let changed = false;
    for (const key of Object.keys(nets)) {
      const n = nets[key];
      const d = n.driver.info;
      const dl = d.type === 'in' ? 0 : level['I:' + d.iid];
      for (const s of n.sinks) {
        const sl = s.info.type === 'out' ? 9999 : level['I:' + s.info.iid];
        const forced = s.info.inst ? s.info.inst.level : null;
      const want = forced != null ? forced : dl + 1;
      if (sl < want) { level['I:' + s.info.iid] = want; changed = true; }
      }
    }
    if (!changed) break;
  }
  const maxLevel = Math.max(...insts.map((it) => level['I:' + it.id]), 0);

  const cols = [];
  for (let L = 0; L <= maxLevel; L++) cols[L] = insts.filter((it) => level['I:' + it.id] === L);

  // input pin rows first: they define the reference ordering for column 0
  const rowPos = {};
  inputs.forEach((p2, i) => { rowPos['IN:' + p2] = START_Y + i * (inTpl_h + cfg.PIN_ROW_GAP) + 8; });

  const driversOf = (id) => {
    const set = new Set();
    for (const key of Object.keys(nets)) {
      const n = nets[key];
      for (const s of n.sinks) if (s.info.type === 'inst' && s.info.iid === id) {
        set.add(n.driver.info.type === 'in' ? 'IN:' + n.driver.info.pin : 'I:' + n.driver.info.iid);
      }
    }
    return [...set];
  };
  const successorsOf = (key) => {
    const set = new Set();
    for (const nk of Object.keys(nets)) {
      const n = nets[nk];
      const dk = n.driver.info.type === 'in' ? 'IN:' + n.driver.info.pin : 'I:' + n.driver.info.iid;
      if (dk === key) for (const s of n.sinks) if (s.info.type === 'inst') set.add('I:' + s.info.iid);
    }
    return [...set];
  };

  // adaptive row pitch: taller columns get more vertical room for routing corridors
  const biggest = Math.max(...cols.map((c) => c.length), 1);
  const rowGap = snap(cfg.ROW_GAP + (cfg.DENSITY || 0));
  const gateH = (id) => byId[id].tpl.h;

  for (let pass = 0; pass < 6; pass++) {
    const down = pass % 2 === 0;
    const range = down ? [...cols.keys()] : [...cols.keys()].reverse();
    for (const L of range) {
      const col = cols[L];
      if (L === 0 && down) continue;
      const bary = new Map();
      for (const it of col) {
        const id = 'I:' + it.id;
        const rel = down ? driversOf(it.id) : successorsOf(id);
        const vals = rel.map((r) => rowPos[r]).filter((v) => v != null);
        bary.set(id, vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : (rowPos[id] ?? L * 1000));
      }
      col.sort((a, b) => bary.get('I:' + a.id) - bary.get('I:' + b.id));
      let y = START_Y;
      const tops = [];
      const prev = new Map();
      for (const it of col) { prev.set('I:' + it.id, rowPos['I:' + it.id]); tops.push(y); rowPos['I:' + it.id] = y + gateH(it.id) / 2; y += gateH(it.id) + rowGap; }
      // Centre the column block on the barycentre of the rows it actually talks to. Without
      // this a lone gate is pinned to the sheet top, and its output row can coincide with a
      // neighbouring net's approach lane to another port of the same symbol.
      const refs = [];
      for (const it of col) {
        const id = 'I:' + it.id;
        const rel = down ? driversOf(it.id) : successorsOf(id);
        for (const r of rel) if (rowPos[r] != null) refs.push(rowPos[r]);
      }
      if (!refs.length) {
        for (const [k2, v2] of prev) if (v2 != null) rowPos[k2] = v2;
        continue;
      }
      if (refs.length && tops.length) {
        const want = refs.reduce((x2, x3) => x2 + x3, 0) / refs.length;
        const blockH = y - rowGap - START_Y;
        const centre = START_Y + blockH / 2;
        const shift = Math.max(0, snap(want - centre));
        if (shift) {
          y = START_Y + shift;
          for (const it of col) { rowPos['I:' + it.id] = y + gateH(it.id) / 2; y += gateH(it.id) + rowGap; }
        }
      }
    }
  }

  const place = {};
  let x = IN_X + 168 + COL_GAP;
  const colX = [];
  cols.forEach((col, L) => {
    colX[L] = x;
    for (const it of col) {
      const tpl = byId[it.id].tpl;
      const rp = rowPos['I:' + it.id];
      const yy = rp != null ? snap(rp - tpl.h / 2) : START_Y;
      place[it.id] = { x, y: Math.max(START_Y, yy) };
    }
    const maxH = col.reduce((m, it) => Math.max(m, byId[it.id].tpl.h), 0);
    x += Math.max(...col.map((it) => byId[it.id].tpl.w), 64) + COL_GAP;
  });
  const outX = x;

  const nodes = [];
  const obstacles = [];
  const portPts = [];
  const portPoint = {};
  const outDir = (tpl, dx, dy) => (dx === tpl.w ? 'r' : dy === 0 ? 'u' : dx === 0 ? 'l' : dy === tpl.h ? 'd' : 'r');
  const inDir = (tpl, dx, dy) => (dx === 0 ? 'l' : dy === 0 ? 'u' : dx === tpl.w ? 'r' : dy === tpl.h ? 'd' : 'l');
  const inTpl = lib.pins.input, outTpl = lib.pins.output;
  if (!inTpl || !outTpl) throw new Error('missing pin templates');
  inputs.forEach((p, i) => {
    const n = clone(inTpl.node);
    const y = START_Y + i * (inTpl.h + cfg.PIN_ROW_GAP);
    setRect(n, IN_X, y);
    renamePin(n, p);
    nodes.push(n);
    obstacles.push({ x0: IN_X, y0: y, x1: IN_X + inTpl.w, y1: y + inTpl.h });
    portPoint['IN:' + p] = { x: IN_X + inTpl.w, y: y + (inTpl.pt ? inTpl.pt[1] : 8), out: outDir(inTpl, inTpl.pt ? inTpl.pt[0] : inTpl.w, inTpl.pt ? inTpl.pt[1] : 8) };
    portPts.push(portPoint['IN:' + p]);
  });
  outputs.forEach((p, i) => {
    const n = clone(outTpl.node);
    const y = START_Y + i * (outTpl.h + cfg.PIN_ROW_GAP);
    setRect(n, outX, y);
    renamePin(n, p);
    nodes.push(n);
    obstacles.push({ x0: outX, y0: y, x1: outX + outTpl.w, y1: y + outTpl.h });
    portPoint['OUT:' + p] = { x: outX, y: y + (outTpl.pt ? outTpl.pt[1] : 8), out: 'l' };
    portPts.push(portPoint['OUT:' + p]);
  });
  for (const it of insts) {
    const rec = byId[it.id];
    const n = clone(rec.tpl.node);
    const { x: px, y: py } = place[it.id];
    setRect(n, px, py);
    renameInstance(n, it.id);
    if (it.params) {
      for (const [k, v] of Object.entries(it.params)) {
        const al = S.kids(n, 'alias');
        const t = al.find((a) => S.isStr(a[1]) && a[1].str === k);
        if (t && t.length > 2 && S.isStr(t[2])) t[2] = { str: String(v) };
      }
    }
    nodes.push(n);
    obstacles.push({ x0: px, y0: py, x1: px + rec.tpl.w, y1: py + rec.tpl.h });
    for (const p of rec.tpl.ports) {
      portPoint['I:' + it.id + '.' + p.label] = { x: px + p.dx, y: py + p.dy, out: p.dir === 'output' ? outDir(rec.tpl, p.dx, p.dy) : 'l', in: inDir(rec.tpl, p.dx, p.dy) };
      portPts.push(portPoint['I:' + it.id + '.' + p.label]);
    }
  }

  for (const [k, v] of Object.entries(portPoint)) {
    if (v.x % U !== 0 || v.y % U !== 0) throw new Error('port ' + k + ' off-grid at ' + v.x + ',' + v.y + ' (grid ' + U + ')');
  }
  const width = outX + outTpl.w + COL_GAP;
  const height = Math.max(...Object.values(rowPos).map((v) => v + 160), ...obstacles.map((ob) => ob.y1)) + cfg.MARGIN;
  const routeNets = [];
  for (const key of Object.keys(nets)) {
    const n = nets[key];
    const d = portPoint[n.driver.info.type === 'in' ? 'IN:' + n.driver.info.pin : 'I:' + n.driver.info.iid + '.' + n.driver.info.port];
    const sk = n.sinks.map((s) => portPoint[s.info.type === 'out' ? 'OUT:' + s.info.pin : 'I:' + s.info.iid + '.' + s.info.port]);
    routeNets.push({ id: n.id, driver: d, sinks: sk });
  }
  const res = RT.route({ width, height, obstacles, ports: portPts, nets: routeNets });
  for (const s of res.segments) {
    nodes.push(['connector', ['pt', s.x1, s.y1], ['pt', s.x2, s.y2]]);
  }
  for (const j of res.junctions) {
    nodes.push(['junction', ['pt', j.x, j.y]]);
  }
  const header = ['header', { str: 'graphic' }, ['version', { str: o.version || '1.3' }]];
  const ordered = [header, ...nodes.filter((n) => S.head(n) === 'pin'), ...nodes.filter((n) => S.head(n) === 'symbol'),
    ...nodes.filter((n) => S.head(n) === 'connector'), ...nodes.filter((n) => S.head(n) === 'junction'),
    ...nodes.filter((n) => !['pin', 'symbol', 'connector', 'junction', 'header'].includes(S.head(n)))];
  return { nodes: ordered, res, nets, portPoint, place, level, width, height, obstacles, spec };
}

function assertFinite(nodes, path) {
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    if (Array.isArray(n)) assertFinite(n, path + '[' + i + ']');
    else if (typeof n === 'number' && !isFinite(n)) throw new Error('non-finite coordinate at ' + path + '[' + i + ']');
  }
}

export function emitBdf(built) {
  assertFinite(built.nodes, 'nodes');
  return S.serialize(built.nodes);
}

export function emitQsf(spec, entity) {
  const lines = [];
  lines.push('# Generated by dsh Quartus bridge (host-generated, no GUI interaction)');
  lines.push('set_global_assignment -name ORIGINAL_QUARTUS_VERSION 5.0');
  lines.push('set_global_assignment -name LAST_QUARTUS_VERSION 5.0');
  lines.push('set_global_assignment -name PROJECT_CREATION_TIME_DATE "' + new Date().toUTCString() + '"');
  for (const f of spec.files || [spec.entity + '.bdf']) lines.push('set_global_assignment -name BDF_FILE ' + f);
  for (const nm of Object.keys(spec.userSymbols || {})) {
    const def = spec.userSymbols[nm];
    if (def.source !== false) lines.push('set_global_assignment -name BDF_FILE ' + nm + '.bdf');
  }
  // Quartus resolves assignment paths relative to the project directory, so only the bare
  // file name belongs here even when the spec keeps sources in a sibling folder.
  for (const fl of spec.vhdl || []) lines.push('set_global_assignment -name VHDL_FILE ' + fl.split(/[\\/]/).pop());
  if (spec.simulationMode) lines.push('set_global_assignment -name SIMULATION_MODE ' + spec.simulationMode);
  for (const f of spec.vwf || []) lines.push('set_global_assignment -name VECTOR_WAVEFORM_FILE ' + f);
  lines.push('');
  lines.push('set_global_assignment -name FAMILY "' + (spec.family || 'Stratix') + '"');
  lines.push('set_global_assignment -name DEVICE ' + (spec.device || 'AUTO'));
  lines.push('set_global_assignment -name TOP_LEVEL_ENTITY ' + (spec.top || entity));
  lines.push('set_global_assignment -name DEVICE_FILTER_SPEED_GRADE FASTEST');
  lines.push('set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1');
  return lines.join('\r\n') + '\r\n';
}

export function emitQpf(entity, version) {
  return ['# Generated by dsh Quartus bridge', 'QUARTUS_VERSION = "' + (version || '5.0') + '"', 'DATE = "' + new Date().toUTCString() + '"', '', 'PROJECT_REVISION = "' + entity + '"'].join('\r\n') + '\r\n';
}