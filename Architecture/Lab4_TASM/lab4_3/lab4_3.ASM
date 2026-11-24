DOSSEG
.MODEL TINY
.DATA
    ROWS    EQU 10
    COLS    EQU 10
    Array   DW ROWS*COLS DUP(0)

    MsgTitle1 DB 13,10,'=== Variant 1: prostaya adresaciya [bx] ===',13,10,'$'
    MsgTitle2 DB 13,10,'=== Variant 2: bazovo-indeksnaya [bx+si] ===',13,10,'$'
    MsgTitle3 DB 13,10,'=== Variant 3: strokovaya komanda STOSW ===',13,10,'$'
    MsgNewLn  DB 13,10,'$'
    MsgSpace  DB '  $'

    NumBuf  DB 6 DUP(?),'$'

.CODE
ORG 100h

start:
;Простая косвенно-регистровая адресация [bx]

    mov  dx, OFFSET MsgTitle1
    mov  ah, 9
    int  21h

    lea  di, Array
    mov  cx, ROWS*COLS
    xor  ax, ax
Clear1:
    mov  [di], ax
    add  di, 2
    loop Clear1


    lea  bx, Array
    mov  ax, 1
    mov  si, 0

RowLoop1:
    test si, 1
    jnz  SkipRow1

    mov  cx, COLS
ColLoop1:
    mov  [bx], ax
    add  bx, 2
    inc  ax
    loop ColLoop1
    jmp  NextRow1

SkipRow1:
    add  bx, COLS*2 

NextRow1:
    inc  si
    cmp  si, ROWS
    jl   RowLoop1

    call PrintArray
    call WaitEnter 

;Базово-индексная адресация [bx+si]

    mov  dx, OFFSET MsgTitle2
    mov  ah, 9
    int  21h

    lea  di, Array
    mov  cx, ROWS*COLS
    xor  ax, ax
Clear2:
    mov  [di], ax
    add  di, 2
    loop Clear2

    lea  bx, Array
    mov  ax, 1              
    xor  di, di

RowLoop2:
    test di, 1
    jnz  SkipRow2

    xor  si, si
    mov  cx, COLS
ColLoop2:
    mov  [bx+si], ax
    add  si, 2
    inc  ax
    loop ColLoop2

SkipRow2:
    add  bx, COLS*2
    inc  di
    cmp  di, ROWS
    jl   RowLoop2

    call PrintArray
    call WaitEnter


; Строковая команда STOSW
    mov  dx, OFFSET MsgTitle3
    mov  ah, 9
    int  21h

    ; Обнуляем массив
    lea  di, Array
    mov  cx, ROWS*COLS
    xor  ax, ax
Clear3:
    mov  [di], ax
    add  di, 2
    loop Clear3

    lea  bx, Array 
    mov  ax, 1 
    xor  dx, dx

RowLoop3:
    test dx, 1
    jnz  SkipRow3

    mov  di, bx             
    mov  cx, COLS
FillRow3:
    stosw                   
    inc  ax
    loop FillRow3

SkipRow3:
    add  bx, COLS*2         
    inc  dx
    cmp  dx, ROWS
    jl   RowLoop3

    call PrintArray
    call WaitEnter 

    ; Выход в DOS
    mov  ah, 4Ch
    int  21h

WaitEnter PROC
wait_for_enter:
    mov ah, 00h
    int 16h
    cmp al, 0Dh
    jne wait_for_enter
    ret 
WaitEnter ENDP

PrintArray PROC
    push ax
    push bx
    push cx
    push dx
    push si

    lea  bx, Array
    mov  si, 0              

PrintRow:
    mov  cx, COLS
PrintCol:
    mov  ax, [bx]
    call PrintNum
    mov  dx, OFFSET MsgSpace
    mov  ah, 9
    int  21h
    add  bx, 2
    loop PrintCol
    
    mov  dx, OFFSET MsgNewLn
    mov  ah, 9
    int  21h
    
    inc  si
    cmp  si, ROWS
    jl   PrintRow

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PrintArray ENDP

PrintNum PROC
    push ax
    push bx
    push cx
    push dx
    push si

    lea  si, NumBuf
    add  si, 5
    mov  byte ptr [si], '$'
    dec  si
    mov  cx, 5
    mov  bx, 10
    xor  dx, dx

ConvLoop:
    xor  dx, dx
    div  bx
    add  dl, '0'
    mov  [si], dl
    dec  si
    loop ConvLoop

    inc  si
SkipZeros:
    cmp byte ptr [si], '0'
    jne PrintIt
    cmp byte ptr [si+1], '$'
    je PrintIt
    inc si
    jmp SkipZeros
PrintIt:
    mov  dx, si
    mov  ah, 9
    int  21h

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PrintNum ENDP

END start