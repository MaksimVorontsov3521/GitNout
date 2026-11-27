# -*- coding: utf-8 -*-
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
blob = "\n".join(units)
print("stale 'утверждений самодиагностики' present:", "утверждений самодиагностики" in blob)
print("stale 'всего 1,229,701 утверждений' present:", "1,229,701 утверждений" in blob)
for nd in ["Единица счёта здесь", "состояний.", "исчерпывающая самодиагностика моделей проверила",
           "проверила 1,229,701 состояний"]:
    print("   %-52s -> %s" % (repr(nd), nd.lower() in blob.lower()))
for u in units:
    if "Единица счёта здесь" in u:
        print("\n--- 3.3 as rendered ---\n   " + u[u.index("Там, где перебор"):][:760])
        break
for u in units:
    if "исчерпывающая самодиагностика моделей проверила" in u.lower():
        print("\n--- 10 as rendered ---\n   " + u[:620]); break
