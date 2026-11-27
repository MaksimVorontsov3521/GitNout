// lab13/seqvwf.mjs - ordered-timeline authoring + Quartus II 5.0 .vwf emitter for
// SEQUENTIAL designs (lab 13 / chapter 18: memory circuits).
//
// WHY THIS EXISTS
//   tools/bdf/vwf.mjs emits a flat vector table: row i of spec.vectors occupies
//   [i*period, (i+1)*period) and every input may only change on those boundaries. A memory
//   circuit needs an ordered script instead - put address+data on the wires, clock an edge,
//   then read a different address - with a free-running clock underneath. That is what
//   buildTimeline() + emitSeqVwf() produce. The only import from tools/ is busMembers(), the
//   single source of truth for the MSB-first member order of a bus, so nothing here depends
//   on the combinational spec format.
//
// FORMAT FACTS - each one checked in this session against a real Quartus II 5.0 file
// (re-runnable assertions in lab13/seqtest.mjs, section "format probes"):
//   * A bus bit channel is spelled NAME[i] in both SIGNAL("...") and TRANSITION_LIST("..."),
//     with PARENT = "NAME". The parent NAME is SIGNAL_TYPE = BUS, WIDTH = n, LSB_INDEX = 0
//     and gets NO transition list of its own. Verified in the guest-returned
//     lab11/evidence/sdacha_control/3_decoder/decoder.sim.vwf: SIGNAL("IN") BUS WIDTH = 8
//     LSB_INDEX = 0, then SIGNAL("IN[7]") .. SIGNAL("IN[0]") SINGLE_BIT LSB_INDEX = -1
//     PARENT = "IN"; that file has 14 TRANSITION_LISTs (8 IN bits, 4 OUT_DATA bits, 2 plain
//     channels) and none of them is named "IN" or "OUT_DATA".
//   * Bits are listed MSB first (IN[7] before IN[0]) - same file, declaration order.
//   * An observed (output) channel still gets a TRANSITION_LIST, and in a *stimulus* file it
//     holds LEVEL X for the whole run. Verified in
//     ../ref_vwf/D/D.vwf lines 95-111 (TRANSITION_LIST("Q") = LEVEL X FOR 200.0).
//   * A returned .sim.vwf collapses runs of equal level (decoder.sim.vwf IN[6] shows
//     "LEVEL 1 FOR 80.0" where two 40.0 intervals merged), so run-collapsing is authentic.
//   * Durations always carry a decimal point ("FOR 205.0;"), and a returned file can hold a
//     non-grid duration - ref/vwf/D/db/D.sim.vwf has "LEVEL 1 FOR 58.309;" - so a checker must
//     sample at arbitrary t, never only at grid multiples.
//   * A bare NAMEi bit channel is silently ignored by the tool, which leaves the wire at X
//     (documented at tools/bdf/vwf.mjs lines 40-43); that is why bus refs here always expand
//     to NAME[i].
//
// NOT VERIFIED HERE (flagged, not hidden): no file in ../ref_vwf uses
// LEVEL Z as *input* stimulus - a recursive search for "LEVEL Z FOR" over that corpus returns
// zero matches - so Z stimulus is emitted in the same syntactic form as 0/1 but has not been
// observed accepted by the tool. Z as a *response* level is what the memory circuits actually
// need, and seqtest.mjs proves the parse side preserves it.
//
// VOCABULARY (deliberately small)
//   level      '0' | '1' | 'X' | 'Z'   (the numbers 0 and 1 are accepted too). Nothing else.
//   chanRef    a bit: 'A0', 'W[3]', or the name of a 1-bit channel ('WE')
//              a bus: 'W'  (whole word)
//   channel    { name, dir: 'in'|'out', bus?: { width }, radix? }
//   op         { at?: number, dur: number, set?: { [chanRef]: value }, repeat?: number }
//   value      a bit chanRef -> a level.
//              a bus chanRef -> an integer, or a level string of exactly width chars
//              MSB-first ('00Z1'), or a level array of length width, or the single char
//              'X'/'Z' meaning "fill every bit with that level".
//   clock      { name, period, duty?, phase? } or an array of them. High on
//              [k*period+phase, k*period+phase+duty*period/100), so with phase 0 the RISING
//              edges land exactly on multiples of period and the wave starts HIGH.
//
// SAMPLING CONVENTION (shared with tools/bdf/simcheck.mjs sampleAt): segments are half-open
// [t0, t1); at a boundary you get the value that STARTS there. Quartus II 5.0 functional
// simulation is zero-delay, so state lands exactly on clock edges and mid-interval sampling
// is deterministic - sample inside an interval, not on its left edge, for the settled value.


import { busMembers } from './tools/bdf/vwf.mjs';
import { parseVwf } from './tools/bdf/simcheck.mjs';

const NL = String.fromCharCode(10);
const TAB = String.fromCharCode(9);
const EPS = 1e-9;

export const LEVELS = Object.freeze(['0', '1', 'X', 'Z']);

// 1e-6 rounding keeps 0.1+0.2 style accumulation out of the emitted decimals without
// pretending to more precision than a .vwf carries.
const r6 = (x) => Math.round(x * 1e6) / 1e6;
const bad = (msg) => { throw new Error('seqvwf: ' + msg); };
// Channel names are validated against NAME_RE below, so they contain no regex metacharacters
// and can be spliced straight into a constructed RegExp.

export function fmtTime(x) {
  if (typeof x !== 'number' || !isFinite(x)) bad('time must be a finite number, got ' + x);
  const r = r6(x);
  if (Number.isInteger(r)) return r.toFixed(1);
  const s = String(r);
  if (s.indexOf('e') >= 0 || s.indexOf('E') >= 0) bad('duration ' + x + ' is not expressible in .vwf decimal form');
  return s;
}

export function normLevel(v, what) {
  const tag = what ? what + ': ' : '';
  if (typeof v === 'number') {
    if (v === 0) return '0';
    if (v === 1) return '1';
    return bad(tag + 'a bit level must be 0, 1 or one of "0"/"1"/"X"/"Z", got ' + v);
  }
  if (typeof v === 'string') {
    const s = v.toUpperCase();
    if (LEVELS.indexOf(s) >= 0) return s;
    return bad(tag + 'unknown level ' + JSON.stringify(v));
  }
  return bad(tag + 'unknown level type ' + typeof v);
}

const NAME_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;
const BIT_RE = /^([A-Za-z_][A-Za-z0-9_]*)\[(\d+)\]$/;
const BARE_BIT_RE = /^([A-Za-z_][A-Za-z0-9_]*?)([0-9]+)$/;

function normDir(d, name) {
  const s = String(d == null ? 'in' : d).toLowerCase();
  if (s === 'in' || s === 'input') return 'in';
  if (s === 'out' || s === 'output') return 'out';
  return bad('channel ' + name + ': dir must be "in"/"out" (or "input"/"output"), got ' + JSON.stringify(d));
}

// declaration -> (waveform channels Quartus must see, in order) + (chanRef index)
function declareChannels(channels) {
  if (!Array.isArray(channels) || !channels.length) bad('channels must be a non-empty array');
  const seenName = new Set();
  const decls = [];
  const leaves = [];
  channels.forEach((c, i) => {
    if (!c || typeof c !== 'object') bad('channels[' + i + '] must be an object');
    const name = c.name;
    if (typeof name !== 'string' || !NAME_RE.test(name)) bad('channels[' + i + ']: illegal name ' + JSON.stringify(name));
    if (seenName.has(name)) bad('duplicate channel name ' + name);
    seenName.add(name);
    const dir = normDir(c.dir, name);
    if (c.bus == null) {
      decls.push({ name, dir, kind: 'bit', width: 1, bits: [name], radix: c.radix || 'Binary' });
      leaves.push({ name, dir, parent: null, width: 1, chan: name, bus: false });
      return;
    }
    const bw = (typeof c.bus === 'object' && c.bus.width != null) ? c.bus.width : c.bus;
    if (!Number.isInteger(bw) || bw < 2) {
      bad('channel ' + name + ': bus width must be an integer >= 2 (a 1-bit signal should be a ' +
        'plain channel), got ' + JSON.stringify(c.bus));
    }
    // MSB-first member order comes from tools/bdf/vwf.mjs, not from a local copy.
    const bare = busMembers({ name, hi: bw - 1, lo: 0 });
    const bits = bare.map((m) => {
      const y = BIT_RE.exec(m);                 // already NAME[i]
      if (y) return y[1] + '[' + Number(y[2]) + ']';
      const w = BARE_BIT_RE.exec(m);            // busMembers() spelling NAMEi
      if (w) return w[1] + '[' + Number(w[2]) + ']';
      bad('busMembers gave an unusable member ' + JSON.stringify(m) + ' for bus ' + name);
    });
    decls.push({ name, dir, kind: 'bus', width: bw, bits, radix: c.radix || 'Unsigned' });
    leaves.push({ name, dir, parent: null, width: bw, chan: name, bus: true });
    for (const b of bits) leaves.push({ name: b, dir, parent: name, width: 1, chan: name, bus: false });
  });
  return { decls, leaves };
}

// ref -> { kind:'bit'|'bus', chan, bit?, bits:[leaf names MSB-first], width }
function buildIndex(decls) {
  const index = Object.create(null);
  const claim = (ref, entry) => {
    const prev = index[ref];
    if (prev) {
      if (prev.chan === entry.chan && prev.bits.join() === entry.bits.join()) return;
      bad('ambiguous channel reference "' + ref + '": it denotes both ' + prev.chan + ' bits [' +
        prev.bits.join(',') + '] and ' + entry.chan + ' bits [' + entry.bits.join(',') + ']; rename one of them');
    }
    index[ref] = entry;
  };
  for (const d of decls) {
    if (d.kind === 'bit') {
      claim(d.name, { kind: 'bit', chan: d.name, bits: [d.name], width: 1 });
      continue;
    }
    claim(d.name, { kind: 'bus', chan: d.name, bits: d.bits, width: d.width });
    d.bits.forEach((leaf, k) => {
      const ix = d.width - 1 - k;                     // bits are stored MSB first
      const e = { kind: 'bit', chan: d.name, bit: ix, bits: [leaf], width: 1 };
      claim(leaf, e);                                 // NAME[i] - the .vwf spelling
      claim(d.name + ix, e);                          // NAMEi  - the BDF connector spelling
    });
  }
  return index;
}

export function resolveRef(timeline, ref) {
  const e = timeline.index[ref];
  if (!e) {
    const known = Object.keys(timeline.index);
    bad('unknown channel reference "' + ref + '"; declared refs: ' + (known.length ? known.join(', ') : '(none)'));
  }
  return e;
}

// any chanRef -> per-bit levels, MSB first
export function expandValue(entry, value) {
  const label = entry.kind === 'bit'
    ? (entry.bit != null ? entry.chan + '[' + entry.bit + ']' : entry.chan)
    : entry.chan;
  if (entry.kind === 'bit') {
    if (Array.isArray(value) || (typeof value === 'string' && value.length !== 1)) {
      bad('reference "' + label + '" is one bit but got the multi-bit value ' + JSON.stringify(value));
    }
    return [normLevel(value, 'value for ' + label)];
  }
  const w = entry.width;
  if (typeof value === 'number') {
    if (!Number.isInteger(value)) bad('bus ' + label + ': word value must be an integer, got ' + value);
    const top = Math.pow(2, w) - 1;
    if (value < 0 || value > top) {
      bad('bus ' + label + ' is ' + w + ' bits, so ' + value + ' does not fit (valid range 0..' + top + ')');
    }
    const out = [];
    for (let k = w - 1; k >= 0; k--) out.push(String((value >> k) & 1));
    return out;
  }
  if (typeof value === 'string') {
    if (value.length === 1) {
      const lv = normLevel(value, 'bus ' + label);
      if (lv !== 'X' && lv !== 'Z') {
        bad('bus ' + label + ': a single-character word value must be "X" or "Z" (fill every bit), got "' + value + '"');
      }
      return new Array(w).fill(lv);
    }
    if (value.length !== w) bad('bus ' + label + ': level string "' + value + '" has length ' + value.length + ', expected ' + w);
    return value.split('').map((ch) => normLevel(ch, 'bus ' + label));
  }
  if (Array.isArray(value)) {
    if (value.length !== w) bad('bus ' + label + ': level array has length ' + value.length + ', expected ' + w);
    return value.map((ch) => normLevel(ch, 'bus ' + label));
  }
  return bad('bus ' + label + ': unsupported word value ' + JSON.stringify(value));
}

// change points -> half-open runs covering exactly [0, total]
function materialize(initLevel, events, total, who) {
  const byT = new Map();
  for (const e of events) {
    const k = r6(e.t);
    if (k < -EPS) bad(who + ': negative event time ' + e.t);
    if (k > total + EPS) bad(who + ': event at ' + e.t + ' lies past the timeline end ' + total);
    byT.set(k, e.level);                       // two writers at one instant: the later op wins
  }
  let lvl = byT.has(0) ? byT.get(0) : initLevel;
  let t = 0;
  const segs = [];
  const keys = [...byT.keys()].filter((k) => k > 0 && k < total).sort((a, b) => a - b);
  for (const k of keys) {
    const nl = byT.get(k);
    if (nl !== lvl) { segs.push({ t0: r6(t), t1: k, level: lvl }); t = k; lvl = nl; }
  }
  segs.push({ t0: r6(t), t1: r6(total), level: lvl });
  if (segs[0].t0 !== 0 || r6(segs[segs.length - 1].t1) !== r6(total)) {
    bad(who + ': segments do not cover [0, ' + total + ']');
  }
  for (const s of segs) if (!(s.t1 > s.t0)) bad(who + ': non-positive run ' + JSON.stringify(s));
  for (let i = 1; i < segs.length; i++) {
    if (segs[i].t0 !== segs[i - 1].t1) bad(who + ': gap or overlap before ' + JSON.stringify(segs[i]));
    if (segs[i].level === segs[i - 1].level) bad(who + ': uncollapsed equal runs at ' + JSON.stringify(segs[i]));
  }
  return segs;
}

// Square wave across [0, total): HIGH from phase to phase + duty% of period, so the first
// event is the fall and every RISING edge lands on k*period + phase.
function clockEvents(clk, total) {
  const evs = [];
  const hi = (clk.duty / 100) * clk.period;
  let t = r6(clk.phase + hi);
  let lvl = '0';
  let guard = 0;
  while (t < total - EPS) {
    if (t > EPS) evs.push({ t: r6(t), level: lvl });
    t = r6(t + (lvl === '0' ? clk.period - hi : hi));
    lvl = lvl === '0' ? '1' : '0';
    if (++guard > 2e6) bad('clock ' + clk.name + ': over 2e6 edges in ' + total + ' ns - check period');
  }
  return evs;
}

function normaliseClocks(clock, index, leaves) {
  if (clock == null) return [];
  const arr = Array.isArray(clock) ? clock : [clock];
  return arr.map((c, i) => {
    const tag = 'clocks[' + i + ']';
    if (!c || typeof c !== 'object') bad(tag + ' must be an object { name, period, duty?, phase? }');
    const unknown = Object.keys(c).filter((k) => k !== 'name' && k !== 'period' && k !== 'duty' && k !== 'phase');
    if (unknown.length) bad(tag + ': unknown key(s) ' + unknown.join(', '));
    if (typeof c.name !== 'string' || !c.name) bad(tag + ': name is required');
    const e = index[c.name];
    if (!e) bad(tag + ': "' + c.name + '" is not a declared channel; declared refs: ' + Object.keys(index).join(', '));
    if (e.kind !== 'bit') bad(tag + ': "' + c.name + '" is a ' + e.width + '-bit bus; a clock must be one bit');
    const leaf = leaves.find((l) => l.name === e.bits[0]);
    if (leaf.dir !== 'in') bad(tag + ': "' + c.name + '" is declared dir "out"; a clock is driven by the stimulus');
    if (typeof c.period !== 'number' || !isFinite(c.period) || c.period <= EPS) {
      bad(tag + ': period must be a positive finite number, got ' + JSON.stringify(c.period));
    }
    const duty = c.duty == null ? 50 : c.duty;
    if (typeof duty !== 'number' || !isFinite(duty) || duty <= 0 || duty >= 100) {
      bad(tag + ': duty must be strictly between 0 and 100 percent, got ' + JSON.stringify(c.duty));
    }
    const phase = c.phase == null ? 0 : c.phase;
    if (typeof phase !== 'number' || !isFinite(phase) || phase < 0 || phase >= c.period - EPS) {
      bad(tag + ': phase must satisfy 0 <= phase < period, got ' + JSON.stringify(c.phase));
    }
    return { name: e.bits[0], period: r6(c.period), duty, phase: r6(phase) };
  });
}

// ---------------------------------------------------------------------------
// buildTimeline(channels, ops, opts) -> timeline
//   opts.clock  { name, period, duty?, phase? } | [ ... ]   free-running square wave(s)
//   opts.total  number   minimum timeline length (a run never ends before its last op)
//   opts.init   { [chanRef]: level }  starting level (default '0' for inputs, 'X' for outputs)
//   opts.gridPeriod / opts.gridDuty  HEADER grid when there is no clock to take it from
// ops are laid out in order. An op without "at" starts where the previous op ended; an op
// with "at" jumps forward and the skipped interval is a HOLD of whatever was already on the
// wires. Jumping backwards is an error, not a rewind - a sequential script has one direction.
// "repeat" replays the same op that many times, advancing the cursor each time.
// ---------------------------------------------------------------------------
export function buildTimeline(channels, ops, opts) {
  const o = opts || {};
  const { decls, leaves } = declareChannels(channels);
  const index = buildIndex(decls);
  const clockList = normaliseClocks(o.clock, index, leaves);
  const clockLeaves = new Set(clockList.map((c) => c.name));

  if (ops != null && !Array.isArray(ops)) bad('ops must be an array');
  const evs = new Map(leaves.map((l) => [l.name, []]));
  let cursor = 0;
  (ops || []).forEach((op, i) => {
    if (!op || typeof op !== 'object' || Array.isArray(op)) bad('ops[' + i + '] must be an object');
    const unknown = Object.keys(op).filter((k) => k !== 'at' && k !== 'dur' && k !== 'set' && k !== 'repeat');
    if (unknown.length) bad('ops[' + i + ']: unknown key(s) ' + unknown.join(', ') + ' (allowed: at, dur, set, repeat)');
    if (typeof op.dur !== 'number' || !isFinite(op.dur) || op.dur <= EPS) {
      bad('ops[' + i + ']: dur must be a positive finite number, got ' + JSON.stringify(op.dur));
    }
    const repeat = op.repeat == null ? 1 : op.repeat;
    if (!Number.isInteger(repeat) || repeat < 1) {
      bad('ops[' + i + ']: repeat must be an integer >= 1, got ' + JSON.stringify(op.repeat));
    }
    const start = op.at == null ? cursor : op.at;
    if (typeof start !== 'number' || !isFinite(start) || start < -EPS) {
      bad('ops[' + i + ']: at must be a non-negative finite number, got ' + JSON.stringify(op.at));
    }
    if (start < cursor - EPS) {
      bad('ops[' + i + ']: at=' + start + ' is before the end of the previous op (' + r6(cursor) +
        '); a sequential script may not run backwards');
    }
    if (op.set != null && (typeof op.set !== 'object' || Array.isArray(op.set))) {
      bad('ops[' + i + ']: set must be an object of chanRef -> value');
    }
    for (let r = 0; r < repeat; r++) {
      const t0 = r6(start + r * op.dur);
      if (op.set) {
        for (const [ref, value] of Object.entries(op.set)) {
          const entry = resolveRef({ index }, ref);
          if (clockLeaves.has(entry.bits[0])) {
            bad('ops[' + i + ']: "' + ref + '" is laid by opts.clock and cannot also be set by an op; ' +
              'gate the storage element with ENA/WE instead of fighting the clock');
          }
          const lv = expandValue(entry, value);
          entry.bits.forEach((leaf, k) => evs.get(leaf).push({ t: t0, level: lv[k] }));
        }
      }
      cursor = r6(t0 + op.dur);
    }
  });

  const total = r6(Math.max(cursor, o.total != null ? o.total : 0));
  if (!(total > EPS)) {
    bad('total duration is ' + total + ': a timeline must be longer than 0 (give an op a dur, or pass opts.total)');
  }

  const init = new Map();
  for (const l of leaves) {
    if (l.bus) continue;                       // a BUS parent gets no transition list at all
    init.set(l.name, l.dir === 'out' ? 'X' : '0');
  }
  if (o.init) {
    for (const [ref, v] of Object.entries(o.init)) {
      const entry = resolveRef({ index }, ref);
      if (clockLeaves.has(entry.bits[0])) bad('opts.init: "' + ref + '" is a clock channel');
      const lv = expandValue(entry, v);
      entry.bits.forEach((leaf, k) => init.set(leaf, lv[k]));
    }
  }
  for (const c of clockList) {
    evs.get(c.name).push({ t: 0, level: '1' });          // the wave starts HIGH
    for (const e of clockEvents(c, total)) evs.get(c.name).push(e);
  }

  const segs = Object.create(null);
  for (const l of leaves) {
    if (l.bus) continue;
    segs[l.name] = materialize(init.get(l.name), evs.get(l.name), total, l.name);
  }

  const grid = clockList.length
    ? { period: clockList[0].period, duty: clockList[0].duty }
    : { period: o.gridPeriod != null ? r6(o.gridPeriod) : 10, duty: o.gridDuty != null ? o.gridDuty : 50 };

  return { unit: 'ns', total, channels: decls, leaves, index, segs, clocks: clockList, grid };
}

// ---------------------------------------------------------------------------
// buildTimelineFromSegments(channels, segMap, opts) -> timeline
// Escape hatch: assemble a timeline straight from per-channel waveforms rather than ops.
// seqtest.mjs uses it to synthesise the shape of a guest .sim.vwf RESPONSE (reference-model
// output -> emitted file -> checkSeq), so deliverables 1, 2 and 4 cross-check each other
// without the guest. A segMap value is a level string (constant, needs opts.total), an array
// of runs with "dur", or an array of spans with "t0"/"t1". Every channel must run to the same
// total.
// ---------------------------------------------------------------------------
export function buildTimelineFromSegments(channels, segMap, opts) {
  const o = opts || {};
  if (!segMap || typeof segMap !== 'object') bad('buildTimelineFromSegments: segMap must be an object');
  const { decls, leaves } = declareChannels(channels);
  const index = buildIndex(decls);
  const segs = Object.create(null);
  let total = -1;
  for (const d of decls) {
    for (const leaf of d.bits) {
      const spec = segMap[leaf];
      if (spec == null) bad('buildTimelineFromSegments: no waveform given for "' + leaf + '"');
      let runs;
      if (typeof spec === 'string') {
        if (!(o.total > 0)) bad('buildTimelineFromSegments: a constant level for "' + leaf + '" needs opts.total');
        runs = [{ level: normLevel(spec, leaf), dur: r6(o.total) }];
      } else if (Array.isArray(spec) && spec.length && spec[0].t0 != null) {
        if (r6(spec[0].t0) !== 0) bad('buildTimelineFromSegments: ' + leaf + ' starts at ' + spec[0].t0 + ', must start at 0');
        for (let i = 1; i < spec.length; i++) {
          if (r6(spec[i].t0) !== r6(spec[i - 1].t1)) {
            bad('buildTimelineFromSegments: ' + leaf + ' has a gap or overlap before ' + JSON.stringify(spec[i]));
          }
        }
        runs = spec.map((s) => ({ level: normLevel(s.level, leaf), dur: r6(s.t1 - s.t0) }));
      } else if (Array.isArray(spec) && spec.length) {
        runs = spec.map((s) => {
          if (!s || typeof s !== 'object' || s.level == null || s.dur == null) {
            bad('buildTimelineFromSegments: ' + leaf + ' run needs level and dur, got ' + JSON.stringify(s));
          }
          return { level: normLevel(s.level, leaf), dur: r6(s.dur) };
        });
      } else {
        bad('buildTimelineFromSegments: ' + leaf + ' waveform must be a level string, an array of ' +
          'runs with dur, or an array of spans with t0/t1');
      }
      for (const s of runs) if (!(s.dur > EPS)) bad('buildTimelineFromSegments: ' + leaf + ' has non-positive dur ' + s.dur);
      const myTotal = r6(runs.reduce((a, s) => a + s.dur, 0));
      if (!(myTotal > EPS)) bad('buildTimelineFromSegments: ' + leaf + ' total is ' + myTotal);
      if (total < 0) total = myTotal;
      else if (Math.abs(total - myTotal) > EPS) {
        bad('buildTimelineFromSegments: "' + leaf + '" runs to ' + myTotal + ' but the timeline runs to ' + total);
      }
      const evs = [];
      let t = 0;
      for (const s of runs) { evs.push({ t, level: s.level }); t = r6(t + s.dur); }
      segs[leaf] = materialize(runs[0].level, evs, total, leaf);
    }
  }
  if (o.total != null && Math.abs(r6(o.total) - total) > EPS) {
    bad('buildTimelineFromSegments: opts.total=' + o.total + ' but the given waveforms run to ' + total);
  }
  if (o.clock != null) bad('buildTimelineFromSegments: lay the clock through segMap, not opts.clock');
  return {
    unit: 'ns',
    total,
    channels: decls,
    leaves,
    index,
    segs,
    clocks: [],
    grid: { period: o.gridPeriod != null ? r6(o.gridPeriod) : 10, duty: o.gridDuty != null ? o.gridDuty : 50 },
  };
}

// ---------------------------------------------------------------------------
// timeline queries. Segments are half-open, so a sample exactly at a boundary returns the
// value that STARTS there - the same rule sampleAt() applies to a returned .vwf.
// ---------------------------------------------------------------------------
export function levelAt(timeline, ref, t) {
  const e = resolveRef(timeline, ref);
  if (e.kind !== 'bit') bad('levelAt: "' + ref + '" names a ' + e.width + '-bit bus; use wordAt() or levelsAt()');
  return sampleSeg(timeline.segs[e.bits[0]], t, e.bits[0]);
}
export function levelsAt(timeline, ref, t) {
  const e = resolveRef(timeline, ref);
  return e.bits.map((leaf) => sampleSeg(timeline.segs[leaf], t, leaf)).join('');
}
// integer word value, or null when any bit is X or Z
export function wordAt(timeline, ref, t) {
  const s = levelsAt(timeline, ref, t);
  if (s.indexOf('X') >= 0 || s.indexOf('Z') >= 0) return null;
  return parseInt(s, 2);
}
function sampleSeg(segs, t, who) {
  if (typeof t !== 'number' || !isFinite(t)) bad('sample time for ' + who + ' must be a finite number, got ' + t);
  if (t < -EPS) bad('sample time for ' + who + ' is negative (' + t + ')');
  for (const s of segs) if (t >= s.t0 - EPS && t < s.t1 - EPS) return s.level;
  if (!segs.length) bad('no segments for ' + who);
  return segs[segs.length - 1].level;                    // past the end: hold the last value
}



// ---------------------------------------------------------------------------
// emitSeqVwf(timeline, opts) -> .vwf text
//   opts.driveAll  true -> write the timeline's own waveform for dir:"out" channels instead
//                          of LEVEL X. Default false is the authentic stimulus shape: an
//                          observed channel is declared but not driven (see D/D.vwf).
//                          driveAll exists for host-side round-trip tests and for writing a
//                          stand-in response file; it is NOT what you hand to the guest.
//   opts.groups    [ { name, members: [bit chanRef, ...], radix? } ]  display-only grouping
//                          of separate 1-bit pins under one row, like the GROUP("Q") block in
//                          ref/vwf/VHDL_4_bit_memory/db/*.sim.vwf. A group name gets no SIGNAL
//                          and no TRANSITION_LIST of its own.
//   opts.comment   extra note appended to the header comment.
// The text is re-read with tools/bdf/simcheck.mjs parseVwf before returning, so a formatting
// slip fails here instead of being rejected by the guest.
// ---------------------------------------------------------------------------
export function emitSeqVwf(timeline, opts) {
  const o = opts || {};
  if (!timeline || !timeline.segs || !timeline.channels) bad('emitSeqVwf: not a timeline - build it with buildTimeline()');
  const total = timeline.total;
  if (!(total > EPS)) bad('emitSeqVwf: non-positive total duration ' + total);
  const dirOf = Object.create(null);
  for (const l of timeline.leaves) dirOf[l.name] = l.dir;
  const driven = (name) => dirOf[name] === 'in' || o.driveAll === true;
  const groups = normaliseGroups(o.groups, timeline);

  const L = [];
  const push = (...xs) => xs.forEach((x) => L.push(x));

  push('/* Generated by lab13/seqvwf.mjs: ordered sequential timeline, no GUI interaction. */');
  if (o.comment) push('/* ' + String(o.comment).split('*/').join('* /') + ' */');
  push('');
  push('HEADER', '{');
  push(TAB + 'VERSION = 1;');
  push(TAB + 'TIME_UNIT = ns;');
  push(TAB + 'SIMULATION_TIME = 0.0;');
  push(TAB + 'GRID_PHASE = 0.0;');
  push(TAB + 'GRID_PERIOD = ' + fmtTime(timeline.grid.period) + ';');
  push(TAB + 'GRID_DUTY_CYCLE = ' + String(r6(timeline.grid.duty)) + ';');
  push('}', '');

  for (const l of timeline.leaves) {
    push('SIGNAL("' + l.name + '")', '{');
    push(TAB + 'VALUE_TYPE = NINE_LEVEL_BIT;');
    push(TAB + 'SIGNAL_TYPE = ' + (l.bus ? 'BUS' : 'SINGLE_BIT') + ';');
    push(TAB + 'WIDTH = ' + (l.bus ? l.width : 1) + ';');
    push(TAB + 'LSB_INDEX = ' + (l.bus ? 0 : -1) + ';');
    push(TAB + 'DIRECTION = ' + (l.dir === 'in' ? 'INPUT' : 'OUTPUT') + ';');
    push(TAB + 'PARENT = "' + (l.parent || '') + '";');
    push('}', '');
  }
  for (const g of groups) {
    push('GROUP("' + g.name + '")', '{');
    push(TAB + 'MEMBERS = ' + g.members.map((m) => '"' + m + '"').join(', ') + ';');
    push('}', '');
  }

  for (const l of timeline.leaves) {
    if (l.bus) continue;                                  // a BUS parent never gets a list
    push('TRANSITION_LIST("' + l.name + '")', '{', TAB + 'NODE', TAB + '{');
    push(TAB + TAB + 'REPEAT = 1;');
    if (!driven(l.name)) {
      push(TAB + TAB + 'LEVEL X FOR ' + fmtTime(total) + ';');
    } else {
      for (const r of collapseRuns(timeline.segs[l.name])) {
        push(TAB + TAB + 'LEVEL ' + r.level + ' FOR ' + fmtTime(r.dur) + ';');
      }
    }
    push(TAB + '}', '}', '');
  }

  // DISPLAY_LINE order, measured on VHDL_4_bit_memory.vwf: ungrouped channels first (buses as a
  // parent row followed by their bit rows), then each GROUP parent row followed by its member
  // rows. A pin that belongs to a group appears ONCE, nested under the group row - emitting it
  // both flat and nested duplicates the CHANNEL name, which Quartus tolerates for two distinct
  // nodes sharing a label (VHDL_4_bit_memory lists "Read" twice for that reason) but which is a
  // bug for one node.
  const grouped = new Set();
  for (const g of groups) for (const m of g.members) grouped.add(m);
  let idx = 0;
  const rows = [];
  for (const d of timeline.channels) {
    if (d.kind === 'bus') {
      const start = idx + 1;
      const my = idx++;
      rows.push({ channel: d.name, level: 0, parent: null, children: d.bits.map((_, k) => start + k), radix: d.radix, my });
      for (const b of d.bits) rows.push({ channel: b, level: 1, parent: my, children: null, radix: d.radix, my: idx++ });
    } else if (!grouped.has(d.name)) {
      rows.push({ channel: d.name, level: 0, parent: null, children: null, radix: d.radix, my: idx++ });
    }
  }
  for (const g of groups) {
    const start = idx + 1;
    const my = idx++;
    rows.push({ channel: g.name, level: 0, parent: null, children: g.members.map((_, k) => start + k), radix: g.radix, my });
    for (const m of g.members) rows.push({ channel: m, level: 1, parent: my, children: null, radix: g.radix, my: idx++ });
  }
  for (const r of rows) {
    push('DISPLAY_LINE', '{');
    push(TAB + 'CHANNEL = "' + r.channel + '";');
    push(TAB + 'EXPAND_STATUS = COLLAPSED;');
    push(TAB + 'RADIX = ' + r.radix + ';');
    push(TAB + 'TREE_INDEX = ' + r.my + ';');
    push(TAB + 'TREE_LEVEL = ' + r.level + ';');
    if (r.parent !== null) push(TAB + 'PARENT = ' + r.parent + ';');
    if (r.children && r.children.length) push(TAB + 'CHILDREN = ' + r.children.join(', ') + ';');
    push('}', '');
  }
  push('TIME_BAR', '{');
  push(TAB + 'TIME = 0;');
  push(TAB + 'MASTER = TRUE;');
  push('}', ';');

  const text = L.join(NL) + NL;
  auditEmitted(text, timeline, groups, o);
  return text;
}

export function collapseRuns(seg) {
  const out = [];
  for (const s of seg) {
    const last = out[out.length - 1];
    if (last && last.level === s.level) { last.dur = r6(last.dur + (s.t1 - s.t0)); continue; }
    out.push({ level: s.level, dur: r6(s.t1 - s.t0) });
  }
  for (const s of out) if (!(s.dur > EPS)) bad('collapseRuns: zero-length run ' + JSON.stringify(s));
  return out;
}

function normaliseGroups(groups, timeline) {
  if (groups == null) return [];
  if (!Array.isArray(groups)) bad('opts.groups must be an array');
  return groups.map((g, i) => {
    const tag = 'groups[' + i + ']';
    if (!g || typeof g !== 'object') bad(tag + ' must be an object with name and members');
    const unknown = Object.keys(g).filter((k) => k !== 'name' && k !== 'members' && k !== 'radix');
    if (unknown.length) bad(tag + ': unknown key(s) ' + unknown.join(', '));
    if (typeof g.name !== 'string' || !NAME_RE.test(g.name)) bad(tag + ': illegal name ' + JSON.stringify(g.name));
    if (timeline.index[g.name]) bad(tag + ': "' + g.name + '" is already a declared channel; a group name must be free');
    if (!Array.isArray(g.members) || g.members.length < 2) bad(tag + ': members must be a list of at least 2 bit refs');
    const leaves = g.members.map((ref) => {
      const e = resolveRef(timeline, ref);
      if (e.kind !== 'bit') bad(tag + ': "' + ref + '" is a ' + e.width + '-bit bus; group members are 1-bit pins');
      return e.bits[0];
    });
    if (new Set(leaves).size !== leaves.length) bad(tag + ': duplicate member in ' + leaves.join(', '));
    return { name: g.name, members: leaves, radix: g.radix || 'Binary' };
  });
}

// Assert, do not assume. Re-read the emitted text with the very parser a guest response is
// checked with, and confirm the invariants the format requires.
function auditEmitted(text, timeline, groups, o) {
  const tl = parseVwf(text);
  const total = timeline.total;
  for (const l of timeline.leaves) {
    if (l.bus) {
      if (tl[l.name]) bad('audit: BUS parent "' + l.name + '" must not carry a TRANSITION_LIST');
      continue;
    }
    const e = tl[l.name];
    if (!e) bad('audit: no TRANSITION_LIST for "' + l.name + '" survived the round trip');
    if (Math.abs(e.end - total) > 1e-6) {
      bad('audit: TRANSITION_LIST("' + l.name + '") runs to ' + r6(e.end) + ' but the timeline total is ' + total);
    }
    let t = 0;
    for (const s of e.segs) {
      if (!(s.t1 > s.t0)) bad('audit: ' + l.name + ' zero-length run ' + JSON.stringify(s));
      if (Math.abs(s.t0 - t) > 1e-6) bad('audit: ' + l.name + ' gap or overlap at ' + JSON.stringify(s));
      if (LEVELS.indexOf(s.level) < 0) bad('audit: ' + l.name + ' level outside the vocabulary: ' + JSON.stringify(s.level));
      t = s.t1;
    }
    if (Math.abs(t - total) > 1e-6) bad('audit: ' + l.name + ' ends at ' + r6(t) + ', expected ' + total);
    if (l.dir === 'out' && !o.driveAll) {
      if (e.segs.length !== 1 || e.segs[0].level !== 'X') {
        bad('audit: observed channel "' + l.name + '" must be a single LEVEL X in a stimulus file');
      }
    }
  }
  const sigNames = [...text.matchAll(/SIGNAL\("([^"]+)"\)/g)].map((m) => m[1]);
  if (sigNames.length !== timeline.leaves.length) {
    bad('audit: ' + sigNames.length + ' SIGNAL blocks for ' + timeline.leaves.length + ' waveform channels');
  }
  for (const l of timeline.leaves) {
    if (sigNames.indexOf(l.name) < 0) bad('audit: no SIGNAL("' + l.name + '")');
    if (l.bus) continue;
    // A bare NAMEi channel is silently ignored by Quartus 5.0 and leaves the wire at X (see
    // tools/bdf/vwf.mjs lines 40-43), so a bus bit may only be spelled NAME[i].
    const d = timeline.channels.find((c) => c.name === l.chan);
    if (d.kind === 'bus') {
      for (let k = 0; k < d.width; k++) {
        const bare = d.name + k;
        if (bare !== l.name && sigNames.indexOf(bare) >= 0) {
          bad('audit: bare bus-bit spelling "' + bare + '" appears as a SIGNAL; Quartus ignores it');
        }
      }
    }
  }
  for (const g of groups) {
    if (sigNames.indexOf(g.name) >= 0) bad('audit: group "' + g.name + '" must not be a SIGNAL');
    if (text.indexOf('GROUP("' + g.name + '")') < 0) bad('audit: missing GROUP block for ' + g.name);
    if (tl[g.name]) bad('audit: group "' + g.name + '" must not carry a TRANSITION_LIST');
  }
  const rows = [...text.matchAll(/CHANNEL = "([^"]+)";/g)].map((m) => m[1]);
  // One row per node. A real Quartus file CAN repeat a label (two distinct nodes with the same
  // name, as VHDL_4_bit_memory.vwf does for "Read"), so this is a guarantee about OUR output,
  // not a claim about the format.
  if (new Set(rows).size !== rows.length) bad('audit: duplicate DISPLAY_LINE channel');
  const indexes = [...text.matchAll(/TREE_INDEX = (\d+);/g)].map((m) => Number(m[1]));
  if (indexes.join() !== indexes.map((_, k) => String(k)).join()) bad('audit: TREE_INDEX is not 0..n-1 in order');
  if (text.indexOf('MASTER = TRUE;') < 0) bad('audit: no TIME_BAR master');
}
