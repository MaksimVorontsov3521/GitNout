# -*- coding: utf-8 -*-
# Adjective-noun NUMBER agreement. Russian adjective endings are regular enough that
# the number can be read off the ending: plural genitive/prepositional "-ых/-их",
# plural instrumental "-ими/-ами", singular masculine/neuter genitive "-ого/-его",
# singular instrumental "-ым/-им". A plural-form adjective standing next to a
# singular noun (or the reverse) is a mismatch. The checker only NARROWS the search;
# every flagged pair is adjudicated by reading it, because a regular ending can also
# belong to a noun ("старых друзей" fine, but "синих" as a noun is a different case).
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")   # запускать из sdacha/8_sbornik_otcheta
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
PLURAL_ADJ = re.compile(r"\b\w+(?:ых|их|ими|ами)\b")
SING_ADJ = re.compile(r"\b\w+(?:ого|его|ым|им)\b")
NOUN_SING_END = re.compile(r"\b\w+(?:о|а|е|ы|и|ь|мя|у|ю|ам|ям|ом|ем|ой|ей|ию|ья|я)\b")
TOK = re.compile(r"[А-Яа-яЁё]{3,}")
pairs = []
for u in units:
    toks = [(m.group(0), m.start()) for m in TOK.finditer(u)]
    for k in range(len(toks) - 1):
        a, b = toks[k][0], toks[k + 1][0]
        la, lb = a.lower(), b.lower()
        if PLURAL_ADJ.search(la) and not PLURAL_ADJ.search(lb) and SING_ADJ.search(lb):
            pairs.append(("PLURAL adj + SINGULAR noun", a, b, u))
        elif SING_ADJ.search(la) and not SING_ADJ.search(lb) and PLURAL_ADJ.search(lb):
            pairs.append(("SINGULAR adj + PLURAL noun", a, b, u))
seen = set(); out = []
for kind, a, b, u in pairs:
    key = (kind, a.lower(), b.lower())
    if key in seen: continue
    seen.add(key)
    i = u.lower().find(a.lower())
    out.append((kind, a, b, re.sub(r"\s+", " ", u[max(0, i - 55):i + 75])))
print("candidate mismatches (deduplicated by word pair): %d" % len(out))
for kind, a, b, ctx in out:
    print("\n   [%s] %s %s\n      ...%s..." % (kind, a, b, ctx.strip()))
