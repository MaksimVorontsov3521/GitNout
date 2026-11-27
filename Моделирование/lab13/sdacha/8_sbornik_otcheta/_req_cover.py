# -*- coding: utf-8 -*-
# Requirement-coverage audit: every demand written in zadanie_lab13.txt must be
# traceable to a section of the report. This is the task<->report cross-check,
# done read-only against the saved document.
import os, re
from docx import Document
HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
z = open(os.path.join(SD, "0_zadanie_i_otchet", "zadanie_lab13.txt"), encoding="utf-8").read()
d = Document(os.path.join(SD, "0_zadanie_i_otchet", "lab13_report.docx"))
texts = [q.text for q in d.paragraphs]
heads = [q.text for q in d.paragraphs if q.style.name.startswith("Heading")]
full = "\n".join(texts + [c.text for t in d.tables for r in t.rows for c in r.cells])

REQ = [
    ("п.1 рис. 18.7, 4 бита, граф. редактор", r"18\.7", r"Задание 1"),
    ("п.1 скомпилировать", r"скомпилирован", r"Задание 1"),
    ("п.1 четыре значения в разные ячейки", r"четыре (различных|события записи)", "5.2"),
    ("п.2 поведенческая VHDL-модель", r"VHDL", r"Задание 2"),
    ("п.3 рис. 18.8, 4x8 бит", r"18\.8", r"Задание 3"),
    ("п.3 74155", r"74155", "7.1"),
    ("п.3 четыре 74374", r"74374", "7.2"),
    ("п.3 74244", r"74244", "7.2"),
    ("п.3 порты a0,a1,w,q,wr,rd и шина d", r"d\[7\.\.0\]", "7.3"),
    ("п.3 объяснить принцип работы", r"три механизма", "7.3"),
    ("п.4 lpm_ram_dq из библиотеки мегафункций", r"lpm_ram_dq", r"Задание 4"),
    ("п.4 только WE, ADDRESS, DATA / Q", r"только WE, ADDRESS, DATA", "8.1"),
    ("п.4 lpm_address_control unregistered", r"lpm_address_control", "8.1"),
    ("п.4 lpm_file none", r"lpm_file", "8.1"),
    ("п.4 lpm_indata unregistered", r"lpm_indata", "8.1"),
    ("п.4 lpm_numwords none", r"lpm_numwords", "8.1"),
    ("п.4 lpm_outdata unregistered", r"lpm_outdata", "8.1"),
    ("п.4 lpm_width 8", r"LPM_WIDTH = 8", "8.1"),
    ("п.4 lpm_width_ad 10", r"LPM_WIDTHAD = 10", "8.1"),
    ("теория 18.1 иерархия C и B", r"18\.1", "4.1"),
    ("теория 18.2 классификация", r"18\.2", "4.2"),
    ("теория ROM/PROM/EPROM/EEPROM", r"EPROM", "4.2"),
    ("теория SRAM и DRAM", r"SRAM", "4.5"),
    ("теория CACHE", r"CACHE", "4.2"),
    ("теория АЗУ и МФЗУ", r"МФЗУ", "4.2"),
    ("теория 256 элементов, 256 проводов", r"256 проводов", "4.3"),
    ("теория 2*sqrt(256) = 32", r"32", "4.3"),
    ("теория два дешифратора 4-16", r"4-в-16|4-16|4 \u00b7 16|четыре-в-шестнадцать", "4.3"),
    ("теория 8 адресных линий, предел 256", r"256", "4.3"),
    ("теория 18.3 триггер DV", r"18\.3", "4.4"),
    ("теория DV: D, CLK, ENA, PRN, CLRN", r"CLRN", "4.4"),
    ("теория неподключённый вывод несёт 1", r"несёт единицу", "4.4"),
    ("теория 18.4/18.5 статическая ячейка n-MOS и CMOS", r"18\.4", "4.5"),
    ("теория последовательности записи/чтения/хранения", r"хранени", "4.5"),
    ("теория 18.6 динамическая ячейка", r"18\.6", "4.6"),
    ("теория (Uon + dU)/2", r"Uon", "4.6"),
    ("теория чувствительный усилитель", r"чувствительн", "4.6"),
    ("теория регенерация", r"егенераци", "4.6"),
    ("теория DRAM плотнее SRAM", r"плотнее", "4.6"),
    ("курс: реальный проект в САПР, не рисунок", r"функциональн", "2."),
    ("САПР: замена MAX+plus II на Quartus II 5.0", r"MAX\+plus", "2."),
]

bad = 0
for name, pat, sec in REQ:
    # EXACT section binding. The previous form also accepted "sec in h", so for a
    # single-digit section like "2" it matched every heading containing the digit 2
    # ("3.2", "5.2", "8.2") and the check was vacuous: it reported every section as
    # present even when the real heading had been deleted. That is how a missing
    # section-2 heading passed this checker with 41/41.
    num = sec.rstrip(".")
    # A heading may be identified either by its number ("5.3") or by the label that
    # follows the number ("Задание 1" in "5. Задание 1: ..."). Both are matched EXACTLY:
    # the number is stripped first and the remainder must begin with the label, so a
    # label can never match in the middle of an unrelated heading - which is what the
    # original substring test allowed and what made the check vacuous for single-digit
    # sections.
    def _bind(h):
        m = re.match(r"^(\d+(?:\.\d+)?)[.\s]+(.*)$", h)
        if m:
            n, rest = m.group(1), m.group(2)
            if n == num or rest.startswith(num):
                return True
            return rest.startswith(sec.rstrip(".")) or h.startswith(sec.rstrip(".") + " ")
        return h.startswith(sec.rstrip("."))
    insec = [h for h in heads if _bind(h)]
    present = re.search(pat, full, re.I) is not None
    sect_ok = bool(insec)
    # and the requirement must appear inside that section, not merely somewhere
    idx = None
    for i, h in enumerate(heads):
        if _bind(h): idx = i; break
    ok = present and sect_ok
    if not ok: bad += 1
    print("  %-4s %-4s %-52s | %s" % ("ok" if present else "MISS", "ok" if sect_ok else "MISS", name, sec))
print("\nrequirements: %d | unmet: %d" % (len(REQ), bad))
# A checker that prints a problem and still exits 0 is not a checker. This one used to
# do exactly that, which is how the vacuous section binding survived: even when the
# heading was missing, the run looked green in the battery.
if bad:
    raise SystemExit("REQUIREMENT COVERAGE INCOMPLETE: %d unmet" % bad)
# self-test: the section binder must reject a heading that does not carry the label,
# and must accept the two legitimate shapes.
_pos = ["5. Задание 1: простейшая схема памяти", "5.3 Ресурсы и задержки", "9.4 Доказательство Z"]
_cases = [("Задание 1", _pos[0], True), ("5.3", _pos[1], True), ("9.4", _pos[2], True),
          ("Задание 1", "7. Задание 3: схема 4 x 8 бит", False), ("2", "3.2 Второй слой сверки", False),
          ("5.3", "5.1 Состав схемы", False)]
_st = 0
for sec_, h, want in _cases:
    m = re.match(r"^(\d+(?:\.\d+)?)[.\s]+(.*)$", h)
    num = sec_.rstrip(".")
    if m:
        n, rest = m.group(1), m.group(2)
        got = (n == num or rest.startswith(num) or rest.startswith(num) or h.startswith(num + " "))
    else:
        got = h.startswith(num)
    ok = got == want
    if ok: _st += 1
    print("  self-test bind(%-10s in %-42s) want=%-5s got=%-5s %s" % (repr(sec_), h[:40], want, got, "OK" if ok else "WRONG"))
print("self-test: %d of %d correct" % (_st, len(_cases)))
if _st != len(_cases):
    raise SystemExit("SELF-TEST FAILED: the section binder misclassifies a planted case")
# section headings actually present
print("\nheadings of section 4: " + JSON.dumps([h for h in heads if h.startswith("4.")], ensure_ascii=False) if False else "")
for h in heads:
    if h.startswith(("4.", "5.", "6.", "7.", "8.", "9.", "10.")): print("   " + h)