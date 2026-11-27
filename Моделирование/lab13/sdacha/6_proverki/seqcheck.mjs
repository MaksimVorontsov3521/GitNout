// lab13/seqcheck.mjs - compare a returned Quartus .sim.vwf against declared sample points.
//
// This is the sequential counterpart of tools/bdf/simcheck.mjs checkSim(), which assumes row i
// of a flat vector table occupies [i*period, (i+1)*period). That holds for a memory circuit
// too - the lead measured probe_reg passing 12 phases of it in the guest - but it forces every
// phase to be the same length and gives no way to say "sample the bus 30 ns after the edge".
// Here a sample is just a time and a set of expected values, so phases may be unequal and a
// sample may sit anywhere mid-interval.
//
//   checkSeq({ vwfText, samples, opts }) -> { ok, checked, mismatches, zSeen, xSeen, ... }
//     samples = [{ t, expect: { chanRef: value }, label }]
//     mismatches = [{ t, chan, want, got, label }]
//     opts.period + opts.phases  sugar: expand a phase list into samples at
//       i*period + frac*period, so an existing spec.vectors table can be re-checked with the
//       sequential rules (proved equivalent to checkSim by seqtest.mjs).
//     opts.relaxZ  true -> a want of Z also accepts 0 or 1 (a bus that is being driven). Off by
//       default: Z means high impedance and nothing else satisfies it.
//
//   busWord(tl, name, width, t) -> integer, or null if ANY bit of the bus is X or Z.
//     tl is a parseVwf() result. Measured reason this exists rather than a parseInt call:
//     parseInt("ZZZZZZZZ", 2) is NaN, but parseInt("0000ZZZZ", 2) is 0 and parseInt("1010Z010",
//     2) is 10 - base-2 parsing stops at the first non-binary character and returns whatever
//     prefix it consumed. A half-idle bus therefore reads as a plausible small integer, which
//     is worse than NaN. busWord checks every bit before deciding, so an idle or unresolved bus
//     is null and cannot masquerade as data.
//
// X versus Z, which the task asks to keep apart:
//   Z is a legitimate idle bus - a tri-state buffer with its enable low. Reaching Z is evidence
//   the output stage works, so checkSeq counts it (zSeen) and never treats it as an error.
//   X is unresolved: the simulator could not decide. That is either an unwritten memory cell
//   or a floating input, and it is a finding, so checkSeq counts it separately (xSeen), lists
//   every X sampled at a channel the caller did NOT expect (unexplainedX), and puts a loud
//   one-line warning into the warn array for it.
//
// A channel that is absent from the response is a MISMATCH, never a silent skip: Quartus drops
// a channel it cannot bind (a bare NAMEi bus-bit spelling is the classic case, see
// tools/bdf/vwf.mjs lines 40-43), so silence is exactly the symptom worth catching.
//
// Z PRESERVATION - measured, not assumed. The tokeniser in tools/bdf/simcheck.mjs is
//   NODE|REPEAT|LEVEL|FOR|[{}]|-?digits|[01XZH]
// and its LEVEL branch accepts either a level token or a number, so Z survives as the string
// "Z". parseVwf() therefore keeps Z segments and sampleAt() returns "Z" for them. That claim is
// re-proved at run time by proveZpreserved() below against real guest output rather than by
// reading the regex: the lead probe files each carry eight channels with genuine LEVEL Z runs,
// and every one of them parses to a Z segment. If a future parser change lost Z,
// proveZpreserved() would report it and checkSeq would refuse to run blind.

import fs from 'node:fs';
import { parseVwf, sampleAt } from './tools/bdf/simcheck.mjs';

export { parseVwf, sampleAt };

const LV = ['0', '1', 'X', 'Z'];
const err = (msg) => { throw new Error('seqcheck: ' + msg); };
const is01 = (s) => s === "0" || s === "1";
const r6 = (x) => Math.round(x * 1e6) / 1e6;
// ---------------------------------------------------------------------------
// channel resolution against a PARSED response
// ---------------------------------------------------------------------------

// Strip brackets so NAME[i] and NAMEi denote one wire, the rule tools/bdf/simcheck.mjs uses.
const stripBrackets = (s) => s.replace(/[\[\]]/g, "");

// tl -> { exact: Set(names), byBare: Map(bareSpelling -> first exact name) }
function channelIndex(tl) {
  const exact = new Set(Object.keys(tl));
  const byBare = new Map();
  for (const k of exact) {
    const b = stripBrackets(k);
    if (!byBare.has(b)) byBare.set(b, k);
  }
  return { exact, byBare };
}

// Resolve one chanRef to the list of response channel names holding its bits, MSB first.
// Returns { bits: [name], width, kind } or null when nothing in the response matches - the
// caller turns a null into an absent-channel mismatch instead of skipping it.
function resolveChan(tl, ref) {
  const ix = channelIndex(tl);
  const bracketed = /^([A-Za-z_][A-Za-z0-9_]*)(?:\[(\d+)\]|([0-9]+))$/.exec(ref);
  if (bracketed && ix.exact.has(ref)) {
    return { kind: "bit", bits: [ref], width: 1 };                       // NAME[i] spelled out
  }
  if (ix.exact.has(ref)) return { kind: "bit", bits: [ref], width: 1 };  // a plain 1-bit channel
  if (bracketed) {
    const idx = bracketed[2] != null ? Number(bracketed[2]) : Number(bracketed[3]);
    const base = bracketed[1];
    const cand = base + "[" + idx + "]";
    if (ix.exact.has(cand)) return { kind: "bit", bits: [cand], width: 1 };   // NAMEi -> NAME[i]
    const alias = ix.byBare.get(base + idx);
    if (alias) return { kind: "bit", bits: [alias], width: 1 };
  }
  // whole bus: every bit NAME[w-1] .. NAME[0] that the response actually carries
  const widths = [...ix.exact]
    .filter((k) => k.indexOf("[") >= 0 && k.slice(0, k.indexOf("[")) === ref)
    .map((k) => Number(/\[(\d+)\]$/.exec(k)[1]));
  if (widths.length) {
    const w = Math.max(...widths) + 1;
    const bits = [];
    for (let k = w - 1; k >= 0; k--) bits.push(ref + "[" + k + "]");
    const missing = bits.filter((b) => !ix.exact.has(b));
    return { kind: missing.length ? "partial" : "bus", bits, width: w, missing };
  }
  const alias = ix.byBare.get(ref);
  if (alias) return { kind: "bit", bits: [alias], width: 1 };
  return null;
}

// Integer value of a bus at time t, or null if any bit is X or Z (or absent).
// Signature per the task: busWord(tl, name, width, t).
export function busWord(tl, name, width, t) {
  const ix = channelIndex(tl);
  const bits = [];
  for (let k = width - 1; k >= 0; k--) {
    const cand = name + "[" + k + "]";
    const ch = ix.exact.has(cand) ? cand : ix.byBare.get(name + k);
    if (!ch) return null;
    bits.push(sampleAt(tl, ch, t));            // sampleAt(tl, name, t) - the tools/bdf signature
  }
  for (const b of bits) if (!is01(b)) return null;                    // X or Z anywhere: no word
  return parseInt(bits.join(""), 2);
}

// ---------------------------------------------------------------------------
// expectation normalisation
// ---------------------------------------------------------------------------

// A wanted value becomes the level string it demands, MSB first for a bus. Accepts a level
// ('Z'), 0/1, an integer word, a level string, or a level array. Anything malformed is an
// authoring error and throws rather than silently becoming a mismatch.
function normWant(v, width, ref) {
  if (typeof v === 'number') {
    if (!Number.isInteger(v)) err('want for ' + ref + ': expected an integer, got ' + v);
    if (width === 1) {
      if (v !== 0 && v !== 1) err('want for 1-bit ' + ref + ': got ' + v);
      return String(v);
    }
    if (v < 0 || v >= Math.pow(2, width)) {
      err('want for ' + ref + ': ' + v + ' does not fit in ' + width + ' bits');
    }
    let s = '';
    for (let k = width - 1; k >= 0; k--) s += String((v >> k) & 1);
    return s;
  }
  if (Array.isArray(v)) {
    if (v.length !== width) err('want for ' + ref + ': array of ' + v.length + ', expected ' + width);
    return v.map((c) => normWant(c, 1, ref)).join('');
  }
  if (typeof v === 'string') {
    const u = v.toUpperCase();
    if (u.length === 1) {
      if (LV.indexOf(u) < 0) err('want for ' + ref + ': unknown level ' + JSON.stringify(v));
      if (width === 1) return u;
      if (u === 'X' || u === 'Z') return new Array(width).fill(u).join('');   // fill the word
      err('want for bus ' + ref + ": a single '" + u + "' cannot fill a " + width + '-bit word; ' +
        'write the whole level string, an integer, or "X"/"Z"');
    }
    if (u.length !== width) err('want for ' + ref + ': level string of ' + u.length + ' chars, expected ' + width);
    for (const c of u) if (LV.indexOf(c) < 0) err('want for ' + ref + ': unknown level in ' + JSON.stringify(v));
    return u;
  }
  return err('want for ' + ref + ': unsupported value ' + JSON.stringify(v));
}

// A bus matches when every bit matches; with relaxZ a wanted Z also accepts a driven 0/1.
function busEquals(got, want, relaxZ) {
  if (got.length !== want.length) return false;
  for (let k = 0; k < want.length; k++) {
    if (got[k] === want[k]) continue;
    if (relaxZ && want[k] === 'Z' && is01(got[k])) continue;
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// sample collection: explicit samples, or the phase-table sugar
// ---------------------------------------------------------------------------

// opts.period + opts.phases expands to samples at i*period + frac*period, which is where a
// zero-delay functional simulation has settled. opts.phases[i] may carry its own dur, so
// unequal phases (the thing checkSim cannot express) work too. Explicit samples win.
function collectSamples(a) {
  if (Array.isArray(a.samples)) {
    return a.samples.map((s, i) => {
      if (!s || typeof s !== 'object') err('samples[' + i + '] must be an object { t, expect, label }');
      const unknown = Object.keys(s).filter((k) => k !== 't' && k !== 'expect' && k !== 'label');
      if (unknown.length) err('samples[' + i + ']: unknown key(s) ' + unknown.join(', '));
      return s;
    });
  }
  const o = a.opts || {};
  if (!Array.isArray(o.phases)) err('checkSeq: give either samples or opts.phases');
  const period = o.period != null ? o.period : a.period;
  if (typeof period !== 'number' || !(period > 0)) err('checkSeq: opts.phases needs opts.period > 0');
  const frac = o.frac == null ? 0.5 : o.frac;
  if (!(frac > 0 && frac < 1)) err('checkSeq: opts.frac must lie strictly inside (0,1), got ' + frac);
  let t = 0;
  return o.phases.map((ph, i) => {
    if (!ph || typeof ph !== 'object') err('opts.phases[' + i + '] must be an object');
    const dur = ph.dur == null ? period : ph.dur;
    if (!(dur > 0)) err('opts.phases[' + i + ']: dur must be positive');
    const at = ph.at != null ? ph.at : t + frac * dur;
    const s = { t: r6(at), expect: ph.expect || ph, label: ph.label == null ? 'phase ' + i : String(ph.label) };
    t = r6(t + dur);
    return s;
  });
}

// ---------------------------------------------------------------------------
// checkSeq
// ---------------------------------------------------------------------------
export function checkSeq(args) {
  const a = args || {};
  if (typeof a.vwfText !== 'string' || !a.vwfText.length) err('checkSeq: vwfText must be non-empty text');
  const tl = parseVwf(a.vwfText);
  const samples = collectSamples(a);
  const relaxZ = a.opts && a.opts.relaxZ === true;
  const mismatches = [];
  const unexplainedX = [];
  const absent = [];
  let checked = 0, zSeen = 0, xSeen = 0;
  const total = Object.keys(tl).reduce((m, k) => Math.max(m, tl[k].end), 0);

  for (const s of samples) {
    const label = s.label == null ? '' : String(s.label);
    if (typeof s.t !== 'number' || !isFinite(s.t) || s.t < 0) {
      err('checkSeq: sample t must be a non-negative number, got ' + JSON.stringify(s.t));
    }
    if (s.t > total + 1e-9) {
      mismatches.push({ t: s.t, chan: '*', want: 'in-range', got: 'past-end', label });
      continue;
    }
    if (!s.expect || typeof s.expect !== 'object') err('checkSeq: sample at ' + s.t + ' needs an expect object');
    for (const [ref, wantRaw] of Object.entries(s.expect)) {
      const res = resolveChan(tl, ref);
      if (!res) {
        absent.push({ t: s.t, chan: ref, label });
        mismatches.push({ t: s.t, chan: ref, want: String(wantRaw), got: '<absent>', label });
        continue;
      }
      if (res.kind === 'partial') {
        for (const b of res.missing) {
          absent.push({ t: s.t, chan: b, label });
          mismatches.push({ t: s.t, chan: b, want: 'present', got: '<absent>', label });
        }
      }
      const width = res.width;
      const want = normWant(wantRaw, width, ref);
      const gotBits = res.bits.map((b) => {
        const v = sampleAt(tl, b, s.t);
        return v == null ? '<absent>' : v;
      });
      const got = gotBits.join('');
      checked++;
      if (got.indexOf('Z') >= 0) zSeen++;
      if (got.indexOf('X') >= 0) xSeen++;
      if (!busEquals(got, want, relaxZ)) {
        mismatches.push({ t: s.t, chan: ref, want, got, label });
      }
      // X that the author did not ask for is a finding even when the row otherwise matched,
      // because with relaxZ a driven bus can hide one.
      if (width === 1) {
        if (got === 'X' && want !== 'X') unexplainedX.push({ t: s.t, chan: ref, got, want, label });
      } else {
        for (let k = 0; k < width; k++) {
          if (gotBits[k] === 'X' && want[k] !== 'X') {
            unexplainedX.push({ t: s.t, chan: res.bits[k], got: 'X', want: want[k], label });
          }
        }
      }
    }
  }

  const warn = [];
  if (absent.length) {
    warn.push('ABSENT CHANNELS: ' + absent.length + ' reference(s) matched no response channel. ' +
      'Quartus drops a channel it cannot bind, so those wires are UNOBSERVED rather than merely wrong: ' +
      absent.slice(0, 6).map((x) => x.chan + '@' + x.t).join(', ') + (absent.length > 6 ? ' ...' : ''));
  }
  if (unexplainedX.length) {
    warn.push('UNRESOLVED (X) WHERE A DEFINITE LEVEL WAS EXPECTED: ' + unexplainedX.length +
      ' sample(s), e.g. ' + unexplainedX.slice(0, 6).map((x) => x.chan + '@' + x.t).join(', ') +
      (unexplainedX.length > 6 ? ' ...' : '') +
      '. An X is either an unwritten memory cell or a floating input; it is never a passing result.');
  }
  return {
    ok: mismatches.length === 0,
    checked,
    mismatches,
    zSeen,
    xSeen,
    unexplainedX,
    absent,
    warn,
    samples: samples.length,
    responseEnd: r6(total),
    channels: Object.keys(tl),
  };
}

// ---------------------------------------------------------------------------
// proveZpreserved - the Z claim tested at run time, not taken on faith
// ---------------------------------------------------------------------------
// Reads the given .sim.vwf texts (or files), parses each with tools/bdf/simcheck.mjs
// parseVwf, and reports whether Z survived: how many Z segments the parser produced, and
// whether sampleAt returns 'Z' at the midpoint of every one of them. ok is false when no Z
// was found at all, because then nothing was proved.
export function proveZpreserved(sources) {
  const list = Array.isArray(sources) ? sources : [sources];
  if (!list.length) err('proveZpreserved: give at least one vwf text or path');
  const reports = [];
  let zSegments = 0, zSampled = 0, levelsSeen = new Set();
  for (const src of list) {
    let text = src, origin = 'inline text';
    if (typeof src === 'object' && src !== null) { text = src.text; origin = src.name || 'inline text'; }
    else if (typeof src === 'string' && (src.indexOf('TRANSITION_LIST') < 0 || src.length < 40)) {
      origin = src;
      text = fs.readFileSync(src, 'utf8');
    }
    const tl = parseVwf(text);
    const names = Object.keys(tl);
    if (!names.length) err('proveZpreserved: ' + origin + ' yielded no channels - the parser did not recognise it');
    const perChannel = [];
    for (const n of names) {
      for (const seg of tl[n].segs) {
        levelsSeen.add(seg.level);
        if (seg.level !== 'Z') continue;
        zSegments++;
        const mid = r6((seg.t0 + seg.t1) / 2);
        const got = sampleAt(tl, n, mid);
        if (got === 'Z') zSampled++;
        perChannel.push({ chan: n, t0: seg.t0, t1: seg.t1, mid, got });
      }
    }
    reports.push({ origin, channels: names.length, zRuns: perChannel.length, zRunsDetail: perChannel });
  }
  const lost = reports.flatMap((r) => r.zRunsDetail).filter((z) => z.got !== 'Z');
  return {
    ok: zSegments > 0 && lost.length === 0,
    zSegments,
    zSampled,
    lost,
    levelsSeen: [...levelsSeen].sort(),
    reports,
  };
}




