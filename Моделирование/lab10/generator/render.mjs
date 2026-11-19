// Render a Quartus II .bdf sheet to SVG straight from its geometry, so a generated diagram can
// be inspected (and put in a report) without opening Quartus. Coordinates are taken verbatim:
// symbol/pin inner text rects are relative to the enclosing rect, connector labels are absolute.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const S = await import(pathToFileURL('C:/Users/User/VirtualBox VMs/Microelectronics/tools/bdf/sexpr.mjs').href);

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function rectOf(n) {
  const r = S.kid(n, 'rect');
  return r && r.length >= 5 ? [Number(r[1]), Number(r[2]), Number(r[3]), Number(r[4])] : null;
}
function pts(n) {
  return S.kids(n, 'pt').filter((p) => p.length >= 3).map((p) => [Number(p[1]), Number(p[2])]);
}
function dirOf(n) {
  for (const c of n) { const h = S.head(c); if (h === 'input' || h === 'output' || h === 'bidirectional' || h === 'tristate') return h; }
  return null;
}
function texts(n) {
  return S.kids(n, 'text').filter((t) => S.isStr(t[1])).map((t) => ({ s: t[1].str, rect: rectOf(t) }));
}

export function bdfToSvg(bdfText, opts) {
  const o = opts || {};
  const pad = o.pad || 24;
  const ast = S.parse(bdfText);
  const nodes = Array.isArray(ast) ? ast : [ast];
  const parts = [];
  let maxX = 0, maxY = 0;
  const track = (x, y) => { if (x > maxX) maxX = x; if (y > maxY) maxY = y; };

  for (const nd of nodes) {
    const h = S.head(nd);
    if (h === 'symbol') {
      const rc = rectOf(nd);
      if (!rc) continue;
      const [x0, y0, x1, y1] = rc;
      track(x1, y1);
      parts.push('<rect x="' + x0 + '" y="' + y0 + '" width="' + (x1 - x0) + '" height="' + (y1 - y0) + '" fill="#fffdf5" stroke="#8a8a8a"/>');
      const dr = S.kid(nd, 'drawing');
      if (dr) {
        for (const c of dr) {
          const ch = S.head(c);
          if (ch === 'rectangle') {
            const r = rectOf(c);
            if (r) parts.push('<rect x="' + (x0 + r[0]) + '" y="' + (y0 + r[1]) + '" width="' + (r[2] - r[0]) + '" height="' + (r[3] - r[1]) + '" fill="none" stroke="#222" stroke-width="1.2"/>');
          } else if (ch === 'line') {
            const p = pts(c);
            if (p.length === 2) parts.push('<line x1="' + (x0 + p[0][0]) + '" y1="' + (y0 + p[0][1]) + '" x2="' + (x0 + p[1][0]) + '" y2="' + (y0 + p[1][1]) + '" stroke="#222" stroke-width="1.2"/>');
          } else if (ch === 'circle') {
            const r = rectOf(c);
            if (r) parts.push('<circle cx="' + (x0 + (r[0] + r[2]) / 2) + '" cy="' + (y0 + (r[1] + r[3]) / 2) + '" r="' + (r[2] - r[0]) / 2 + '" fill="#fff" stroke="#222" stroke-width="1.2"/>');
          }
        }
      }
      const ts = texts(nd);
      ts.forEach((t, i) => {
        if (!t.rect) return;
        const tx = x0 + t.rect[0], ty = y0 + t.rect[1];
        const isName = i === 0;
        parts.push('<text x="' + tx + '" y="' + (ty + 11) + '" font-family="' + (isName ? 'Arial' : 'Courier New') + '" font-size="' + (isName ? 11 : 9) + '" fill="' + (isName ? '#0b3d91' : '#555') + '">' + esc(t.s) + '</text>');
      });
      for (const p of S.kids(nd, 'port')) {
        const pp = pts(p);
        if (!pp.length) continue;
        const d = dirOf(p);
        track(x0 + pp[0][0], y0 + pp[0][1]);
        parts.push('<circle cx="' + (x0 + pp[0][0]) + '" cy="' + (y0 + pp[0][1]) + '" r="2" fill="' + (d === 'input' ? '#0a7d33' : d === 'output' ? '#b3300f' : '#777') + '"/>');
      }
    } else if (h === 'pin') {
      const rc = rectOf(nd);
      if (!rc) continue;
      const [x0, y0, x1, y1] = rc;
      track(x1, y1);
      const d = dirOf(nd);
      parts.push('<rect x="' + x0 + '" y="' + y0 + '" width="' + (x1 - x0) + '" height="' + (y1 - y0) + '" fill="' + (d === 'input' ? '#eaf6ff' : '#fff0ea') + '" stroke="' + (d === 'input' ? '#2477b8' : '#b3542a') + '"/>');
      const ts = texts(nd).filter((t) => t.s !== 'INPUT' && t.s !== 'OUTPUT' && t.s !== 'VCC' && t.s !== 'GND');
      for (const t of ts) {
        if (!t.rect) continue;
        parts.push('<text x="' + (x0 + t.rect[0]) + '" y="' + (y0 + t.rect[1] + 11) + '" font-family="Arial" font-size="11" font-weight="bold" fill="#123">' + esc(t.s) + '</text>');
      }
      const dr = S.kid(nd, 'drawing');
      if (dr) for (const c of dr) {
        if (S.head(c) !== 'line') continue;
        const p = pts(c);
        if (p.length === 2) parts.push('<line x1="' + (x0 + p[0][0]) + '" y1="' + (y0 + p[0][1]) + '" x2="' + (x0 + p[1][0]) + '" y2="' + (y0 + p[1][1]) + '" stroke="#2477b8" stroke-width="1"/>');
      }
    } else if (h === 'connector') {
      const p = pts(nd);
      for (const q of p) track(q[0], q[1]);
      for (let i = 0; i + 1 < p.length; i++) {
        parts.push('<line x1="' + p[i][0] + '" y1="' + p[i][1] + '" x2="' + p[i + 1][0] + '" y2="' + p[i + 1][1] + '" stroke="#111" stroke-width="1.4"' + (S.kids(nd, 'bus').length ? ' stroke-dasharray="5,2"' : '') + '/>');
      }
      const lbl = texts(nd)[0];
      if (lbl && lbl.rect) parts.push('<text x="' + lbl.rect[0] + '" y="' + (lbl.rect[1] + 11) + '" font-family="Courier New" font-size="10" fill="#7a007a">' + esc(lbl.s) + '</text>');
    } else if (h === 'junction') {
      const p = pts(nd)[0];
      if (p) { track(p[0], p[1]); parts.push('<circle cx="' + p[0] + '" cy="' + p[1] + '" r="3" fill="#111"/>'); }
    }
  }
  const w = maxX + pad * 2, ht = maxY + pad * 2;
  const body = parts.map((x) => '  ' + x).join('\n');
  return '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="' + ht + '" viewBox="' + (-pad) + ' ' + (-pad) + ' ' + w + ' ' + ht + '">\n' +
    '  <rect x="' + -pad + '" y="' + -pad + '" width="' + w + '" height="' + ht + '" fill="#ffffff"/>\n' + body + '\n</svg>\n';
}

if (process.argv[1] && process.argv[1].endsWith('render.mjs')) {
  const inF = process.argv[2], outF = process.argv[3];
  fs.writeFileSync(outF, bdfToSvg(fs.readFileSync(inF, 'latin1')), 'utf8');
  console.log('rendered ' + inF + ' -> ' + outF);
}
