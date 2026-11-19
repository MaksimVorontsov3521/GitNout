#!/usr/bin/env node
// Build a Quartus II 5.0 project (BDF + BSF + QSF + QPF + VWF + VHDL) from a JSON spec.
// Dependencies: spec.userSymbols.<name>.from points at a sibling spec JSON; that block is
// built into the same project folder and its .bsf is emitted so Quartus can resolve it.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const HOME = 'C:/Users/User/VirtualBox VMs/Microelectronics';
const G = await import(pathToFileURL(HOME + '/tools/bdf/gen.mjs').href);
const V = await import(pathToFileURL(HOME + '/tools/bdf/verify.mjs').href);
const W = await import(pathToFileURL(HOME + '/tools/bdf/vwf.mjs').href);
const B = await import(pathToFileURL(HOME + '/tools/bdf/bsf.mjs').href);

const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf('--' + k); return i >= 0 ? argv[i + 1] : d; };
const specPath = argv[0];
if (!specPath || specPath.startsWith('--')) { console.error('usage: build.mjs <spec.json> [--out DIR] [--dry FILE]'); process.exit(2); }
const rootSpec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const specDir = rootSpec.specDir ? path.resolve(rootSpec.specDir) : path.dirname(specPath);
const outDir = opt('out', 'D:/Desktop/NF/qwork/' + rootSpec.entity);
const lib = G.loadLibrary(HOME + '/tools/bdf/library.json');
const ATTEMPTS = [
  {},
  { DENSITY: 16 },
  { DENSITY: 32, COL_GAP: 248 },
  { DENSITY: 56, COL_GAP: 288, PIN_ROW_GAP: 52 },
  { DENSITY: 88, COL_GAP: 336, PIN_ROW_GAP: 60, MARGIN: 180 },
  { DENSITY: 24, ROW_GAP: 88, COL_GAP: 264, PIN_ROW_GAP: 56 },
  { DENSITY: 48, ROW_GAP: 120, COL_GAP: 304, PIN_ROW_GAP: 64 },
  { DENSITY: 96, ROW_GAP: 152, COL_GAP: 368, PIN_ROW_GAP: 76, MARGIN: 220 },
  { DENSITY: 144, ROW_GAP: 184, COL_GAP: 432, PIN_ROW_GAP: 88, MARGIN: 260 },
];

function buildOne(spec, label) {
  for (let attempt = 0; attempt < ATTEMPTS.length; attempt++) {
    const lay = Object.assign({}, spec.layout || {}, ATTEMPTS[attempt]);
    let built;
    try { built = G.build({ ...spec, layout: lay }, lib, {}); }
    catch (e) { console.error('BUILD FAIL (' + label + ' attempt ' + attempt + '): ' + e.message); process.exit(3); }
    const bdf = G.emitBdf(built);
    const errs = V.compareWithSpec(V.netlistFromBdf(bdf), spec);
    const routeErrs = built.res.errors;
    if (!routeErrs.length && !errs.length) {
      if (attempt) console.log(label + ': routed on attempt ' + attempt + ' with ' + JSON.stringify(lay));
      return { built, bdf, label };
    }
    console.log(label + ' attempt ' + attempt + ': ' + routeErrs.length + ' router / ' + errs.length + ' verify errors' +
      (routeErrs.length ? ' [' + routeErrs.slice(0, 2).join('; ') + ']' : '') + (errs.length ? ' [' + errs.slice(0, 2).join('; ') + ']' : ''));
  }
  console.error(label + ': BUILD FAILED after ' + ATTEMPTS.length + ' layout attempts');
  process.exit(4);
}

const written = [];
const done = new Set();
function emitProject(spec, entity, isTop) {
  const { built, bdf } = buildOne(spec, entity);
  fs.mkdirSync(outDir, { recursive: true });
  const bdfPath = path.join(outDir, entity + '.bdf');
  fs.writeFileSync(bdfPath, bdf, 'latin1');
  written.push(entity + '.bdf');
  console.log(entity + ': sheet=' + built.width + 'x' + built.height + ' segs=' + built.res.segments.length +
    ' junctions=' + built.res.junctions.length + ' levels=' + JSON.stringify(Object.fromEntries((spec.instances || []).map((i) => [i.id, built.level['I:' + i.id]]))));
  if (opt('dry') && isTop) { fs.mkdirSync(path.dirname(opt('dry')), { recursive: true }); fs.writeFileSync(opt('dry'), bdf, 'latin1'); console.log('written (dry) -> ' + opt('dry')); }
  if (isTop && spec.inputs && spec.inputs.length) {
    fs.writeFileSync(path.join(outDir, entity + '.vwf'), W.emitVwf(spec, {}), 'latin1');
    written.push(entity + '.vwf');
  }
  return built;
}

if (rootSpec.vhdlOnly) {
  fs.mkdirSync(outDir, { recursive: true });
  for (const f of rootSpec.vhdl || []) {
    const srcPath = path.isAbsolute(f) ? f : path.join(specDir, f);
    fs.copyFileSync(srcPath, path.join(outDir, path.basename(f)));
    written.push(path.basename(f));
  }
  if (rootSpec.inputs && rootSpec.inputs.length) {
    fs.writeFileSync(path.join(outDir, rootSpec.entity + '.vwf'), W.emitVwf(rootSpec, {}), 'latin1');
    written.push(rootSpec.entity + '.vwf');
  }
  fs.writeFileSync(path.join(outDir, rootSpec.entity + '.qsf'), G.emitQsf(rootSpec, rootSpec.entity), 'latin1');
  fs.writeFileSync(path.join(outDir, rootSpec.entity + '.qpf'), G.emitQpf(rootSpec.entity), 'latin1');
  written.push(rootSpec.entity + '.qsf', rootSpec.entity + '.qpf');
  console.log('VHDL-ONLY PROJECT WRITTEN -> ' + outDir);
  console.log('files: ' + written.join(', '));
  process.exit(0);
}

// 1. build dependency blocks first, and emit their .bsf so the parent sheet can place them
const depInfo = {};
function emitDep(nm, def, fromDir) {
  if (done.has(nm)) return;
  done.add(nm);
  const base = fromDir || specDir;
  const depPath = path.isAbsolute(def.from) ? def.from : path.join(base, def.from + '.json');
  const dep = JSON.parse(fs.readFileSync(depPath, 'utf8'));
  const want = { inputs: def.inputs || dep.inputs, outputs: def.outputs || dep.outputs };
  // Quartus matches sub-design ports by NAME, so declaration order only affects how the
  // symbol is drawn. Compare as sets, but refuse silently-different port sets.
  const setEq = (x, y) => !!x === !!y && (!x || [...x].sort().join() === [...y].sort().join());
  if (!setEq(dep.inputs, def.inputs)) throw new Error('block ' + nm + ': input set ' + JSON.stringify(dep.inputs) + ' disagrees with parent declaration ' + JSON.stringify(def.inputs));
  if (!setEq(dep.outputs, def.outputs)) throw new Error('block ' + nm + ': output set ' + JSON.stringify(dep.outputs) + ' disagrees with parent declaration ' + JSON.stringify(def.outputs));
  // the dependency's own children must exist in the same project folder
  const depDir = path.resolve(path.dirname(depPath));
  for (const [cn, cd] of Object.entries(dep.userSymbols || {})) emitDep(cn, cd, depDir);
  emitProject(dep, nm, false);
  fs.writeFileSync(path.join(outDir, nm + '.bsf'), B.emitBsf(nm, want.inputs, want.outputs), 'latin1');
  written.push(nm + '.bsf');
  depInfo[nm] = { inputs: want.inputs, outputs: want.outputs, spec: dep };
  const g = B.symbolGeometry(want.inputs, want.outputs);
  console.log(nm + ': .bsf emitted (' + g.w + 'x' + g.h + ')');
}
for (const [nm, def] of Object.entries(rootSpec.userSymbols || {})) {
  if (!def.from) {
    if (def.vhdl) { depInfo[nm] = { inputs: def.inputs, outputs: def.outputs, vhdl: true }; console.log(nm + ': VHDL-backed block, source supplied by spec.vhdl'); }
    continue;
  }
  emitDep(nm, def);
}

// 2. build the top-level sheet
const built = emitProject(rootSpec, rootSpec.entity, true);

// 3. VHDL sources that belong to this project (copied verbatim from the spec folder)
for (const f of rootSpec.vhdl || []) {
  const srcPath = path.isAbsolute(f) ? f : path.join(specDir, f);
  fs.copyFileSync(srcPath, path.join(outDir, path.basename(f)));
  written.push(path.basename(f));
  console.log('vhdl staged: ' + path.basename(f));
}

// 4. project files
fs.writeFileSync(path.join(outDir, rootSpec.entity + '.qsf'), G.emitQsf(rootSpec, rootSpec.entity), 'latin1');
fs.writeFileSync(path.join(outDir, rootSpec.entity + '.qpf'), G.emitQpf(rootSpec.entity), 'latin1');
written.push(rootSpec.entity + '.qsf', rootSpec.entity + '.qpf');
if (rootSpec.vwf) for (const v of rootSpec.vwf) if (!written.includes(v)) console.log('note: extra vwf expected in spec folder: ' + v);
console.log('PROJECT WRITTEN -> ' + outDir);
console.log('files: ' + written.join(', '));
if (fs.existsSync(path.join(specDir, 'extra'))) for (const f of fs.readdirSync(path.join(specDir, 'extra'))) { fs.copyFileSync(path.join(specDir, 'extra', f), path.join(outDir, f)); console.log('extra staged: ' + f); }
process.exit(0);