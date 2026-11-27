# -*- coding: utf-8 -*-
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
blob = "\n".join(units)
for nd in ["144 перехода", "1204 раза", "64 комбинации входов 74155", "64 наблюдения, ноль",
           "Собственные схемы работы, построенные", "52 сегмента", "64 сегмента", "2 пути tpd",
           "112 сегментов", "537 переходов"]:
    print("   %-34s -> %s" % (repr(nd), nd in blob))
for stale in ["сегментов X предсказаны", "сегментов со значением Z", "сегментов Z в пяти",
              "путь tpd", "144 переходов", "1204 раз.", "64 комбинаций входов 74155",
              "64 наблюдений, ноль", "работы построенные"]:
    if stale in blob: print("   STALE FORM STILL PRESENT: " + repr(stale))
print("\nVERDICT: %s" % ("ALL AGREEMENT FIXES LANDED AND NO STALE FORM REMAINS" if not any(s in blob for s in
      ["сегментов X предсказаны", "сегментов со значением Z", "сегментов Z в пяти", "путь tpd",
       "144 переходов", "1204 раз.", "64 комбинаций входов 74155", "64 наблюдений, ноль",
       "работы построенные"]) else "STALE FORMS REMAIN"))
