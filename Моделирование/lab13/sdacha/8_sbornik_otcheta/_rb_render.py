# -*- coding: utf-8 -*-
# What does the report claim about the PDF / render layer, verbatim? If a sentence
# presents a render result as applying to the delivered build while the render evidence
# measured a 421182-byte build that no longer exists, that is a false claim in the
# deliverable - the same class as the deleted heading, and no XML checker would see it.
import re
from docx import Document
import os
HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        p = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(p):
            return p
    return None
DOC = find("lab13_report.docx") or find("0_zadanie_i_otchet", "lab13_report.docx")
if DOC is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
d = Document(DOC)
paras = [(i, p.text, p.style.name) for i, p in enumerate(d.paragraphs)]
cells = []
for ti, t in enumerate(d.tables):
    for ri, r in enumerate(t.rows):
        for ci, c in enumerate(r.cells):
            cells.append(("T%d r%d c%d" % (ti, ri, ci), c.text))
PAT = re.compile(r"PDF|рендер|Render|LibreOffice|конвертаци|страниц|Courier|моноширин|визуальн|картин|рисунок в|битмап", re.I)
print("=== paragraphs mentioning the render layer ===")
n = 0
for i, t, st in paras:
    if PAT.search(t):
        n += 1
        print("\n[p%03d %s]\n   %s" % (i, st, re.sub(r"\s+", " ", t)))
print("\nparagraph hits: %d" % n)
print("\n=== table cells mentioning the render layer ===")
m = 0
for k, t in cells:
    if PAT.search(t) and t.strip():
        m += 1
        print("   %-14s %s" % (k, re.sub(r"\s+", " ", t)[:150]))
print("cell hits: %d" % m)
