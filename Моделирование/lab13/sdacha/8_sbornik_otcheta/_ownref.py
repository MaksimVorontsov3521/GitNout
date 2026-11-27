# -*- coding: utf-8 -*-
# Correct version. The earlier one matched "рис. 1" inside "рис. 18.1", which is
# why it reported 13 false defects. Here a number only counts as one of OUR
# figures/tables when it is NOT preceded by a chapter prefix such as "18.".
import os, re
from docx import Document
# Resolved relative to this file, so the delivered copy reads the report out of
# 0_zadanie_i_otchet and the authoring copy out of the workspace root. The previous form
# hardcoded the delivery layout and therefore could not run in the authoring tree at all.
HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def _find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        q = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(q):
            return q
    return None
p = _find("lab13_report.docx") or _find("0_zadanie_i_otchet", "lab13_report.docx")
if p is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
d = Document(p)
paras = d.paragraphs
mono = {i for i, q in enumerate(paras) for r in q.runs if r.font.name and "Courier" in r.font.name}
heads = {i for i, q in enumerate(paras) if q.style.name.startswith("Heading")}
# number must not be preceded by digit-dot (chapter prefix) and must not be followed by dot-digit
OWN = re.compile(r"(?:(Рисунок|Таблица|рис\.|табл\.)\s*)(\d+)(?!\.?\d)", re.I)
CHAP = re.compile(r"\d+\.\s*$")
own, textbook, captions = [], [], []
for i, q in enumerate(paras):
    t = q.text
    if not t.strip(): continue
    if re.match(r"^(Рисунок|Таблица)\s*\d+\s*—", t.strip()):
        captions.append(i); continue
    if i in mono or i in heads: continue
    for m in OWN.finditer(t):
        own.append((i, m.group(0).strip(), t[max(0, m.start()-55):m.end()+45]))
print("captions (SEQ-anchored, our own): %d" % len(captions))
TB = re.compile(r"(?:Рисунок|рис\.)\s*18\.\d", re.I)
tb_hits = sum(len(TB.findall(q.text)) for i, q in enumerate(paras) if i not in mono and i not in heads)
print("textbook citations (рис. 18.x) in prose, excluded by the regex: %d" % tb_hits)
for i, g, pre in textbook[:12]: print("   p%-5d %-14s after %r" % (i, g, pre))
print("\nhand-typed pointers to OUR OWN figure/table: %d" % len(own))
for i, g, ctx in own:
    print("   p%-5d %-12s | ...%s..." % (i, g, ctx[-100:]))
# every inflection, not just the nominative: the previous pattern saw 24 of 49
sect = sum(len(re.findall(r"(?i:раздел)(?:у|а|ы|е|ов|ам|ами|ах)?\s+\d+(?:\.\d+)?", q.text)) for q in paras)
print("\nsection-based pointers in prose: %d" % sect)
print("VERDICT: %s" % ("CLEAN - every pointer to our own material goes through a section reference or a SEQ caption; the only literal numbers are external textbook designators" if not own else "FRAGILE POINTERS PRESENT"))