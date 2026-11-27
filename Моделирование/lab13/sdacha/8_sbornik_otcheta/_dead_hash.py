# -*- coding: utf-8 -*-
# A dead hash is not one defect class but two, and treating them alike is wrong in both
# directions:
#
#   HISTORY     - a recorded measurement of an earlier build ("v1 ecf10655…, 421182 B",
#                 "пробная сборка дала 39197e0a…"). Rewriting such a field to today's
#                 value FABRICATES the measurement. It must stay, labelled.
#   DIRECTIVE   - an instruction to the reader: "убедиться, что sha256 равен …",
#                 "verify its sha256 equals …". Here the hash is an OPERAND of an action.
#                 A stale operand makes the check fail for anyone who follows it, so it
#                 MUST be repointed. Correcting an instruction is not falsifying a record.
#
# This checker therefore asks, for every 64-hex token in the delivery tree: does some
# file in the tree carry it (live)? If not, is it inside a directive (finding) or inside
# labelled history / a normalized-text digest (acceptable)? An unlabelled dead token is a
# finding too, because a reader cannot tell an honest record from a stale claim.
import hashlib, json, os, re, sys

SH = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
TXT = re.compile(r"\.(txt|md|json|mjs|py|tdf|bdf|vwf|qsf|sdc|vhd|ahdl|ini|log|rpt|eqn|pin|csv)$", re.I)
HEX = re.compile(r"\b[0-9a-f]{64}\b")

DIRECTIVE = re.compile(r"равен|равна|эталон|верифиц|убедит|свер|ожидается|должен|"
                       r"equals?|verify|expected|should be|check that|confirm|reference hash", re.I)
HISTORY = re.compile(r"superseded|отозван|стары|истори|ранее|ранни|до этого|до правк|лини|редакц|"
                     r"history|snapshot|before|regen|after|первая|пробная сборка|вторая редакция|"
                     r"\bv[1-9]\b|смене|предыдущ|уже не|устарев", re.I)
TEXTDIGEST = re.compile(r"sha256_normalized|content_fingerprint|units_digest|blob_sha|"
                        r"normalized|нормализованн|text_digest|fingerprint", re.I)
# A third honest reason a hash names no delivered file: the artifact is a DERIVATIVE that
# is deliberately not shipped, and the record says so. Keeping this separate from HISTORY
# matters - history is "we measured an older build", this is "we refuse to ship a
# third-party engine's output and it is reproducible". Both are legitimate; neither may be
# an unlabelled bare hash.
ABSENT = re.compile(r"not part of the delivery|intentionally absent|deliberately not|"
                    r"не доставлен|не входит в сдачу|производный артефакт|reproducible from|"
                    r"not shipped|восстанавливаются", re.I)

def sha(b):
    return hashlib.sha256(b).digest if False else hashlib.sha256(b).hexdigest()

# index the tree
live_hashes, files = set(), []
for root, dirs, names in os.walk(SH):
    for n in names:
        p = os.path.join(root, n)
        try:
            b = open(p, "rb").read()
        except Exception:
            continue
        h = sha(b)
        live_hashes.add(h)
        files.append((p, len(b), h))
print("files indexed in the delivery tree: %d (%d B)" % (len(files), sum(x[1] for x in files)))

PROX = 70   # characters immediately before the token that still count as its operand

def classify(tok, window, is_live, operand=None):
    """Decide the role of one 64-hex token.

    Two corrections to the first version, each forced by a false positive it produced on
    correct prose:

    * A directive marker has to be ADJACENT to the token, inside its operand window.
      The first version searched a four-line window, so the narrative sentence
      "пока эталон не зафиксирован" turned the labelled history line "v1 ecf10655…" into
      a supposed instruction. Adjacency is the actual grammar of an instruction:
      "равен эталону (…): <hash>", "verify its sha256 equals <hash>".
    * History and text-digest labels may come from the wider window, because a JSON key
      such as docxShaSupersededAll sits several lines above the bare strings it governs.
    """
    if is_live:
        return "LIVE"
    # The operand window is the text IMMEDIATELY BEFORE the token. Taking the last PROX
    # characters of a string that ENDS with the 64-hex token would push the marker out of
    # the window entirely, which is what made this self-test fail on its first two cases:
    # the token itself is 64 of the 70 characters. Strip it before taking the window.
    op = operand if operand is not None else window
    op = op.replace(tok, "")
    near = op[-PROX:]
    if DIRECTIVE.search(near):
        return "DIRECTIVE"
    if HISTORY.search(window):
        return "HISTORY"
    if TEXTDIGEST.search(window):
        return "TEXTDIGEST"
    if ABSENT.search(window):
        return "ABSENT_BY_DESIGN"
    return "UNLABELLED"

rows = []
for p, size, h in files:
    if not TXT.search(p) or size > 900000:
        continue
    try:
        lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
    except Exception:
        continue
    for i, line in enumerate(lines):
        for m in HEX.finditer(line):
            tok = m.group(0)
            # window: the line itself plus the three preceding non-empty lines, which is
            # where the label lives in both prose and pretty-printed JSON
            back = [l for l in lines[:i] if l.strip()][-3:]
            if TXT.search(p) and p.lower().endswith(".json"):
                # the governing key may be further above a bare array of strings, so walk
                # back to the nearest line that actually carries a "key":
                keyline = None
                for l in reversed([x for x in lines[:i] if x.strip()]):
                    if re.search(r'"[A-Za-z_][\w]*"\s*:', l):
                        keyline = l
                        break
                if keyline is not None:
                    back = ([x for x in back if x is not keyline] + [keyline])
                    back = [keyline] + [l for l in lines[:i] if l.strip() and l is not keyline][-2:]
            # The label may sit AFTER the value, which is the normal JSON style for an
            # annotation appended next to a measured hash. A window built only from
            # preceding lines therefore reported a correctly labelled record as
            # unlabelled. Look both ways; the DIRECTIVE test is unaffected because it
            # reads the operand, which is by definition what precedes the token.
            fwd = [l for l in lines[i + 1:i + 4] if l.strip()][:2]
            window = " ".join(back + [line] + fwd)
            operand = (" ".join(back[-1:]) + " " + line[:m.start()])[-200:]
            rows.append((os.path.relpath(p, SH), i + 1, tok,
                         classify(tok, window, tok in live_hashes, operand), window))
from collections import Counter
c = Counter(r[3] for r in rows)
print("\n64-hex tokens in delivery text files: %d" % len(rows))
for k in ("LIVE", "HISTORY", "TEXTDIGEST", "ABSENT_BY_DESIGN", "DIRECTIVE", "UNLABELLED"):
    print("   %-11s %d" % (k, c.get(k, 0)))
bad = [r for r in rows if r[3] in ("DIRECTIVE", "UNLABELLED")]
print("\nFINDINGS (a dead hash used as an operand of an instruction, or dead and unlabelled): %d" % len(bad))
for rel, ln, tok, cls, w in bad:
    print("   %s %s:%d  %s…" % (cls, rel, ln, tok[:12]))
    print("        " + re.sub(r"\s+", " ", w)[-150:])

# ---------------- mandatory self-test: SAME classify() the scan uses ----------------
CASES = [
    # (token, window, operand, live?, expected)
    ("a" * 64, "1) cd 6_proverki; убедиться, что sha256 отчёта равен эталону: aaaa", "равен эталону (pack.json): " + "a" * 64, False, "DIRECTIVE"),
    ("b" * 64, '"step1": "copy the report and verify its sha256 equals bbb', "verify its sha256 equals " + "b" * 64, False, "DIRECTIVE"),
    # the exact prose that fooled the first classifier: "эталон" appears far above, the
    # token itself is labelled v1 - it must come out as HISTORY, not DIRECTIVE
    ("c" * 64, "пока эталон не зафиксирован. Линия целиком (старые хеши сохранены): v1 cccc", "сохранены): v1  " + "c" * 64, False, "HISTORY"),
    ("d" * 64, '"docxShaSupersededAll": [ "dddd", "eeee" ]', '[ "dddd", "eeee" ]', False, "HISTORY"),
    ("e" * 64, '"sha256_normalized": "eeee",', '"sha256_normalized": "' + "e" * 64, False, "TEXTDIGEST"),
    ("f" * 64, "этот хеш равен эталону ffff", "равен эталону " + "f" * 64, True, "LIVE"),
    ("0" * 64, "упомянут без всякой подписи 0000", "подписи " + "0" * 64, False, "UNLABELLED"),
    # a bare record of a measured input file: dead and unlabelled must still be caught
    ("9" * 64, '{"path": "../x.docx", "bytes": 421182, "sha256": "9999', '"sha256": "' + "9" * 64, False, "UNLABELLED"),
    # a derivative artifact the delivery refuses to ship, said out loud: acceptable
    ("8" * 64, '"pdf_sha256": "8888 ... The PDF is deliberately NOT part of the delivery',
     '"pdf_sha256": "' + "8" * 64, False, "ABSENT_BY_DESIGN"),
]
ok = 0
print("\n--- self-test: the same classify() on planted inputs ---")
for tok, win, op, liv, want in CASES:
    got = classify(tok, win, liv, op)
    good = got == want
    ok += good
    print("   want=%-11s got=%-11s %s  %s" % (want, got, "OK" if good else "WRONG", re.sub(r"\s+", " ", op)[:62]))
if ok != len(CASES):
    sys.exit("SELF-TEST FAILED: %d of %d planted cases misclassified - the scan cannot be trusted" % (ok, len(CASES)))
print("self-test: %d of %d planted cases correct" % (ok, len(CASES)))
OUT = os.path.join(SH, "6_proverki", "evidence", "dead_hashes_directive.json")
json.dump({"delivery_tree": SH, "files": len(files), "tree_bytes": sum(x[1] for x in files),
           "tokens": len(rows), "by_class": dict(c),
           "rule": "a dead hash inside a directive operand window (70 chars before the token) "
                   "is a finding; a dead hash labelled by history or text-digest wording nearby "
                   "or within two following lines is an honest record; an unlabelled dead hash is "
                   "a finding because a reader cannot tell the two apart",
           # The report records only a 16-character prefix of each offending token:
           # embedding the full hash would make this artifact itself a text file of
           # unlabelled dead hashes, so a rerun of the gate would report its own report
           # as a violation - which is what happened on the first delivery run. A prefix
           # still locates the finding for a human without re-introducing the defect.
           "findings": [{"file": r[0], "line": r[1], "token_prefix": r[2][:16], "class": r[3]} for r in bad]},
          open(OUT, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("\nwrote " + OUT)
if bad:
    sys.exit("DEAD-HASH DIRECTIVES: %d instruction(s) tell the reader to verify a hash no delivered file carries" % len(bad))
print("VERDICT: EVERY DEAD HASH IN THE DELIVERY IS LABELLED HISTORY OR A TEXT DIGEST; NO INSTRUCTION POINTS AT A DEAD OPERAND")
