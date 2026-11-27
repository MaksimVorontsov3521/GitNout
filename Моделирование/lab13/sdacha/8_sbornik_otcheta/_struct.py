# -*- coding: utf-8 -*-
# Structural checker: the heading TREE of the report, asserted against the plan it is
# supposed to implement. This exists because a paragraph-level battery cannot notice a
# deleted heading: every other checker tests content that is present. During this work
# an editing patch destroyed the section-2 heading and all 21 other checkers still
# reported clean, because none of them asked "is every section of the plan there?".
import os, re, sys
from docx import Document
DOC = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
PLAN = ["1", "2", "3", "3.1", "3.2", "3.3", "4", "4.1", "4.2", "4.3", "4.4", "4.5", "4.6",
        "5", "5.1", "5.2", "5.3", "5.4", "6", "6.1", "7", "7.1", "7.2", "7.3", "7.4", "7.5",
        "8", "8.1", "8.2", "8.3", "8.4", "9", "9.1", "9.2", "9.3", "9.4", "10"]
def headings(path):
    d = Document(path)
    out = []
    for q in d.paragraphs:
        if not q.style.name.startswith("Heading"):
            continue
        m = re.match(r"^(\d+(?:\.\d+)?)(?:[.\s]|$)", q.text.strip())
        if m:
            out.append((m.group(1), q.text.strip()))
    return out
hs = headings(DOC)
nums = [n for n, t in hs]
missing = [p for p in PLAN if p not in nums]
extra = sorted(set(n for n in nums if n not in PLAN))
dup = sorted({n for n in nums if nums.count(n) > 1})
order_ok = nums == sorted(nums, key=lambda s: [int(x) for x in s.split(".")])
print("plan sections: %d | headings found: %d" % (len(PLAN), len(hs)))
print("missing: %s | unexpected: %s | duplicated: %s | numbering monotonic: %s"
      % (missing or "none", extra or "none", dup or "none", order_ok))
# every Heading 1 must be a top-level number and every Heading 2/3 a dotted one.
# Computed by walking the paragraphs directly: an earlier version zipped two lists of
# different lengths (numeric headings only, versus all headings), so it compared the
# wrong pairs and could have reported a mismatch that does not exist.
lvl_bad = []
for q in Document(DOC).paragraphs:
    if not q.style.name.startswith("Heading"):
        continue
    m = re.match(r"^(\d+(?:\.\d+)?)(?:[.\s]|$)", q.text.strip())
    if not m:
        lvl_bad.append(("<no number>", q.text.strip()[:60], q.style.name)); continue
    depth = m.group(1).count(".") + 1
    style_lvl = int(q.style.name.split()[-1])
    if depth != style_lvl:
        lvl_bad.append((m.group(1), q.text.strip()[:60], q.style.name))
print("heading-level mismatches: %d" % len(lvl_bad))
for n, t, s in lvl_bad[:6]: print("   %-10s %-58s %s" % (n, t, s))
# self-test: delete one heading from the plan view and require the checker to notice
PLANT = [p for p in ["2", "5.4", "9.2"] if p in nums]
caught = 0
for p in PLANT:
    sim = [n for n in nums if n != p]
    miss = [x for x in PLAN if x not in sim]
    ok = p in miss
    if ok: caught += 1
    print("   self-test: pretend %s deleted -> missing=%s -> %s" % (p, miss, "CAUGHT" if ok else "NOT CAUGHT"))
print("self-test: %d of %d caught" % (caught, len(PLANT)))
if caught != len(PLANT):
    sys.exit("SELF-TEST FAILED: the structural checker cannot detect a deleted heading")
if missing or extra or dup or not order_ok or lvl_bad:
    sys.exit("STRUCTURE DEFECT: missing=%s unexpected=%s dup=%s order=%s level=%d"
             % (missing, extra, dup, order_ok, len(lvl_bad)))
print("VERDICT: HEADING TREE MATCHES THE PLAN EXACTLY - %d sections, none missing, none duplicated" % len(hs))
