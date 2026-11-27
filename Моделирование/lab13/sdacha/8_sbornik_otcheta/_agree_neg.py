# -*- coding: utf-8 -*-
# Negative test, corrected. The checker hands the exemption rules the text
# IMMEDIATELY BEFORE the numeral, so a prefix must not contain the numeral itself;
# the previous version appended "21 " to the prefix and therefore could never
# match a rule anchored at \s+$ - a bug in the test, not in the checker.
import re
PREP = re.compile(r"\b(из|от|до|без|у|при|на|в|во|за|под|над|через|между|вокруг|о|об)\s+$", re.I)
ALL = re.compile(r"(всех|всёх)\b[^\n]{0,40}$", re.I)
MULTI = re.compile(r"\d[\s,]*\d{3}")
CASES = [
    ("nominative 52 сегментов",  "программа насчитала ",            "52",   "CATCH"),
    ("nominative 64 комбинаций", "исчерпывающим перебором ",        "64",   "CATCH"),
    ("oblique из 21 экземпляра", "Схема смонтирована из ",          "21",   "EXEMPT"),
    ("всех at distance",         "перебором ВСЕХ 2 в 6-й = ",       "64",   "EXEMPT"),
    ("multigroup 1024 слов",     "десять адресных линий дают ",     "1024", "EXEMPT"),
    ("multigroup 1,229,701",     "всего ",                          "1,229,701", "EXEMPT"),
    # «на 256 элементов» is the NORM, not a defect: after «на» expressing capacity
    # Russian governs the genitive plural, as in «комната на 5 человек». Expecting a
    # CATCH here was the test's error, not the checker's, so the expectation is EXEMPT.
    ("capacity after на",        "обязательным обходом примера на ", "256",  "EXEMPT"),
    ("digit form after на",      "распологает те же элементы в решётку ", "16", "CATCH"),
    ("genitive after на всех",   "формула проверена на всех ",      "64",   "EXEMPT"),
]
bad = 0
for name, pre, num, want in CASES:
    hit = bool(ALL.search(pre) or PREP.search(pre) or MULTI.search(num))
    got = "EXEMPT" if hit else "CATCH"
    ok = got == want
    if not ok: bad += 1
    print("   %-28s want=%-7s got=%-7s %s" % (name, want, got, "OK" if ok else "WRONG"))
print("\nnegative test failures: %d" % bad)
raise SystemExit(1 if bad else 0)
