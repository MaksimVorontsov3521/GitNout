# -*- coding: utf-8 -*-
# Text-only render fidelity check. The earlier attempt failed for two reasons
# found by diagnosis: the page /Font dictionary is an INDIRECT object, and the
# fonts are simple (1-byte codes), not 2-byte Identity-H CIDs. Both handled.
import os, re, zlib
from docx import Document

HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
PIN = os.path.join(HERE, "_render_pin")
DOCX = os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx")
PDF = os.path.join(PIN, "lab13_report_pinned.pdf")
os.makedirs(PIN, exist_ok=True)
if not os.path.exists(PDF):
    raise SystemExit("НЕТ PDF для разбора. Сначала конверсия сторонним движком (LibreOffice Kit):" + os.linesep + "  & <node> <cli> convert --input " + DOCX + " --output " + PDF)
pdf = open(PDF, "rb").read()
objs = {}
for m in re.finditer(rb"(?<!\d)(\d+)\s+0\s+obj(.*?)\bendobj", pdf, re.S):
    objs[int(m.group(1))] = m.group(2)

def split(body):
    i = body.find(b"stream")
    if i < 0: return body, None
    j = i + 6
    while j < len(body) and body[j:j + 1] in (b"\r", b"\n"): j += 1
    k = body.rfind(b"endstream")
    return body[:i], (body[j:k] if k >= j else None)

def flat(num):
    body = objs.get(num)
    if body is None: return ""
    d, raw = split(body)
    if raw is None: return d.decode("latin1", "replace")
    try: data = zlib.decompress(raw)
    except Exception: data = b""
    return d.decode("latin1", "replace") + " |STREAM " + str(len(data)) + "B| " + data.decode("latin1", "replace")

def parse_cmap(t):
    cmap = {}
    for blk in re.findall(r"beginbfchar(.*?)endbfchar", t, re.S):
        for a, b in re.findall(r"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", blk):
            cmap[int(a, 16)] = "".join(chr(int(b[i:i + 4], 16)) for i in range(0, len(b), 4) if len(b[i:i + 4]) == 4)
    for blk in re.findall(r"beginbfrange(.*?)endbfrange", t, re.S):
        for a, b, c in re.findall(r"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[^>]*>|\[[^\]]*\])", blk):
            lo, hi = int(a, 16), int(b, 16)
            if c.startswith("["):
                items = re.findall(r"<([0-9A-Fa-f]+)>", c)
                for n, it in enumerate(items):
                    if lo + n <= hi:
                        cmap[lo + n] = "".join(chr(int(it[i:i + 4], 16)) for i in range(0, len(it), 4) if len(it[i:i + 4]) == 4)
            else:
                base = int(re.sub(r"[^0-9A-Fa-f]", "", c), 16)
                for cid in range(lo, hi + 1):
                    cmap[cid] = chr(base + (cid - lo))
    return cmap

# ---- fonts: code width from /Type0 vs simple, ToUnicode resolved indirectly ----
fonts = {}
for num, body in objs.items():
    d, _ = split(body)
    if not re.search(rb"/BaseFont", d): continue
    width = 2 if b"/Type0" in d else 1
    bf = re.search(rb"/BaseFont\s*/([A-Za-z0-9+\-_,.]+)", d)
    enc = re.search(rb"/Encoding\s*/([A-Za-z0-9\-]+)", d)
    cm = {}
    m = re.search(rb"/ToUnicode\s+(\d+)\s+0\s+R", d)
    if m:
        td, traw = split(objs.get(int(m.group(1)), b""))
        try: cm = parse_cmap(zlib.decompress(traw).decode("latin1", "replace")) if traw else {}
        except Exception: cm = {}
    fonts[num] = {"width": width, "cmap": cm,
                  "base": bf.group(1).decode("latin1") if bf else "?",
                  "enc": enc.group(1).decode("latin1") if enc else "-"}
print("font objects: %d" % len(fonts))
shapes = {}
for n, f in fonts.items():
    shapes.setdefault((f["width"], f["enc"], len(f["cmap"]) > 0), 0)
    shapes[(f["width"], f["enc"], len(f["cmap"]) > 0)] += 1
for k, v in sorted(shapes.items(), key=lambda x: str(x[0])):
    print("   width=%d enc=%-16s hasToUnicode=%-5s count=%d" % (k[0], k[1], k[2], v))

def resolve(text, key):
    m = re.search(r"/" + key + r"\s*(<<.*?>>|\d+\s+0\s+R)", text, re.S)
    if not m: return None
    s = m.group(1)
    if s.startswith("<<"): return s
    n = re.search(r"(\d+)", s)
    return flat(int(n.group(1))) if n else None

WINANSI = {}
def dec_literal(s, f):
    # simple fonts here carry /Encoding; decode bytes via latin1 then remap nothing
    return s

def unesc(s):
    out, i = "", 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n in "01234567":
                oc, j = "", i + 1
                while j < len(s) and len(oc) < 3 and s[j] in "01234567":
                    oc += s[j]; j += 1
                out += chr(int(oc, 8)); i = j; continue
            out += {"n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f", "(": "(", ")": ")", "\\": "\\"}.get(n, n)
            i += 2; continue
        out += c; i += 1
    return out

# Strings appear as array operands in TJ, so a string is NEVER required to be
# followed by a show operator. Token kinds: font select, positioning, string.
OP = re.compile(r'''/([A-Za-z0-9_.]+)\s+[\d.]+\s+Tf'''
                r'''|\b(Td|TD|T\*|ET|TP|TL|Tc|Tw|Tz|Ts)\b'''
                r'''|(<[0-9A-Fa-f\s]+>)'''
                r'''|(\((?:[^()\\]|\\.)*\))''')

pages = [(n, split(b)[0]) for n, b in sorted(objs.items()) if re.search(rb"/Type\s*/Page(?!s)", split(b)[0])]
print("\npages: %d" % len(pages))
res_cache = {}
page_texts = []
for pn, d in pages:
    dt = d.decode("latin1", "replace")
    rt = dt
    if "/Resources" not in dt:
        p = re.search(r"/Parent\s+(\d+)\s+0\s+R", dt)
        if p: rt = flat(int(p.group(1)))
    rtext = resolve(rt, "Resources") or ""
    if rtext not in res_cache:
        ft = resolve(rtext, "Font") or ""
        tbl = {}
        for name, num in re.findall(r"/([A-Za-z0-9_.]+)\s+(\d+)\s+0\s+R", ft):
            tbl[name] = int(num)
        res_cache[rtext] = tbl
    ftab = res_cache[rtext]
    # Contents must be taken as an OBJECT NUMBER from the page dict, never by
    # resolving the stream object and reading its first integer - that first
    # integer is /Length's own reference, which is what made every page empty.
    cnums = []
    mc = re.search(r"/Contents\s*(\d+)\s+0\s+R", dt)
    ma = re.search(r"/Contents\s*\[([^\]]*)\]", dt, re.S)
    if mc: cnums.append(int(mc.group(1)))
    if ma: cnums += [int(x) for x in re.findall(r"(\d+)\s+0\s+R", ma.group(1))]
    blob = b""
    for cn in cnums:
        cd, craw = split(objs.get(cn, b""))
        if craw:
            try: blob += zlib.decompress(craw)
            except Exception: blob += craw
    t = blob.decode("latin1", "replace")
    cur = {"width": 1, "cmap": {}}
    out = []
    for tok in OP.finditer(t):
        fname, pop, hx, lit = tok.group(1), tok.group(2), tok.group(3), tok.group(4)
        if fname is not None:
            cur = fonts.get(ftab.get(fname, -1), cur); continue
        if pop is not None:
            if pop in ("Td", "TD", "T*", "ET", "TP"): out.append("\n")
            continue
        if hx is not None:
            s = re.sub(r"[^0-9A-Fa-f]", "", hx)
            w = cur["width"] * 2
            if len(s) % w: s = "0" * (w - len(s) % w) + s
            out.append("".join(cur["cmap"].get(int(s[i:i + w], 16), "") for i in range(0, len(s), w)))
        elif lit is not None:
            out.append(unesc(lit[1:-1]))
    page_texts.append("".join(out))

full = "\n".join(page_texts)
print("extracted chars: %d" % len(full))
print("page 1 head: %r" % page_texts[0][:150])
norm = lambda s: re.sub(r"\s+", " ", s).strip()
hay = norm(full)
d = Document(DOCX)
paras = [q.text for q in d.paragraphs if q.text.strip()]
cells = [c.text for tb in d.tables for r in tb.rows for c in r.cells if c.text.strip()]
missing = [s for s in paras + cells if norm(s) and norm(s) not in hay]
print("\ndocx units checked: %d (paragraphs %d + table cells %d)" % (len(paras) + len(cells), len(paras), len(cells)))
print("NOT FOUND in the rendered PDF: %d" % len(missing))
for s in missing[:10]: print("   " + repr(norm(s)[:100]))
open(os.path.join(PIN, "pdf_text.txt"), "w", encoding="utf-8").write(full)
print("\nVERDICT: %s" % ("EVERY PARAGRAPH AND CELL SURVIVES THE FOREIGN RENDER" if not missing else "SEE ABOVE"))
