# -*- coding: utf-8 -*-
# Broad homoglyph sweep: every delivered text file, not just the notes. A mixed
# script inside one token is a typing defect regardless of the carrier - a
# comment in a .tdf or a string in a .mjs ships too.
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
SD = os.path.normpath(os.path.join(HERE, ".."))
CYR, LAT = r"Ѐ-ӿ", r"A-Za-z"
MIX = re.compile("[" + CYR + "][" + LAT + "]|[" + LAT + "][" + CYR + "]")
# token may contain digits, hyphen, underscore, dot - but the mixed pair must be
# adjacent letters, so identifiers like "seqcheck.mjs-код" are separated by a
# punctuation boundary and are reported only when the scripts truly abut.
WORD = re.compile("[" + CYR + LAT + "][0-9_" + CYR + LAT + ".]*")
SKIP_EXT = (".png", ".qif", ".sof", ".jsc", ".db", ".qws", ".woff", ".exe")
# Контекст экранирования. r"\bпри" ставит латинскую b рядом с кириллическим
# словом, но эта b - пунктуация движка регулярных выражений, а не опечатка
# набора: тот же класс ложной срабатывки, что и символьный класс выше.
# Граница считается настоящей только когда её латинская буква НЕ предваряется
# обратным слэшем. Функция служит и скану, и самотесту, поэтому самотест не
# может пройти, проверяя помощника, которым скан не пользуется (измеренная
# слабость первой версии _yo2.py, которую руководитель записал сам).
def mixed_cores(line):
    esc = set()
    for em in re.finditer("[" + LAT + "]", line):
        if em.start() > 0 and line[em.start() - 1] == "\\":   # ONE backslash character; the previous form held two, so the escape rule could never fire
            esc.add(em.start())
    out = []
    for wm in WORD.finditer(line):
        w = wm.group(0)
        if re.search(r"\[[^\]]*" + re.escape(w) + r"[^\]]*\]", line):
            continue
        for am in MIX.finditer(line):
            if not (wm.start() <= am.start() < wm.end()):
                continue
            lp = am.start() + (0 if re.fullmatch("[" + LAT + "][" + CYR + "]", am.group(0)) else 1)
            if lp in esc:
                continue
            out.append(w.strip("._-"))
            break
    return out

rows = []
files = 0
for root, dirs, fnames in os.walk(SD):
    dirs[:] = [d for d in dirs if d != "__pycache__"]
    for fn in fnames:
        p = os.path.join(root, fn)
        if fn.lower().endswith(SKIP_EXT):
            continue
        files += 1
        try:
            t = open(p, encoding="utf-8", errors="strict").read()
        except UnicodeDecodeError:
            continue          # binary (Quartus databases, .acf) - no prose there
        except Exception:
            continue
        for i, line in enumerate(t.split("\n"), 1):
            # A character class such as [A-Za-zА-Яа-яЁё] legitimately puts the two
            # scripts side by side; flagging that boundary is a false positive of
            # this sweep, not a defect. Drop tokens that sit inside [...] brackets.
            for core in mixed_cores(line):
                rows.append((os.path.relpath(p, SD), i, core, line.strip()[:100]))
print("patterns: CYR=%r LAT=%r" % (CYR, LAT))
print("   MIX  = %r" % MIX.pattern)
print("   WORD = %r" % WORD.pattern)
# self-test: a planted mixed-script token MUST be caught, otherwise the sweep is
# silently matching nothing (which is exactly what happened on the first try of
# this script, when the Cyrillic range lost its lower bound).
# Plant the defective forms from code points, not from the keyboard: typing
# "altram" by hand is how the first self-test got it wrong (I wrote the correct
# Latin spelling and then expected the checker to flag it).
BAD_ALTRAM = chr(0x0430) + chr(0x043B) + "tram"      # Cyrillic a, l + Latin tram (the real docx defect)
BAD_E = "предел" + chr(0x0065) + " C·B"               # "предел" + LATIN small e (0x65, not Cyrillic 0x435)
PLANT = "в " + BAD_E + " ограничено, САМ" + chr(0x49) + chr(0x4D) + " доставленным, str" + chr(0x0430) + chr(0x0070) + "ов и " + BAD_ALTRAM
caught = mixed_cores(PLANT)   # the same function the scan calls, not WORD+MIX
for want in [BAD_E.split(" ")[0], "САМ" + chr(0x49) + chr(0x4D), "str" + chr(0x0430) + chr(0x0070) + "ов", BAD_ALTRAM]:
    if not any(want in c for c in caught):
        raise SystemExit("SELF-TEST FAILED: sweep does not detect planted %s (caught=%s)" % (ascii(want), ascii(caught)))
print("self-test: all 4 planted tokens detected: %s" % ascii(caught))
# The suppression claim is CHECKED, not printed: a rule that never fires is exactly
# what made 12 regex artifacts (r"\bпри", "\nе-forms") look like typing defects.
print("text files swept: %d | mixed-script tokens: %d" % (files, len(rows)))
if mixed_cores(r'\bпри\s+') != []:
    raise SystemExit("SELF-TEST FAILED: escape suppression does not fire - %s" % ascii(mixed_cores(r'\bпри\s+')))
if mixed_cores(chr(0x0062) + chr(0x043f) + chr(0x0440) + chr(0x0438)) == []:
    raise SystemExit("SELF-TEST FAILED: a genuine mixed token is not detected")
print("self-test: escape context CHECKED: \bпри suppressed, bare chr(0x0062) + chr(0x043f) + chr(0x0440) + chr(0x0438) caught")
groups = {}
for f, i, w, ctx in rows:
    groups.setdefault(w, []).append("%s:%d" % (f, i))
for w, locs in sorted(groups.items(), key=lambda kv: -len(kv[1])):
    kind = "IDENTIFIER+ENDING (legit)" if re.search(r"\d", w) and re.search(LAT + r"\d", w) else "TYPO (fix)"
    print("   %-24s %-28s %d  %s" % (ascii(w), kind, len(locs), ", ".join(locs[:3])))
