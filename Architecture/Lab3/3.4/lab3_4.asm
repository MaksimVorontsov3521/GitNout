; lab3_4.asm
; Задание 4*: ввод, заполнение массива и вывод чисел
; в формате с плавающей запятой.

.286
.287
.MODEL TINY
.CODE
ORG 100h

START:
    mov ax, cs
    mov ds, ax
    mov es, ax

    lea dx, MSG_PROMPT
    mov ah, 09h
    int 21h

    lea di, ARR
    mov bp, N

INPUT_LOOP:
    lea dx, INBUF
    mov ah, 0Ah
    int 21h

    lea dx, CRLF
    mov ah, 09h
    int 21h

    lea si, INBUF+2
    mov cl, [INBUF+1]
    xor ch, ch
    cmp cx, 0
    je EMPTY_STR
    call PARSE_FLOAT
    jmp NEXT_LABEL

EMPTY_STR:
    mov word ptr [di], 0
    mov word ptr [di+2], 0

NEXT_LABEL:
    add di, 4
    dec bp
    jnz INPUT_LOOP

    lea dx, MSG_RESULT
    mov ah, 09h
    int 21h

    lea si, ARR
    mov bp, N

OUTPUT_LOOP:
    call PRINT_FLOAT
    lea dx, CRLF
    mov ah, 09h
    int 21h
    add si, 4
    dec bp
    jnz OUTPUT_LOOP

    mov ah, 4Ch
    xor al, al
    int 21h

; =========================================================
PARSE_FLOAT PROC
    pusha
    mov byte ptr [NEG_FLAG], 0
    mov word ptr [INT_PART], 0
    mov word ptr [INT_PART+2], 0
    mov word ptr [FRAC_PART], 0
    mov word ptr [FRAC_PART+2], 0
    mov word ptr [FRAC_DIV], 1
    mov word ptr [FRAC_DIV+2], 0
    jmp SKIP_SPACES_START

SKIP_SPACES_LOOP:
    inc si
    dec cx

SKIP_SPACES_START:
    cmp cx, 0
    jne SPACES_HAS_CHARS    ; ИСПРАВЛЕНИЕ СТРОКИ 87: инвертируем условие
    jmp PARSE_ERROR         ; и делаем безусловный переход

SPACES_HAS_CHARS:
    mov al, [si]
    cmp al, ' '
    je SKIP_SPACES_LOOP
    cmp al, '-'
    jne CHECK_PLUS
    mov byte ptr [NEG_FLAG], 1
    inc si
    dec cx
    jmp INT_LOOP_START

CHECK_PLUS:
    cmp al, '+'
    jne INT_LOOP_START
    inc si
    dec cx

; ----- целая часть -----
INT_LOOP_START:
    cmp cx, 0
    jne INT_HAS_CHARS
    jmp DONE_PARSE

INT_HAS_CHARS:
    mov al, [si]
    cmp al, '.'
    je FRAC_START_LABEL
    cmp al, '0'
    jae INT_CHK_9
    jmp PARSE_ERROR

INT_CHK_9:
    cmp al, '9'
    jbe INT_DIGIT_OK
    jmp PARSE_ERROR

INT_DIGIT_OK:
    mov ax, word ptr [INT_PART]
    mov dx, word ptr [INT_PART+2]
    mov bx, 10
    call MUL32_10
    
    mov bx, [si]
    and bx, 0FFh
    sub bx, '0'
    call ADD32_BX
    
    mov word ptr [INT_PART], ax
    mov word ptr [INT_PART+2], dx
    inc si
    dec cx
    jmp INT_LOOP_START

FRAC_START_LABEL:
    inc si
    dec cx

; ----- дробная часть -----
FRAC_LOOP_START:
    cmp cx, 0
    jne FRAC_HAS_CHARS
    jmp DONE_PARSE

FRAC_HAS_CHARS:
    mov al, [si]
    cmp al, '0'
    jae FRAC_CHK_9
    jmp PARSE_ERROR

FRAC_CHK_9:
    cmp al, '9'
    jbe FRAC_DIGIT_OK
    jmp PARSE_ERROR

FRAC_DIGIT_OK:
    mov ax, word ptr [FRAC_PART]
    mov dx, word ptr [FRAC_PART+2]
    mov bx, 10
    call MUL32_10
    
    mov bx, [si]
    and bx, 0FFh
    sub bx, '0'
    call ADD32_BX
    
    mov word ptr [FRAC_PART], ax
    mov word ptr [FRAC_PART+2], dx
    
    mov ax, word ptr [FRAC_DIV]
    mov dx, word ptr [FRAC_DIV+2]
    mov bx, 10
    call MUL32_10
    mov word ptr [FRAC_DIV], ax
    mov word ptr [FRAC_DIV+2], dx
    
    inc si
    dec cx
    jmp FRAC_LOOP_START

DONE_PARSE:
    fild dword ptr [INT_PART]
    fild dword ptr [FRAC_PART]
    fild dword ptr [FRAC_DIV]
    fdivp st(1), st
    faddp st(1), st
    cmp byte ptr [NEG_FLAG], 0
    je STORE_FLOAT
    fchs

STORE_FLOAT:
    fstp dword ptr [di]
    jmp PARSE_DONE

PARSE_ERROR:
    mov word ptr [di], 0
    mov word ptr [di+2], 0

PARSE_DONE:
    popa
    ret
PARSE_FLOAT ENDP

; =========================================================
MUL32_10 PROC
    push bx
    push cx
    mov cx, ax
    mov bx, dx
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    add ax, cx
    adc dx, bx
    shl ax, 1
    rcl dx, 1
    pop cx
    pop bx
    ret
MUL32_10 ENDP

; =========================================================
ADD32_BX PROC
    add ax, bx
    adc dx, 0
    ret
ADD32_BX ENDP

; =========================================================
PRINT_FLOAT PROC
    pusha
    mov ax, word ptr [si+2]
    test ax, 8000h
    jz PRINT_POSITIVE
    mov dl, '-'
    mov ah, 02h
    int 21h

PRINT_POSITIVE:
    fld dword ptr [si]
    fabs
    fld dword ptr [SCALE]
    fmulp st(1), st
    fistp dword ptr [SCALED]
    mov ax, word ptr [SCALED]
    mov dx, word ptr [SCALED+2]
    call DWORD_TO_DEC
    mov cx, word ptr [DECLEN]
    cmp cx, 4
    jbe NO_INT_PART
    jmp HAS_INT_PART

NO_INT_PART:
    mov dl, '0'
    mov ah, 02h
    int 21h
    mov dl, '.'
    mov ah, 02h
    int 21h
    mov bx, 4
    sub bx, cx
    jz PRINT_FRAC_ONLY

PRINT_ZEROS:
    mov dl, '0'
    mov ah, 02h
    int 21h
    dec bx
    jnz PRINT_ZEROS

PRINT_FRAC_ONLY:
    mov si, word ptr [DECPTR]
    mov cx, word ptr [DECLEN]

PRINT_ALL_DIGITS:
    mov dl, [si]
    mov ah, 02h
    int 21h
    inc si
    loop PRINT_ALL_DIGITS
    jmp PRINT_END

HAS_INT_PART:
    mov bx, cx
    sub bx, 4
    mov si, word ptr [DECPTR]
    mov cx, bx

PRINT_INT_DIGITS:
    mov dl, [si]
    mov ah, 02h
    int 21h
    inc si
    loop PRINT_INT_DIGITS
    
    mov dl, '.'
    mov ah, 02h
    int 21h
    
    mov cx, 4
    mov si, word ptr [DECPTR]
    add si, bx

PRINT_FRAC_DIGITS:
    mov dl, [si]
    mov ah, 02h
    int 21h
    inc si
    loop PRINT_FRAC_DIGITS

PRINT_END:
    popa
    ret
PRINT_FLOAT ENDP

; =========================================================
; Исправлено корректное деление 32-битного числа DX:AX на 10
; =========================================================
DWORD_TO_DEC PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    lea di, DECBUF+10
    mov byte ptr [di], 0
    mov bx, 10
    xor cx, cx

CONV_LOOP:
    mov si, ax      ; SI = младшее слово
    mov ax, dx      ; AX = старшее слово
    xor dx, dx      ; DX = 0
    div bx          ; AX = старшее / 10, DX = остаток
    push ax         ; сохраняем частное старшего слова
    mov ax, si      ; AX = младшее слово
    div bx          ; AX = младшее / 10, DX = итоговый остаток (0..9)
    pop si          ; SI = частное старшего слова
    
    ; Теперь DX = остаток, AX = младшее частное, SI = старшее частное
    add dl, '0'
    dec di
    mov [di], dl
    inc cx
    
    mov dx, si      ; восстанавливаем DX для следующей итерации
    or ax, ax
    jnz CONV_LOOP
    or dx, dx
    jnz CONV_LOOP
    
    mov word ptr [DECPTR], di
    mov word ptr [DECLEN], cx
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DWORD_TO_DEC ENDP

; =========================================================
N           equ 5
MSG_PROMPT  DB 'Enter 5 floats (one per line):',13,10,'$'
MSG_RESULT  DB 13,10,'You entered:',13,10,'$'
CRLF        DB 13,10,'$'
INBUF       DB 32,0,32 DUP(0)
ARR         DD N DUP(0)
SCALE       DD 10000.0
SCALED      DD 0
DECBUF      DB 12 DUP(0)
DECPTR      DW 0
DECLEN      DW 0
INT_PART    DD 0
FRAC_PART   DD 0
FRAC_DIV    DD 1
NEG_FLAG    DB 0

END START