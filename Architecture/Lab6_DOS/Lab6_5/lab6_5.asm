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

; 0. Старый вектор 00h
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

; 1. Запомнить старый вектор и установить новый
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

; 2. Возбудить особый случай: деление на нуль
       ShowS MsgHead1
       ShowS MsgOper
       mov  ax, Dividend
       call Phex16
       ShowS MsgOper2
       mov  ax, Divisor
       call Phex16
       ShowC

       mov  SpMain, sp
       mov  ax, Dividend
       xor  dx, dx
       mov  bx, Divisor
       div  bx

       mov  Quotient,  ax
       mov  Remainder, dx

; 3. Восстановить старый вектор
       xor  ax, ax
       mov  es, ax
       cli
       mov  ax, OldOfs
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

; 4. Анализ заполнения стека
       ShowS MsgHead2
       ShowS MsgSpMain
       mov  ax, SpMain
       call Phex16
       ShowS MsgArrow
       mov  ax, SpIsr
       call Phex16
       ShowS MsgBytes
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
       add  bx, 2
       add  si, 2
       dec  cx
       jnz  L_dump

       ShowS MsgWhy18
       ShowC

; 5. Адрес возврата: до и после add [bp+18], 2
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

; 6. Результат, выданный ПП через кадр
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

; 7. Сравнение с шагом 3 на Си
       ShowS MsgHead5
       ShowS MsgCompare
       ShowC
       ShowS MsgPause
IFNDEF NOWAIT
       mov  ah, 00h
       int  16h
ENDIF

       mov  ah, 4Ch
       int  21h

ISR_DIV0 PROC FAR
       mov  SpIsr, sp

       push ax
       push bx
       push cx
       push dx
       push es
       push ds
       push si
       push di
       push bp
       mov  bp, sp

       mov  FrSS, ss
       mov  FrBP, bp

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

       xor  dx, dx
       mov  ax, Dividend
       mov  bx, SafeDiv
       div  bx
       mov  Quotient,  ax
       mov  Remainder, dx

       mov  word ptr ss:[bp+16], ax
       mov  word ptr ss:[bp+10], dx
       mov  bx, bp
       mov  ax, ss:[bx+16]
       mov  SlotAX, ax
       mov  ax, ss:[bx+10]
       mov  SlotDX, ax

       add  word ptr ss:[bp+18], 2

       mov  ax, ss:[bp+18]
       mov  IpAfter, ax

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

Pflags PROC
       push bx
       push cx
       call Phex16
       mov  bx, ax
       ShowS MsgNCF
       mov  ax, bx
       and  ax, 1
       call Pdec16
       ShowS MsgNPF
       mov  ax, bx
       shr  ax, 1
       shr  ax, 1
       and  ax, 1
       call Pdec16
       ShowS MsgNAF
       mov  ax, bx
       shr  ax, 4
       and  ax, 1
       call Pdec16
       ShowS MsgNZF
       mov  ax, bx
       shr  ax, 6
       and  ax, 1
       call Pdec16
       ShowS MsgNSF
       mov  ax, bx
       shr  ax, 7
       and  ax, 1
       call Pdec16
       ShowS MsgNTF
       mov  ax, bx
       shr  ax, 8
       and  ax, 1
       call Pdec16
       ShowS MsgNIF
       mov  ax, bx
       shr  ax, 9
       and  ax, 1
       call Pdec16
       ShowS MsgBrkC
       pop  cx
       pop  bx
       ret
Pflags ENDP

.DATA
Dividend    DW  24680
Divisor     DW  0
SafeDiv     DW  7
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