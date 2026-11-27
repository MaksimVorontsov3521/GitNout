# -*- coding: utf-8 -*-
# Read the nine patched sentences WHOLE, not as fragments: a computed ending can
# be grammatical and still produce a bad sentence. This is the mandatory
# read-back step that found four earlier defects in this lab.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
NEED = ["144 перехода", "1204 раза", "64 комбинации входов 74155", "64 наблюдения, ноль",
        "2 пути tpd", "52 сегмента", "64 сегмента X", "112 сегментов Z",
        "Собственные схемы работы, построенные", "64 комбинации шести входов"]
def sentence(u, i):
    s = 0
    for stop in ".;:!":
        j = u.rfind(stop + " ", 0, i)
        if j > s: s = j + 2
    e = len(u)
    for stop in ".;:!":
        j = u.find(stop + " ", i)
        if 0 < j < e: e = j + 1
    return u[s:e].strip()
for nd in NEED:
    hit = None
    for u in units:
        i = u.find(nd)
        if i >= 0:
            hit = sentence(u, i); break
    print("\n[%s] %s" % (nd, "FOUND" if hit else "ABSENT"))
    if hit: print("   " + (hit[:400] + ("…" if len(hit) > 400 else "")))
