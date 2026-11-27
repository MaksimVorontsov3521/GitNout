# -*- coding: utf-8 -*-
import re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
flat = re.sub(r"\s+", " ", "\n".join(units))
STALE = ["расхождений — 0 расхождений", "этой замены требует формулировка задания",
         "блоки библиотки maxplus2", "заряженной", "разряженной", "во во всех", "нет.Уровни",
         "144 переходов", "1204 раз.", "64 комбинаций входов 74155", "утверждений самодиагностики"]
FRESH = ["суммарное число расхождений по всем пяти проектам равно 0",
         "Замена вызвана не формулировкой задания, а недоступностью самой системы",
         "блоки библиотеки maxplus2", "заряжённой", "разряжённой", "во всех 20 фазах",
         "нет. Уровни", "144 перехода", "1204 раза", "64 комбинации входов 74155",
         "проверила 1,229,701 состояний"]
bad = 0
for s in STALE:
    if s in flat: print("   STALE STILL PRESENT: " + repr(s)); bad += 1
for f in FRESH:
    if f not in flat: print("   EXPECTED FORM MISSING: " + repr(f)); bad += 1
print("stale forms remaining: %d | expected forms absent: %d" % (
      sum(1 for s in STALE if s in flat), sum(1 for f in FRESH if f not in flat)))
for u in units:
    if "Замена вызвана" in u: print("\n--- 2 as rendered ---\n   " + re.sub(r"\s+", " ", u)[:420])
    if "суммарное число расхождений" in u: print("\n--- 1 as rendered ---\n   " + re.sub(r"\s+", " ", u)[-260:])
print("\nVERDICT: %s" % ("ALL TEXT REPAIRS VERIFIED IN THE RENDERED DOCUMENT" if bad == 0 else "%d PROBLEMS" % bad))
raise SystemExit(1 if bad else 0)
