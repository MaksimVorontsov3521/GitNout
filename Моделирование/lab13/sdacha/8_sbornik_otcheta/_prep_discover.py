# -*- coding: utf-8 -*-
# Discovery pass: every site of the construction "при <numeral> <noun>" in the rendered
# report, printed verbatim with the noun isolated. The checker that follows is built on
# this list rather than on an imagined one, because the defect that motivated it
# ("при 18 выводов символа") sits in a construction my own numeral-agreement checker
# deliberately EXEMPTS: it recognised the preposition, classified the site as an oblique
# case and stopped, so it could never verify WHICH oblique case is correct. That
# limitation was recorded in evidence; this pass closes the gap for the one preposition
# the report actually uses with a numeral.
import re
from docx import Document
DOC = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(DOC)
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
PAT = re.compile(r"\bпри\s+(\d[\d\s]*(?:,\d{3})*)\s+((?:[а-яё]+(?:ыми|ими|ых|их)\s+)?[а-яё]{3,})", re.I)
sites = []
for u in units:
    for m in PAT.finditer(re.sub(r"\s+", " ", u)):
        sites.append((m.group(1).strip(), m.group(2).strip(), re.sub(r"\s+", " ", u)))
print("sites of 'при <numeral> <noun>': %d" % len(sites))
seen = {}
for num, noun, ctx in sites:
    seen.setdefault(noun, []).append(num)
for noun in sorted(seen):
    print("   %-16s numerals=%s" % (noun, sorted(set(seen[noun]))))
print("\n--- every site verbatim ---")
for num, noun, ctx in sites:
    i = ctx.find("при " + num.split()[0])
    print("   [%s %s] ...%s..." % (num, noun, ctx[max(0, i - 40):i + 60]))
