# -*- coding: utf-8 -*-
import re
flat = "Разводка при 6 входах и 8 выходах."
GROUP = re.compile(r"(?P<num>\d[\d\s]*(?:,\d{3})*)\s+(?P<phrase>[а-яё]{3,}(?:\s+[а-яё]{3,})?)(?![\w])", re.I)
SEP = re.compile(r"^(?:\s*(?:и|или|,)\s+)", re.I)
for pm in re.finditer(r"\bпри\s+", flat, re.I):
    pos = pm.end()
    steps = 0
    while steps < 5:
        steps += 1
        g = GROUP.match(flat, pos)
        if not g:
            print("  step %d: no GROUP match at pos %d (%r)" % (steps, pos, flat[pos:pos+14])); break
        print("  step %d: num=%r phrase=%r span=%d..%d rest=%r" % (steps, g.group("num"), g.group("phrase"), g.end(), 0, flat[g.end():g.end()+12]))
        s2 = SEP.match(flat, g.end())
        if not s2:
            print("     SEP did not match at %d: %r" % (g.end(), flat[g.end():g.end()+8])); break
        print("     SEP matched %r -> pos %d" % (s2.group(0), s2.end()))
        pos = s2.end()
