# -*- coding: utf-8 -*-
# A Latin-word leak scan of the Russian prose. Words that are legitimate technical identifiers
# (Quartus, lpm_ram_dq, 74155, VHDL, WE, Z, X, tpd, ns, LE, RAM, SRAM, DRAM, MOS, CACHE, ...) are
# whitelisted; anything else standing inside Russian sentences is reported.
import os, re
from docx import Document
d = Document("../0_zadanie_i_otchet/lab13_report.docx")
WHITE = set("""
quartus ii altera maxplus windows ep1s10f484c5 stratix cyclone acex1k flex10ke apex20k max3000a
vhdl ahdl bdf vwf scf wfm pdb tdf megafunction library entity architecture signal std_logic
component port generic map lpm_ram_dq lpm_width lpm_width_ad lpm_numwords lpm_file lpm_indata
lpm_outdata lpm_address_control unregistered unused altram altsyncram content sram ram rom prom
eprom eeprom dram cache mfzu azu dv nmos cmos and or nand band tri dffe dff gnd vcc not buf
we address data oe oecl clr prn clrn ena sel selb sel a gn cn en ad q clk clocki clocko
tpd tsu th tco ns ps us usd node net pin pins LE f max min avg sum total build version
ep1s10f484 c5 ff f0 a5 5a x z o x y i j k n m a b c d e f g h
input output inout bidirectional buffer primitive megafunction parameter value default none
file name path type mode single dual port width depth address control registered
on off yes no error errors warning warnings critical info verbose
success successful unsuccessful was is are not do does did have has been being
the a an and or of in to for with as by is are was were be been being
""".split())
# collect every latin word in non-monospace, non-heading prose paragraphs
paras = d.paragraphs
mono = {i for i, q in enumerate(paras) for r in q.runs if r.font.name and "Courier" in r.font.name}
heads = {i for i, q in enumerate(paras) if q.style.name.startswith("Heading")}
cyr = re.compile(r"[\u0400-\u04FF]")
lat = re.compile(r"[A-Za-z][A-Za-z0-9_.~\/+-]*")
flagged = {}
for i, q in enumerate(paras):
    t = q.text
    if not t.strip() or i in mono or i in heads: continue
    if not cyr.search(t): continue          # only Russian sentences
    for w in lat.findall(t):
        if w.lower() in WHITE: continue
        if re.fullmatch(r"[A-Z]{1,4}", w): continue      # short ALL-CAPS identifiers
        if re.fullmatch(r"[A-Za-z0-9_]*[0-9][A-Za-z0-9_]*", w) and len(w) <= 8: continue
        flagged.setdefault(w, []).append(i)
for j, t in enumerate([c.text for tb in d.tables for row in tb.rows for c in row.cells]):
    if not cyr.search(t): continue
    for w in lat.findall(t):
        if w.lower() in WHITE: continue
        if re.fullmatch(r"[A-Z]{1,4}", w): continue
        if re.fullmatch(r"[A-Za-z0-9_]*[0-9][A-Za-z0-9_]*", w) and len(w) <= 8: continue
        flagged.setdefault(w, []).append("tbl%d" % j)
print("flagged latin tokens: %d" % len(flagged))
for w, locs in sorted(flagged.items(), key=lambda kv: -len(kv[1])):
    print("   %-22s x%-3d %s" % (w, len(locs), sorted(set(map(str, locs)))[:6]))