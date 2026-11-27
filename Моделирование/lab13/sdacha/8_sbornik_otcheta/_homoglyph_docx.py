# -*- coding: utf-8 -*-
import os, re
from docx import Document
CYR = chr(0x0400) + "-" + chr(0x04FF)
LAT = "A-Za-z"
MIX = re.compile("[" + CYR + "][" + LAT + "]|[" + LAT + "][" + CYR + "]")
WORD = re.compile("[" + CYR + LAT + "][0-9_" + CYR + LAT + ".]*")
for tag, p in [("NEW workspace docx", r"../0_zadanie_i_otchet/lab13_report.docx"),
               ("delivery docx", r"../0_zadanie_i_otchet/lab13_report.docx")]:
    d = Document(p)
    units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
    hits = [w for u in units for w in WORD.findall(u) if MIX.search(w.strip("._-"))]
    print("%-20s paragraphs+cells=%d mixed=%d %r" % (tag, len(units), len(hits), hits))
    print("   contains Cyrillic-altram: %s | contains Latin altram: %s" % (chr(0x0430) + chr(0x043B) + "tram" in "\n".join(units), "altram" in "\n".join(units)))
