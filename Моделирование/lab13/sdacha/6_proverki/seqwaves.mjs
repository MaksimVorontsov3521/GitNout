// lab13/seqwaves.mjs - verify the RETURNED guest waves with models.mjs, through seqcheck.
//
// This is the independent second opinion the report asks for. The expectation is NOT taken from
// the spec array that was used to author the stimulus - it is computed by lab13/models.mjs, a
// separate implementation written without reference to either the schematic or the VHDL. The
// stimulus is read back out of the wave Quartus returned, so a wiring mistake has nowhere to
// hide: the model sees what the hardware saw, and any disagreement surfaces as a mismatch.
//
// Every comparison goes through seqcheck.checkSeq(), so the nine-level rules are applied in one
// place: an absent channel is a mismatch rather than a silent skip, Z is counted as legitimate
// idle-bus evidence (zSeen), and X is counted separately (xSeen) and listed in unexplainedX with
// a loud warning when the model did not predict it.
//
// Usage:
//   node lab13/seqwaves.mjs            # run every wave, print a table, write evidence json
//   import { verifyWave, WAVES } from './seqwaves.mjs'
//
// Evidence written: lab13/evidence/seqwaves.json

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkSeq, busWord, parseVwf, sampleAt } from './seqcheck.mjs';
import * as MD from './models.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
// sdacha: волны лежат в папках сдачи, а не в авторском дереве work/.
const WAVE_ROOT = {'ram4':'../1_ram4','ram4beh':'../2_ram4beh','mem4x8':'../3_mem4x8','lpramax':'../4_lpm_ram_dq','lpramwb':'../4_lpm_ram_dq','lpramfk':'../4_lpm_ram_dq','probe_tri':'../5_proby_polyarnosti','probe_trioe':'../5_proby_polyarnosti','probe_reg':'../5_proby_polyarnosti'};
const WORK = null;
const PER = 100;                       // every one of these waves runs GRID_PERIOD = 100
const mid = (i) => i * PER + PER / 2;  // phase midpoint: settled, and off every edge

// names are listed MSB first, so the returned level string reads like the wave's own bus.
const busAt = (tl, names, t) => names.map((n) => sampleAt(tl, n, t)).join('');
const range = (hi, lo) => { const a = []; for (let b = hi; b >= lo; b--) a.push(b); return a; };

// ---------------------------------------------------------------------------
// Wave descriptors. Each says: where the file is, how many phases, how to read
// the stimulus out of the wave into model operands, which model to step, and
// how the model's answer maps onto response channel names.
// ---------------------------------------------------------------------------
export const WAVES = {
  ram4: {
    what: 'task 1, figure 18.7 structural RAM',
    file: 'ram4_out/ram4.sim.vwf',
    phases: 20,
    // Cells start at '0' to match lab13/vhdl/ram4beh.vhd, whose cell array is (others => '0').
    // The same geometry therefore has to answer the same way in both tasks, so '0' is the
    // expectation source for BOTH ram4 and ram4beh; seqwaves reports if that assumption is what
    // a mismatch is really caused by.
    init: () => ({ cell: '0' }),
    model: () => MD.ram4Model(4),
    // stimulus: CLK, WE, A = A1 A0 (MSB first), D
    ins: (tl, t) => ({
      CLK: sampleAt(tl, 'CLK', t), WE: sampleAt(tl, 'WE', t),
      A: busAt(tl, ['A1', 'A0'], t), D: sampleAt(tl, 'D', t),
    }),
    // the read side of ram4 is combinational in WE: Q follows the addressed cell when WE = 0
    expect: (M, st, ins) => ({ Q: M.outputs(st, ins).Q }),
    chans: (e) => ({ Q: e.Q }),
  },
  ram4beh: {
    what: 'task 2, behavioural VHDL twin of the same circuit',
    file: 'ram4beh_out/ram4beh.sim.vwf',
    phases: 20,
    init: () => ({ cell: '0' }),
    model: () => MD.ram4Model(4),
    ins: (tl, t) => ({
      CLK: sampleAt(tl, 'clk', t), WE: sampleAt(tl, 'we', t),
      A: busAt(tl, ['a[1]', 'a[0]'], t), D: sampleAt(tl, 'd', t),
    }),
    expect: (M, st, ins) => ({ q: M.outputs(st, ins).Q }),
    chans: (e) => ({ q: e.q }),
  },
  mem4x8: {
    what: 'task 3, figure 18.8: 74155 decoder + 4x 74374 + 74244 output',
    file: 'mem4x8_out/mem4x8.sim.vwf',
    phases: 17,
    // Words start at '0' because that is what the wave shows: d[7..0] reads 00000000 at the
    // phase-0 midpoint, before the first wr rise, for an unwritten word. See the power-on note in
    // models.mjs - probe_reg cannot show this, mem4x8 can.
    init: () => ({ word: '0' }),
    model: () => MD.mem4x8Model({ words: 4, dataWidth: 8, addrWidth: 2 }),
    ins: (tl, t) => ({
      CLK: sampleAt(tl, 'wr', t), WE: '1',
      A: busAt(tl, ['a1', 'a0'], t),
      D: busAt(tl, range(7, 0).map((b) => 'w[' + b + ']'), t),
      rd: sampleAt(tl, 'rd', t),
    }),
    // d is the addressed word on the internal bus (the 74374 octal outputs are hard-enabled in
    // this sheet); q is d passed through the 74244, whose enable is rd.
    expect: (M, st, ins) => {
      const d = M.outputs(st, { OEN: '0', A: ins.A }).Q;
      return { d, q: ins.rd === '1' ? d : 'Z'.repeat(8) };
    },
    chans: (e) => {
      const o = {};
      for (let b = 0; b < 8; b++) { o['d[' + b + ']'] = e.d[7 - b]; o['q[' + b + ']'] = e.q[7 - b]; }
      return o;
    },
  },
  lpramax: {
    what: 'task 4, lpm_ram_dq 8x1024, all-unregistered (17 measured phases)',
    file: 'lpramax_out/lpramax.sim.vwf',
    phases: 17,
    init: () => ({}),                        // an ideal block: nothing written, reads X
    model: () => MD.lpmRamDqModel(8, 10),    // default write mode is the measured we-fall rule
    ins: (tl, t) => ({
      WE: sampleAt(tl, 'WE', t),
      A: busAt(tl, range(9, 0).map((b) => 'ADDRESS[' + b + ']'), t),
      D: busAt(tl, range(7, 0).map((b) => 'DATA[' + b + ']'), t),
    }),
    expect: (M, st, ins) => ({ DATAQ: M.outputs(st, { WE: ins.WE, A: ins.A, D: ins.D }).DATAQ }),
    chans: (e) => {
      const o = {};
      for (let b = 0; b < 8; b++) o['Q[' + b + ']'] = e.DATAQ[7 - b];
      return o;
    },
  },
  lpramwb: {
    what: 'task 4 probe, the write-rule discriminator (11 measured phases)',
    file: 'lpramwb_out/lpramwb.sim.vwf',
    phases: 11,
    init: () => ({}),
    model: () => MD.lpmRamDqModel(8, 10),
    ins: (tl, t) => ({
      WE: sampleAt(tl, 'WE', t),
      A: busAt(tl, range(9, 0).map((b) => 'ADDRESS[' + b + ']'), t),
      D: busAt(tl, range(7, 0).map((b) => 'DATA[' + b + ']'), t),
    }),
    expect: (M, st, ins) => ({ DATAQ: M.outputs(st, { WE: ins.WE, A: ins.A, D: ins.D }).DATAQ }),
    chans: (e) => {
      const o = {};
      for (let b = 0; b < 8; b++) o['Q[' + b + ']'] = e.DATAQ[7 - b];
      return o;
    },
  },
};

// ---------------------------------------------------------------------------
// verifyWave: step the model with the stimulus read back out of the wave, build one
// expectation set per phase from the MODEL, and let seqcheck.checkSeq do the comparing.
// ---------------------------------------------------------------------------
export function verifyWave(key, opts) {
  const o = opts || {};
  const d = WAVES[key];
  if (!d) throw new Error('seqwaves: unknown wave ' + key);
  const p = path.resolve(HERE, WAVE_ROOT[key], d.file.split('_out/')[1]);
  if (!fs.existsSync(p)) return { key, skipped: 'no returned wave at ' + p };
  const vwfText = fs.readFileSync(p, 'latin1');
  const tl = parseVwf(vwfText);
  const M = d.model();
  let st = M.initial(d.init ? d.init() : undefined);

  const samples = [];
  const trace = [];
  const exps = [];            // per-phase model answer, so busWord below compares phase i with phase i
  for (let i = 0; i < d.phases; i++) {
    const t = mid(i);
    const ins = d.ins(tl, t);
    st = M.step(st, ins);
    const e = d.expect(M, st, ins);
    samples.push({ t, expect: d.chans(e), label: key + ' phase ' + i });
    exps.push(e);
    trace.push(Object.assign({ phase: i, t }, ins, { model: d.summary ? d.summary(e) : e }));
  }

  const r = checkSeq({ vwfText, samples, opts: o.relaxZ ? { relaxZ: true } : undefined });

  // Wave-to-wave retention, reported so the evidence shows WHAT the memory ended up holding.
  const retained = key === 'ram4' || key === 'ram4beh' ? { cells: st.cells }
    : key === 'mem4x8' ? { words: st.words }
    : { words: st.mem.filter((w) => w !== 'XXXXXXXX') , written: st.written.filter(Boolean).length };

  // busWord cross-check: seqcheck.busWord must agree with the model on every driven phase and
  // must return null on every idle (Z) or unresolved (X) phase. This is the check that would
  // silently pass a floated bus as the value 0 if busWord were built on parseInt.
  let busWordBad = null, busWordChecked = 0, busNull = 0;
  const width = key === 'mem4x8' ? 8 : key === 'lpramax' || key === 'lpramwb' ? 8 : 0;
  if (width) {
    const base = key === 'mem4x8' ? 'q' : key === 'lpramax' || key === 'lpramwb' ? 'Q' : null;
    for (let i = 0; i < d.phases && !busWordBad; i++) {
      const t = mid(i);
      const e = exps[i];
      const wordStr = base === 'q' ? e.q : base === 'Q' ? e.DATAQ : null;
      if (wordStr == null) continue;
      const got = busWord(tl, base, width, t);
      const want = /^[01]+$/.test(wordStr) ? parseInt(wordStr, 2) : null;
      busWordChecked++;
      if (got === null) busNull++;
      if (got !== want) busWordBad = 'phase ' + i + ' busWord ' + got + ' vs model ' + want;
    }
  }

  return {
    key, what: d.what, path: p, phases: d.phases,
    ok: r.ok, checked: r.checked, mismatches: r.mismatches.length,
    zSeen: r.zSeen, xSeen: r.xSeen,
    unexplainedX: r.unexplainedX.length, absent: r.absent.length, warn: r.warn,
    firstMismatch: r.mismatches[0] || null,
    busWord: width ? { checked: busWordChecked, nullReads: busNull, bad: busWordBad } : null,
    retained, trace,
    model: M.name + (M.write ? ' write=' + M.write + '/' + M.sample : ''),
  };
}

export function verifyAll(keys, opts) {
  const out = {};
  for (const k of keys || Object.keys(WAVES)) out[k] = verifyWave(k, opts);
  return out;
}

// ---------------------------------------------------------------------------
// report
// ---------------------------------------------------------------------------
if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('lab13/seqwaves.mjs')) {
  const res = verifyAll();
  const NL = String.fromCharCode(10);
  const pad = (s, n) => String(s).padEnd(n);
  console.log(NL + 'wave       phases  checked  mism  zSeen  xSeen  unexplX  absent  busWord  verdict');
  let totalMismatch = 0, totalBusBad = 0;
  for (const k of Object.keys(res)) {
    const r = res[k];
    if (r.skipped) { console.log(pad(k, 10) + '  SKIPPED: ' + r.skipped); continue; }
    totalMismatch += r.mismatches;
    if (r.busWord && r.busWord.bad) totalBusBad++;
    console.log([
      pad(k, 10), pad(r.phases, 8), pad(r.checked, 8), pad(r.mismatches, 5), pad(r.zSeen, 6),
      pad(r.xSeen, 6), pad(r.unexplainedX, 8), pad(r.absent, 7),
      pad(r.busWord ? r.busWord.checked + '/' + r.busWord.nullReads + ' null' : '-', 8),
      r.ok && !(r.busWord && r.busWord.bad) ? 'PASS' : 'FAIL',
    ].join(' '));
  }
  console.log(NL + 'retained state per wave:');
  for (const k of Object.keys(res)) {
    const r = res[k];
    if (r.skipped) continue;
    console.log('  ' + pad(k, 10) + ' ' + JSON.stringify(r.retained).slice(0, 200));
  }
  const warns = Object.keys(res).filter((k) => !res[k].skipped && res[k].warn.length);
  if (warns.length) {
    console.log(NL + 'seqcheck warnings (X/Z findings, not necessarily failures):');
    for (const k of warns) for (const w of res[k].warn) console.log('  ' + k + ': ' + w);
  }
  const ev = {
    generatedBy: 'lab13/seqwaves.mjs',
    note: 'expectations computed by lab13/models.mjs, stimulus read back out of each returned wave, comparison by lab13/seqcheck.mjs checkSeq',
    waves: res,
    verdict: totalMismatch === 0 && totalBusBad === 0
      ? 'EVERY RETURNED WAVE CONFRONTS models.mjs THROUGH seqcheck WITH ZERO MISMATCHES'
      : 'MISMATCHES: ' + totalMismatch + ' channel comparisons, busWord failures: ' + totalBusBad,
  };
  const out = path.join(HERE, 'evidence/seqwaves.json');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(ev, null, 1), 'utf8');
  console.log(NL + 'VERDICT: ' + ev.verdict);
  console.log('evidence: ' + out);
  if (totalMismatch !== 0 || totalBusBad !== 0) process.exit(1);
}
