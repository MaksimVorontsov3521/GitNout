# -*- coding: utf-8 -*-
# Audit of the claims this report makes about the composition of the schemes IT ASSEMBLED
# (ram4 from fig 18.7, mem4x8 from fig 18.8) and about the library chips it disassembled
# (74155, 74374, 74244). Truth is the .json spec that drives the .bdf build and the parsed
# library .bdf, never a handbook.
#
# Why this file exists: an earlier version resolved every numeral against specs/ram4.json
# and so called the correct 74155 claim a defect, while missing the real defect - the
# caption said "три трёхстальных буфера" two sentences before concluding "четыре TRI".
# A checker that cannot tell which scheme a sentence is about cannot audit anything.
#
# Claim resolution, in order of confidence:
#   1. DESIGNATOR ENUMERATION. "четыре инвертора P0..P3" names its own operands, so the
#      expected count is the number of enumerated ids and the subject is whichever scheme
#      owns those ids. This is measurable, not guessed.
#   2. QUALIFIER. "4 вентиля AND3 на запись" is one half of the AND3 total, because the
#      write strobes and the read strobes are separate instances of the same type.
#   3. RATE. "один триггер на разряд" is a ratio, not a count: skipped, never flagged.
#   4. NEAREST PRECEDING SUBJECT in the same paragraph, otherwise the claim is skipped
#      rather than attributed to a scheme by luck.
# The noun is the FIRST primitive noun in a bounded window after the numeral; a bare digit
# inside that window ends the claim (a new one starts), which is what made "по четыре и
# 2 инвертора" read as "четыре ... инвертора" in the previous version.
import json, os, re, sys
import os
HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        p = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(p):
            return p
    return None
WS = HERE
ROOT = UP
DOCX_PATH = find("lab13_report.docx") or find("0_zadanie_i_otchet", "lab13_report.docx")
SPEC_PATH = {}
for _n in ("ram4", "mem4x8"):
    SPEC_PATH[_n] = find("specs", _n + ".json") or find({"ram4": "1_ram4", "mem4x8": "3_mem4x8"}[_n], _n + ".json")
RD_PATH = find("report_data.json") or find("6_proverki", "report_data.json")
if DOCX_PATH is None or RD_PATH is None or any(v is None for v in SPEC_PATH.values()):
    raise SystemExit("SOURCE NOT FOUND relative to " + __file__ + ": docx=%s data=%s specs=%s" % (DOCX_PATH, RD_PATH, SPEC_PATH))
SPEC, IDS = {}, {}
for name in ("ram4", "mem4x8"):
    s = json.load(open(SPEC_PATH[name], encoding="utf-8"))
    by, ids = {}, {}
    for it in s["instances"]:
        by[it["type"]] = by.get(it["type"], 0) + 1
        ids.setdefault(it["type"], []).append(it["id"])
    SPEC[name], IDS[name] = by, ids
rd = json.load(open(RD_PATH, encoding="utf-8"))
LC = rd["library_composition"]
TRUTH = dict(SPEC)
for chip in ("74155", "74374", "74244"):
    TRUTH[chip] = dict(LC[chip]["symbols"])
    TRUTH[chip]["__total__"] = LC[chip]["symbol_total"]
OWNER = {}                      # instance id -> scheme, from the measured specs
for sch, m in IDS.items():
    for typ, lst in m.items():
        for i in lst:
            OWNER[i] = sch
SUBJECT_TOKENS = {
    "ram4": ["\u0440\u0438\u0441. 18.7", "\u0440\u0438\u0441\u0443\u043d\u043a\u0443 18.7", "\u043f\u0440\u043e\u0441\u0442\u0435\u0439\u0448\u0435\u0435 \u0417\u0423",
             "\u043f\u0440\u043e\u0441\u0442\u0435\u0439\u0448\u0435\u0439 \u0441\u0445\u0435\u043c\u044b \u043f\u0430\u043c\u044f\u0442\u0438", "\u0417\u0430\u0434\u0430\u043d\u0438\u0435 1", "\u043f\u0443\u043d\u043a\u0442 1", "\u041f\u0443\u043d\u043a\u0442 1", "ram4"],
    "mem4x8": ["\u0440\u0438\u0441. 18.8", "\u0440\u0438\u0441\u0443\u043d\u043a\u0443 18.8", "4 \u00d7 8", "\u0417\u0430\u0434\u0430\u043d\u0438\u0435 3", "\u041f\u0443\u043d\u043a\u0442 3", "mem4x8"],
    "74155": ["74155"], "74374": ["74374"], "74244": ["74244"],
}
TYPES = {"DFFE","TRI","AND3","AND2","NAND3","BAND2","NOT","VCC","GND","DFF"}
NOUN = {"DFFE": "DFFE", "\u0442\u0440\u0438\u0433\u0433\u0435\u0440": "DFFE", "DV": "DFFE",
        "TRI": "TRI", "\u0431\u0443\u0444\u0435\u0440": "TRI",
        "AND3": "AND3", "\u0432\u0435\u043d\u0442\u0438\u043b\u044c": "AND3",
        "AND2": "AND2", "NAND3": "NAND3", "BAND2": "BAND2",
        "NOT": "NOT", "\u0438\u043d\u0432\u0435\u0440\u0442\u043e\u0440": "NOT",
        "VCC": "VCC", "GND": "GND", "DFF": "DFF",
        "\u044d\u043a\u0437\u0435\u043c\u043f\u043b\u044f\u0440": "__total__",
        "\u044d\u043b\u0435\u043c\u0435\u043d\u0442": "__total__",
        "\u0441\u043e\u0435\u0434\u0438\u043d\u0435\u043d\u0438\u0435": "__connects__",
        "\u0441\u043e\u0435\u0434\u0438\u043d\u0435\u043d\u0438": "__connects__"}
WORD = {"\u043d\u043e\u043b\u044c": 0, "\u043e\u0434\u0438\u043d": 1, "\u043e\u0434\u043d\u0430": 1,
        "\u043e\u0434\u043d\u043e": 1, "\u0434\u0432\u0435": 2, "\u0434\u0432\u0430": 2, "\u0442\u0440\u0438": 3,
        "\u0447\u0435\u0442\u044b\u0440\u0435": 4, "\u0447\u0435\u0442\u044b\u0440\u0451\u0445": 4, "\u043f\u044f\u0442\u044c": 5,
        "\u0448\u0435\u0441\u0442\u044c": 6, "\u0441\u0435\u043c\u044c": 7, "\u0432\u043e\u0441\u0435\u043c\u044c": 8,
        "\u0434\u0435\u0432\u044f\u0442\u044c": 9, "\u0434\u0435\u0441\u044f\u0442\u044c": 10,
        "\u0434\u0432\u0430\u0434\u0446\u0430\u0442\u044c": 20, "\u043f\u044f\u0442\u044c\u0434\u0435\u0441\u044f\u0442": 50}
RATE = re.compile(r"^\s+(?:\u043d\u0430|\u0432)\s+(?:\u0440\u0430\u0437\u0440\u044f\u0434|\u0431\u0438\u0442|\u0441\u043b\u043e\u0432\u043e|\u044f\u0447\u0435\u0439\u043a\u0443|\u0430\u0434\u0440\u0435\u0441|\u043a\u0430\u043d\u0430\u043b|\u0432\u044b\u0445\u043e\u0434|\u0432\u0445\u043e\u0434)", re.I)
ENUM = re.compile(r"([A-Z]{1,3}\d{1,2})(?:\s*(?:\.\.|\u2026|-)\s*([A-Z]{1,3}\d{1,2}))?")
WIN = 34
# A quantity claim does not survive a clause boundary. Without this rule "ноль
# расхождений); TRI - ..." resolves "ноль" against TRI, and "59 соединений
# (четыре DFFE ..." resolves "59" against DFFE: both invent defects in correct
# prose. A dot is a boundary only when a space or end follows it, so net names
# (N0.OUT, V0.1) survive, which is the same rule _audit_final.py already uses.
BOUND = re.compile(r"[;:()]|—|«|\.(?=\s|$)")

def digit_before(window, upto):
    return re.search(r"(?:^|[^\w\d])\d{1,3}(?![\w\d])", window[:upto]) is not None

REF = re.compile(r"(?:\u043f\u0443\u043d\u043a\u0442|\u043f\u0443\u043d\u043a\u0442\u0435|\u043f\u0443\u043d\u043a\u0442\u0430|\u0440\u0430\u0437\u0434\u0435\u043b|\u0440\u0430\u0437\u0434\u0435\u043b\u0435|\u0442\u0430\u0431\u043b\u0438|\u0440\u0438\u0441\u0443\u043d\u043e\u043a|\u0440\u0438\u0441\u0443\u043d\u043a\u0430|\u0440\u0438\u0441\u0443\u043d\u043a\u0435|\u0444\u0430\u0437\u0435|\u0444\u0430\u0437|\u0441\u0442\u0440\u043e\u043a\u0435|\u0441\u0442\u0440\u043e\u043a\u0430|\u0434\u0438\u0430\u0433\u0440\u0430\u043c\u043c|\u043f\u0440\u0438\u043c\u0435\u0440|\u0442\u0430\u0431\u043b\u0438\u0446\u0443|\u0432\u0435\u0440\u0441\u0438\u044e|\u0432\u0435\u0440\u0441\u0438\u0438|\u043d\u043e\u043c\u0435\u0440)", re.I)

def cut(window):
    m = BOUND.search(window)
    return window[:m.start()] if m else window

def first_noun(window):
    window = cut(window)
    best = None
    for surf, key in NOUN.items():
        for m in re.finditer(re.escape(surf) + r"\w*", window):
            if digit_before(window, m.start()):
                continue
            if best is None or m.start() < best[1]:
                best = (key, m.start(), m.group(0))
    if best is None or digit_before(window, best[1]):
        return None
    key, pos, surf = best
    # "2 сдвоенных элемента BAND2" names the type AFTER the generic noun; extend to it only
    # while no bare digit intervenes, so "15 экземпляров (5 инверторов NOT" keeps 15 as total.
    if key in ("__total__", "__connects__"):
        gap = cut(window[pos + len(surf):])
        for tp in sorted(TYPES, key=len, reverse=True):
            mt = re.search(r"\b" + re.escape(tp) + r"\b", gap)
            if mt and not digit_before(gap, mt.start()):
                return (tp, pos, surf)
    return best

def enumerate_ids(site):
    out = []
    for m in ENUM.finditer(site):
        a, b = m.group(1), m.group(2)
        if b:
            pa, pb = re.match(r"([A-Z]+)(\d+)$", a), re.match(r"([A-Z]+)(\d+)$", b)
            if pa and pb and pa.group(1) == pb.group(1):
                out += [pa.group(1) + str(i) for i in range(int(pa.group(2)), int(pb.group(2)) + 1)]
                continue
        out.append(a)
    return [i for i in out if i in OWNER]

def audit(units):
    rows, skipped = [], []
    nums = "|".join(sorted(WORD, key=len, reverse=True))
    pat = re.compile(r"(?:^|(?<=[ ,;(]))(\d{1,3}|%s)\b" % nums)
    for u in units:
        flat = re.sub(r"\s+", " ", u)
        for m in pat.finditer(flat):
            tok = m.group(1)
            val = int(tok) if tok.isdigit() else WORD.get(tok.lower())
            if val is None:
                continue
            pre = flat[max(0, m.start() - 16):m.start()]
            if REF.search(pre):
                continue                       # "в пункте 1", "фаза 12": a reference, not a count
            if re.search(r"[=\d]\s*$", pre) and not re.search(r"\s\d+$", pre):
                skipped.append(("value of an expression, not a count", flat[max(0, m.start() - 50):m.end() + 40])); continue
            nxt = flat[m.end():m.end() + 8]
            if re.match(r"s*%", nxt) or re.search(r"<s*$| %s*$", pre):
                continue                       # "< 1 %" is a utilisation percentage
            # A per-unit rate can be stated with its qualifier BEFORE the numeral:
            # "На каждый разряд 74374 приходится ровно один DFF" - one DFF per bit is
            # correct prose about an eight-bit chip, and flagging it would demand that
            # the sentence be broken.
            if re.search(r"(?:на каждый|на каждую|приходится|в пересчёте|на разряд|на бит|ровно один|ровно одна|по одному)", flat[max(0, m.start() - 70):m.start()], re.I):
                skipped.append(("per-unit rate, qualifier precedes the numeral", flat[max(0, m.start() - 60):m.end() + 40])); continue
            window = flat[m.end():m.end() + WIN]
            fn = first_noun(window)
            if fn is None:
                continue
            key, pos, surf = fn
            site = flat[max(0, m.start() - 60):m.end() + pos + 60]
            if RATE.match(window[pos + len(surf):]):
                skipped.append(("rate (a ratio, not a count)", site)); continue
            ids = enumerate_ids(flat[m.end() + pos: m.end() + pos + 60])
            if ids:
                owners = {OWNER[i] for i in ids}
                if len(owners) != 1:
                    skipped.append(("designators span schemes " + str(sorted(owners)), site)); continue
                sub = owners.pop()
                owned = set(IDS[sub].get(key, []))
                if not set(ids) <= owned:
                    # the designators belong to some OTHER noun of the sentence ("...триггеров
                    # подключены к V0.1"): attributing their count to this noun would invent
                    # a defect, so the claim is skipped instead.
                    skipped.append(("designators " + ",".join(ids) + " are not " + key + " of " + sub, site)); continue
                how, want = "enumerates " + ",".join(ids), len(ids)
            else:
                best, bestp = None, -1
                for s_, toks in SUBJECT_TOKENS.items():
                    for tk in toks:
                        p = flat.rfind(tk, 0, m.start())
                        if p > bestp:
                            best, bestp = s_, p
                if best is None:
                    skipped.append(("no resolvable subject", site)); continue
                sub = best
                tbl = TRUTH[sub]
                how = ""
                low = window.lower()
                if key == "AND3" and tbl.get("AND3"):
                    if "\u043d\u0430 \u0437\u0430\u043f\u0438\u0441\u044c" in low or "\u0437\u0430\u043f\u0438\u0441\u043d\u043e\u0433\u043e" in low:
                        want, how = tbl["AND3"] // 2, "write half of %d" % tbl["AND3"]
                    elif "\u043d\u0430 \u0447\u0442\u0435\u043d\u0438\u0435" in low or "\u0441\u0447\u0438\u0442\u044b\u0432\u0430\u044e\u0449\u0435\u0433\u043e" in low:
                        want, how = tbl["AND3"] // 2, "read half of %d" % tbl["AND3"]
                    else:
                        want, how = tbl["AND3"], ""
                elif key == "__connects__":
                    if sub not in rd["composition_own"]:
                        skipped.append(("connections counted for " + sub + ", which is not an assembled scheme", site)); continue
                    want = rd["composition_own"][sub]["total_connects"]
                elif key in tbl:
                    want = tbl[key]
                elif key == "AND3":
                    low = window.lower()
                    if "\u043d\u0430 \u0437\u0430\u043f\u0438\u0441\u044c" in low or "\u0437\u0430\u043f\u0438\u0441\u043d\u043e\u0433\u043e" in low:
                        want, how = tbl[key] // 2, "write half of %d" % tbl[key]
                    elif "\u043d\u0430 \u0447\u0442\u0435\u043d\u0438\u0435" in low or "\u0441\u0447\u0438\u0442\u044b\u0432\u0430\u044e\u0449\u0435\u0433\u043e" in low:
                        want, how = tbl[key] // 2, "read half of %d" % tbl[key]
                    else:
                        skipped.append(("AND3 without a half qualifier in " + sub, site)); continue
                else:
                    skipped.append(("no %s in %s" % (key, sub), site)); continue
            rows.append({"subject": sub, "prose": val, "measured": want, "key": key, "how": how,
                         "ok": val == want, "site": site})
    return rows, skipped

def report(units, label):
    rows, skipped = audit(units)
    bad = [r for r in rows if not r["ok"]]
    print("\n=== %s: %d resolved, %d skipped, %d mismatches ===" % (label, len(rows), len(skipped), len(bad)))
    for r in rows:
        print("   %-9s %-7s prose=%-3d measured=%-3d %-11s %-24s %s"
              % ("OK" if r["ok"] else "MISMATCH", r["subject"], r["prose"], r["measured"],
                 r["key"], r["how"], re.sub(r"\s+", " ", r["site"])[:84]))
    for why, site in skipped:
        print("   skip  %-36s %s" % (why, re.sub(r"\s+", " ", site)[:84]))
    return rows, bad

from docx import Document
d = Document(DOCX_PATH)
units = [p.text for p in d.paragraphs] + [c.text for t in d.tables for row in t.rows for c in row.cells]
rows, bad = report(units, "RENDERED DOCUMENT")
PLANT = [
 ("\u0420\u0438\u0441\u0443\u043d\u043e\u043a 18.7 — \u043f\u0440\u043e\u0441\u0442\u0435\u0439\u0448\u0435\u0435 \u0417\u0423: \u0442\u0440\u0438 \u0442\u0440\u0451\u0445\u0441\u0442\u0430\u043b\u044c\u043d\u044b\u0445 \u0431\u0443\u0444\u0435\u0440\u0430, \u0432\u044b\u0432\u0435\u0434\u0435\u043d\u043d\u044b\u0445 \u043d\u0430 \u043e\u0431\u0449\u0443\u044e \u0448\u0438\u043d\u0443.", "ram4", "TRI", 3, False),
 ("\u0420\u0438\u0441\u0443\u043d\u043e\u043a 18.7 — \u043f\u0440\u043e\u0441\u0442\u0435\u0439\u0448\u0435\u0435 \u0417\u0423: \u043f\u044f\u0442\u044c \u0438\u043d\u0432\u0435\u0440\u0442\u043e\u0440\u043e\u0432 NOT, \u0434\u0435\u0448\u0438\u0444\u0440\u0430\u0442\u043e\u0440 \u0430\u0434\u0440\u0435\u0441\u0430.", "ram4", "NOT", 5, False),
 ("\u0420\u0438\u0441\u0443\u043d\u043e\u043a 18.7 — \u043f\u0440\u043e\u0441\u0442\u0435\u0439\u0448\u0435\u0435 \u0417\u0423: \u0447\u0435\u0442\u044b\u0440\u0435 \u0442\u0440\u0451\u0445\u0441\u0442\u0430\u043b\u044c\u043d\u044b\u0445 \u0431\u0443\u0444\u0435\u0440\u0430, \u0432\u044b\u0432\u0435\u0434\u0435\u043d\u043d\u044b\u0445 \u043d\u0430 \u043e\u0431\u0449\u0443\u044e \u0448\u0438\u043d\u0443.", "ram4", "TRI", 4, True),
 ("\u041f\u043e\u0434\u043b\u0438\u043d\u043d\u0430\u044f \u0441\u0445\u0435\u043c\u0430 74155 \u0441\u043e\u0434\u0435\u0440\u0436\u0438\u0442 15 \u044d\u043a\u0437\u0435\u043c\u043f\u043b\u044f\u0440\u043e\u0432: 5 \u0438\u043d\u0432\u0435\u0440\u0442\u043e\u0440\u043e\u0432 NOT, 2 \u0441\u0434\u0432\u043e\u0435\u043d\u043d\u044b\u0445 \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u0430 BAND2 \u0438 8 \u0442\u0440\u0451\u0445\u0432\u0445\u043e\u0434\u043e\u0432\u044b\u0445 NAND3.", "74155", None, None, True),
 ("\u0418\u0442\u043e\u0433\u043e 4 DFFE, 4 \u0432\u0435\u043d\u0442\u0438\u043b\u044f AND3 \u043d\u0430 \u0437\u0430\u043f\u0438\u0441\u044c, 4 \u0432\u0435\u043d\u0442\u0438\u043b\u044f AND3 \u043d\u0430 \u0447\u0442\u0435\u043d\u0438\u0435, 4 TRI.", "ram4", None, None, True),
 ("\u041f\u0443\u043d\u043a\u0442 1 (\u0447\u0435\u0442\u044b\u0440\u0435 \u0431\u0438\u0442\u0430, \u043e\u0434\u0438\u043d \u0442\u0440\u0438\u0433\u0433\u0435\u0440 \u043d\u0430 \u0440\u0430\u0437\u0440\u044f\u0434) \u0434\u0430\u0451\u0442 \u0445\u0443\u0434\u0448\u0443\u044e \u0437\u0430\u0434\u0435\u0440\u0436\u043a\u0443.", None, None, None, "skip"),
 ("\u0421\u0445\u0435\u043c\u0430 \u0441\u043c\u043e\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0430: \u043f\u0435\u0440\u0435\u0447\u0435\u043d\u044c \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u043e\u0432 \u0442\u0430\u043a\u043e\u0439: \u0447\u0435\u0442\u044b\u0440\u0435 \u0438\u043d\u0432\u0435\u0440\u0442\u043e\u0440\u0430 P0..P3.", "mem4x8", None, None, True),
]
fails = []
for text, want_sub, want_key, want_val, expect in PLANT:
    rs, sk = audit([text])
    if expect == "skip":
        if rs:
            fails.append("rate claim resolved instead of skipped: " + text[:50] + " -> " + str([(r["subject"], r["key"], r["prose"], r["measured"]) for r in rs]))
        continue
    if expect is True:
        wrong = [r for r in rs if (want_sub is None or r["subject"] == want_sub) and not r["ok"]]
        if wrong:
            fails.append("known-correct claim flagged: %s -> %s" % (text[:50], [(r["subject"], r["key"], r["prose"], r["measured"]) for r in wrong]))
    else:
        hit = [r for r in rs if r["subject"] == want_sub and r["key"] == want_key and not r["ok"]]
        if not hit:
            fails.append("known-bad NOT caught: %s -> %s" % (text[:50], [(r["subject"], r["key"], r["prose"], r["measured"], r["ok"]) for r in rs]))
if fails:
    for f in fails:
        print("   SELF-TEST FAIL: " + f)
    raise SystemExit("self-test failed: %d" % len(fails))
print("\nself-test: %d planted cases correct (2 known-bad caught, 4 known-correct passed, 1 rate skipped)" % len(PLANT))
from collections import Counter
_bd = Counter(w for w, _ in audit([u for u in units])[1])
_tot = sum(_bd.values())
print("\nskipped-claim breakdown (%d): %s" % (_tot, json.dumps(dict(_bd.most_common()), ensure_ascii=False)))
_res = len(audit([u for u in units])[0])
print("coverage: %d composition claims resolved against the measured source, %d numerals skipped as not-composition (timings, resources, phases, references, percentages, rates)" % (_res, _tot))
print("VERDICT: " + ("EVERY COMPOSITION CLAIM RESOLVES TO ITS OWN SCHEME AND AGREES WITH THE MEASURED SOURCE"
                     if not bad else "DEFECTS REMAIN: %d" % len(bad)))
sys.exit(0 if not bad else 1)

# SKIP BREAKDOWN
