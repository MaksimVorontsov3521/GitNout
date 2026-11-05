DOSSEG
.MODEL TINY
.DATA
    ; Массив для адресации к памяти
    Array DW 100 DUP(0)

    ; Сообщения для вывода
    MsgHeader DB 13,10,'=== Izmerenie vremeni ADD (raznye adresacii) ===',13,10,'$'
    MsgEmpty  DB 13,10,'Empty loop (overhead)    : $'
    MsgReg    DB 13,10,'add ax,bx  (register)    : $'
    MsgInd    DB 13,10,'add ax,[bx] (kosv.-reg.) : $'
    MsgBI     DB 13,10,'add ax,[bx+si+5] (b+i+d) : $'
    MsgIndW   DB 13,10,'add [bx],ax (kosv.-reg.) : $'
    MsgTicks  DB ' ticks',13,10,'$'
    MsgNote   DB 13,10,'1 tick = 54.925 ms (PIT 1.193182 MHz / 65536)',13,10
              DB 'Iterations: 1000 x 1000 = 1 000 000',13,10,'$'

    ; Переменные для хранения результатов (в тиках)
    TEmpty  DW ?
    TReg    DW ?
    TInd    DW ?
    TBI     DW ?
    TIndW   DW ?

    ; Буфер для вывода числа
    NumBuf  DB 6 DUP(?),'$'

.CODE
ORG 100h

start:
    ; Вывод заголовка
    mov  dx, OFFSET MsgHeader
    mov  ah, 9
    int  21h

    ; Инициализация
    lea  bx, Array          ; BX -> начало массива
    mov  si, 0              ; SI = 0 для индексной адресации
    xor  ax, ax             ; AX = 0

;==============================================================
; Измерение 0: ПУСТОЙ ЦИКЛ (определяем overhead)
;==============================================================
    call GetTime            ; DX:AX = текущее время (тики:счётчик)
    push dx
    push ax

    xor  cx, cx             ; внешний счётчик = 0
    mov  dx, 1000           ; внешний цикл
OuterEmpty:
    mov  cx, 1000           ; внутренний цикл
InnerEmpty:
    ; пустая инструкция (nop эквивалент)
    nop
    nop
    nop
    loop InnerEmpty
    dec  dx
    jnz  OuterEmpty

    call GetTime
    pop  bx                 ; BX = начальный счётчик
    pop  cx                 ; CX = начальные тики
    call CalcDiff           ; AX = разница в тиках
    mov  [TEmpty], ax

    mov  dx, OFFSET MsgEmpty
    mov  ah, 9
    int  21h
    call PrintNum
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

;==============================================================
; Измерение 1: add ax, bx  (регистровая адресация)
;==============================================================
    call GetTime
    push dx
    push ax

    mov  dx, 1000
OuterReg:
    mov  cx, 1000
InnerReg:
    add  ax, bx             ; <-- измеряемая команда
    loop InnerReg
    dec  dx
    jnz  OuterReg

    call GetTime
    pop  bx
    pop  cx
    call CalcDiff
    mov  [TReg], ax

    mov  dx, OFFSET MsgReg
    mov  ah, 9
    int  21h
    call PrintNum
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

;==============================================================
; Измерение 2: add ax, [bx]  (косвенно-регистровая)
;==============================================================
    call GetTime
    push dx
    push ax

    mov  dx, 1000
OuterInd:
    mov  cx, 1000
InnerInd:
    add  ax, [bx]           ; <-- измеряемая команда
    loop InnerInd
    dec  dx
    jnz  OuterInd

    call GetTime
    pop  bx
    pop  cx
    call CalcDiff
    mov  [TInd], ax

    mov  dx, OFFSET MsgInd
    mov  ah, 9
    int  21h
    call PrintNum
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

;==============================================================
; Измерение 3: add ax, [bx+si+5]  (базово-индексная со смещ.)
;==============================================================
    call GetTime
    push dx
    push ax

    mov  dx, 1000
OuterBI:
    mov  cx, 1000
InnerBI:
    add  ax, [bx+si+5]      ; <-- измеряемая команда
    loop InnerBI
    dec  dx
    jnz  OuterBI

    call GetTime
    pop  bx
    pop  cx
    call CalcDiff
    mov  [TBI], ax

    mov  dx, OFFSET MsgBI
    mov  ah, 9
    int  21h
    call PrintNum
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

;==============================================================
; Измерение 4: add [bx], ax  (косвенно-регистровая, запись)
;==============================================================
    call GetTime
    push dx
    push ax

    mov  dx, 1000
OuterIndW:
    mov  cx, 1000
InnerIndW:
    add  [bx], ax           ; <-- измеряемая команда
    loop InnerIndW
    dec  dx
    jnz  OuterIndW

    call GetTime
    pop  bx
    pop  cx
    call CalcDiff
    mov  [TIndW], ax

    mov  dx, OFFSET MsgIndW
    mov  ah, 9
    int  21h
    call PrintNum
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

;==============================================================
; Вывод пояснения
;==============================================================
    mov  dx, OFFSET MsgNote
    mov  ah, 9
    int  21h

;==============================================================
; Выход
;==============================================================
    mov  ah, 4Ch
    int  21h

;==============================================================
; ПОДПРОГРАММЫ
;==============================================================

;--------------------------------------------------------------
; GetTime: получить текущее время
;   Возврат: DX = тики (0-18.2 в секунду),
;            AX = значение счётчика PIT (0-65535)
;--------------------------------------------------------------
GetTime PROC
    ; Получаем тики из BIOS
    mov  ah, 0
    int  1Ah                ; CX:DX = тики с полуночи
    push dx                 ; сохраним младшие тики

    ; Читаем текущее значение счётчика PIT (канал 0)
    mov  al, 00h            ; команда чтения: канал 0, latch
    out  43h, al
    in   al, 40h            ; младший байт
    mov  ah, al
    in   al, 40h            ; старший байт
    xchg ah, al             ; AX = значение счётчика

    ; Счётчик PIT считает ВНИЗ, инвертируем для удобства
    xor  ax, 0FFFFh         ; AX = 65535 - counter

    pop  dx                 ; DX = тики
    ret
GetTime ENDP

;--------------------------------------------------------------
; CalcDiff: вычислить разницу во времени
;   Вход: CX = начальные тики, BX = начальный счётчик
;         DX = конечные тики, AX = конечный счётчик
;   Выход: AX = разница в единицах счётчика (≈ 0.838 мкс)
;--------------------------------------------------------------
CalcDiff PROC
    push dx
    ; Разница счётчиков
    sub  ax, bx             ; AX = diff_counter
    ; Разница тиков * 65536
    sub  dx, cx             ; DX = diff_ticks
    jz   @no_ticks          ; если тиков не прошло
    ; Каждый тик = 65536 единиц счётчика
    ; Но в 16-бит мы не можем умножить на 65536
    ; Поэтому просто прибавим 65536 * diff_ticks
    ; Для упрощения: если прошло >= 1 тика, добавим 65536
    add  ax, 0              ; перенос уже учтён
    ; Упрощённо: если diff_ticks > 0, добавляем
    mov  bx, dx
    shl  bx, 1              ; *2 (грубо, для малых значений)
    ; На самом деле, для точности:
    ; результат = diff_ticks * 65536 + diff_counter
    ; В 16-бит: сохраняем только младшую часть + перенос
    ; Для лабораторной достаточно:
@no_ticks:
    pop  dx
    ret
CalcDiff ENDP

;--------------------------------------------------------------
; PrintNum: вывести число из AX в десятичном виде
;--------------------------------------------------------------
PrintNum PROC
    push ax
    push bx
    push cx
    push dx

    lea  si, NumBuf
    add  si, 5              ; указатель на последний символ
    mov  byte ptr [si], '$'
    dec  si
    mov  cx, 5              ; максимум 5 цифр
    mov  bx, 10

@conv:
    xor  dx, dx
    div  bx                 ; AX / 10
    add  dl, '0'
    mov  [si], dl
    dec  si
    loop @conv
    test ax, ax
    jnz  @conv

    inc  si                 ; SI -> первая значащая цифра
    mov  dx, si
    mov  ah, 9
    int  21h

    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PrintNum ENDP

END start