# -*- coding: utf-8 -*-
# Final numeric provenance audit of the saved report.
#
# Every number in the report prose and tables is classified before it is traced:
#   STRUCTURAL  - a section, figure, table or tool-version reference; not a measurement
#   BITSTRING   - a wave pattern such as 1010 or 1111 (digits 0/1 only, length >= 4)
#   MEASURED    - must appear literally in report_data.json, an evidence file or a Quartus
#                 report, OR be reproducible by the derivation registry below.
#
# The derivation registry is recomputed here from the same measured values the generator uses,
# so a number produced by arithmetic in make_report.py is proved by independent arithmetic here
# instead of being excused from the corpus lookup.
import json, os, re
from docx import Document

HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
d = Document(os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx"))
RD = json.load(open(os.path.join(SD, "6_proverki", "report_data.json"), encoding="utf-8"))
corpus = set()

def harvest(o):
    if isinstance(o, str):
        corpus.add(o.strip())
        for tok in re.findall(r"[\d.,]+", o):
            corpus.add(tok.strip("., "))
            corpus.add(tok.replace(",", "").strip("., "))
    elif isinstance(o, bool):
        pass
    elif isinstance(o, (int, float)):
        corpus.add(str(o))
        corpus.add("{:,}".format(int(o)) if float(o).is_integer() else str(o))
    elif isinstance(o, (list, tuple)):
        for v in o: harvest(v)
    elif isinstance(o, dict):
        for v in o.values(): harvest(v)

harvest(RD)
# sdacha: доказательства лежат по папкам проектов, а не в одном evidence/
EV_DIRS = [os.path.join(SD, f) for f in
           ("1_ram4", "2_ram4beh", "3_mem4x8", "4_lpm_ram_dq",
            "5_proby_polyarnosti", "6_proverki")]
# A transcript of THIS audit's own stdout must never enter its corpus, or a number
# is "traced" merely because an earlier run printed it. pack.json is such a
# transcript (it records the "proved by derivation" list), so the exclusion is by
# content marker, not by file name, and it is reported rather than silent.
SELF_MARKERS = ("MEASURED AND UNTRACED", "proved by derivation", "measured basis: t1=")
skipped = []
for _d in EV_DIRS:
    for _root, _sub, _files in os.walk(_d):
        for fn in sorted(_files):
            if not fn.endswith(".json"): continue
            _p = os.path.join(_root, fn)
            raw_txt = open(_p, encoding="utf-8", errors="replace").read()
            if any(mk in raw_txt for mk in SELF_MARKERS):
                skipped.append(os.path.relpath(_p, SD)); continue
            try: harvest(json.load(open(_p, encoding="utf-8")))
            except Exception: pass
# sdacha: отчёты Quartus лежат в папках проектов, а не в <проект>_out
blob = []
for _root, _sub, _files in os.walk(SD):
    for fn in sorted(_files):
        if fn.endswith(".rpt"): blob.append(open(os.path.join(_root, fn), encoding="latin1").read())
for tok in re.findall(r"[\d.,]+", "\n".join(blob)):
    corpus.add(tok.strip("., ")); corpus.add(tok.replace(",", "").strip("., "))

paras = d.paragraphs
texts = [q.text for q in paras]
mono = {i for i, q in enumerate(paras) for r in q.runs if r.font.name and "Courier" in r.font.name}
heads = {i for i, q in enumerate(paras) if q.style.name.startswith("Heading")}
tbl = [c.text for t in d.tables for row in t.rows for c in row.cells]

TOKEN = re.compile(r"(?<![\w\d.])(\d{1,3}(?:,\d{3})+|\d+(?:[.,]\d+)?)(?![\d])(\s*(?:ns|%))?")
STRUCT_HEAD = re.compile(r"(раздел|Раздел|рисун|Рисун|рис\.|табл|Табл|глав|пункт|Пункт|верси"
                          r"|Build|Quartus II|MAX\+plus|стека|в 6-й|2 в)\s*[^\d]{0,6}$")

def cls(v, unit, pre):
    if unit: return "MEASURED"
    if set(v) <= {"0", "1"} and len(v) >= 4: return "BITSTRING"
    if STRUCT_HEAD.search(pre): return "STRUCTURAL"
    if re.fullmatch(r"\d+\.\d+", v) and all(len(p) <= 2 for p in v.split(".")) and float(v) < 100:
        return "STRUCTURAL"
    return "MEASURED"

def traced(v):
    w = v.replace(",", "")
    if w in corpus or v in corpus: return True
    if w.isdigit():
        try: return "{:,}".format(int(w)) in corpus
        except Exception: return False
    return False

def _n(x): return float(str(x).replace("ns", "").strip())
t1 = _n(RD["tasks"]["ram4"]["tpd"]["actual"])
t2 = _n(RD["tasks"]["ram4beh"]["tpd"]["actual"])
t3 = _n(RD["tasks"]["mem4x8"]["tpd"]["actual"])
le1 = int(str(RD["tasks"]["ram4"]["logic_elements"]).split("/")[0].replace(",", ""))
le3 = int(str(RD["tasks"]["mem4x8"]["logic_elements"]).split("/")[0].replace(",", ""))
DERIVED = []
for prec, val in [(3, t1 - t2), (3, t3 - t1), (1, 100.0 * (t3 - t1) / t1), (2, t3 / t1), (1, le3 / le1)]:
    DERIVED.append(("%." + str(prec) + "f") % val)
print("measured basis: t1=%.3f t2=%.3f t3=%.3f le1=%d le3=%d" % (t1, t2, t3, le1, le3))
print("derived recomputed independently: " + repr(DERIVED))
print("evidence files excluded as self-transcripts: %d %s" % (len(skipped), skipped))

nums = []
for i, t in enumerate(texts):
    if i in mono or i in heads: continue
    for m in TOKEN.finditer(t):
        nums.append(("p%d" % i, m.group(1), (m.group(2) or "").strip(),
                     t[max(0, m.start() - 30):m.start()], t[m.end():m.end() + 30]))
for j, t in enumerate(tbl):
    for m in TOKEN.finditer(t):
        nums.append(("tbl%d" % j, m.group(1), (m.group(2) or "").strip(),
                     t[max(0, m.start() - 30):m.start()], t[m.end():m.end() + 30]))
stat, bad, der = {}, [], []
for src, v, u, pre, post in nums:
    k = cls(v, u, pre)
    stat[k] = stat.get(k, 0) + 1
    if k != "MEASURED" or traced(v): continue
    if v.replace(",", "") in DERIVED or v in DERIVED: der.append((src, v, u))
    else: bad.append((src, v, u, pre + "[" + v + "]" + post))
print("tokens: %d | classes: %s" % (len(nums), stat))
print("MEASURED, proved by derivation: %d  distinct %s" % (len(der), sorted({(v, u) for _, v, u in der})))
print("MEASURED AND UNTRACED: %d" % len(bad))
for src, v, u, ctx in bad: print("  %-7s %-10s | ...%s..." % (src, v + u, ctx[-95:]))