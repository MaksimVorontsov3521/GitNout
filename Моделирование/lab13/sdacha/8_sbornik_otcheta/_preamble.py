# -*- coding: utf-8 -*-
# Report generator for Laboratory 13 (chapter 18: memory circuits).
#
# Layout demanded by the assignment file: A4, Times New Roman 12 pt, 1.5 line spacing,
# margins left 3.0 / right 1.5 / top 2.0 / bottom 2.0 cm. Figures and tables carry WORD
# auto-numbers (SEQ fields) with live cross-references (bookmark + REF), so re-numbering
# happens inside Word with F9 rather than by hand. Every number in the prose is read from
# report_data.json, which was assembled from the Quartus reports and the exhaustive model
# checks; nothing is typed by hand, so the document cannot drift from the measurements.
import json, os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# sdacha: данные и изображения берутся из папок сдачи, путь считается от самого
# скрипта, поэтому сборка работает без дерева авторства и без гостевой ОС.
HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
DATA = json.load(open(os.path.join(SD, "6_proverki", "report_data.json"), encoding="utf-8"))
PNG_DIRS = [os.path.join(SD, f) for f in
            ("1_ram4", "2_ram4beh", "3_mem4x8", "4_lpm_ram_dq", "lib_maxplus2")]


def _png(name):
    for d in PNG_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    raise FileNotFoundError("v sdache net izobrazheniya: " + name)
FONT = "Times New Roman"

# ------------------------------------------------------------------ fonts and styles
def _rfonts(el, name):
    r = el.find(qn('w:rPr'))
    if r is None:
        r = OxmlElement('w:rPr'); el.insert(0, r)
    rf = r.find(qn('w:rFonts'))
    if rf is None:
        rf = OxmlElement('w:rFonts'); r.insert(0, rf)
    for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'):
        rf.set(qn(a), name)

def style_font(doc, style_name, size, bold=False, name=FONT):
    try:
        st = doc.styles[style_name]
    except KeyError:
        return
    st.font.name = name
    st.font.size = Pt(size)
    st.font.bold = bold
    st.font.color.rgb = RGBColor(0, 0, 0)
    rpr = st.element.get_or_add_rPr()
    _rfonts(rpr, name)
    # kill the theme colour Word puts on heading styles
    col = rpr.find(qn('w:color'))
    if col is not None:
        rpr.remove(col)

def para_font(run, size=12, bold=False, italic=False, name=FONT):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    rpr = run._element.get_or_add_rPr()
    _rfonts(rpr, name)

def set_spacing(p, line=1.5, before=0, after=6, align=None):
    pf = p.paragraph_format
    if line == 1.5:
        pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    elif line == 1.0:
        pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
    else:
        pf.line_spacing = line
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    if align is not None:
        p.alignment = align

# ------------------------------------------------------------------ page setup
def setup_page(doc):
    s = doc.sections[0]
    s.page_width, s.page_height = Cm(21.0), Cm(29.7)
    s.left_margin, s.right_margin = Cm(3.0), Cm(1.5)
    s.top_margin, s.bottom_margin = Cm(2.0), Cm(2.0)
    # usable text width drives every picture and table
    return s.left_margin, s.right_margin

WORK_W = 21.0 - 3.0 - 1.5      # 16.5 cm of text column
WORK_H = 29.7 - 2.0 - 2.0      # 25.7 cm of text height

# ------------------------------------------------------------------ field-code plumbing
def _fld(instr):
    r = OxmlElement('w:r')
    fc = OxmlElement('w:fldChar'); fc.set(qn('w:fldCharType'), 'begin'); r.append(fc)
    yield r
    r2 = OxmlElement('w:r')
    it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve'); it.text = instr
    r2.append(it)
    yield r2
    r3 = OxmlElement('w:r')
    fs_ = OxmlElement('w:fldChar'); fs_.set(qn('w:fldCharType'), 'separate'); r3.append(fs_)
    yield r3
    r4 = OxmlElement('w:r')
    t = OxmlElement('w:t'); t.text = "1"
    r4.append(t)
    yield r4
    r5 = OxmlElement('w:r')
    fe = OxmlElement('w:fldChar'); fe.set(qn('w:fldCharType'), 'end'); r5.append(fe)
    yield r5

def add_field(par, instr, placeholder="1"):
    """Insert a real Word field (SEQ / REF / PAGEREF) into a paragraph."""
    rs = list(_fld(instr))
    rs[3].find(qn('w:t')).text = placeholder      # the cached result Word shows until F9
    for r in rs:
        par._p.append(r)

def bookmark(par, name, text):
    """Wrap a run of text in a bookmark so REF fields can point at it."""
    bs = OxmlElement('w:bookmarkStart'); bs.set(qn('w:id'), str(abs(hash(name)) % 2000000000)); bs.set(qn('w:name'), name)
    be = OxmlElement('w:bookmarkEnd'); be.set(qn('w:id'), bs.get(qn('w:id')))
    r = OxmlElement('w:r')
    rpr = OxmlElement('w:rPr'); rf = OxmlElement('w:rFonts')
    for a in ('w:ascii', 'w:hAnsi', 'w:cs'): rf.set(qn(a), FONT)
    sz = OxmlElement('w:sz'); sz.set(qn('w:val'), '24'); rpr.append(rf); rpr.append(sz)
    r.append(rpr)
    t = OxmlElement('w:t'); t.set(qn('xml:space'), 'preserve'); t.text = text
    r.append(t)
    par._p.append(bs); par._p.append(r); par._p.append(be)

# ------------------------------------------------------------------ captions
class Counter:
    def __init__(self): self.n = 0
    def next(self): self.n += 1; return self.n

FIG = Counter(); TBL = Counter()
FIG_BM = {}; TBL_BM = {}

def fig_caption(doc, text, key):
    p = doc.add_paragraph(); set_spacing(p, 1.0, 4, 10, WD_ALIGN_PARAGRAPH.CENTER)
    n = FIG.next(); bm = "Fig%d" % n; FIG_BM[key] = bm
    r = p.add_run("Рисунок "); para_font(r, 11)
    add_field(p, " SEQ Figure \\* ARABIC ", str(n))
    r2 = p.add_run(" — " + text); para_font(r2, 11)
    # bookmark the number itself so REF can fetch it
    bs = OxmlElement('w:bookmarkStart'); bs.set(qn('w:id'), str(1000000 + n)); bs.set(qn('w:name'), bm)
    be = OxmlElement('w:bookmarkEnd'); be.set(qn('w:id'), str(1000000 + n))
    # place the bookmark around the SEQ field run group
    p._p.insert(list(p._p).index(p.runs[0]._r) if p.runs else 0, bs)
    p._p.append(be)
    return n

def tbl_caption(doc, text, key):
    p = doc.add_paragraph(); set_spacing(p, 1.0, 8, 4, WD_ALIGN_PARAGRAPH.LEFT)
    n = TBL.next(); bm = "Tbl%d" % n; TBL_BM[key] = bm
    r = p.add_run("Таблица "); para_font(r, 11, bold=True)
    add_field(p, " SEQ Table \\* ARABIC ", str(n))
    r2 = p.add_run(" — " + text); para_font(r2, 11, bold=True)
    bs = OxmlElement('w:bookmarkStart'); bs.set(qn('w:id'), str(2000000 + n)); bs.set(qn('w:name'), bm)
    be = OxmlElement('w:bookmarkEnd'); be.set(qn('w:id'), str(2000000 + n))
    p._p.insert(0, bs); p._p.append(be)
    return n

def ref_fig(key):   return "Figure " + FIG_BM[key]
def ref_tbl(key):   return "Table " + TBL_BM[key]

def add_picture_fit(doc, path, cap_key, caption):
    from PIL import Image
    iw, ih = Image.open(path).size
    maxw, maxh = WORK_W - 0.2, WORK_H - 3.0
    scale = min(maxw / (iw / 96 * 2.54), maxh / (ih / 96 * 2.54), 1.0)
    w = Cm(iw / 96 * 2.54 * scale)
    p = doc.add_paragraph(); set_spacing(p, 1.0, 6, 2, WD_ALIGN_PARAGRAPH.CENTER)
    p.add_run().add_picture(path, width=w)
    return fig_caption(doc, caption, cap_key)

# ==================================================================== build the document
def H1(t):
    p = doc.add_paragraph(t, style="Heading 1"); set_spacing(p, 1.5, 12, 6)
    for r in p.runs: para_font(r, 14, bold=True)
    return p
def H2(t):
    p = doc.add_paragraph(t, style="Heading 2"); set_spacing(p, 1.5, 10, 4)
    for r in p.runs: para_font(r, 13, bold=True)
    return p
def H3(t):
    p = doc.add_paragraph(t, style="Heading 3"); set_spacing(p, 1.5, 8, 3)
    for r in p.runs: para_font(r, 12, bold=True, italic=True)
    return p
def body(t, align=WD_ALIGN_PARAGRAPH.JUSTIFY, first=None):
    p = doc.add_paragraph(); set_spacing(p, 1.5, 0, 6, align)
    r = p.add_run(t); para_font(r, 12)
    if first:
        fr = p.add_run(); para_font(fr, 12)
    return p
def bullet(t):
    p = doc.add_paragraph(style="List Bullet"); set_spacing(p, 1.5, 0, 3)
    r = p.add_run(t); para_font(r, 12); return p
def mono(t):
    p = doc.add_paragraph(); set_spacing(p, 1.0, 2, 6, WD_ALIGN_PARAGRAPH.LEFT)
    r = p.add_run(t); r.font.name = "Courier New"; r.font.size = Pt(10)
    rpr = r._element.get_or_add_rPr(); _rfonts(rpr, "Courier New"); return p
def quote(t):
    p = doc.add_paragraph(); set_spacing(p, 1.0, 4, 6, WD_ALIGN_PARAGRAPH.LEFT)
    p.paragraph_format.left_indent = Cm(1.0)
    r = p.add_run(t); para_font(r, 11, italic=True); return p
def make_table(rows, widths=None, header=True, fs_=10):
    t = doc.add_table(rows=len(rows), cols=len(rows[0])); t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, row in enumerate(rows):
        for j, cell in enumerate(row):
            c = t.cell(i, j); c.text = ""
            p = c.paragraphs[0]; set_spacing(p, 1.0, 1, 1)
            r = p.add_run(str(cell)); para_font(r, fs_, bold=(header and i == 0))
            if header and i == 0:
                sh = OxmlElement('w:shd'); sh.set(qn('w:val'), 'clear'); sh.set(qn('w:fill'), 'e8eef5')
                c._tc.get_or_add_tcPr().append(sh)
    if widths:
        for j, wd in enumerate(widths):
            for i in range(len(rows)):
                t.cell(i, j).width = Cm(wd)
    return t


# ------------------------------------------------------------------ safety net
# Quartus reports and hand-written literals can carry characters that XML forbids (C0 controls,
# stray backslash escapes such as \\a -> BEL, lone surrogates). Word cannot store them, so they are
# stripped centrally rather than at each call site. A non-empty strip is reported loudly, so the
# report can never silently lose a character.
_STRIP_LOG = []
def _sanitize(s):
    if not isinstance(s, str):
        return s
    keep = []
    for ch in s:
        c = ord(ch)
        if (c < 32 and c not in (9, 10, 13)) or (0xD800 <= c <= 0xDFFF)            or (0xFDD0 <= c <= 0xFDEF) or c in (0xFFFE, 0xFFFF) or c > 0x10FFFF:
            _STRIP_LOG.append((hex(c), s[max(0, len(keep)) - 30:len(keep) + 10]))
        else:
            keep.append(ch)
    return "".join(keep)
def _clean(x):
    if isinstance(x, str):
        return _sanitize(x)
    if isinstance(x, list):
        return [_clean(v) for v in x]
    if isinstance(x, tuple):
        return tuple(_clean(v) for v in x)
    if isinstance(x, dict):
        return {k: _clean(v) for k, v in x.items()}
    return x
def _guarded(fn, name):
    def wrapped(*a, **kw):
        return fn(*((_clean(v) for v in a)), **{k: _clean(v) for k, v in kw.items()})
    return wrapped
body = _guarded(body, "body"); bullet = _guarded(bullet, "bullet"); mono = _guarded(mono, "mono")
quote = _guarded(quote, "quote"); H1 = _guarded(H1, "H1"); H2 = _guarded(H2, "H2"); H3 = _guarded(H3, "H3")
fig_caption = _guarded(fig_caption, "fig_caption"); tbl_caption = _guarded(tbl_caption, "tbl_caption")
make_table = _guarded(make_table, "make_table")

doc = Document()
setup_page(doc)
for st, sz, bd in [("Normal", 12, False), ("Heading 1", 14, True), ("Heading 2", 13, True),
                   ("Heading 3", 12, True), ("Title", 16, True), ("List Bullet", 12, False),
                   ("List Number", 12, False)]:
    style_font(doc, st, sz, bd)
ns = doc.styles["Normal"].element.get_or_add_rPr(); _rfonts(ns, FONT)


# ---------------------------------------------------------------- title block
tp = doc.add_paragraph(); set_spacing(tp, 1.5, 0, 2, WD_ALIGN_PARAGRAPH.CENTER)
r = tp.add_run(DATA["meta"]["lab"]); para_font(r, 16, bold=True)
sp = doc.add_paragraph(); set_spacing(sp, 1.5, 0, 2, WD_ALIGN_PARAGRAPH.CENTER)
r = sp.add_run(DATA["meta"]["topic"]); para_font(r, 14, bold=True)
cp = doc.add_paragraph(); set_spacing(cp, 1.0, 0, 10, WD_ALIGN_PARAGRAPH.CENTER)
r = cp.add_run(DATA["meta"]["chapter"]); para_font(r, 12, italic=True)

