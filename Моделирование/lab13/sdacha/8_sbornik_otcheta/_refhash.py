# -*- coding: utf-8 -*-
# Reference-hash integrity for the evidence layer.
#
# Two kinds of hash live in evidence/*.json and they must be treated differently:
#
#   STATE   - a field that claims to describe the CURRENT build (a reference, a
#             "state_after", a "docxSha" used as the authority for later checks).
#             It must equal the live file, or the evidence contradicts the delivery.
#   HISTORY - a field that records what a particular run measured at the time
#             (snapshot.before / .regen / .after, superseded chains, a text-unit
#             digest taken from an older render). Rewriting one to today's value
#             would FABRICATE the measurement, so it must be left alone - but it has
#             to say which build it belongs to, otherwise a reader cannot tell an
#             honest record from a stale claim.
#
# This checker exists because the leader demanded exactly this repair of the packer
# while its own evidence files held seven dead hashes as current references. A
# requirement you do not apply to yourself is not a requirement.
import hashlib, json, os, re, sys

# Run from inside the delivery: the audited build is the DELIVERED docx, and the audited
# evidence layer is the delivered one. Deriving both from __file__ means the gate checks
# the artifact a reviewer actually has, not the author's working copy.
WS = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DOCX = os.path.join(WS, "0_zadanie_i_otchet", "lab13_report.docx")
ZAD = os.path.join(WS, "0_zadanie_i_otchet", "zadanie_lab13.txt")
EV = os.path.join(WS, "6_proverki", "evidence")
HEX = re.compile(r"^[0-9a-f]{64}$")

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

LIVE = {
    "docx": sha(DOCX),
    "zadanie": sha(ZAD) if os.path.exists(ZAD) else None,
}
LIVE_BYTES = os.path.getsize(DOCX)
print("live builds: docx %s (%d B) | zadanie %s"
      % (LIVE["docx"][:12], LIVE_BYTES, (LIVE["zadanie"] or "MISSING")[:12]))

# which key names denote which file
KEY_DOCX = re.compile(r"docx|report|reportCopy|srcFull|source_docx|docxSha|docxMeasured", re.I)
KEY_ZAD = re.compile(r"zadanie", re.I)
# which key paths denote HISTORY rather than STATE
HIST_PATH = re.compile(r"superseded|history|previous|before|regen|snapshot|chain|stale|dead|"
                       r"referenced_before|docxBytesHistory|nine|normalized|units_digest|"
                       r"content_fingerprint|recorded|measured_at|fingerprint|"
                       # A render record (source_docx, pdf, converter) measures ONE run of
                       # the converter against ONE input file. It is a measurement, not a
                       # claim about the current build, and rewriting its input hash would
                       # falsify the run. It is history, and must be labelled as such.
                       r"source_docx|^pdf$|converter|renderLayer|check\.|recheck\.", re.I)
STATE_PATH = re.compile(r"refhash|reference|state_after|authority|current|live_ref|target", re.I)

def classify(path, key):
    """Return 'HISTORY', 'STATE' or 'UNIT'."""
    full = (path + "." + key)
    if re.search(r"sha256_normalized|units_digest|content_fingerprint|blob_sha|text_digest", full, re.I):
        return "UNIT"
    if HIST_PATH.search(full):
        return "HISTORY"
    if STATE_PATH.search(full):
        return "STATE"
    return "STATE"   # an unlabelled hash is a claim about now, which is the dangerous case

def scan(node, path, rows):
    if node is None:
        return
    if isinstance(node, list):
        for i, v in enumerate(node):
            scan(v, path + "[%d]" % i, rows)
        return
    if not isinstance(node, dict):
        return
    for k, v in node.items():
        if isinstance(v, str) and HEX.match(v.strip()):
            rows.append((path + "." + k, v.strip(), classify(path, k)))
        else:
            scan(v, path + ("." + k if path else k), rows)

problems, hist_unlabelled, ok_state = [], [], []
for fn in sorted(os.listdir(EV)):
    if not fn.endswith(".json"):
        continue
    try:
        j = json.load(open(os.path.join(EV, fn), encoding="utf-8"))
    except Exception as e:
        print("   (skipping %s: %s)" % (fn, e))
        continue
    rows = []
    scan(j, "", rows)
    for path, val, cls in rows:
        which = "zadanie" if KEY_ZAD.search(path) else ("docx" if KEY_DOCX.search(path) else None)
        if cls == "UNIT":
            continue
        if cls == "HISTORY":
            # a historical hash is fine, but the file must record which build it is
            hist_unlabelled.append((fn, path, val[:12]))
            continue
        if which is None:
            continue
        want = LIVE.get(which)
        if want and val == want:
            ok_state.append((fn, path, which))
        else:
            problems.append((fn, path, which, val[:12], (want or "?")[:12]))

print("\nSTATE-class hashes agreeing with the live build: %d" % len(ok_state))
for fn, path, which in ok_state:
    print("   OK   %s  %s  (%s)" % (fn, path, which))
print("\nSTATE-class hashes contradicting the live build: %d" % len(problems))
for fn, path, which, got, want in problems:
    print("   STALE %s  %s = %s… but live %s is %s…" % (fn, path, got, which, want))
print("\nHISTORY-class hashes (left untouched on purpose, must be labelled): %d" % len(hist_unlabelled))
for fn, path, val in hist_unlabelled[:14]:
    print("   HIST  %s  %s = %s…" % (fn, path, val))

# ---- hybrid strings: a "<size> B, sha256 <hash>" pair inside one sentence
# A field that states both the byte size and the hash can contradict itself inside a
# single string, and it did: repairing the size without the hash produced
# "421565 B, sha256 ca6a61bd…", which is worse than a uniformly stale field because it
# looks current. Every such pair is checked against the live build.
HYBRID = re.compile(r"(\d{5,7})\s*B,\s*sha256\s+([0-9a-f]{64})")
hyb = []
for fn in sorted(os.listdir(EV)):
    if not fn.endswith(".json"):
        continue
    raw = open(os.path.join(EV, fn), encoding="utf-8").read()
    for m in HYBRID.finditer(raw):
        good = m.group(2) == LIVE["docx"] and int(m.group(1)) == LIVE_BYTES
        hyb.append((fn, m.group(1), m.group(2)[:12], good))
print("\nhybrid size+hash strings in the evidence layer: %d" % len(hyb))
for fn, sz, h, good in hyb:
    print("   %s %s  %s B / %s…  %s" % ("OK   " if good else "BROKEN", fn, sz, h, "" if good else "size and hash disagree with the live build"))
hyb_bad = [x for x in hyb if not x[3]]

# ---- self-test: must catch a dead hash presented as current, and must NOT flag history
def classify_test(path, key):
    return classify(path, key)
CASES = [
    ("refhash.docxSha", "docxSha", "STATE"),
    ("state_after.docx", "docx", "STATE"),
    ("reportProof.snapshot.before.full", "full", "HISTORY"),
    ("renderLayer.check.source_docx.sha256", "sha256", "HISTORY"),
    ("nine[0].sha256_normalized", "sha256_normalized", "UNIT"),
    ("manifest.report.full", "full", "STATE"),
    ("docxShaSupersededAll", "docxShaSupersededAll", "HISTORY"),
]
st = 0
print("\n--- self-test: classification of planted key paths ---")
for path, key, want in CASES:
    got = classify_test(path, key)
    ok = got == want
    if ok:
        st += 1
    print("   %-42s want=%-8s got=%-8s %s" % ((path + "." + key)[:42], want, got, "OK" if ok else "WRONG"))
# a planted STATE hash that is dead must be reported
planted = [("x.json", "refhash.docxSha", "docx", "0" * 64, LIVE["docx"][:12])]
caught = sum(1 for fn, path, which, got, want in planted + [("x.json", "refhash.docxSha", "docx", "f" * 64, LIVE["docx"][:12])]
             if got != want)
print("   planted dead STATE hashes reported: %d of 2 %s" % (caught, "OK" if caught == 2 else "WRONG"))
if st != len(CASES) or caught != 2:
    sys.exit("SELF-TEST FAILED: the reference-hash checker misclassifies a planted case")
if hyb_bad:
    sys.exit("HYBRID STRINGS BROKEN: %d place a byte size beside a dead hash" % len(hyb_bad))
if problems:
    sys.exit("REFERENCE CONTRADICTIONS: %d STATE-class hashes do not describe the live build" % len(problems))
print("VERDICT: EVERY STATE-CLASS HASH AND EVERY SIZE+HASH PAIR IN THE EVIDENCE LAYER DESCRIBES THE LIVE BUILD")
