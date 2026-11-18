# Lab6_DOS — результаты автопрогона в DOSBox (перехват вывода)

Получено командой `powershell -NoProfile -ExecutionPolicy Bypass -File autotest.ps1`
(или в VS Code: открыть папку задачи → Ctrl+Shift+B → «Selftest: capture output»).
Источник каждого блока — `Lab6_N\build\run.txt`, то есть вывод самой программы,
снятый редиректом ВНУТРИ DOS: `lab6 > d:\build\run.txt`.

Как это работает и почему раньше не получалось — раздел 8 плана (`Plan_Lab6.md`)
и комментарии вверху `autotest.ps1`. Ключевые условия: внутренняя команда DOSBox
`-c "exit"`, явное `WaitForExit()` у GUI-процесса и символ `NOWAIT` вместо
ожидания клавиши. Все числа ниже — фактические, не расчётные.

---

## Шаг 1 (C + inline asm): программное прерывание INT 0F0h как вызов ПП

Диагностика сборки: ошибок нет

```dos
=== Lab6 step 1: software interrupt INT 0xF0 as a subroutine call ===

IVT[0xF0] before install : 0000:0000
IVT[0xF0] after  install : 01A3:02C3

--- results of the subroutine (PP) ---
entries into the handler   : 2
(a) shared memory : A=1234 B=0007 -> SUM=123B PROD=7F6C
(b) registers     : AX=00A5 BX=001C -> SUM=00C1
    handler really read : AX=00A5 BX=001C

FLAGS before INT  = 7246
FLAGS after return= 7246   (IF/TF restored by IRET)

IVT[0xF0] restored         : 0000:0000

Press any key...
```

## Шаг 2 (TASM): заполнение стека при программном прерывании

Диагностика сборки: ошибок нет

```dos

=== Lab6 step 2 (ASM): stack fill of a software interrupt ===
IVT: 256 vectors x 4 bytes = 0000:0000..0000:03FF (first 1 KB)
  vector 0F0h, old = 0000:0000
  vector 0F0h, new = 0193:04A4
  new vector installed by direct IVT write under CLI/STI

--- 1) INT 0F0h as a subroutine call: params in AX,BX,CX,SI ---

--- 2) STACK FILL at the handler entry ---
  SP before INT = FFFE  ->  FFF8  = 6  = 3 words of stack

  frame contents:
    [SP+0] IP    = 01AA   <- pushed by THE PROCESSOR  = return address (ok)
    [SP+2] CS    = 0193   <- pushed by THE PROCESSOR  = return address (ok)
    [SP+4] FLAGS = 7293   <- pushed by THE PROCESSOR   (old flags, saved before the interrupt)

  SP after IRET  = FFFE  = SP before INT: stack balanced

--- 3) data processed INSIDE the handler (PP) ---
  SUM(array + AX + BX) = 42B3
  array elements       = 4
  handler really read: AX=1234, BX=0078
  entries into PP      = 1

--- 4) TF and IF are cleared by the CPU at the interrupt ---
  FLAGS before INT : 7293  CF=1 PF=0 AF=1 ZF=0 SF=1 TF=0 IF=1   (bits 0,2,4,6,7,8,9)
  FLAGS inside PP  : 7093  CF=1 PF=0 AF=1 ZF=0 SF=1 TF=0 IF=0   (bits 0,2,4,6,7,8,9)
  FLAGS after IRET : 7293  CF=1 PF=0 AF=1 ZF=0 SF=1 TF=0 IF=1   (bits 0,2,4,6,7,8,9)
  expected: TF=0 and IF=0 INSIDE the PP, restored after IRET

--- 5) CALL vs INT: words added to the stack ---
    CALL NEAR -> words = 1   (IP only), saved return IP = 038C
    INT  0F0h -> words = 3   (IP, CS, FLAGS) = 01AA:0193:7293
    CALL FAR  -> words = 2   (IP, CS; FLAGS NOT saved) = 039E:0193
  Conclusion: an interrupt is an INDIRECT far transfer through a
  IVT vector, and it saves FLAGS as well - therefore the handler returns
  with IRET (3 words), not RET (1..2 words).

  vector 0F0h restored = 0000:0000

--- 6) allowed / forbidden vectors ---
    00h..07h  CPU exceptions        - forbidden for an app
    08h..0Fh  hardware IRQ (8259)   - reserved
    10h..1Ah  BIOS                  - reserved
    20h..3Fh  DOS                   - reserved
    40h..6Fh  DOS/BIOS tables       - reserved
    70h..77h  IRQ (second 8259)     - reserved
    78h..B7h  local / user          - ALLOWED
    B8h..FFh  user-definable        - ALLOWED (we used 0F0h)

>>> Press any key to finish...
```

## Шаг 3 (C + inline asm): ПП через особый случай int 00h (деление на нуль)

Диагностика сборки: ошибок нет

```dos
=== Lab6 step 3: subroutine called via an EXCEPTION (divide by zero) ===

IVT[00h] before install : 01A3:01A0
IVT[00h] after  install : 01A3:02C3

Dividend = 24680 (0x6068),  Divisor = 0  -> DIV by zero

IVT[00h] restored       : 01A3:01A0

--- results of the subroutine (PP) ---
entries into the handler : 1
handler saw             : AX=6068 DX=0000 BX=0000
handler fixed           : BX := 0001 (record written into [bp+14])

RESULT  24680 / 0 (fixed to 1) = 24680  remainder 0

NB: the DIV instruction was executed TWICE - the exception
    mechanism re-executes the faulting instruction unless IP
    ([bp+18]) is advanced by the handler.

Press any key...
```

## Шаг 4 (C + inline asm): анализ кадра + пропуск команды add [bp+18], 2

Диагностика сборки: ошибок нет

```dos
=== Lab6 step 4: stack fill of an EXCEPTION + skipping the faulting DIV ===

Dividend = 24680 (0x6068), Divisor = 0 -> DIV BX raises int 00h

--- 1) STACK FILL (snapshot taken inside the handler) ---
SS = 038E   BP(frame) = FFDE   SP inside PP = FFDE
SP before INT = FFF6  ->  stack grew by 24 bytes = 12 words

SLOT           VALUE    WHO PUSHED IT
[bp+0 ] BP     0000h     prologue
[bp+2 ] DI     0A66h     prologue
[bp+4 ] SI     0A5Ah     prologue
[bp+6 ] DS     038Eh     prologue
[bp+8 ] ES     01A3h     prologue
[bp+10] DX     0000h     prologue
[bp+12] CX     0000h     prologue
[bp+14] BX     0000h     prologue
[bp+16] AX     6068h     prologue
[bp+18] IP     0430h     PROCESSOR
[bp+20] CS     01A3h     PROCESSOR
[bp+22] FLAGS  7286h     PROCESSOR

   9 words (BP..AX) are pushed by the COMPILER prologue,
   3 words (IP, CS, FLAGS) are pushed by THE PROCESSOR.
   Hence IP lives at bp+18 = 24 bytes above BP.  That is why
   the assignment says:  add [bp+18], 2

--- 2) RETURN ADDRESS AND FLAGS ---
IP in frame before 'add' : 0430  (points AT the DIV instruction)
IP in frame after  'add' : 0432  (points AFTER it, DIV +2 bytes)
CS in frame              : 01A3
FLAGS=7286  CF=0 PF=1 AF=0 ZF=0 SF=1 TF=0 IF=1

   NB: TF and IF were cleared BY THE CPU at the moment of the
       exception; the copy in the frame shows their OLD values.

--- 3) RESULT SUPPLIED BY THE HANDLER THROUGH THE FRAME ---
24680 / 7 = 3525  remainder 5
entries into PP = 1  (DIV was NOT re-executed: IP was moved)

--- 4) COMPARISON WITH STEP 3 ---
   step 3: IP untouched -> processor RE-EXECUTED DIV, PP fixed BX;
   step 4: add [bp+18],2 -> DIV SKIPPED, PP wrote AX and DX.
   Both push the same 3 words (FLAGS, CS, IP): exception and
   software INT fill the stack identically; only the SOURCE of
   the event differs (internal fault vs the INT instruction).

Press any key...
```

## Шаг 3+4 (TASM): особый случай и add [bp+18], 2 без участия компилятора

Диагностика сборки: ошибок нет

```dos

=== Lab6 steps 3+4 (ASM): exception int 00h + skipping the faulting DIV ===
IVT[00h] is the Divide Error vector (one of the first ten):
  old vector 00h = F000:1060
  00h DIVIDE ERROR, 01h TRAP, 02h NMI, 03h BREAKPOINT, 04h INTO,
  05h BOUND, 06h INVALID OPCODE, 07h DEVICE NOT AVAILABLE,
  08h DOUBLE FAULT, 09h COPROCESSOR SEGMENT OVERRUN

  new vector 00h = 0193:03E6

--- 1) raise the exception: DIV with a zero divisor ---
  Dividend = 6068,  Divisor = 0000
  vector 00h restored = F000:1060

--- 2) STACK FILL of the exception (snapshot inside the PP) ---
  SP before the exception = FFFE  ->  FFF8  = 6 bytes  = 3 words
  frame address  SS:BP = 0193:FFE6
  [bp+0 ] BP    = 091C   <- compiler prologue (push ax..bp)
  [bp+2 ] DI    = FFFE   <- compiler prologue (push ax..bp)
  [bp+4 ] SI    = 0100   <- compiler prologue (push ax..bp)
  [bp+6 ] DS    = 0193   <- compiler prologue (push ax..bp)
  [bp+8 ] ES    = 0000   <- compiler prologue (push ax..bp)
  [bp+10] DX    = 0000   <- compiler prologue (push ax..bp)
  [bp+12] CX    = 00FF   <- compiler prologue (push ax..bp)
  [bp+14] BX    = 0000   <- compiler prologue (push ax..bp)
  [bp+16] AX    = 6068   <- compiler prologue (push ax..bp)
  [bp+18] IP    = 01C1   <- PROCESSOR (INT / exception)
  [bp+20] CS    = 0193   <- PROCESSOR (INT / exception)
  [bp+22] FLAGS = 7246   <- PROCESSOR (INT / exception)
  9 prologue words = 18 bytes, so the processor-pushed IP sits at bp+18.
  That is exactly why the assignment writes:  add [bp+18], 2


--- 3) return address before / after "add word ptr [bp+18], 2" ---
  IP in frame before add = 01C1   <- points AT the DIV opcode (F7 F3)
  IP in frame after  add = 01C3   <- points AFTER the DIV: the faulting command is SKIPPED
  IP advanced by 2 bytes  (= length of DIV BX: F7 F3)
  CS in frame            = 0193
  FLAGS in frame (old)   = 7246  CF=0 PF=1 AF=0 ZF=1 SF=0 TF=0 IF=1   (bits 0,2,4,6,7,8,9)
  TF and IF were cleared by the CPU entering the PP; the frame keeps
  their PREVIOUS values, and IRET restores them.


--- 4) result supplied by the PP THROUGH the frame ---
  quotient  = 3525,  remainder = 5
  frame slots written by PP: [bp+16] AX = 0DC5:0005
  entries into PP = 1   (DIV was NOT re-executed: IP was moved)

--- 5) comparison with the C version of step 3 ---
  step 3 (C) : IP untouched -> CPU RE-EXECUTED DIV, PP fixed BX=1;
  step 4 here : add [bp+18],2 -> DIV SKIPPED, PP wrote AX and DX.
  Exception and software INT fill the stack IDENTICALLY (FLAGS,CS,IP);
  only the SOURCE differs: internal CPU fault vs the INT instruction.


>>> Press any key to finish...
```

---

### Сверка с ожидаемыми значениями

| Шаг | Ожидалось по ЗАДАНИЕ.txt | Получено в DOSBox | Совпадение |
|---|---|---|---|
| 1 | сумма 1234h+0007h=123Bh, произведение 7F6Ch, регистры AX=00A5 BX=001C → 00C1h, вектор восстановлен 0000:0000 | SUM=123B PROD=7F6C; AX=00A5 BX=001C → SUM=00C1; IVT restored 0000:0000; FLAGS 7246 → 7246 | да |
| 2 | INT = 3 слова (IP, CS, FLAGS); CALL NEAR = 1; CALL FAR = 2; IF=0 внутри ПП | 6 байт = 3 слова; NEAR 1; FAR 2; FLAGS 7293 → 7093 (IF=0) → 7293; сумма 42B3h = 1234h+0078h+3007h | да |
| 3 | DIV исполняется повторно: 24680 / 1 = 24680, остаток 0, входов 1 | RESULT 24680 / 0 (fixed to 1) = 24680 remainder 0; entries 1 | да |
| 4 | кадр 12 слов (24 байта); IP 0430h → 0432h; 24680 / 7 = 3525 остаток 5; входов 1 | 24 bytes = 12 words; IP 0430 → 0432; 3525 remainder 5; entries 1 | да |
| 5 | то же без компилятора: кадр 12 слов, IP 01C1h → 01C3h, слоты 0DC5h:0005h | 6 bytes = 3 слова до пролога; IP 01C1 → 01C3; AX=0DC5 DX=0005 (3525:5); entries 1 | да |

Все пять шагов: **ошибок сборки нет**, вывод соответствует заданию A6.txt.
Неиспользуемые параметры кадра (`Warning: Parameter ... is never used`) ожидаемы: обработчик
читает только часть кадровых слов, остальные присутствуют ради формы кадра.
