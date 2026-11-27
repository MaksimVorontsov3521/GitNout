# -*- coding: utf-8 -*-
# Adapted from lab12 for Laboratory 13; only the document path differs.
# Geometry-only layout audit: no image reading, pure measurement from the saved package.
from docx import Document
from docx.shared import Emu
from docx.oxml.ns import qn
p = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(p)
s = d.sections[0]
from docx.shared import Emu as _E
avail_w = _E(int(s.page_width) - int(s.left_margin) - int(s.right_margin))
avail_h = _E(int(s.page_height) - int(s.top_margin) - int(s.bottom_margin))
print("text area: %.2f x %.2f cm" % (avail_w.cm, avail_h.cm))
# inline shapes
bad_img = []; nimg = 0
for para in d.paragraphs:
    for r in para.runs:
        for il in r._element.findall(".//" + qn("wp:inline")):
            ext = il.find(qn("wp:extent")); nimg += 1
            w = Emu(int(ext.get("cx"))); h = Emu(int(ext.get("cy")))
            if w.cm > avail_w.cm + 0.01 or h.cm > avail_h.cm + 0.01:
                bad_img.append((nimg, round(w.cm,2), round(h.cm,2)))
print("inline images: %d, overflowing text area: %d" % (nimg, len(bad_img)))
for b in bad_img[:10]: print("   overflow #%d: %.2f x %.2f cm" % b)
# tables: sum of column widths vs available
bad_tbl = []
for i, t in enumerate(d.tables):
    ws = [c.width.cm if c.width else 0 for c in t.columns]
    tot = sum(ws)
    if tot > avail_w.cm + 0.01:
        bad_tbl.append((i, round(tot,2), len(ws)))
print("tables: %d, wider than text area: %d" % (len(d.tables), len(bad_tbl)))
for b in bad_tbl: print("   wide table #%d: %.2f cm over %d cols" % b)
# per-cell width sanity: any zero-width column?
zero = [(i, j) for i, t in enumerate(d.tables) for j, c in enumerate(t.columns) if c.width is None]
print("columns with unset width: %d" % len(zero))
# captions vs pictures balance
print("figure captions (SEQ Figure): %d" % sum(1 for e in d.element.body.findall(".//"+qn("w:instrText")) if e.text and "Figure" in e.text))
print("table captions (SEQ Table): %d" % sum(1 for e in d.element.body.findall(".//"+qn("w:instrText")) if e.text and "Table" in e.text))
# every image has a caption paragraph right after? check ordering
paras = d.paragraphs
img_idx = [i for i,pa in enumerate(paras) if pa._element.findall(".//"+qn("wp:inline"))]
cap_after = sum(1 for i in img_idx if i+1 < len(paras) and paras[i+1].text.startswith("Рисунок "))
print("images immediately followed by a caption: %d / %d" % (cap_after, len(img_idx)))
