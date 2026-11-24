# Лабораторная работа №7. Результаты автономных прогонов

Все пять программ собраны и запущены без ручного вмешательства; повторный прогон даёт
**побайтово те же захваты** (проверено дважды: 2264, 11822, 9066, 10131, 18959 байт).
Ни один захват не правился после прогона: печатается ровно то, что выдала программа.

Инструмент: [autotest.ps1](<D:\Desktop\NF\GitNout\Architecture\LAB7_DOS\autotest.ps1>)
(копия корневого `Architecture\dosbox_autotest.ps1`), DOSBox 0.74-3, `-TimeoutSec 40`.
Пауза на клавишу под автопрогоном отключена макросом `NOWAIT`, который передаёт только
автопрогон; интерактивные задачи Ctrl+Shift+B её сохраняют.

Команды сборки:
- ASM: `tasm /zi /dNOWAIT ..\lab7_n.asm` + `tlink /v /t ...`;
- C: `tcc -B -ms -v -DNOWAIT -d:\build d:\lab7_n.c` (ключ `-v`, а не `-g`: замерено, что `-g`
  не добавляет отладочной информации - EXE 6444 B и OBJ 368 B и с ним, и без).

## Сводка

| задание | источник | захват | непустых строк | секций | вердиктов OK / RAZNICHA | контрольных значений сверено |
|---|---|---|---|---|---|---|
| Lab7_1 | `lab7_1.asm` | 2264 B | 44 | 5 | 0 / 0 | 15 из 15 |
| Lab7_2 | `lab7_2.c` | 11822 B | 168 | 6 | 1 / 0 | 13 из 13 |
| Lab7_3 | `lab7_3.asm` | 9066 B | 170 | 10 | 0 / 0 | 17 из 17 |
| Lab7_4 | `lab7_4.asm` | 10131 B | 141 | 11 | 3 / 0 | 15 из 15 |
| Lab7_5 | `lab7_5.c` | 18959 B | 314 | 7 | 9 / 0 | 25 из 25 |

Контрольные значения - конкретные величины, искавшиеся в захвате машинно (побитовые
образы, слова состояния, байты, вердикты). Найдено 85 из 85. Одно
уточнение, важное для понимания: коды условия «не сравниваемы» дают полное слово
`4501h`, а не маску `4500h` (бит 0 остаётся взведённым от создания NaN), поэтому
декодирование идёт по маске - см. [Otvet.md](<D:\Desktop\NF\GitNout\Architecture\LAB7_DOS\Otvet.md>), раздел 1.3.

## Что остаётся непроверенным

- **Визуальные проверки в Turbo Debugger.** TD интерактивен, автозахват его вывода
  невозможен. Процедуры описаны в Otvet.md, раздел 3; ни одно утверждение вида «я видел
  в TD» в работах не сделано.
- **Реальное железо.** Все замеры сделаны в DOSBox 0.74-3. Два расхождения с книгой
  (недоставка немаскированных исключений и несообщение переполнения стека) - свойства
  эмулятора, а не x87; программы печатают об этом оговорки прямо в выводе.
- **Нереализованные ветки вывода.** В Lab7_5 две строки печатаются только при других
  данных: `<overflow: num >= 2^(k+16)>` (овёрфлоу при 16.02 не бывает) и «в 24 знаках
  после точки ошибки не видно» (ошибка здесь видна). Они отсутствуют в захвате - это
  норма, а не потеря.
---


## Lab7_1 - 1 (A7.txt 26-29): три числа, регистры FPU, сумма, ограниченность мантиссы

Источник: `Lab7_1\lab7_1.asm`. Захват: `Lab7_1\build\run.txt` (2264 байт, 44 непустых строк). Секций: 5.
Команда получения (перехват вывода идёт редиректом **внутри DOS**):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "LAB7_DOS\autotest.ps1" ^
  -Root "D:\Desktop\NF\GitNout\Architecture\LAB7_DOS" -Dir Lab7_1 -TimeoutSec 40
```

Полный захват, дословно:

```
=== Lab7 step 1 (ASM): three numbers in the FPU stack, their sum, mantissa limits ===
--- 1) INPUT: three numbers in a dialog ---
  parsed: sign=0  int=16  frac=2  scale=100  value in FPU = 16.02000046
  parsed: sign=0  int=3  frac=5  scale=10  value in FPU = 3.50000000
  parsed: sign=1  int=0  frac=125  scale=1000  value in FPU = -0.12500000


--- 2) HOW THE FPU REGISTERS ARE USED: a stack of 8 x 80 bits ---
  control word = 037F
  status word  = 2900  TOP (status bits 13..11) = 5
  tag word     = 03FF
  tags R0..R7 (V=valid Z=zero S=special E=empty): E E E E E V V V 
  ST(0) = BFFC 8000 0000 0000 0000
  ST(1) = 4000 E000 0000 0000 0000
  ST(2) = 4003 8028 F600 0000 0000
  note: FLD pushes (TOP decreases), FADDP/FDIVP/FSTP pop; FSAVE stores the
  whole stack and resets it. Header of FSAVE is 14 bytes (386 mode):
  CW, SW, TAG, opcode offset+sel, operand offset+sel.


--- 3) SUMMING (FADD/FADDP) AND THE RESULT ---
  A + B        = 19.52000046
  80-bit view: 4003 9C28 F600 0000 0000
  (A + B) + C  = 19.39500046
  80-bit view: 4003 9B28 F600 0000 0000
  status flags I D Z O U P SF ES = 0 0 0 0 0 0 0 0 


--- 4) MANTISSA WIDTH: precision control = CW bits 9..8 ---
  PC=24 bit : CW = 007F
   PC=0 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
  1.0e8 + 1.0  -> ST(0) = 4019 BEBC 2000 0000 0000
  (sum - 1.0e8) = 0.00000000
  1.0e8 + 0.01 -> ST(0) = 4019 BEBC 2000 0000 0000
  (sum - 1.0e8) = 0.00000000
  PC=64 bit : CW = 037F
   PC=3 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
  1.0e8 + 1.0  -> ST(0) = 4019 BEBC 2020 0000 0000
  (sum - 1.0e8) = 1.00000000
  1.0e8 + 0.01 -> ST(0) = 4019 BEBC 2000 51EB 851F
  (sum - 1.0e8) = 0.01000000


--- 5) THE SAME NUMBER IN THE THREE FORMATS (A7.txt lines 50-66) ---
  KV (single, 32 bit) bytes: F6 28 80 41 
  DV (double, 64 bit) bytes: 85 EB 51 B8 1E 05 30 40 
  VV (temp,   80 bit) bytes: F6 28 5C 8F C2 F5 28 80 03 40 
  KV value  = 16.02000046
  DV value  = 16.02000000
  VV value  = 16.02000000
  note: KV and DV hide the leading mantissa bit (implicit), VV shows it,
  so 16.02 is exact only in the 80-bit register; KV loses the digits.
```

## Lab7_2 - 2 (A7.txt 30): получить значение NaN в FPU

Источник: `Lab7_2\lab7_2.c`. Захват: `Lab7_2\build\run.txt` (11822 байт, 168 непустых строк). Секций: 6.
Команда получения (перехват вывода идёт редиректом **внутри DOS**):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "LAB7_DOS\autotest.ps1" ^
  -Root "D:\Desktop\NF\GitNout\Architecture\LAB7_DOS" -Dir Lab7_2 -TimeoutSec 40
```

Полный захват, дословно:

```
=== Lab7 step 2 (C): obtaining NaN in the FPU and reading its bit image ===
--- 1) WHAT NaN IS, IN BITS (A7.txt lines 226-258) ---
  A NaN is a value with the EXPONENT FIELD ALL ONES and a NON-ZERO
  MANTISSA. Two kinds: the quiet bit (MSB of the mantissa) set -> QNaN,
  cleared -> SNaN. QNaN travels through operations silently; an SNaN used
  as an operand is a signalling case: it raises Invalid Operation (I) and
  gets QUIETED (the quiet bit is set) on the way out. The sign bit of a NaN
  carries no meaning but is preserved, and the rest of the mantissa is a
  payload - the FPU does not define it, the producer may.
  Widths in this compiler (measured): sizeof float=4  double=8  long double=10
  float.h of this toolkit: FLT_MANT_DIG=24, DBL_MANT_DIG=53, LDBL_MANT_DIG=64,
  so KV=32 bit with 8-bit exponent, DV=64 bit with 11-bit, VV=80 bit with 15.
--- 2) SIX WAYS TO GET NaN, EACH SHOWN IN ALL THREE FORMATS ---
  (a) 0.0 / 0.0
      KV (4B)        : 00 00 C0 FF 
      KV decode      :   sign=1 exp=FFh mant=400000h  QNaN
      DV (8B)        : 00 00 00 00 00 00 F8 FF 
      DV decode      :   sign=1 exp=7FFh mant=80000h_00000000  QNaN
      VV (10B, ST(0)) : 00 00 00 00 00 00 00 C0 FF FF 
      VV decode      :      sign=1  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
  (b) sqrt(-1.0)
      KV (4B)        : 00 01 C0 7F 
      KV decode      :   sign=0 exp=FFh mant=400100h  QNaN
      DV (8B)        : 00 00 00 00 20 00 F8 7F 
      DV decode      :   sign=0 exp=7FFh mant=80020h_00000000  QNaN
      VV (10B, ST(0)) : 00 00 00 00 00 00 01 C0 FF 7F 
      VV decode      :      sign=0  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C001000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
      errno after sqrt(-1.0) = 33  (EDOM in math.h = 33)
  (c) Inf - Inf   (Inf = 1.0/0.0)
      KV (4B)        : 00 00 C0 FF 
      KV decode      :   sign=1 exp=FFh mant=400000h  QNaN
      DV (8B)        : 00 00 00 00 00 00 F8 FF 
      DV decode      :   sign=1 exp=7FFh mant=80000h_00000000  QNaN
      VV (10B, ST(0)) : 00 00 00 00 00 00 00 C0 FF FF 
      VV decode      :      sign=1  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
  (d) 0.0 * Inf
      KV (4B)        : 00 00 C0 FF 
      KV decode      :   sign=1 exp=FFh mant=400000h  QNaN
      DV (8B)        : 00 00 00 00 00 00 F8 FF 
      DV decode      :   sign=1 exp=7FFh mant=80000h_00000000  QNaN
      VV (10B, ST(0)) : 00 00 00 00 00 00 00 C0 FF FF 
      VV decode      :      sign=1  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
(e) hand-built SNaN 7F800001h used in FADD (SNaN + 1.0)
      operand SNaN, KV bytes: 01 00 80 7F 
      operand decode      : sign=0 exp=FFh mant=000001h  SNaN
      result KV             : 01 00 C0 7F 
      result decode         : sign=0 exp=FFh mant=400001h  QNaN
      result VV (ST(0))     : 00 00 00 00 00 01 00 C0 FF 7F 
      result decode         :      sign=0  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000010000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
      note: the quiet bit of the RESULT is set - the FPU quieted the
      SNaN instead of signalling. On real hardware with the I-mask
      cleared this is exactly the case that raises the interrupt.
  (f) 0.0L / 0.0L (80-bit arithmetic)
      KV (4B)        : 00 00 C0 FF 
      KV decode      :   sign=1 exp=FFh mant=400000h  QNaN
      DV (8B)        : 00 00 00 00 00 00 F8 FF 
      DV decode      :   sign=1 exp=7FFh mant=80000h_00000000  QNaN
      VV (10B, ST(0)) : 00 00 00 00 00 00 00 C0 FF FF 
      VV decode      :      sign=1  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
--- 3) ALL SPECIAL PATTERNS, BUILT AND DECODED BY HAND ---
  Single (KV), 32 bit = 1 sign + 8 exponent + 23 mantissa bits:
  +QNaN single    word=7FC00000  bytes: 00 00 C0 7F                         sign=0 exp=FFh mant=400000h  QNaN
  -QNaN single    word=FFC00000  bytes: 00 00 C0 FF                         sign=1 exp=FFh mant=400000h  QNaN
  +SNaN single    word=7F800001  bytes: 01 00 80 7F                         sign=0 exp=FFh mant=000001h  SNaN
  +Inf single     word=7F800000  bytes: 00 00 80 7F                         sign=0 exp=FFh mant=000000h  INFINITY
  -Inf single     word=FF800000  bytes: 00 00 80 FF                         sign=1 exp=FFh mant=000000h  INFINITY
  +0 single       word=00000000  bytes: 00 00 00 00                         sign=0 exp=00h mant=000000h  ZERO
  -0 single       word=80000000  bytes: 00 00 00 80                         sign=1 exp=00h mant=000000h  ZERO
  min denormal    word=00000001  bytes: 01 00 00 00                         sign=0 exp=00h mant=000001h  DENORMALIZED
  max denormal    word=007FFFFF  bytes: FF FF 7F 00                         sign=0 exp=00h mant=7FFFFFh  DENORMALIZED
  min normal      word=00800000  bytes: 00 00 80 00                         sign=0 exp=01h mant=000000h  NORMAL = 1.mant * 2^-126
  max finite      word=7F7FFFFF  bytes: FF FF 7F 7F                         sign=0 exp=FEh mant=7FFFFFh  NORMAL = 1.mant * 2^127

  Double (DV), 64 bit = 1 sign + 11 exponent + 52 mantissa bits:
  +QNaN double    word=7FF80000_00000000  bytes: 00 00 00 00 00 00 F8 7F                         sign=0 exp=7FFh mant=80000h_00000000  QNaN
  -QNaN double    word=FFF80000_00000000  bytes: 00 00 00 00 00 00 F8 FF                         sign=1 exp=7FFh mant=80000h_00000000  QNaN
  +SNaN double    word=7FF00000_00000001  bytes: 01 00 00 00 00 00 F0 7F                         sign=0 exp=7FFh mant=00000h_00000001  SNaN
  +Inf double     word=7FF00000_00000000  bytes: 00 00 00 00 00 00 F0 7F                         sign=0 exp=7FFh mant=00000h_00000000  INFINITY
  -Inf double     word=FFF00000_00000000  bytes: 00 00 00 00 00 00 F0 FF                         sign=1 exp=7FFh mant=00000h_00000000  INFINITY
  min denormal    word=00000000_00000001  bytes: 01 00 00 00 00 00 00 00                         sign=0 exp=000h mant=00000h_00000001  DENORMALIZED
  max denormal    word=000FFFFF_FFFFFFFF  bytes: FF FF FF FF FF FF 0F 00                         sign=0 exp=000h mant=FFFFFh_FFFFFFFF  DENORMALIZED
  min normal      word=00100000_00000000  bytes: 00 00 00 00 00 00 10 00                         sign=0 exp=001h mant=00000h_00000000  NORMAL = 1.mant * 2^-1022
  max finite      word=7FEFFFFF_FFFFFFFF  bytes: FF FF FF FF FF FF EF 7F                         sign=0 exp=7FEh mant=FFFFFh_FFFFFFFF  NORMAL = 1.mant * 2^1023

  Extended (VV), 80 bit = 1 sign + 15 exponent + 64 mantissa bits,
  the leading mantissa bit is EXPLICIT here (in KV and DV it is implied):
  +QNaN extended    bytes:00 00 00 00 00 00 00 C0 FF 7F 
      sign=0  exp=7FFFh (32767)  J=1  Q=1
      mantissa, 64 bit (bytes b7..b0): C000000000000000
      ->  QNaN (quiet: propagates silently, carries a payload)
  +Inf extended     bytes:00 00 00 00 00 00 00 80 FF 7F 
      sign=0  exp=7FFFh (32767)  J=1  Q=0
      mantissa, 64 bit (bytes b7..b0): 8000000000000000
      ->  INFINITY (exp all ones, mantissa = J only)
  Compare: both have exp=7FFFh and J=1; they differ ONLY in Q.
--- 4) HOW THIS COMPILER COMPARES NaN (MEASURED, not assumed) ---
  n = 0.0/0.0 (a NaN). Results produced by Turbo C 2.01 on DOSBox:
      n != n  -> 0      n == n  -> 1
      n <  1.0-> 1      n >  1.0-> 0
      !(n<1.0)-> 0      inf > 1e300 -> 1
      printf %f of n renders as: -NAN   <- that is the CRT text, NOT the FPU answer
  WHY: the emitted assembly of a float comparison (measured, build
  of a probe) is exactly this:
      FLD   qword ptr <right>
      FLD   qword ptr <left>
      FCOMPP                 ; compare ST(0) with ST(1), pop both
      FSTSW word ptr FLAGS8087@   ; status word to memory
      FWAIT
      mov   ah, byte ptr FLAGS8087@+1  ; HIGH byte of the status word
      sahf                        ; AH -> CF,PF,AF,ZF,SF
      jbe   <label>               ; the test actually used
  AH is bits 15..8 of the status word and SAHF copies AH into SF,ZF,_,AF,
  _,_,PF,_,CF - so the x87 codes land as C0 (bit 8) -> CF, C2 (bit 10) ->
  PF, C3 (bit 14) -> ZF, while bits 11..13 (the TOP pointer!) end up in AF
  and bit 15 (busy) in SF. The mapping is measured, not guessed: the status
  word 2900h printed by Lab7_1 has TOP=5 in bits 13..11, so C3 cannot be
  bit 3 and C2 cannot be bit 2. The branches TCC emits use CF and ZF, that
  is C0 and C3; C1 goes nowhere (bit 9 is not an SAHF flag bit).
  For an UNORDERED pair the FPU sets C0=C1=C2=C3=1, hence CF=1 and ZF=1,
  so the below-or-equal branch is taken: this C code reports NaN as EQUAL
  to itself and as LESS than 1.0 - both measurements above. That is a
  property of the compiler's flag mapping, NOT of the FPU: the real flags
  live in the status word, and only Lab7_3 (assembly, FSTSW) reads them.
--- 5) WHERE TO LOOK AT THE NaN IN TURBO DEBUGGER (manual, for defence) ---
  TD is interactive, so this part cannot be captured by the autotest; the
  autotest proves the NUMBERS, TD proves the FPU STATE. Procedure:
    1. Build with debugging info. MEASURED on this toolkit: tcc -g adds NO
       debug information (the EXE is byte-for-byte the same size as without
       the switch), while tcc -v does (the source file name appears inside the
       EXE: 6444 bytes vs 9295 bytes). The Compile and Debug task therefore
       uses: tcc -B -ms -v -nd:\build d:\lab7_2.c  then  td lab7_2.
    2. In TD: Alt+F9 to run to the breakpoint, F2 on the line after the
       statement that produced the NaN.
    3. View -> Floating Point (or CPU window, FPU pane). You see ST(0)..ST(7)
       as 10-byte values - exactly the KV/DV/VV bytes this program printed,
       plus the tag word: the NaN slot is marked SPECIAL (binary 10), which
       is how the FPU distinguishes NaN/Inf from ordinary numbers.
    4. View -> Registers -> FPU (Control and Status words). After 0.0/0.0 the
       status word has IE (bit 0) set and C0..C3 = 1000b for INVALID; after
       Inf-Inf and 0*Inf also IE; a QNaN produced silently leaves only IE.
    5. Watch the stack: FLD pushes (TOP decreases), FSTP/FADDP/FDIVP pop.
       With 8 slots filled, the 9th FLD raises Stack Fault (SF, bit 6) -
       try it in the TD command line (Ctrl+F4) with fld st(0) repeated.
--- 6) ANSWERS ---
  1. NaN appears whenever an operation has no meaningful numeric result:
     0/0, Inf-Inf, 0*Inf, sqrt of a negative number, an SNaN operand, and
     stack over/underflow. Its bits: exponent all ones, mantissa non-zero.
  2. QNaN (quiet bit set) propagates silently and carries a payload; SNaN
     signals Invalid Operation and is quieted on the way out - measured here
     on the hand-built 7F800001h pattern.
  3. The sign of a NaN is preserved but meaningless. The bit images above
     agree with the patterns published in A7.txt (lines 226-258); they were
     NOT compared with real 8087 hardware - only this emulator was measured.
  4. In this toolkit the FPU flags are reachable from C only through the
     compiler flag mapping, which loses C2 - so unordered comparisons lie.
     Reading the status word directly (Lab7_3) is the only honest way.
  5. DOSBox 0.74-3 does NOT deliver unmasked x87 exceptions (measured in
     Lab7_4): the flags accumulate in the status word, no interrupt arrives.
```

## Lab7_3 - 3 (A7.txt 31-32): прочитать и разобрать слово состояния и слово управления

Источник: `Lab7_3\lab7_3.asm`. Захват: `Lab7_3\build\run.txt` (9066 байт, 170 непустых строк). Секций: 10.
Команда получения (перехват вывода идёт редиректом **внутри DOS**):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "LAB7_DOS\autotest.ps1" ^
  -Root "D:\Desktop\NF\GitNout\Architecture\LAB7_DOS" -Dir Lab7_3 -TimeoutSec 40
```

Полный захват, дословно:

```
=== Lab7 step 3: reading and analysing the FPU control and status words ===
--- 1) CONTROL WORD: fields as given by A7.txt lines 128-152 ---
  CW = 037F
  bits 15..0 (most significant bit first): 0000 0011 0111 1111
  exception masks, bits 5..0 (0 = unmasked, 1 = masked):

1:0 invalid operation (IE) 
1:1 denormal operand (DE)  
1:2 zero divide (ZE)       
1:3 overflow (OE)          
1:4 underflow (UE)         
1:5 precision (PE)         
   PC=3 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F

--- 2) PRECISION CONTROL (bits 9..8): the same 1.0/3.0 at every PC ---
  CW set to 007F
   PC=0 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
    1.0 / 3.0 -> 3FFD AAAA AB00 0000 0000    = 0.33333334
   -1.0 / 3.0 -> BFFD AAAA AB00 0000 0000    = -0.33333334
  CW set to 017F
   PC=1 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAB    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAB    = -0.33333333
  CW set to 027F
   PC=2 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA A800    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA A800    = -0.33333333
  CW set to 037F
   PC=3 (00=24, 10=53, 11=64)  RC=0 (00=nearest, 01=down, 10=up, 11=truncate)  IC=0  exception masks = 003F
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAB    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAB    = -0.33333333
--- 3) ROUNDING CONTROL (bits 11..10), A7.txt lines 142-146 ---
  CW = 037F
    mode 00 nearest, ties to even                                       
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAB    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAB    = -0.33333333
  CW = 077F
    mode 01 down (toward minus infinity)                                
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAA    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAA    = -0.33333334
  CW = 0B7F
    mode 10 up (toward plus infinity)                                   
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAB    = 0.33333334
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAB    = -0.33333333
  CW = 0F7F
    mode 11 truncate (toward zero)                                      
    1.0 / 3.0 -> 3FFD AAAA AAAA AAAA AAAA    = 0.33333333
   -1.0 / 3.0 -> BFFD AAAA AAAA AAAA AAAA    = -0.33333333
--- 4) STATUS WORD: fields as given by A7.txt lines 160-184 ---
  SW = 0000
  bits 15..0 (most significant bit first): 0000 0000 0000 0000
  every bit of the status word:

0:0  invalid operation IE      
0:1  denormal operand DE       
0:2  zero divide      ZE       
0:3  overflow         OE       
0:4  underflow         UE      
0:5  precision         PE      
0:6  stack fault       SF      
0:7  error summary     ES      
0:8  condition code    C0      
0:9  condition code    C1      
0:10 condition code    C2      
0:11 top pointer 13..11        
0:12 top pointer 13..11        
0:13 top pointer 13..11        
0:14 condition code    C3      
0:15 FPU busy        BUSY      
  class by PRIORITY (A7.txt lines 84-95): no unmasked special case detected
   ES (bit 7) = 0: no unmasked case (all masks are set)
  proof that TOP lives in bits 13..11 (MEASURED in Lab7_1): SW = 2900
    bits 13..11 of it give TOP = 5
  note: Phex16 changes AX, so the value is reloaded before the shift
--- 5) FSTSW AX vs FSTSW memory (A7.txt lines 157-159) ---
  FSTSW AX    -> 3B20
  FSTSW memory-> 3B20
  identical: YES

  bits 15..0 (most significant bit first): 0011 1011 0010 0000
  every bit of the status word:

0:0  invalid operation IE      
0:1  denormal operand DE       
0:2  zero divide      ZE       
0:3  overflow         OE       
0:4  underflow         UE      
1:5  precision         PE      
0:6  stack fault       SF      
0:7  error summary     ES      
1:8  condition code    C0      
1:9  condition code    C1      
0:10 condition code    C2      
1:11 top pointer 13..11        
1:12 top pointer 13..11        
1:13 top pointer 13..11        
0:14 condition code    C3      
0:15 FPU busy        BUSY      
  class by PRIORITY (A7.txt lines 84-95): 6) inexact result (bit 5)
   ES (bit 7) = 0: no unmasked case (all masks are set)
--- 6) EVERY EXCEPTION FLAG, ONE EXPERIMENT AT A TIME (masks all set) ---
  0.0 / 0.0                :  SW = 3901
  0:IE=1   1:DE=0   2:ZE=0   3:OE=0   4:UE=0   5:PE=0   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 1) invalid operation (bit 0)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  FADD with a denormal operand:  SW = 3922
  0:IE=0   1:DE=1   2:ZE=0   3:OE=0   4:UE=0   5:PE=1   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 3) denormalized operand (bit 1)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  1.0 / 0.0                :  SW = 3904
  0:IE=0   1:DE=0   2:ZE=1   3:OE=0   4:UE=0   5:PE=0   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 2) zero divide (bit 2)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  2^16383 * 2^16383        :  SW = 3B28
  0:IE=0   1:DE=0   2:ZE=0   3:OE=1   4:UE=0   5:PE=1   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 4) overflow (bit 3)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  2^-16445 * 2^-16445      :  SW = 3932
  0:IE=0   1:DE=1   2:ZE=0   3:OE=0   4:UE=1   5:PE=1   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 3) denormalized operand (bit 1)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  1.0 / 3.0                :  SW = 3B20
  0:IE=0   1:DE=0   2:ZE=0   3:OE=0   4:UE=0   5:PE=1   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): 6) inexact result (bit 5)
   ES (bit 7) = 0: no unmasked case (all masks are set)
  the 10th FLD into 8 registers:  SW = 3800
  0:IE=0   1:DE=0   2:ZE=0   3:OE=0   4:UE=0   5:PE=0   6:SF=0   7:ES=0 
  class by PRIORITY (A7.txt lines 84-95): no unmasked special case detected
   ES (bit 7) = 0: no unmasked case (all masks are set)
  MEASURED: the 9th and 10th FLD did NOT set SF (bit 6) here.
  DOSBox 0.74-3 does not report stack overflow at all, so a real
  8087 must be consulted for the SF behaviour (A7.txt line 167).
--- 6b) CONDITION CODES C0..C3 (A7.txt lines 181-184) ---
  only FCOM/FTST/FXAM change C0..C3; arithmetic leaves them unchanged
  C0 C1 C2 C3 = 0 0 0 1   SW = 4000h    -> meaning: ST(0) equal to ST(1)
  C0 C1 C2 C3 = 0 0 0 0   SW = 0000h    -> meaning: ST(0) greater than ST(1)
  C0 C1 C2 C3 = 1 0 0 0   SW = 0100h    -> meaning: ST(0) less than ST(1)
  C0 C1 C2 C3 = 1 0 1 1   SW = 4501h    -> meaning: UNORDERED (at least one operand is a NaN)
  Intel 8087 differs: greater = C3=1,C0=1 (4100h), less = 0000h.
  The table above is the MEASURED DOSBox behaviour, not the book.
--- 7) FCLEX: clearing the flags ---
  SW before FCLEX = 3901
   SW after  FCLEX = 3900
  Without FCLEX the flag stays set: the next WAIT-form instruction would
  report the SAME special case again, over and over.
--- 8) TAG WORD AND STACK ROTATION (A7.txt lines 186-205) ---
  FSAVE header, bytes 0..1  (control word)      = 037F
  FSAVE header, bytes 2..3  (status word)      = 2900
  FSAVE header, bytes 4..5  (tag word)         = 03FF
  TOP taken from the saved status word:
  TOP (status bits 13..11) = 5

  tag word decoded:
  tags R0..R7 (V=valid Z=zero S=special E=empty): E E E E E V V V 

  ST(0) (the last pushed, 3.0) : 4000 C000 0000 0000 0000
  ST(1)               (2.0)   : 4000 8000 0000 0000 0000
  ST(2)               (1.0)   : 3FFF 8000 0000 0000 0000
  rotation without moving data: FINCSTP / FDECSTP change TOP only
  three values pushed, TOP =  TOP (status bits 13..11) = 5

  after FINCSTP (TOP + 1 mod 8):  TOP (status bits 13..11) = 6

  after two FDECSTP (TOP - 2 mod 8):  TOP (status bits 13..11) = 4

  The data did not move: only the circular pointer changed, so the same
  physical register is now seen as another logical ST(i).
--- 9) HOW TO TRACE THE SAME THINGS IN TURBO DEBUGGER (interactive) ---
  TD cannot be captured by the autotest (it is a full-screen debugger), so
  this is the manual procedure for the defence:
    1. Run the "Compile and Debug in TD" task (Ctrl+Shift+B, second task).
    2. View -> Floating Point: ST(0)..ST(7) as 10-byte values, the tag word
       and the Control/Status words live there. F2 sets a breakpoint, F7 steps
       one instruction - watch TOP decrease on FLD and increase on FSTP.
--- 10) ANSWERS ---
  1. The control word selects MODES (PC, RC, IC, six masks); the status word
     reports FACTS (six flags, SF, ES, TOP, four condition codes, BUSY).
  2. TOP occupies bits 13..11, the condition codes are split: C0,C1,C2 in bits
     8,9,10 and C3 in bit 14 - that is why FSTSW AX + SAHF maps only C0 and C3
     onto CF and ZF, and C2 (the unordered indicator) is lost in C code.
```

## Lab7_4 - 4 (A7.txt 33-36): возбудить особый случай и отреагировать на него

Источник: `Lab7_4\lab7_4.asm`. Захват: `Lab7_4\build\run.txt` (10131 байт, 141 непустых строк). Секций: 11.
Команда получения (перехват вывода идёт редиректом **внутри DOS**):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "LAB7_DOS\autotest.ps1" ^
  -Root "D:\Desktop\NF\GitNout\Architecture\LAB7_DOS" -Dir Lab7_4 -TimeoutSec 40
```

Полный захват, дословно:

```
=== Lab 7 step 4 (ASM): FPU special case - the handler reacts on the status word ===
  task A7.txt 33-36: unmask one class, provoke it, decode SW, enter the handler.
--- 1) VECTORS AS FOUND BEFORE ANY CHANGE (int 21h/AH=35h gives ES:BX) ---
  vector 75h (math coprocessor, IRQ13, the path used when NE=0) = 0000:0000
  vector 16h (x87 exception,              path used when NE=1) = F000:11E0
  both values are saved here and restored in section 10: a .COM program that
  leaves its own address in the vector table breaks the next run of the box.
--- 2) CR0 BY MACHINE CODE (.286 cannot encode MOV EAX,CR0; .386 breaks tlink /t) ---
  CR0 hi:lo = 0000:0000   bit 16 of that value, called NE = 0
  the number above is printed as two 16-bit halves ONLY. It is not used to
  conclude anything about NE: this emulator returns an undefined CR0 for such
  a probe (measured twice: 0000:0000h), so the NE bit is not readable here.
  Per the documentation of a real PC the NE bit is normally 1 (the BIOS sets it).
--- 3) INSTALL OUR OWN HANDLER (int 21h/AH=25h, DS:DX = handler address) ---
  set vector 75h -> DS:DX = 0193:0950
  set vector 16h -> DS:DX = 0193:097F
  read vector 75h back (AH=35h) = 0193:0950
  read vector 16h back (AH=35h) = 0193:097F
  both vectors now point to our handler; each of them has its own counter.
--- 4) UNMASK EXACTLY ONE CLASS: Z = division by zero (clear CW bit 2) ---
  control word BEFORE  CW = 037F
  status word right after FINIT  SW = 0000
  exception mask bits of CW (A7.txt lines 134-140):
  P=1   masked   -> the FPU handles it by itself, the program continues
  U=1   masked   -> the FPU handles it by itself, the program continues
  O=1   masked   -> the FPU handles it by itself, the program continues
  Z=1   masked   -> the FPU handles it by itself, the program continues
  D=1   masked   -> the FPU handles it by itself, the program continues
  I=1   masked   -> the FPU handles it by itself, the program continues
  control word AFTER   CW = 037B   (only the Z mask bit became 0)
  exception mask bits of CW (A7.txt lines 134-140):
  P=1   masked   -> the FPU handles it by itself, the program continues
  U=1   masked   -> the FPU handles it by itself, the program continues
  O=1   masked   -> the FPU handles it by itself, the program continues
  Z=0   UNMASKED -> this class has to be reported to a software handler
  D=1   masked   -> the FPU handles it by itself, the program continues
  I=1   masked   -> the FPU handles it by itself, the program continues

--- 5) PROVOKE THAT CLASS: 1.0 / 0.0, operands built FROM INTEGER constants ---
  FILD word ptr OneI  -> ST(0) = 1.0
  FILD word ptr ZeroI -> ST(0) = 0.0, therefore ST(1) = 1.0
  FDIVP               -> ST(1) := ST(1)/ST(0) = 1.0/0.0, then the stack pops
  FWAIT               -> synchronisation, so that SW is read afterwards
  FSTSW SW1           -> the status word of the finished operation
  no float literals in the data: TASM 4.1 encodes DD/DQ/DT with a decimal
  value using nibbles swapped inside every byte (measured), so only the
  integer constants above are safe (A7.txt 194-199 and 218-224 on WAIT).
--- 6) STATUS WORD DECODED BIT BY BIT (FSTSW, A7.txt lines 154-185) ---
  status word SW = 3904
  exception flags of bits 0..5 and the two summary bits 6 and 7:
  I =0 D =0 Z =1 O =0 U =0 P =0 SF=0 ES=0
    TOP (bits 13..11) = 7  C0(8) = 1 C1(9) = 0 C2(10) = 0 C3(14) = 0  BUSY(15) = 0
  priority chain (A7.txt 84-99; a stack fault is a part of invalid, lines 70, 86):
    I(bit0) > SF(bit6) > Z(bit2) > O(bit3) > U(bit4) > P(bit5) > D(bit1) > none
  first class by priority = 2 Z  - division by zero (A7.txt lines 72, 88)
  default FPU response    = +infinity or -infinity (A7.txt line 88)
  ES (bit 7, error summary) = 0
  measured, not assumed: the UNMASKED Z flag is set (bit 2 = 1) while the
  summary bit ES (bit 7) stays 0. A test that looks only at ES would report
  that nothing happened. The per-class flag in SW is the reliable evidence.
--- 7) ENTER THE HANDLER: a SOFTWARE int 75h, the very vector used when NE=0 ---
  handler entries BEFORE our int 75h:  75h = 0   16h = 0
  both counters read 0 at this moment: the case is FLAGGED in SW but it is
  NOT VECTORED by DOSBox 0.74-3 (measured). On real 8087/387 hardware the
  counters would already be 1 here - the CPU would stop the program and route
  control to the handler by itself. The int 75h below is OUR OWN call.

--- 8) WHAT THE HANDLER RECORDED (main prints it; a handler must not print) ---
  handler entries AFTER  our int 75h:  75h = 1   16h = 0
  entries made by our software int 75h: 75h = 1    16h = 0
  the hardware path added nothing: before our call both counters were 0.
  SW found inside the handler (its own FSTSW) = 3904
  the handler decoded that status word and got:
  I =0 D =0 Z =1 O =0 U =0 P =0 SF=0 ES=0
  class decoded by the handler = 2 Z  - division by zero (A7.txt lines 72, 88)
  default FPU response         = +infinity or -infinity (A7.txt line 88)
  message index stored in a global = 2   (the class code; main uses it to pick the printed text)
  CW after the handler (it did FLDCW of the saved mask) = 037F   (all six classes masked again)
  SW after the handler (it did FCLEX)                   = 3900   (all exception flags cleared)
  FCLEX clears the six exception flags; C0..C3 are condition codes, not flags.
  FCLEX is mandatory: while a flag stays set the NEXT FPU instruction would be
  counted as a special case again. The FLDCW done first stops a re-entry:
  FSTSW is a WAIT-form command (A7.txt 194-199) and with an unmasked flag it
  would be a second delivery point for the very same condition.
  EOI (mov al,20h / out 20h,al) matters only for a real IRQ13 arrival.
  Real hardware, A7.txt 105-110: NE=1 -> the CPU enters vector 16h itself;
  NE=0 -> INT 75h / IRQ13. In this box only our own call reached vector 75h.
  ST(0) exponent:sign = 7FFF  mantissa hi..lo     = 8000000000000000   encoding = INFINITY (exponent all ones, mantissa exactly 1.0; A7.txt lines 235 and 247)
  Compare with A7.txt line 88: the answer of the FPU to division by zero is Inf.

--- 9) SECOND CLASS: unmask I (CW bit 0), take 0.0 / 0.0, decode, call again ---
  control word BEFORE  CW = 037F
  control word AFTER   CW = 037E   (only the I mask bit became 0)
  exception mask bits of CW (A7.txt lines 134-140):
  P=1   masked   -> the FPU handles it by itself, the program continues
  U=1   masked   -> the FPU handles it by itself, the program continues
  O=1   masked   -> the FPU handles it by itself, the program continues
  Z=1   masked   -> the FPU handles it by itself, the program continues
  D=1   masked   -> the FPU handles it by itself, the program continues
  I=0   UNMASKED -> this class has to be reported to a software handler
  FLDZ / FLDZ -> ST(0) = 0.0 and ST(1) = 0.0; FDIVP -> ST(1) := 0.0/0.0, pop;
  FWAIT; both operands are zero, so the class here is I - invalid operation.
  status word SW = 3901
  exception flags of bits 0..5 and the two summary bits 6 and 7:
  I =1 D =0 Z =0 O =0 U =0 P =0 SF=0 ES=0
    TOP (bits 13..11) = 7  C0(8) = 1 C1(9) = 0 C2(10) = 0 C3(14) = 0  BUSY(15) = 0
  first class by priority = 0 I  - invalid operation (A7.txt lines 70, 86-87)
  default FPU response    = QNaN for a stack fault, invalid for an SNaN operand (A7.txt 86-87)
  ES (bit 7, error summary) = 0
  handler entries BEFORE the second int 75h: 75h = 1   (the one entry there is our own call of section 7)
  handler entries AFTER  our int 75h:  75h = 2   16h = 0
  SW found inside the handler (its own FSTSW) = 3901   class decoded by the handler = 0 I  - invalid operation (A7.txt lines 70, 86-87)
  ST(0) exponent:sign = FFFF  mantissa hi..lo     = C000000000000000   encoding = QNaN (exponent all ones, mantissa MSB set; A7.txt lines 231-232)
  Compare with A7.txt lines 86-87: the answer to an invalid operation is a NaN.

  priority is the TABLE order (A7.txt 84-99), NOT the order of bits (168-174):
    class            SW bit    priority rank    provoked in this run
    I  invalid         0            1            yes - second experience
    SF stack fault     6            2            no (a part of invalid)
    Z  zero divide     2            3            yes - first experience
    O  overflow        3            4            no
    U  underflow       4            5            no
    P  precision       5            6            no
    D  denormal        1            7            no
  the two orders differ: D is bit 1 but ranks LAST, P is bit 5 yet outranks D,
  SF is bit 6 but ranks second. Scanning bits upward would pick D before P,
  which is wrong. Each of the two experiences above set exactly ONE exception
  flag - it is visible in the printed bit decode - so the chain order changes
  nothing here; it is what makes the verdict right when flags come in a set.
--- 10) RESTORE BOTH VECTORS (int 21h/AH=25h) AND READ THEM BACK ---
  restored vector 75h = 0000:0000 OK: it matches the value saved in section 1
  restored vector 16h = F000:11E0 OK: it matches the value saved in section 1
  AH=25h takes the new vector from DS:DX, so DS is briefly the segment of the
  saved vector (0000h for 75h in this box); DOS only copies DS:DX into the
  table. CW is loaded back to 037Fh and FCLEX clears the flags afterwards.
--- 11) WHY IT WORKS THIS WAY ---
  1. On a real 8087/387 an UNMASKED special case stops the program: the FPU
     raises its flag, the CPU vectors to INT 16h when NE=1 or to INT 75h /
     IRQ13 when NE=0, and the handler finds the CAUSE from the status word.
  2. In DOSBox 0.74-3 the flags accumulate but the interrupt is NOT generated
     (measured: entry counters 0, ES = 0, old vector 75h = 0000:0000h)
     so the reaction here is a flag analysis of SW plus a SOFTWARE int 75h
     into the same handler code, and the program prints that arrival as OURS.
  3. EOI is needed only on a real hardware arrival; FCLEX is needed always.
  lab7_4 is over: both vectors restored, CW back to 037Fh, flags cleared.
```

## Lab7_5 - 5 (A7.txt 37-38): механизм перевода 16.02 в плавающий формат

Источник: `Lab7_5\lab7_5.c`. Захват: `Lab7_5\build\run.txt` (18959 байт, 314 непустых строк). Секций: 7.
Команда получения (перехват вывода идёт редиректом **внутри DOS**):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "LAB7_DOS\autotest.ps1" ^
  -Root "D:\Desktop\NF\GitNout\Architecture\LAB7_DOS" -Dir Lab7_5 -TimeoutSec 40
```

Полный захват, дословно:

```
=== Lab7 shag 5 (C): mehanizm prevrashhenija 16.02 v plavajushhij format ===
    KV = 32 bita (float), DV = 64 bita (double),
    VV = 80 bitov (long double / ST(0) u FPU)
    Sekcii 1-5: vsja arifmetika celochislennaja (96 bit iz 16-bitnyh slov).
    Plavajushhie literaly - tol'ko kak kontrol' v sekcii 6.

--- 1) ISHODNOE CHISLO 16.02: CELOJA I DROBNAYA CHASTI ---
  16.02 = 1602/100 = 801/50, to est' celaja 16 + drobnaja 1/50.
  Drobnaja chast' vedetsja kak para chislitel/50: ostatok vsegda beretsja
  po modulju 50, pojetomu nikakogo okruglenija zdes' voobshhe net.

  1a) celaja chast' 16 -> dvoinoe, delenie na 2 s ostatkom:
         16 / 2 =   8  ostatok 0   ->  bit 0  (ves 2^0)
          8 / 2 =   4  ostatok 0   ->  bit 0  (ves 2^1)
          4 / 2 =   2  ostatok 0   ->  bit 0  (ves 2^2)
          2 / 2 =   1  ostatok 0   ->  bit 0  (ves 2^3)
          1 / 2 =   0  ostatok 1   ->  bit 1  (ves 2^4)
        bity ot mladshago k starsnemu: 0 0 0 0 1 
        16 = 10000b    (starsnij bit = 1; v KV/DV on stanet PODRAZUMEVAEMYM)

  1b) drobnaja chast' 1/50 -> dvoinoe, umnozhenie na 2 (36 shagov):
   no.   mnozhimoe  x2   proizvedenie   bit   ostatok
   ---- ---------- ---  -------------- ----- ----------
    1     1/50     x2       2/50         0      2/50
    2     2/50     x2       4/50         0      4/50
    3     4/50     x2       8/50         0      8/50
    4     8/50     x2      16/50         0     16/50
    5    16/50     x2      32/50         0     32/50
    6    32/50     x2      64/50         1     14/50
    7    14/50     x2      28/50         0     28/50
    8    28/50     x2      56/50         1      6/50
    9     6/50     x2      12/50         0     12/50
   10    12/50     x2      24/50         0     24/50
   11    24/50     x2      48/50         0     48/50
   12    48/50     x2      96/50         1     46/50
   13    46/50     x2      92/50         1     42/50
   14    42/50     x2      84/50         1     34/50
   15    34/50     x2      68/50         1     18/50
   16    18/50     x2      36/50         0     36/50
   17    36/50     x2      72/50         1     22/50
   18    22/50     x2      44/50         0     44/50
   19    44/50     x2      88/50         1     38/50
   20    38/50     x2      76/50         1     26/50
   21    26/50     x2      52/50         1      2/50
   22     2/50     x2       4/50         0      4/50
   23     4/50     x2       8/50         0      8/50
   24     8/50     x2      16/50         0     16/50
   25    16/50     x2      32/50         0     32/50
   26    32/50     x2      64/50         1     14/50
   27    14/50     x2      28/50         0     28/50
   28    28/50     x2      56/50         1      6/50
   29     6/50     x2      12/50         0     12/50
   30    12/50     x2      24/50         0     24/50
   31    24/50     x2      48/50         0     48/50
   32    48/50     x2      96/50         1     46/50
   33    46/50     x2      92/50         1     42/50
   34    42/50     x2      84/50         1     34/50
   35    34/50     x2      68/50         1     18/50
   36    18/50     x2      36/50         0     36/50

        dvoinye cifry drobi (pervye 32): 0000 0101 0001 1110 1011 1000 0101 0001 

        Ostatki povtarjajutsja, znachit povtarjajutsja i cifry:
        golovka (bity do perioda) = 1 bit(ov), period = 20 bitov
        period: (00001010001111010111)
        0.02 = 0.0(00001010001111010111)(00001010001111010111)...  - beskonechno
        Proverka po tablice vyshe: ostatok 2/50 voznik posle shaga 1 i
        voznik snova posle shaga 21. Znachit bity 2..21 povtoryajutsja
        v bity 22..41, i tak beskonechno (period 20).

  1c) VYVOD: 0.02 v dvoinoj sisteme - BESKONECHNAYA periodicheskaja drob':
      znamenatel' 50 = 2 x 5^2 soderzhit mnozhitel' 5, kotoryj v dvoinoj
      sisteme ne skorat'sja. Znachit 16.02 TOCHNO NE PREDSTAVIMO ni v KV,
      ni v DV, ni v VV: luboj sokhranennyj bitovoj obraz - eto OKRUGLENIE.
      Dalshe pokazano, kakie bita vyzhivajut i kakaja oshibka ostajetsja.

--- 2) NORMALIZACIJA: sdvig dvoinoj tochki do mantissy v [1,2) ---
        ishodnoe:  10000.00000101000111101011...
        tochka svinuta na 4 mesta vlevo:
                     1.000000000101000111101011...  x 2^4
        (starsnaja 1 v pole KV/DV bol'she NE pishetsja - ona PODRAZUMEVAEMAYA;
         v 80-bitnov VV ona, naoborot, IZOBRAZHAETSJA: A7.txt, stroki 65-66)

        znak               S = 0   (chislo polozhitel'noe)
        istinnyj pjorjadok     e = 4
        harakteristika      E = e + bias:
          KV (bias 2^7-1  = 127)  : E =   4 + 127   = 131 = 10000011b = 83h
          DV (bias 2^10-1 = 1023) : E =   4 + 1023  = 1027 = 10000000011b = 403h
          VV (bias 2^14-1 = 16383): E =   4 + 16383 = 16387 = 100000000000011b = 4003h

        Smeshchenie nuzhno, chtoby pjorjadki sravnivalis kak bezznakovie
        celye i chtoby ne vodyt' otdel'nyj bit znaka pjorjadka. Znachenija
        E=0 i E=max rezervirujutsja pod nuli/denormali i pod Inf/NaN, pojetomu
        rabochij diapazon e uzhe ne vsja shirina polja.

--- 3) MANTISSA: bity, otdbrosyvaemaja chast', guard/round/sticky ---
        Normalizovannaja mantissa = 1.[bity nizhe]; starsnaja 1 v pole
        KV/DV ne hodit, pojetomu pole - eto imenno drob'naja chast'.

        Drob'naja chast' mantissy, bity 1..36 (numeracija s 1):
        bit   : 0000 0000 0101 0001 1110 1011 1000 0101 0001 
        tens  : 0000 0000 0111 1111 1112 2222 2222 2333 3333 
        ones  : 1234 5678 9012 3456 7890 1234 5678 9012 3456 
        pole KV:
<=== ==== ==== ==== ==== ==>G Rsss ssss ssss 
        (<..=> 23 bita pola KV; G bit 24 guard; R bit 25 round;
         s bity 26.. - sticky: vse, cto ostalos' za round)
        Pole DV (52 bita) v etom okne ne pomestitsja - sm. 3b.
        Pole VV (64 bita) nachinaetsja s YVNOGO starsnogo bita - sm. 3c.

  3a) KV: pole 23 bita
        otschyomnye 23 bita : 0x0028F5   (000.0000.0010.1000.1111.0101)
        otdbrosyvaetsja     : 11000010100...  [bit 24 guard, bit 25 round, bity 26+ sticky]
        G=1  R=1  S=1
        pravilo RC=00: G=0 -> syom;  G=1 i (R|S)=1 -> +1;
                       G=1, R=0, S=0 (roavno 1/2 ulp) -> +1 tol'ko pri
                       netchetnom pole
        priroshchenie = 1,  vykhod za starsnij bit pola = 0
        itogovoe pole 23 bita: 0x0028F6   (000.0000.0010.1000.1111.0110)

  3b) DV: pole 52 bita
        otschyomnye 52 bita : 0x0051EB851EB85
        (bity 1..52): 0000000001010001111010111000010100011110101110000101
        otdbrosyvaetsja     : 00011110101110...  [bit 53 guard, bit 54 round, bity 55+ sticky]
        G=0  R=0  S=1  ->  priroshchenie = 0,  vykhod za pole = 0
        Zdes' otdbrosyvaetsja MENSHE poloviny ulp (G=0), pojetomu DV lezhit
        SNUZU ot 16.02.
        itogovoe pole 52 bita: 0x0051EB851EB85
        (bity 1..52): 0000000001010001111010111000010100011110101110000101

  3c) VV: pole 64 bita (starsnij bit - YVNYJ, eto zhe sb[0])
        otschyomnye 64 bita : 0x8028F5C28F5C28F5
        otdbrosyvaetsja     : 1100001010001...  [bit 65 guard, bit 66 round, bity 67+ sticky]
        G=1  R=1  S=1  ->  priroshchenie = 1,  vykhod za pole = 0
        itogovoe pole 64 bita: 0x8028F5C28F5C28F6

        Podskazka dlya zashhity: u 1/50 beskonechnyj dvoinoj period, i v njom
        est' edinitcy, pojetomu S vsegda = 1 vsled za G=1. Sluchaj 'roavno
        1/2 ulp' (R=0, S=0) byvaet tol'ko u chisel s konechnym dvoinym
        razlozheniem - 16.02 k nim ne otnositsja. Vykhoda za pole (mantissy
        2.0) zdes' net ni v odnom formate: ovfl = 0/0/0.

--- 4) SBORKA SLOVA: pola po bitam, HEX, bayty v pjorjadke pamjati ---

  4a) KV (32 bita): S(1) | E(8) | M(23)
        bit  31      : 0   (znak)
        bity 30..23  : 1000.0011  = 83h = 131
        bity 22..0   : 000.0000.0010.1000.1111.0110  = 0x0028F6
          S EEEEEEEE MMMMMMMMMMMMMMMMMMMMMMM
          0 10000011 00000000010100011110110
        slovo tselikom : 0x418028F6
        bayty (LE)     : F6 28 80 41 
           byte[0] = bity 7..0    (mladshie 8 bitov mantissy)
           byte[1] = bity 15..8
           byte[2] = bity 23..16  (starsnij bit mantissy + 7 bitov E)
           byte[3] = bity 31..24  (ZNAK + 7 starsnih bitov E)

  4b) DV (64 bita): S(1) | E(11) | M(52)
        bit  63      : 0   (znak)
        bity 62..52  : 100.0000.0011  = 403h = 1027
        bity 51..0   : 0x0051EB851EB85
          S EEEEEEEEEEE MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
          0 10000000011 0000000001010001111010111000010100011110101110000101
        slovo tselikom : 0x4030051EB851EB85
        bayty (LE)     : 85 EB 51 B8 1E 05 30 40 
           byte[7] = ZNAK + 7 starsnih bitov E (E=403h -> bayt 40h)
           byte[0] = mladshie 8 bitov 52-bitnogo pola mantissy

  4c) VV (80 bitov): S(1) | E(15) | M(64, starsnij bit IZOBRAZHEN)
        bit  79      : 0   (znak)
        bity 78..64  : 100.0000.0000.0011  = 4003h = 16387
        bity 63..0   : 0x8028F5C28F5C28F6
        slovo tselikom : 0x40038028F5C28F5C28F6
        bayty (LE)     : F6 28 5C 8F C2 F5 28 80 03 40 
           bayty 0..7 - mantissa (byte[7] soderzhit YVNYJ starsnij bit = 1)
           bayty 8..9 - pjorjadok (znak v bit 7 bayta 9)

        Raznica: v KV/DV starsnaja 1 v pole NE hodit (ekonomija odnogo bita),
        v VV ona IZOBRAZHEMA - otuda 64 znashhih bita pri 80-bitnovom sleve.

--- 5) OBRATNAYA REKONSTRUKCIYA: iz bitov snova v desjatichnoe, i oshibka ---
        Formula: V = (-1)^S x (1 + sum M_i x 2^-i) x 2^e   dlya KV/DV,
                 V = (-1)^S x (M s yvnym bitom) x 2^(E - 16383 - 63) dlya VV.
        V celikh chislakh: V = SIG / 2^k, gde k = (ves starsnogo bita) - e.

  5a) pervye 12 slagaemyh drobnoj chasti mantissy (tochnye desjatichnye):
        M_ 1 = 0   x   2^- 1 = 0.5             nol'
        M_ 2 = 0   x   2^- 2 = 0.25            nol'
        M_ 3 = 0   x   2^- 3 = 0.125           nol'
        M_ 4 = 0   x   2^- 4 = 0.0625          nol'
        M_ 5 = 0   x   2^- 5 = 0.03125         nol'
        M_ 6 = 0   x   2^- 6 = 0.015625        nol'
        M_ 7 = 0   x   2^- 7 = 0.0078125       nol'
        M_ 8 = 0   x   2^- 8 = 0.00390625      nol'
        M_ 9 = 0   x   2^- 9 = 0.001953125     nol'
        M_10 = 1   x   2^-10 = 0.0009765625    uchastvuet
        M_11 = 0   x   2^-11 = 0.00048828125   nol'
        M_12 = 1   x   2^-12 = 0.000244140625  uchastvuet
        (podrazumevaemaja 1 davaet 1.000000..., dalshe idut bity pola;
         pervaja edinitca v pole - eto bit 10, ves 2^-10)

  5b) rekonstrukcija i oshibka po kazhdomu formatu:
        tochnoe 16.02 = 801/50 = 16.020000000000000000000000
   KV: SIG = 8399094  / 2^23
        mantissa v [1,2) = 1.001250028610229492187500
        x 2^4 (pjorjadok e) = SIG/2^19 ->  V = 16.020000457763671875000000
        oshibka absolyutnaja V - 16.02 = +0.000000457763671875000000
        oshibka otnositel'naja         = 0.000000028574511352996254
        pervaja nenulevaja cifra - na 7-m znake posle tochki,
        to est' vernyh cifr posle tochki: 6
        sovpadenie ZAPISI s tochnym 16.02: pervye 9 simvola
        (sravnivajte zapisi, a ne verit' im: 16.01999... rascxoditsja
         rano, hotja oshibka v njom mala)

   DV: SIG = 4509229126904709  / 2^52
        mantissa v [1,2) = 1.001249999999999973354647
        x 2^4 (pjorjadok e) = SIG/2^48 ->  V = 16.019999999999999573674358
        oshibka absolyutnaja V - 16.02 = -0.000000000000000426325641
        oshibka otnositel'naja         = 0.000000000000000026612087
        pervaja nenulevaja cifra - na 16-m znake posle tochki,
        to est' vernyh cifr posle tochki: 15
        sovpadenie ZAPISI s tochnym 16.02: pervye 4 simvola
        (sravnivajte zapisi, a ne verit' im: 16.01999... rascxoditsja
         rano, hotja oshibka v njom mala)

   VV: SIG = 9234901251900844278  / 2^63
        mantissa v [1,2) = 1.001250000000000000026020
        x 2^4 (pjorjadok e) = SIG/2^59 ->  V = 16.020000000000000000416333
        oshibka absolyutnaja V - 16.02 = +0.000000000000000000416333
        oshibka otnositel'naja         = 0.000000000000000000025988
        pervaja nenulevaja cifra - na 19-m znake posle tochki,
        to est' vernyh cifr posle tochki: 18
        sovpadenie ZAPISI s tochnym 16.02: pervye 21 simvola
        (sravnivajte zapisi, a ne verit' im: 16.01999... rascxoditsja
         rano, hotja oshibka v njom mala)

        Vyvod: pervaja oshibka posle tochki - na 7-m znake u KV, na 16-m u DV,
        na 19-m u VV; to est' vernyh cifr posle tochki 6, 15 i 18.
        Garantirovannaja tochnost' iz A7.txt (stroka 63): 6, 15 i 19 vernyh
        desjatichnyh cifr. U KV i DV eta cifra - rovno chislo vernyh cifr posle
        tochki; u VV k nim dobavljajutsja dve cifry celoj chasti (16), to est'
        na 2 bolshe, chem ukazano vyshe, i garant 19 perekryvaetsja.
        Chislo okrugljaetsja uzhe na shage 3 (sekciya 3) i bolshe ne menyatsja:
        rekonstrukcija dajet to zhe samoe, chto lezit v pamjati.
        Umnozenie na 2^4 vcheno v k = (ves starsnogo bita) - e, pojetomu
        otdel'nogo 'plavajushhego' shaga net: vse tochno v celikh.

--- 6) SRAVNENIE S REAL'NOST'YU: bayty kompilyatora protiv rascheta ---

        razmery v etom kompilyatore: sizeof float=4  double=8
        sizeof long double=10

  6a) KV
        raschet (sekciya 4a) : F6 28 80 41 
        iz pamjati (float)   : F6 28 80 41 
        kontrol'nyi progon   : F6 28 80 41 
        razbor baytov iz pamyati: znak=0  E=83h (131)  M=0028F6h
        -> e = 131 - 127 = 4,  V = (1 + M/2^23) x 2^4
        verdit raschet-vs-pamyat'  : OK
        verdit raschet-vs-kontrol' : OK
        tot zhe float cherez printf: %.8f -> 16.02000046
        (sravnit' s oshibkoj iz 5b: v 8 znakax ona uzhe vidna)

  6b) DV
        raschet (sekciya 4b) : 85 EB 51 B8 1E 05 30 40 
        iz pamjati (double)  : 85 EB 51 B8 1E 05 30 40 
        kontrol'nyi progon   : 85 EB 51 B8 1E 05 30 40 
        razbor baytov iz pamyati: znak=0  E=403h (1027)
        M = 0051E:B851EB85h -> e = 1027 - 1023 = 4, V = (1 + M/2^52) x 2^4
        verdit raschet-vs-pamyat'  : OK
        verdit raschet-vs-kontrol' : OK
        tot zhe double cherez printf: %.8lf -> 16.02000000
        (oshibka DV v 8 znakax ne projavljaetsja - no eto NE znachit, chto
         predstavlenie tochnoe: sm. 5b)

  6c) VV (80 bit, to chto lezit v registre FPU)
        raschet (sekciya 4c) : F6 28 5C 8F C2 F5 28 80 03 40 
        iz pamjati, (long double)16.02 : F6 28 5C 8F C2 F5 28 80 03 40 
        kontrol'nyi progon             : F6 28 5C 8F C2 F5 28 80 03 40 
        verdit raschet-vs-pamyat'      : OK
        verdit raschet-vs-kontrol'     : OK

  6d) rashirenie double -> 80 bit (to zhe chislo, no zagruzhennoe v FPU iz DV)
        iz pamjati (cwiden = cd) : 00 28 5C 8F C2 F5 28 80 03 40 
        raschet (53 bita -> 64, mladshie 11 bitov = 0):
           mantissa 64 bita: 0x8028F5C28F5C2800   pjorjadok: 4003h
        verdit tol'ko po mantisse (bayty 0..7): OK
        Smysl: DV-chislo, zagruzhennoe v FPU, NE stanovit tochnee - k ego
        mantisse prosto dobavlyajutsja nuli, i tochnost' 16.02 ogranichena
        uzhe 53 bitami DV. Nastojashhij 80-bitnyi obraz (6c) ima druguju
        mantissu: on okrugljaetsja po pravilu 64 bitov, a ne 52, i potomu
        on tochnee oboikh.

  6e) pochemu v 80-bitnov formate 16.02 lejit TOCHNEE vsego:
        1) pole mantissy 64 bita protiv 23 (KV) i 52 (DV);
        2) starsnij bit v nem IZOBRAZHEN, a ne podrazumevaetsja, to est' vse
           64 bita real'no znashhie (A7.txt, stroki 62-66: 'Neyavnyj bit:
           opushchen / izobrazhaetsja'), i okruglenie idet po 64, a ne po 52
           dvoinym cifram;
        3) pjorjadok 15 bit daet diapazon 10^-4931 .. 10^4932 - sdvig zdes'
           daleko ot granicy, pojetomu ogranichenie tol'ko na mantissu.
        Otdel'no: 80-bitnyi format - eto arifmeticheskij format REGISTRA, a ne
        format xranenija; TCC xranit long double tem zhe obrazom (10 bayt),
        chto i proveryeno vyshe v 6c.

  6f) slovo upravlenija FPU posle FINIT (inline asm, bez 386-registrov):
        CW = 037Fh   SW = 0000h
        bity 11..10 (RC, okruglenie) = 00
        -> 00 = do blizhajshego, pri ravnyh k chetnomu.
           Eto rovno to pravilo, chto primenjeno v sekicii 3.
        bity  9..8  (PC, tochnost')  = 11
        -> 11 = 64 bita (rasshirennaja tochnost').
           FPU schitaet s 64-bitnovoj mantissoj, a pola KV/DV okrugljajutsja
           pri xranenii - otuda i raznica mezhdu 16.02f, 16.02 (double) i
           80-bitnov ST(0).
        maski iskluchenij (bity 5..0) = 3Fh -> vse zamaskirovany: FPU
           obrabatyvaet osobyye sluchai sam; osobennyh situacij eta programma
           ne provociruet.

--- 7) KRATKYY OTVET (dlya zashhity) ---
  1. 16.02 = 801/50, a 50 = 2 x 5^2. Dvojnaya drob' konechna tol'ko pri
     znamenatele vida 2^n; mnozhitel' 5 skorat' nechem. Znachit 0.02 -
     beskonechnaja periodicheskaja drob' (period 20 bitov), i 16.02 TOCHNO
     ne predstavimo ni v 32, ni v 64, ni v 80 bitov: luboj bitovoj obraz -
     eto priblizhenie.
  2. Mehanizm: 16.02 -> 10000.0000010100011110...b ->
     1.00000000001010001111...b x 2^4 -> znak 0, harakteristika
     4+127=131=83h (KV) / 4+1023=1027=403h (DV), mantissa 23/52 bita s
     okrugleniem do blizhajshego (pri ravnyh - k chetnomu).
  3. Garantirovannye tochnye desjatichnye cifry: KV 6, DV 15, VV 19
     (A7.txt, stroka 63). Po etomu chislu: oshibka KV na 7-m znake posle
     tochki, DV na 16-m, VV na 19-m (25 = ne vidno v 24 znakax) - eto i est'
     nakoplennaja oshibka razryadnoj setki mantissy.
  4. Oshibka terjaetsja na DVOH shagah: (a) pri otbrosa 23/52 bitov mantissy
     (sekciya 3) i (b) pri peresypanii iz 80-bitnova registra v 32/64-bitnovoe
     slovo pamjati. Pervyj shag neizbezhon (chislo ne predstavimo), vtoroj
     zavisit ot razryadnosti xraneniya.
  5. Raschytnye bayty sovpali s pamyat'ju kompilyatora i s kontrol'noj
     zapis'ju progonov (verdit'y OK v sekicii 6a-6c): IEEE 754 v TCC
     real'no rabotaet tak,
     kak opisano v A7.txt, stroki 50-66 i 226-257.

        Tablica parametr formata (A7.txt, stroki 57-66):
        format  bitov  pole E  smeshchenie  pole M  tochn. cifr  neyavnyj bit
        KV (C)     32       8          127      23            6  opushchen
        DV (L)     64      11         1023      52           15  opushchen
        VV (T)     80      15        16383      64           19  izobrazhaetsja
        (C - korotkoe, L - dlinnoe, T - temporal'noe veshchestvennoe,
         A7.txt, stroki 52-55)

=== KONETS Lab7_5 (pod -DNOWAIT vyhod bez ozhidaniya klawishi) ===
```
