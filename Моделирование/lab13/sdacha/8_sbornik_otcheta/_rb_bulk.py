# -*- coding: utf-8 -*-
# Bulk read-back of every section not yet read verbatim. Prose paragraphs only:
# tables, captions and monospace listings are checked by their own layers, and
# dumping them here would bury the sentences that a human reader can be wrong about.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
paras = [(q.style.name, q.text.strip()) for q in d.paragraphs]
cur = None
WANT = {"1", "2", "3", "3.1", "3.2", "3.3", "4", "4.1", "4.4", "4.5", "4.6", "5", "5.1", "5.2", "5.3", "6"}
tot = 0
for st, t in paras:
    if not t: continue
    m = re.match(r"^(\d+(?:\.\d+)?)[.\s]", t)
    if m and st.startswith("Heading"):
        cur = m.group(1)
        print("\n" + "=" * 30 + " " + cur + " " + "=" * 30)
        continue
    if cur in WANT and st.startswith("Body") or (cur in WANT and st == "Normal" and len(t) > 90):
        if t.startswith("Рисунок") or t.startswith("Таблица"): continue
        tot += 1
        print("  * " + re.sub(r"\s+", " ", t))
print("\n\n[prose paragraphs dumped: %d]" % tot)
