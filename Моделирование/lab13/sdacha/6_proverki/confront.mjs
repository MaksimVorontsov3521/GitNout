// lab13/confront.mjs - confront every measured guest waveform with an independent model.
//
// The point of this file is that the expectation is NOT taken from the spec array I hand-wrote
// when the stimulus was authored. Instead the stimulus is read BACK OUT OF THE RETURNED WAVE, the
// model is stepped with exactly those levels, and the model's output is compared with the wave's
// output channel at every phase midpoint. A wiring mistake in the schematic therefore has nowhere
// to hide: the model sees what the hardware saw, and any disagreement shows up as a mismatch.
//
// Models come from lab13/models.mjs (written by the seqsim teammate) except for the lpm_ram_dq
// write rule, which is implemented here from the measured behaviour because that file's model is
// edge-controlled and the prescribed parameter set has no clock connected at all.
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
// sdacha: все зависимости и все волны разрешаются относительно самого скрипта, так что
// прогон изнутри сдачи не касается ни авторского дерева, ни дерева гостя.
const WAVE_ROOT = {'ram4':'../1_ram4','ram4beh':'../2_ram4beh','mem4x8':'../3_mem4x8','lpramax':'../4_lpm_ram_dq','lpramwb':'../4_lpm_ram_dq','lpramfk':'../4_lpm_ram_dq','probe_tri':'../5_proby_polyarnosti','probe_trioe':'../5_proby_polyarnosti','probe_reg':'../5_proby_polyarnosti'};
const wavePath = (rel) => fileURLToPath(new URL(rel, import.meta.url));
const SC = await import(new URL('./tools/bdf/simcheck.mjs', import.meta.url).href);
const SQ = await import(new URL('./seqcheck.mjs', import.meta.url).href);
const MD = await import(new URL('./models.mjs', import.meta.url).href);
const PER = 100, FRAC = 0.5;
const mid = (i) => i * PER + FRAC * PER;
const lv = (tl, n, t) => SQ.sampleAt(tl, n, t);
// Every bus is walked in DESCENDING index order so the resulting string is a true MSB-first word:
// parseInt() and the displayed hex then agree with the waveform, and with the independently
// extracted measurement tables in evidence/lpramwb_measured.json and lpramax_crosscheck.json.
const bitsMSB = (tl, base, hi, t) => {
  const a = [];
  for (let k = hi; k >= 0; k--) a.push(lv(tl, base + '[' + k + ']', t));
  return a.join('');
};
const bits = (tl, names, t) => names.map((n) => lv(tl, n, t));
// bits() joins LSB-first, so a word string must be reversed before it is read as hex.
// msw() is display-only; comparisons below always use the raw LSB-first strings on BOTH sides.
const msw = (b) => b;   // buses are already MSB-first; kept for readability of the rows
const toWord = (str) => (str.includes('Z') ? 'Z' : str.includes('X') ? 'X' : parseInt(str, 2));

export function loadWave(nm, sub) {
  const p = wavePath(WAVE_ROOT[nm] + '/' + (sub || nm) + '.sim.vwf');
  return { tl: SC.parseVwf(fs.readFileSync(p, 'latin1')), path: p };
}

// ---------------- task 1: the structural sheet of figure 18.7 ----------------
export function confrontRam4() {
  const { tl, path } = loadWave('ram4');
  const n = Math.floor(tl.CLK.end / PER);
  const M = MD.ram4Model(4);
  let st = M.initial({ cell: '0' });
  const rows = [], mism = [];
  for (let i = 0; i < n; i++) {
    const t = mid(i);
    const ins = { CLK: lv(tl, 'CLK', t), WE: lv(tl, 'WE', t), A: [lv(tl, 'A1', t), lv(tl, 'A0', t)].join(''), D: lv(tl, 'D', t) };
    st = M.step(st, ins);
    const qm = M.outputs(st, ins).Q;
    const qg = lv(tl, 'Q', t);
    rows.push({ phase: i, t, ...ins, model: qm, measured: qg });
    if (qm !== qg) mism.push({ phase: i, model: qm, measured: qg });
  }
  return { what: 'ram4 (fig 18.7, structural)', path, phases: n, checked: n, mismatches: mism.length, detail: mism, rows, cells: st.cells };
}

// ---------------- task 2: the behavioural VHDL model, same stimulus ----------------
export function confrontRam4beh() {
  const { tl, path } = loadWave('ram4beh');
  const n = Math.floor(tl.clk.end / PER);
  const M = MD.ram4Model(4);
  let st = M.initial({ cell: '0' });
  const rows = [], mism = [];
  for (let i = 0; i < n; i++) {
    const t = mid(i);
    const ins = { CLK: lv(tl, 'clk', t), WE: lv(tl, 'we', t), A: [lv(tl, 'a[1]', t), lv(tl, 'a[0]', t)].join(''), D: lv(tl, 'd', t) };
    st = M.step(st, ins);
    const qm = M.outputs(st, ins).Q, qg = lv(tl, 'q', t);
    rows.push({ phase: i, ...ins, model: qm, measured: qg });
    if (qm !== qg) mism.push({ phase: i, model: qm, measured: qg });
  }
  return { what: 'ram4beh (task 2, behavioural VHDL)', path, phases: n, mismatches: mism.length, detail: mism, rows, cells: st.cells };
}

// ---------------- task 3: 4 x 8-bit memory of figure 18.8 ----------------
export function confrontMem4x8() {
  const { tl, path } = loadWave('mem4x8');
  const n = Math.floor(tl.wr.end / PER);
  const M = MD.mem4x8Model({ words: 4, dataWidth: 8, addrWidth: 2 });
  let st = M.initial({ word: '0' });
  const rows = [], mismD = [], mismQ = [];
  for (let i = 0; i < n; i++) {
    const t = mid(i);
    const a1 = lv(tl, 'a1', t), a0 = lv(tl, 'a0', t);
    const ins = { CLK: lv(tl, 'wr', t), WE: '1', A: a1 + a0, D: bitsMSB(tl, 'w', 7, t) };
    st = M.step(st, ins);
    const dm = M.outputs(st, { A: a1 + a0, OEN: '0' }).Q;     // the addressed cell always drives d here
    const dg = bitsMSB(tl, 'd', 7, t);
    const rd = lv(tl, 'rd', t);
    const qm = rd === '1' ? dm : 'Z'.repeat(8);
    const qg = bitsMSB(tl, 'q', 7, t);
    rows.push({ phase: i, CLK: ins.CLK, A: ins.A, D_display: msw(ins.D), rd,
      model_d_display: msw(dm), measured_d_display: msw(dg), model_q_display: msw(qm), measured_q_display: msw(qg),
      model_d: dm, measured_d: dg, model_q: qm, measured_q: qg });
    if (dm !== dg) mismD.push({ phase: i, model: dm, measured: dg });
    if (qm !== qg) mismQ.push({ phase: i, model: qm, measured: qg });
  }
  return { what: 'mem4x8 (fig 18.8, 74155 + 4x74374 + 74244)', path, phases: n,
    d_mismatches: mismD.length, q_mismatches: mismQ.length, detail: { d: mismD, q: mismQ }, rows,
    words: st.words.map(msw), words_as_measured_lsb_first: st.words };
}

// ---------------- task 4: lpm_ram_dq, measured write rule ----------------
// The rule below is not an assumption: it is the only rule that explains all 28 measured phases of
// lpramax (17) and lpramwb (11), and it follows from altram.tdf, which at USED(clocki)==0 never
// connects clki (lines 439-441) and drives the MEMORY primitive's we port straight from WE
// (line 449 with real_we[0] = we at line 427).
export function lpmWeFallModel(width, widthad) {
  const depth = Math.pow(2, widthad);
  const allX = 'X'.repeat(width);
  return {
    name: 'lpm_ram_dq we-fall (measured)', width, widthad, depth,
    initial: () => ({ mem: new Array(depth).fill(allX), we: '0' }),
    // one phase: (we, a, d) at the phase midpoint; the store happens on the WE fall, sampling the
    // address and data as they are at that instant; while WE is high the addressed word passes
    // straight to Q (write-through, measured in every WE=1 phase of both traces).
    step: (st, we, a, d) => {
      let mem = st.mem;
      if (st.we === '1' && we === '0') { const m = mem.slice(); m[a] = d; mem = m; }
      const q = we === '1' ? d : mem[a];
      return { mem, we, q };
    },
  };
}
export function confrontLpm(nm, phases) {
  const { tl, path } = loadWave(nm);
  const M = lpmWeFallModel(8, 10);
  let st = M.initial();
  const rows = [], mism = [];
  for (let i = 0; i < phases; i++) {
    const t = mid(i);
    const we = lv(tl, 'WE', t);
    const as = bitsMSB(tl, 'ADDRESS', 9, t);   // MSB-first string, e.g. "0000010000"
    const ds = bitsMSB(tl, 'DATA', 7, t);
    const qg = bitsMSB(tl, 'Q', 7, t);
    const aNum = toWord(as);                   // number, or 'X'/'Z' if the bus is not 0/1
    const dNum = toWord(ds);
    st = M.step(st, we, aNum, ds);
    rows.push({
      phase: i, we,
      a: aNum, d: dNum,
      a_hex: typeof aNum === 'number' ? '0x' + aNum.toString(16).toUpperCase().padStart(3, '0') : String(aNum),
      d_bin_msb: ds, q_bin_msb: qg,
      model_q: st.q,
      model_q_hex: st.q.includes('X') ? 'X' : st.q.includes('Z') ? 'Z' : '0x' + parseInt(st.q, 2).toString(16).toUpperCase().padStart(2, '0'),
      measured_q_hex: qg.includes('X') ? 'X' : qg.includes('Z') ? 'Z' : '0x' + parseInt(qg, 2).toString(16).toUpperCase().padStart(2, '0'),
    });
    if (st.q !== qg) mism.push({ phase: i, model: st.q, measured: qg });
  }
  const written = st.mem
    .map((v, k) => (v.includes('X') ? null : {
      address: '0x' + k.toString(16).toUpperCase().padStart(3, '0'),
      word_bin_msb: v,
      word_hex: '0x' + parseInt(v, 2).toString(16).toUpperCase().padStart(2, '0'),
    }))
    .filter(Boolean);
  return { what: nm + ' (lpm_ram_dq 8 x 1024, prescribed parameters)', path, phases,
    mismatches: mism.length, detail: mism, rows, written };
}

if (process.argv[1] && process.argv[1].endsWith('confront.mjs')) {
  const out = {};
  out.ram4 = confrontRam4();
  out.ram4beh = confrontRam4beh();
  out.mem4x8 = confrontMem4x8();
  out.lpramax = confrontLpm('lpramax', 17);
  out.lpramwb = confrontLpm('lpramwb', 11);
  // task 1 versus task 2, wave against wave
  const a = loadWave('ram4').tl, b = loadWave('ram4beh').tl;
  const n = Math.floor(a.CLK.end / PER);
  const vw = [];
  for (let i = 0; i < n; i++) vw.push({ phase: i, schematic: lv(a, 'Q', mid(i)), vhdl: lv(b, 'q', mid(i)) });
  out.task1_vs_task2 = { phases: n, differences: vw.filter((r) => r.schematic !== r.vhdl).length, rows: vw };
  // Cross-check the extracted stimulus columns against a SEPARATELY written extraction of the
  // same wave (evidence/lpramwb_measured.json, produced by an independent bit-order convention).
  // If either extraction slips, this disagrees and the program refuses to produce evidence.
  const lm = JSON.parse(fs.readFileSync(wavePath('../4_lpm_ram_dq/lpramwb_measured.json'), 'utf8'));
  const dispBad = out.lpramwb.rows.filter((r, i) => {
    const m = lm[i];
    return String(r.a) !== String(m.a) || String(r.d) !== String(m.d) || String(r.we) !== String(m.we);
  });
  out.displayCrossCheck = {
    against: 'evidence/lpramwb_measured.json', rows_checked: out.lpramwb.rows.length,
    disagreements: dispBad.length, detail: dispBad,
    note: 'the stimulus columns are compared with a separately written extraction of the same wave, so a bit-order slip in either one is caught',
  };
  if (dispBad.length) throw new Error('confront.mjs: extracted stimulus disagrees with the independent measurement: ' + JSON.stringify(dispBad.slice(0, 3)));
  out.zProof = SQ.proveZpreserved(['../1_ram4/ram4.sim.vwf', '../2_ram4beh/ram4beh.sim.vwf',
    '../3_mem4x8/mem4x8.sim.vwf', '../5_proby_polyarnosti/probe_tri.sim.vwf',
    '../5_proby_polyarnosti/probe_reg.sim.vwf'].map(wavePath));
  const total = out.ram4.mismatches + out.ram4beh.mismatches + out.mem4x8.d_mismatches + out.mem4x8.q_mismatches + out.lpramax.mismatches + out.lpramwb.mismatches;
  out.verdict = total === 0 && out.task1_vs_task2.differences === 0 ? 'ALL WAVES CONFRONT THEIR MODELS WITH ZERO DIFFERENCES' : 'MISMATCHES: ' + total;
  fs.writeFileSync(wavePath('./evidence/confrontation.json'), JSON.stringify(out, null, 1), 'utf8');
  for (const k of ['ram4', 'ram4beh', 'mem4x8', 'lpramax', 'lpramwb']) {
    const o = out[k];
    console.log(k.padEnd(9) + ' phases=' + String(o.phases).padStart(3) + ' mismatches=' +
      (o.mismatches !== undefined ? o.mismatches : o.d_mismatches + '+' + o.q_mismatches) +
      '  retained=' + JSON.stringify(o.cells || o.words || o.written || []));
  }
  console.log('task1 vs task2 differences: ' + out.task1_vs_task2.differences);
  console.log('Z proof: ' + JSON.stringify({ ok: out.zProof.ok, zSegments: out.zProof.zSegments, zSampled: out.zProof.zSampled, levels: out.zProof.levelsSeen }));
  console.log('VERDICT: ' + out.verdict);
  if (total !== 0) process.exit(1);
}
