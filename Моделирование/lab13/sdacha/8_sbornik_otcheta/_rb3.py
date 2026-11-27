# -*- coding: utf-8 -*-
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
paras = [(q.style.name, q.text.strip()) for q in d.paragraphs]
cur = None
WANT = {"1", "2", "6", "6.1", "7", "7.1", "7.2", "7.3", "7.4", "8", "8.1", "8.2", "8.3"}
for st, t in paras:
    if not t: continue
    m = re.match(r"^(\d+(?:\.\d+)?)[.\s]", t)
    if m and st.startswith("Heading"):
        cur = m.group(1)
        print("\n" + "=" * 24 + " " + cur + " " + "=" * 24)
        continue
    if cur in WANT and not st.startswith("Heading"):
        if t.startswith("Рисунок") or t.startswith("Таблица"): continue
        print("  * " + re.sub(r"\s+", " ", t))
