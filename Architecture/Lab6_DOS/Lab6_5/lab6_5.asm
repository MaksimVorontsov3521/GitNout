;==============================================================
;  Лабораторная работа 6, ШАГИ 3 и 4 на чистом ассемблере
;  (A6.txt, строки 48-53)
;
;  3. Выполнить ПП путём создания ОСОБОГО СЛУЧАЯ (деление на нуль),
;     соответствующего одному из ПЕРВЫХ ДЕСЯТИ векторов (вектор 00h).
;  4. Проанализировать заполнение стека и при выходе из обработчика
;     ПРОПУСТИТЬ команду, вызывающую особый случай:
;                                     add [bp+18], 2
;
;  Здесь показано, ОТКУДА берётся 18: это не магия, а следствие
;  пролога компилятора Borland/Turbo C. Мы воспроизводим его ВРУЧНУЮ:
;      push ax,bx,cx,dx,es,ds,si,di,bp : mov bp,sp
;  Тогда кадр обрабатчика выглядит ровно как в шагах 3-4 на Си:
;      [bp+0 ]=BP  [bp+2 ]=DI  [bp+4 ]=SI  [bp+6 ]=DS  [bp+8 ]=ES
;      [bp+10]=DX  [bp+12]=CX  [bp+14]=BX  [bp+16]=AX
;      [bp+18]=IP  [bp+20]=CS  [bp+22]=FLAGS   <- эти 3 кладёт ЦП
;
;  ОСОБЫЙ СЛУЧАЙ vs ПРОГРАММНОЕ ПРЕРЫВАНИЕ:
;     источник события - внутренняя ошибка ЦП (DIV с нулём), а не
;     команда INT; но заполнение стека ОДИНАКОВОЕ (FLAGS, CS, IP).
;     По умолчанию ЦП ПОВТОРЯЕТ команду. Чтобы её пропустить -
;     сдвигаем IP в кадре на длину команды (DIV BX = F7 F3 = 2 байта).
;
;  Сборка:  tasm /zi lab6_5.asm  +  tlink /v /t lab6_5   (задача VS Code)
;  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab6_5
;==============================================================

.286
.MODEL TINY

ShowS   MACRO msg
       lea  dx, msg
       mov  ah, 09h
       int  21h
ENDM

ShowC  MACRO
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
ENDM

.CODE
ORG 100h

START:
       ShowS MsgTitle

;--------------------------------------------------------------
; 0. СТАРЫЙ ВЕКТОР 00h (IVT = 0000:0000, вектор 00h -> адрес 0)
;--------------------------------------------------------------
       xor  ax, ax
       mov  es, ax
       mov  ax, es:[00h*4+2]
       mov  OldSeg, ax
       mov  ax, es:[00h*4]
       mov  OldOfs, ax

       ShowS MsgIvtHdr
       ShowS MsgIvtOld
       mov  ax, OldSeg
       call Phex16
       ShowS MsgSep
       mov  ax, OldOfs
       call Phex16
       ShowC
       ShowS MsgFirstTen
       ShowC

;--------------------------------------------------------------
; 1. ЗАПОМНИТЬ СТАРЫЙ ВЕКТОР и УСТАНОВИТЬ НОВЫЙ (аналог setvect)
;--------------------------------------------------------------
       cli
       mov  word ptr es:[00h*4],     offset ISR_DIV0
       mov  word ptr es:[00h*4+2],   cs
       sti

       mov  ax, es:[00h*4+2]
       mov  NewSeg, ax
       mov  ax, es:[00h*4]
       mov  NewOfs, ax

       ShowS MsgIvtNew
       mov  ax, NewSeg
       call Phex16
       ShowS MsgSep
       mov  ax, NewOfs
       call Phex16
       ShowC

;--------------------------------------------------------------
; 2. ВОЗБУДИТЬ ОСОБЫЙ СЛУЧАЙ: деление на нуль
;    параметры ПП - в регистрах (AX - делимое, BX - делитель)
;    и в памяти (Dividend, Divisor, SafeDiv)
;--------------------------------------------------------------
       ShowS MsgHead1
       ShowS MsgOper
       mov  ax, Dividend
       call Phex16
       ShowS MsgOper2
       mov  ax, Divisor
       call Phex16
       ShowC

       mov  SpMain, sp           ; вершина стека ДО особого случая
       mov  ax, Dividend
       xor  dx, dx
       mov  bx, Divisor
       div  bx                   ; BX=0 -> особый случай, вектор 00h

       ; ---- выполнение продолжается ЗДЕСЬ: DIV пропущена (IP сдвинут)
       mov  Quotient,  ax
       mov  Remainder, dx

;--------------------------------------------------------------
; 3. ВОССТАНОВИТЬ СТАРЫЙ ВЕКТОР
;--------------------------------------------------------------
       xor  ax, ax
       mov  es, ax
       cli
       mov  ax, OldOfs              ; память -> память недопустима: через AX
       mov  es:[00h*4],   ax
       mov  ax, OldSeg
       mov  es:[00h*4+2], ax
       sti

       mov  ax, es:[00h*4+2]
       mov  ResSeg, ax
       mov  ax, es:[00h*4]
       mov  ResOfs, ax

       ShowS MsgRestored
       mov  ax, ResSeg
       call Phex16
       ShowS MsgSep
       mov  ax, ResOfs
       call Phex16
       ShowC

;--------------------------------------------------------------
; 4. АНАЛИЗ ЗАПОЛНЕНИЯ СТЕКА (снят внутри ПП до изменений)
;--------------------------------------------------------------
       ShowS MsgHead2
       ShowS MsgSpMain
       mov  ax, SpMain
       call Phex16
       ShowS MsgArrow
       mov  ax, SpIsr
       call Phex16
       ShowS MsgBytes            ; ShowS ДО вычисления: int 21h/09h меняет AH
       mov  ax, SpMain
       sub  ax, SpIsr
       call Pdec16
       ShowS MsgBytesUnit
       ShowS MsgWords
       mov  ax, SpMain
       sub  ax, SpIsr
       shr  ax, 1
       call Pdec16
       ShowS MsgWordsUnit
       ShowC

       ShowS MsgFrSS
       mov  ax, FrSS
       call Phex16
       ShowS MsgSep
       mov  ax, FrBP
       call Phex16
       ShowC

       ; --- дамп 12 слов кадра ---
       lea  si, Frame
       lea  bx, NameTbl
       mov  cx, 12
L_dump:
       mov  ax, [bx]
       mov  dx, ax
       mov  ah, 09h
       int  21h
       mov  ax, [si]
       call Phex16
       ; кто положил: первые 9 слов - пролог компилятора, последние 3 - ЦП
       mov  ax, 12
       sub  ax, cx
       cmp  ax, 9
       jb   L_whoProlog
       ShowS MsgWhoCpu
       jmp  L_whoDone
L_whoProlog:
       ShowS MsgWhoProlog
L_whoDone:
       ShowC
       add  bx, 2               ; таблица теперь из слов (DW)
       add  si, 2
       dec  cx
       jnz  L_dump

       ShowS MsgWhy18
       ShowC

;--------------------------------------------------------------
; 5. АДРЕС ВОЗВРАТА: до и после add [bp+18], 2
;--------------------------------------------------------------
       ShowS MsgHead3
       ShowS MsgIpBefore
       mov  ax, IpBefore
       call Phex16
       ShowS MsgPointsAt
       ShowC
       ShowS MsgIpAfter
       mov  ax, IpAfter
       call Phex16
       ShowS MsgPointsAfter
       ShowC
       ShowS MsgDelta2
       mov  ax, IpAfter
       sub  ax, IpBefore
       call Pdec16
       ShowS MsgDeltaUnit
       ShowC

       ShowS MsgCsIn
       mov  ax, CsIn
       call Phex16
       ShowC
       ShowS MsgFlIn
       mov  ax, FlIn
       call Pflags
       ShowS MsgIfNote
       ShowC

;--------------------------------------------------------------
; 6. РЕЗУЛЬТАТ, ВЫДАННЫЙ ПП ЧЕРЕЗ КАДР (слоты AX и DX)
;--------------------------------------------------------------
       ShowS MsgHead4
       ShowS MsgRes
       mov  ax, Quotient
       call Pdec16
       ShowS MsgResRem
       mov  ax, Remainder
       call Pdec16
       ShowC
       ShowS MsgSlots
       mov  ax, SlotAX
       call Phex16
       ShowS MsgSep
       mov  ax, SlotDX
       call Phex16
       ShowC
       ShowS MsgEntries
       mov  ax, Entries
       call Pdec16
       ShowS MsgEntriesNote
       ShowC

;--------------------------------------------------------------
; 7. СРАВНЕНИЕ СО ШАГОМ 3 на Си (там IP НЕ сдвигали)
;--------------------------------------------------------------
       ShowS MsgHead5
       ShowS MsgCompare
       ShowC
       ShowS MsgPause
IFNDEF NOWAIT            ; /dNOWAIT: пакетная самопроверка без ожидания клавиши
       mov  ah, 00h
       int  16h
ENDIF

       mov  ah, 4Ch
       int  21h

;==============================================================
;  ПП - обработчик ОСОБОГО СЛУЧАЯ int 00h (Divide Error)
;  На входе: [SP]=IP, [SP+2]=CS, [SP+4]=FLAGS  (положил ЦП)
;==============================================================
ISR_DIV0 PROC FAR
       mov  SpIsr, sp            ; вершина стека НА ВХОДЕ в ПП

       ; --- пролог в стиле Borland C (9 слов) ---
       push ax
       push bx
       push cx
       push dx
       push es
       push ds
       push si
       push di
       push bp
       mov  bp, sp               ; теперь IP лежит в [bp+18]

       mov  FrSS, ss
       mov  FrBP, bp

       ; --- снять кадр ДО каких-либо изменений ---
       lea  si, Frame
       mov  bx, bp
       mov  cx, 12
L_snap:
       mov  ax, ss:[bx]
       mov  [si], ax
       add  bx, 2
       add  si, 2
       dec  cx
       jnz  L_snap

       mov  ax, ss:[bp+18]
       mov  IpBefore, ax
       mov  ax, ss:[bp+20]
       mov  CsIn, ax
       mov  ax, ss:[bp+22]
       mov  FlIn, ax

       inc  Entries

       ; --- ОБРАБОТКА ДАННЫХ: ПП сама считает результат ---
       ;     (делитель нулевой, поэтому деление повторно не нужно)
       xor  dx, dx
       mov  ax, Dividend
       mov  bx, SafeDiv
       div  bx
       mov  Quotient,  ax
       mov  Remainder, dx

       ; --- выдать результат вызывающему ЧЕРЕЗ КАДР:
       ;     [bp+16] = AX, [bp+10] = DX. После IRET и pop ax / pop dx
       ;     main получит эти значения, хотя DIV не исполнялась.
       mov  word ptr ss:[bp+16], ax      ; слот AX вызывающего <- частное
       mov  word ptr ss:[bp+10], dx      ; слот DX вызывающего <- остаток
       mov  bx, bp                       ; снимаем слоты ПОСЛЕ записи: подпись
       mov  ax, ss:[bx+16]               ; "written by PP" должна показывать
       mov  SlotAX, ax                   ; именно записанные значения
       mov  ax, ss:[bx+10]
       mov  SlotDX, ax

       ; --- ПРОПУСК КОМАНДЫ, ВЫЗВАВШЕЙ ОСОБЫЙ СЛУЧАЙ (строка 53 A6.txt)
       ;     DIV BX = F7 F3 -> 2 байта
       add  word ptr ss:[bp+18], 2

       mov  ax, ss:[bp+18]
       mov  IpAfter, ax

       ; --- эпилог (обратный прологу) и выход ЧЕРЕЗ IRET ---
       pop  bp
       pop  di
       pop  si
       pop  ds
       pop  es
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       iret
ISR_DIV0 ENDP

;==============================================================
;  PrintHex16: AX в HEX (4 цифры)
;==============================================================
Phex16 PROC
       push ax
       push bx
       push cx
       push dx
       mov  cx, 4
L_ph1:
       rol  ax, 4
       push ax
       mov  dl, al
       and  dl, 0Fh
       add  dl, '0'
       cmp  dl, '9'
       jbe  L_ph2
       add  dl, 7
L_ph2:
       mov  ah, 02h
       int  21h
       pop  ax
       loop L_ph1
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       ret
Phex16 ENDP

;==============================================================
;  Pdec16: AX как беззнаковое десятичное
;==============================================================
Pdec16 PROC
       push bx
       push cx
       push dx
       push si
       mov  bx, offset DecBuf + 6
       mov  byte ptr [bx], '$'
       mov  si, 10
L_pd1:
       xor  dx, dx
       div  si
       add  dl, '0'
       dec  bx
       mov  [bx], dl
       test ax, ax
       jnz  L_pd1
       lea  dx, [bx]
       mov  ah, 09h
       int  21h
       pop  si
       pop  dx
       pop  cx
       pop  bx
       ret
Pdec16 ENDP

;==============================================================
;  Pflags: AX = слово флагов -> HEX + CF PF AF ZF SF TF IF
;==============================================================
Pflags PROC
       ; ИМЯ бита печатается ДО вычисления (ShowS присваивает AH=09h),
       ; иначе вместо битов выводилось содержимое AH: "PF PF PF...".
       push bx
       push cx
       call Phex16
       mov  bx, ax               ; Phex16 восстанавливает AX
       ShowS MsgNCF
       mov  ax, bx
       and  ax, 1                ; CF (bit 0)
       call Pdec16
       ShowS MsgNPF
       mov  ax, bx
       shr  ax, 1
       shr  ax, 1                ; PF (bit 2)
       and  ax, 1
       call Pdec16
       ShowS MsgNAF
       mov  ax, bx
       shr  ax, 4                ; AF (bit 4)
       and  ax, 1
       call Pdec16
       ShowS MsgNZF
       mov  ax, bx
       shr  ax, 6                ; ZF (bit 6)
       and  ax, 1
       call Pdec16
       ShowS MsgNSF
       mov  ax, bx
       shr  ax, 7                ; SF (bit 7)
       and  ax, 1
       call Pdec16
       ShowS MsgNTF
       mov  ax, bx
       shr  ax, 8                ; TF (bit 8)
       and  ax, 1
       call Pdec16
       ShowS MsgNIF
       mov  ax, bx
       shr  ax, 9                ; IF (bit 9)
       and  ax, 1
       call Pdec16
       ShowS MsgBrkC
       pop  cx
       pop  bx
       ret
Pflags ENDP

;==============================================================
;  ДАННЫЕ - ПОСЛЕ кода (обязательно для .COM)
;==============================================================
.DATA
Dividend    DW  24680               ; 0x6068 - делимое
Divisor     DW  0                   ; 0  -> особый случай
SafeDiv     DW  7                   ; чем ПП заменит нулевой делитель
Quotient    DW  ?
Remainder   DW  ?

SpMain      DW  ?
SpIsr       DW  ?
FrSS        DW  ?
FrBP        DW  ?
Frame       DW  12 DUP(?)
SlotAX      DW  ?
SlotDX      DW  ?
IpBefore    DW  ?
IpAfter     DW  ?
CsIn        DW  ?
FlIn        DW  ?
Entries     DW  0

OldOfs      DW  ?
OldSeg      DW  ?
NewOfs      DW  ?
NewSeg      DW  ?
ResOfs      DW  ?
ResSeg      DW  ?

;  ВАЖНО: именно DW + OFFSET, а не "DD Sl0,..": DD с меткой без OFFSET
;  порождает 32-битный far-указатель с СЕГМЕНТНОЙ релокацией, и TLINK
;  для .COM отказывает: "Cannot generate COM file: segment-relocatable
;  items present in module". В модели TINY все смещения 16-битные.
NameTbl     DW  offset Sl0, offset Sl1, offset Sl2, offset Sl3
        DW  offset Sl4, offset Sl5, offset Sl6, offset Sl7
        DW  offset Sl8, offset Sl9, offset Sl10, offset Sl11
DecBuf      DB  7 DUP(?)

Sl0   DB  '  [bp+0 ] BP    = $'
Sl1   DB  '  [bp+2 ] DI    = $'
Sl2   DB  '  [bp+4 ] SI    = $'
Sl3   DB  '  [bp+6 ] DS    = $'
Sl4   DB  '  [bp+8 ] ES    = $'
Sl5   DB  '  [bp+10] DX    = $'
Sl6   DB  '  [bp+12] CX    = $'
Sl7   DB  '  [bp+14] BX    = $'
Sl8   DB  '  [bp+16] AX    = $'
Sl9   DB  '  [bp+18] IP    = $'
Sl10  DB  '  [bp+20] CS    = $'
Sl11  DB  '  [bp+22] FLAGS = $'

MsgCr        DB  13,10,'$'
MsgSep       DB  ':$'
MsgArrow     DB  '  ->  $'
MsgBytes     DB  '  = $'
MsgBytesUnit DB  ' bytes$'
MsgWords     DB  '  = $'
MsgWordsUnit DB  ' words$'
MsgPointsAt  DB  '   <- points AT the DIV opcode (F7 F3)$'
MsgPointsAfter DB '   <- points AFTER the DIV: the faulting command is SKIPPED$'
MsgDelta2    DB  '  IP advanced by $'
MsgDeltaUnit DB  ' bytes  (= length of DIV BX: F7 F3)$'
MsgWhoCpu    DB  '   <- PROCESSOR (INT / exception)$'
MsgWhoProlog DB  '   <- compiler prologue (push ax..bp)$'
MsgNCF       DB  '  CF=$'
MsgNPF       DB  ' PF=$'
MsgNAF       DB  ' AF=$'
MsgNZF       DB  ' ZF=$'
MsgNSF       DB  ' SF=$'
MsgNTF       DB  ' TF=$'
MsgNIF       DB  ' IF=$'
MsgBrkC      DB  '   (bits 0,2,4,6,7,8,9)$'

MsgTitle     DB  13,10,'=== Lab6 steps 3+4 (ASM): exception int 00h + skipping the faulting DIV ===',13,10,'$'
MsgIvtHdr    DB  'IVT[00h] is the Divide Error vector (one of the first ten):',13,10,'$'
MsgIvtOld    DB  '  old vector 00h = $'
MsgIvtNew    DB  '  new vector 00h = $'
MsgFirstTen  DB  '  00h DIVIDE ERROR, 01h TRAP, 02h NMI, 03h BREAKPOINT, 04h INTO,',13,10
             DB  '  05h BOUND, 06h INVALID OPCODE, 07h DEVICE NOT AVAILABLE,',13,10
             DB  '  08h DOUBLE FAULT, 09h COPROCESSOR SEGMENT OVERRUN',13,10,'$'
MsgRestored  DB  '  vector 00h restored = $'

MsgHead1     DB  13,10,'--- 1) raise the exception: DIV with a zero divisor ---',13,10,'$'
MsgOper      DB  '  Dividend = $'
MsgOper2     DB  ',  Divisor = $'

MsgHead2     DB  13,10,'--- 2) STACK FILL of the exception (snapshot inside the PP) ---',13,10,'$'
MsgSpMain    DB  '  SP before the exception = $'
MsgFrSS      DB  '  frame address  SS:BP = $'
MsgWhy18     DB  '  9 prologue words = 18 bytes, so the processor-pushed IP sits at bp+18.',13,10
             DB  '  That is exactly why the assignment writes:  add [bp+18], 2',13,10,'$'

MsgHead3     DB  13,10,'--- 3) return address before / after "add word ptr [bp+18], 2" ---',13,10,'$'
MsgIpBefore  DB  '  IP in frame before add = $'
MsgIpAfter   DB  '  IP in frame after  add = $'
MsgCsIn      DB  '  CS in frame            = $'
MsgFlIn      DB  '  FLAGS in frame (old)   = $'
MsgIfNote    DB  13,10,'  TF and IF were cleared by the CPU entering the PP; the frame keeps',13,10
             DB  '  their PREVIOUS values, and IRET restores them.',13,10,'$'

MsgHead4     DB  13,10,'--- 4) result supplied by the PP THROUGH the frame ---',13,10,'$'
MsgRes       DB  '  quotient  = $'
MsgResRem    DB  ',  remainder = $'
MsgSlots     DB  '  frame slots written by PP: [bp+16] AX = $'
MsgEntries   DB  '  entries into PP = $'
MsgEntriesNote DB '   (DIV was NOT re-executed: IP was moved)$'

MsgHead5     DB  13,10,'--- 5) comparison with the C version of step 3 ---',13,10,'$'
MsgCompare   DB  '  step 3 (C) : IP untouched -> CPU RE-EXECUTED DIV, PP fixed BX=1;',13,10
             DB  '  step 4 here : add [bp+18],2 -> DIV SKIPPED, PP wrote AX and DX.',13,10
             DB  '  Exception and software INT fill the stack IDENTICALLY (FLAGS,CS,IP);',13,10
             DB  '  only the SOURCE differs: internal CPU fault vs the INT instruction.',13,10,'$'
MsgPause     DB  13,10,'>>> Press any key to finish... $'

END START
