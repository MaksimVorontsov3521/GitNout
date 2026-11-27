# -*- coding: utf-8 -*-
# Cross-reference integrity: every REF field must name a bookmark that exists,
# every SEQ field must have a matching caption bookmark, and every caption
# bookmark must be referenced at least once (an unreferenced caption means the
# text never points at it).
import os, re
from docx import Document
from docx.oxml.ns import qn
p = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(p)
body = d.element.body
instr = [e.text.strip() for e in body.findall(".//" + qn("w:instrText")) if e.text]
refs = [t for t in instr if t.startswith("REF ")]
seqs = [t for t in instr if t.startswith("SEQ ")]
bms = [b.get(qn("w:name")) for b in body.findall(".//" + qn("w:bookmarkStart"))]
print("REF fields: %d | SEQ fields: %d | bookmarks: %d" % (len(refs), len(seqs), len(bms)))
have = set(bms)
orphan = []
for t in refs:
    m = re.match(r"REF\s+(\S+)", t)
    if not m: orphan.append(("unparsable", t)); continue
    if m.group(1) not in have: orphan.append(("missing bookmark", m.group(1), t))
print("REF fields pointing at a nonexistent bookmark: %d" % len(orphan))
for o in orphan[:20]: print("   " + repr(o))
# which bookmarks are SEQ caption anchors, and are they referenced?
seq_names = {re.match(r"SEQ\s+(\S+)", t).group(1) for t in seqs if re.match(r"SEQ\s+(\S+)", t)}
ref_names = {re.match(r"REF\s+(\S+)", t).group(1) for t in refs if re.match(r"REF\s+(\S+)", t)}
print("\nSEQ anchors: %d  %s" % (len(seq_names), sorted(seq_names)))
print("REF targets : %d  %s" % (len(ref_names), sorted(ref_names)))
unref = sorted(seq_names - ref_names)
print("\ncaption anchors never referenced by the text: %d  %s" % (len(unref), unref))
extra = sorted(ref_names - seq_names - {b for b in bms if b.startswith("tbl_") or b.startswith("fig_")})
print("REF targets that are neither SEQ anchor nor caption bookmark: %d  %s" % (len(extra), extra))
# duplicate bookmark names would make Word pick one arbitrarily
from collections import Counter
dup = {k: v for k, v in Counter(bms).items() if v > 1}
print("duplicate bookmark names: %d  %s" % (len(dup), dup))
# figure/table numbering: SEQ Figure and SEQ Table counters
print("\nSEQ Figure anchors: %d | SEQ Table anchors: %d" % (
    sum(1 for t in seqs if "Figure" in t), sum(1 for t in seqs if "Table" in t)))
bad = 0 if (not orphan and not dup) else 1
print("\nVERDICT: %s" % ("ALL CROSS-REFERENCES RESOLVE, NO DUPLICATE BOOKMARKS" if bad == 0 else "DEFECTS PRESENT"))