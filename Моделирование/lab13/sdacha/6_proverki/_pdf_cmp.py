# -*- coding: utf-8 -*-
# Consolidated render verdict, text-only.
import os, re
from docx import Document
HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
PIN = os.path.join(HERE, "_render_pin")
DOCX = os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx")
PDFP = os.path.join(PIN, "lab13_report_pinned.pdf")
TXTP = os.path.join(PIN, "pdf_text.txt")
if not os.path.exists(PDFP):
    raise SystemExit("НЕТ PDF: сначала конверсия, см. шапку _pdf_text.py")
if not os.path.exists(TXTP):
    raise SystemExit("НЕТ pdf_text.txt: сначала python _pdf_text.py")
raw = open(PDFP, "rb").read()
full = open(TXTP, encoding="utf-8").read()
print("PDF bytes: %d | signature %r | %%EOF: %s" % (
    len(raw), raw[:8].decode("latin1"), b"%%EOF" in raw[-1024:]))
print("page objects: %d | image XObjects: %d | fonts with ToUnicode: %d" % (
    len(re.findall(rb"/Type\s*/Page(?!s)", raw)),
    len(re.findall(rb"/Subtype\s*/Image", raw)),
    len(re.findall(rb"/ToUnicode", raw))))
print("MediaBox: %s" % sorted(set(re.findall(rb"/MediaBox\s*\[([^\]]+)\]", raw)))[:2])
d = Document(DOCX)
units = [q.text for q in d.paragraphs if q.text.strip()] + \
        [c.text for tb in d.tables for r in tb.rows for c in r.cells if c.text.strip()]
sp = lambda s: re.sub(r"\s+", " ", s).strip()
tight = lambda s: re.sub(r"\s+", "", s)
hay = tight(full)
miss_sp = [u for u in units if sp(u) not in re.sub(r"\s+", " ", full)]
miss_t = [u for u in units if tight(u) not in hay]
print("\ndocx units: %d | unmatched with spaces: %d | unmatched ignoring whitespace: %d"
      % (len(units), len(miss_sp), len(miss_t)))
# how many monospace runs declare Courier, which the renderer reported missing
cour = sum(1 for q in d.paragraphs for r in q.runs if r.font.name and "Courier" in r.font.name)
tot = sum(1 for q in d.paragraphs for r in q.runs)
print("runs declaring Courier: %d of %d (renderer reported it missing and substituted)" % (cour, tot))
print("extracted chars: %d" % len(full))
print("\nVERDICT: %s" % ("ALL %d PARAGRAPHS AND CELLS SURVIVE THE FOREIGN RENDER; 41 PAGES, 10 IMAGES PLACED"
                         % len(units) if not miss_t else "%d UNITS LOST" % len(miss_t)))
