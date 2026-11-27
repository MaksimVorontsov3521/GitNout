# -*- coding: utf-8 -*-
import os, re
from docx import Document
from docx.shared import Pt
p = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
d = Document(p)
paras = d.paragraphs
texts = [q.text for q in paras]
def is_mono(q):
    for r in q.runs:
        if r.font.name and "Courier" in r.font.name: return True
    return False
print("=== empty paragraphs (index, neighbours, style, mono?) ===")
for i, t in enumerate(texts):
    if not t.strip():
        prev = texts[i-1][:70] if i > 0 else "<start>"
        nxt = texts[i+1][:70] if i+1 < len(texts) else "<end>"
        print("  p%-4d style=%-14s mono=%-5s prev=%r next=%r" % (i, paras[i].style.name, is_mono(paras[i]), prev, nxt))
print("\n=== double spaces OUTSIDE monospace paragraphs ===")
n = 0
for i, t in enumerate(texts):
    if is_mono(paras[i]): continue
    for m in re.finditer(r"  +", t):
        n += 1
        print("  p%-4d | ...%s␣␣%s..." % (i, t[max(0,m.start()-45):m.start()].replace("\n"," "), t[m.end():m.end()+45].replace("\n"," ")))
print("  total:", n)
print("\n=== repeated words (threshold lowered to 2 characters) ===")
# The threshold used to be 3, which is why the duplicated short word "во во" sat
# in this document through every earlier audit run: function words are the commonest
# place for this typo and they were exactly the ones excluded. Table cells are now
# scanned as well as paragraphs, because the old rule looked only at paragraphs.
units = texts + [c.text for tb in d.tables for r_ in tb.rows for c in r_.cells]
rep = 0
REPEAT_PAT = r"\b([\w\-]{2,})\s+\1\b"
for i, t in enumerate(units):
    for m in re.finditer(REPEAT_PAT, t, re.I):
        rep += 1
        print("  u%-4d | ...%s..." % (i, t[max(0,m.start()-50):m.end()+50]))
print("  repeated-word sites: %d" % rep)

print("\n=== missing space after a sentence terminator ===")
# A full stop followed straight by a letter is a concatenation accident. It is
# invisible to the double-space rule above, and it arises specifically from implicit
# Python string concatenation, which is how this document is generated.
# GUARD: the dot must not be inside an identifier. The first version of this rule
# reported six "sites" that were net names - N0.OUT, NR.IN, NR.OUT - because a digit
# or a Latin letter before the dot means a signal name, not a sentence. Requiring a
# Cyrillic letter before the dot and a capital after it removes all six and still
# catches the real case "нет.Уровни".
NOSPACE_PAT = r"(?<![A-Za-z0-9.])[А-Яа-яЁё]\.(?=[А-ЯA-Z])"
# A comma followed straight by a letter is the same accident on a smaller scale.
# Case matters: the conjunction "а" is lowercase, so the first version of this rule,
# which looked only for capitals, could not catch its own planted case.
COMMA_PAT = r",(?=[А-Яа-яЁёA-Za-z])"
nospace = comma = 0
for i_, t in enumerate(units):
    for m in re.finditer(NOSPACE_PAT, t):
        nospace += 1
        print("  u%-4d | ...%s..." % (i_, t[max(0, m.start() - 50):m.start() + 50]))
    for m in re.finditer(COMMA_PAT, t):
        comma += 1
        print("  u%-4d | ...%s..." % (i_, t[max(0, m.start() - 50):m.start() + 50]))
print("  missing-space sites: %d | missing-space-after-comma sites: %d" % (nospace, comma))

print("\n=== a word repeated across a number in the same clause ===")
# "расхождений — 0 расхождений" is a tautology the adjacent-repeat rule cannot see,
# because a number and a dash sit between the two copies. It arises from concatenating
# a literal prefix, a computed value and a literal suffix - the generator's own idiom -
# so it needs a rule of its own.
TAUT_PAT = r"([А-Яа-яЁё]{4,})[\s\-—:]*[\d,]+[\s\-—:]*(\1)"
taut = 0
for i_, t in enumerate(units):
    for m in re.finditer(TAUT_PAT, t, re.I):
        taut += 1
        print("  u%-4d | ...%s..." % (i_, re.sub(r"\s+", " ", t[max(0, m.start() - 55):m.end() + 55])))
print("  tautology sites: %d" % taut)

print("\n=== self-test: the two rules above must catch planted defects ===")
PLANTED = [
    ("duplicated short word (2 chars)", "совпадают поканально во во всех 20 фазах", REPEAT_PAT),
    ("duplicated long word",            "данный данный отчёт невозможно получить", REPEAT_PAT),
    ("missing space after stop",        "потерянных значений нет.Уровни встреченные", NOSPACE_PAT),
    ("comma then lowercase",            "в работе проверен не на цифрах,а на схемах", COMMA_PAT),
    ("stop then lowercase letter",      "отчёт.он печатает его дословно", NOSPACE_PAT.replace("?=[А-ЯA-Z]", "?=[А-Яа-яA-Z]")),
    ("word across a number (tautology)", "расхождений — 0 расхождений суммарно", TAUT_PAT),
]
caught = 0
for name, txt, pat in PLANTED:
    hit = bool(re.search(pat, txt))
    if hit: caught += 1
    print("  %-32s -> %s" % (name, "CAUGHT" if hit else "NOT CAUGHT"))
print("  self-test: %d of %d planted defects caught" % (caught, len(PLANTED)))
if caught != len(PLANTED):
    raise SystemExit("SELF-TEST FAILED: a planted defect went undetected, so the clean verdicts above are meaningless")
# a clean sentence must NOT be flagged, or the rules are a blanket
CLEAN = ["совпадают поканально во всех 20 фазах", "нет. Уровни встреченные в волнах",
         "данный отчёт невозможно получить", "проверен не на цифрах, а на схемах",
         "входы E0 соединены с N0.OUT, N1.OUT и WE", "стробы 1GN и 2GN: NR.IN = rd, NR.OUT идёт на оба",
         "глава иллюстрирует закон на ЭВМ Минск-32, Р120, Р1200",
         "суммарное число расхождений по всем пяти проектам равно 0",
         "Ресурсы: 9 / 10,570 ( < 1 % ) логических элементов, 6 / 336 ( 1 % ) выводов",
         "привязан к V0.1 (единице), как и требует раздел 4.4"]
fp = sum(1 for t in CLEAN for pat in (REPEAT_PAT, NOSPACE_PAT, COMMA_PAT, TAUT_PAT) if re.search(pat, t))
print("  false positives on %d correct sentences: %d" % (len(CLEAN), fp))
if fp:
    raise SystemExit("SELF-TEST FAILED: the rules flag correct text, so they are a blanket, not a check")
print("\n=== paragraphs whose text ends mid-sentence (no terminator) ===")
for i, t in enumerate(texts):
    s = t.strip()
    if not s or is_mono(paras[i]) or paras[i].style.name.startswith("Heading"): continue
    if s.endswith((".", "!", "?", ":", ";", "»", ")", "]", '"')): continue
    print("  p%-4d | ...%s" % (i, s[-90:]))
print("\n=== 'list lost empty' phrasing ===")
for i, t in enumerate(texts):
    if "потерянных пуст" in t: print("  p%d | %s" % (i, t[:300]))
