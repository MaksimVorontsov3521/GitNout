# -*- coding: utf-8 -*-
# Decide the ё question by measurement, not by taste: which words carry ё in this
# document, and which candidate words carry е. If ё is used systematically then an
# е-form is a defect; if it is used only in the handful of words where omission is
# widely treated as an error, then the е-forms match the document's own practice.
import os, re, collections
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
WORD = re.compile(r"[А-Яа-яЁё]{2,}")
yo = collections.Counter(); ye = collections.Counter()
for u in units:
    for w in WORD.findall(u):
        (yo if "ё" in w.lower() else ye)[w.lower()] += 1
print("distinct words containing ё: %d | total ё-tokens: %d" % (len(yo), sum(yo.values())))
print("top ё-words:", ", ".join("%s×%d" % (w, n) for w, n in yo.most_common(18)))
# candidates: words that WOULD contain ё in standard spelling and appear here with е
CAND = ["заряжен", "разряжен", "реш", "все", "всё", "еще", "сверх", "плен", "обеспеч", "утвержд",
        "свеч", "хле", "шел", "нем", "всем", "этот", "поет", "жаль", "шомпол"]
print("\nе-forms of words whose standard spelling has ё:")
for stem in CAND:
    hits = {w: n for w, n in ye.items() if stem in w}
    yohits = {w: n for w, n in yo.items() if stem in w}
    if hits or yohits:
        print("   stem %-10s ё: %-28s е: %s" % (stem,
              ", ".join("%s×%d" % (w, n) for w, n in sorted(yohits.items())) or "—",
              ", ".join("%s×%d" % (w, n) for w, n in sorted(hits.items())[:6]) or "—"))
