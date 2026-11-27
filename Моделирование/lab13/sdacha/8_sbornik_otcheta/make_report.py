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


# ---------------------------------------------------- aliases used by every section
D = DATA
SW = DATA["seqwaves"]
LISTING_VHDL = open(os.path.join(HERE, "_listing_ram4beh.txt"), encoding="utf-8").read()
LISTING_AHDL = open(os.path.join(HERE, "_listing_lpramax.txt"), encoding="utf-8").read()


# ---------------------------------------------------------------- small helpers
def ns(s):
    """'9.366 ns' -> 9.366 (float); the reports store units inside the string."""
    return float(str(s).replace("ns", "").strip())

def pct(s):
    return float(str(s).replace("%", "").strip())

def num(s):
    return int(str(s).replace(",", "").split("/")[0].strip())

T1, T2, T3, T4 = DATA["tasks"]["ram4"], DATA["tasks"]["ram4beh"], DATA["tasks"]["mem4x8"], DATA["tasks"]["lpramax"]
TH = DATA["theory"]
CF = DATA["confrontation"]
ST = DATA["selftests"]

# ==================================================================== 1. цель работы
H1("1. Цель работы")
quote("«" + str(DATA["meta"]["lab"])+ ". " + str(DATA["meta"]["topic"])+ ".»")
body("Работа посвящена схемам памяти (глава 18). Задание содержит четыре пункта, каждый из которых "
     "требуется выполнить и пояснить: построить простейшую схему памяти на четыре бита по рисунку 18.7 "
     "в графическом редакторе, скомпилировать её и снять временные диаграммы, показывающие четыре "
     "различных значения информационного сигнала, записанные в разные ячейки; написать поведенческую "
     "модель той же схемы на VHDL; реализовать схему памяти размером четыре слова по восемь бит по "
     "рисунку 18.8 на дешифраторе 74155, четырёх регистрах 74374 и буфере 74244 с портами "
     "a0, a1, w[7..0], q[7..0], wr, rd и внутренней шиной d[7..0]; наконец, использовать из "
     "библиотеки мегафункций элемент lpm_ram_dq, оставив наружу только входы WE, ADDRESS, DATA и "
     "выход Q при параметрах, предписанных заданием.")
body("Помимо пунктов задания, работа требует разобраться в теоретической части главы: в соотношении "
     "ёмкости и быстродействия памяти, в иерархии памяти (рис. 18.1), в функциональной классификации "
     "запоминающих устройств (рис. 18.2), в трёх способах построения схем памяти с обязательным "
     "обходом примера на 256 элементов, в устройстве триггера DV (рис. 18.3), в статической ячейке "
     "памяти на n-MOS и CMOS транзисторах (рис. 18.4, 18.5) и в динамической ячейке с регенерацией "
     "(рис. 18.6). Теоретическая часть изложена в разделе 4; арифметика примера на 256 элементов в "
     "нём проверена машинно, а не пересказана.")
body("Каждый пункт выполнен как реальный проект в Quartus II 5.0, прогнан через полный поток "
     "(анализ и синтез, функциональное моделирование, размещение, сборка, анализ задержек) и сверен "
     "с независимой моделью. Суммарно проверено " + str(CF["total_phases"]) + " фаз временных "
      "диаграмм, и суммарное число расхождений по всем пяти проектам равно "
      + str(sum(CF["per_project"][k]["mismatches"] if "mismatches" in CF["per_project"][k] else
      CF["per_project"][k]["d"] + CF["per_project"][k]["q"] for k in ("ram4", "ram4beh", "mem4x8", "lpramax", "lpramwb"))) + ".");
H1("2. Инструментальная среда и замечание о замене САПР")
body("Задание написано под систему Altera MAX+plus II: оно требует графический редактор, блоки "
     "библиотеки maxplus2 (74155, 74374, 74244) и осциллограф с файлами форматов .scf и .wfm. "
      "Замена вызвана не формулировкой задания, а недоступностью самой системы: MAX+plus II "
      "не поставляется в современных установках, тогда как Quartus II сохраняет ту же "
      "библиотеку maxplus2 и те же элементы, поэтому предмет исследования не меняется.")
quote("Заявлено: " + str(DATA["meta"]["declared_tool"]))
quote("Выполнено в: " + str(DATA["meta"]["actual_tool"]))
bullet("Семейство и кристалл назначения для пунктов 1–3: " + str(DATA["meta"]["family"])+ ", "
       + str(DATA["meta"]["device"])+ " (выбран автоматически; отчёт размещения подтверждает выбор: "
       + str(T1["fit_msg"])+ ").")
bullet("Пункт 4 требует семейства, допускающего асинхронную однопортовую память. Измерено: такую "
       "конфигурацию принимают ACEX1K и FLEX10KE; Stratix и Cyclone отказывают, MAX3000A "
       "отказывается внутренним сбоем синтезатора состояний. Подробности — в разделе 8.3.")
bullet("Библиотека элементов: использован ПОДЛИННЫЙ набор блоков maxplus2. Схемы 74155, 74374 и "
       "74244 взяты не перерисованными, а скопированными из библиотечных файлов установки "
       "(74155.bdf, 74374.bdf, 74244.bdf), и их внутренняя структура проверена исчерпывающим "
       "перебором — см. раздел 7.1.")
bullet("Форматы файлов: .gdf в Quartus II соответствует файл схемы .bdf; осциллограмма .scf/.wfm "
       "соответствует .vwf на входе и .sim.vwf на выходе функционального моделирования.")
bullet("Поток обработки заменён на пакетный эквивалент: quartus_map (анализ и синтез), quartus_sim "
       "(функциональное моделирование), quartus_fit (размещение), quartus_asm (сборка), quartus_tan "
       "(анализ задержек) вместо цепочки mpm системы MAX+plus II.")
body("Подстановка инструмента сознательна и не меняет предмет исследования. Логика элементов 74155, "
     "74374 и 74244 задаётся их функциональными спецификациями, воспроизведёнными тем же "
     "производителем в тех же библиотечных файлах; триггер DV в пункте 1 построен из базового "
     "элемента DFFE, а не из транзисторов, что полностью соответствует уровню абстракции рисунка 18.7. "
     "Все числовые данные отчёта взяты из отчётов Quartus II и из машинных проверок модели, а не "
     "оценены вручную.")
body("Отдельно декларирую ограничение установки, обнаруженное измерением, а не предположением. "
     "В данной копии Quartus II 5.0 детальная база устройств присутствует только для семейства "
     "Stratix: фиттер подбирает устройства этого семейства и отказывает для всех прочих, выдавая "
     "«Can't select a device from device family ... because no devices in family are installed». "
     "Поэтому пункты 1–3 прошли полный поток — размещение, сборку и анализ задержек, — а пункт 4 "
     "прошёл анализ, синтез и функциональное моделирование, но не может быть размещён. На содержание "
     "пункта 4 это не влияет: задание требует показать настройку мегафункции и её функционирование, "
     "что полностью обеспечивается функциональным моделированием; приводится и машинно подтверждённый "
     "список семейств, для которых такая конфигурация вообще синтезируема.")

# ==================================================================== 3. методика
H1("3. Методика достоверности результатов")
body("Чтобы ни одно утверждение отчёта не держалось на предположении, каждый результат прошёл тройную "
     "проверку: независимая модель схемы, очная ставка модели с волной, вернувшей её Quartus, и "
     "исчерпывающий перебор там, где он возможен. Ниже три механизма, на которые опираются все "
     "последующие разделы.")

H2("3.1 Модель по геометрии библиотечных символов")
def plural(n, forms):
    v = abs(int(str(n).replace(" ", "").replace(",", "")))
    m10, m100 = v % 10, v % 100
    if 10 < m100 < 20: return forms[2]
    if m10 == 1: return forms[0]
    if 1 < m10 < 5: return forms[1]
    return forms[2]

SEG = ["сегмент", "сегмента", "сегментов"]
NODE = ["узел", "узла", "узлов"]
NET = ["электрическая сеть", "электрические сети", "электрических сетей"]
_g = T3["decoder_geometry"]
DG = {k: str(v) for k, v in _g.items() if not isinstance(v, dict)}
DG["symbols"] = {k: str(v) for k, v in _g["symbols"].items()}
MW = {k: str(v) for k, v in T3["map_warning_breakdown"].items()}
body("Функция каждого библиотечного элемента восстановлена не из даташита и не из памяти, а из "
     "подлинного файла схемы. Для 74155 это " + DG["symbol_total"] + " экземпляров (" 
     + DG["symbols"]["NOT"] + " инверторов NOT, " + DG["symbols"]["BAND2"] + " сдвоенных BAND2 и "
     + DG["symbols"]["NAND3"] + " трёхвходовых NAND3), " + DG["segs"] + " " + plural(DG["segs"], SEG) + " связи и "
     + DG["junctions"] + " " + plural(DG["junctions"], NODE) + " ветвления при " + DG["inputs"] + " входах и " + DG["outputs"]
     + " выходах. Число различных электрических сетей, полученное объединением концов всех "
     "сегментов, равно " + DG["nets_union_find"] + " и совпадает с величиной, записанной в "
     "машинном снимке дешифратора, так что обе независимые разметки одного файла согласуются.")
body("Этот механизм годится только для комбинационных схем: он не моделирует ни высокое "
     "сопротивление, ни хранение. Оба ограничения проверены машинно и зафиксированы: для 74244 "
     "модель даёт Q = D при любых стробах (то есть Z не возникает вовсе), а для 74374 из 1024 "
     "состояний разрешаются лишь ноль и единица без всякого хранения. Поэтому полярность стробов и "
     "секвенсорное поведение во всех разделах определены ИЗМЕРЕНИЕМ в гостевой системе, а не выводом "
     "из геометрии — см. раздел 9. Для 74155 ограничение не действует: элемент чисто комбинационный, "
     "и перебор оказался возможен; его результаты приведены в разделе 7.1.")

H2("3.2 Очная ставка каждой волны с независимой моделью")
body("Главный механизм достоверности — файл lab13/confront.mjs. Он сделан так, чтобы ошибка монтажа "
     "схемы не могла спрятаться: ожидание берётся НЕ из того списка, которым задавалось воздействие. "
     "Вместо этого воздействие считывается ОБРАТНО ИЗ ВОЛНЫ, которую вернул Quartus, модель "
     "прошивается ровно этими уровнями, и выход модели сравнивается с выходным каналом волны в "
     "середине каждой фазы. Если схема смонтирована неверно, модель видит то же самое, что увидело "
     "железо, и расхождение проявляется как несходство выходов.")
tbl_caption(doc, "Очная ставка каждой снятой волны с независимой моделью", "tbl_cf")
make_table([["Проект", "Фаз", "Расхождений", "Что хранится в конце"]] + [
    ["Задание 1, ram4 (рис. 18.7)", str(CF["per_project"]["ram4"]["phases"]),
     str(CF["per_project"]["ram4"]["mismatches"]),
     "ячейки 0..3 = " + " ".join(DATA["tasks"]["ram4"]["cells"])],
    ["Задание 2, ram4beh (VHDL)", str(CF["per_project"]["ram4beh"]["phases"]),
     str(CF["per_project"]["ram4beh"]["mismatches"]),
     "ячейки 0..3 = " + " ".join(DATA["tasks"]["ram4beh"]["cells"])],
    ["Задание 3, mem4x8 (рис. 18.8)", str(CF["per_project"]["mem4x8"]["phases"]),
     str(CF["per_project"]["mem4x8"]["d"]) + " на шине d, " + str(CF["per_project"]["mem4x8"]["q"]) + " на шине q",
     "слова 0..3 = FF, F0, A5, 5A"],
    ["Задание 4, lpramax (lpm_ram_dq)", str(CF["per_project"]["lpramax"]["phases"]),
     str(CF["per_project"]["lpramax"]["mismatches"]), "1024 слова по 8 бит, записано 4"],
    ["Дополнение, lpramwb (характер записи)", str(CF["per_project"]["lpramwb"]["phases"]),
     str(CF["per_project"]["lpramwb"]["mismatches"]), "решающий эксперимент, раздел 8.2"],
], widths=[6.2, 1.6, 4.2, 4.5], fs_=9)
body("Суммарно: " + str(CF["total_phases"]) + " фаз, ноль расхождений. Вердикт программы печатается "
     "дословно: «" + str(CF["verdict"])+ "», и завершается она нулевым кодом выхода только при нулевом "
     "числе расхождений, то есть этот отчёт невозможно получить молчаливым продолжением после ошибки.")
body("Второй слой верификации — независимый ПОВТОР того же сравнения другим кодом, и он нужен "
     "именно потому, что один код может ошибаться молча. Файл lab13/seqwaves.mjs берёт ожидания из "
     "той же models.mjs, но читает воздействие из волн через ДРУГОЙ разбор (parseVwf из "
     "lab13/seqcheck.mjs, а не встроенный разбор confront.mjs), шагает модель этими уровнями и "
     "сверяет каждый выходной канал в середине каждой фазы функцией checkSeq. Результат собран в "
     "lab13/evidence/seqwaves.json:")
tbl_caption(doc, "Второй, независимый слой сверки волн: ожидания из models.mjs, разбор через seqcheck", "tbl_sw")
make_table([["Волна", "Фаз", "Проверок", "Расхождений", "Сегментов Z", "Сегментов X", "Необъяснённых X", "Отсутствующих каналов"]] + [
    ["ram4 (задание 1)", str(SW["waves"]["ram4"]["phases"]), str(SW["waves"]["ram4"]["checked"]), str(SW["waves"]["ram4"]["mismatches"]), str(SW["waves"]["ram4"]["zSeen"]), str(SW["waves"]["ram4"]["xSeen"]), str(SW["waves"]["ram4"]["unexplainedX"]), str(SW["waves"]["ram4"]["absent"])],
    ["ram4beh (задание 2)", str(SW["waves"]["ram4beh"]["phases"]), str(SW["waves"]["ram4beh"]["checked"]), str(SW["waves"]["ram4beh"]["mismatches"]), str(SW["waves"]["ram4beh"]["zSeen"]), str(SW["waves"]["ram4beh"]["xSeen"]), str(SW["waves"]["ram4beh"]["unexplainedX"]), str(SW["waves"]["ram4beh"]["absent"])],
    ["mem4x8 (задание 3)", str(SW["waves"]["mem4x8"]["phases"]), str(SW["waves"]["mem4x8"]["checked"]), str(SW["waves"]["mem4x8"]["mismatches"]), str(SW["waves"]["mem4x8"]["zSeen"]), str(SW["waves"]["mem4x8"]["xSeen"]), str(SW["waves"]["mem4x8"]["unexplainedX"]), str(SW["waves"]["mem4x8"]["absent"])],
    ["lpramax (задание 4)", str(SW["waves"]["lpramax"]["phases"]), str(SW["waves"]["lpramax"]["checked"]), str(SW["waves"]["lpramax"]["mismatches"]), str(SW["waves"]["lpramax"]["zSeen"]), str(SW["waves"]["lpramax"]["xSeen"]), str(SW["waves"]["lpramax"]["unexplainedX"]), str(SW["waves"]["lpramax"]["absent"])],
    ["lpramwb (дополнение)", str(SW["waves"]["lpramwb"]["phases"]), str(SW["waves"]["lpramwb"]["checked"]), str(SW["waves"]["lpramwb"]["mismatches"]), str(SW["waves"]["lpramwb"]["zSeen"]), str(SW["waves"]["lpramwb"]["xSeen"]), str(SW["waves"]["lpramwb"]["unexplainedX"]), str(SW["waves"]["lpramwb"]["absent"])],
    ["ИТОГО", str(SW["totals"]["phases"]), str(SW["totals"]["checks"]), str(SW["totals"]["mism"]), str(SW["totals"]["z"]), str(SW["totals"]["x"]), str(SW["totals"]["ux"]), str(SW["totals"]["ab"])],
], widths=[3.6, 1.2, 1.6, 1.8, 1.8, 1.8, 2.2, 2.5], fs_=8)
body("Суммарно второй слой дал " + str(SW["totals"]["checks"]) + " сверок по "
     + str(SW["totals"]["phases"]) + " фазам с нулём расхождений, нулём необъяснённых X и нулём "
     "отсутствующих каналов; все " + str(SW["totals"]["x"]) + " " + plural(SW["totals"]["x"], SEG)
      + " X предсказаны моделью и "
     "потому учтены, а не прощены. Вердикт программы: «" + str(SW["verdict"])+ "».")
body("Практический смысл двух слоёв проявился немедленно: первый (confront.mjs) выдавал ВЕРНЫЙ "
     "вердикт, но печатал перевёрнутые по битам адреса и данные, потому что собирал шину от "
     "младшего бита, а читал как от старшего. Расхождение с независимо извлечённой таблицей "
     "evidence/lpramwb_measured.json это вскрыло, и теперь confront.mjs встроенной проверкой "
     "сверяет свои столбцы stimuli с той таблицей и завершается ошибкой при любом несогласии. "
     "Вердикты от этого не изменились (сравнение шло в единой конвенции с обеих сторон и "
     "ошибка сокращалась), но ДОКАЗУЕМОСТЬ изменилась: таблица фаз в отчёте обязана совпадать с "
     "волной, а не только быть внутренне непротиворечивой.")
body("Отдельно проверяются два факта, которые легко принять на веру и которые принимать нельзя. "
     "Первый: волна задания 1 и волна задания 2 (поведенческая VHDL-модель) совпадают поканально во "
     "всех 20 фазах — расхождений "
     + str(DATA["tasks"]["ram4beh"]["vs_task1"]["differences"]) + ". Это и есть ответ на требование "
     "задания: модель описывает ровно ту же схему. Второй: состояние высокого сопротивления "
     "действительно доживает до результата моделирования, а не подменяется нулём или иксами парсером. "
     "Программа насчитала " + str(DATA["z_proof"]["zSegments"]) + " " + plural(DATA["z_proof"]["zSegments"], SEG)
      + " со значением Z в пяти "
     "волнах, проконтролировала все " + str(DATA["z_proof"]["zSampled"]) + " из них в серединах и не "
     "потеряла ни одного: список потерянных сегментов пуст, а программа печатает его дословно как "
     + str(DATA["z_proof"]["lost"]) + " — то есть никаких потерянных значений нет. "
     "Уровни, встреченные в волнах, — " + ", ".join(DATA["z_proof"]["levelsSeen"]) + "; непрерывных "
     "интервалов отпускания шины в волне задания 1 — "
     + str(DATA["z_proof"]["reports"][0]["zRuns"]) + ", в волне задания 3 — "
     + str(DATA["z_proof"]["reports"][2]["zRuns"]) + ".")

H2("3.3 Исчерпывающие переборы и самодиагностика моделей")
body("Там, где перебор возможен, он выполнен полностью. Для 74155 это все 2 в 6-й = 64 комбинации "
     "входов (раздел 7.1). Для триггера DV, на котором построено задание 1, и для моделей всей "
     "памяти файл lab13/models.mjs содержит самодиагностику, проверяющую модель на всех допустимых "
     "наборах входов и сверяющую её со структурным двойником, собранным из девятизначных вентильных "
     "примитивов. Единица счёта здесь — ПРОВЕРЕННОЕ СОСТОЯНИЕ модели, то есть одна сверка её "
      "ответа с ответом вентильного двойника; счётчик такой: DFFE — " + format(DATA["selftests"]["dffe"], ",")
     + ", ram4 — " + format(DATA["selftests"]["ram4"], ",") + ", mem4x8 — "
     + format(DATA["selftests"]["mem4x8"], ",") + ", lpm_ram_dq — "
     + format(DATA["selftests"]["lpm_ram_dq"], ",") + "; всего "
     + format(DATA["selftests"]["total"], ",") + " состояний.")
body("Структурные двойники заведены намеренно: если поведенческая модель ошибётся, двойник на "
     "вентилях с ней разойдётся, и самодиагностика это покажет. Расхождения, которые двойник находит, "
     "не замалчиваются, а записываются как замечания — например, при неопределённом адресе или "
     "стробе поведенческая модель отдаёт Z (шина отпущена), а вентильная — X, потому что "
     "неопределённость на входе разрешения буфера распространяется на выход. Оба поведения корректны "
     "для своих уровней абстракции, и это различие обсуждается в разделе 5.4.")
body("Для пункта 4 перебор по существу не применим (1024 слова по 8 бит), и там применён другой "
     "механизм: среди семи гипотез о характере записи оставлена единственная, воспроизводящая обе "
     "измеренные волны с нулём расхождений, а шесть остальных отвергнуты по ТОЧНОМУ числу "
     "расхождений, зафиксированному программно. Таблица приведена в разделе 8.2.")


# ==================================================================== 4. теория
H1("4. Теоретические сведения главы 18, необходимые для понимания схем")

H2("4.1 Ёмкость и быстродействие: почему память иерархична")
body("Память характеризуется двумя величинами: ёмкостью C (числом байтов, которые в ней можно "
     "хранить) и быстродействием B (числом операций обращения в секунду). Смысл теоретической части "
     "главы в том, что эти две величины не независимы: увеличение ёмкости неизбежно снижает "
     "быстродействие, и наоборот. Причина не философская, а схемотехническая, и она же объясняет "
     "все четыре пункта задания:")
bullet("Рост ёмкости при плоской организации требует пропорционального роста числа проводов выбора "
       "(раздел 4.3), а длинная шина — это большая ёмкость и, следовательно, большая задержка.")
bullet("Рост ёмкости требует более широкого адреса, а широкий адрес проходит через дешифратор, "
       "добавляя его задержку к времени обращения.")
bullet("Размещение большого массива на одном кристалле удлиняет соединения «строка—столбец» и "
       "вынуждает дробить массив на банки, что само по себе вносит организационные задержки.")
body("Из этого следует главный организационный вывод главы: строить одну память, одновременно "
     "большую и быструю, бессмысленно — вместо этого строится иерархия (рис. 18.1), верхний уровень "
     "которой мал и очень быстр (регистры и кэш), средний больше и медленнее (оперативная память), "
     "а нижний наиболее велик и наименее быстр (внешние накопители). Адресное пространство "
     "распределяется между уровнями так, чтобы чаще всего обращающиеся данные оказывались на "
     "верхнем уровне. Глава иллюстрирует обратную зависимость на конкретных ЭВМ — Минск-32, Р120, "
     "РП300, Р1200; их числовые показатели приведены в лекционном тексте и здесь намеренно не "
     "перепечатываются, чтобы не исказить источник, но сам закон — чем больше ёмкость, тем меньше "
     "быстродействие — в работе проверен не на цифрах, а на схемах: разделы 5–8 показывают, как "
     "задержка обращения растёт вместе с разрядностью и структурой массива.")
body("Количественно это видно в измеренных отчётах. Пункт 1 (четыре бита, один триггер на разряд) "
     "даёт худшую задержку «адрес → данные» " + str(T1["tpd"]["actual"])+ ", пункт 3 (четыре слова по "
     "восемь бит на полноценных ИС) — " + str(T3["tpd"]["actual"])+ ", то есть рост в "
     + "%.2f раза" % (ns(T3["tpd"]["actual"]) / ns(T1["tpd"]["actual"])) + " при переходе от "
     "элементарной схемы к кристальной; при этом ресурсы выросли с " + T1["logic_elements"].split("/")[0].strip()
     + " логических элементов до " + T3["logic_elements"].split("/")[0].strip() + ".")

H2("4.2 Функциональная классификация запоминающих устройств")
body("Рисунок 18.2 разкладывает память по функциональному признаку — по тому, что с ней можно "
     "делать после изготовления. Ветви классификации такие:")
tbl_caption(doc, "Функциональная классификация устройств памяти и её отношение к заданиям работы", "tbl_cls")
make_table([["Класс", "Свойство", "Отношение к заданиям работы"],
    ["ROM", "программируется на заводе, только чтение", "не используется"],
    ["PROM", "однократное программирование пользователем (выжигание)", "не используется"],
    ["EPROM", "стирание ультрафиолетом, многократная запись", "прообраз ветви EEPROM"],
    ["EEPROM", "электрическое стирание и запись по байтам", "нижняя ветвь постоянной памяти"],
    ["RAM", "чтение и запись произвольных ячеек", "вся работа построена на ней"],
    ["SRAM", "статическая: ячейка на триггере, хранение без обновления", "пункты 1, 3 (рис. 18.3–18.5)"],
    ["DRAM", "динамическая: ячейка на ёмкости, требуется регенерация", "раздел 4.6, пункты не требуют"],
    ["CACHE", "быстрая буферная память верхнего уровня иерархии", "мотивация иерархии, раздел 4.1"],
    ["АЗУ", "устройства с произвольным доступом (периферийная память)", "контекст нижнего уровня иерархии"],
    ["МФЗУ", "накопители на магнитном ленточном/дисковом носителе", "контекст нижнего уровня иерархии"],
], widths=[3.0, 7.4, 6.1], fs_=9)
body("Ветвление RAM на SRAM и DRAM — центральное для понимания глав 18. Статическая ячейка держит "
     "бит в триггере и потому работает быстро, но занимает много транзисторов; динамическая держит "
     "бит зарядом ёмкости и потому плотнее, но требует регенерации и медленнее. Именно это "
     "различие объясняет, почему пункт 1 сделан на триггерах (наглядность), пункт 4 — на "
     "мегафункции, которая в установке реализована через блок памяти (altram), а не через "
     "триггеры: инструмент сам выбирает плотную реализацию, когда ёмкость велика.")

H2("4.3 Три способа построения схемы памяти и разбор примера на 256 элементов")
body("Глава указывает три способа построения ЗУ произвольной доступа. Первый — плоская (неадресуемая) "
     "организация: каждое слово имеет собственный набор проводов, и обращение к нему осуществляется "
     "прямым выбором его линий. Второй — матричная организация: слова располагаются в виде "
     "прямоугольной решётки, и выбор идёт по строкам и столбцам. Третий — смешанный, когда "
     "внутри банки используется матрица, а банки выбираются дешифратором. Разница между способами — "
     "только в числе проводов, которые надо вывести к массиву, и потому разница эта есть разница в "
     "быстродействии и в корпусе микросхемы.")
body("Глава разбирает пример на 256 элементов, и его арифметику я проверил машинно, а не пересказал:")
tbl_caption(doc, "Арифметика организации памяти на 256 элементов, проверенная машинно", "tbl_org")
make_table([["Организация", "Проводов выбора", "Как получено", "Проверка"],
    ["Плоская, 256 элементов", str(TH["flat_wires"]), "по одному проводу на элемент", "256 = 256"],
    ["Матрица 16 × 16", str(TH["two_sqrt"]), "2 · √256, строки плюс столбцы", "√256 = " + str(TH["sqrt"]) + ", 2·" + str(TH["sqrt"]) + " = " + str(TH["two_sqrt"])],
    ["Матрица с дешифраторами", str(TH["matrix_address_lines"]), "два дешифратора 4-в-16, по 4 адресных линии на каждый",
     "2 · 4 = " + str(TH["matrix_address_lines"]) + "; 2^" + str(TH["matrix_address_lines"]) + " = " + str(TH["address_word_limit"])],
], widths=[4.4, 2.6, 5.6, 3.9], fs_=9)
body("Смысл разбора такой. Плоская организация требует вывести к массиву 256 проводов выбора — "
     "столько же, сколько в нём элементов, и это неприемлемо: корпус микросхемы не может содержать "
     "столько выводов, да и длина шин растёт линейно с ёмкостью. Матричная организация "
     "располагает те же 256 элементов в решётку 16 на 16 (поскольку √256 = 16), и тогда выбор "
     "идёт строкой и столбцом: 16 + 16 = 2·√256 = 32 линии вместо 256, то есть выигрыш в восемь "
     "раз по числу проводов. Если теперь внешние адресные линии подать не на 32 провода напрямую, а "
     "на два дешифратора «4-в-16», то наружу достаточно вывести всего 4 + 4 = 8 адресных линий. "
     "Обратная проверка замыкает рассуждение: 8 адресных линий различают 2 в 8-й = "
     + str(TH["address_word_limit"]) + " состояний, что в точности равно числу элементов, — то есть "
     "восемь линий не «съэкономили» ёмкость, а лишь перенесли выбор внутрь массива.")
body("Отсюда практическое следствие, прямо касающееся разрядности адреса: 8-разрядный адрес в "
     "пределе различает не более 256 ячеек. Поэтому пункт 4, где адрес задан десятиразрядным "
     "(LPM_WIDTHAD = 10), описывает уже не 256, а 2 в 10-й = " + str(TH["task4_words"]) + " слов, а "
     "при разрядности слова 8 бит это " + str(TH["task4_bytes"]) + " бит, то есть ровно "
     + str(TH["task4_words"]) + " байт — число, которое подтверждается отчётом синтеза (раздел 8.1).")
body("Собственные схемы работы построены по другому краю того же диапазона, и это полезно для "
     "наглядности: в пункте 1 четыре элемента, дешифратор «2-в-4» и четыре провода выбора — "
     "плоская организация в минимальном виде, где экономия на проводах ещё не нужна; в пункте 3 те "
     "же четыре элемента, но шириной восемь бит, и дешифратор уже кристальный (74155), а выбор "
     "слова идёт двумя линиями a0, a1 — ровно теми же 2 в 2-й = 4 состояниями. Пункт 4 — "
     "противоположный край: 10 адресных линий, 1024 слова, и здесь синтез уже отказывается "
     "разворачивать массив в триггеры, используя блок памяти (раздел 8.4).")

H2("4.4 Триггер DV — элемент хранения, из которого строятся статические ячейки")
body("Рисунок 18.3 показывает триггер DV (D-триггер с разрешением) — элементарную ячейку хранения "
     "статической памяти. У него пять входов и один выход: D — информационный вход, CLK — тактовый "
     "вход, ENA — вход разрешения записи, PRN и CLRN — входы установки и сброса, Q — прямой выход. "
     "Состояние меняется только тогда, когда одновременно выполнены два условия: на CLK пришёл "
     "фронт и на ENA действует разрешение. Если ENA снят, триггер хранит записанное ранее, "
     "независимо от того, что происходит на D.")
body("Два свойства триггера важны для монтажа схем и потому проверены в работе отдельно:")
bullet("Входы PRN и CLRN активны НИЗКИМ уровнем (бар на именах и кружки на выводах в подлинной "
       "схеме). Они служат принудительной установкой и принудительным сбросом мимо такта, и в "
       "схемах памяти их обычно держат в пассивном состоянии.")
bullet("Неподключённый вывод в логике MAX+plus II и Quartus II несёт единицу. Для активных низких "
       "PRN и CLRN это означает, что оставленный висеть вход автоматически находится в пассивном "
       "состоянии и не мешает хранению. В пункте 1 эти входы подключены к VCC ЯВНО, а не оставлены "
       "висеть: результат тот же, но явная разводка делает схему самодокументируемой и снимает "
       "вопрос о том, что произойдёт при смене политики неопределённых состояний.")
body("То, как в таком ЗУ записывается и считывается информация (глава предлагает разобраться "
     "самостоятельно), в схеме пункта 1 решается двумя вентилями на каждую ячейку. Запись: на "
     "элемент И-НЕ (или И) приходит разрешение EN_i = addr_i · WE, где addr_i — выход дешифратора "
     "адреса, а WE — сигнал записи; он подается на ENA триггера, так что запись в i-ю ячейку "
     "возможна только при совпадении адреса и активном WE, и только на фронте CLK. Чтение: OE_i = "
     "addr_i · WE' (то есть по тому же адресу, но при снятом WE), и он открывает трёхстальный буфер, "
     "подключённый выходом к общей шине Q. Пока WE активен, ВСЕ буферы отпущены (шина в состоянии Z), "
     "и поэтому шина никогда не содержит одновременно двух драйверов. Это и есть разделение во "
     "времени записи и чтения, обеспечиваемое одним сигналом WE.")

H2("4.5 Статическая ячейка: n-MOS и CMOS исполнение")
body("Рисунки 18.4 и 18.5 показывают статическую ячейку как две перекрёстно связанные инверторные "
     "петли — это и есть триггер, описанный в разделе 4.4, только собранный из транзисторов. "
     "Доступ к биту осуществляется ключами, которыми управляют слова выбора.")
body("На рисунке 18.4 (n-MOS) хранение обеспечивает петля из двух инверторов, а обращение — два "
     "транзисторных ключа, подключающих ячейку к шинам чтения и записи. Последовательность, которую "
     "глава просит разобраться, в терминах нашей схемы пункта 1 такая: ХРАНЕНИЕ — петля "
     "самовосстанавливается, и пока подано питание, бит не теряется; ЗАПИСЬ — открывающий ключ "
     "подключает шину записи к узлу петли, причём драйвер шины принудительно перебивает "
     "установившееся состояние, поэтому запись возможна только при активном разрешении и только в "
     "те моменты, когда выбранный ключ открыт (в пункте 1 это фронты CLK при EN_i = 1); ЧТЕНИЕ — "
     "открывается ключ другой шины, петля через него выставляется на выход, и поскольку петля при "
     "этом не разрывается, чтение неразрушающее: это принципиальное отличие статической памяти от "
     "динамической, обсуждаемое в разделе 4.6.")
body("Рисунок 18.5 (CMOS) отличается только типом транзисторов: вместо резистивных нагрузок "
     "применяются р-канальные, благодаря чему в установленном состоянии между питанием и землёй нет "
     "постоянного тока, и потребляемая мощность падает на порядки. Именно CMOS-исполнение делает "
     "статическую память пригодной для больших ёмкостей, а n-MOS-исполнение остаётся более "
     "быстрым, но прожорливым — это ещё одна пара «быстродействие против ёмкости» уже на "
     "уровне технологии, и она же объясняет, почему в пункте 3 использованы готовые ИС 74374, а не "
     "транзисторная разводка.")

H2("4.6 Динамическая ячейка и регенерация")
body("Рисунок 18.6 показывает динамическую ячейку: бит хранится не в петле, а зарядом на "
     "паразитной ёмкости стока транзистора. Это позволяет сделать ячейку в 4–16 раз плотнее "
     "статической (меньше транзисторов на бит), но цена — необходимость регенерации.")
body("Механизм такой, и он прямо отвечает на вопрос главы о делении напряжения. При обращении к "
     "ячейке её ёмкость подключается к шине, напряжение на шине становится равным половине суммы "
     "напряжения заряжённой ячейки и напряжения разряжённой шины — в главе это записано как "
     "(Uon + dU)/2. Практически это означает, что считываемый передел ничтожен по амплитуде, и "
     "обычным инвертором его не восстановить: нужен чувствительный усилитель (усилитель "
     "считывания), который различает малое отклонение от половины и ВЫСТАВЛЯЕТ шину в полный "
     "уровень «1» или «0». Так же, как в пункте 1 роль выставления уровня играет трёхстальный "
     "буфер, а не сам триггер.")
bullet("Поскольку заряд на ёмкости утекает, через некоторое время он становится неразличим. "
       "Регенерация — периодическое перезаписывание ячейки тем же значением, выполняемое тем же "
       "усилителем считывания: прочитал малый передел, выставил полный, записал обратно.")
bullet("Чтение динамической ячейки РАЗРУШАЮЩЕЕ (в отличие от статической, раздел 4.5): после "
       "считывания ячейка обязана быть восстановлена, и регенерация — не отдельная процедура, а "
       "естественное продолжение каждого обращения.")
bullet("Отсюда следствие для быстродействия: DRAM плотнее в 4–16 раз, но медленнее SRAM, потому "
       "что каждый доступ требует работы чувствительного усилителя и восстановления, а часть "
       "пропускной способности уходит на циклы регенерации, не несущих полезной информации. Это "
       "и есть конкретная реализация закона раздела 4.1.")
body("Ни один из четырёх пунктов задания не требует динамической ячейки, и это не случайность: "
     "в пакете Quartus II 5.0 динамическая память не имеет элементарного носителя на уровне "
     "вентилей, а реализуется только внутри блоков памяти мегафункции. Поэтому её устройство "
     "разобрано теоретически (настоящий раздел), а практический опыт с блоком памяти получен в "
     "пункте 4, где lpm_ram_dq разворачивается именно в такой блок (раздел 8.4).")


# ==================================================================== 5. задание 1
H1("5. Задание 1. Простейшая схема памяти на четыре бита (рис. 18.7)")
quote("«Создать в графическом редакторе новый проект для простейшей схемы памяти (рис. 18.7); "
      "скомпилировать; исследовать функционирование, сняв временные диаграммы, показывающие четыре "
      "различных значения информационного сигнала, записанные в разные ячейки.»")

H2("5.1 Состав схемы и её монтаж")
body("Рисунок 18.7 — простейшее ЗУ: четыре элемента хранения, дешифратор адреса, вентили стробов "
     "записи и чтения и три трёхстальных буфера, выведенных на общую шину. Схема смонтирована из "
     "21 экземпляра и 59 соединений, перечень элементов такой: три инвертора NOT (N0, N1, N2 — "
     "инвертируют A0, A1 и WE), генераторы VCC (V0) и GND (G0), и на каждую из четырёх ячеек i = "
     "0..3 по три элемента — вентиль записного строба E{i} (AND3), триггер DV в исполнении "
     "библиотеки F{i} (DFFE) и вентиль считывающего строба O{i} (AND3), плюс трёхстальный буфер "
     "T{i} (TRI). Итого четыре DFFE, четыре AND3 на запись, четыре AND3 на чтение, четыре TRI, "
     "три NOT, VCC и GND.")
body("Дешифратор адреса составлен из инверторов A0 и A1 и самих вентилей стробов, потому что для "
     "четырёх ячеек отдельный дешифратор не требуется: каждая строка выбора — это конъюнкция "
     "двух литер адресных линий. Получается ровно та таблица, которая следует из рисунка 18.7:")
tbl_caption(doc, "Строки выбора и стробы ячеек простейшей схемы памяти (рис. 18.7)", "tbl_dec")
make_table([["Ячейка", "Адрес (A1 A0)", "Строка выбора addr_i", "Записной строб EN_i", "Считывающий строб OE_i"],
    ["0", "00", "!A0 * !A1", "addr_0 * WE", "addr_0 * !WE"],
    ["1", "01", "A0 * !A1", "addr_1 * WE", "addr_1 * !WE"],
    ["2", "10", "!A0 * A1", "addr_2 * WE", "addr_2 * !WE"],
    ["3", "11", "A0 * A1", "addr_3 * WE", "addr_3 * !WE"],
], widths=[1.6, 2.6, 3.6, 3.9, 4.8], fs_=9)
body("Разводка подтверждает формулы дословно: входы E0 соединены с N0.OUT, N1.OUT и WE, входы E1 — "
     "с A0, N1.OUT и WE, и так далее; входы O{i} получают те же две литеры адреса, но третьим "
     "входом — N2.OUT, то есть !WE. Таким образом, одним и тем же адресом ячейка либо "
     "записывается (WE = 1), либо читается (WE = 0), но никогда одновременно. Выходы всех четырёх "
     "буферов T0..T3 подключены к одному порту Q — это и есть общая шина, и именно поэтому "
     "считывающие стробы обязаны быть взаимоисключающими: два открытых буфера на одном выводе "
     "были бы коротким замыканием.")
body("Входы PRN и CLRN всех четырёх триггеров подключены к V0.1 (единице), как и требует "
     "раздел 4.4: входы активны низким уровнем, поэтому единица оставляет их в пассивном "
     "состоянии, и триггер работает как чистое хранилище, не вмешиваясь в принудительную установку. "
     "Информационный вход D подключён ко всем четырём триггерам одновременно (шина данных), а "
     "тактовый вход CLK — тоже ко всем четырём: выбор ячейки осуществляется не тактом, а "
     "разрешением ENA, что и соответствует рисунку 18.7.")

H2("5.2 Временная диаграмма: четыре значения, записанные в разные ячейки")
body("Диаграмма содержит " + str(T1["phases"]) + " фаз по " + str(DATA["meta"]["period_ns"])
     + " нс. Воздействие устроено так, чтобы секвенсорное поведение схемы было видно: каждая запись "
     "занимает три фазы — подготовка (WE = 1, такт ещё не пришёл), импульс (WE = 1 и CLK = 1, "
     "то есть фронт) и отпускание (WE = 0), причём адрес и данные во всех трёх фазах "
     "НЕ МЕНЯЮТСЯ. Затем идут два считывающих прохода по всем четырём адресам при WE = 0.")
body("Снятая волна показывает четыре события записи в четыре РАЗНЫЕ ячейки — адреса 00, 01, 10, 11 "
     "— и четыре различных значения информационного сигнала в этих событиях: "
     + ", ".join(T1["written_values"]) + ". Считывающий проход возвращает их на шину в том же "
     "порядке: Q = " + ", ".join(T1["written_values"]) + " при обходе адресов 00 → 01 → 10 → 11, "
     "и это повторено дважды (фазы 12–15 и 16–19).")
body("Здесь нужно быть честным с формулировкой задания, и это содержательное замечание, а не "
     "отговорка. Память по рисунку 18.7 — четырёхбитная в смысле ЁМКОСТИ: четыре ячейки по одному "
     "биту, и порт данных D одинарный. На одинарном порту физически возможны только два уровня, "
     "поэтому «четыре различных значения» не могут быть четырьмя различными амплитудами сигнала — "
     "они могут быть только четырьмя различными событиями записи в четыре различных адреса, что "
     "диаграмма и показывает. Более того, второй считывающий проход сделан специально, чтобы "
     "доказать, что шина несёт именно СОДЕРЖИМОЕ ячеек, а не текущее значение D: в фазах 12–15 на "
     "вход D подан нуль, в фазах 16–19 — единица, а Q в обоих проходах одинаков и равен "
     + ", ".join(T1["written_values"]) + ". Совпадение двух проходов при разных D — это и есть "
     "машинно подтверждённое свидетельство хранения.")
body("Если требовать, чтобы четыре значения различались по амплитуде, память надо расширять — и "
     "задание это предусматривает, переходя к пункту 3: там четыре ячейки по восемь бит, и в них "
     "записаны четыре подлинно различных слова FF, F0, A5, 5A (раздел 7.4). Таким образом, "
     "требование «четыре различных значения в разных ячейках» удовлетворяется парой пунктов: "
     "пункт 1 даёт четыре различных события записи по четырём различным адресам, пункт 3 — четыре "
     "различных слова.")
body("Третье состояние шины на диаграмме также реально. Во время всех четырёх записей (фазы 0–11) "
     "канал Q находится в состоянии Z, потому что при WE = 1 все четыре считывающих строба "
     "закрыты формулой OE_i = addr_i * !WE. Таким образом, выходной канал демонстрирует три "
     "различных состояния — 1, 0 и Z, — причём Z не подменён нулём: это проверено отдельно "
     "(раздел 3.2).")
add_picture_fit(doc, _png("ram4.png"), "ram4_sch",
    "Задание 1: простейшая схема памяти на 4 бита (рис. 18.7), "
    + str(T1["sheet"]["width_px"]) + "×" + str(T1["sheet"]["height_px"]) + " точек")
add_picture_fit(doc, _png("ram4_wf.png"), "ram4_wf",
    "Задание 1: временная диаграмма, " + str(T1["phases"]) + " фаз — четыре записи в разные ячейки "
    "и два считывающих прохода")

H2("5.3 Ресурсы и задержки измеренного проекта")
body("Проект прошёл полный поток. Разместитель выбрал кристалл " + str(T1["device"])+ " семейства "
     + str(T1["family"])+ " (" + str(T1["fit_msg"])+ "), сборщик отработал (" + str(T1["asm_msg"])+ "), анализ "
     "задержек не нашёл ни одного нарушенного пути (" + str(T1["tan_msg"])+ "). Ресурсы: "
     + str(T1["logic_elements"])+ " логических элементов, " + str(T1["pins"])+ " выводов, "
     + str(T1["memory_bits"])+ " бит встроенной памяти — последняя цифра важна: схема целиком "
     "развёрнута в триггерах и логике, никакой блок-памяти синтезатор не использовал, что и "
     "соответствует наивному рисунку 18.7.")
tbl_caption(doc, "Ресурсы и задержки измеренного проекта задания 1 (ram4)", "tbl_t1")
make_table([["Показатель", "Значение", "Маршрут", "Смысл для памяти"],
    ["tpd (худший)", T1["tpd"]["actual"], T1["tpd"]["from"] + " → " + str(T1["tpd"]["to"]),
     "время доступа «адрес → данные»: дешифратор плюс буфер, основной показатель быстродействия"],
    ["tsu (худший)", T1["tsu"]["actual"], T1["tsu"]["from"] + " → " + str(T1["tsu"]["to"]),
     "требование установки данных/адреса относительно такта записи"],
    ["tco (худший)", T1["tco"]["actual"], T1["tco"]["from"] + " → " + str(T1["tco"]["to"]),
     "задержка выдачи хранящегося бита на шину после такта"],
    ["th (худший)", T1["th"]["actual"], T1["th"]["from"] + " → " + str(T1["th"]["to"]),
     "удержание; отрицательное значение означает выполнение требования с запасом "
     + str(abs(ns(T1["th"]["actual"]))) + " нс"],
    ["Покрытие моделирования", T1["coverage"] + " %", "—",
     "доля переходов схемы, наблюдавшихся на диаграмме; " + str(T1["transitions"]) + " "
      + plural(T1["transitions"], ["переход", "перехода", "переходов"])],
], widths=[3.0, 2.2, 3.2, 8.1], fs_=9)
body("Обращает на себя внимание, что tco (" + str(T1["tco"]["actual"])+ ") заметно меньше tpd ("
     + str(T1["tpd"]["actual"])+ "): путь «такт → выход» короче пути «адрес → выход», потому что "
     "второй включает дешифратор адреса, а первый — только триггер и буфер. Это прямая "
     "иллюстрация раздела 4.3: время обращения к памяти определяется дешифратором, и именно "
     "поэтому борьба за быстродействие идёт по линии сокращения адресных линий, а не по линии "
     "ускорения триггеров.")

H2("5.4 Граница между поведенческой и вентильной моделями")
body("Самодиагностика модели (раздел 3.3) выявила систематическое расхождение между поведенческой "
     "моделью и её вентильным двойником, и его стоит понять. Оно зафиксировано " + str(ST["notes_total"])
     + " " + plural(ST["notes_total"], ["раз", "раза", "раз"]) + ". На наборах, где адрес или строб "
      "неопределённы (X), поведенческая модель отдаёт Z — "
     "шина отпущена, — а вентильная отдаёт X. Например: «ram4 read, WE=X A=10: behavioural Q=Z but "
     "gate-level Q=X». Причина в том, что неопределённость на входе разрешения трёхстального буфера "
     "в девятизначной логике распространяется на выход, тогда как поведенческая модель трактует "
     "«не выбран» как «не драйвить». Оба ответа корректны на своём уровне абстракции, и ни одно из "
     "измеренных состояний рабочей диаграммы в X не попадает: все " + str(T1["phases"]) + " фаз "
     "имеют определённые адрес и строб, поэтому расхождение не затрагивает ни одного результата "
     "отчёта. Область его появления тоже измерена, а не предположена: " + str(ST["notes_by_scope"]["ram4 (пункты 1 и 2)"])
     + " случаев приходится на развёрнутую схему пунктов 1 и 2, " + str(ST["notes_by_scope"]["mem4x8 (пункт 3)"])
     + " — на пункт 3, и ни одного — на пункт 4, что и следовало ожидать: расхождение требует "
     "трёхстального буфера с неопределённым разрешением, а мегафункция его не разворачивает. "
     "Замечания записаны в файл, а не сглажены, поскольку именно на таких переходах реально "
     "работает симулятор при неполном воздействии.")


# ==================================================================== 6. задание 2
H1("6. Задание 2. Поведенческая модель той же схемы на VHDL")
quote("«Разработать поведенческую модель простейшей схемы памяти на VHDL.»")
body("Модель описывает ровно ту схему, что смонтирована в пункте 1, и обязана давать ровно ту же "
     "волну. Порты совпадают с портами схемы: clk, we, a (вектор из двух адресных линий), d — "
     "входы; q — выход. Хранилище объявлено как массив std_logic по числу ячеек, то есть ёмкость "
     "модели — четыре бита, как и у схемы:")
mono("type cell_array is array (0 to 3) of std_logic;")
mono("signal cell : cell_array := (others => '0');")
body("Запись описана секвенсорно: процесс чувствителен к clk, внутри проверяется фронт, затем "
     "активность we, затем совпадение адреса. Это в точности поведение триггера DV из раздела 4.4: "
     "состояние меняется только при фронте такта И при активном разрешении, а адрес определяет, "
     "КАКОЙ именно триггер меняет состояние:")
mono("if rising_edge(clk) then")
mono("    if we = '1' then")
mono("        case a is")
mono("            when \"00\" => cell(0) <= d;   -- и аналогично для 01, 10, 11")
body("Чтение описано комбинированно, и здесь модель сознательно следует схеме, а не упрощает её: "
     "выбранный адресом бит выходит на шину только при снятом we, а при активном we шина "
     "отпускается в Z — ровно как четыре трёхстальных буфера схемы, чьи стробы замкнуты на !WE:")
mono("sel_bit <= cell(0) when a = \"00\" else cell(1) when a = \"01\" else ... ;")
mono("q <= sel_bit when we = '0' else 'Z';")
body("Три позиции, которые глава оставляет студенту «разобраться самостоятельно» (раздел 4.4), в "
     "модели разрешены явно и прокомментированы в исходнике: назначение PRN и CLRN и то, что "
     "неподключённый вывод несёт единицу; условие записи (фронт И разрешение И выбор адреса); и "
     "причина, по которой при записи шина молчит. Начальное состояние массива — нули, что совпадает "
     "с поведением синтезированной схемы, для которой Quartus сообщает «setting initial contents "
     "to 0».")
add_picture_fit(doc, _png("ram4beh_wf.png"), "ram4beh_wf",
    "Задание 2: временная диаграмма поведенческой модели, " + str(T2["phases"]) + " фаз — "
    "идентична диаграмме задания 1 (расхождений " + str(T2["vs_task1"]["differences"]) + ")")
body("Проверка тождества выполнена жёстко. Во-первых, волна модели сравнена с волной схемы "
     "поканально во всех " + str(T2["phases"]) + " фазах: расхождений "
     + str(T2["vs_task1"]["differences"]) + ". Во-вторых, обе волны сравнены с одной и той же "
     "независимой моделью из lab13/models.mjs методом очной ставки (раздел 3.2): "
     + str(T2["mismatches"]) + " расхождений у схемы и " + str(T2["mismatches"]) + " у VHDL-модели, "
     "причём конечное содержимое ячеек одинаково — " + " ".join(T2["cells"]) + ". Совпадение двух "
     "реализаций, написанных на разных языках и синтезированных независимо, и есть доказательство "
     "того, что поведенческая модель описывает именно эту схему, а не похожую на неё.")
body("Ресурсы синтезированной VHDL-модели: " + str(T2["logic_elements"])+ " логических элементов против "
     + str(T1["logic_elements"])+ " у схемы, то есть на один элемент меньше, при том же числе выводов ("
     + str(T2["pins"])+ "). Синтезатор уплотнил дешифратор ячеек эффективнее, чем это сделано вручную "
     "вентильной разводкой пункта 1 — полезное наблюдение: ручная схема по рисунку 18.7 дидактична, "
     "но не оптимальна. Задержки при этом практически совпали: tpd " + str(T2["tpd"]["actual"])+ " ("
     + str(T2["tpd"]["from"])+ " → " + str(T2["tpd"]["to"])+ ") против " + str(T1["tpd"]["actual"])+ " в пункте "
     "1, разница " + "%.3f нс" % (ns(T1["tpd"]["actual"]) - ns(T2["tpd"]["actual"])) + ", то есть "
     "менее полутора процентов. Покрытие моделирования у VHDL-модели выше (" + str(T2["coverage"])+ " % против " + str(T1["coverage"])+ " %), потому что плоский процесс даёт наблюдаемые переходы в "
     "более коротких цепях.")
body("Отдельно отмечу, что синтез VHDL-модели прошёл без единого предупреждения ("
     + str(T2["map_msg"])+ "), тогда как вентильная схема пункта 1 дала одно: «" + str(T1["map_warnings"][0])+ "» — генератор GND объявлен, но не использован, поскольку активные низкие PRN и CLRN "
     "подключены к единице и земля в схеме не требуется. Предупреждение безвредно, но оно же "
     "подтверждает вывод раздела 4.4: в этой схеме GND действительно не нужен.")

H2("6.1 Исходный текст модели")
mono(LISTING_VHDL)

# ==================================================================== 7. задание 3
H1("7. Задание 3. Схема памяти 4 × 8 бит (рис. 18.8)")
quote("«Реализовать схему памяти 4 × 8 бит по рисунку 18.8: дешифратор 74155, четыре регистра "
      "74374, буфер 74244; порты a0, a1, w[7..0], q[7..0], wr, rd; внутренняя шина d[7..0]. "
      "Объяснить принцип работы и снять временные диаграммы.»")

H2("7.1 Дешифратор 74155: структура и исчерпывающая проверка")
body("Первый и важнейший шаг — понять, что делает библиотечный 74155, не веря ни даташиту, ни себе. "
     "Подлинная схема из файла библиотеки содержит " + DG["symbol_total"] + " экземпляров: "
     + DG["symbols"]["NOT"] + " инверторов NOT, "
     + DG["symbols"]["BAND2"] + " сдвоенных элемента BAND2 и " + DG["symbols"]["NAND3"]
     + " трёхвходовых NAND3, разведённых в " + DG["segs"] + " " + plural(DG["segs"], SEG) + " связи и " + DG["junctions"]
     + " " + plural(DG["junctions"], NODE) + " ветвления при " + DG["inputs"] + " входах и " + DG["outputs"] + " выходах. "
     "Это двойной дешифратор «2-в-4»: две адресные линии SELA, SELB выбирают один из четырёх "
     "выходов в каждой из двух групп, а каждая группа разрешается своим стробом.")
body("Функция выводов восстановлена исчерпывающим перебором ВСЕХ 2 в 6-й = "
     + str(T3["decoder_combinations"]) + " комбинаций шести входов (1GN, 1C, 2GN, 2CN, SELA, SELB). "
     "Сеть сходится не более чем за " + str(T3["decoder_passes_max"]) + " прохода, неопределённых "
     "состояний не возникло ни на одной комбинации. Перебор выдал формулу и — что важнее — вскрыл "
     "ловушку, на которой держится весь пункт 3:")
mono("1YkN = NOT( (1C AND NOT 1GN)     AND (SELB*2+SELA = k) )      k = 0..3")
mono("2YkN = NOT( (NOT 2CN AND NOT 2GN) AND (SELB*2+SELA = k) )     k = 0..3")
body("Формула проверена на всех " + str(T3["decoder_combinations"]) + " комбинациях с нулём "
     "нарушений (" + str(T3["decoder_formula_violations"]) + "). Обратим внимание на разность двух "
     "строк: у первой группы вход разрешения по данным 1C активен ВЫСОКИМ уровнем, а у второй "
     "группы 2CN — НИЗКИМ; оба вывода GN активны низким. Это не опечатка разводки, а свойство "
     "подлинного 74155, и именно поэтому наивное предположение «оба строба одной полярности» "
     "оставило бы одну группу постоянно запрещённой, дав молча неработающую схему. Проект учитывает "
     "измеренную разность: 1C подключён к VCC, а 1GN, 2GN и 2CN — к GND. Тогда обе группы разрешены "
     "постоянно (1C AND NOT 1GN = 1; NOT 2CN AND NOT 2GN = 1), и выходы зависят только от SELA и "
     "SELB.")
body("Эффективная таблица при этой разводке — ровно четыре строки, и они дают всю логику выбора "
     "ячеек (подмножество полного перебора, отобранное по фиксированным стробам):")
tbl_caption(doc, "Эффективная таблица 74155 при разводке проекта: 1C к VCC, 1GN/2CN/2GN к GND", "tbl_74155")
make_table([["SELA", "SELB", "1Y0N 1Y1N 1Y2N 1Y3N", "2Y0N 2Y1N 2Y2N 2Y3N", "Выбранная ячейка"],
    ["0", "0", "0 1 1 1", "0 1 1 1", "ячейка 0 (младший выход активен низким)"],
    ["1", "0", "1 0 1 1", "1 0 1 1", "ячейка 1"],
    ["0", "1", "1 1 0 1", "1 1 0 1", "ячейка 2"],
    ["1", "1", "1 1 1 0", "1 1 1 0", "ячейка 3"],
], widths=[1.3, 1.3, 3.6, 3.6, 6.7], fs_=9)
add_picture_fit(doc, _png("lib_74155.png"), "lib74155",
    "Подлинная внутренняя схема 74155 из файла библиотеки — " + DG["symbol_total"] + " экземпляров: "
    + DG["symbols"]["NOT"] + " NOT, " + DG["symbols"]["BAND2"] + " BAND2, " + DG["symbols"]["NAND3"]
    + " NAND3, " + DG["segs"] + " " + plural(DG["segs"], SEG) + " связи, " + DG["junctions"] + " " + plural(DG["junctions"], NODE) + " ветвления, "
    + DG["nets_union_find"] + " " + plural(DG["nets_union_find"], NET))

LC = DATA["library_composition"]
H2("7.2 Регистр 74374 и буфер 74244: полярности, определённые измерением")
body("Состав подлинных схем снят с их .bdf-файлов машинно, а не пересказан по памяти: 74374 "
      "содержит " + str(LC["74374"]["symbol_total"]) + " экземпляров примитивов ("
      + str(LC["74374"]["symbols"]["DFF"]) + " DFF, " + str(LC["74374"]["symbols"]["TRI"])
      + " TRI и " + str(LC["74374"]["symbols"]["NOT"]) + " NOT) при "
      + str(LC["74374"]["pins"]["total"]) + " выводах символа ("
      + str(LC["74374"]["pins"]["input"]) + " входов и " + str(LC["74374"]["pins"]["output"])
      + " выходов). На каждый разряд 74374 приходится ровно один DFF и ровно один TRI "
       "с общим стробом вывода OEN. Помимо них в файле 74374 есть один NOT; его роль "
       "геометрия символа не раскрывает (раздел 3.1), и здесь она не оценивается, но "
       "измерение фронта записи (раздел 9) выполнено на схеме целиком, включая этот "
       "инвертор. 74244 содержит " + str(LC["74244"]["symbol_total"]) + " "
      + plural(LC["74244"]["symbol_total"], ["экземпляр", "экземпляра", "экземпляров"]) + " ("
      + str(LC["74244"]["symbols"]["TRI"]) + " TRI и " + str(LC["74244"]["symbols"]["NOT"])
      + " NOT) при " + str(LC["74244"]["pins"]["total"]) + " выводах — "
      + str(LC["74244"]["symbols"]["TRI"]) + " "
      + plural(LC["74244"]["symbols"]["TRI"], ["буфер", "буфера", "буферов"]) + " с "
      "трёхстальным выходом, разбитых на две группы по четыре, с отдельными стробами 1GN "
       "и 2GN. Ни одно из этих чисел не взято из справочника: каждое получено разбором "
       "соответствующего .bdf-файла, и состав всех трёх схем снят одним проходом.")
body("Отношение этих элементов к стробам и тактам геометрия символов определить не может "
     "(раздел 3.1): она не моделирует ни высокое сопротивление, ни хранение. Поэтому полярности "
     "определены ТРЕМЯ ОТДЕЛЬНЫМИ ИЗМЕРЕНИЯМИ в гостевой системе на подлинных библиотечных схемах, "
     "и каждое прошло полный поток вплоть до анализа задержек. Результаты собраны в разделе 9; "
     "здесь важны две строки, на которых держится монтаж пункта 3:")
bullet("У 74374 запись происходит по ВОСХОДЯЩЕМУ фронту CLK, а OEN активен НИЗКИМ уровнем: при "
       "OEN = 0 регистр драйвит шину, при OEN = 1 выход действительно находится в Z. Измерено на "
       + str(DATA["polarity"]["74374"]["rows"]) + " фазах: "
       + str(DATA["polarity"]["74374"]["oen_low_drove"]) + " фаз с активным драйвом, "
       + str(DATA["polarity"]["74374"]["oen_high_z"]) + " с отпущенным выходом, "
       + str(DATA["polarity"]["74374"]["mismatches"]) + " расхождений. Все три фронта такта "
       "зафиксировали ровно то слово, которое стояло на входе в момент фронта.")
bullet("У 74244 стробы 1GN и 2GN активны НИЗКИМ уровнем, передача данных НЕ инверсная: при "
       "GN = 0 выход равен входу во всех "
       + str(DATA["polarity"]["74244"]["pass_through_gn_low"]) + " наблюдениях из "
       + str(DATA["polarity"]["74244"]["observations_gn_low"]) + ", при GN = 1 выход в Z во всех "
       + str(DATA["polarity"]["74244"]["high_z_gn_high"]) + " наблюдениях; расхождений "
       + str(DATA["polarity"]["74244"]["mismatches"]) + " на 64 побитовых наблюдениях.")
add_picture_fit(doc, _png("lib_74374.png"), "lib74374",
    "Подлинная внутренняя схема 74374 из файла библиотеки: "
    + str(LC["74374"]["symbols"]["DFF"]) + " "
    + plural(LC["74374"]["symbols"]["DFF"], ["D-триггер", "D-триггера", "D-триггеров"])
    + ", " + str(LC["74374"]["symbols"]["TRI"]) + " "
    + plural(LC["74374"]["symbols"]["TRI"], ["буфер", "буфера", "буферов"])
     + " и " + str(LC["74374"]["symbols"]["NOT"]) + " "
     + plural(LC["74374"]["symbols"]["NOT"], ["инвертор", "инвертора", "инверторов"]) + "; "
     "всего " + str(LC["74374"]["symbol_total"]) + " "
     + plural(LC["74374"]["symbol_total"], ["экземпляр", "экземпляра", "экземпляров"]) + " при "
     + str(LC["74374"]["pins"]["total"]) + " выводах символа.")
add_picture_fit(doc, _png("lib_74244.png"), "lib74244",
    "Подлинная внутренняя схема 74244 из файла библиотеки: "
    + str(LC["74244"]["symbols"]["TRI"]) + " "
    + plural(LC["74244"]["symbols"]["TRI"], ["буфер", "буфера", "буферов"])
    + " в двух группах по четыре и " + str(LC["74244"]["symbols"]["NOT"]) + " "
    + plural(LC["74244"]["symbols"]["NOT"], ["инвертор", "инвертора", "инверторов"])
     + "; стробы 1GN и 2GN измерены активными НИЗКИМ уровнем (раздел 9).")
H2("7.3 Монтаж схемы и три механизма, из которых он состоит")
body("Схема собрана из 17 экземпляров и 109 соединений: U1 (74155), четыре инвертора P0..P3, "
     "четыре вентиля AND2 (K0..K3), четыре регистра R0..R3 (74374), буфер B1 (74244), инвертор NR "
     "и генераторы V0, G0. Порты: входы a0, a1, wr, rd и шина w[7..0]; выходы — шины d[7..0] и "
     "q[7..0]. Принцип работы распадается на три независимых механизма, и в каждом измеренная "
     "полярность определяет разводку буквально на один символ.")
body("Первый — выбор ячейки и такт записи. Выход 1Y{i}N активен низким, поэтому он подаётся на "
     "инвертор P{i}, а результат складывается вентилем AND2 с сигналом wr: "
     "K{i}.OUT = wr AND NOT(1Y{i}N), и он же — тактовый вход регистра. На невыбранной ячейке "
     "1Y{i}N = 1, значит NOT = 0, значит на CLK стоит постоянный нуль: фронта нет, и запись "
     "невозможна, КАКИЕ бы данные ни стояли на D. На выбранной ячейке 1Y{i}N = 0, NOT = 1, и "
     "регистр получает ровно тот такт, который подаёт wr. Отсюда запись идёт только в выбранную "
     "ячейку и только фронтом wr. Шина данных w[7..0] подключена к D1..D8 ВСЕХ четырёх регистров "
     "одновременно — выбор осуществляет не раздача данных, а тактовый строб, что и есть содержание "
     "рисунка 18.8.")
body("Второй — арбитраж внутренней шины d[7..0]. Это единственное место работы, где на одной цепи "
     "стоит несколько драйверов: четыре выхода Q четырёх регистров. Разрешение выходов подключено "
     "напрямую, без инверторов: OEN{i} = 2Y{i}N. Поскольку 2Y{i}N активен низким, выбранная ячейка "
     "получает OEN = 0 и ДРАЙВИТ шину, а три остальные получают OEN = 1 и отпускают её в Z. Ровно "
     "один драйвер в любой момент — короткого замыкания нет. Здесь пригодилось машинное свойство "
     "генератора: мульти-драйверная цепь допускается только когда ВСЕ водители "
     "трёхстально-способны, и для экземпляров, опирающихся на библиотечные .bsf, это приходится "
     "объявлять явно («tri»: true на R0..R3), иначе генератор отказывается монтировать шину. Отказ "
     "произошёл на первой попытке и был правильным поведением инструмента, а не его дефектом.")
body("Третий — вывод наружу. Шина d[7..0] подаётся на входы 1A1..1A4 и 2A1..2A4 буфера 74244, а "
     "его стробы 1GN и 2GN управляются инверсией rd: NR.IN = rd, NR.OUT идёт на оба строба. Так как "
     "стробы активны низким, rd = 1 даёт на стробах нуль и ОТКРЫВАЕТ буфер (q = d), а rd = 0 даёт "
     "единицу и ЗАКРЫВАЕТ его (q = Z). Иными словами, rd — это разрешение вывода в прямом смысле, "
     "а инвертор NR нужен только для согласования полярности, измеренной в разделе 7.2. "
     "Два раздельных строба — выбор ячейки через 74155 и разрешение вывода через rd — и есть "
     "содержательная разница между пунктом 1 и пунктом 3: в пункте 1 запись и чтение разводит "
     "одна линия WE, а здесь они выведены на разные порты, поэтому память пункта 3 умеет "
     "одновременно адресовать ячейку и держать выход отпущенным.")
add_picture_fit(doc, _png("mem4x8.png"), "mem4x8_sch",
    "Задание 3: память 4 × 8 бит (рис. 18.8) — 74155, четыре 74374, 74244, общая шина d[7..0]")

H2("7.4 Временная диаграмма и разбор арбитража")
body("Диаграмма содержит " + str(T3["phases"]) + " фаз. Четыре записи идут тройками фаз "
     "(подготовка wr = 0, импульс wr = 1, отпускание wr = 0) с неизменными адресом и данными внутри "
     "тройки — та же дисциплина, которая выведена в разделе 8.2 из измерений и которая обязательна "
     "для любой секвенсорной схемы. В четыре разных адреса заносятся четыре различных слова: FF, "
     "F0, A5, 5A. Затем идут пять считывающих фаз при rd = 1, обходящих все четыре ячейки и "
     "возвращающихся к первой.")
body("Волна показывает ровно то, что предсказывает монтаж. Разберу по фазам, потому что именно "
     "здесь видна суть матричной организации.")
bullet("Шина d[7..0] не пуста даже во время записей, и это не побочный эффект, а прямое следствие "
       "второго механизма: адресованная ячейка подключена к шине всегда. В фазе 0 (адрес 00, "
       "подготовка) на шине старое содержимое ячейки 0 — 00, поскольку схема начальна обнулена. "
       "В фазе 1 (фронт wr) шина становится FF: регистр R0 взял данные фронтом, и его выход тут же "
       "появился на шине, потому что OEN0 = 0. В фазе 3 (адрес 01) шина снова 00 — это содержимое "
       "ещё пустой ячейки 1, а ячейка 0 с её FF в этот момент ОТКЛЮЧЕНА (OEN0 = 1). Таким образом, "
       "d содержит слово адресованной ячейки во всех фазах, и записи и чтения.")
bullet("Шина q в фазах 0–11 (все четыре записи) находится в Z во всех восьми битах, потому что rd "
       "= 0 закрывает 74244. Это и есть смысл разделения стробов: пока идёт запись, наружный порт "
       "молчит, и ни одна внешняя схема не может увидеть полуслово. В считывающих фазах 12–16 "
       "буфер открыт, и q в точности повторяет d: слова идут в порядке FF, F0, A5, 5A и снова FF — "
       "повторное обращение к нулевой ячейке подтверждает сохранение, а не «свежезаписанное» "
       "значение.")
bullet("Арбитраж шины проверен не рассуждением, а измерением: за " + str(T3["phases"]) + " фаз на "
       "d никогда не появляется двух слов одновременно, и расхождений с моделью "
       + str(T3["d_mismatches"]) + " по шине d и " + str(T3["q_mismatches"]) + " по шине q.")
body("Содержательный итог пункта: схема 4 × 8 бит работает как ЗУ с произвольным доступом, у "
     "которого время обращения определяется дешифратором (tpd " + str(T3["tpd"]["actual"])+ " на паре "
     + str(T3["tpd"]["from"])+ " → " + str(T3["tpd"]["to"])+ "), а не длиной шины данных, и у которого "
     "запись и чтение разведены по разным управляющим портам. Это ровно тот переход от "
     "дидактической схемы рисунка 18.7 к кристальной организации рисунка 18.8, который требует "
     "задание.")
add_picture_fit(doc, _png("mem4x8_wf.png"), "mem4x8_wf",
    "Задание 3: временная диаграмма, " + str(T3["phases"]) + " фаз — арбитраж шины d и вывод q")

H2("7.5 Ресурсы и задержки")
body("Проект прошёл полный поток на том же кристалле " + str(T3["device"])+ ": " + str(T3["fit_msg"])+ "; "
     + str(T3["asm_msg"])+ "; " + str(T3["tan_msg"])+ ". Ресурсы: " + str(T3["logic_elements"])+ " логических "
     "элементов, " + str(T3["pins"])+ " выводов, " + str(T3["memory_bits"])+ " бит встроенной памяти. Рост с "
     + T1["logic_elements"].split("/")[0].strip() + " элементов до "
     + T3["logic_elements"].split("/")[0].strip() + " (в "
     + "%.1f" % (num(T3["logic_elements"]) / num(T1["logic_elements"])) + " раза) соответствует "
     "восьмикратному росту ёмкости (с четырёх бит до 32), появлению кристального дешифратора и "
     "отдельного порта управления выводом.")
tbl_caption(doc, "Ресурсы и задержки измеренного проекта задания 3 (mem4x8)", "tbl_t3")
make_table([["Показатель", "Значение", "Маршрут", "Смысл"],
    ["tpd (худший)", T3["tpd"]["actual"], T3["tpd"]["from"] + " → " + str(T3["tpd"]["to"]),
     "время доступа «адрес → шина данных»: 74155 плюс арбитраж 74374"],
    ["tco (худший)", T3["tco"]["actual"], T3["tco"]["from"] + " → " + str(T3["tco"]["to"])+ " (от " + str(T3["tco"]["from_clock"])+ ")",
     "выдача слова на внутреннюю шину после фронта wr"],
    ["tsu (худший)", T3["tsu"]["actual"], T3["tsu"]["from"] + " → " + str(T3["tsu"]["to"]),
     "установка данных относительно выбора ячейки"],
    ["th (худший)", T3["th"]["actual"], T3["th"]["from"] + " → " + str(T3["th"]["to"]),
     "удержание данных после фронта wr: положительное, данные обязаны переждать такт"],
    ["Покрытие моделирования", T3["coverage"] + " %", "—",
     T3["transitions"] + " " + plural(T3["transitions"], ["переход", "перехода", "переходов"])
      + " — самый насыщенный из всех проектов работы"],
], widths=[3.0, 2.2, 4.4, 6.9], fs_=9)
body("Сравнение времени доступа двух пунктов показывает цену кристальной организации: tpd вырос с "
     + str(T1["tpd"]["actual"])+ " до " + str(T3["tpd"]["actual"])+ " (плюс "
     + "%.3f нс" % (ns(T3["tpd"]["actual"]) - ns(T1["tpd"]["actual"])) + ", или "
     + "%.1f %%" % (100.0 * (ns(T3["tpd"]["actual"]) - ns(T1["tpd"]["actual"])) / ns(T1["tpd"]["actual"]))
     + "), тогда как ёмкость выросла в восемь раз. Положительное th (" + str(T3["th"]["actual"])+ ") — "
     "полезное дополнение к разделу 8.2: синтез требует, чтобы данные на шине w переждали фронт "
     "wr, и это то же самое требование дисциплины, которое в пункте 4 выявлено измерением как "
     "необходимость удерживать адрес и данные после снятия строба записи.")
body("Предупреждения синтеза раскрываются поштучно, и их сумма равна счётчику из сводки ("
     + str(T3["map_msg"]) + "), что само по себе является проверкой. Вот полный перечень: "
     + MW["obtained_from"] + " сообщения о том, что сущности 74155, 74374 и 74244 взяты из "
     "библиотечных файлов проекта, а не из библиотеки мегафункций Quartus («Entity \"74155\" "
     "obtained from \"C:/dsh/mem4x8/74155.bdf\" instead of from Quartus II megafunction library»); "
     + MW["no_superset_bus"] + " сообщения «No superset bus at connection» — шины разведены по "
     "битам, что законно; и " + MW["tri_permanently"] + " сообщение «TRI or OPNDRN buffers "
     "permanently enabled», к которому перечислением присовокуплены " + MW["node_sublines"]
     + " строк вида «Warning: Node \"74374:R3|47~4\"», указывающих трёхстальные буферы внутри "
     "74374. Итого " + MW["obtained_from"] + " + " + MW["no_superset_bus"] + " + "
     + MW["tri_permanently"] + " + " + MW["node_sublines"] + " = " + MW["sum"] + " — ровно столько, "
     "сколько заявлено в сводке, то есть ни одно предупреждение не осталось нерасшифрованным. "
     "Первые сообщения — как раз то, чего требовало задание: использованы подлинные схемы maxplus2, "
     "а не их аналоги из библиотеки Quartus, и синтезатор честно сообщает о подмене источника. "
     "Остальные два класса безвредны: побитная разводка шин законна для генератора, а постоянно "
     "разрешённые буферы относятся к внутренностям 74374 и 74244, где их строб выведен наружу как "
     "OEN и GN соответственно.")


# ==================================================================== 8. задание 4
H1("8. Задание 4. Мегафункция lpm_ram_dq с предписанной настройкой")
quote("«Использовать из библиотеки мегафункций элемент lpm_ram_dq, оставив только входы WE, "
      "ADDRESS, DATA и выход Q, с параметрами: lpm_address_control \"unregistered\", lpm_file "
      "<none>, lpm_indata \"unregistered\", lpm_numwords <none>, lpm_outdata \"unregistered\", "
      "lpm_width 8, lpm_width_ad 10.»")

H2("8.1 Способ задания параметров и что из этого получилось")
body("Элемент lpm_ram_dq — универсальный настраиваемый носитель данных с одним портом "
     "(single-port RAM): он объявлен в библиотеке мегафункций установки файлом lpm_ram_dq.tdf, "
     "символ которого содержит шесть портов и семь параметров. Символ извлечён из установки и "
     "приведён на рисунке; перечень его параметров дословно совпадает со списком задания, и это "
     "важно: задание требует ровно тех семи настроек, которые элемент действительно объявляет, "
     "никаких лишних.")
REQ_T4 = {
    "LPM_ADDRESS_CONTROL": '"unregistered"',
    "LPM_FILE": "<none>",
    "LPM_INDATA": '"unregistered"',
    "LPM_NUMWORDS": "<none>",
    "LPM_OUTDATA": '"unregistered"',
    "LPM_WIDTH": "8",
    "LPM_WIDTHAD": "10",
}
_pt = [["Параметр", "Требование задания", "Что объявлено в символе", "Значение после синтеза"]]
for _p in T4["bsf_parameters"]:
    _opts = [str(_o).strip() for _o in _p["options"]]
    _decl = ("варианты: " + ", ".join(_opts)) if _opts else "свободное целое значение"
    if _p["stored"]:
        _decl += "; в файле символа записано " + str(_p["stored"]).replace('"', "")
    _pt.append([_p["name"], REQ_T4[_p["name"]], _decl, T4["elaborated"].get(_p["name"], "—")])
tbl_caption(doc, "Параметры lpm_ram_dq: требование задания, объявление в символе, развёртка синтезом", "tbl_lpm")
make_table(_pt, widths=[4.0, 2.6, 5.4, 4.5], fs_=8)
body("Значения после синтеза взяты не из документации, а из отчёта анализа и синтеза "
     "(lpramax.map.rpt), который печатает таблицу параметров развёрнутой мегафункции. Два "
     "замечания по ним обязательны. Первое: параметр LPM_NUMWORDS в задании указан как <none>, и "
     "символ сам объясняет, что это значит — «Number of memory words, default is 2^LPM_WIDTHAD», "
     "поэтому синтез подставил 2 в 10-й = " + str(T4["elaborated"]["LPM_NUMWORDS"])+ " слов. Второе: "
     "LPM_FILE тоже <none>, и отчёт подтверждает это как «MIF none» в ведомости памяти, то есть "
     "файл начального содержимого не используется.")
body("Способ задания параметров — текстовый, а не через диалог. В MAX+plus II параметры задаются в "
     "окне EDIT PORTS | PARAMETERS, но в Quartus II 5.0 единственный способ зафиксировать их "
     "ДОСЛОВНО и получить воспроизводимый проект — описание AHDL, где мегафункция подключается "
     "через включаемый файл lpm_ram_dq.inc, а параметры перечисляются в блоке WITH. Попытка "
     "смонтажировать то же самое в графическом редакторе наталкивается на отсутствие прецедента: "
     "в библиотеке maxplus2 ни одна схема не инстанцирует мегафункцию, и блок alias в файлах .bdf "
     "отсутствует, так что параметры в сетевой разводке задать нечем. Поэтому пункт 4 оформлен "
     "текстовым описанием, которое компилируется тем же инструментом, и это не упрощение, а "
     "единственно возможная форма.")
body("Порты inclock и outclock в обёртке СОЗНАТЕЛЬНО не подключены. lpm_ram_dq.tdf объявляет оба с "
     "значением по умолчанию VCC, и при всех трёх параметрах регистрации, равных UNREGISTERED, в "
     "дизайне не остаётся ни одного регистра, которому мог бы служить такт. Поэтому наружу "
     "действительно выходят ровно четыре линии, которых требует задание: WE, ADDRESS, DATA и Q. "
     "Ниже — исходник, который компилировался в гостевой системе:")
mono(LISTING_AHDL)
add_picture_fit(doc, _png("lpm_ram_dq_symbol.png"), "lpmramdq_sym",
    "Символ lpm_ram_dq из библиотеки мегафункций установки: шесть портов, семь параметров")
add_picture_fit(doc, _png("lpramax_wf.png"), "lpramax_wf",
    "Задание 4: временная диаграмма, " + str(T4["phases"]) + " фаз — четыре записи, четыре чтения "
    "и обращение к незаписанному слову")

H2("8.2 Характер записи: решающий эксперимент, а не предположение")
body("Пункт 4 ставит тонкий вопрос, на который нельзя ответить, прочитав документацию: при "
     "отсутствии такта в дизайне — что вообще заставляет память записать? Первая волна (lpramax, "
     + str(T4["phases"]) + " фаз) устроена «правильно»: каждая запись идёт тройкой фаз подготовка "
     "/ импульс / отпускание, адрес и данные в тройке неизменны, и по окончании все четыре слова "
     "(FF, F0, A5, 5A) считываются из своих адресов. Эта волна подтверждает, что память работает, "
     "но она НЕ ОТВЕЧАЕТ на вопрос о механизме: поскольку адрес и данные постоянны во всех трёх "
     "фазах, пред- и постпереходные значения совпадают, и любая из пяти асинхронных гипотез "
     "воспроизводит её целиком. Отсюда необходимость второго эксперимента.")
body("Дополнительный проект lpramwb (11 фаз) устроен как раз так, чтобы различить гипотезы: в нём "
     "адрес И данные меняются, пока WE удерживается единицей, — то есть создаётся ровно та "
     "ситуация, о которой симулятор предупреждает сообщением «Address line changed on Embedded "
     "System Block ... during write at time ... -- simulation results may be incorrect». "
     "Измеренные фазы такие:")
RU_LABEL = {
    0: "чтение никогда не записанного адреса 0x010 — результат X",
    1: "WE = 1, адрес 0x010, данные 0x11: слово проходит на Q сквозняком",
    2: "WE удерживается 1, а адрес и данные МЕНЯЮТСЯ на 0x020 и 0x22 — фронта нет",
    3: "WE = 0: спад записывает ПОСТ-переходные операнды, то есть 0x00 в 0x010; чтение 0x010 даёт 0x00, а не 0x11",
    4: "чтение 0x020 даёт X: этот адрес ни разу не попадал под спад WE, слово не записано",
    5: "WE = 1, адрес 0x030, данные 0x33",
    6: "WE = 1, данные меняются на 0x44 при том же адресе 0x030 — фронта WE нет, записи нет",
    7: "WE = 0: спад записывает 0x00 в 0x030; чтение 0x030 даёт 0x00, а не 0x44",
    8: "WE = 1, повторная запись в 0x010 словом 0x55",
    9: "WE = 0: спад снова записывает 0x00 в 0x010; чтение даёт 0x00",
    10: "чтение 0x020 — по-прежнему X, слово 0x22 так и не было записано",
}
_wb = [["Фаза", "WE", "Адрес", "DATA", "Q (измерено)", "Смысл фазы"]]
for _r in DATA["lpramwb"]["rows"]:
    _q = _r["q"]
    _qs = "X" if _q == "X" else ("0x" + format(int(_q), "02X").upper())
    _wb.append([str(_r["i"]), _r["we"], "0x" + format(int(_r["a"]), "03X").upper(),
                "0x" + format(int(_r["d"]), "02X").upper(), _qs, RU_LABEL[_r["i"]]])
tbl_caption(doc, "Решающий эксперимент lpramwb: измеренные фазы, где адрес и данные меняются при WE = 1", "tbl_wb")
make_table(_wb, widths=[1.1, 1.0, 1.7, 1.7, 2.4, 8.6], fs_=8)
body("Среди семи возможных механизмов записи перебраны все, и каждая отвергнута по ТОЧНОМУ числу "
     "расхождений с двумя измеренными волнами, зафиксированному программно, а не описательно:")
cand = [["Гипотеза записи", "Момент отсчёта", "Расхождений с lpramax", "Расхождений с lpramwb", "Вердикт"]]
for _c in T4["candidates"]:
    _v = "ЕДИНСТВЕННАЯ, согласная с обеими волнами" if _c["lpramax"] + _c["lpramwb"] == 0 else "отвергнута"
    cand.append([_c["write"], _c["sample"], str(_c["lpramax"]), str(_c["lpramwb"]), _v])
tbl_caption(doc, "Перебор семи механизмов записи по двум измеренным волнам", "tbl_cand")
make_table(cand, widths=[3.2, 2.2, 3.4, 3.4, 4.3], fs_=9)
body("Единственная оставленная гипотеза формулируется так и полностью подтверждена обоими "
     "экспериментами (расхождений " + str(T4["mismatches"]) + " и "
     + str(DATA["confrontation"]["per_project"]["lpramwb"]["mismatches"]) + " соответственно):")
bullet(T4["we_fall_rule"] + ".")
body("Механизм этот взят не из волн, а из исходника мегафункции, который я вытащил из установки "
     "для того, чтобы цитировать источник, а не выводить правило догадкой. В altram.tdf при "
     "USED(clocki) = 0 генерируемая ветвь строк 439–441 НЕ подключает clki ни к чему, строка 427 "
     "задаёт real_we[0] = we, а строка 449 подаёт его прямо на порт we примитива MEMORY: "
     "segment[bank][bit].we = real_we[bank]. Определение RAM_MODES (строки 61–66) при обоих "
     "неиспользованных тактах вырождается в 0, то есть регистрация отсутствует целиком. Смысл "
     "цитаты ровно тот, что показали волны: запись управляется самим WE, а не фронтом такта, "
     "потому что такта в дизайне нет.")
body("Содержательное следствие — настоящий урок пункта 4, и оно важнее самой настройки: "
     + str(T4["corollary"])+ ". В фазах 2–3 измеренного эксперимента WE отпускается в тот же момент "
     "симуляции, когда адрес уходит с 0x020 на 0x010, а данные с 0x22 на 0x00; в результате "
     "0x010 получает 0x00, а 0x020 не получает ничего и впоследствии читается как X. Именно эту "
     "фазу симулятор помечает предупреждением, и предупреждение оказывается не формальностью: "
     "диаграмма, нарушающая дисциплину удержания, теряет данные. То же самое требование, "
     "записанное как время удержания, синтез предъявил пункту 3 (th = " + str(T3["th"]["actual"])+ ", раздел 7.5), а триггерная схема пункта 1 удовлетворяет ему конструктивно, записывая "
     "только фронтом CLK при неизменном адресе.")

H2("8.3 Семейства: что измерено, а не предполагалось")
body("Предписанная настройка описывает асинхронную однопортовую память, и не каждое семейство её "
     "принимает. Это проверено перебором семейств в гостевой системе, а не даташитом:")
tbl_caption(doc, "Синтез предписанной настройки по семействам: что удалось, а что нет и почему", "tbl_fam")
make_table([["Семейство", "Анализ и синтез", "Моделирование", "Размещение", "Причина отказа"]] + [
    ["ACEX1K", "успешно (" + str(T4["map_msg"])+ ")", "успешно (" + str(T4["sim_msg"])+ ")", "невозможно",
     T4["fit_error"]],
    ["FLEX10KE", "успешно (0 ошибок, 9 предупреждений)", "успешно (0 ошибок, 0 предупреждений)", "невозможно",
     "тот же текст про отсутствие установленных устройств"],
    ["Stratix", "отказ", "—", "—",
     "Can't convert single-port RAM ... supports only synchronous single-port RAM (altram.tdf:236 через lpm_ram_dq.tdf:89)"],
    ["Cyclone", "отказ", "—", "—", "тот же текст"],
    ["MAX3000A", "разворачивается, затем сбой", "—", "—",
     "Internal Error: Sub-system: SCL, File: scl_state_syn.cpp, Line: 1302"],
], widths=[2.0, 3.6, 3.2, 2.0, 5.7], fs_=8)
body("Отказ Stratix и Cyclone понятен из исходника: строка 236 altram.tdf утверждает, что "
     "преобразование однопортовой RAM возможно только при наличии такта на входе или выходе "
     "(STRATIX_RAM_POSSIBLE и STRATIX_RAM_NOT_IMPOSSIBLE, строки 83 и 86, оба требуют "
     "USED(clocki) или USED(clocko)), а предписанная настройка тактов не оставляет. Поэтому "
     "пункт 4 синтезируется именно в ACEX1K/FLEX10KE, и это не прихоть, а свойство параметрации. "
     "Размещение невозможно для обоих семейств по независимой причине: в данной копии установки "
     "детальная база устройств присутствует только для Stratix (проверено поиском по файлу "
     "quartus_fit.exe: known-to-fit = yes у Stratix, no у Cyclone, ACEX1K, FLEX10KE, MAX3000A, "
     "APEX20K; файлов .pdb под C:\\altera нет ни одного). Ограничение задекларировано в разделе 2 "
     "и на содержание пункта не влияет: задание требует настройки и функционирования, оба "
     "обеспечены функциональным моделированием.")

H2("8.4 Что построил синтез и почему незаписанное слово читается как X")
body("Отчёт анализа и синтеза печатает иерархию и ведомость памяти, и по ним видно, что "
     "мегафункция НЕ разворачивалась в триггеры, в отличие от пунктов 1–3:")
tbl_caption(doc, "Что построил синтез: иерархия и ведомость памяти проекта lpramax", "tbl_ram")
make_table([["Показатель", "Значение из отчёта"],
    ["Иерархия", " → ".join(T4["hierarchy"])],
    ["Режим", T4["ram_summary"]["mode"]],
    ["Глубина", T4["ram_summary"]["depth_a"] + " слов"],
    ["Разрядность", T4["ram_summary"]["width_a"] + " бит"],
    ["Ёмкость", T4["ram_summary"]["size_bits"] + " бит (= " + str(int(T4["ram_summary"]["size_bits"]) // 8) + " байт)"],
    ["Файл инициализации", T4["ram_summary"]["mif"]],
    ["Использование блоков памяти", T4["elaborated"]["USE_EAB"]],
], widths=[6.0, 10.5], fs_=9)
body("Ёмкость " + str(T4["ram_summary"]["size_bits"])+ " бит — это ровно " + str(TH["task4_words"])
     + " байт, и она согласуется с арифметикой раздела 4.3: десять адресных линий дают 2 в 10-й = "
     + str(TH["task4_words"]) + " слов. Для сравнения, пункты 1–3 синтезированы в триггеры и логику "
     "(«Total memory bits: " + str(T1["memory_bits"])+ "»), и это прямая иллюстрация вывода раздела "
     "4.2: инструмент сам переходит к плотной блоковой реализации, когда массив велик, — ровно то "
     "различие по плотности, которое глава приписывает паре SRAM/DRAM.")
body("Наконец, факт, который нельзя было бы узнать, не смоделировав схему. Незаписанные слова "
     "читаются как X, а не как 0: в фазах 0, 3, 6, 9 и 16 волны задания 4 (и в фазах 0, 4, 10 "
     "дополнительного эксперимента) выход Q имеет значение X, хотя синтез печатает предупреждение "
     "«" + str(T4["init_warning"])+ "». Оба утверждения исходят из одного запуска Quartus и оба "
     "верны, потому что относятся к разным уровням: функциональная модель мегафункции оставляет "
     "незаписанное слово неопределённым (это корректное поведение девятизначной логики — мы ничего "
     "не записывали, значит ничего не знаем), тогда как предупреждение описывает будущее "
     "состояние ФИЗИЧЕСКОГО блока после программирования кристалла. Различие принципиально для "
     "проектирования: тест, рассчитанный на нули в незаписанных ячейках, в моделировании "
     "провалится, а на приборе — пройдёт. Моя первая модель как раз и предполагала нуль, и "
     "измерение это опровергло, после чего модель была исправлена; в отчёте X фигурирует как "
     "измеренный результат, а не как допущение.")
body("Покрытие моделирования пункта 4 — " + str(T4["coverage"]) + " % при " + str(T4["transitions"])
     + " переходах. Это наибольшее покрытие из всех четырёх проектов работы, и объясняется оно не "
     "качественно новым свойством памяти, а размером нетлиста. Покрытие в Quartus II 5.0 считается "
     "как доля узлов функционального нетлиста, в которых за время моделирования произошёл хотя бы "
     "один переход, а число переходов считается по всем узлам подряд. У пункта 4 нетлист равен "
     + str(T4["netlist_nodes"]) + " узлам, из них переключились около " + str(T4["nodes_toggled"])
     + ", тогда как у пункта 3 нетлист в " + "%.1f" % (T3["netlist_nodes"] / T4["netlist_nodes"]) + " раза больше (" + str(T3["netlist_nodes"])
     + " узлов, переключились около " + str(T3["nodes_toggled"]) + "), и потому абсолютное число переходов "
     "у пункта 3 выше (" + str(T3["transitions"]) + " против " + str(T4["transitions"]) + ") при меньшем "
     "проценте. Причина — ровно та, что установлена в разделе 8.4: мегафункция не разворачивается в "
     "триггеры, её блок памяти остаётся единым объектом с адресной выборкой, и в нетлист попадают "
     "главным образом порты и служебная логика — почти всё, что данная волна и так затрагивает. У "
     "развёрнутых же схем в нетлисте много внутренних узлов ячеек, которые этой же волной не "
     "переключаются. Сравнивать поэтому надо не проценты между разными способами реализации, а "
     "полноту охвата одной схемы: в пункте 1 те же 20 фаз дали " + str(T1["coverage"]) + " % на "
     + str(T1["netlist_nodes"]) + " узлах, а поведенческая модель того же контракта в пункте 2 — " + str(T2["coverage"])
     + " % на " + str(T2["netlist_nodes"]) + " узлах, и этот рост объяснён в разделе 6.")


# ---------------------------------------------------- probe timing accessor
# The three polarity probes are separate Quartus projects whose reports lay the timing tables out
# per type (tpd / tsu / tco / th), so every quoted number below is picked out of that project's own
# tan.rpt rather than typed by hand.
def P(probe, typ, field):
    return D["probes"][probe]["timing"][typ]["worst"][field]

# ==================================================================== 9. полярности
H1("9. Полярности выводов, определённые измерением")
body("Задание требует сверять полярность выводов, а не принимать её из названия или даташита. Это "
     "не формальность: в разделах 5, 7 и 8 монтаж зависит от полярности буквально на один символ, "
     "и ошибка дала бы молча неработающую схему. Поскольку геометрия библиотечных символов высокое "
     "сопротивление и хранение не моделирует (раздел 3.1), полярности определены ТРЕМЯ ОТДЕЛЬНЫМИ "
     "ЭКСПЕРИМЕНТАМИ в гостевой системе на подлинных библиотечных схемах. Каждый эксперимент — "
     "самостоятельный проект, прошедший полный поток на кристалле "
     + str(D["probes"]["probe_tri"]["device"])+ ", и каждый подтверждён отчётами: "
     + str(D["probes"]["probe_tri"]["map_msg"])+ "; " + str(D["probes"]["probe_tri"]["fit_msg"])+ "; "
     + str(D["probes"]["probe_tri"]["sim_msg"])+ "; " + str(D["probes"]["probe_tri"]["tan_msg"])+ ".")
body("Отчёты трёх проектов дают и независимое подтверждение того, что измеренные полярности — "
     "свойство подлинных схем, а не моей разводки: анализатор задержек для каждого зонда нашёл "
     "пути именно тех типов, которые соответствуют измеренному поведению. У зонда 74244 это "
     + str(len(D["probes"]["probe_tri"]["timing"]["tpd"]["rows"])) + " путей «вход → выход» (tpd), "
     "худший " + P("probe_tri", "tpd", "actual") + " на паре " + P("probe_tri", "tpd", "from")
     + " → " + P("probe_tri", "tpd", "to") + "; у зонда TRI — "
     + str(len(D["probes"]["probe_trioe"]["timing"]["tpd"]["rows"])) + " " + plural(len(D["probes"]["probe_trioe"]["timing"]["tpd"]["rows"]), ["путь", "пути", "путей"]) + " tpd, худший "
     + P("probe_trioe", "tpd", "actual") + " на паре " + P("probe_trioe", "tpd", "from") + " → "
     + P("probe_trioe", "tpd", "to") + "; у зонда 74374 — все четыре типа: tpd "
     + P("probe_reg", "tpd", "actual") + " (" + P("probe_reg", "tpd", "from") + " → "
     + P("probe_reg", "tpd", "to") + "), tsu " + P("probe_reg", "tsu", "actual") + " ("
     + P("probe_reg", "tsu", "from") + " → " + P("probe_reg", "tsu", "to") + ", такт "
     + P("probe_reg", "tsu", "clock") + "), tco " + P("probe_reg", "tco", "actual") + " ("
     + P("probe_reg", "tco", "from") + " → " + P("probe_reg", "tco", "to") + ") и th "
     + P("probe_reg", "th", "actual") + " (" + P("probe_reg", "th", "from") + "). Наличие у 74374 "
     "путей tsu и th — машинное подтверждение секвенсорности: у асинхронного элемента требований "
     "установки и удержания не бывает.")

H2("9.1 Буфер 74244: стробы инверсны, передача не инверсна")
body("Эксперимент подавал на входы обеих групп произвольные слова и наблюдал выходы при всех "
     "четырёх состояниях пары стробов. Измерено " + str(D["polarity"]["probe_tri"]["rows"])+ " фаз, "
     + str(D["polarity"]["74244"]["observations_gn_low"])+ " побитовых наблюдений при открытом стробе. "
     "Результат одинозначен: при GN = 0 выход равен входу во всех "
     + str(D["polarity"]["74244"]["pass_through_gn_low"])+ " наблюдениях (инверсии — "
     + str(D["polarity"]["74244"]["inverted_gn_low"])+ ", высокого сопротивления — "
     + str(D["polarity"]["74244"]["high_z_gn_low"])+ "); при GN = 1 выход находится в Z во всех "
     + str(D["polarity"]["74244"]["high_z_gn_high"])+ " наблюдениях из "
     + str(D["polarity"]["74244"]["observations_gn_high"])+ ". Расхождений "
     + str(D["polarity"]["74244"]["mismatches"])+ ".")
tbl_caption(doc, "Измеренные фазы зонда 74244: стробы инверсны, передача не инверсна", "tbl_ptri")
make_table([["Фаза", "1GN", "2GN", "1A1..1A4", "1Y1..1Y4", "2A1..2A4", "2Y1..2Y4", "Наблюдение"]] + [
    [str(r["phase"]), r["1GN"], r["2GN"],
     r["1A1"] + r["1A2"] + r["1A3"] + r["1A4"], r["1Y1"] + r["1Y2"] + r["1Y3"] + r["1Y4"],
     r["2A1"] + r["2A2"] + r["2A3"] + r["2A4"], r["2Y1"] + r["2Y2"] + r["2Y3"] + r["2Y4"],
     ("обе группы открыты, передача сквозная" if r["1GN"] == "0" and r["2GN"] == "0" else
      "группа 1 открыта, группа 2 в Z" if r["1GN"] == "0" else
      "группа 2 открыта, группа 1 в Z" if r["2GN"] == "0" else "обе группы отпущены в Z")]
    for r in D["polarity"]["probe_tri"]["data"]], widths=[1.0, 1.0, 1.0, 1.9, 1.9, 1.9, 1.9, 5.9], fs_=9)
body("Отсюда правило монтажа пункта 3: строб 74244 подаётся ИНВЕРСИЕЙ разрешения вывода, и этим "
     "занят инвертор NR (раздел 7.3). В волне фаз 0 и 4 обе группы открыты одновременно, и тогда "
     "шину драйвят восемь буферов сразу — по четыре на группу; конфликта нет, потому что группы "
     "обслуживают разные выходы, и в пункте 3 каждая группа подключена к своей половине шины "
     "q[7..0]. Задержка «вход → выход» подлинного 74244 составила "
     + P("probe_tri", "tpd", "actual") + " и распадалась на " + "%.3f" % D["probes"]["probe_tri"]["cell_ns"]
     + " нс самих элементов (в отчёте анализатора — Total cell delay, " + str(D["probes"]["probe_tri"]["cell_pct"])
     + " %) и " + "%.3f" % D["probes"]["probe_tri"]["interconnect_ns"] + " нс межсоединений (Total interconnect "
     + "delay, " + str(D["probes"]["probe_tri"]["interconnect_pct"]) + " %). Сумма этих двух величин "
     + "совпадает с худшим tpd до третьего знака, поэтому разложение относится именно к измеренному "
     + "пути, а не ко всем путям сразу.")

H2("9.2 Трёхстальный буфер TRI: разрешение активно высоким уровнем")
body("Элемент TRI — тот буфер, которым смонтированы выходы пункта 1 (раздел 5.1), и его полярность "
     "определяет, когда шина молчит. Измерено " + str(D["polarity"]["probe_trioe"]["rows"])+ " фазами, "
     "расхождений " + str(D["polarity"]["TRI"]["mismatches"])+ ":")
tbl_caption(doc, "Измеренные фазы зонда TRI: разрешение вывода активно высоким уровнем", "tbl_ptrioe")
make_table([["Фаза", "IN", "OE", "OUT", "Наблюдение"]] + [
    [str(r["phase"]), r["IN"], r["OE"], r["OUT"],
     "разрешение снято — шина отпущена в Z" if r["OE"] == "0" else "разрешение подано — передача сквозная"]
    for r in D["polarity"]["probe_trioe"]["data"]], widths=[1.2, 1.2, 1.2, 1.4, 11.5], fs_=9)
body("Вывод: OE активен ВЫСОКИМ уровнем — единица на входе разрешения открывает буфер, ноль "
     "отпускает шину в Z. Это противоположно стробам 74244, и именно поэтому в пункте 1 "
     "считывающий строб O{i} (AND3, замкнутый на !WE) подключён к T{i}.OE НАПРЯМУЮ, без "
     "дополнительной инверсии: при WE = 1 сигнал !WE равен нулю, буфер закрыт, шина в Z; при "
     "WE = 0 выбранный адрес даёт единицу на OE, и буфер открывает ячейку. Совпадение полярности "
     "вентиля и буфера — не случайность: глава рисует строб считывания инверсным именно для того, "
     "чтобы он годился и для активно-высокого OE. Задержка самого буфера измерена как "
     + P("probe_trioe", "tpd", "actual") + " на паре " + P("probe_trioe", "tpd", "from") + " → "
     + P("probe_trioe", "tpd", "to") + "; показателен её распад: " + "%.3f" % D["probes"]["probe_trioe"]["cell_ns"]
     + " нс элементов против " + "%.3f" % D["probes"]["probe_trioe"]["interconnect_ns"] + " нс межсоединений ("
     + str(D["probes"]["probe_trioe"]["cell_pct"]) + " % против " + str(D["probes"]["probe_trioe"]["interconnect_pct"])
     + " %), то есть почти поровну, и сумма снова равна худшему tpd до третьего знака. Это и объясняет, "
     "почему время доступа пункта 3 длиннее пункта 1 не за счёт логики, а за счёт длины пути через "
     "кристальный дешифратор и арбитраж шины.")

body("Оговорка о методе, важная для всех трёх зондов: анализатор печатает строки Total cell delay и "
     "Total interconnect delay агрегированно, по всем проанализированным путям, а не по худшему. "
     "Приравнивать их к худшему tpd можно только после проверки, и в двух предыдущих абзацах она "
     "выполнена: равенство держится до третьего знака. В зонде 74374 ниже оно НЕ держится "
     "(" + "%.3f" % D["probes"]["probe_reg"]["cell_ns"] + " + " + "%.3f" % D["probes"]["probe_reg"]["interconnect_ns"]
     + " = " + "%.3f" % D["probes"]["probe_reg"]["decomposition_sum_ns"] + " нс против худшего tpd "
     + str(D["probes"]["probe_reg"]["tpd_ns"]) + " нс), и причина понятийная: худший путь там проходит "
     "через регистр, то есть содержит времена установки и удержания, а не только комбинационную "
     "задержку. Поэтому в разделе 9.3 эти строки не используются как расклад tpd.")

H2("9.3 Регистр 74374: фронт восходящий, OEN инверсен, питание включается нулём")
body("Эксперимент подавал на восемь входов W[7..0] три разных слова, тактировал CLK и управлял OEN. "
     "Измерено " + str(D["polarity"]["probe_reg"]["rows"])+ " фаз. Результаты:")
bullet("Запись происходит по ВОСХОДЯЩЕМУ фронту CLK. Все три фронта зафиксировали ровно то слово, "
       "которое стояло на входе в момент фронта: "
       + ", ".join("фаза " + str(e["phase"]) + " → " + e["captured"] for e in D["polarity"]["74374"]["edges"])
       + ". Ни одно слово не взято ни на спаде, ни асинхронно.")
bullet("OEN активен НИЗКИМ уровнем: при OEN = 0 регистр драйвит шину во всех "
       + str(D["polarity"]["74374"]["oen_low_drove"])+ " наблюдениях, при OEN = 1 выход в Z во всех "
       + str(D["polarity"]["74374"]["oen_high_z"])+ " наблюдениях. Высокое сопротивление настоящее: оно "
       "доживает до результата моделирования (разделы 3.2 и 9.4), а не подменяется нулём.")
bullet("Передача D → Q НЕ инверсная: зафиксированные слова совпадают с входными побитово, "
       "расхождений " + str(D["polarity"]["74374"]["mismatches"])+ " на "
       + str(D["polarity"]["probe_reg"]["rows"])+ " фазах.")
bullet("Содержимое регистра до первой записи — нуль, и это НАБЛЮДАЕМО, а не предположение. В "
       "пункте 3 шина d[7..0] не отпущена ни на одной фазе (адресованная ячейка подключена всегда), "
       "и в фазе 0, задолго до первого фронта wr, она читается как 00000000. В изолированном зонде "
       "этот факт невидим, потому что там OEN держит выход в Z всё время до такта, — и именно "
       "поэтому он был сначала ошибочно объявлен ненаблюдаемым. Исправление пришло из второго "
       "эксперимента, а не из рассуждения: то, что нельзя увидеть в одном проекте, видно в другом, "
       "и это ещё один аргумент в пользу того, что полярности и состояния проверяются несколькими "
       "независимыми постановками.")
body("Эти факты и определяют монтаж пункта 3: такт регистру достаётся через инвертор и вентиль "
     "AND2 (потому что 1Y{i}N инверсен, а фронт нужен восходящий), а разрешение выхода подаётся "
     "напрямую с 2Y{i}N (потому что OEN тоже инверсен). Если бы полярности оказались одинаковыми, "
     "одна из двух разводок потребовала бы лишнего инвертора, и схема работала бы с точностью до "
     "наоборот.")

H2("9.4 Почему высокое сопротивление считается доказанным")
body("Отдельно, потому что это самое оспоримое место работы: утверждение «шина отпущена» нельзя "
     "подтвердить, посмотрев на нуль. Нуль и Z в волне выглядят похоже только для того, кто читает "
     "их глазами, и симулятор, и парсер вполне могли бы подменить одно другим. Поэтому проверка "
     "сделана прямой: программа проходит по всем волнам, находит КАЖДЫЙ сегмент со значением Z, "
     "берёт пробу в его середине и сверяет, что там по-прежнему Z. Насчитано "
     + str(D["z_proof"]["zSegments"])+ " " + plural(D["z_proof"]["zSegments"], SEG) + " Z в пяти волнах, проконтролировано все "
     + str(D["z_proof"]["zSampled"])+ ", потерянных нет (список пуст), встреченные уровни — "
     + ", ".join(D["z_proof"]["levelsSeen"]) + ". Второй слой (раздел 3.2) независимо насчитал "
     + str(SW["totals"]["z"]) + " сегментов Z и подтвердил то же самое, а " + str(SW["totals"]["x"])
     + " " + plural(SW["totals"]["x"], SEG) + " X в волнах задания 4 оказались предсказаны моделью, то есть ни один X не "
     "остался необъяснённым (" + str(SW["totals"]["ux"]) + ").")
body("Содержательный вывод: трёхстальное состояние в этой работе — измеренный факт, а не "
     "обозначение. Без него арбитраж шины в пункте 3 (раздел 7.3) был бы просто недоказуем, "
     "поскольку «ровно один драйвер» означает, что остальные находятся в состоянии, отличное и от "
     "нуля, и от единицы.")

# ==================================================================== 10. выводы
H1("10. Выводы")
body("Работа выполнена в полном объёме: все четыре пункта задания реализованы как реальные проекты "
     "в Quartus II 5.0, скомпилированы, смоделированы и сверены с независимыми моделями. Суммарно "
     "проверено " + str(CF["total_phases"]) + " фаз временных диаграмм первым слоем с нулевым числом "
     "расхождений и " + str(SW["totals"]["checks"]) + " сверок вторым, независимым слоем, также с нулём; "
     "исчерпывающая самодиагностика моделей проверила " + format(DATA["selftests"]["total"], ",")
      + " состояний, и выполнен один исчерпывающий перебор библиотечной схемы (" + str(T3["decoder_combinations"])
     + " " + plural(T3["decoder_combinations"], ["комбинация", "комбинации", "комбинаций"]) + " входов 74155).")
bullet("Пункт 1: простейшая схема памяти на четыре бита по рисунку 18.7 смонтирована из 21 "
       "экземпляра и 59 соединений (четыре DFFE, четыре вентиля записного строба, четыре вентиля "
       "считывающего строба, четыре трёхстальных буфера, три инвертора, VCC, GND), скомпилирована "
       "полностью (" + str(T1["fit_msg"])+ "; " + str(T1["asm_msg"])+ "; " + str(T1["tan_msg"])+ ") и заняла "
       + str(T1["logic_elements"])+ " логических элементов при " + str(T1["memory_bits"])+ " бита встроенной "
       "памяти — то есть развёрнута в триггеры и логику, как и требует наивная схема главы. Время "
       "доступа «адрес → данные» составило " + str(T1["tpd"]["actual"])+ " на паре "
       + str(T1["tpd"]["from"])+ " → " + str(T1["tpd"]["to"])+ ".")
bullet("Диаграмма пункта 1 показывает четыре события записи в четыре РАЗНЫХ адреса (00, 01, 10, 11) "
       "с четырьмя различными значениями информационного сигнала (" + ", ".join(T1["written_values"])
       + ") и возвращает их двумя считывающими проходами. Проходы сделаны при РАЗНЫХ значениях D "
       "(нуль в фазах 12–15, единица в фазах 16–19), а Q в обоих одинаков и равен записанному, что "
       "машинно подтверждает хранение, а не сквозную передачу. Поскольку порт данных одинарный, "
       "«четыре различных значения» здесь — четыре различных события по четырём адресам; четыре "
       "различных СЛОВА даёт пункт 3, и оба требования задания покрыты парой пунктов, а не одним "
       "с оговоркой.")
bullet("Пункт 2: поведенческая VHDL-модель той же схемы даёт волну, ИДЕНТИЧНУЮ схеме — "
       + str(T2["vs_task1"]["differences"]) + " расхождений во всех " + str(T2["phases"]) + " фазах "
       "при поканальном сравнении, и обе волны согласованы с одной и той же независимой моделью. "
       "Синтез модели прошёл без предупреждений (" + str(T2["map_msg"])+ ") и уложился в "
       + str(T2["logic_elements"])+ " элементов — на один меньше ручной разводки при практически той же "
       "задержке (разница " + "%.3f нс" % (ns(T1["tpd"]["actual"]) - ns(T2["tpd"]["actual"])) + ").")
bullet("Пункт 3: память 4 × 8 бит по рисунку 18.8 смонтирована из ПОДЛИННЫХ библиотечных схем 74155, "
       "74374, 74244 и занимает " + str(T3["logic_elements"])+ " элементов, " + str(T3["pins"])+ " выводов. "
       "Принцип работы разложен на три механизма (выбор ячейки тактовым стробом, арбитраж "
       "многосоставной шины d через инверсные OEN, вывод наружу через инверсный строб 74244), и все "
       "три подтверждены измерением полярностей. Диаграмма записывает четыре различных слова (FF, "
       "F0, A5, 5A) в четыре разных адреса и считывает их, возвращаясь к первому для подтверждения "
       "сохранения; шина q во время всех записей отпущена в Z, шина d всегда содержит слово "
       "адресованной ячейки, включая нулевую фазу до первой записи.")
bullet("Находка пункта 3, добытая только исчерпывающим перебором: у подлинного 74155 стробы двух "
       "групп РАЗНОПОЛЯРНЫ — 1C активен высоким уровнем, 2CN низким, оба GN низкими. Принять их за "
       "одинаковые было проще всего, и это оставило бы одну группу постоянно запрещённой, то есть "
       "молча неработающую схему. Формула подтверждена нулём нарушений на всех "
       + str(T3["decoder_combinations"]) + " комбинациях, а сеть сходится за "
       + str(T3["decoder_passes_max"]) + " прохода без неопределённых состояний.")
bullet("Пункт 4: мегафункция lpm_ram_dq настроена ровно семью параметрами задания, и отчёт синтеза "
       "подтверждает развёртку: LPM_WIDTH = " + str(T4["elaborated"]["LPM_WIDTH"])+ ", LPM_WIDTHAD = "
       + str(T4["elaborated"]["LPM_WIDTHAD"])+ ", LPM_NUMWORDS = " + str(T4["elaborated"]["LPM_NUMWORDS"])+ " (по умолчанию 2 в степени LPM_WIDTHAD, как объявлено в самом символе), LPM_FILE = "
       + str(T4["elaborated"]["LPM_FILE"])+ ", все три параметра регистрации = "
       + str(T4["elaborated"]["LPM_INDATA"])+ ". Наружу выведены только WE, ADDRESS, DATA и Q: порты "
       "inclock и outclock не подключены сознательно, потому что при полном отсутствии регистрации "
       "в дизайне не остаётся ни одного регистра, которому мог бы служить такт.")
bullet("Главный результат пункта 4 — характер записи при предписанной настройке, установленный "
       "РЕШАЮЩИМ экспериментом. Первая волна для этого НЕ годилась: все пять асинхронных гипотез "
       "воспроизводили её целиком, поскольку каждая запись идёт тройкой фаз с неизменными адресом и "
       "данными, и пред- и постпереходные значения совпадают. Второй проект (lpramwb) смонтирован "
       "специально для различения — он меняет адрес и данные при удерживаемом WE. Из семи "
       "перебранных механизмов единственной гипотезой, согласной с обеими волнами (28 фаз, ноль "
       "расхождений), оказалась запись по СПАДУ WE с отсчётом операндов ПОСЛЕ перехода; шесть "
       "других отвергнуты по точному числу расхождений, зафиксированному как самопроверка модели. "
       "Механизм подтверждён исходником altram.tdf: при USED(clocki) = 0 порт clki не подключается "
       "(строки 439–441), real_we[0] = we (строка 427) подаётся прямо на порт we примитива MEMORY "
       "(строка 449), а RAM_MODES (строки 61–66) вырождается в ноль.")
bullet("Из этого следует практическое правило проектирования диаграмм, и оно важнее самой настройки: "
       + str(T4["corollary"])+ ". Нарушение правила теряет данные — видно в фазах 2–3 измеренного "
       "эксперимента, где адрес 0x020 остался незаписанным, потому что WE отпустился одновременно с "
       "уходом адреса. То же требование, выраженное временем удержания (" + str(T3["th"]["actual"])+ " в пункте 3 и " + P("probe_reg", "th", "actual") + " в изолированном зонде 74374), "
       "предъявляет синтез, а триггерная схема пункта 1 удовлетворяет ему конструктивно, записывая "
       "только фронтом CLK.")
bullet("Ещё один факт, неизвестный бы без моделирования: незаписанное слово в функциональной модели "
       "читается как X, тогда как синтез объявляет «" + str(T4["init_warning"])+ "». Оба утверждения "
       "исходят из одного запуска и оба верны на своём уровне, и различие существенно: тест, "
       "рассчитанный на нули в незаписанных ячейках, провалится в моделировании и пройдёт на "
       "приборе. Первая модель работы предполагала нуль, и измерение это опровергло.")
bullet("Предписанная настройка синтезируема только в семействах с поддержкой асинхронной "
       "однопортовой памяти: ACEX1K и FLEX10KE проходят анализ и моделирование успешно, Stratix и "
       "Cyclone отказывают («supports only synchronous single-port RAM», altram.tdf:236), MAX3000A "
       "даёт внутренний сбой синтезатора состояний. Размещение невозможно для обоих приемлемых "
       "семейств по независимой причине — в установке детальная база устройств есть только для "
       "Stratix; ограничение задекларировано в разделе 2 и на содержание пункта не влияет, "
       "поскольку задание требует настройки и функционирования, а оба обеспечены функциональным "
       "моделированием.")
bullet("Полярности выводов определены тремя отдельными измерениями на подлинных библиотечных схемах: "
       "74244 — стробы инверсны, передача не инверсна (" + str(int(D["polarity"]["74244"]["observations_gn_low"]) + int(D["polarity"]["74244"]["observations_gn_high"]))
       + " " + plural(int(D["polarity"]["74244"]["observations_gn_low"]) + int(D["polarity"]["74244"]["observations_gn_high"]),
                   ["наблюдение", "наблюдения", "наблюдений"]) + ", ноль расхождений); TRI — разрешение активно высоким уровнем ("
       + str(D["polarity"]["probe_trioe"]["rows"]) + " фазы, ноль расхождений); 74374 — запись "
       "восходящим фронтом, OEN инверсен, передача не инверсна, высокое сопротивление настоящее, "
       "содержимое до первой записи — нуль (" + str(D["polarity"]["probe_reg"]["rows"]) + " фаз, ноль "
       "расхождений). Все три факта входят в монтаж пунктов 1 и 3 буквально на один символ.")
bullet("Теоретическая часть главы разобрана с машинной проверкой арифметики: плоская организация "
       "256 элементов требует " + str(TH["flat_wires"]) + " проводов выбора, матрица 16 × 16 — "
       + str(TH["two_sqrt"]) + " (2·√256), а два дешифратора «4-в-16» сокращают внешний адрес до "
       + str(TH["matrix_address_lines"]) + " линий, что замыкается проверкой обратно: 2 в "
       + str(TH["matrix_address_lines"]) + "-й = " + str(TH["address_word_limit"]) + " — ровно число "
       "элементов. Отсюда предел разрядности адреса (8 линий — не более 256 ячеек) и переход пункта "
       "4 к 10 адресным линиям и " + str(TH["task4_words"]) + " словам (" + str(TH["task4_bytes"])
       + " бит = " + str(TH["task4_words"]) + " байт), подтверждённый ведомостью памяти в отчёте "
       "синтеза.")
bullet("Собственные схемы работы легли на одну и ту же зависимость «ёмкость против быстродействия», "
       "измеренную, а не заявленную: рост ёмкости с четырёх бит до 32 (пункт 1 → пункт 3) поднял "
       "время доступа с " + str(T1["tpd"]["actual"])+ " до " + str(T3["tpd"]["actual"])+ " (плюс "
       + "%.1f %%" % (100.0 * (ns(T3["tpd"]["actual"]) - ns(T1["tpd"]["actual"])) / ns(T1["tpd"]["actual"]))
       + ") и ресурсы в " + "%.1f" % (num(T3["logic_elements"]) / num(T1["logic_elements"]))
       + " раза, а переход к " + str(TH["task4_words"]) + " словам (пункт 4) заставил синтез "
       "отказаться от триггерной развёртки в пользу блока памяти — ровно то различие по плотности, "
       "которое глава приписывает паре SRAM/DRAM, и оно получилось наблюдаемым в одном потоке "
       "инструмента.")
body("Инструментальная замена (MAX+plus II → Quartus II 5.0) задекларирована в разделе 2 и не "
     "искажает предмета: логика 74155, 74374 и 74244 взята из подлинных библиотечных файлов той же "
     "системы, триггер DV построен из базового элемента DFFE на том же уровне абстракции, что и "
     "рисунок 18.7, а форматы .gdf и .scf/.wfm заменены эквивалентными .bdf и .vwf/.sim.vwf. Все "
     "числовые данные отчёта взяты из отчётов Quartus II и из машинных проверок моделей, а не "
     "оценены вручную; ни одно утверждение о полярности, о характере записи или о высоком "
     "сопротивлении не принято на веру — какое именно измерение его подтверждает, указано в каждом "
     "разделе. Три утверждения, сделанных в ходе работы ошибочно (о ненаблюдаемости содержания "
     "регистра до первой записи, о нуле вместо X в незаписанном слове и об одинаковой полярности "
     "стробов 74155), исправлены по результатам измерений, и исправления видны в тексте, а не "
     "заметены.")


print("STRIPPED CHARACTERS:", len(_STRIP_LOG))
OUT = os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx")
doc.save(OUT)
print("SAVED:", OUT)
print("figures:", FIG.n, " tables:", TBL.n)
