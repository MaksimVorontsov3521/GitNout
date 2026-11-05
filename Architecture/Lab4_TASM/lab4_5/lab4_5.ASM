;==============================================================
; Сборка:
;   COM (TINY) :  tasm /dTINY lab4_t5.asm  &  tlink /t lab4_t5.obj
;   EXE (SMALL):  tasm lab4_t5.asm         &  tlink lab4_t5.obj
;==============================================================

IFDEF TINY
    .MODEL TINY
ELSE
    .MODEL SMALL
    .STACK 200h
ENDIF

.CODE
IFDEF TINY
    ORG 100h                ; COM-файл: код начинается со 100h
ENDIF

START:
IFNDEF TINY
    mov  ax, @DATA          ; EXE: DS должен указать на DGROUP
    mov  ds, ax
ENDIF

;--------------------------------------------------------------
; Чтение данных через РАЗНЫЕ сегментные регистры
;--------------------------------------------------------------
    lea  bx, DataW          ; BX = смещение данных
    mov  ax, [bx]           ; чтение через DS (умолчание)
    mov  ValDS, ax
    mov  ax, cs:[bx]        ; ПРЕФИКС 2Eh: чтение из сегмента КОДА
    mov  ValCS, ax

;--------------------------------------------------------------
; Вывод результатов
;--------------------------------------------------------------
    lea  dx, MsgTitle
    mov  ah, 9
    int  21h

    lea  dx, MsgDS
    mov  ah, 9
    int  21h
    mov  ax, ValDS
    call PrintHex16

    lea  dx, MsgCR
    mov  ah, 9
    int  21h

    lea  dx, MsgCS
    mov  ah, 9
    int  21h
    mov  ax, ValCS
    call PrintHex16

    lea  dx, MsgCR
    mov  ah, 9
    int  21h

    ; Значения сегментных регистров
    lea  dx, MsgSeg1
    mov  ah, 9
    int  21h
    mov  ax, ds
    call PrintHex16
    lea  dx, MsgSeg2
    mov  ah, 9
    int  21h
    mov  ax, cs
    call PrintHex16
    lea  dx, MsgCR
    mov  ah, 9
    int  21h

;--------------------------------------------------------------
; Вывод: одинаковые или разные данные прочитаны
;--------------------------------------------------------------
    mov  ax, ValDS
    cmp  ax, ValCS
    je   Same
    lea  dx, MsgDiff
    jmp  Show
Same:
    lea  dx, MsgSame
Show:
    mov  ah, 9
    int  21h

    call WaitEnter
    mov  ah, 4Ch
    int  21h

;==============================================================
; PrintHex16: вывод AX в HEX (4 цифры)
;==============================================================
PrintHex16 PROC
    push ax
    push bx
    push cx
    push dx
    mov  cx, 4
ph1:
    rol  ax, 4
    push ax
    mov  dl, al
    and  dl, 0Fh
    add  dl, '0'
    cmp  dl, '9'
    jbe  ph2
    add  dl, 7
ph2:
    mov  ah, 2
    int  21h
    pop  ax
    loop ph1
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PrintHex16 ENDP

;==============================================================
; WaitEnter: пауза до нажатия Enter
;==============================================================
WaitEnter PROC
    push ax
    lea  dx, MsgPause
    mov  ah, 9
    int  21h
we1:
    mov  ah, 0
    int  16h
    cmp  al, 0Dh
    jne  we1
    pop  ax
    ret
WaitEnter ENDP

;==============================================================
; ДАННЫЕ (размещены ПОСЛЕ кода - обязательно для COM)
;==============================================================
.DATA
DataW   DW 1111h, 2222h, 3333h, 4444h
ValDS   DW ?
ValCS   DW ?

MsgTitle  DB 13,10,'=== Lab4 task5: read via DS: and CS: ===',13,10,'$'
MsgDS     DB 'DS:[bx] = $'
MsgCS     DB 'CS:[bx] = $'
MsgSeg1   DB 13,10,'DS = $'
MsgSeg2   DB '   CS = $'
MsgCR     DB 13,10,'$'
MsgSame   DB 13,10,'RESULT: SAME data     -> CS = DS  (model TINY, COM)',13,10,'$'
MsgDiff   DB 13,10,'RESULT: DIFFERENT data-> CS <> DS (model SMALL, EXE)',13,10,'$'
MsgPause  DB 13,10,'>>> Press ENTER... $'

END START