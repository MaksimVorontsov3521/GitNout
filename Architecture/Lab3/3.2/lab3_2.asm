; lab3_2.asm
; DOS COM-программа
; Копирует массив A -> B через REP MOVSB
; и выводит цифры через INT 21h / AH=02h

.MODEL TINY
.CODE
ORG 100h

START:
    mov ax, cs
    mov ds, ax          ; DS = сегмент кода/данных
    mov es, ax          ; ES = DS, нужно для MOVSB

    cld                 ; DF=0: SI и DI будут увеличиваться
    lea si, A           ; SI -> A
    lea di, B           ; DI -> B
    mov cx, 10          ; 10 байт
    rep movsb           ; копировать CX байт из DS:SI в ES:DI

    lea si, B           ; теперь выводим массив B
    mov cx, 10

PRINT_LOOP:
    mov dl, [si]        ; DL = очередное число 0..9
    add dl, '0'         ; преобразуем цифру в ASCII-символ
    mov ah, 02h         ; функция DOS: вывод символа из DL
    int 21h

    mov dl, ' '         ; пробел между числами
    mov ah, 02h
    int 21h

    inc si
    loop PRINT_LOOP

    mov ah, 4Ch         ; завершение программы
    xor al, al
    int 21h

A DB 0,1,2,3,4,5,6,7,8,9
B DB 10 DUP(0)

END START