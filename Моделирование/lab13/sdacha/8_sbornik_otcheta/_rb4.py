# -*- coding: utf-8 -*-
import os, re
# Resolved relative to this file: the delivery keeps the report in 0_zadanie_i_otchet, the
# authoring tree keeps it at the workspace root. No absolute path, so the delivered copy
# cannot read the authoring tree.
import os as _os
_UP4 = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
DOCX_REL = (_os.path.join(_UP4, "lab13_report.docx")
            if _os.path.exists(_os.path.join(_UP4, "lab13_report.docx"))
            else _os.path.join(_UP4, "0_zadanie_i_otchet", "lab13_report.docx"))
from docx import Document
d = Document(DOCX_REL)
paras = [(q.style.name, q.text.strip()) for q in d.paragraphs]
cur = None
WANT = {"4", "5", "7", "7.1", "7.2", "7.3", "7.4"}
for st, t in paras:
    if not t: continue
    m = re.match(r"^(\d+(?:\.\d+)?)(?:[.\s]|$)", t)
    if m and st.startswith("Heading"):
        cur = m.group(1)
        print("\n" + "=" * 22 + " " + cur + " " + "=" * 22)
        continue
    if cur in WANT and not st.startswith("Heading"):
        if t.startswith("Рисунок") or t.startswith("Таблица"): continue
        print("  * " + re.sub(r"\s+", " ", t))
