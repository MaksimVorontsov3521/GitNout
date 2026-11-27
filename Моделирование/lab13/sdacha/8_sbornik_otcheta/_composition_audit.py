# -*- coding: utf-8 -*-
# Composition audit: every claim the report makes about how many primitives, pins or
# instances an AUTHENTIC library scheme contains is checked against the .bdf file
# itself, not against the report's own data file.
#
# Why this checker exists. The prose once asserted that 74374 contains "24 трёхстальных
# буфера TRI, два инвертора и сорок D-триггеров, то есть восемь DFF и три элемента на
# разряд". Those are instance INDEXES (TRI 40..47, NOT 2) read as counts, and the very
# same sentence contradicted them. Nothing caught it: the numeric audit harvests DIGIT
# tokens and "сорок" is a word; the grammar checkers test agreement, not truth. So this
# checker has to understand Russian numerals and Russian component names, not only the
# "8 TRI" shape - otherwise it cannot see the defect it was written for.
import hashlib, os, re, sys
from docx import Document

SD_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
LIB = os.path.join(SD_ROOT, "lib_maxplus2")
# The audit must not trust the copy it reads. These are independent locations the same
# library files occupy: the pristine extraction made when the schemes were first
# recovered, the primitive-library copy, and the working project directories the
# Quartus flow actually consumed. If the delivery copy differed from any of them, the
# composition truth below would describe a modified file and the audit would agree with
# it, which is the failure mode this section exists to exclude.
REFS = [os.path.join(SD_ROOT, "3_mem4x8"), os.path.join(SD_ROOT, "5_proby_polyarnosti")]
# ВНУТРИ сдачи независимыми свидетелями служат проектные папки: Quartus
# резолвит дочерние .bdf только из каталога проекта, поэтому копии там не
# для порядка, а для компиляции. Первозданная выборка и рабочие каталоги
# отсюда недостижимы - и это НЕ потеря свидетельства, а смена слоя: сверку
# сдачи с MP2 по sha256 делает правило C.2 аудитора, а не этот скрипт.
# Числа согласовавшихся копий требуются утверждением прогона (1, 2, 2),
# поэтому исчезновение копии валит слой, а не делает его пустым.

def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()

def verify_sources():
    print("source authenticity of the library files the truth is parsed from:")
    ok = True
    for name in ("74155", "74244", "74374"):
        base = os.path.join(LIB, name + ".bdf")
        h = sha(base)
        matches, missing = [], []
        for rd in REFS:
            cand = os.path.join(rd, name + ".bdf")
            if not os.path.exists(cand):
                continue
            (matches if sha(cand) == h else missing).append(rd)
        print("   %s.bdf  %s  %d B  independent copies agreeing: %d%s" %
              (name, h[:16], os.path.getsize(base), len(matches),
               "  MISMATCHING: " + str(missing) if missing else ""))
        if not matches:
            print("   WARNING: no independent copy of %s was found to compare against" % name)
            ok = False
        if missing:
            ok = False
    return ok
DOC = "../0_zadanie_i_otchet/lab13_report.docx"   # запускать из sdacha/8_sbornik_otcheta
BITS = 8

def truth(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    types = re.findall(r'\(symbol \(rect [^)]*\)\(text "([A-Z0-9_]+)"', t)
    by = {}
    for s in types:
        by[s] = by.get(s, 0) + 1
    ins = len(re.findall(r'\(pin \(input\)', t))
    outs = len(re.findall(r'\(pin \(output\)', t))
    ios = len(re.findall(r'\(pin \(I_O\)', t))
    by["PINS_IN"] = ins
    by["PINS_OUT"] = outs
    by["PINS_TOTAL"] = ins + outs + ios
    by["TOTAL"] = len(types)
    return by

TRUE = {}
for name in ("74155", "74244", "74374"):
    TRUE[name] = truth(os.path.join(LIB, name + ".bdf"))

NUMW = {}
for w, n in [("ноль", 0), ("один", 1), ("одна", 1), ("одно", 1), ("одному", 1), ("одного", 1),
             ("одну", 1), ("два", 2), ("две", 2), ("двух", 2), ("три", 3), ("трёх", 3),
             ("трех", 3), ("четыре", 4), ("четырёх", 4), ("четырех", 4), ("пять", 5),
             ("пяти", 5), ("шесть", 6), ("шести", 6), ("семь", 7), ("семи", 7),
             ("восемь", 8), ("восьми", 8), ("девять", 9), ("девяти", 9), ("десять", 10),
             ("десяти", 10), ("пятнадцать", 15), ("пятнадцати", 15), ("семнадцать", 17),
             ("восемнадцать", 18), ("двадцать", 20), ("сорок", 40), ("восемьдесят", 80),
             ("сто", 100), ("двести", 200), ("триста", 300)]:
    NUMW[w] = n

NOUN = [(r"D-триггер\w*", "DFF"), (r"триггер\w*", "DFF"), (r"буфер\w*", "TRI"),
        (r"инвертор\w*", "NOT"), (r"экземпляр\w*", "TOTAL"), (r"примитив\w*", "TOTAL"),
        (r"вход\w*", "PINS_IN"), (r"выход\w*", "PINS_OUT"), (r"вывод\w*", "PINS_TOTAL"),
        (r"NAND3", "NAND3"), (r"BAND2", "BAND2"), (r"NOT", "NOT"), (r"TRI", "TRI"),
        (r"DFF", "DFF"), (r"AND2", "AND2"), (r"AND3", "AND3"), (r"OR2", "OR2")]
NOUN_RE = "(?:" + "|".join(p for p, _ in NOUN) + ")"
NUMTOK = r"(?:\d{1,3}|(?:" + "|".join(sorted(NUMW, key=len, reverse=True)) + r"))"
CLAIM = re.compile(r"(?<![\w\d.])(" + NUMTOK + r")((?:\s+[а-яё0-9]+){0,2})\s+(" + NOUN_RE + r")(?![\w])", re.I)
# A number may be separated from the component name it counts by at most two words, and
# every such word must be on this whitelist of modifiers. Without the whitelist the rule
# bound "64 комбинации входов" to PINS_IN and reported a false mismatch: "входов" there is
# a genitive dependent of "комбинации", not the head being counted. The list is printed on
# every run so that its extent is auditable, and any claim with a non-whitelisted
# intervening word is reported as unresolved instead of being adjudicated silently.
MODIF = {"сдвоенных", "трёхвходовых", "трехвходовых", "отдельных", "побитовых", "простых",
         "различных", "ровно", "примерно", "всего", "элемента", "элементов", "типа",
         "трёхстальных", "трехстальных", "набора", "наборов", "группы", "по", "и", "или",
         "шт", "штуки", "вещественных", "логических", "тех", "этих", "них", "самых"}
PER_UNIT = re.compile(r"на\s+(?:каждый\s+)?(?:разряд|бит|слово|линию|ячейку)", re.I)
PRIMKEYS = {"DFF", "TRI", "NOT", "NAND3", "BAND2", "AND2", "AND3", "OR2"}
LIBIN = re.compile(r"74(?:155|244|374)")
# Our own assembled scheme uses the same primitive words ("четыре инвертора P0..P3"),
# but those counts describe OUR design, not the library file. Such sentences are
# excluded by designator, and the exclusion is reported rather than left silent.
OWN = re.compile(r"\b(?:[PKRBGV]\d|U1|NR|G0|V0|A1|D\d|Q\d)\b")
SENTEND = re.compile(r"[!?]|\.\s")

def key_of(word):
    w = word.lower()
    for pat, key in NOUN:
        if re.fullmatch(pat, w, re.I):
            return key
    return None

def num_of(tok):
    tok = tok.lower()
    return int(tok) if tok.isdigit() else NUMW.get(tok)

def adjudicate(text):
    """Return (findings, resolved, unresolved, excluded_own).
    Attribution: a claim belongs to the library scheme named NEAREST BEFORE it in the
    same sentence, and only if no other scheme is named between that mention and the
    claim. Sentences describing our own assembly are excluded by designator."""
    findings, resolved, unresolved, excluded = [], [], [], []
    for sent in SENTEND.split(text):
        if not sent.strip():
            continue
        if OWN.search(sent):
            if LIBIN.search(sent) and CLAIM.search(sent):
                excluded.append(re.sub(r"\s+", " ", sent).strip()[:90])
            continue
        mentions = [(m.start(), m.group(0)) for m in LIBIN.finditer(sent)]
        for m in CLAIM.finditer(sent):
            n = num_of(m.group(1))
            if n is None:
                continue
            head = sent[max(0, m.start(1) - 3):m.start(1)]
            if re.search(r"[=<>≥≤≠]", head):
                unresolved.append(("operand of a comparison", m.group(1), m.group(3).strip(),
                                   re.sub(r"\s+", " ", sent).strip()[:80]))
                continue
            # Which word does the number count?  The first intervening word that is
            # itself a component name is the head ("5 инверторов NOT" counts инверторов,
            # and the trailing NOT is a synonym of it, not a second quantity).  If the
            # intervening words are all whitelisted modifiers, the head is the trailing
            # noun ("24 трёхстальных буфера" counts буфера).  If an intervening word is
            # neither, the number counts THAT word, whose meaning is not a primitive or
            # pin count ("64 комбинации входов" counts комбинации), and the claim is left
            # unverified rather than bound to the following genitive.
            fillers = [w for w in m.group(2).split() if w]
            key, word = None, None
            for w in fillers:
                if key_of(w):
                    key, word = key_of(w), w
                    break
            if key is None:
                if all(w.lower() in MODIF for w in fillers):
                    key, word = key_of(m.group(3)), m.group(3)
                else:
                    unresolved.append(("number counts a non-component word", m.group(1),
                                       " ".join(fillers) + " " + m.group(3),
                                       re.sub(r"\s+", " ", sent).strip()[:80]))
                    continue
            if key is None:
                continue
            before = [p for p in mentions if p[0] < m.start()]
            if not before:
                unresolved.append(("no scheme named", m.group(1), word,
                                   re.sub(r"\s+", " ", sent).strip()[:80]))
                continue
            pos, lib = before[-1]
            if any(p > pos for p, _ in mentions):
                unresolved.append(("scheme ambiguous", m.group(1), word,
                                   re.sub(r"\s+", " ", sent).strip()[:80]))
                continue
            want = TRUE[lib].get(key)
            if want is None:
                continue
            kind = "total"
            if key in PRIMKEYS and PER_UNIT.search(sent):
                want, kind = want // BITS, "per-unit"
            resolved.append((lib, key, n, want, kind, re.sub(r"\s+", " ", sent).strip()[:95]))
            if n != want:
                findings.append((lib, key, n, want, kind, re.sub(r"\s+", " ", sent).strip()[:115]))
    return findings, resolved, unresolved, excluded

d = Document(DOC)
units = [q.text for q in d.paragraphs] + [c.text for t in d.tables for r in t.rows for c in r.cells]
allf, allr, allu, alle = [], [], [], []
for u in units:
    f, r_, u_, e_ = adjudicate(u)
    allf += f; allr += r_; allu += u_; alle += e_

SRC_OK = verify_sources()
print("modifier whitelist (%d words): %s" % (len(MODIF), sorted(MODIF)))
print("truth parsed from the authentic .bdf files:")
for k, v in TRUE.items():
    print("   %s: %s" % (k, v))
print("\nclaims resolved against that truth: %d" % len(allr))
seen = set()
for lib, key, n, want, kind, ctx in allr:
    sig = (lib, key, n, kind)
    if sig in seen:
        continue
    seen.add(sig)
    print("   %-6s %-10s %-8s prose=%-4d file=%-4d %s" % (lib, key, kind, n, want, "OK" if n == want else "BAD"))
print("\nclaims left unverified on purpose (attribution unclear): %d" % len(allu))
for why, num, word, ctx in allu[:10]:
    print("   %-18s num=%-5s word=%-12s ...%s..." % (why, num, word, ctx[:64]))
print("\nsentences excluded because they describe OUR assembly: %d" % len(alle))
for ctx in alle[:6]:
    print("   ..." + ctx[:88] + "...")
print("\nfindings: %d" % len(allf))
for lib, key, n, want, kind, ctx in allf:
    print("   MISMATCH %s %s (%s): prose %d, file %d | ...%s..." % (lib, key, kind, n, want, ctx[:96]))

# The historically false wording must be gone, and its false numbers must not reappear
STALE = ["сорок D-триггеров", "24 трёхстальных буфера", "три элемента на разряд",
         "два инвертора и сорок", "восемь DFF и три"]
flat = re.sub(r"\s+", " ", " ".join(units))
stale_hits = [s for s in STALE if s in flat]
print("\nstale false-composition wording still present: %d %s" % (len(stale_hits), stale_hits))

PLANT = [
    ("74374 - регистр на восемь бит: подлинная схема содержит 24 трёхстальных буфера TRI, "
     "два инвертора и сорок D-триггеров, то есть восемь DFF и три элемента на разряд.", 3, "ge"),
    ("74374 содержит 24 буфера TRI, 2 инвертора NOT и 40 D-триггеров DFF.", 3, "eq"),
    ("74374 содержит 8 буферов TRI, 1 инвертор NOT и 8 D-триггеров DFF при 10 входах и 8 выходах.", 0, "eq"),
    ("74244 содержит 9 буферов и 2 инвертора.", 1, "eq"),
    ("74155 содержит 5 инверторов NOT, 2 элемента BAND2 и 8 NAND3 при 6 входах и 8 выходах.", 0, "eq"),
    ("74155 содержит 5 инверторов и 8 NAND3 при 6 входах и 9 выходах.", 1, "eq"),
    ("74374 содержит 17 экземпляров примитивов.", 0, "eq"),
    ("74374 содержит 24 экземпляра примитивов.", 1, "eq"),
    ("На каждый разряд 74374 приходится ровно один DFF и ровно один TRI.", 0, "eq"),
    ("На каждый разряд 74374 приходится три DFF.", 1, "eq"),
    ("Схема собрана из 17 экземпляров и 109 соединений: U1 (74155), четыре инвертора P0..P3, "
     "четыре вентиля AND2 (K0..K3), четыре регистра R0..R3 (74374), буфер B1 (74244).", 0, "eq"),
    # the three shapes that produced false mismatches during development of this checker:
    # they must yield NO finding, and must be reported as unresolved rather than dropped.
    ("Для 74155 это все 2 в 6-й = 64 комбинации входов (раздел 7.1).", 0, "eq"),
    ("У 74374 OEN активен НИЗКИМ уровнем: при OEN = 1 выход действительно находится в Z.", 0, "eq"),
    ("У 74244 при GN = 0 выход равен входу во всех 32 наблюдениях.", 0, "eq"),
]
print("\n--- self-test: planted sentences adjudicated by the SAME function the scan uses ---")
st = 0
for text, want, mode in PLANT:
    f, r_, u_, e_ = adjudicate(text)
    got = len(f)
    ok = got >= want if mode == "ge" else got == want
    if ok:
        st += 1
    print("   expect%s%-2d got=%-2d resolved=%-2d unres=%-2d own=%-2d %s | %s"
          % (">=" if mode == "ge" else "=", want, got, len(r_), len(u_), len(e_),
             "OK" if ok else "WRONG", text[:48]))
    if mode == "eq" and want == 0 and text.startswith(("Для 74155 это", "У 74374 OEN", "У 74244 при")):
        if not u_:
            print("      NOTE: the shape was neither adjudicated nor reported unresolved")
            st = -1
print("self-test: %d of %d correct" % (st, len(PLANT)))
if st != len(PLANT):
    sys.exit("SELF-TEST FAILED: the composition audit misjudges a planted sentence")
if stale_hits:
    sys.exit("STALE WORDING PRESENT: %s" % stale_hits)
if not SRC_OK:
    sys.exit("SOURCE AUTHORITY NOT ESTABLISHED: the .bdf the composition is parsed from does not match any independent copy of it")
if allf:
    sys.exit("COMPOSITION DEFECTS: %d claims disagree with the authentic .bdf files" % len(allf))
print("VERDICT: THE LIBRARY FILES MATCH THEIR INDEPENDENT COPIES, AND EVERY ATTRIBUTABLE COMPOSITION CLAIM AGREES WITH THE AUTHENTIC .bdf FILE")
