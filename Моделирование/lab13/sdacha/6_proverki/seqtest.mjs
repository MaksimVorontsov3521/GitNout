// lab13/seqtest.mjs - self-test for the sequential verification stack, WITHOUT the guest.
//
// Run (from the workspace root, with the runtime node):
//   node lab13/seqtest.mjs
// which is
//   & "<runtime>\node.exe" lab13/seqtest.mjs
//
// Six sections, each a set of named assertions. Every assertion is a fact this stack depends
// on; the format probes in section 1 are the ones seqvwf.mjs and seqcheck.mjs cite in their
// comments, so a comment claim can be re-checked by running this file rather than by trusting
// the comment. Exit code is non-zero if any assertion fails, and the PASS/FAIL table names the
// failing assertion.
//
// Sections
//   1 format probes   - claims about the Quartus .vwf format, measured on real files. Skipped
//                       (reported, not passed) when a file is not present on this host.
//   2 Z preservation  - tools/bdf/simcheck.mjs parseVwf keeps Z, proved on synthetic text AND
//                       on the lead's returned guest waves when they are on disk.
//   3 round trip      - buildTimeline -> emitSeqVwf -> parseVwf -> sampleAt, every channel at
//                       every nanosecond and at every segment boundary, including Z runs and
//                       clock edges.
//   4 legacy parity   - checkSeq reproduces tools/bdf/simcheck.mjs checkSim on a real returned
//                       .sim.vwf, so the sequential checker is a superset, not a rival.
//   5 negative cases  - an absent channel is a mismatch, busWord refuses to guess through X/Z,
//                       a sabotaged expectation is caught, the emitter asserts on bad input.
//   6 models          - the four reference models' internal self-tests, plus a timeline driven
//                       through a model and checked with checkSeq (deliverables 1, 2, 4 and 3
//                       confronted with each other).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const HOME = HERE;
const dyn = (p) => import(new URL('file://' + p.replace(/\\/g, '/')).href);
const SC = await dyn(path.join(HOME, 'tools/bdf/simcheck.mjs'));
const W = await dyn(path.join(HERE, 'seqvwf.mjs'));
const K = await dyn(path.join(HERE, 'seqcheck.mjs'));
const MD = await dyn(path.join(HERE, 'models.mjs'));

// Reference .vwf corpus. Everything here is a file Quartus itself wrote or a lab sheet a
// student authored; a missing path downgrades a probe to SKIP instead of failing the run.
const REF = [
  path.resolve(HERE, '../ref_vwf'),                                   // sibling of the ref tree
  // абсолютный путь авторского дерева убран: сдача от него не зависит
];
const LEAD = [
  path.resolve(HERE, '../5_proby_polyarnosti/probe_reg.sim.vwf'),
  path.resolve(HERE, '../5_proby_polyarnosti/probe_tri.sim.vwf'),
  path.resolve(HERE, '../5_proby_polyarnosti/probe_trioe.sim.vwf'),
];
const firstExisting = (list) => list.filter((p) => { try { return fs.existsSync(p); } catch { return false; } });
const REFROOT = firstExisting(REF)[0] || null;
const LEADFILES = firstExisting(LEAD);
const DEC = (p) => (p ? path.basename(path.dirname(p)) + '/' + path.basename(p) : '(missing)');

// ---- assertion harness ----------------------------------------------------
const results = [];                       // { section, name, status, detail }
let failures = 0;
function ok(section, name, cond, detail) {
  results.push({ section, name, status: cond ? 'PASS' : 'FAIL', detail: cond ? '' : String(detail == null ? '' : detail).slice(0, 220) });
  if (!cond) failures++;
  return !!cond;
}
function skip(section, name, why) {
  results.push({ section, name, status: 'SKIP', detail: String(why).slice(0, 220) });
}
function throws(section, name, fn, match) {
  let msg = null;
  try { fn(); } catch (e) { msg = e && e.message ? e.message : String(e); }
  if (msg == null) return ok(section, name, false, 'expected a throw, got none');
  if (match && msg.indexOf(match) < 0) return ok(section, name, false, 'threw "' + msg + '", wanted /' + match + '/');
  return ok(section, name, true);
}
const NL = String.fromCharCode(10);
const readText = (p) => fs.readFileSync(p, 'utf8');

// ===========================================================================
// 1. FORMAT PROBES - each claim seqvwf.mjs / seqcheck.mjs cites, measured
// ===========================================================================
const grep = (re, text) => (text.match(re) || []);

// 1a. A bus bit channel is spelled NAME[i] with PARENT = "NAME", listed MSB first.
if (REFROOT) {
  const dec = readText(path.join(REFROOT, 'VHDLCMP_4BIT/VHDLCMP_4BIT.vwf'));
  const sigs = grep(/SIGNAL\("([^"]+)"\)/g, dec).map((m) => /SIGNAL\("([^"]+)"\)/.exec(m)[1]);
  ok('1 format', 'bus bits spelled NAME[i]', sigs.some((s) => /\[\d+\]$/.test(s)), sigs.join(' '));
  const parents = grep(/PARENT = "([A-Za-z0-9_]+)";/g, dec);
  ok('1 format', 'bus bits carry PARENT', parents.length > 0, JSON.stringify(parents.slice(0, 3)));
} else skip('1 format', 'bus bit spelling', 'no reference corpus at ' + REFROOT);

// 1b. The BUS parent is SIGNAL_TYPE = BUS, WIDTH = n, LSB_INDEX = 0, and has NO
//     TRANSITION_LIST of its own. Measured on a Quartus-WRITTEN file, not just a stimulus.
{
  const cands = [];
  if (REFROOT) cands.push(path.join(REFROOT, 'db/VHDLCMP_4BIT.sim.vwf'));
  cands.push(...LEADFILES);
  const found = firstExisting(cands);
  if (found.length) {
    let checkedParents = 0, badLists = 0;
    for (const f of found) {
      const t = readText(f);
      const busParents = grep(/SIGNAL\("([^"\[\]]+)"\)\s*\{[^}]*SIGNAL_TYPE = BUS;/g, t)
        .map((m) => /SIGNAL\("([^"\[\]]+)"\)/.exec(m)[1]);
      for (const bp of busParents) {
        checkedParents++;
        const block = new RegExp('SIGNAL\\("' + bp + '"\\)\\s*\\{([^}]*)\\}').exec(t)[1];
        if (!/WIDTH = \d+;/.test(block) || !/LSB_INDEX = 0;/.test(block)) badLists++;
        if (new RegExp('TRANSITION_LIST\\("' + bp + '"\\)').test(t)) badLists++;
      }
    }
    ok('1 format', 'BUS parent: WIDTH/LSB_INDEX=0 and no TRANSITION_LIST',
      checkedParents > 0 && badLists === 0, checkedParents + ' parents, ' + badLists + ' bad');
  } else skip('1 format', 'BUS parent shape', 'no bus-bearing .sim.vwf on disk');
}

// 1c. Returned waves collapse equal runs and can hold NON-GRID durations, so a checker must
//     sample at arbitrary t. ref/vwf/D/db/D.sim.vwf is Quartus's own output for a D latch.
if (REFROOT) {
  const d = readText(path.join(REFROOT, 'D/db/D.sim.vwf'));
  const durs = grep(/LEVEL \S FOR ([\d.]+);/g, d).map((m) => Number(/FOR ([\d.]+)/.exec(m)[1]));
  const grid = 50;
  const offGrid = durs.filter((x) => Math.abs(x % grid) > 1e-9);
  ok('1 format', 'returned waves carry off-grid durations', offGrid.length > 0, JSON.stringify(durs));
  ok('1 format', 'every duration has a decimal point', grep(/LEVEL \S FOR \d+\.\d+;/g, d).length === durs.length);
} else skip('1 format', 'off-grid durations', 'no reference corpus');

// 1d. An observed channel in a STIMULUS file is one LEVEL X spanning the whole run.
if (REFROOT) {
  const d = readText(path.join(REFROOT, 'D/D.vwf'));
  const blk = /TRANSITION_LIST\("Q"\)\s*\{([\s\S]*?)\n\}/.exec(d)[1];
  const runs = grep(/LEVEL (\S) FOR ([\d.]+);/g, blk);
  ok('1 format', 'stimulus output is a single LEVEL X',
    runs.length === 1 && /LEVEL X FOR/.test(blk), JSON.stringify(runs));
} else skip('1 format', 'stimulus output X', 'no reference corpus');

// 1e. GROUP("name"){MEMBERS=...} groups separate pins and the group name is NOT a SIGNAL.
if (REFROOT) {
  const m = readText(path.join(REFROOT, 'VHDL_4_bit_memory/db/VHDL_4_bit_memory.sim.vwf'));
  const g = /GROUP\("([^"]+)"\)\s*\{\s*MEMBERS = ([^;]*);/.exec(m);
  ok('1 format', 'GROUP block exists in Quartus output', !!g, 'no GROUP in VHDL_4_bit_memory');
  if (g) {
    const gname = g[1];
    ok('1 format', 'group name is not a SIGNAL or TRANSITION_LIST',
      m.indexOf('SIGNAL("' + gname + '")') < 0 && m.indexOf('TRANSITION_LIST("' + gname + '")') < 0, gname);
  }
} else skip('1 format', 'GROUP block', 'no reference corpus');

// 1f. TIME_UNIT / GRID fields are always present, and SIMULATION_TIME is 0.0 in a stimulus but
//     the run length in a returned file.
if (REFROOT) {
  const stim = readText(path.join(REFROOT, 'D/D.vwf'));
  const resp = readText(path.join(REFROOT, 'D/db/D.sim.vwf'));
  ok('1 format', 'stimulus SIMULATION_TIME = 0.0', /SIMULATION_TIME = 0\.0;/.test(stim), (/(SIMULATION_TIME = [^;]*;)/.exec(stim) || [])[1]);
  ok('1 format', 'returned SIMULATION_TIME is the run length', /SIMULATION_TIME = 200\.0;/.test(resp), (/(SIMULATION_TIME = [^;]*;)/.exec(resp) || [])[1]);
} else skip('1 format', 'SIMULATION_TIME', 'no reference corpus');

// ===========================================================================
// 2. Z PRESERVATION - proved, not assumed
// ===========================================================================
// 2a. Synthetic: one channel whose whole vocabulary is exercised, parsed by tools/bdf parseVwf.
{
  const synth = [
    'HEADER', '{', '\tVERSION = 1;', '\tTIME_UNIT = ns;', '\tSIMULATION_TIME = 100.0;',
    '\tGRID_PHASE = 0.0;', '\tGRID_PERIOD = 10.0;', '\tGRID_DUTY_CYCLE = 50;', '}', '',
    'SIGNAL("Y")', '{', '\tVALUE_TYPE = NINE_LEVEL_BIT;', '\tSIGNAL_TYPE = SINGLE_BIT;',
    '\tWIDTH = 1;', '\tLSB_INDEX = -1;', '\tDIRECTION = OUTPUT;', '\tPARENT = "";', '}', '',
    'TRANSITION_LIST("Y")', '{', '\tNODE', '\t{', '\t\tREPEAT = 1;',
    '\t\tLEVEL 0 FOR 20.0;', '\t\tLEVEL 1 FOR 20.0;', '\t\tLEVEL Z FOR 30.0;',
    '\t\tLEVEL X FOR 30.0;', '\t}', '}', '',
    'TIME_BAR', '{', '\tTIME = 0;', '\tMASTER = TRUE;', '}', ';',
  ].join(NL);
  const p = K.proveZpreserved([{ name: 'synthetic nine-level', text: synth }]);
  ok('2 Z', 'parseVwf keeps a Z run', p.ok && p.zSegments === 1, JSON.stringify(p.levelsSeen));
  const tl = SC.parseVwf(synth);
  ok('2 Z', 'sampleAt returns Z mid-run', SC.sampleAt(tl, 'Y', 55) === 'Z', SC.sampleAt(tl, 'Y', 55));
  ok('2 Z', 'sampleAt returns X mid-run', SC.sampleAt(tl, 'Y', 85) === 'X', SC.sampleAt(tl, 'Y', 85));
  ok('2 Z', 'Z and X stay distinct through the parser',
    SC.sampleAt(tl, 'Y', 55) === 'Z' && SC.sampleAt(tl, 'Y', 85) === 'X');
  ok('2 Z', 'parser keeps the run boundaries', tl.Y.segs[2].t0 === 40 && tl.Y.segs[2].t1 === 70,
    JSON.stringify(tl.Y.segs));
}
// 2b. Real guest output, when the lead's evidence is on this host.
if (LEADFILES.length) {
  const p = K.proveZpreserved(LEADFILES);
  ok('2 Z', 'parseVwf preserves Z in real .sim.vwf', p.ok,
    'zSegments=' + p.zSegments + ' sampled=' + p.zSampled);
  ok('2 Z', 'every Z run sampled back as Z', p.zSegments === p.zSampled,
    p.zSegments + ' vs ' + p.zSampled);
  results.push({ section: '2 Z', name: '  measured: ' + LEADFILES.map(DEC).join(', '), status: 'INFO',
    detail: p.zSegments + ' Z runs across ' + p.reports.map((r) => r.channels).join('+') + ' channels; levels seen ' + JSON.stringify(p.levelsSeen) });
} else skip('2 Z', 'real guest waves', 'no probe_*.sim.vwf under ../5_proby_polyarnosti');

// ===========================================================================
// 3. ROUND TRIP - buildTimeline -> emitSeqVwf -> parseVwf -> sampleAt
// ===========================================================================
// A timeline with everything a memory circuit needs: a free-running clock, an 8-bit input bus,
// a 1-bit write enable, a 2-bit address bus, and a tri-stated 8-bit output carrying genuine Z.
const CH = [
  { name: 'CLK', dir: 'in' },
  { name: 'WE', dir: 'in' },
  { name: 'D', dir: 'in', bus: { width: 8 } },
  { name: 'A', dir: 'in', bus: { width: 2 } },
  { name: 'Q', dir: 'out', bus: { width: 8 } },
];
const OPS = [
  { dur: 20, set: { WE: 1, D: 0xAA, A: 0 } },            // write 10101010 to word 0
  { dur: 20, set: { WE: 1, D: 0x3C, A: 1 } },            // write 00111100 to word 1
  { dur: 20, set: { WE: 0 } },                            // read mode; Q floats then tracks
  { dur: 40, set: { D: 'ZZZZZZZZ', A: 2 } },              // whole bus to Z
  { dur: 20, set: { D: '0000000X' }, at: 120 },           // jump forward: 20 ns of hold first
  { dur: 40, set: { D: 0x55, A: 3 }, repeat: 1 },
];
const TL = W.buildTimeline(CH, OPS, { clock: { name: 'CLK', period: 20 } });

ok('3 roundtrip', 'clock lays a square wave across the whole timeline',
  TL.segs.CLK.every((s) => s.t1 > s.t0) && TL.segs.CLK[TL.segs.CLK.length - 1].t1 === TL.total);
ok('3 roundtrip', 'rising edges land on multiples of the period',
  [0, 20, 40, 60, 80, 100, 120, 140].every((t) => W.levelAt(TL, 'CLK', t) === '1') &&
  [10, 30, 50, 70, 90, 110, 130, 150].every((t) => W.levelAt(TL, 'CLK', t) === '0'));
ok('3 roundtrip', 'bus expands MSB-first into NAME[i] plus the parent',
  TL.channels.find((c) => c.name === 'D').bits.join(',') === 'D[7],D[6],D[5],D[4],D[3],D[2],D[1],D[0]',
  TL.channels.find((c) => c.name === 'D').bits.join(','));
ok('3 roundtrip', 'a whole-bus integer splits bitwise MSB-first',
  W.levelsAt(TL, 'D', 5) === '10101010' && W.wordAt(TL, 'D', 5) === 0xAA, W.levelsAt(TL, 'D', 5));
ok('3 roundtrip', 'an output bus starts at X (unobserved until the guest answers)',
  W.levelsAt(TL, 'Q', 5) === 'XXXXXXXX');

// ---- corrected section 3 expectations, with the measured reasons -------------
// TL.total is 180, not 160: the ops sum to 140 ns of explicit duration and the "at: 120" jump
// leaves a 20 ns GAP [100,120) that the timeline fills by holding the previous value. A
// sequential script must say what happens between the ops it names.
ok('3 roundtrip', 'total counts the held gap as well as the named ops', TL.total === 180, TL.total);
ok('3 roundtrip', 'an "at" jump holds the previous value across the gap',
  W.levelsAt(TL, 'D', 110) === 'ZZZZZZZZ' && W.levelsAt(TL, 'D', 120) === '0000000X' &&
  W.wordAt(TL, 'A', 110) === 2,
  W.levelsAt(TL, 'D', 110) + ' ' + W.levelsAt(TL, 'D', 120) + ' A=' + W.wordAt(TL, 'A', 110));
ok('3 roundtrip', 'runs of equal level merge across a held gap',
  (function () {
    const z = TL.segs['D[7]'].filter((s) => s.level === 'Z');
    return z.length === 1 && z[0].t0 === 60 && z[0].t1 === 120;
  })(), JSON.stringify(TL.segs['D[7]'].filter((s) => s.level === 'Z')));

// Emit twice: the stimulus shape (outputs LEVEL X) and the drive-all shape (outputs carry the
// timeline's own wave, including Z) which is what a host-side round trip needs.
const stimText = W.emitSeqVwf(TL, {});
const fullText = W.emitSeqVwf(TL, { driveAll: true });
ok('3 roundtrip', 'stimulus emits one LEVEL X per observed bit channel',
  (function () {
    const bits = TL.leaves.filter((l) => l.dir === 'out' && !l.bus).map((l) => l.name);
    const span = 'LEVEL X FOR ' + W.fmtTime(TL.total) + ';';
    for (const b of bits) {
      const head = 'TRANSITION_LIST(' + String.fromCharCode(34) + b + String.fromCharCode(34) + ')';
      const i = stimText.indexOf(head);
      if (i < 0) return false;
      // cut the block at the NEXT transition list: a fixed-width window would swallow the
      // following channel's LEVEL lines and miscount the runs.
      const nxt = stimText.indexOf('TRANSITION_LIST', i + head.length);
      const blk = stimText.slice(i, nxt < 0 ? stimText.length : nxt);
      if ((blk.match(/LEVEL \S FOR/g) || []).length !== 1) return false;
      if (blk.indexOf(span) < 0) return false;
    }
    return bits.length === 8;
  })(), 'an observed bus bit is not a single LEVEL X spanning the run');

ok('3 roundtrip', 'Z appears in the emitted stimulus bus when asked',
  (fullText.match(/LEVEL Z FOR/g) || []).length > 0, (fullText.match(/LEVEL Z FOR/g) || []).length);

// Parse both back with the tools/bdf parser and compare EVERY channel at EVERY nanosecond.
function roundTrip(label, text, expectOutputs) {
  const tl = SC.parseVwf(text);
  let bad = null, samples = 0;
  for (const l of TL.leaves) {
    if (l.bus) continue;                                   // a BUS parent has no list of its own
    for (let t = 0; t <= TL.total; t++) {
      if (t === TL.total) continue;
      const want = W.levelAt(TL, l.name, t);
      const got = SC.sampleAt(tl, l.name, t);
      samples++;
      if (got === undefined) { bad = l.name + '@' + t + ' absent from the parse'; break; }
      if (!expectOutputs && l.dir === 'out') {
        if (got !== 'X') { bad = l.name + '@' + t + ' should be X in a stimulus, got ' + got; break; }
      } else if (got !== want) {
        bad = l.name + '@' + t + ' want ' + want + ' got ' + got;
        break;
      }
    }
    if (bad) break;
  }
  ok('3 roundtrip', label + ': every channel at every ns (' + samples + ' samples)', bad === null, bad);
  // segment boundaries, both sides, with the half-open convention
  let bbad = null;
  for (const l of TL.leaves) {
    if (l.bus) continue;
    for (const s of TL.segs[l.name]) {
      for (const t of [s.t0, s.t0 + 1e-6, s.t1 - 1e-6]) {
        if (t < 0 || t >= TL.total) continue;
        const want = W.levelAt(TL, l.name, t);
        const got = SC.sampleAt(tl, l.name, t);
        if (expectOutputs && got !== want) { bbad = l.name + '@' + t + ' want ' + want + ' got ' + got; break; }
        if (!expectOutputs && l.dir === 'out' && got !== 'X') { bbad = l.name + '@' + t + ' not X'; break; }
      }
      if (bbad) break;
    }
    if (bbad) break;
  }
  ok('3 roundtrip', label + ': boundaries honour the half-open rule', bbad === null, bbad);
  return tl;
}
roundTrip('stimulus shape', stimText, false);
const back = roundTrip('drive-all shape', fullText, true);

// The Z runs specifically.
{
  const zRuns = TL.segs['D[7]'].filter((s) => s.level === 'Z');
  ok('3 roundtrip', 'the timeline contains a genuine Z interval on D[7]', zRuns.length === 1 && zRuns[0].t0 === 60 && zRuns[0].t1 === 120,
    JSON.stringify(zRuns));
  ok('3 roundtrip', 'the parsed file reports Z there too',
    SC.sampleAt(back, 'D[7]', 110) === 'Z' && SC.sampleAt(back, 'D[0]', 110) === 'Z',
    SC.sampleAt(back, 'D[7]', 110));
  ok('3 roundtrip', 'a Z bus has no integer word value', W.wordAt(TL, 'D', 110) === null, W.wordAt(TL, 'D', 110));
  ok('3 roundtrip', 'clock edges survive the round trip',
    SC.sampleAt(back, 'CLK', 0) === '1' && SC.sampleAt(back, 'CLK', 10) === '0' &&
    SC.sampleAt(back, 'CLK', 20) === '1' && SC.sampleAt(back, 'CLK', 150) === '0');
  ok('3 roundtrip', 'runs of equal level are collapsed in the emitted text',
    (function () {
      const blk = /TRANSITION_LIST\("CLK"\)\s*\{([\s\S]*?)\n\}/.exec(fullText)[1];
      const runs = blk.match(/LEVEL \S FOR [\d.]+;/g) || [];
      for (let i = 1; i < runs.length; i++) if (runs[i] === runs[i - 1]) return false;
      return runs.length === TL.segs.CLK.length;
    })(), 'adjacent identical runs or a count mismatch');
}
// A second geometry: 1-bit channels only, grouped the VHDL_4_bit_memory way, plus a duty cycle
// that is not 50 percent and a phase offset.
{
  const ch2 = [{ name: 'C', dir: 'in' }, { name: 'Q1', dir: 'out' }, { name: 'Q2', dir: 'out' }, { name: 'Q3', dir: 'out' }, { name: 'Q4', dir: 'out' }];
  const tl2 = W.buildTimeline(ch2, [{ dur: 12, set: {} }, { dur: 12, set: {} }],
    { clock: { name: 'C', period: 12, duty: 30 }, total: 48 });
  const t2 = W.emitSeqVwf(tl2, { driveAll: true, groups: [{ name: 'QQ', members: ['Q1', 'Q2', 'Q3', 'Q4'] }] });
  const p2 = SC.parseVwf(t2);
  ok('3 roundtrip', 'uneven duty: high for 30 percent of the period',
    W.levelAt(tl2, 'C', 0) === '1' && W.levelAt(tl2, 'C', 3.5) === '1' && W.levelAt(tl2, 'C', 4) === '0' &&
    W.levelAt(tl2, 'C', 11.9) === '0' && W.levelAt(tl2, 'C', 12) === '1',
    [0, 3.5, 4, 11.9, 12].map((t) => W.levelAt(tl2, 'C', t)).join(''));
  ok('3 roundtrip', 'a GROUP name is not a SIGNAL and not a transition list',
    t2.indexOf('GROUP("QQ")') >= 0 && p2.QQ === undefined && t2.indexOf('SIGNAL("QQ")') < 0);
  ok('3 roundtrip', 'group members parse normally',
    SC.sampleAt(p2, 'Q1', 0) === 'X' || SC.sampleAt(p2, 'Q1', 0) !== undefined, String(SC.sampleAt(p2, 'Q1', 0)));
  ok('3 roundtrip', 'an empty set op is a pure delay', tl2.total === 48 && tl2.segs.Q1.length === 1);
}

// ===========================================================================
// 4. LEGACY PARITY - checkSeq reproduces tools/bdf/simcheck.mjs checkSim
// ===========================================================================
if (LEADFILES.length) {
  const spec = JSON.parse(fs.readFileSync(path.join(HERE, '../5_proby_polyarnosti/probe_reg.json'), 'utf8'));
  const txt = readText(LEADFILES[0]);
  const legacy = SC.checkSim(txt, spec, 0.5);
  const manual = spec.vectors.map((row, i) => ({ t: i * spec.period + spec.period * 0.5, expect: row, label: 'row ' + i }));
  const seq = K.checkSeq({ vwfText: txt, samples: manual });
  ok('4 parity', 'checkSim reports zero errors on probe_reg', legacy.errs.length === 0, JSON.stringify(legacy.errs).slice(0, 200));
  ok('4 parity', 'checkSeq agrees (zero mismatches) on the same wave', seq.ok, JSON.stringify(seq.mismatches).slice(0, 200));
  ok('4 parity', 'both cover the same rows', seq.samples === legacy.rows, seq.samples + ' vs ' + legacy.rows);
  const sugar = K.checkSeq({ vwfText: txt, opts: { period: spec.period, frac: 0.5, phases: spec.vectors.map((row) => ({ expect: row })) } });
  ok('4 parity', 'the opts.phases sugar equals explicit samples',
    sugar.checked === seq.checked && sugar.mismatches.length === seq.mismatches.length && sugar.ok === seq.ok,
    JSON.stringify(sugar).slice(0, 150));
} else skip('4 parity', 'probe_reg cross-check', 'no lead .sim.vwf on this host');

// ===========================================================================
// 5. NEGATIVE CASES - the rules must be able to fire
// ===========================================================================
{
  const txt = LEADFILES.length ? readText(LEADFILES[0]) : null;
  if (txt) {
    const r = K.checkSeq({ vwfText: txt, samples: [{ t: 450, expect: { NOSUCHCHANNEL: 0, 'Q[0]': 0 }, label: 'absent' }] });
    ok('5 negative', 'an absent channel is a mismatch, not a skip',
      !r.ok && r.absent.length === 1 && r.mismatches.some((m) => m.chan === 'NOSUCHCHANNEL' && m.got === '<absent>'),
      JSON.stringify(r.mismatches).slice(0, 200));
    ok('5 negative', 'an absent channel raises a loud warning', r.warn.some((w) => w.indexOf('ABSENT CHANNELS') === 0), JSON.stringify(r.warn).slice(0, 160));
    const bad = [{ t: 450, expect: { 'Q[4]': 1 }, label: 'sabotage' }];
    const rb = K.checkSeq({ vwfText: txt, samples: bad });
    ok('5 negative', 'a wrong expectation is caught with want/got/t/label',
      !rb.ok && rb.mismatches.length === 1 && rb.mismatches[0].want === '1' && rb.mismatches[0].got === '0' &&
      rb.mismatches[0].t === 450 && rb.mismatches[0].label === 'sabotage', JSON.stringify(rb.mismatches).slice(0, 200));
    const zc = [{ t: 200, expect: { 'Q[0]': 'Z' }, label: 'idle bus' }];
    const rz = K.checkSeq({ vwfText: txt, samples: zc });
    ok('5 negative', 'Z is accepted as a legitimate idle bus and counted', rz.ok && rz.zSeen === 1, JSON.stringify(rz).slice(0, 120));
    const rx = K.checkSeq({ vwfText: txt, samples: [{ t: 200, expect: { 'Q[0]': 0 }, label: 'Z demanded as 0' }] });
    ok('5 negative', 'a driven value does not satisfy a Z expectation by default',
      !rx.ok && rx.mismatches.length === 1, JSON.stringify(rx.mismatches).slice(0, 160));
    // relaxZ acts on a WANT of Z, letting a driven 0 or 1 satisfy it. It does not let a Z answer
    // a 0 expectation. probe_reg holds Q idle for the first 400 ns and drives it by 450.
    const rStrict = K.checkSeq({ vwfText: txt, samples: [{ t: 450, expect: { 'Q[0]': 'Z' } }] });
    ok('5 negative', 'a want of Z is refused where the bus is really driven',
      !rStrict.ok && rStrict.mismatches.length === 1, JSON.stringify(rStrict.mismatches).slice(0, 160));
    const rr = K.checkSeq({ vwfText: txt, samples: [{ t: 450, expect: { 'Q[0]': 'Z' } }], opts: { relaxZ: true } });
    ok('5 negative', 'opts.relaxZ lets that driven bit satisfy a Z expectation',
      rr.ok && rr.zSeen === 0, JSON.stringify(rr.mismatches).slice(0, 160));
  } else skip('5 negative', 'absent / sabotage / Z rules', 'no lead .sim.vwf on this host');

  // busWord must refuse to guess through X and Z
  if (LEADFILES.length) {
    const tl = SC.parseVwf(readText(LEADFILES[0]));
    ok('5 negative', 'busWord returns null on an idle (Z) bus, not 0', K.busWord(tl, 'Q', 8, 200) === null, String(K.busWord(tl, 'Q', 8, 200)));
    ok('5 negative', 'busWord returns the integer on a driven bus', K.busWord(tl, 'Q', 8, 450) === 170, String(K.busWord(tl, 'Q', 8, 450)));
    ok('5 negative', 'busWord returns null for a bus the response does not carry', K.busWord(tl, 'NOSUCH', 8, 450) === null);
    const idle = K.busWord(tl, 'Q', 8, 200);
    ok('5 negative', 'the parseInt trap is real: a half-idle word parses as a number',
      parseInt('0000ZZZZ', 2) === 0 && idle === null, 'parseInt gave ' + parseInt('0000ZZZZ', 2));
  } else skip('5 negative', 'busWord X/Z refusal', 'no lead .sim.vwf on this host');

  // the emitter and timeline must assert, not guess
  throws('5 negative', 'buildTimeline rejects an unknown channel', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }], [{ dur: 10, set: { B: 1 } }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a bus overflow', () =>
    W.buildTimeline([{ name: 'B', dir: 'in', bus: { width: 4 } }], [{ dur: 10, set: { B: 32 } }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a non-positive total', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }], [{ dur: 0, set: { A: 1 } }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a malformed level', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }], [{ dur: 10, set: { A: 'Q' } }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a duplicate channel', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }, { name: 'A', dir: 'out' }], [{ dur: 10 }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a bus of width 0 or 1', () =>
    W.buildTimeline([{ name: 'B', dir: 'in', bus: { width: 1 } }], [{ dur: 10 }]), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects an unknown clock name', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }], [{ dur: 10 }], { clock: { name: 'Z', period: 5 } }), 'seqvwf:');
  throws('5 negative', 'buildTimeline rejects a backwards at (a sequential stream cannot rewind)', () =>
    W.buildTimeline([{ name: 'A', dir: 'in' }], [{ at: 30, dur: 10, set: { A: 1 } }, { at: 5, dur: 10, set: { A: 0 } }]), 'seqvwf:');
  throws('5 negative', 'emitSeqVwf rejects a group naming a channel that is not there', () =>
    W.emitSeqVwf(W.buildTimeline([{ name: 'A', dir: 'in' }], [{ dur: 10 }]), { groups: [{ name: 'G', members: ['NOPE'] }] }), 'seqvwf:');
  // A sample past the end of the response is a MISMATCH, not a throw: the caller asked for a
  // level the wave does not contain, which is exactly the mistake worth reporting.
  const tiny = ['HEADER', '{', '\tVERSION = 1;', '\tTIME_UNIT = ns;', '\tSIMULATION_TIME = 10.0;',
    '\tGRID_PHASE = 0.0;', '\tGRID_PERIOD = 10.0;', '\tGRID_DUTY_CYCLE = 50;', '}', '',
    'SIGNAL("A")', '{', '\tVALUE_TYPE = NINE_LEVEL_BIT;', '\tSIGNAL_TYPE = SINGLE_BIT;', '\tWIDTH = 1;',
    '\tLSB_INDEX = -1;', '\tDIRECTION = INPUT;', '\tPARENT = "";', '}', '',
    'TRANSITION_LIST("A")', '{', '\tNODE', '\t{', '\t\tREPEAT = 1;', '\t\tLEVEL 0 FOR 10.0;', '\t}', '}', '',
    'TIME_BAR', '{', '\tTIME = 0;', '\tMASTER = TRUE;', '}', ';'].join(NL);
  const rp = K.checkSeq({ vwfText: tiny, samples: [{ t: 500, expect: { A: 0 }, label: 'past the end' }] });
  ok('5 negative', 'a sample past the response end is a mismatch',
    !rp.ok && rp.mismatches.length === 1 && rp.mismatches[0].got === 'past-end', JSON.stringify(rp.mismatches).slice(0, 160));
  const rk = K.checkSeq({ vwfText: tiny, samples: [{ t: 5, expect: { A: 0 } }] });
  ok('5 negative', 'the same wave passes when sampled inside its range', rk.ok, JSON.stringify(rk.mismatches).slice(0, 160));
  throws('5 negative', 'checkSeq rejects an empty vwfText', () => K.checkSeq({ vwfText: '', samples: [] }), 'seqcheck:');
  throws('5 negative', 'checkSeq rejects a sample with neither samples nor opts.phases', () =>
    K.checkSeq({ vwfText: 'HEADER { VERSION = 1; }' }), 'seqcheck:');
}

  // The emitter audits its own output with parseVwf (auditEmitted). One of the things it
  // guarantees is the fact section 1 measured: a bus bit is always NAME[i], never a bare NAMEi,
  // because Quartus 5.0 silently ignores a bare spelling and leaves the wire at X.
  {
    const t = W.emitSeqVwf(TL, { driveAll: true });
    const bare = /SIGNAL\("(?:D|A|Q)[0-9]"\)/.test(t);
    ok("5 negative", "the emitted text never spells a bus bit bare NAMEi", !bare, "found a bare bit");
    const parents = /SIGNAL\("(?:D|A|Q)"\)\s*\{[^}]*SIGNAL_TYPE = BUS;/.test(t);
    ok("5 negative", "bus parents are declared SIGNAL_TYPE = BUS", parents);
    const noParentList = !/TRANSITION_LIST\("(?:D|A|Q)"\)/.test(t);
    ok("5 negative", "a BUS parent carries no TRANSITION_LIST of its own", noParentList);
  }

// ===========================================================================
// 6. MODELS - internal self-tests, the divergence record, and full composition
// ===========================================================================
{
  const counts = MD.runAllSelfTests();
  const want = ['dffe', 'ram4', 'mem4x8', 'lpm_ram_dq'];
  ok('6 models', 'every model reports a positive state count',
    want.every((k) => Number.isInteger(counts[k]) && counts[k] > 0), JSON.stringify(counts));
  results.push({ section: '6 models', name: '  states checked', status: 'INFO', detail: JSON.stringify(counts) });

  // The behavioural-versus-gate divergence is a FINDING, not a bug, and the record must not be
  // able to vanish silently: ram4beh.vhd disables its buffer (q <= 'Z') where a real tri-state
  // with an X enable outputs X. seqvwf/models keep both and note the disagreement.
  const notes = MD.selfTestNotes();
  const pre = notes.filter((x) => x.indexOf('ram4 read') === 0);
  const mem = notes.filter((x) => x.indexOf('mem4x8 read') === 0);
  ok('6 models', 'the ram4 behavioural-versus-gate divergences are recorded', pre.length > 0, 'no notes');
  ok('6 models', 'the mem4x8 behavioural-versus-gate divergences are recorded', mem.length > 0, 'no notes');
  ok('6 models', 'every recorded note is behavioural Z versus gate-level X, nothing else',
    notes.every((x) => /behavioural Q=[XZ]+ vs gate-level Q=[XZ]+/.test(x) || /behavioural Q=\S+ but gate-level Q=\S+/.test(x)),
    notes.filter((x) => !/behavioural/.test(x))[0] || '');
  results.push({ section: '6 models', name: '  recorded divergences', status: 'INFO',
    detail: notes.length + ' (ram4 ' + pre.length + ', mem4x8 ' + mem.length + ')' });

  // The measured lpm_ram_dq rule is data in models.mjs, so a host-only run can re-check it.
  ok('6 models', 'models.mjs carries the two measured traces as data',
    Array.isArray(MD.LPRAMAX_MEASURED) && MD.LPRAMAX_MEASURED.length === 17 &&
    Array.isArray(MD.LPRAMWB_MEASURED) && MD.LPRAMWB_MEASURED.length === 11,
    (MD.LPRAMAX_MEASURED || []).length + '/' + (MD.LPRAMWB_MEASURED || []).length);
  const L = MD.lpmRamDqModel(8, 10);
  ok('6 models', 'the default write mode is the measured we-fall rule',
    L.write === 'we-fall' && L.sample === 'post', L.write + '/' + L.sample);
  ok('6 models', 'the measured rule reproduces all 28 phases',
    MD.replayMeasured(L, MD.LPRAMAX_MEASURED).length === 0 &&
    MD.replayMeasured(L, MD.LPRAMWB_MEASURED).length === 0,
    JSON.stringify(MD.replayMeasured(L, MD.LPRAMWB_MEASURED)).slice(0, 200));

  // DFFE power-on: X by default (the honest isolated-cell answer), overridable to the device
  // value that mem4x8's driven d bus makes observable.
  const D0 = MD.dffeInitial();
  const D1 = MD.dffeInitial({ q: '0' });
  ok('6 models', 'dffeInitial defaults to X and accepts an override',
    D0.q === 'X' && D1.q === '0', JSON.stringify(D0) + ' ' + JSON.stringify(D1));

  // ---- full composition: emitter -> file -> parser -> checker -> model -----
  // Build the stimulus, emit it, parse it back, sample the stimulus out of the PARSE (not out of
  // the timeline, so the parser is genuinely in the loop), step a model with those levels, feed
  // the model's answers back as output ops, re-emit, re-parse, and let checkSeq verify. This is
  // the whole stack confronting itself without a guest.
  {
    const M = MD.ram4Model(4);
    let st = M.initial({ cell: '0' });
    // 10 phases of 20 ns: write 1,0,1,0 into cells 0..3, then read them back. WE=1 phases also
    // carry a rising clock edge, so the write is qualified by both, exactly as ram4beh.vhd has it.
    const vec = [
      { WE: 1, A: 0, D: 1 }, { WE: 1, A: 1, D: 0 }, { WE: 1, A: 2, D: 1 }, { WE: 1, A: 3, D: 0 },
      { WE: 0, A: 0, D: 0 }, { WE: 0, A: 1, D: 0 }, { WE: 0, A: 2, D: 0 }, { WE: 0, A: 3, D: 0 },
      { WE: 0, A: 0, D: 0 }, { WE: 0, A: 3, D: 0 },
    ];
    const chans = [
      { name: 'CLK', dir: 'in' }, { name: 'WE', dir: 'in' },
      { name: 'A', dir: 'in', bus: { width: 2 } }, { name: 'D', dir: 'in' },
      { name: 'Q', dir: 'out' },                       // 1 bit, so a plain channel: a bus needs width >= 2
    ];
    const PER = 20, TOTAL = vec.length * PER;
    const stimOps = vec.map((v, i) => ({ at: i * PER, dur: PER, set: { WE: v.WE, A: v.A, D: v.D } }));
    const tlStim = W.buildTimeline(chans, stimOps, { clock: { name: 'CLK', period: PER }, total: TOTAL });
    const parsed = SC.parseVwf(W.emitSeqVwf(tlStim, { driveAll: true }));

    // Rising edges land on multiples of the period (measured above), so the model must be stepped
    // at the edge AND at the phase midpoint: sampling only mid-phase would show CLK = 0 every
    // time and the model would never see a 0 -> 1 transition, writing nothing.
    const preds = [];
    const samples = [];
    for (let i = 0; i < vec.length; i++) {
      for (const t of [i * PER, i * PER + PER / 2]) {
        const ins = {
          CLK: SC.sampleAt(parsed, 'CLK', t), WE: SC.sampleAt(parsed, 'WE', t),
          A: SC.sampleAt(parsed, 'A[1]', t) + SC.sampleAt(parsed, 'A[0]', t),
          D: SC.sampleAt(parsed, 'D', t),
        };
        st = M.step(st, ins);
        const Q = M.outputs(st, ins).Q;
        if (t === i * PER) preds.push(Q);
        samples.push({ t, expect: { Q: Q }, label: 'composed t=' + t });
      }
    }
    ok('6 models', 'the stimulus round-trips through the emitted file with real clock edges',
      preds.length === vec.length && preds.every((p) => '01ZX'.indexOf(p) >= 0) &&
      SC.sampleAt(parsed, 'CLK', 0) === '1' && SC.sampleAt(parsed, 'CLK', PER / 2) === '0',
      JSON.stringify(preds));

    // One op per phase: a timeline is a sequential script, so appending a second list whose at
    // values restart at 0 would run backwards, and buildTimeline asserts that.
    const fullOps = vec.map((v, i) => ({
      at: i * PER, dur: PER, set: { WE: v.WE, A: v.A, D: v.D, Q: preds[i] },
    }));
    const tlFull = W.buildTimeline(chans, fullOps, { clock: { name: 'CLK', period: PER }, total: TOTAL });
    const fullText = W.emitSeqVwf(tlFull, { driveAll: true });
    const r = K.checkSeq({ vwfText: fullText, samples: samples });
    ok('6 models', 'checkSeq verifies a model-driven output written by the emitter and read by the parser',
      r.ok && r.checked === samples.length, JSON.stringify(r.mismatches).slice(0, 200));
    ok('6 models', 'the composed wave holds the bus idle as Z during writes and the checker counts it',
      r.zSeen === 8 && r.xSeen === 0, 'zSeen=' + r.zSeen + ' xSeen=' + r.xSeen);
    // 4 write phases (WE=1, buffer disabled, Q = Z) then 6 read phases cycling cells 0,1,2,3,0,3
    ok('6 models', 'the composed read-back matches the behavioural contract of ram4beh.vhd',
      preds.slice(0, 4).join('') === 'ZZZZ' && preds.slice(4).join('') === '101010', JSON.stringify(preds));
    ok('6 models', 'the model ended holding 1,0,1,0 in cells 0..3', st.cells.join('') === '1010', st.cells.join(''));
  }
}

// ===========================================================================
// report
// ===========================================================================
const SEC = ['1 format', '2 Z', '3 roundtrip', '4 parity', '5 negative', '6 models'];
const NL2 = String.fromCharCode(10);
console.log(NL2 + 'lab13 sequential verification stack - self test' + NL2);
for (const s of SEC) {
  const rows = results.filter((r) => r.section === s);
  if (!rows.length) continue;
  const p = rows.filter((r) => r.status === 'PASS').length;
  const f = rows.filter((r) => r.status === 'FAIL').length;
  const k = rows.filter((r) => r.status === 'SKIP').length;
  console.log(NL2 + '[' + s + ']  ' + p + ' passed, ' + f + ' failed, ' + k + ' skipped');
  for (const r of rows) {
    const mark = r.status === 'PASS' ? '  ok  ' : r.status === 'FAIL' ? ' FAIL ' : ' skip ';
    console.log('  ' + mark + r.name + (r.detail ? NL2 + '         -> ' + r.detail : ''));
  }
}
const skipped = results.filter((r) => r.status === 'SKIP');
if (skipped.length) {
  console.log(NL2 + 'skipped, with the reason (these are host-availability gaps, not failures):');
  for (const r of skipped) console.log('  ' + r.name + ': ' + r.detail);
}
console.log(NL2 + (failures === 0
  ? 'RESULT: PASS - ' + results.filter((r) => r.status === 'PASS').length + ' assertions' + (skipped.length ? ', ' + skipped.length + ' skipped' : '')
  : 'RESULT: FAIL - ' + failures + ' assertion(s) failed'));
process.exit(failures === 0 ? 0 : 1);
