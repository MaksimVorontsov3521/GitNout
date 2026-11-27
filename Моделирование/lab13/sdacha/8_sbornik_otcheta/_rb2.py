# -*- coding: utf-8 -*-
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
paras = [(q.style.name, q.text.strip()) for q in d.paragraphs]
cur = None
WANT = {"4.5", "4.6", "5", "5.1", "5.2", "5.3", "6", "6.1"}
for st, t in paras:
    if not t: continue
    m = re.match(r"^(\d+(?:\.\d+)?)[.\s]", t)
    if m and st.startswith("Heading"):
        cur = m.group(1)
        print("\n" + "=" * 26 + " " + cur + " " + "=" * 26)
        continue
    if cur in WANT:
        if t.startswith("Рисунок") or t.startswith("Таблица"): continue
        if st.startswith("Heading"): continue
        print("  * " + re.sub(r"\s+", " ", t))
