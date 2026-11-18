;==============================================================
;  Лабораторная работа 6, ШАГ 2  (A6.txt, строка 47)
;  "Проанализируйте заполнение стека" для программного прерывания.
;
;  Чистый ассемблер (TASM, модель TINY -> .COM). Разбирается, как
;  заполняется стек при:
;     a) программном прерывании INT 0F0h  -> 3 слова: IP, CS, FLAGS
;     b) вызове CALL NEAR                 -> 1 слово:  IP
;     c) вызове CALL FAR                  -> 2 слова:  IP, CS
;  плюс проверяется "ЧТО НУЖНО ОСОЗНАТЬ": вектор = 32-битная ячейка
;  IVT, разрешённые/запрещённые вектора, сброс TF и IF, возврат IRET.
;
;  ВНИМАНИЕ: обработчик (ПП) НЕ вызывает int 21h - DOS не реентера-
;  белен; ПП только пишет данные в память, печать - в основном коде.
;
;  Сборка:  tasm /zi lab6_2.asm  +  tlink /v /t lab6_2   (задача VS Code)
;  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab6_2
;==============================================================

.286                    ; нужны PUSHF/POPF и обращение к [SP]
.MODEL TINY

;---------- макросы вывода (определяем ДО использования) ----------
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
ORG 100h                        ; COM: PSP занимает 00h..0FFh

START:
;  в TINY/COM DOS загружает CS = DS = SS одинаково, assume не нужен

       ShowS MsgTitle

;--------------------------------------------------------------
; 0. ВЕКТОР ПРЕРЫВАНИЯ ДО УСТАНОВКИ НАШЕГО ОБРАБОТЧИКА
;    IVT = 0000:0000, 256 векторов по 4 байта = первые 1000h байт
;--------------------------------------------------------------
       xor  ax, ax
       mov  es, ax              ; ES -> 0000 (IVT)
       mov  ax, es:[0F0h*4+2]
       mov  OldSeg, ax
       mov  ax, es:[0F0h*4]
       mov  OldOfs, ax

       ShowS MsgIvtRange
       ShowS MsgIvtOld
       mov  ax, OldSeg           ; AX надо ПЕРЕЗАГРУЗИТЬ: ShowS меняет AH (09h)
       call Phex16
       ShowS MsgSep
       mov  ax, OldOfs
       call Phex16
       ShowC

;--------------------------------------------------------------
; 1. УСТАНОВИТЬ НОВЫЙ ВЕКТОР (аналог setvect(0F0h, ISR_F0))
;    разрешение/запрет прерываний: CLI / STI (аналог disable/enable)
;--------------------------------------------------------------
       cli
       mov  word ptr es:[0F0h*4],     offset ISR_F0
       mov  word ptr es:[0F0h*4+2],   cs
       sti

       mov  ax, es:[0F0h*4+2]
       mov  NewSeg, ax
       mov  ax, es:[0F0h*4]
       mov  NewOfs, ax

       ShowS MsgIvtNew
       mov  ax, NewSeg
       call Phex16
       ShowS MsgSep
       mov  ax, NewOfs
       call Phex16
       ShowC
       ShowS MsgInstalled
       ShowC

;--------------------------------------------------------------
; 2. ПАРАМЕТРЫ ПП -> РЕГИСТРЫ И ПАМЯТЬ, ВЫЗОВ ПП ЧЕРЕЗ INT
;--------------------------------------------------------------
       ShowS MsgHead1

       mov  SpBefore, sp        ; вершина стека ДО прерывания

       pushf                    ; FLAGS до прерывания снимаем СРАЗУ:
       pop  ax                  ;   если сделать это после загрузки параметров,
       mov  FlBefore, ax        ;   pop ax затрёт параметр (AX=1234h)

       mov  ax, 1234h           ; 1-й параметр (AX)
       mov  bx, 0078h           ; 2-й параметр (BX)
       lea  si, Array           ; 3-й параметр: адрес массива (SI)
       mov  cx, 4               ; 4-й параметр: число элементов (CX)

       int  0F0h                ; === ПРОГРАММНОЕ ПРЕРЫВАНИЕ = ВЫЗОВ ПП ===

AfterInt:
       mov  CsExp, cs
       mov  IpExp, offset AfterInt
       pushf
       pop  ax
       mov  FlAfter, ax

;--------------------------------------------------------------
; 3. АНАЛИЗ ЗАПОЛНЕНИЯ СТЕКА
;--------------------------------------------------------------
       ShowS MsgHead2
       ShowS MsgSpLbl
       mov  ax, SpBefore
       call Phex16
       ShowS MsgArrow
       mov  ax, SpIsr
       call Phex16

       ShowS MsgBytes            ; ShowS ПЕРВЫМ, иначе int 21h затирает AX
       mov  ax, SpBefore
       sub  ax, SpIsr
       call Pdec16
       ShowS MsgWords
       mov  ax, SpBefore
       sub  ax, SpIsr
       shr  ax, 1
       call Pdec16
       ShowS MsgWordsUnit
       ShowC

       ShowS MsgTblHdr
       ShowS MsgTblIP
       mov  ax, StkIP
       call Phex16
       ShowS MsgCpu
       mov  ax, StkIP
       cmp  ax, IpExp
       jne  L_IpBad
       ShowS MsgEqRet
       ShowC
       jmp  L_IpShow
L_IpBad:
       ShowS MsgNeRet
       ShowC
L_IpShow:

       ShowS MsgTblCS
       mov  ax, StkCS
       call Phex16
       ShowS MsgCpu
       mov  ax, StkCS
       cmp  ax, CsExp
       jne  L_CsBad
       ShowS MsgEqRet
       ShowC
       jmp  L_CsShow
L_CsBad:
       ShowS MsgNeRet
       ShowC
L_CsShow:

       ShowS MsgTblFL
       mov  ax, StkFL
       call Phex16
       ShowS MsgCpu
       ShowS MsgOldFlags
       ShowC

       ShowS MsgBalanced
       mov  ax, sp
       call Phex16              ; само значение SP после IRET
       cmp  sp, SpBefore        ; Phex16 сохраняет AX, но SP сравниваем прямо
       jne  L_BalBad
       ShowS MsgEqSp
       ShowC
       jmp  L_BalShow
L_BalBad:
       ShowS MsgNotEq
       ShowC
L_BalShow:

;--------------------------------------------------------------
; 4. РЕЗУЛЬТАТ ОБРАБОТКИ ДАННЫХ ВНУТРИ ПП
;--------------------------------------------------------------
       ShowS MsgHead3
       ShowS MsgSumLbl
       mov  ax, ResSum
       call Phex16
       ShowC
       ShowS MsgCntLbl
       mov  ax, ResCnt
       call Pdec16
       ShowC
       ShowS MsgReadLbl
       mov  ax, GotAX
       call Phex16
       ShowS MsgComma
       mov  ax, GotBX
       call Phex16
       ShowC
       ShowS MsgEntries
       mov  ax, Entries
       call Pdec16
       ShowC

;--------------------------------------------------------------
; 5. ФЛАГИ TF И IF: ПРОЦЕССОР СБРАСЫВАЕТ ИХ ПРИ ВХОДЕ В ПП
;--------------------------------------------------------------
       ShowS MsgHead4
       ShowS MsgFlBefore
       mov  ax, FlBefore
       call Pflags
       ShowS MsgFlIsr
       mov  ax, FlIsr
       call Pflags
       ShowS MsgFlAfter
       mov  ax, FlAfter
       call Pflags
       ShowS MsgTfIfNote
       ShowC

;--------------------------------------------------------------
; 6. СРАВНЕНИЕ С ВЫЗОВОМ ПОДПРОГРАММЫ (CALL NEAR / CALL FAR)
;--------------------------------------------------------------
       ShowS MsgHead5

       mov  SpB1, sp
       call NearSub                    ; кадр NEAR: 1 слово (IP)

       mov  word ptr [FarPtr],     offset FarSub
       mov  word ptr [FarPtr+2],   cs
       mov  SpB2, sp
       call dword ptr [FarPtr]         ; кадр FAR: 2 слова (CS:IP)

       ShowS MsgRowNear
       mov  ax, SpB1
       sub  ax, SpInNear
       shr  ax, 1
       call Pdec16
       ShowS MsgRowNear2
       mov  ax, NearRetIP
       call Phex16
       ShowC

       ShowS MsgRowInt
       mov  ax, SpBefore
       sub  ax, SpIsr
       shr  ax, 1
       call Pdec16
       ShowS MsgRowInt2
       mov  ax, StkIP
       call Phex16
       ShowS MsgSep
       mov  ax, StkCS
       call Phex16
       ShowS MsgSep
       mov  ax, StkFL
       call Phex16
       ShowC

       ShowS MsgRowFar
       mov  ax, SpB2
       sub  ax, SpInFar
       shr  ax, 1
       call Pdec16
       ShowS MsgRowFar2
       mov  ax, FarRetIP
       call Phex16
       ShowS MsgSep
       mov  ax, FarRetCS
       call Phex16
       ShowC

       ShowS MsgConclusion
       ShowC

;--------------------------------------------------------------
; 7. ВОССТАНОВИТЬ СТАРЫЙ ВЕКТОР (аналог setvect(0F0h, old_f0))
;--------------------------------------------------------------
       xor  ax, ax
       mov  es, ax
       cli
       mov  ax, OldOfs               ; память -> память на 8086 НЕДОПУСТИМА,
       mov  es:[0F0h*4],   ax         ;   поэтому старый вектор возвращаем
       mov  ax, OldSeg                ;   через AX
       mov  es:[0F0h*4+2], ax
       sti

       mov  ax, es:[0F0h*4+2]
       mov  ResSeg, ax
       mov  ax, es:[0F0h*4]
       mov  ResOfs, ax

       ShowS MsgRestored
       mov  ax, ResSeg
       call Phex16
       ShowS MsgSep
       mov  ax, ResOfs
       call Phex16
       ShowC

;--------------------------------------------------------------
; 8. РАЗРЕШЁННЫЕ И ЗАПРЕЩЁННЫЕ ВЕКТОРА
;--------------------------------------------------------------
       ShowS MsgVecHdr
       ShowS MsgVecList
       ShowS MsgPause
IFNDEF NOWAIT            ; /dNOWAIT: пакетная самопроверка без ожидания клавиши
       mov  ah, 00h
       int  16h
ENDIF

       mov  ah, 4Ch
       int  21h

;==============================================================
;  ПП - обработчик программного прерывания 0F0h (FAR по природе)
;  На входе:  [SP]=IP, [SP+2]=CS, [SP+4]=FLAGS  (положил ЦП)
;==============================================================
ISR_F0 PROC FAR
       mov  GotAX, ax            ; ПАРАМЕТРЫ регистрируем СРАЗУ: дальше AX
       mov  GotBX, bx            ;  перезапишется через pushf/pop ax
       mov  SpIsr, sp            ; вершина стека НА ВХОДЕ в ПП

       ; --- снять 3 слова, положенные ПРОЦЕССОРОМ ---
       mov  bx, sp
       mov  ax, ss:[bx]
       mov  StkIP, ax
       mov  ax, ss:[bx+2]
       mov  StkCS, ax
       mov  ax, ss:[bx+4]
       mov  StkFL, ax

       ; --- FLAGS ВНУТРИ ПП (ЦП уже обнулил TF и IF) ---
       pushf
       pop  ax
       mov  FlIsr, ax

       ; --- сохранить регистры (пролог в стиле Borland) ---
       push ax
       push bx
       push cx
       push dx
       push es
       push ds
       push si
       push di
       push bp

       inc  Entries              ; GotAX/GotBX сняты на входе

       ; --- ОБРАБОТКА ДАННЫХ в ПП ---
       ;   сумма: параметр-массив (SI, CX) + параметры AX и BX
       mov  ResCnt, cx
       xor  ax, ax
       add  ax, GotAX
       add  ax, GotBX
       mov  bx, cx               ; число элементов
       L_IsrLoop:
       add  ax, [si]
       add  si, 2
       dec  bx
       jnz  L_IsrLoop
       mov  ResSum, ax

       ; --- восстановить регистры и выйти ЧЕРЕЗ IRET ---
       pop  bp
       pop  di
       pop  si
       pop  ds
       pop  es
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       iret                      ; извлекает IP, CS, FLAGS (3 слова)
ISR_F0 ENDP

;==============================================================
;  Подпрограммы для сравнения механизмов возврата
;==============================================================
NearSub PROC NEAR
       mov  SpInNear, sp         ; СПЕРВА замер SP (иначе push bx исказит дельту)
       push bx                   ;        BX бережём: он живёт в main
       mov  bx, SpInNear         ; SP как индекс прямо нельзя: [sp] - "Illegal
       mov  ax, ss:[bx]          ;  indexing mode" даже с .386, нужен базовый рег.
       mov  NearRetIP, ax        ; ЕДИНСТВЕННОЕ слово кадра CALL NEAR
       pop  bx
       ret
NearSub ENDP

FarSub  PROC FAR
       mov  SpInFar, sp          ; СПЕРВА замер SP: SP внутри = 4 байта ниже
       push bx
       mov  bx, SpInFar
       mov  ax, ss:[bx]          ; [SP]   = IP
       mov  FarRetIP, ax
       mov  ax, ss:[bx+2]        ; [SP+2] = CS ; FLAGS НЕ сохраняются
       mov  FarRetCS, ax
       pop  bx
       ret
FarSub  ENDP

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
;  Pflags: AX = слово флагов -> HEX + разбор CF PF AF ZF SF TF IF
;==============================================================
Pflags PROC
       ; ИМЯ бита выводится ДО вычисления: ShowS вызывает int 21h/09h,
       ; который присваивает AH=09h, поэтому порядок "сначала ShowS, потом
       ; mov/and/call Pdec16" - иначе печаталось содержимое AH (0906h = 2310).
       push bx
       push cx
       call Phex16               ; само слово флагов в HEX
       mov  bx, ax               ; Phex16 восстанавливает AX -> образец в BX
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
Array       DW  1000h, 2000h, 0003h, 0004h

SpBefore    DW  ?
SpIsr       DW  ?
StkIP       DW  ?
StkCS       DW  ?
StkFL       DW  ?
FlBefore    DW  ?
FlIsr       DW  ?
FlAfter     DW  ?
CsExp       DW  ?
IpExp       DW  ?

OldOfs      DW  ?
OldSeg      DW  ?
NewOfs      DW  ?
NewSeg      DW  ?
ResOfs      DW  ?
ResSeg      DW  ?

GotAX       DW  ?
GotBX       DW  ?
ResSum      DW  ?
ResCnt      DW  ?
Entries     DW  0

SpB1        DW  ?
SpInNear    DW  ?
SpB2        DW  ?
SpInFar     DW  ?
NearRetIP   DW  ?
FarRetIP    DW  ?
FarRetCS    DW  ?
FarPtr      DD  ?
DecBuf      DB  7 DUP(?)

MsgCr       DB  13,10,'$'
MsgSep      DB  ':$'
MsgComma    DB  ', BX=$'
MsgArrow    DB  '  ->  $'
MsgBytes    DB  '  = $'
MsgWords    DB  '  = $'
MsgWordsUnit DB ' words of stack$'
MsgCpu      DB  '   <- pushed by THE PROCESSOR$'
MsgEqRet    DB  '  = return address (ok)$'
MsgNeRet    DB  '  <> return address (!)$'
MsgEqSp     DB  '  = SP before INT: stack balanced$'
MsgNotEq    DB  '  <> SP before INT: LEAK!$'
MsgOldFlags DB  '   (old flags, saved before the interrupt)$'
MsgNCF      DB  '  CF=$'
MsgNPF      DB  ' PF=$'
MsgNAF      DB  ' AF=$'
MsgNZF      DB  ' ZF=$'
MsgNSF      DB  ' SF=$'
MsgNTF      DB  ' TF=$'
MsgNIF      DB  ' IF=$'
MsgBrkC     DB  '   (bits 0,2,4,6,7,8,9)$'

MsgTitle    DB  13,10,'=== Lab6 step 2 (ASM): stack fill of a software interrupt ===',13,10,'$'
MsgIvtRange DB  'IVT: 256 vectors x 4 bytes = 0000:0000..0000:03FF (first 1 KB)',13,10,'$'
MsgIvtOld   DB  '  vector 0F0h, old = $'
MsgIvtNew   DB  '  vector 0F0h, new = $'
MsgInstalled DB '  new vector installed by direct IVT write under CLI/STI$'

MsgHead1    DB  13,10,'--- 1) INT 0F0h as a subroutine call: params in AX,BX,CX,SI ---',13,10,'$'
MsgHead2    DB  13,10,'--- 2) STACK FILL at the handler entry ---',13,10,'$'
MsgSpLbl    DB  '  SP before INT = $'
MsgTblHdr   DB  13,10,'  frame contents:',13,10,'$'
MsgTblIP    DB  '    [SP+0] IP    = $'
MsgTblCS    DB  '    [SP+2] CS    = $'
MsgTblFL    DB  '    [SP+4] FLAGS = $'
MsgBalanced DB  13,10,'  SP after IRET  = $'

MsgHead3    DB  13,10,'--- 3) data processed INSIDE the handler (PP) ---',13,10,'$'
MsgSumLbl   DB  '  SUM(array + AX + BX) = $'
MsgCntLbl   DB  '  array elements       = $'
MsgReadLbl  DB  '  handler really read: AX=$'
MsgEntries  DB  '  entries into PP      = $'

MsgHead4    DB  13,10,'--- 4) TF and IF are cleared by the CPU at the interrupt ---',13,10,'$'
MsgFlBefore DB  '  FLAGS before INT : $'
MsgFlIsr    DB  13,10,'  FLAGS inside PP  : $'
MsgFlAfter  DB  13,10,'  FLAGS after IRET : $'
MsgTfIfNote DB  13,10,'  expected: TF=0 and IF=0 INSIDE the PP, restored after IRET$'

MsgHead5    DB  13,10,'--- 5) CALL vs INT: words added to the stack ---',13,10,'$'
MsgRowNear  DB  '    CALL NEAR -> words = $'
MsgRowNear2 DB  '   (IP only), saved return IP = $'
MsgRowInt   DB  '    INT  0F0h -> words = $'
MsgRowInt2  DB  '   (IP, CS, FLAGS) = $'
MsgRowFar   DB  '    CALL FAR  -> words = $'
MsgRowFar2  DB  '   (IP, CS; FLAGS NOT saved) = $'
MsgConclusion DB '  Conclusion: an interrupt is an INDIRECT far transfer through a',13,10,'  IVT vector, and it saves FLAGS as well - therefore the handler returns',13,10,'  with IRET (3 words), not RET (1..2 words).',13,10,'$'

MsgRestored DB  '  vector 0F0h restored = $'
MsgVecHdr   DB  13,10,'--- 6) allowed / forbidden vectors ---',13,10,'$'
MsgVecList  DB  '    00h..07h  CPU exceptions        - forbidden for an app',13,10
            DB  '    08h..0Fh  hardware IRQ (8259)   - reserved',13,10
            DB  '    10h..1Ah  BIOS                  - reserved',13,10
            DB  '    20h..3Fh  DOS                   - reserved',13,10
            DB  '    40h..6Fh  DOS/BIOS tables       - reserved',13,10
            DB  '    70h..77h  IRQ (second 8259)     - reserved',13,10
            DB  '    78h..B7h  local / user          - ALLOWED',13,10
            DB  '    B8h..FFh  user-definable        - ALLOWED (we used 0F0h)',13,10,'$'
MsgPause    DB  13,10,'>>> Press any key to finish... $'

END START
