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
    mov dl, [si]
    add dl, '0'
    mov ah, 02h
    int 21h

    mov dl, ' '
    mov ah, 02h
    int 21h

    inc si
    loop PRINT_LOOP

    mov ah, 4Ch
    xor al, al
    int 21h

A DB 0,1,2,3,4,5,6,7,8,9
B DB 10 DUP(0)

END START