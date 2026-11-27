# -*- coding: utf-8 -*-
# Exact accounting of what the conversion drops, independent of text order: subtract the
# PDF character multiset from the docx one. Ordering effects (a paragraph continued on the
# next page behind a table) make a CONTIGUITY test report a loss that does not exist; a
# multiset difference cannot.
import re, zlib, json, os
from collections import Counter
from docx import Document
# DOCX comes from _find() above; the absolute path that stood here made the delivered
# copy read the report out of the authoring tree, which is exactly what the
# delivery-relative resolver exists to prevent.
# Same class of defect as in _pdf_live.py: this check read lab13/render_live/, an older
# directory, so it compared the CURRENT docx against a STALE PDF - a hybrid of two builds
# that shows up as a few dozen phantom lost characters. The path is now the converter's own
# output, and the guard refuses to compare across builds at all.
import os as _os
_HERE = _os.path.dirname(_os.path.abspath(__file__))
_UP = _os.path.dirname(_HERE)
def _find(*rels):
    for base in (_UP, _HERE, _os.path.dirname(_UP)):
        p = _os.path.normpath(_os.path.join(base, *rels))
        if _os.path.exists(p):
            return p
    return None
PDF = _find("evidence", "lab13_report.pdf") or _find("lab13", "evidence", "lab13_report.pdf")
DOCX_PATH = _find("lab13_report.docx") or _find("0_zadanie_i_otchet", "lab13_report.docx")
if DOCX_PATH is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
if PDF is None:
    print("NOT RUNNABLE INSIDE THE DELIVERY: the PDF is a derivative artifact and is "
        "deliberately not shipped; reproduce it by the commands in 6_proverki/ZIPISKA.txt. "
          "Exit 3 = not applicable by construction.")
    raise SystemExit(3)
OUT_PATH = _find("evidence", "render_multiset.json") or _os.path.join(_HERE, "evidence", "render_multiset.json")
if __import__("os").path.getmtime(PDF) < __import__("os").path.getmtime(DOCX_PATH):
    raise SystemExit("STALE PDF: it predates the docx, so the multiset would mix two builds")
raw = open(PDF, "rb").read()
objs = {}
for m in re.finditer(rb"(\d+)\s+0\s+obj(.*?)endobj", raw, re.S):
    body = m.group(2)
    sm = re.search(rb"stream\r?\n(.*?)endstream", body, re.S)
    if sm:
        data = sm.group(1)
        try: data = zlib.decompress(data)
        except Exception: pass
        objs[int(m.group(1))] = (body[:sm.start()], data)
    else:
        objs[int(m.group(1))] = (body, None)
def cmap(fn):
    h, _ = objs[fn]
    m = re.search(rb"ToUnicode\s+(\d+)\s+0\s+R", h)
    if not m: return {}
    _, su = objs[int(m.group(1))]
    t = {}
    for bf in re.finditer(rb"beginbfchar(.*?)endbfchar", su, re.S):
        for pp in re.finditer(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", bf.group(1)):
            t[int(pp.group(1), 16)] = "".join(chr(int(pp.group(2)[j:j+4], 16)) for j in range(0, len(pp.group(2)), 4))
    for br in re.finditer(rb"beginbfrange(.*?)endbfrange", su, re.S):
        for tr in re.finditer(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", br.group(1)):
            lo, hi, base = int(tr.group(1), 16), int(tr.group(2), 16), int(tr.group(3), 16)
            for c in range(lo, hi+1): t[c] = chr(base + c - lo)
    return t
fdict = objs[int(re.search(r"Font\s+(\d+)\s+0\s+R", objs[215][0].decode("latin-1")).group(1))][0].decode("latin-1")
names = dict(re.findall(r"/(\w+)\s+(\d+)\s+0\s+R", fdict))
maps = {n: cmap(int(v)) for n, v in names.items()}
pdf_buf = []
for n, (h, s) in sorted(objs.items()):
    if s is None or (b"TJ" not in s and b"Tj" not in s): continue
    font = None
    for tm in re.finditer(rb"/(\w+)\s+[\d.]+\s+Tf|\[(?:[^\]]*)\]\s*TJ?|\((?:[^()\\]|\\.)*\)\s*Tj?", s):
        tok = tm.group(0)
        f = re.match(rb"/(\w+)\s+[\d.]+\s+Tf", tok)
        if f: font = f.group(1).decode(); continue
        mp = maps.get(font) or {}
        for part in re.finditer(rb"<([0-9A-Fa-f\s]+)>|\((?:[^()\\]|\\.)*\)", tok):
            bs = bytes.fromhex(re.sub(rb"\s", b"", part.group(1)).decode("ascii")) if part.group(1) is not None else re.sub(rb"\\([()\\])", rb"\1", part.group(0)[1:-1])
            pdf_buf.append("".join(mp.get(b, "" if b > 127 else chr(b)) for b in bs))
d = Document(DOCX_PATH)
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]

# Counter iterates KEYS, so "strip("".join(pdf_chars))" would have compared a set of
# distinct characters against a multiset of all of them - that mistake produced a
# nonsense "188 non-space PDF chars". Build the PDF text as a string first.
pdf_text = "".join(pdf_buf)
strip = lambda c: re.sub(r"\s+", "", c)
dn = Counter(strip("".join(units)))
pn = Counter(strip(pdf_text))
print("PDF text length: raw %d, non-space %d" % (len(pdf_text), sum(pn.values())))
lost = dn - pn
print("docx non-space chars: %d | PDF non-space chars: %d" % (sum(dn.values()), sum(pn.values())))
print("characters present in the docx and absent from the PDF text: %d" % sum(lost.values()))
groups = {"digit": lambda c: c.isdigit(), "latin": lambda c: c.isascii() and c.isalpha(),
          "cyrillic": lambda c: "\u0400" <= c <= "\u04FF", "punct": lambda c: not c.isalnum()}
for g, pred in groups.items():
    tot = sum(v for k, v in lost.items() if pred(k))
    print("   %-9s %d" % (g, tot))
print("\ntop 24 lost characters: " + ", ".join("%r:%d" % (k, v) for k, v in lost.most_common(24)))
# how many SEQ caption numbers does that account for?
caps = [u for u in units if re.match(r"^(Таблица|Рисунок) \d+ —", u)]
print("\ncaption units matching '^(Таблица|Рисунок) N —': %d" % len(caps))
print("digits those captions contribute: %d" % sum(len(re.findall(r"\d+", c.split("—")[0])) for c in caps))
listing = [u for u in units if re.match(r"^[-–—=_*]{6,}", u) or re.search(r"\b(std_logic|rising_edge|begin|end|process|signal|architecture|library|when|else|case)\b", u)]
print("units that look like VHDL/listing: %d, non-space chars %d" % (len(listing), sum(len(strip(x)) for x in listing)))
json.dump({"docx_nonspace": sum(dn.values()), "pdf_nonspace": sum(pn.values()),
           "lost_total": sum(lost.values()),
           "lost_by_class": {g: sum(v for k, v in lost.items() if p(k)) for g, p in groups.items()},
           "lost_top": {k: v for k, v in lost.most_common(40)},
           "caption_units": len(caps), "listing_units": len(listing)},
          open(OUT_PATH, "w", encoding="utf-8"),
          indent=2, ensure_ascii=False)
print("\nwrote lab13/evidence/render_multiset.json")
