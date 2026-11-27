# -*- coding: utf-8 -*-
# One paragraph count changed between the previous build and this one. Find out which
# one, rather than assume the repair was clean: a silently vanished paragraph would be
# a regression no other checker here would notice, because they all test content that
# is present, not content that is absent.
import re
from docx import Document
cur = Document("../0_zadanie_i_otchet/lab13_report.docx")
old = Document("../0_zadanie_i_otchet/lab13_report.docx")
# ВНУТРИ сдачи этот скрипт НЕ РАБОТАЕТ, и отказ печатается явно, а не молчится.
# Он сравнивает авторский отчёт с доставленным, а авторской копии в доставке нет:
# оба пути указывают на один файл, и дифф был бы пуст не потому, что расхождений
# нет, а потому, что сравнивать нечем - то есть ложным «чисто». Скрипт везётся как
# свидетельство метода: именно диффом по difflib была названа по имени удалённая
# строка заголовка раздела 2, когда 21 проверка из 22 сообщила «чисто»
# (см. ../6_proverki/evidence/structural_regression.json).
print("NOT RUNNABLE INSIDE THE DELIVERY: current and delivered documents are the same file. This is the author-side paragraph diff, shipped as method evidence. Run it in the authoring tree, where the two paths differ. Exit code 3 means NOT APPLICABLE BY CONSTRUCTION, which is distinct from 1 = a real difference was found.")
raise SystemExit(3)   # 3 = NOT APPLICABLE BY CONSTRUCTION; 1 would read as a real difference found
def sig(d):
    return [re.sub(r"\s+", " ", q.text.strip()) for q in d.paragraphs]
c, o = sig(cur), sig(old)
print("current paragraphs: %d | delivered: %d" % (len(c), len(o)))
# align by longest-common subsequence of normalized first 60 chars
def key(s): return s[:60]
oc = [key(x) for x in o]; cc = [key(x) for x in c]
import difflib
sm = difflib.SequenceMatcher(None, oc, cc, autojunk=False)
for tag, a, b, i, j in sm.get_opcodes():
    if tag == "equal": continue
    print("\n[%s] old %d:%d -> new %d:%d" % (tag, a, b, i, j))
    for x in o[a:b]: print("   OLD: " + x[:150])
    for x in c[i:j]: print("   NEW: " + x[:150])
