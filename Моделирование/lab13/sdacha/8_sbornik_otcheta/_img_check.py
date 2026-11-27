# -*- coding: utf-8 -*-
# Figure fidelity: every inline image in the report must correspond to a real PNG on
# disk, byte for byte, at the declared pixel geometry. A report that cites a waveform
# it does not actually embed would otherwise pass every text checker.
import hashlib, os, re
# Paths are resolved RELATIVE to this file so that the delivered copy runs inside the
# delivery and the authoring copy runs in the authoring tree, with no absolute path in
# either. The delivery keeps the report in 0_zadanie_i_otchet, the specs in 1_ram4 and
# 3_mem4x8, report_data.json in 6_proverki, and the PNGs beside their projects; the
# authoring tree keeps them in the workspace root, lab13/specs and lab13/png.
HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.dirname(HERE)
def find(*rels):
    for base in (UP, HERE, os.path.dirname(UP)):
        p = os.path.normpath(os.path.join(base, *rels))
        if os.path.exists(p):
            return p
    return None
def walk_png(root):
    out = {}
    for dirpath, _dirs, names in os.walk(root):
        if os.path.basename(dirpath) == "__pycache__":
            continue
        for n in names:
            if n.lower().endswith(".png"):
                out.setdefault(n, os.path.join(dirpath, n))
    return out

from docx import Document
from docx.parts.image import ImagePart
DOC = find("lab13_report.docx") or find("0_zadanie_i_otchet", "lab13_report.docx")
if DOC is None:
    raise SystemExit("REPORT NOT FOUND relative to " + __file__)
PNG_DIRS = [p for p in [find("png"), UP] if p]
d = Document(DOC)
parts = [p for p in d.part.package.iter_parts() if isinstance(p, ImagePart)]
print("embedded image parts: %d" % len(parts))
disk = {}
PNGS = {}
for _d in PNG_DIRS:
    walk_png(_d).items()
PNGS = {}
for _d in PNG_DIRS:
    for _n, _p in walk_png(_d).items():
        PNGS.setdefault(_n, _p)
for f in sorted(PNGS):
    if f.lower().endswith(".png"):
        b = open(PNGS[f], "rb").read()
        disk[hashlib.sha256(b).hexdigest()] = (f, len(b))
matched, unmatched = 0, []
for p in parts:
    blob = p.blob
    h = hashlib.sha256(blob).hexdigest()
    if h in disk:
        matched += 1
        f, n = disk[h]
        print("   OK   %-22s %7d B  %d x %d px" % (f, n, p.width_px if hasattr(p, "width_px") else -1, -1))
    else:
        unmatched.append((p.partname, len(blob)))
print("\nembedded images matching a PNG on disk: %d of %d" % (matched, len(parts)))
for pn, n in unmatched:
    print("   UNMATCHED part %s (%d B)" % (pn, n))
import sys
sys.exit(1 if unmatched or matched != len(parts) else 0)
