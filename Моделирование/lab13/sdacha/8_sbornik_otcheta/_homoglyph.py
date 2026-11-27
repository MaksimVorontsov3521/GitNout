# -*- coding: utf-8 -*-
# Homoglyph audit of the delivered notes. A token that mixes Cyrillic and Latin
# letters is a typing defect, not an identifier: "MAX+plus" or "lab13_report"
# are pure Latin, "C::B" is punctuation-separated, but "предел" + chr(0x0065) is a Cyrillic
# word with a Latin e inside it. Found by accident in 0_zadanie_i_otchet.
import os, re, unicodedata
HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
CYR = r"Ѐ-ӿ"
LAT = r"A-Za-z"
MIXED = re.compile(r"(?:[{c}][{l}]|[{l}][{c}])".format(c=CYR, l=LAT))
WORD = re.compile(r"[{c}{l}\d_\-\.]+".format(c=CYR, l=LAT))
rows = []
for root, dirs, files in os.walk(SD):
    dirs[:] = [d for d in dirs if d != "__pycache__"]
    for fn in files:
        if not fn.lower().endswith((".txt", ".json", ".zipiska")):
            continue
        p = os.path.join(root, fn)
        try:
            t = open(p, encoding="utf-8", errors="strict").read()
        except Exception as e:
            rows.append((os.path.relpath(p, SD), 0, "UNDECODABLE " + str(e)[:40], ""))
            continue
        for i, line in enumerate(t.split("\n"), 1):
            for w in WORD.findall(line):
                if MIXED.search(w):
                    rows.append((os.path.relpath(p, SD), i, w, line.strip()[:110]))
print("script-mixed tokens in delivered notes: %d" % len(rows))
seen = {}
for f, i, w, ctx in rows:
    seen.setdefault(w, []).append("%s:%d" % (f, i))
for w, locs in sorted(seen.items(), key=lambda kv: -len(kv[1])):
    print("   %-22s %d occurrence(s)  %s" % (ascii(w), len(locs), ", ".join(locs[:4])))
# same check on the report itself, since the docx prose could carry it too
from docx import Document
d = Document(os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx"))
hits = []
for q in d.paragraphs:
    for w in WORD.findall(q.text):
        if MIXED.search(w):
            hits.append((w, q.text[:90]))
for tb in d.tables:
    for r in tb.rows:
        for c in r.cells:
            for w in WORD.findall(c.text):
                if MIXED.search(w):
                    hits.append((w, c.text[:90]))
print("\nscript-mixed tokens in the DOCX: %d" % len(hits))
for w, ctx in hits[:20]:
    print("   %-22s | %s" % (ascii(w), ctx))
