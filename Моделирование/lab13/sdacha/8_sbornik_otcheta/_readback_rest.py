# -*- coding: utf-8 -*-
# Finish the mandatory read-back: the corrected 4.3 sentence whole, the tail of
# the 8.4 coverage paragraph (the earlier dump was cut by my own slice limit, so
# I must confirm the document itself is not truncated), and 9.2 / 9.3 which had
# never been read back because of the heading-regex bug.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
paras = [(q.style.name, q.text.strip()) for q in d.paragraphs]
print("=== 4.3 corrected sentence, whole paragraph ===")
for st, t in paras:
    if t.startswith("Собственные схемы работы"):
        print("   " + t); print("   [len=%d]" % len(t)); break
print("\n=== 8.4 coverage paragraph, full tail ===")
for st, t in paras:
    if "Покрытие моделирования пункта 4" in t:
        print("   [len=%d] ...%s" % (len(t), t[-420:])); break
print("\n=== 9.2 and 9.3 sections ===")
def style_of(i):
    return paras[i][0]
idx = {}
for i, (st, t) in enumerate(paras):
    m = re.match(r"^(\d+(?:\.\d+)?)\s", t)
    if m and st.startswith("Heading"): idx[m.group(1)] = i
for sec in ["9.2", "9.3"]:
    if sec not in idx:
        print("\n--- %s NOT LOCATED ---" % sec); continue
    i = idx[sec]
    out = [paras[i][1]]
    for j in range(i + 1, len(paras)):
        if paras[j][0].startswith("Heading") and re.match(r"^\d", paras[j][1]): break
        if paras[j][1]: out.append(paras[j][1])
    print("\n--- %s (%d paragraphs) ---" % (sec, len(out) - 1))
    for t in out[1:]:
        print("   * " + (t[:330] + ("…" if len(t) > 330 else "")))
