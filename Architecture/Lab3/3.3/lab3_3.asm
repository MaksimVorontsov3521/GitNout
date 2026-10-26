; lab3_3.asm
; DOS COM-программа
; Копирует массив A -> B строковыми командами.
; Затем выводит числа в десятичном виде.
; Преобразование: деление на 10, остатки складываются в стек,
; потом выводятся в обратном порядке.

.MODEL TINY
.CODE
ORG 100h

START:
    mov ax, cs
    mov ds, ax
    mov es, ax

    cld
    lea si, A
    lea di, B
    mov cx, 10
    rep movsb               ; B = A

    lea si, B
    mov cx, 10

PRINT_LOOP:
    mov al, [si]            ; AL = число 0..255
    call PRINT_U8           ; вывод числа в десятичном виде

    mov dl, ' '
    mov ah, 02h
    int 21h

    inc si
    loop PRINT_LOOP

    mov ah, 4Ch
    xor al, al
    int 21h

; ---------------------------------------------------------
; PRINT_U8
; Вход:  AL = беззнаковое число 0..255
; Выход: число выведено на экран через INT 21h / AH=02h
; Использует деление на 10.
; ---------------------------------------------------------
PRINT_U8 PROC
    push ax
    push bx
    push cx
    push dx

    mov bl, 10
    xor cx, cx              ; CX = количество цифр

CONVERT:
    xor ah, ah              ; AH=0, чтобы делилось именно AX
    div bl                  ; AL = AX / 10, AH = остаток
    push ax                 ; сохраняем остаток и частное
    inc cx
    test al, al
    jnz CONVERT             ; пока частное != 0

OUTPUT:
    pop ax                  ; AH = очередная цифра
    mov dl, ah
    add dl, '0'             ; цифра -> ASCII
    mov ah, 02h
    int 21h
    loop OUTPUT

    pop dx
    pop cx
    pop bx
    pop ax
    ret
PRINT_U8 ENDP

A DB 0,7,9,12,34,56,99,100,123,255
B DB 10 DUP(0)

END START