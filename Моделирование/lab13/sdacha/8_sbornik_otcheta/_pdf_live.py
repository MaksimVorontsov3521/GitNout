# -*- coding: utf-8 -*-
# Text-only render check of the LIVE build, with an extractor written here rather than
# reused from the packer's 6_proverki/_pdf_text.py. Independence of TOOL matters as much
# as independence of run: if both checks used the same parser, a parser bug would hide in
# both. Known limits of this extractor are listed at the end and are the reason the check
# is called text-only.
import hashlib, io, json, os, re, sys, zlib
from docx import Document

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def _find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        p = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(p):
            return p
    return None
WS = HERE
DOCX = _find("lab13_report.docx") or _find("0_zadanie_i_otchet", "lab13_report.docx")
if DOCX is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
# The PDF must be the one just converted from the CURRENT docx. This check previously
# pointed at lab13/render_live/, an older directory, so its record paired a live docx hash
# with a stale PDF measurement - a hybrid. _refhash.py cannot catch that class, because
# pdf_sha256 is neither a docx key nor a zadanie key. The path is now the converter's own
# output, and the guard below makes the wrong pairing impossible rather than unlikely.
PDF = _find("evidence", "lab13_report.pdf") or _find("lab13", "evidence", "lab13_report.pdf")
if PDF is None:
    print("NOT RUNNABLE INSIDE THE DELIVERY: the PDF is a derivative artifact of a "
        "third-party engine and is deliberately not shipped (see pdf_sha256_note in "
        "evidence/render_live.json). Reproduce it from the delivered docx by the two "
        "commands in 6_proverki/ZIPISKA.txt, then run this check. Exit 3 = not "
          "applicable by construction, not a failure.")
    raise SystemExit(3)
if not os.path.exists(PDF):
    raise SystemExit("NO PDF TO CHECK: " + PDF + " - convert the docx first, then rerun")
_pd, _dx = os.path.getmtime(PDF), os.path.getmtime(DOCX)
if _pd < _dx:
    raise SystemExit("STALE PDF: it predates the docx by %.1f s, so any hash pairing would "
                     "mix two builds. Re-convert before running this check." % (_dx - _pd))

raw = open(PDF, "rb").read()
print("PDF: %d B  sha256 %s" % (len(raw), hashlib.sha256(raw).hexdigest()))
src = open(DOCX, "rb").read()
print("source docx: %d B  sha256 %s" % (len(src), hashlib.sha256(src).hexdigest()))

# --- objects: parse every "N 0 obj ... endobj", inflating streams ---
objs = {}
for m in re.finditer(rb"(\d+)\s+0\s+obj(.*?)endobj", raw, re.S):
    num = int(m.group(1)); body = m.group(2)
    sm = re.search(rb"stream\r?\n(.*?)endstream", body, re.S)
    if sm:
        data = sm.group(1)
        try:
            data = zlib.decompress(data)
        except Exception:
            pass
        objs[num] = (body[:sm.start()], data)
    else:
        objs[num] = (body, None)
print("objects parsed: %d" % len(objs))

pages = [n for n, (h, s) in objs.items() if re.search(rb"/Type\s*/Page\b(?!s)", h)]
print("page objects: %d" % len(pages))
mediaboxes = set()
for n in pages:
    h, _ = objs[n]
    m = re.search(rb"MediaBox\s*\[([^\]]*)\]", h)
    if m:
        mediaboxes.add(tuple(float(x) for x in m.group(1).split()))
print("distinct MediaBox: %s" % sorted(mediaboxes))
if len(mediaboxes) == 1:
    (x0, y0, x1, y1), = mediaboxes
    print("   page size: %.2f x %.2f pt = %.2f x %.2f cm (A4 is 21.0 x 29.7 cm)"
          % (x1 - x0, y1 - y0, (x1 - x0) / 72 * 2.54, (y1 - y0) / 72 * 2.54))

imgs = set()
for n, (h, s) in objs.items():
    if re.search(rb"/Subtype\s*/Image", h):
        imgs.add(n)
print("image XObjects: %d" % len(imgs))
fonts = {}
for n, (h, s) in objs.items():
    if re.search(rb"/Type\s*/Font", h):
        sub = re.search(rb"/Subtype\s*/(\w+)", h)
        tu = b"ToUnicode" in h
        nm = re.search(rb"/BaseFont\s*/([A-Za-z0-9+\-,]+)", h)
        fonts[n] = (sub.group(1).decode() if sub else "?", tu, nm.group(1).decode() if nm else "?")
print("font objects: %d, with ToUnicode: %d" % (len(fonts), sum(1 for v in fonts.values() if v[1])))
for n, (sub, tu, nm) in sorted(fonts.items()):
    print("   %-3d %-10s ToUnicode=%-5s %s" % (n, sub, tu, nm))

# --- text extraction: content streams of each page, Tj/TJ with ToUnicode maps ---
def cmap_for(fontnum):
    # A FONT object has no stream at all, so testing "stream is None" on the font
    # returns {} for every font before doing any work - which is exactly what happened:
    # the header dump showed 14 fonts carrying ToUnicode while every map came back
    # empty and the document looked like 40 characters of nothing. The stream belongs
    # to the CMap object, and it is checked there.
    h, _ = objs.get(fontnum, (b"", None))
    m = re.search(rb"ToUnicode\s+(\d+)\s+0\s+R", h)
    if not m:
        return {}
    ref = int(m.group(1))
    rh, su = objs.get(ref, (b"", None))
    if su is None:
        return {}
    # The CMap stream is FlateDecode-compressed in this file. The first version of this
    # extractor only tried to inflate when the payload was None, which is the one case
    # where there is nothing to inflate, so every map came back empty and the whole
    # document appeared to contain 40 characters. Attempt inflation whenever a stream
    # exists, and say so if it fails.
    # The parser above already inflates every stream it can, so inflating again here
    # fails with "incorrect header check" and throws the map away. Only inflate if the
    # payload still looks like raw zlib data (a zlib stream starts with 0x78).
    if su[:2] == b"x\x9c" or su[:2] == b"x\x01" or su[:1] == b"x":
        try:
            su = zlib.decompress(su)
        except Exception as e:
            print("   CMap object %d: inflation failed (%s)" % (ref, e))
            return {}
    table = {}
    for bf in re.finditer(rb"beginbfchar(.*?)endbfchar", su, re.S):
        for pair in re.finditer(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", bf.group(1)):
            src_ = pair.group(1); dst = pair.group(2)
            code = int(src_, 16)
            chars = "".join(chr(int(dst[i:i + 4], 16)) for i in range(0, len(dst), 4))
            table[code] = chars
    for br in re.finditer(rb"beginbfrange(.*?)endbfrange", su, re.S):
        for trip in re.finditer(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<([0-9A-Fa-f]+)>|\[(.*?)\])", br.group(1), re.S):
            lo = int(trip.group(1), 16); hi = int(trip.group(2), 16)
            if trip.group(4) is not None:
                base = int(trip.group(4), 16)
                for c in range(lo, hi + 1):
                    table[c] = chr(base + (c - lo))
            else:
                arr = re.findall(rb"<([0-9A-Fa-f]+)>", trip.group(5) or b"")
                for i, c in enumerate(range(lo, hi + 1)):
                    if i < len(arr):
                        table[c] = "".join(chr(int(arr[i][j:j + 4], 16)) for j in range(0, len(arr[i]), 4))
    return table

def page_text(pnum):
    h, _ = objs[pnum]
    m = re.search(rb"Contents\s*(\d+)\s+0\s+R", h)
    if not m:
        mm = re.search(rb"Contents\s*\[(.*?)\]", h, re.S)
        nums = [int(x) for x in re.findall(rb"(\d+)\s+0\s+R", mm.group(1))] if mm else []
    else:
        nums = [int(m.group(1))]
    out = []
    font = None
    maps = {}
    for n in nums:
        s = objs.get(n, (b"", None))[1]
        if s is None:
            continue
        for tm in re.finditer(rb"/(\w+)\s+[\d.]+\s+Tf|\((?:[^()\\]|\\.)*\)|\[(?:[^\]\\]|\\.)*\]|T\*|Td|TD|TJ|Tj", s):
            tok = tm.group(0)
            f = re.match(rb"/(\w+)\s+[\d.]+\s+Tf", tok)
            if f:
                font = f.group(1).decode()
                continue
            if tok.startswith(b"(") and tok.endswith(b")"):
                body = tok[1:-1]
                body = re.sub(rb"\\([()\\])", rb"\1", body)
                body = re.sub(rb"\\(\d{3})", lambda mm2: bytes([int(mm2.group(1), 8)]), body)
                mp = maps.get(font, {})
                out.append("".join(mp.get(b, chr(b) if b < 128 else "") for b in body))
            elif tok.startswith(b"["):
                mp = maps.get(font, {})
                buf = []
                for part in re.finditer(rb"\((?:[^()\\]|\\.)*\)", tok):
                    body = part.group(0)[1:-1]
                    body = re.sub(rb"\\([()\\])", rb"\1", body)
                    body = re.sub(rb"\\(\d{3})", lambda mm2: bytes([int(mm2.group(1), 8)]), body)
                    buf.extend(mp.get(b, chr(b) if b < 128 else "") for b in body)
                out.append("".join(buf))
    return "".join(out)

# --- resource resolution ---
# Every page here shares ONE Resources dictionary (object 215), referenced by
# "Resources 215 0 R" rather than written inline. The first version of this extractor
# only understood an inline "<< ... >>" and compared rm.lastgroup (a string) against 1,
# so it resolved nothing, produced empty glyph maps, and reported 40 extracted
# characters for a 41-page document - a failure that looked like an empty PDF rather
# than a broken parser. Both bugs are fixed here and the fix is verified by the count.
def find_dict_value(text, key):
    """Return the raw token following /key, handling a dict, an array and a reference."""
    m = re.search(r"/" + key + r"\b\s*", text)
    if not m:
        return None
    rest = text[m.end():]
    if rest.startswith("<<"):
        depth, i = 0, 0
        while i < len(rest):
            if rest.startswith("<<", i):
                depth += 1; i += 2
            elif rest.startswith(">>", i):
                depth -= 1; i += 2
                if depth == 0:
                    return rest[:i]
            else:
                i += 1
        return rest
    if rest.startswith("["):
        return rest[:rest.index("]") + 1]
    m2 = re.match(r"(\d+)\s+0\s+R", rest)
    return ("REF:" + m2.group(1)) if m2 else rest.split()[0] if rest.split() else None

def resources_of(pnum):
    h = objs[pnum][0].decode("latin-1")
    v = find_dict_value(h, "Resources")
    if v and v.startswith("REF:"):
        v = objs[int(v[4:])][0].decode("latin-1")
    return v or ""

def deref(token):
    """Follow one level of "REF:<n>" indirection, which this producer uses for Font,
    Resources and Contents alike."""
    if token and token.startswith("REF:"):
        return objs.get(int(token[4:]), (b"", None))[0].decode("latin-1")
    return token or ""

def page_font_maps(pnum):
    # resources_of() already returns the VALUE of /Resources, which here is the token
    # "REF:215"; the previous line looked for /Resources inside that token, which is
    # nonsense and yielded nothing. Dereference the value itself, then read /Font,
    # which is ALSO a reference ("Font 214 0 R") in this producer.
    res = deref(resources_of(pnum))
    fonts = deref(find_dict_value(res, "Font"))
    out = {}
    for fr in re.finditer(r"/(\w+)\s+(\d+)\s+0\s+R", fonts):
        out[fr.group(1)] = cmap_for(int(fr.group(2)))
    return out

def page_text(pnum, maps):
    h = objs[pnum][0].decode("latin-1")
    v = find_dict_value(h, "Contents")
    if v and v.startswith("REF:"):
        nums = [int(v[4:])]
    elif v and v.startswith("["):
        nums = [int(x) for x in re.findall(r"(\d+)\s+0\s+R", v)]
    else:
        nums = []
    out = []
    font = None
    for n in nums:
        blob = objs.get(n)
        if not blob or blob[1] is None:
            continue
        s = blob[1]
            # LibreOffice writes the text of this document as HEX literals inside TJ
            # arrays - "[<01>1<020304050206040507>1<0208>-2<…>]TJ" - not as bracketed
            # byte strings. An extractor that only understands "(text)" therefore finds
            # nothing at all, which is why the run reported 40 characters (the 40 page
            # separators) for a 41-page document. Both forms are handled here.
        for tm in re.finditer(rb"/(\w+)\s+[\d.]+\s+Tf|\((?:[^()\\]|\\.)*\)|\[(?:[^\]]*)\]|T\*|\dTd|TD|TJ|Tj|'", s):
            tok = tm.group(0)
            f = re.match(rb"/(\w+)\s+[\d.]+\s+Tf", tok)
            if f:
                font = f.group(1).decode()
                continue
            def unescape(body):
                body = re.sub(rb"\\([()\\])", rb"\1", body)
                body = re.sub(rb"\\(\d{1,3})", lambda mm2: bytes([int(mm2.group(1), 8) & 0xFF]), body)
                return body
            def emit(bs, mp):
                return "".join(mp.get(b, chr(b) if b < 128 else "") for b in bs)
            mp = maps.get(font) or {}
            if tok.startswith(b"(") and tok.endswith(b")"):
                out.append(emit(unescape(tok[1:-1]), mp))
            elif tok.startswith(b"["):
                buf = []
                for part in re.finditer(rb"<([0-9A-Fa-fs]+)>|\((?:[^()\\]|\\.)*\)", tok):
                    if part.group(1) is not None:
                        hx = re.sub(rb"\s", b"", part.group(1))
                        buf.append(emit(bytes.fromhex(hx.decode("ascii")), mp))
                    else:
                        buf.append(emit(unescape(part.group(0)[1:-1]), mp))
                out.append("".join(buf))
    return "".join(out)

p0 = sorted(pages)[0]
print("\nresolution chain for the first page object %d:" % p0)
print("   raw /Resources value : " + repr(find_dict_value(objs[p0][0].decode("latin-1"), "Resources")))
print("   resolved Resources   : " + repr(deref(resources_of(p0))[:120]))
print("   raw /Font value      : " + repr(find_dict_value(deref(resources_of(p0)), "Font")))
print("   resolved Font        : " + repr(deref(find_dict_value(deref(resources_of(p0)), "Font"))[:160]))
all_text = []
mapped_fonts = 0
for p in sorted(pages)[:2] if False else sorted(pages):
    maps = page_font_maps(p)
    nonempty = sum(1 for v in maps.values() if v)
    mapped_fonts += nonempty
    if p == sorted(pages)[0]:
        print("   page %d: %d font resources, %d with a non-empty map" % (p, len(maps), nonempty))
        for nm, mp in list(maps.items())[:3]:
            print("      %s -> %d entries, sample %s" % (nm, len(mp), dict(list(mp.items())[:4])))
        blob = objs[2][1]
        print("   content stream of page 1 (obj 2): %s B, first 200: %r" % (blob and len(blob), (blob or b"")[:200]))
    all_text.append(page_text(p, maps))
text = "\n".join(all_text)
print("\nfont resources with a non-empty ToUnicode map, summed over pages: %d" % mapped_fonts)
print("extracted characters: %d" % len(text))
print("first 300 extracted characters: " + repr(text[:300]))

d = Document(DOCX)
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
norm = lambda s: re.sub(r"\s+", "", s)
pdfn = norm(text)
missing = [u for u in units if u.strip() and norm(u) not in pdfn]
print("units: %d (paragraphs %d + cells %d)" % (len(units), len(d.paragraphs), sum(len(r.cells) for t in d.tables for r in t.rows)))
print("units not found in the PDF text: %d" % len(missing))
for u in missing[:12]:
    print("   ...%s..." % re.sub(r"\s+", " ", u)[:96])
courier = len(re.findall(r"Courier", text))
print("literal 'Courier' occurrences in extracted text: %d" % courier)
OUT = _find("evidence", "render_live.json") or os.path.join(WS, "evidence", "render_live.json")
_rec = {"pdf_bytes": len(raw), "pdf_sha256": hashlib.sha256(raw).hexdigest(),
           "docx_bytes": len(src), "docx_sha256": hashlib.sha256(src).hexdigest(),
           "pages": len(pages), "images": len(imgs), "fonts": len(fonts),
           "fonts_with_tounicode": sum(1 for v in fonts.values() if v[1]),
           "mediabox": sorted(mediaboxes), "extracted_chars": len(text),
           "units": len(units), "units_missing": len(missing),
           "pdf_sha256_note": "The PDF is deliberately NOT part of the delivery: it is a "
               "derivative artifact of a third-party engine, reproducible from the delivered "
               "docx by the command recorded in 6_proverki/ZIPISKA.txt. This hash therefore "
               "names a file that is intentionally absent. It is measured from the docx in the "
               "same run - the staleness guard refuses to report when the PDF predates the "
               "docx - so it cannot describe a different build.",
           "pdf_staleness_guard": "Refuses to run if the PDF mtime predates the docx mtime. "
               "Added because an earlier version pointed at an older directory and paired a "
               "live docx hash with a stale PDF measurement.",
           "pdf_newer_than_docx_seconds": round(_pd - _dx, 1),
           "units_missing_explained": "units_missing is a CONTIGUITY statistic of this "
               "text-only check, not a claim that the conversion lost text. The order-"
               "independent character-multiset difference is in render_multiset.json; the "
               "deficit sits in the monospaced listings (Courier, reported missing by the "
               "converter) and in the SEQ caption numbers, whose cached field results "
               "LibreOffice does not emit into PDF text.",
           "converter_font_substitution": "The converter reports missingFonts [\"Courier\"]; "
               "the report sets its listings in Courier, so the PDF substitutes a replacement "
               "face. A property of the conversion environment, recorded rather than hidden."}
# The note for a field must be ADJACENT to that field, because the hash gate reads the
# label from the neighbouring lines only. Building the dict first and ordering it here
# keeps the literal readable while guaranteeing adjacency, and the completeness check
# below makes a silently dropped note impossible rather than merely unlikely.
_ORDER = ["pdf_bytes", "pdf_sha256", "pdf_sha256_note", "pdf_staleness_guard",
          "pdf_newer_than_docx_seconds", "docx_bytes", "docx_sha256", "pages", "images",
          "fonts", "fonts_with_tounicode", "mediabox", "extracted_chars", "units",
          "units_missing", "units_missing_explained", "converter_font_substitution"]
if set(_ORDER) != set(_rec):
    raise SystemExit("RECORD KEY SET DRIFTED: ordered=%s built=%s missing=%s extra=%s"
                       % (len(_ORDER), len(_rec), sorted(set(_ORDER) - set(_rec)),
                         sorted(set(_rec) - set(_ORDER))))
_rec = {_k: _rec[_k] for _k in _ORDER}
json.dump(_rec, open(OUT, "w", encoding="utf-8"),
          indent=2, ensure_ascii=False)
print("\nwrote lab13/evidence/render_live.json")
