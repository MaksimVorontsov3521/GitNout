// lab13/models.mjs - pure reference models for the lab 13 (chapter 18) memory circuits.
//
// These are the OTHER side of the measurement: the guest compiles a schematic or a VHDL
// architecture, and these models state what the same contract says with no gates in it. A
// mismatch between a returned .sim.vwf and a model here is a finding about the design, not
// about this file - which is why every model is self-tested exhaustively (selfTest() returns
// the number of (state, input) pairs it exercised) and why nothing here imports the emitter,
// the parser or the timeline. Models and waveform stack stay independent so they can be
// confronted.
//
// UNIFORM INTERFACE (so a driver can walk any of them the same way)
//   model.initial(opts?) -> state          a fresh, immutable-by-convention state
//   model.step(state, ins) -> state        advance the sequential part (clock edges only)
//   model.output(state, ins) -> value      combinational view: what the pins show NOW
//   model.selfTest() -> number             states checked, throws on an internal contradiction
// Values are nine-valued level strings '0' '1' 'X' 'Z' unless noted; a bus is a level string
// written MSB first ('0000ZZZZ'), or an integer where one is unambiguous.
//
// INPUT SPELLING
//   Every model takes a plain object of named inputs, e.g. { CLK, WE, A, D }. An address may
//   be given as an integer (0..2^widthad-1) or as a MSB-first level string ('10'); a data
//   word may be an integer or a MSB-first level string. Anything not exactly '0' or '1' is
//   unresolved and propagates as documented per model rather than being coerced to 0.
//
// WHAT IS MEASURED AND WHAT IS ASSUMED
//   * DFFE async pins: tools/bdf/primitives.json defines DFFE with PRN (dy 0) and CLRN (dy 80)
//     and enadff.bdf straps both pins to VCC inside the macrofunction, so in the lab sheets
//     they are permanently inactive ('1'). Section 18.3.1 of the course text says the same in
//     words ("when they hang in the air they carry a 1"). Active-low asynchronous behaviour is
//     therefore implemented but is never exercised by a correctly wired sheet.
//   * THE POWER-ON LEVEL, now measured rather than assumed. Two returned waves disagree about
//     whether it can be seen, and both readings are correct for their own circuit:
//       - probe_reg: Q[7..0] sits at 'Z' for the first 400 ns, through every row before the
//         first rising edge, because OEN disables the octal buffer. The cell state is hidden, so
//         that wave cannot settle the question.
//       - mem4x8: the data bus d[7..0] is driven from t=0 (verified at the phase-0 midpoint,
//         before the first wr rise at t=100), and reads 00000000 for a word nobody has written.
//         So a 74374 in this Quartus functional simulation powers up at '0', not 'X'.
//     dffeInitial() still defaults to 'X' - the honest answer for a cell in isolation, and the
//     level a correctly wired sheet never reveals - and takes { q } to override; mem4x8Model and
//     ram4Model are driven with an explicit initial word by anyone who needs the device value.
//     ram4 defaults to '0' and mem4x8 to 'X' for different reasons, both stated below.
//   * ram4 cells default to '0' because lab13/vhdl/ram4beh.vhd declares
//     "signal cell : cell_array := (others => '0')" - the behavioural twin this structural
//     reference has to agree with. Its read side mirrors that file exactly, including
//     "when others => q <= 'Z'" for an address that does not resolve.
//   * mem4x8 and lpm_ram_dq default unwritten words to 'X': an ideal RAM has no power-on
//     content, and the lead's lpm_ram_dq evidence shows X for a word never written.


const LV = ['0', '1', 'X', 'Z'];
const fail = (msg) => { throw new Error('models: ' + msg); };
const is01 = (s) => s === '0' || s === '1';

// Where a self-test finds two legitimate descriptions of the same circuit disagree, it records
// the fact here instead of choosing silently. selfTestNotes() drains the list.
const NOTES = [];
function note(msg) { NOTES.push(msg); }
export function selfTestNotes() { const c = NOTES.slice(); NOTES.length = 0; return c; }


export function level(v, what) {
  if (typeof v === 'number') {
    if (v === 0) return '0';
    if (v === 1) return '1';
    return fail((what || 'value') + ': expected 0, 1 or a level string, got ' + v);
  }
  if (typeof v === 'string') {
    const s = v.toUpperCase();
    if (LV.indexOf(s) >= 0 && s.length === 1) return s;
    return fail((what || 'value') + ': unknown level ' + JSON.stringify(v));
  }
  return fail((what || 'value') + ': expected a level, got ' + typeof v);
}

// A level word MSB first. Accepts an integer (with its width) or a level string / array.
export function word(v, width, what) {
  if (typeof v === 'number') {
    if (!Number.isInteger(v) || v < 0 || v >= Math.pow(2, width)) {
      return fail((what || 'word') + ': ' + v + ' does not fit in ' + width + ' bits');
    }
    let s = '';
    for (let k = width - 1; k >= 0; k--) s += String((v >> k) & 1);
    return s;
  }
  const arr = Array.isArray(v) ? v : String(v).split('');
  if (arr.length !== width) {
    return fail((what || 'word') + ': ' + JSON.stringify(v) + ' is ' + arr.length + ' chars, expected ' + width);
  }
  return arr.map((x) => level(x, what)).join('');
}

// Integer value of a resolved word, or null if any bit is X or Z.
export function wordValue(w) {
  for (const ch of w) if (!is01(ch)) return null;
  return parseInt(w, 2);
}

// ---- DFFE ---------------------------------------------------------------
// The storing element of section 18.3.1. The course text calls it the DV trigger; the Altera
// primitive is DFFE, and enadff.bdf wraps it with PRN and CLRN strapped to VCC (verified in
// ../lib_maxplus2/enadff.bdf: its INPUT pins carry VCC symbols for PRN and
// CLRN, and the symbol inside is DFFE with ports PRN, CLRN, D, CLK, ENA, Q).
//
//   dffeInitial(opts)     -> { q, clk }   fresh state; q defaults to X, clk to 0
//   dffeStep(state, ins)  -> { q, clk }   a NEW state; the argument is never mutated
//   ins has D, CLK and optional ENA, PRN, CLRN (each defaulting to a level of 1)
//
// Order of evaluation - this is what asynchronous means for PRN and CLRN:
//   1. CLRN low            -> q becomes 0, no clock edge needed
//   2. PRN low             -> q becomes 1
//   3. both low together   -> q becomes X (undefined; the model will not invent a winner)
//   4. an unresolved async pin -> q becomes X (a wire nobody drove is not a 1 in simulation,
//      even though the lab sheet ties it to VCC)
//   5. otherwise, on a CLEAN low-to-high clock transition only:
//      ENA high stores D; ENA low holds; ENA unresolved makes q X.
//      Any other clock movement - falling edge, X, Z, no change - leaves q alone.
// The state carries clk, the last observed clock level, because edge detection needs it.

export function dffeInitial(opts) {
  const o = opts || {};
  return {
    q: o.q == null ? 'X' : level(o.q, 'dffeInitial q'),
    clk: o.clk == null ? '0' : level(o.clk, 'dffeInitial clk'),
  };
}

export function dffeStep(st, ins) {
  const s = st || dffeInitial();
  const q0 = level(s.q, 'dffe q');
  const clk0 = level(s.clk, 'dffe clk');
  const D = level(ins.D, 'D');
  const CLK = level(ins.CLK, 'CLK');
  const ENA = ins.ENA == null ? '1' : level(ins.ENA, 'ENA');
  const PRN = ins.PRN == null ? '1' : level(ins.PRN, 'PRN');
  const CLRN = ins.CLRN == null ? '1' : level(ins.CLRN, 'CLRN');
  let q = q0;
  if (CLRN === '0' && PRN === '0') q = 'X';
  else if (CLRN === '0') q = '0';
  else if (PRN === '0') q = '1';
  else if (!is01(CLRN) || !is01(PRN)) q = 'X';
  else if (clk0 === '0' && CLK === '1') {
    if (ENA === '1') q = D;
    else if (ENA === '0') q = q0;
    else q = 'X';
  }
  return { q, clk: CLK };
}

// DFFE in the uniform model shape used by every model in this file.
export function dffeModel(opts) {
  const o = opts || {};
  return {
    name: 'dffe',
    initial: () => dffeInitial(o),
    step: (st, ins) => dffeStep(st, ins),
    outputs: (st, ins) => ({ Q: dffeStep(st, Object.assign({}, ins, { CLK: st.clk })).q }),
    selfTest: dffeSelfTest,
  };
}

function dffeSelfTest() {
  let n = 0;
  const vals = ['0', '1', 'X'];
  // exhaustive over q, clk, D, CLK, ENA, PRN, CLRN = 3^7 = 2187 transitions
  for (const q of vals) for (const clk of vals) for (const D of vals) for (const C of vals)
    for (const ena of vals) for (const prn of vals) for (const clrn of vals) {
      const next = dffeStep({ q, clk }, { D, CLK: C, ENA: ena, PRN: prn, CLRN: clrn });
      n++;
      if (next.clk !== C) fail('dffe: clock level not recorded');
      if (LV.indexOf(next.q) < 0) fail('dffe: output level out of vocabulary');
      let want;                                                   // re-derived from the words above
      if (clrn === '0' && prn === '0') want = 'X';
      else if (clrn === '0') want = '0';
      else if (prn === '0') want = '1';
      else if (!is01(clrn) || !is01(prn)) want = 'X';
      else if (clk === '0' && C === '1') want = ena === '1' ? D : (ena === '0' ? q : 'X');
      else want = q;
      if (next.q !== want) {
        fail('dffe: q=' + q + ' clk=' + clk + ' D=' + D + ' CLK=' + C + ' ENA=' + ena +
          ' PRN=' + prn + ' CLRN=' + clrn + ' gave ' + next.q + ', expected ' + want);
      }
    }
  const a = { q: '1', clk: '0' };
  const frozen = JSON.stringify(a);
  dffeStep(a, { D: '0', CLK: '1' });
  if (JSON.stringify(a) !== frozen) fail('dffeStep mutated its argument');
  n++;
  const edge = (st, ins) => dffeStep(st, ins).q;
  const z = dffeInitial({ q: '0' });
  if (edge(z, { D: '1', CLK: '1' }) !== '1') fail('dffe: rising edge did not store D'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '0' }) !== '1') fail('dffe: falling edge moved the output'); n++;
  if (edge(z, { D: '0', CLK: '1', ENA: 'X' }) !== 'X') fail('dffe: an unresolved ENA must make q X'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '1', ENA: '0' }) !== '1') fail('dffe: ENA=0 let a write through'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '1', ENA: '1' }) !== '0') fail('dffe: ENA=1 blocked a write'); n++;
  if (edge(z, { D: '1', CLK: '0', CLRN: '0' }) !== '0') fail('dffe: CLRN=0 did not clear asynchronously'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '0', PRN: '0' }) !== '1') fail('dffe: PRN=0 did not preset asynchronously'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '1', CLRN: '0', PRN: '0' }) !== 'X') fail('dffe: simultaneous clear and preset must be undefined'); n++;
  if (edge(dffeInitial({ q: '1' }), { D: '0', CLK: '1', CLRN: 'X' }) !== 'X') fail('dffe: a floating CLRN is not a 1 in simulation'); n++;
  if (dffeInitial().q !== 'X') fail('dffe: an unwritten cell should read as unresolved'); n++;
  return n;
}

// ---- ram4: the simplest memory of figure 18.7 ---------------------------
// n cells of ONE bit each, addressed by ceil(log2 n) bits (n = 4 gives the 2-bit address of
// the figure). Structurally it is: an address decoder of invertors and AND gates producing n
// write enables, n DFFE cells sharing one clock, and n tri-state buffers tying the cells to
// one shared Q. This model states the same contract with no gates in it, and it is written to
// agree with lab13/vhdl/ram4beh.vhd line by line, because that file is the behavioural twin
// the chapter asks to be confronted with the structural sheet:
//
//   * WE = '1' selects WRITE mode, WE = '0' selects READ mode (ram4beh.vhd process 1);
//   * a write is taken on the RISING edge of the common clock, and only by the cell whose
//     address matches - every other cell sees ENA = '0' from its AND gate;
//   * the read is COMBINATIONAL: the selected cell drives Q through its tri-state buffer, and
//     while WE = '1' no buffer is enabled, so Q floats to 'Z';
//   * an address that does not resolve (any bit X or Z) selects no cell, so Q is 'Z' - the
//     same answer ram4beh.vhd gives through its "when others => q <= 'Z'" branch;
//   * cells power up at '0', matching "signal cell : cell_array := (others => '0')".
//
//   ram4Model(n)  ->  { name, words, addrWidth, initial, step, outputs, readCell, selfTest }
//   state = { cells: [level x n], clk: level }
//   step(st, { CLK, WE, A, D })      A: integer or MSB-first level string of addrWidth bits
//   outputs(st, { WE, A })           -> { Q: level }
// Does address word A (MSB first, addrWidth bits) definitely select cell i?
// Returns 1 for certainly, 0 for certainly not, X for "cannot tell". A single resolved
// address bit that contradicts row i settles the whole decoder output to 0 even if another
// bit is floating - that is what an AND gate with a 0 input does, and a model that answered
// X here would disagree with the structural sheet on the write side.
function matchCell(A, i, aw) {
  let unknown = false;
  for (let k = 0; k < aw; k++) {
    const a = A[aw - 1 - k];                                  // bit k of the address, LSB index k
    const want = String((i >> k) & 1);
    if (a === '0' || a === '1') { if (a !== want) return '0'; continue; }
    unknown = true;                                            // X or Z on this address line
  }
  return unknown ? 'X' : '1';
}

// Nine-valued AND, written as a truth table (the structural twin derives the same answer
// from a chain of gate primitives instead).
function andEna(a, b) {
  if (a === '0' || b === '0') return '0';
  if (a === '1' && b === '1') return '1';
  return 'X';
}

export function ram4Model(n) {
  const words = n == null ? 4 : n;
  if (!Number.isInteger(words) || words < 2) fail('ram4Model: n must be an integer >= 2, got ' + JSON.stringify(n));
  const aw = Math.ceil(Math.log2(words));
  if (Math.pow(2, aw) !== words) fail('ram4Model: n must be a power of two (a binary address), got ' + words);
  const M = {
    name: 'ram4',
    words,
    addrWidth: aw,
    dataWidth: 1,
    initial: (opts) => {
      const o = opts || {};
      const v = o.cell == null ? '0' : level(o.cell, 'ram4 initial cell');
      return { cells: new Array(words).fill(v), clk: o.clk == null ? '0' : level(o.clk, 'ram4 initial clk') };
    },
    readCell: (st, i) => st.cells[i],
    step: (st, ins) => {
      const CLK = level(ins.CLK, 'ram4 CLK');
      const WE = ins.WE == null ? '1' : level(ins.WE, 'ram4 WE');
      const A = word(ins.A, aw, 'ram4 A');
      const D = level(ins.D, 'ram4 D');
      const cells = st.cells.map((q, i) => dffeStep({ q, clk: st.clk }, {
        D, CLK,
        ENA: andEna(WE, matchCell(A, i, aw)),      // decoder output of cell i: WE AND sel_i
        PRN: '1', CLRN: '1',                       // enadff.bdf ties both to VCC
      }).q);
      return { cells, clk: CLK };
    },
    outputs: (st, ins) => {
      const WE = ins.WE == null ? '0' : level(ins.WE, 'ram4 WE');
      const A = word(ins.A, aw, 'ram4 A');
      const idx = wordValue(A);
      let Q = 'Z';
      if (WE === '0' && idx !== null && idx < words) Q = st.cells[idx];
      return { Q };
    },
    selfTest: () => ram4SelfTest(M),
  };
  return M;
}

// nine-valued gate helpers, used only by the self-tests: they let a self-test rebuild the
// EXPECTATION structurally (decoder + DFFE + tri-state) instead of restating the model, so a
// mistake in the model has somewhere to show up.
function gNot(a) { return a === '0' ? '1' : a === '1' ? '0' : a === 'Z' ? 'Z' : 'X'; }
function gAnd2(a, b) {
  if (a === '0' || b === '0') return '0';
  if (a === '1' && b === '1') return '1';
  if (a === 'Z' || b === 'Z') return 'X';
  return 'X';
}
function gOr2(a, b) {
  if (a === '1' || b === '1') return '1';
  if (a === '0' && b === '0') return '0';
  return 'X';
}
// one wire with several tri-state drivers: Z is released, a lone 0 or 1 drives, a 0/1 clash
// or any unresolved driver makes the wire X (this is what Quartus functional sim reports).
function wireResolve(drivers) {
  let v = 'Z';
  for (const d of drivers) {
    if (d === 'Z') continue;
    if (d === 'X') return 'X';
    if (v === 'Z') { v = d; continue; }
    if (v !== d) return 'X';
  }
  return v;
}

// Structural twin of ram4Model: 2-to-4 decoder of AND/NOT gates, one DFFE per cell, one
// tri-state per cell onto a shared wire. Written independently of the model above on purpose.
function ram4Structural(st, ins, M) {
  const words = M.words, aw = M.addrWidth;
  const A = word(ins.A, aw, 'A');
  const WE = level(ins.WE, 'WE');
  const D = level(ins.D, 'D');
  const CLK = level(ins.CLK, 'CLK');
  const abits = A.split('').reverse();                      // abits[k] is bit k, LSB first
  const sel = [];
  for (let i = 0; i < words; i++) {
    let s = '1';
    for (let k = 0; k < aw; k++) {                                        // decoder: a 1 takes the
      const want = String((i >> k) & 1);                                // true literal, a 0 takes
      s = gAnd2(s, want === '1' ? abits[k] : gNot(abits[k]));            // the inverted one
    }
    sel.push(s);
  }
  const cells = st.cells.map((q, i) => dffeStep({ q, clk: st.clk }, { D, CLK, ENA: gAnd2(WE, sel[i]) }).q);
  const drivers = [];
  for (let i = 0; i < words; i++) {
    const en = gAnd2(gNot(WE), sel[i]);
    drivers.push(en === '1' ? st.cells[i] : en === '0' ? 'Z' : 'X');
  }
  return { next: { cells, clk: CLK }, Q: wireResolve(drivers) };
}

function ram4SelfTest(M) {
  const words = M.words, aw = M.addrWidth;
  const vals = ['0', '1', 'X'];
  let n = 0;
  // exhaustive write-side sweep, compared against the structural twin
  const cellStates = [];
  const rec = (k, cur) => {
    if (k === words) { cellStates.push(cur.slice()); return; }
    for (const v of vals) { cur.push(v); rec(k + 1, cur); cur.pop(); }
  };
  rec(0, []);
  const addrs = [];
  const recA = (k, cur) => {
    if (k === aw) { addrs.push(cur.join('')); return; }
    for (const v of vals) { cur.push(v); recA(k + 1, cur); cur.pop(); }
  };
  recA(0, []);
  for (const cells of cellStates) {
    for (const clk of vals) {
      for (const WE of vals) {
        for (const A of addrs) {
          for (const D of vals) {
            const st = { cells, clk };
            const got = M.step(st, { CLK: clk === '0' ? '1' : clk, WE, A, D });
            const str = ram4Structural(st, { CLK: clk === '0' ? '1' : clk, WE, A, D }, M);
            n++;
            if (got.cells.join() !== str.next.cells.join()) {
              fail('ram4 write side disagrees with its structural twin: cells ' + cells.join('') +
                ' clk ' + clk + ' WE ' + WE + ' A ' + A + ' D ' + D + ' -> model ' + got.cells.join('') +
                ' vs structural ' + str.next.cells.join(''));
            }
            if (got.clk !== str.next.clk) fail('ram4: clock state diverged from the twin');
            if (JSON.stringify(st) !== JSON.stringify({ cells, clk })) fail('ram4: step mutated its argument');
          }
        }
      }
    }
  }
  // read side, same sweep: the model must agree with the twin whenever WE resolves, and must
  // give the documented behavioural answer when it does not.
  for (const cells of cellStates) {
    for (const WE of vals) {
      for (const A of addrs) {
        const st = { cells, clk: '0' };
        const Q = M.outputs(st, { WE, A }).Q;
        n++;
        const idx = wordValue(A);
        const want = (WE === '0' && idx !== null) ? cells[idx] : 'Z';   // the behavioural contract
        if (Q !== want) fail('ram4: Q should be ' + want + ', got ' + Q);
        if ((WE === '0' || WE === '1') && idx !== null) {
          // resolved address: the gate-level twin must say the same thing
          const str = ram4Structural(st, { CLK: '0', WE, A, D: '0' }, M);
          if (Q !== str.Q) {
            fail('ram4 read side disagrees with the twin: cells ' + cells.join('') + ' WE ' + WE +
              ' A ' + A + ' -> model ' + Q + ' vs structural ' + str.Q);
          }
        } else {
          // unresolved address: the two descriptions of the SAME circuit legitimately differ.
          // ram4beh.vhd reaches its "when others => q <= Z" branch, so the behavioural answer is
          // Z; a real tri-state buffer whose enable is X outputs X, not released. The model
          // follows the behavioural twin, because that is what the chapter asks to confront, and
          // the divergence is recorded instead of hidden - see selfTestNotes().
          const str = ram4Structural(st, { CLK: '0', WE, A, D: '0' }, M);
          if (str.Q !== Q) {
            note('ram4 read, WE=' + WE + ' A=' + A + ': behavioural Q=' + Q +
              ' but gate-level Q=' + str.Q);
          }
        }
      }
    }
  }
  // the contract the lab measures: write 1,0,1,0 into the four cells, then read each back
  let s = M.initial();
  for (let i = 0; i < 4; i++) {
    const d = i % 2 === 0 ? '1' : '0';
    s = M.step(s, { CLK: '0', WE: '1', A: i, D: d });
    s = M.step(s, { CLK: '1', WE: '1', A: i, D: d });
    if (M.outputs(s, { WE: '1', A: i }).Q !== 'Z') fail('ram4: Q must float while WE is high');
    n += 2;
  }
  for (let i = 0; i < 4; i++) {
    const want = i % 2 === 0 ? '1' : '0';
    const got = M.outputs(s, { WE: '0', A: i }).Q;
    if (got !== want) fail('ram4: cell ' + i + ' read back ' + got + ', expected ' + want);
    if (M.readCell(s, i) !== want) fail('ram4: readCell disagrees with outputs');
    n++;
  }
  return n;
}

// ---- mem4x8: 4 words of 8 bits, one octal output buffer -----------------
// The same figure-18.7 idea scaled up: a 2-bit address selects one of four 8-bit words, each
// bit stored in its own DFFE, all sharing one clock; the write enable is qualified by the
// decoder, and the four words reach the outside world through ONE tri-state (octal) buffer
// with an ACTIVE-LOW strobe - the 74244/74374 convention the lead measured in probe_reg, where
// OEN = 1 holds Q[7..0] at Z and OEN = 0 drives them.
//
//   state   = { words: [8-char level string x 4], clk: level }
//   step(st, { CLK, WE, A, D })        D: integer or MSB-first 8-char level string
//   outputs(st, { OEN, A })            -> { Q: 8-char level string }  ('ZZZZZZZZ' when idle)
//   readWord(st, i) / addrWidth / dataWidth / words
export function mem4x8Model(opts) {
  const o = opts || {};
  const words = o.words == null ? 4 : o.words;
  const dw = o.dataWidth == null ? 8 : o.dataWidth;
  const aw = o.addrWidth == null ? Math.ceil(Math.log2(words)) : o.addrWidth;
  if (Math.pow(2, aw) !== words) fail('mem4x8Model: ' + words + ' words need an integral binary address width, got ' + aw);
  const blank = (v) => new Array(dw).fill(v).join('');
  const M = {
    name: 'mem4x8',
    words, addrWidth: aw, dataWidth: dw,
    initial: (init) => {
      const ii = init || {};
      const v = ii.word == null ? 'X' : level(ii.word, 'mem4x8 initial word');
      return { words: new Array(words).fill(blank(v === '0' || v === '1' ? v : 'X')), clk: ii.clk == null ? '0' : level(ii.clk, 'mem4x8 initial clk') };
    },
    readWord: (st, i) => st.words[i],
    step: (st, ins) => {
      const CLK = level(ins.CLK, 'mem4x8 CLK');
      const WE = ins.WE == null ? '1' : level(ins.WE, 'mem4x8 WE');
      const A = word(ins.A, aw, 'mem4x8 A');
      const D = word(ins.D, dw, 'mem4x8 D');
      const next = st.words.map((w, i) => {
        const ena = andEna(WE, matchCell(A, i, aw));
        if (ena === '0') return w;
        let out = '';
        for (let k = 0; k < dw; k++) {
          out += dffeStep({ q: w[k], clk: st.clk }, { D: D[k], CLK, ENA: ena, PRN: '1', CLRN: '1' }).q;
        }
        return out;
      });
      return { words: next, clk: CLK };
    },
    outputs: (st, ins) => {
      const OEN = ins.OEN == null ? '0' : level(ins.OEN, 'mem4x8 OEN');
      const A = word(ins.A, aw, 'mem4x8 A');
      const idx = wordValue(A);
      const driving = OEN === '0' && idx !== null && idx < words;
      return { Q: driving ? st.words[idx] : blank('Z') };
    },
    selfTest: () => mem4x8SelfTest(M),
  };
  return M;
}

// Structural twin of mem4x8, built the way the sheet is built: a 2-to-4 decoder of AND/NOT
// gates, one DFFE per stored bit, and one octal tri-state buffer onto the shared Q wires.
// Derived from gates on purpose, so it can catch a mistake in the model above.
function mem4x8Structural(st, ins, M) {
  const { words, addrWidth: aw, dataWidth: dw } = M;
  const A = word(ins.A, aw, 'A');
  const WE = level(ins.WE, 'WE');
  const D = word(ins.D, dw, 'D');
  const CLK = level(ins.CLK, 'CLK');
  const OEN = level(ins.OEN, 'OEN');
  const abits = A.split('').reverse();
  const sel = [];
  for (let i = 0; i < words; i++) {
    let s = '1';
    for (let k = 0; k < aw; k++) {
      const want = String((i >> k) & 1);
      s = gAnd2(s, want === '1' ? abits[k] : gNot(abits[k]));
    }
    sel.push(s);
  }
  const nextWords = st.words.map((w, i) => {
    const ena = gAnd2(WE, sel[i]);
    let out = '';
    for (let k = 0; k < dw; k++) out += dffeStep({ q: w[k], clk: st.clk }, { D: D[k], CLK, ENA: ena }).q;
    return out;
  });
  const en = gNot(OEN);
  const drivers = [];
  for (let k = dw - 1; k >= 0; k--) {
    let v = 'Z';
    for (let i = 0; i < words; i++) {
      const bitEn = gAnd2(en, sel[i]);
      const d = bitEn === '1' ? st.words[i][k] : bitEn === '0' ? 'Z' : 'X';
      v = wireResolve([v, d]);
    }
    drivers.push(v);
  }
  return { next: { words: nextWords, clk: CLK }, Q: drivers.join('') };
}

function mem4x8SelfTest(M) {
  const { words, addrWidth: aw, dataWidth: dw } = M;
  const vals = ['0', '1', 'X'];
  let n = 0;
  const addrs = [];
  const recA = (k, cur) => {
    if (k === aw) { addrs.push(cur.join('')); return; }
    for (const v of vals) { cur.push(v); recA(k + 1, cur); cur.pop(); }
  };
  recA(0, []);
  const blanks = (v) => new Array(dw).fill(v).join('');
  const profiles = [
    new Array(words).fill(blanks('0')),
    new Array(words).fill(blanks('X')),
    new Array(words).fill(blanks('1')),
    Array.from({ length: words }, (_, i) => blanks(i % 2 ? '1' : '0')),
    Array.from({ length: words }, (_, i) => new Array(dw).fill(String((i + dw) % 2)).join('')),
  ];
  const dpats = [blanks('0'), blanks('1'), '10101010'.slice(0, dw), '11110000'.slice(0, dw)];
  // exhaustive write sweep, model against its structural twin
  for (const ws of profiles) for (const clk of vals) for (const WE of vals)
    for (const A of addrs) for (const D of dpats) {
      const st = { words: ws, clk };
      const CLK = clk === '0' ? '1' : clk;
      const got = M.step(st, { CLK, WE, A, D });
      const str = mem4x8Structural(st, { CLK, WE, A, D, OEN: '0' }, M);
      n++;
      if (got.words.join() !== str.next.words.join()) {
        fail('mem4x8 write side disagrees with the twin: words ' + ws.join('|') + ' clk ' + clk +
          ' WE ' + WE + ' A ' + A + ' D ' + D + ' -> model ' + got.words.join('|') +
          ' vs structural ' + str.next.words.join('|'));
      }
      if (JSON.stringify(st) !== JSON.stringify({ words: ws, clk })) fail('mem4x8: step mutated its argument');
    }
  // exhaustive read sweep
  for (const ws of profiles) for (const OEN of vals) for (const A of addrs) {
    const st = { words: ws, clk: '0' };
    const Q = M.outputs(st, { OEN, A }).Q;
    n++;
    const idx = wordValue(A);
    const driving = OEN === '0' && idx !== null && idx < words;
    const want = driving ? ws[idx] : blanks('Z');
    if (Q !== want) fail('mem4x8: Q should be ' + want + ', got ' + Q);
    const str = mem4x8Structural(st, { CLK: '0', WE: '0', A, D: blanks('0'), OEN }, M);
    if (driving) {
      if (Q !== str.Q) fail('mem4x8 read disagrees with twin: OEN ' + OEN + ' A ' + A + ' -> ' + Q + ' vs ' + str.Q);
    } else if (str.Q !== Q) {
      note('mem4x8 read, OEN=' + OEN + ' A=' + A + ': behavioural Q=' + Q + ' vs gate-level Q=' + str.Q);
    }
  }
  // the contract a lab report measures, spelled out on the default 4 x 8 geometry
  let st = M.initial();
  const wnt = [];
  for (let i = 0; i < words; i++) {
    const D = new Array(dw).fill(0).map((_, k) => String((i * 3 + k) % 2)).join("");
    wnt.push(D);
    st = M.step(st, { CLK: "0", WE: "1", A: i, D: "00000000".slice(0, dw) });   // pre-load junk, no edge
    st = M.step(st, { CLK: "1", WE: "1", A: i, D });                            // rising edge takes it
    if (M.outputs(st, { OEN: "1", A: i }).Q !== blanks("Z")) fail("mem4x8: Q must float while the strobe is inactive");
    n += 2;
  }
  for (let i = 0; i < words; i++) {
    const got = M.outputs(st, { OEN: "0", A: i }).Q;
    if (got !== wnt[i]) fail("mem4x8: word " + i + " read back " + got + ", expected " + wnt[i]);
    if (M.readWord(st, i) !== wnt[i]) fail("mem4x8: readWord disagrees with outputs");
    n++;
  }
  // a falling edge with WE high must not write, and a rising edge with WE low must not write
  const before = st.words.join("|");
  st = M.step(st, { CLK: "0", WE: "1", A: 0, D: blanks("1") });
  if (st.words.join("|") !== before) fail("mem4x8: a falling edge wrote");
  st = M.step(st, { CLK: "1", WE: "0", A: 0, D: blanks("1") });
  if (st.words.join("|") !== before) fail("mem4x8: WE low let a write through");
  n += 2;
  // an unwritten word reads as X, not as 0
  const fresh = M.initial();
  if (M.outputs(fresh, { OEN: "0", A: 0 }).Q !== blanks("X")) fail("mem4x8: an untouched word must read X");
  n++;
  // deterministic random campaign against the twin (LCG, seed 20261126)
  let seed = 20261126;
  const rnd = (m) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % m; };
  let cs = M.initial();
  for (let k = 0; k < 4000; k++) {
    const CLK = String(rnd(2));
    const WE = rnd(9) === 0 ? "X" : String(rnd(2));
    const A = rnd(9) === 0 ? new Array(aw).fill('X').join('') : rnd(words);   // integer or level string
    const D = new Array(dw).fill(0).map(() => String(rnd(2))).join("");
    const OEN = rnd(9) === 0 ? "X" : String(rnd(2));
    const str = mem4x8Structural(cs, { CLK, WE, A, D, OEN }, M);
    cs = M.step(cs, { CLK, WE, A, D });
    n++;
    if (cs.words.join() !== str.next.words.join()) fail("mem4x8 campaign step " + k + " diverged from the twin");
    if (WE !== 'X' && OEN !== 'X' && wordValue(word(A, aw, 'A')) !== null) {
      const Q = M.outputs(cs, { OEN, A }).Q;
      const str2 = mem4x8Structural(cs, { CLK, WE, A, D, OEN }, M);
      if (Q !== str2.Q) fail("mem4x8 campaign read step " + k + " diverged from the twin");
      n++;
    }
  }
  return n;
}

// ---- lpm_ram_dq: an ideal RAM block whose write rule is MEASURED ---------
// The lead's two probes (lab13/probe/lpramax, lab13/probe/lpramwb) leave inclock and outclock
// UNCONNECTED on purpose: the task fixes LPM_ADDRESS_CONTROL / LPM_INDATA / LPM_OUTDATA all to
// "unregistered", and lpm_ram_dq.tdf defaults those ports to VCC, so the elaborated design
// contains no clock edge at all. lab13/evidence/lpramax_crosscheck.json records the mapped
// geometry: LPM_WIDTH=8, LPM_WIDTHAD=10, LPM_NUMWORDS=1024, LPM_FILE=UNUSED, three UNREGISTERED,
// RAM Summary "Single Port / 1024 / 8 / size 8192 / MIF none".
//
// An edge-triggered write therefore predicts "no writes, X everywhere" and is WRONG: the guest
// retained FF/F0/A5/5A at 0x000/0x155/0x2AA/0x3FF. The rule below was chosen by running four
// candidate write mechanisms against all 28 measured phases of the two traces; only one
// reproduces both (see lpmRamDqSelfTest, which re-states the measurement as data):
//
//   rule        lpramax disagreements  lpramwb disagreements   (of 17 and 11 phases)
//   we-fall/post            0                      0            <== the only rule fitting both
//   we-fall/pre             0                      5
//   we-rise/post            0                      3
//   we-rise/pre             0                      2
//   we-level/post           0                      5
//   none (never stores)     8                      3
//   clk-rise, inclock=VCC  12                      8
//
// The last two rows are not really candidates for this parameter set - they are listed because
// they are what a reader would reach for first, and clk-rise in particular is what this model
// implemented before the measurement existed.
//
// lpramax alone cannot discriminate: five of those six rules fit all 17 of its phases, because
// there every write is setup(WE=0) / pulse(WE=1) / release(WE=0) with ADDRESS and DATA held
// constant across all three, so pre- and post-instant operands coincide. lpramwb is what
// settles it, and it does so on two independent counts:
//
//   * phase 3 reads 0x00 at 0x010, not the 0x11 that phase 1 presented. So a WE=1 pulse does
//     NOT store continuously - a transparent latch would have kept 0x11 - the store needs a WE
//     transition, exactly as a registered RAM needs a clock transition.
//   * the WE fall at 2->3 lands at the same simulation instant as A moving 0x020->0x010 and D
//     moving 0x22->0x00. 0x010 received 0x00 and 0x020 received NOTHING (phase 4 reads X). So
//     the fall sampled the NEW address and the NEW data: in a zero-delay functional simulation
//     simultaneous transitions are seen post-transition by the write port.
//
// THE PEDAGOGICAL COROLLARY, which is the real lesson of these two probes: a correct memory
// waveform must keep ADDRESS and DATA stable for one phase AFTER WE drops. Move the data bus
// away under a releasing WE and the cell stores the next phase's data instead of the intended
// word - lpramwb loses 0x11, 0x22, 0x44 and 0x55 that way and stores 0x00 four times over.
//
// WHAT REMAINS OPEN: the waves fix the observable rule, not the mechanism. "A fall-triggered
// write port" and "a WE-transparent latch that freezes on the fall, having already seen the new
// D" are indistinguishable here because every change is simultaneous. The lead is pulling
// altram.tdf from the guest install into ../ref_altera/mega/ to quote the source; if
// it shows a level-sensitive storage element, the we-level mode below is the one to use and this
// comment must be rewritten. Until then write: "we-fall" is the default, because it is the mode
// that reproduces the measurement.
//
//   state = { mem: [level string x depth], written: [boolean x depth], ctrl: level }
//     ctrl is the previous value of the controlling signal: WE in we-fall / we-level / none,
//     CLK in clk-rise. Keeping one field lets every mode share the state shape.
//   step(st, { WE, A, D })        -> state      A, D: integer or MSB-first level string
//   outputs(st, { WE, A, D })     -> { DATAQ: level string }
//   lpmRamDqModel(width, widthad, opts)
//     opts.write  'we-fall' (default, measured) | 'we-level' | 'clk-rise' | 'none'
//     opts.sample 'post' (default, measured) | 'pre'   which instant a transition stores
//     opts.clk    true to carry a CLK operand for the clk-rise mode
export function lpmRamDqModel(width, widthad, opts) {
  const dw = width == null ? 8 : width;
  const aw = widthad == null ? 10 : widthad;
  if (!Number.isInteger(dw) || dw < 1) fail('lpmRamDqModel: width must be an integer >= 1, got ' + width);
  if (!Number.isInteger(aw) || aw < 1) fail('lpmRamDqModel: widthad must be an integer >= 1, got ' + widthad);
  const o = opts || {};
  const mode = o.write == null ? 'we-fall' : o.write;
  if (['we-fall', 'we-rise', 'we-level', 'clk-rise', 'none'].indexOf(mode) < 0) fail('lpmRamDqModel: unknown write mode ' + mode);
  const sample = o.sample == null ? 'post' : o.sample;
  if (sample !== 'post' && sample !== 'pre') fail('lpmRamDqModel: sample must be "post" or "pre", got ' + sample);
  const depth = Math.pow(2, aw);
  const allX = new Array(dw).fill('X').join('');
  // ctrl is the previous value of the controlling signal

  // Does this step store? Returns the operand set to store, or null.
  const storeOperand = (st, ins) => {
    const prev = st.ctrl;
    const now = mode === 'clk-rise' ? level(ins.CLK, 'lpm_ram_dq CLK') : level(ins.WE, 'lpm_ram_dq WE');
    let edge = false;
    if (mode === 'we-fall') edge = prev === '1' && now === '0';
    else if (mode === 'we-rise') edge = prev === '0' && now === '1';
    else if (mode === 'clk-rise') {
      // A registered write still needs WE: the clock only says WHEN, WE says WHETHER.
      // WE is read as its own operand here, not as this mode's controlling signal.
      const WE = ins.WE == null ? '1' : level(ins.WE, 'lpm_ram_dq WE');
      if (WE !== '1') return null;
      edge = prev === '0' && now === '1';
    }
    else if (mode === 'we-level') edge = now === '1';               // level, not an edge
    if (!edge) return null;
    // "pre" reads the operands as they were in the previous step, "post" as they are now.
    const src = sample === 'pre' && st.last ? st.last : ins;
    const A = word(src.A, aw, 'lpm_ram_dq A');
    const D = word(src.D, dw, 'lpm_ram_dq D');
    const idx = wordValue(A);
    if (idx === null) return null;                                  // unresolved address: no store
    if (mode === 'we-level' && wordValue(D) === null) return null;  // a latch cannot store X cleanly
    return { idx, D };
  };

  const M = {
    name: 'lpm_ram_dq',
    write: mode, sample, clk: mode === 'clk-rise',
    words: depth, addrWidth: aw, dataWidth: dw,
    initial: (init) => {
      const ii = init || {};
      const v = ii.word == null ? 'X' : level(ii.word, 'lpm_ram_dq initial word');
      return {
        mem: new Array(depth).fill(allX),
        written: new Array(depth).fill(false),
        ctrl: ii.ctrl == null ? '0' : level(ii.ctrl, 'lpm_ram_dq initial ctrl'),
        last: null,
      };
    },
    readWord: (st, i) => st.mem[i],
    isWritten: (st, i) => st.written[i],
    step: (st, ins) => {
      const stored = storeOperand(st, ins);
      let mem = st.mem, written = st.written;
      if (stored) {
        mem = st.mem.slice(); written = st.written.slice();
        mem[stored.idx] = stored.D; written[stored.idx] = true;
      }
      const ctrl = mode === 'clk-rise' ? level(ins.CLK, 'lpm_ram_dq CLK') : level(ins.WE, 'lpm_ram_dq WE');
      return { mem, written, ctrl, last: { WE: ins.WE, A: ins.A, D: ins.D, CLK: ins.CLK } };
    },
    outputs: (st, ins) => {
      const WE = mode === 'clk-rise' ? '0' : level(ins.WE, 'lpm_ram_dq WE');
      const A = word(ins.A, aw, 'lpm_ram_dq A');
      const idx = wordValue(A);
      if (mode === 'clk-rise') return { DATAQ: idx === null ? allX : st.mem[idx] };
      // measured: while WE = 1 the data bus reaches Q regardless of the address (lpramwb phase 8
      // shows 0x55 on Q while addressing 0x010, whose stored word was 0x00).
      if (WE === '1') return { DATAQ: word(ins.D, dw, 'lpm_ram_dq D') };
      // WE = 0, or WE unresolved: read the array. An unresolved address or WE has never been
      // measured by either probe; all-X is the honest answer, and it is flagged as unmeasured.
      if (WE !== '0') return { DATAQ: allX };
      return { DATAQ: idx === null ? allX : st.mem[idx] };
    },
    selfTest: () => lpmRamDqSelfTest(M),
  };
  return M;
}

// The two measured traces, transcribed from the guest's own .sim.vwf by seqtest.mjs and pinned
// here as data so the self-test stays host-only. Rows are [WE, A, D, Q] with A, D, Q as numbers,
// except Q = 'X' for a word the functional model leaves unknown. Source:
//   ../4_lpm_ram_dq/lpramax.sim.vwf  (17 phases, SIMULATION_TIME 1700.0)
//   ../4_lpm_ram_dq/lpramwb.sim.vwf  (11 phases, SIMULATION_TIME 1100.0)
export const LPRAMAX_MEASURED = [
  [0, 0x000, 0xFF, 'X'], [1, 0x000, 0xFF, 0xFF], [0, 0x000, 0xFF, 0xFF],
  [0, 0x155, 0xF0, 'X'], [1, 0x155, 0xF0, 0xF0], [0, 0x155, 0xF0, 0xF0],
  [0, 0x2AA, 0xA5, 'X'], [1, 0x2AA, 0xA5, 0xA5], [0, 0x2AA, 0xA5, 0xA5],
  [0, 0x3FF, 0x5A, 'X'], [1, 0x3FF, 0x5A, 0x5A], [0, 0x3FF, 0x5A, 0x5A],
  [0, 0x000, 0x00, 0xFF], [0, 0x155, 0x00, 0xF0], [0, 0x2AA, 0x00, 0xA5], [0, 0x3FF, 0x00, 0x5A],
  [0, 0x1AA, 0x00, 'X'],
];
export const LPRAMWB_MEASURED = [
  [0, 0x010, 0x00, 'X'], [1, 0x010, 0x11, 0x11], [1, 0x020, 0x22, 0x22],
  [0, 0x010, 0x00, 0x00], [0, 0x020, 0x00, 'X'],
  [1, 0x030, 0x33, 0x33], [1, 0x030, 0x44, 0x44],
  [0, 0x030, 0x00, 0x00],
  [1, 0x010, 0x55, 0x55],
  [0, 0x010, 0x00, 0x00], [0, 0x020, 0x00, 'X'],
];

// Replay one measured trace through a model. Returns the list of disagreements.
export function replayMeasured(M, rows, fixed) {
  const { dataWidth: dw } = M;
  const toWord = (v) => {
    if (v === 'X') return new Array(dw).fill('X').join('');
    let s = '';
    for (let k = dw - 1; k >= 0; k--) s += String((v >> k) & 1);
    return s;
  };
  const fx = fixed || {};
  let st = M.initial();
  const errs = [];
  rows.forEach(([WE, A, D, Q], i) => {
    const op = Object.assign({}, fx, { WE, A, D });
    st = M.step(st, op);
    const got = M.outputs(st, op).DATAQ;
    const want = toWord(Q);
    if (got !== want) errs.push('phase ' + i + ' WE=' + WE + ' A=0x' + A.toString(16) + ' D=0x' + D.toString(16) +
      ': measured ' + want + ', model ' + got);
  });
  return errs;
}

function lpmRamDqSelfTest(M) {
  const { addrWidth: aw, dataWidth: dw, words: depth } = M;
  const allX = new Array(dw).fill('X').join('');
  let n = 0;

  // 1. the measured geometry, so a silent parameter slip cannot pass unnoticed
  if (dw !== 8 || aw !== 10 || depth !== 1024) {
    fail('lpm_ram_dq: the probes map 8 x 1024; this model is ' + dw + ' x ' + depth);
  }
  n += 3;

  // 2. the default mode must reproduce BOTH traces with zero disagreements
  if (M.write !== 'we-fall' || M.sample !== 'post') fail('lpm_ram_dq: default mode drifted off the measurement');
  const eMax = replayMeasured(M, LPRAMAX_MEASURED);
  const eWb = replayMeasured(M, LPRAMWB_MEASURED);
  n += LPRAMAX_MEASURED.length + LPRAMWB_MEASURED.length;
  if (eMax.length) fail('lpm_ram_dq disagrees with lpramax: ' + eMax.join('; '));
  if (eWb.length) fail('lpm_ram_dq disagrees with lpramwb: ' + eWb.join('; '));

  // 3. every alternative rule must fail by an EXACT measured amount. This is the discrimination
  // table that chose the default mode, restated as assertions so a future edit cannot quietly
  // make two rules indistinguishable. Counts are disagreements per trace, measured this session
  // against the two .sim.vwf files. lpramax cannot separate the five asynchronous rules - all
  // fit its 17 phases, because ADDRESS and DATA are held constant across each setup/pulse/
  // release triple, so the pre- and post-instant operands coincide. lpramwb is the sole
  // discriminator for those; clk-rise and none die on lpramax as well.
  const CANDIDATES = [
    // mode, sample, fixed operands, lpramax disagreements, lpramwb disagreements
    ['we-fall', 'post', {}, 0, 0],
    ['we-fall', 'pre', {}, 0, 5],
    ['we-rise', 'post', {}, 0, 3],
    ['we-rise', 'pre', {}, 0, 2],
    ['we-level', 'post', {}, 0, 5],
    ['clk-rise', 'post', { CLK: '1' }, 12, 8],
    ['none', 'post', {}, 8, 3],
  ];
  let perfect = 0;
  for (const c of CANDIDATES) {
    const mode = c[0], samp = c[1], fx = c[2];
    const A1 = lpmRamDqModel(dw, aw, { write: mode, sample: samp, clk: mode === 'clk-rise' });
    const em = replayMeasured(A1, LPRAMAX_MEASURED, fx).length;
    const ew = replayMeasured(A1, LPRAMWB_MEASURED, fx).length;
    n += LPRAMAX_MEASURED.length + LPRAMWB_MEASURED.length;
    if (em !== c[3]) fail('lpm_ram_dq: ' + mode + '/' + samp + ' disagrees with lpramax ' + em + ' times, expected ' + c[3]);
    if (ew !== c[4]) fail('lpm_ram_dq: ' + mode + '/' + samp + ' disagrees with lpramwb ' + ew + ' times, expected ' + c[4]);
    if (em + ew === 0) perfect++;
  }
  if (perfect !== 1) fail('lpm_ram_dq: ' + perfect + ' candidate rules fit both traces; the measurement must single out exactly one');

  // 4. the two counts lpramwb settles on its own, restated as assertions
  {
    const st = M.initial();
    const seq = LPRAMWB_MEASURED.map(([WE, A, D]) => ({ WE, A, D }));
    let s2 = st;
    const qs = [];
    for (const r of seq) { s2 = M.step(s2, r); qs.push(M.outputs(s2, r).DATAQ); }
    if (qs[3] !== '00000000') fail('lpm_ram_dq: phase 3 must read 0x00, the WE-fall value, not the 0x11 pulsed in phase 1');
    if (qs[4] !== allX) fail('lpm_ram_dq: 0x020 saw no WE fall while addressed and must stay X');
    if (qs[1] !== '00010001' || qs[2] !== '00100010') fail('lpm_ram_dq: Q must follow DATA while WE is high');
    if (qs[8] !== '01010101') fail('lpm_ram_dq: phase 8 must pass 0x55 through while addressing 0x010');
    n += 4;
  }

  // 5. an unwritten word reads X, never 0 - the honest-model requirement. Synthesis warns that
  //    the mapped device would initialise to 0 with LPM_FILE=UNUSED; the FUNCTIONAL model the
  //    .sim.vwf comes from does not, and a model that guessed 0 would hide a real difference.
  {
    const fresh = M.initial();
    for (const a of [0, 1, 0x1AA, 0x3FF]) {
      if (M.outputs(fresh, { WE: '0', A: a, D: 0 }).DATAQ !== allX) fail('lpm_ram_dq: unwritten 0x' + a.toString(16) + ' must read X');
      n++;
    }
    const wz = M.step(M.initial(), { WE: '1', A: 7, D: 0 });
    if (!M.isWritten(M.step(wz, { WE: '0', A: 7, D: 0 }), 7)) fail('lpm_ram_dq: a fall after a zero write must mark the word written');
    n += 2;
  }

  // 6. a word written with X bits reads those X bits and still counts as written
  {
    const s1 = M.step(M.initial(), { WE: '1', A: 3, D: allX });
    const s2 = M.step(s1, { WE: '0', A: 3, D: allX });
    if (!M.isWritten(s2, 3)) fail('lpm_ram_dq: an all-X write must still mark the word written');
    if (M.outputs(s2, { WE: '0', A: 3, D: 0 }).DATAQ !== allX) fail('lpm_ram_dq: an all-X write must read back all-X');
    if (M.isWritten(s2, 4)) fail('lpm_ram_dq: a neighbour must stay unwritten');
    n += 3;
  }

  // 7. campaign against an independent associative spec, written in a different shape
  {
    const spec = new Map();
    let prevWE = '0', prevA = null, prevD = null;
    let st = M.initial();
    let seed = 20261126;
    const rnd = (m) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % m; };
    for (let k = 0; k < 30000; k++) {
      const WE = rnd(9) === 0 ? 'X' : String(rnd(2));
      const ai = rnd(depth);
      const D = new Array(dw).fill(0).map(() => (rnd(8) === 0 ? 'X' : String(rnd(2)))).join('');
      st = M.step(st, { WE, A: ai, D });
      if (prevWE === '1' && WE === '0' && /^[01XZ]+$/.test(D)) spec.set(ai, D);   // fall, post operands
      prevWE = WE; prevA = ai; prevD = D;
      n++;
      const Q = M.outputs(st, { WE, A: ai, D }).DATAQ;
      let wantQ;
      if (WE === '1') wantQ = D;
      else if (WE === '0') wantQ = spec.has(ai) ? spec.get(ai) : allX;
      else wantQ = allX;
      if (Q !== wantQ) fail('lpm_ram_dq: campaign step ' + k + ' WE=' + WE + ' A=' + ai + ' gave ' + Q + ', spec ' + wantQ);
      n++;
      if (rnd(200) === 0) {
        for (let a = 0; a < depth; a++) {
          if (st.mem[a] !== (spec.has(a) ? spec.get(a) : allX)) fail('lpm_ram_dq: campaign array diverged at step ' + k + ' word ' + a);
        }
        n += depth;
      }
    }
    if (prevA === null) fail('lpm_ram_dq: campaign produced no phases');
    n++;
  }

  // 8. purity: step must not mutate its argument
  {
    const base = M.initial();
    const snap = JSON.stringify(base);
    const s1 = M.step(base, { WE: '1', A: 0, D: 0xAA });
    M.step(s1, { WE: '0', A: 0, D: 0xAA });
    if (JSON.stringify(base) !== snap) fail('lpm_ram_dq: step mutated its argument');
    if (M.outputs(s1, { WE: '0', A: 0, D: 0 }).DATAQ !== allX) fail('lpm_ram_dq: outputs must not store either');
    n += 2;
  }

  // 9. the registered configuration keeps the edge rule, and needs a clock to write at all
  {
    const R = lpmRamDqModel(8, 4, { write: 'clk-rise', clk: true });
    let s = R.initial();
    s = R.step(s, { CLK: '0', WE: '1', A: 2, D: 0x5A });
    if (R.isWritten(s, 2)) fail('lpm_ram_dq(clk-rise): a level must not write');
    s = R.step(s, { CLK: '1', WE: '1', A: 2, D: 0x5A });
    if (!R.isWritten(s, 2)) fail('lpm_ram_dq(clk-rise): a rising edge with WE=1 must write');
    if (R.outputs(s, { A: 2 }).DATAQ !== '01011010') fail('lpm_ram_dq(clk-rise): read-back mismatch');
    s = R.step(s, { CLK: '0', WE: '1', A: 2, D: 0x00 });
    s = R.step(s, { CLK: '1', WE: '0', A: 2, D: 0x00 });
    if (R.outputs(s, { A: 2 }).DATAQ !== '01011010') fail('lpm_ram_dq(clk-rise): WE=0 must block a write');
    n += 5;
  }
  return n;
}

// ---- one place to run every model --------------------------------------
// Returns { dffe, ram4, mem4x8, lpm_ram_dq } in states checked and throws on the first
// internal contradiction.
export function runAllSelfTests() {
  return {
    dffe: dffeModel().selfTest(),
    ram4: ram4Model().selfTest(),
    mem4x8: mem4x8Model().selfTest(),
    lpm_ram_dq: lpmRamDqModel().selfTest(),
  };
}
