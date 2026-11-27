# -*- coding: utf-8 -*-
# Adapted from lab12 for Laboratory 13; only the document path differs.
from docx import Document
from docx.enum.text import WD_LINE_SPACING
p = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(p)
from collections import Counter
c = Counter()
for para in d.paragraphs:
    r = para.paragraph_format.line_spacing_rule
    ls = para.paragraph_format.line_spacing
    if r == WD_LINE_SPACING.ONE_POINT_FIVE: c["1.5"] += 1
    elif r == WD_LINE_SPACING.SINGLE: c["single"] += 1
    elif ls: c["mult %.2f" % ls] += 1
    else: c["inherited"] += 1
print("paragraph line-spacing rules:", dict(c))
# any paragraph still inheriting from Normal? confirm Normal has none set -> defaults single
print("Normal rule:", d.styles["Normal"].paragraph_format.line_spacing_rule)
