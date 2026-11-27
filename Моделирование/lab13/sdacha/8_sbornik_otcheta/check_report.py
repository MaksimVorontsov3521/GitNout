# -*- coding: utf-8 -*-
# Adapted from lab12 for Laboratory 13; only the document path differs.
import sys, zipfile
from docx import Document
from docx.oxml.ns import qn
p = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(p)
# headings
hs = [(para.style.name, para.text) for para in d.paragraphs if para.style.name.startswith("Heading")]
print("HEADINGS (%d):" % len(hs))
for st, t in hs:
    lvl = 1 if st == "Heading 1" else (2 if st == "Heading 2" else 3)
    print("  " + "  "*(lvl-1) + t)
# counts
imgs = [r for r in d.part.rels.values() if "image" in r.reltype]
print("\nimages embedded: %d" % len(imgs))
print("tables: %d" % len(d.tables))
print("paragraphs: %d" % len(d.paragraphs))
# field codes
seq = d.element.body.findall(".//" + qn("w:instrText"))
seqt = [e.text for e in seq if e.text and "SEQ" in e.text]
print("SEQ fields: %d (Figure %d, Table %d)" % (len(seqt), sum(1 for x in seqt if "Figure" in x), sum(1 for x in seqt if "Table" in x)))
bm = d.element.body.findall(".//" + qn("w:bookmarkStart"))
print("bookmarks: %d" % len(bm))
# margins / font
s = d.sections[0]
print("page %.2fx%.2f cm, margins L%.1f R%.1f T%.1f B%.1f" % (s.page_width.cm, s.page_height.cm, s.left_margin.cm, s.right_margin.cm, s.top_margin.cm, s.bottom_margin.cm))
n = d.styles["Normal"]
print("Normal font: %s %s pt, line rule: %s" % (n.font.name, n.font.size.pt if n.font.size else "?", n.paragraph_format.line_spacing_rule))
# zip integrity
z = zipfile.ZipFile(p); bad = z.testzip()
print("zip testzip: %s" % ("OK (no bad entries)" if bad is None else "BAD " + bad))
print("package parts: %d" % len(z.namelist()))
