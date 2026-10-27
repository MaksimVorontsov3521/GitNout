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
    rep movsb

    lea si, B
    mov cx, 10

PRINT_LOOP:
    mov al, [si]
    call PRINT_U8

    mov dl, ' '
    mov ah, 02h
    int 21h

    inc si
    loop PRINT_LOOP

    mov ah, 4Ch
    xor al, al
    int 21h

PRINT_U8 PROC
    push ax
    push bx
    push cx
    push dx

    mov bl, 10
    xor cx, cx

CONVERT:
    xor ah, ah
    div bl
    push ax
    inc cx
    test al, al
    jnz CONVERT

OUTPUT:
    pop ax
    mov dl, ah
    add dl, '0'
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