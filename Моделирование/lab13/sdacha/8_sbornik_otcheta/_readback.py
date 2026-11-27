# -*- coding: utf-8 -*-
# Read-back of the heavily patched sections, verbatim, so a human-grade sentence
# check happens on the RENDERED document rather than on the source that produced it.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
# headings are recognised by STYLE, not by a numbering pattern: the earlier
# version required a dot after the number and located nothing, which is a false
# "section missing" report caused by the checker.
want = ["4.2", "4.3", "5.4", "7.5", "8.4", "9.1", "9.2", "9.3", "10"]
cur = None
out = {}
for q in d.paragraphs:
    t = q.text
    if q.style.name.startswith("Heading"):
        m = re.match(r"^(\d+(?:\.\d+)?)[.\s]", t.strip())
        cur = m.group(1) if m else None
        if cur in want: out[cur] = []
        continue
    if cur in want and t.strip():
        out[cur].append(t)
print("headings matched: %s" % sorted(out))
for k in want:
    if k not in out:
        print("\n!!! section %s not located" % k); continue
    print("\n===================== %s (%d paragraphs) =====================" % (k, len(out[k])))
    for p in out[k]:
        print("  * " + p)


# Numeral agreement scan: for "<number> <noun>", Russian requires the noun form
# to depend on the last digits. Extract every such pair and group by lemma so a
# wrong form is visible as an inconsistent variant set.
PAIR = re.compile(r"(?<![\d.])(\d[\d\s]*|\d+(?:,\d{3})+)(\s+)([А-Яа-яЁё]{3,})(?![-\wА-Яа-я])")
def form(n):
    v = abs(int(str(n).replace(" ", "").replace(",", "")))
    m10, m100 = v % 10, v % 100
    if 10 < m100 < 20: return 2
    if m10 == 1: return 0
    if 1 < m10 < 5: return 1
    return 2
groups = {}
for u in [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]:
    for m in PAIR.finditer(u):
        n, w = m.group(1), m.group(3).lower()
        groups.setdefault(w, {}).setdefault(form(n), []).append((n.strip(), m.group(0).strip()))
print("\n\n================ NUMERAL AGREEMENT ================")
suspect = 0
for w, forms in sorted(groups.items()):
    if len(forms) >= 2:
        # a noun appearing with two different agreement forms is worth a look
        print("   %-18s forms used: %s" % (w, {k: [x[0] for x in v][:6] for k, v in sorted(forms.items())}))
        suspect += 1
print("nouns with more than one agreement form: %d" % suspect)
