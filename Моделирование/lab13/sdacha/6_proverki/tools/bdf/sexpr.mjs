// BDF s-expression parser and serializer for Quartus II graphic files
const NL = String.fromCharCode(10);
const TAB = String.fromCharCode(9);
const DQ = String.fromCharCode(34);
const BS = String.fromCharCode(92);

export function isStr(x) { return x !== null && typeof x === 'object' && typeof x.str === 'string'; }
export function head(node) { return Array.isArray(node) && node.length && typeof node[0] === 'string' ? node[0] : ''; }
export function atom(v) { return typeof v === 'string'; }

export function parse(text) {
  const n = text.length;
  const toks = [];
  let i = 0;
  const sp = (c) => c === 32 || c === 9 || c === 10 || c === 13 || c === 11 || c === 12;
  while (i < n) {
    const c = text.charCodeAt(i);
    if (c === 47 && text.charCodeAt(i + 1) === 47) { while (i < n && text.charCodeAt(i) !== 10) i++; continue; }
    if (c === 47 && text.charCodeAt(i + 1) === 42) {
      i += 2;
      while (i < n && !(text.charCodeAt(i) === 42 && text.charCodeAt(i + 1) === 47)) i++;
      i += 2; continue;
    }
    if (sp(c)) { i++; continue; }
    if (c === 40) { toks.push('('); i++; continue; }
    if (c === 41) { toks.push(')'); i++; continue; }
    if (c === 34) {
      let j = i + 1, s = '';
      while (j < n) {
        const cj = text.charCodeAt(j);
        if (cj === 92 && j + 1 < n) { s += text.charAt(j + 1); j += 2; continue; }
        if (cj === 34) { j++; break; }
        s += text.charAt(j); j++;
      }
      toks.push({ str: s }); i = j; continue;
    }
    let j = i;
    while (j < n) {
      const cj = text.charCodeAt(j);
      if (sp(cj) || cj === 40 || cj === 41) break;
      if (cj === 47 && (text.charCodeAt(j + 1) === 47 || text.charCodeAt(j + 1) === 42)) break;
      j++;
    }
    toks.push(text.slice(i, j)); i = j; continue;
  }
  const top = [];
  const stack = [top];
  for (const t of toks) {
    if (t === '(') { const l = []; stack[stack.length - 1].push(l); stack.push(l); }
    else if (t === ')') { stack.pop(); if (stack.length === 0) throw new Error('unbalanced parens in BDF'); }
    else stack[stack.length - 1].push(t);
  }
  if (stack.length !== 1) throw new Error('unclosed parens in BDF');
  return top;
}

export function inline(node) {
  if (isStr(node)) return DQ + node.str.split(DQ).join(BS + DQ) + DQ;
  if (typeof node !== 'object' || node === null) return String(node);
  if (Array.isArray(node)) {
    let out = '(';
    for (let k = 0; k < node.length; k++) {
      if (k > 0) {
        const prev = out.charAt(out.length - 1);
        const e = node[k];
        const nx = isStr(e) ? DQ : (Array.isArray(e) ? '(' : String(e).charAt(0));
        if (!(prev === ')' && nx === '(')) out += ' ';
      }
      out += inline(node[k]);
    }
    return out + ')';
  }
  return JSON.stringify(node);
}

const EXPAND = ['pin', 'symbol', 'port', 'drawing', 'title_block', 'section'];

export function ser(node, depth) {
  const d = depth || 0;
  const pad = TAB.repeat(d);
  if (isStr(node) || typeof node !== 'object' || node === null) return pad + inline(node);
  if (!Array.isArray(node)) return pad + String(node);
  const h = head(node);
  if (EXPAND.indexOf(h) < 0) return pad + inline(node);
  const out = [pad + '(' + h];
  for (let k = 1; k < node.length; k++) out.push(ser(node[k], d + 1));
  out.push(pad + ')');
  return out.join(NL);
}

export function serialize(nodes) { return nodes.map((nd) => ser(nd, 0)).join(NL) + NL; }

export function kids(node, name) { return node.filter((c) => head(c) === name); }
export function kid(node, name) { const k = kids(node, name); return k.length ? k[0] : null; }
export function firstText(node) {
  for (const c of node) if (head(c) === 'text' && isStr(c[1])) return c[1].str;
  return null;
}
export function allTexts(node) {
  const r = [];
  for (const c of node) if (head(c) === 'text' && isStr(c[1])) r.push(c[1].str);
  return r;
}
export function rectOf(node) {
  const rc = kid(node, 'rect');
  return rc ? rc.slice(1).map(Number) : null;
}
export function ptOf(node) {
  const p = kid(node, 'pt');
  return p ? p.slice(1).map(Number) : null;
}
