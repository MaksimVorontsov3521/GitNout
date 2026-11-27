# -*- coding: utf-8 -*-
# A comma-delimited participial phrase whose head is a numeral + noun in the NOMINATIVE
# takes a nominative-plural participle, not a genitive-plural one: "Три утверждения,
# СДЕЛАНЫЕ ошибочно, исправлены" - because the head is the subject of the finite predicate
# that follows the phrase. The genitive plural is correct in the other construction,
# "2 сдвоенных элемента" and "8 адресных линий", where the noun itself is genitive singular
# after the numeral and no comma separates a phrase. The distinction is the comma, so the
# rule requires it: without a comma the modifier is a plain attribute and the genitive is
# the norm. The numeral-agreement layer of this work audits nouns only and therefore could
# not see a participle at all.
import os, re, sys
from docx import Document
HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def _find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        p = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(p):
            return p
    return None
DOCX = _find("lab13_report.docx") or _find("0_zadanie_i_otchet", "lab13_report.docx")
if DOCX is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
NUM = r"(?:[Дд]ва|[Тт]ри|[Чч]етыре|[Пп]ять|[Шш]есть|[Сс]емь|[Вв]осемь|[Дд]евять|[Дд]еся[а-я]*|\d{1,4})"
# The genitive-plural participle: passive forms end -нных/-нних ("сделанных",
# "запущенных"), past active forms end -вших/-щих/-ших ("написавших", "отшедших").
# The nominative plural of the same word ends -нные/-ние/-вшие/-шие, so the two forms are
# separated by the case ending alone and no stem guessing is needed.
GEN = r"([а-яё]{2,}(?:нных|нних|вших|щих|ших))\b"
# The phrase must be set off on BOTH sides. "за 3 прохода, неопределённых состояний не
# возникло ни на одной комбинации" is not a phrase: the comma there opens a clause whose
# subject is the genitive noun itself, and no closing comma follows. Requiring the closing
# comma (optionally after a bracketed list) removes that false positive without touching
# the real one, "Три утверждения, сделанных ... ошибочно (...), исправлены".
RULE = re.compile(NUM + r"\s+[а-яё]+[а-яёыиё]\s*,\s*" + GEN + r"[^.]*?[,),]\s*[а-яё]+(?:ы|и|ли|ла|ло)", re.U)
# A broken conditional: a FULL adjective ("неизвестный") followed by "бы". Russian puts the
# short predicative form there ("неизвестен был бы", or simply "неизвестный без ..."), so a
# full adjectival ending plus "бы" is a sentence with no predicate behind the particle.
# Pronouns ("какой бы", "что бы") cannot match: three letters and the -ый/-ий ending are
# required, and the alternation is anchored to the adjective ending, not to any word.
BARE = re.compile(r"\b([а-яё]{3,}(?:ый|ий))\s+бы\b", re.U)
def audit(texts):
    """Both scans run over the same list of paragraph texts and return the finding rows.
    Called identically by the live scan and by the self-test below."""
    out = []
    for i, t in enumerate(texts):
        for m in RULE.finditer(t):
            out.append((i, "GENITIVE PARTICIPLE AFTER A NOMINATIVE NUMERAL HEAD", m.group(1),
                        re.sub(r"\s+", " ", t[max(0, m.start() - 30):m.end() + 70])))
        for m in BARE.finditer(t):
            out.append((i, "SHORT ADJECTIVE WITH 'бы' BUT NO VERB", m.group(1),
                        re.sub(r"\s+", " ", t[max(0, m.start() - 30):m.end() + 70])))
    return out
CASES = [
    ("Три утверждения, сделанных в ходе работы ошибочно, исправлены по измерениям.", "found"),
    ("Ещё один факт, неизвестный бы без моделирования, важен.", "found"),
    ("Четыре проекта, запущенных подряд, дали разный результат.", "found"),
    ("2 сдвоенных элемента BAND2 и 8 трёхвходовых NAND3.", "clean"),
    ("Три утверждения, сделанные в ходе работы ошибочно, исправлены.", "clean"),
    ("8 адресных линий различают 256 ячеек.", "clean"),
    ("Ещё один факт, неизвестный без моделирования, важен.", "clean"),
    ("Пять найденных способов перебраны полностью.", "clean"),
    ("Какой бы вариант ни выбрать, оба верны.", "clean"),
    ("Факт, неизвестный был бы без моделирования, всё равно верен.", "clean"),
    ("Два результата, полученные независимо, совпали.", "clean"),
    ("Сеть сходится за 3 прохода, неопределённых состояний не возникло ни на одной.", "clean"),
    ("Три утверждения, сделанных ошибочно (о двух уровнях), исправлены померками.", "found"),
]
def main():
    bad = 0
    print("=== self-test: the same audit() function, 13 planted cases ===")
    rows = audit([c[0] for c in CASES])
    hit = {i for i, _k, _t, _c in rows}
    for k, (txt, want) in enumerate(CASES):
        got = "found" if k in hit else "clean"
        ok = got == want
        bad += 0 if ok else 1
        print("   want=%-6s got=%-6s %s  %s" % (want, got, "OK " if ok else "MISCLASSIFIED", txt[:64]))
    if bad:
        raise SystemExit("SELF-TEST FAILED: %d misclassification(s)" % bad)
    print("self-test: %d of %d planted cases correct" % (len(CASES), len(CASES)))
    d = Document(DOCX)
    texts = [p.text.strip() for p in d.paragraphs if p.text.strip()]
    for p in d.tables:
        for row in p.rows:
            for c in row.cells:
                if c.text.strip():
                    texts.append(c.text.strip())
    rows = audit(texts)
    print("\nunits scanned: %d | findings: %d" % (len(texts), len(rows)))
    for i, kind, tok, ctx in rows:
        print("   %s: %s | ...%s..." % (kind, tok, ctx))
    print("\nVERDICT: %s" % ("NO MISFORMED PARTICIPLE OR BROKEN CONDITIONAL" if not rows else "FINDINGS PRESENT"))
    sys.exit(1 if rows else 0)
if __name__ == "__main__":
    main()
