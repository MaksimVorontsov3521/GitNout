# -*- coding: utf-8 -*-
# The task gives lpm_file and lpm_numwords as <none>. That is NOT a value: it means
# the parameter is left unset, and the tool substitutes a default. The report must
# say so, otherwise it presents a tool-chosen default as a choice I made.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
flat = re.sub(r"\s+", " ", "\n".join(units))
for probe in ["<none>", "не задан", "не указан", "по умолчанию", "подставил", "подставляет",
              "оставлен незадавленным", "значение по умолчанию", "синтез подставил"]:
    print("   %-28s -> %s" % (repr(probe), probe.lower() in flat.lower()))
print()
for u in units:
    if "LPM_FILE" in u and ("UNUSED" in u or "не зад" in u.lower() or "подстав" in u.lower()):
        print("--- how the report states the LPM_FILE default ---")
        print("   " + re.sub(r"\s+", " ", u)[:900]); break
for u in units:
    if "LPM_NUMWORDS" in u and ("1024" in u):
        print("\n--- how the report states the LPM_NUMWORDS default ---")
        i = u.find("LPM_NUMWORDS")
        print("   " + re.sub(r"\s+", " ", u[max(0, i - 260):i + 420])); break
