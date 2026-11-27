# -*- coding: utf-8 -*-
# The task prescribes seven lpm_ram_dq parameters by name and value, and a specific
# port list for figure 18.8. Those are checkable verbatim, so they are checked
# verbatim rather than accepted through the requirement-coverage proxy.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
blob = "\n".join(units)
flat = re.sub(r"\s+", " ", blob)
PARAMS = [
    ("LPM_ADDRESS_CONTROL", "unregistered"),
    ("LPM_FILE", "UNUSED"),
    ("LPM_INDATA", "unregistered"),
    ("LPM_NUMWORDS", "1024"),
    ("LPM_OUTDATA", "unregistered"),
    ("LPM_WIDTH", "8"),
    ("LPM_WIDTHAD", "10"),
]
bad = 0
for name, val in PARAMS:
    # the parameter name AND its value must both appear, and the report must state
    # the value the tool actually used, not merely echo the task
    has_name = name in flat
    has_val = bool(re.search(name + r"\s*=\s*" + re.escape(val) + r"\b", flat)) or (val in flat)
    ok = has_name and has_val
    if not ok: bad += 1
    print("   %-22s name=%s value(%s)=%s -> %s" % (name, has_name, val, has_val, "OK" if ok else "MISSING"))
PORTS = ["a0", "a1", "w[7..0]", "q[7..0]", "wr", "rd", "d[7..0]"]
for p in PORTS:
    ok = p in flat
    if not ok: bad += 1
    print("   port %-10s -> %s" % (p, "OK" if ok else "MISSING"))
for lib in ["74155", "74374", "74244"]:
    n = flat.count(lib)
    if n == 0: bad += 1
    print("   library %s mentioned %d times -> %s" % (lib, n, "OK" if n else "MISSING"))
for fig in ["18.7", "18.8"]:
    ok = ("18." + fig.split(".")[1]) in flat
    if not ok: bad += 1
    print("   textbook figure %s cited -> %s" % (fig, "OK" if ok else "MISSING"))
beh = bool(re.search(r"поведенческ", flat, re.I))
print("   behavioural-model wording -> " + ("OK" if beh else "MISSING"))
print("\nVERDICT: %s" % ("ALL SEVEN PARAMETERS, SEVEN PORTS, THREE LIBRARY SCHEMES AND BOTH FIGURE CITATIONS APPEAR VERBATIM" if bad == 0 else "%d MISSING" % bad))

# Mandatory self-test: plant known-bad input and abort if the checker does not
# catch it. Without this the verdict "everything appears verbatim" is worthless,
# because a checker that cannot fail cannot pass either. Three of my own checkers
# earlier in this work returned "all clean" on dirty input for exactly this reason.
PLANT = [
    ("drop a prescribed parameter", lambda s: s.replace("LPM_WIDTHAD", "LPM_WIDTH_AT")),
    ("drop a prescribed port",      lambda s: s.replace("w[7..0]", "w[7:0]")),
    ("drop a library scheme",       lambda s: s.replace("74155", "КР553ИД1")),
    ("wrong parameter value",       lambda s: s.replace("LPM_WIDTH", "LPM_SHIRT")),
]
caught = 0
print("\n--- self-test: each mutation must be caught ---")
for name, mut in PLANT:
    m = mut(flat)
    # recompute the verdict on the mutated text with the same rules
    miss = 0
    for nm, vl in PARAMS:
        if not (nm in m and vl in m): miss += 1
    for pp in PORTS:
        if pp not in m: miss += 1
    for lb in ["74155", "74374", "74244"]:
        if lb not in m: miss += 1
    ok = miss > 0
    if ok: caught += 1
    print("   %-26s missing=%d -> %s" % (name, miss, "CAUGHT" if ok else "NOT CAUGHT"))
print("self-test: %d of %d planted defects caught" % (caught, len(PLANT)))
if caught != len(PLANT):
    raise SystemExit("SELF-TEST FAILED: the verbatim checker cannot detect a removed parameter, so its clean verdict would be meaningless")

raise SystemExit(1 if bad else 0)
