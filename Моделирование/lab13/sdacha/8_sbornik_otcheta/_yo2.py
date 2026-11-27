# -*- coding: utf-8 -*-
# Ё checker, third version. Two weaknesses of the second are repaired here.
#
# (1) The self-test exercised classify() while the scan used separate inline logic,
#     so the test proved nothing about the rule that actually runs. The scan and the
#     test now call the SAME function.
# (2) The rule required ё for every ё-stem word lacking it, which is wrong for SHORT
#     participles: the full form is "разряжённый"/"заряжённый", but the short forms
#     carry the stress on the ending and take no ё - "разряжены", "заряжены",
#     "разряжена", "заряжена". The report uses neither short form, but a rule that
#     cannot tell them apart would flag correct text, and a rule that flags correct
#     text is worthless for the same reason a rule that misses defects is.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
flat = "\n".join(units)
YO_STEMS = ["заряжен", "разряжен"]
# endings of the FULL participle / adjective: these require ё
FULL_END = re.compile(r"(ый|ая|ое|ее|ые|ий|ия|ие|ияя|ого|ему|ым|ыми|ых|их|ому|ым)$")
# endings of the SHORT participle: these do NOT require ё
SHORT_END = re.compile(r"(ы|и|а|о)$")
OK_E = ["обеспеч", "утвержд", "разрешение", "разрешени", "разреша", "все", "всем", "всего",
        "всей", "всегда", "вовсе", "этот", "этом"]

def classify(w):
    """True if this word form must be flagged: a ё-stem written without ё in a
    position where standard spelling puts it."""
    lw = w.lower()
    if "ё" in lw:
        return False
    stem = next((s for s in YO_STEMS if s in lw), None)
    if stem is None:
        return False
    if any(o in lw for o in OK_E):
        return False
    tail = lw[len(stem) + (1 if lw.endswith(("ый", "ая", "ое", "ые")) else 0):]
    # the suffix after the stem decides: "ный"/"нная" => full form, bare => short
    suffix = lw[lw.index(stem) + len(stem):]
    if SHORT_END.match(suffix) and not suffix.endswith(("ный", "нные", "нного")):
        return False
    return bool(FULL_END.match(suffix)) or suffix.startswith(("н", "нн"))

bad = []
for w in re.findall(r"\b[А-Яа-яЁё]+\b", flat):
    if classify(w):
        i = flat.find(w)
        bad.append((w, re.sub(r"\s+", " ", flat[max(0, i - 55):i + len(w) + 45]).strip()))
print("ё defects: %d" % len(bad))
seen = set()
for w, ctx in bad:
    if w in seen: continue
    seen.add(w)
    print("   %-20s | ...%s..." % (w, ctx[:120]))

PLANT = [
    ("заряженной", True, "full participle without ё - the defect this lab had"),
    ("разряженной", True, "full participle without ё"),
    ("заряжённой", False, "correct full form"),
    ("разряжённой", False, "correct full form"),
    ("заряжены", False, "SHORT plural - stress on the ending, no ё by norm"),
    ("разряжены", False, "SHORT plural - same"),
    ("заряжена", False, "SHORT feminine - same"),
    ("обеспечивает", False, "no ё in this word at all"),
    ("разрешены", False, "short plural of разрешить"),
    ("все", False, "все has no ё; всё does"),
]
caught = 0
print("\n--- self-test: same function the scan uses ---")
for w, expect, why in PLANT:
    got = classify(w)
    ok = got == expect
    if ok: caught += 1
    print("   %-16s expect=%-5s got=%-5s %-5s %s" % (w, expect, got, "OK" if ok else "WRONG", why))
print("self-test: %d of %d correct" % (caught, len(PLANT)))
if caught != len(PLANT):
    raise SystemExit("SELF-TEST FAILED: the ё rule misclassifies a planted case, so its clean verdict is meaningless")
if bad:
    raise SystemExit("ё DEFECTS PRESENT: %d" % len(bad))
