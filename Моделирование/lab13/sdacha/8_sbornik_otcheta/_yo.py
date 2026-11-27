# -*- coding: utf-8 -*-
# Ё-consistency. The report writes ё throughout (ёмкость, ещё, её, обеспечивает...),
# so a word that occurs BOTH with ё and without it is an internal inconsistency,
# detectable without a dictionary: take the stem with ё removed and group occurrences.
# This is a precise test - it cannot flag a word that simply never appears with ё.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
WORD = re.compile(r"[А-Яа-яЁё]{3,}")
YO = re.compile(r"[А-Яа-яё]*ё[А-Яа-яё]*", re.I)
groups = {}
for u in units:
    for w in WORD.findall(u):
        lw = w.lower()
        if "ё" in lw:
            stem = lw.replace("ё", "е")
            groups.setdefault(stem, {"yo": set(), "ye": set()})["yo"].add(lw)
        else:
            # a candidate ye-form only if some ё-form of the same shape exists
            cand = lw.replace("е", "ё")
            groups.setdefault(cand, {"yo": set(), "ye": set()})["ye"].add(lw)
both = []
for stem, g in groups.items():
    if g["yo"] and g["ye"]:
        # keep only pairs that differ solely by the ё/е letter
        pairs = sorted((y, e) for y in g["yo"] for e in g["ye"] if y.replace("ё", "е") == e)
        if pairs: both += pairs
print("words occurring BOTH with ё and with е (pure inconsistency): %d" % len(both))
for y, e in sorted(set(both)):
    # show one context for the е-form so it can be adjudicated
    ctx = ""
    for u in units:
        i = re.search(r"\b" + re.escape(e) + r"\b", u, re.I)
        if i:
            ctx = re.sub(r"\s+", " ", u[max(0, i.start() - 45):i.start() + len(e) + 45]); break
    print("   ё-form %-18s е-form %-18s | ...%s..." % (y, e, ctx.strip()))
