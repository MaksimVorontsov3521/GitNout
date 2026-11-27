# -*- coding: utf-8 -*-
import re, sys
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
caps = [re.sub(r"\s+", " ", q.text.strip()) for q in d.paragraphs
        if re.sub(r"\s+", " ", q.text.strip()).startswith("Рисунок") and ("74374" in q.text or "74244" in q.text or "74155" in q.text)]
for c in caps: print("   " + c)
NEED = ["8 D-триггеров, 8 буферов и 1 инвертор; всего 17 экземпляров при 18 выводах символа",
        "8 буферов в двух группах по четыре и 2 инвертора",
        "15 экземпляров: 5 NOT, 2 BAND2, 8 NAND3"]
FORBID = ["и 8 буферов и", "при 18 выводов", "сорок D-триггеров", "24 трёхстальных"]
flat = re.sub(r"\s+", " ", "\n".join([q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]))
bad = 0
for n in NEED:
    if n not in flat: print("EXPECTED ABSENT: " + repr(n)); bad += 1
for f in FORBID:
    if f in flat: print("FORBIDDEN PRESENT: " + repr(f)); bad += 1
print("\ncaption read-back: %s" % ("CLEAN" if bad == 0 else "%d PROBLEMS" % bad))
sys.exit(1 if bad else 0)
