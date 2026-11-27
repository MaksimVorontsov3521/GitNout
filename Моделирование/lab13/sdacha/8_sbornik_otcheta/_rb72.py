# -*- coding: utf-8 -*-
import re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
cur = None
for q in d.paragraphs:
    t = q.text.strip()
    if not t: continue
    m = re.match(r"^(\d+(?:\.\d+)?)(?:[.\s]|$)", t)
    if m and q.style.name.startswith("Heading"):
        cur = m.group(1); continue
    if cur == "7.2":
        print("\n[7.2 | " + q.style.name + "]")
        print("   " + re.sub(r"\s+", " ", t))
print("\n--- figure captions mentioning 74374 / 74244 ---")
for q in d.paragraphs:
    t = re.sub(r"\s+", " ", q.text.strip())
    if t.startswith("Рисунок") and ("74374" in t or "74244" in t):
        print("   " + t)
