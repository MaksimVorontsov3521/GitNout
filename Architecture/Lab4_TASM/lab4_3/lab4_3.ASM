DOSSEG
.MODEL TINY
.DATA
    ; Двумерный массив: 10 строк x 10 столбцов (слова)
    ROWS    EQU 10
    COLS    EQU 10
    Array   DW ROWS*COLS DUP(0)

    ; Сообщения
    MsgTitle1 DB 13,10,'=== Variant 1: prostaya adresaciya [bx] ===',13,10,'$'
    MsgTitle2 DB 13,10,'=== Variant 2: bazovo-indeksnaya [bx+si] ===',13,10,'$'
    MsgTitle3 DB 13,10,'=== Variant 3: strokovaya komanda STOSW ===',13,10,'$'
    MsgNewLn  DB 13,10,'$'
    MsgSpace  DB '  $'

    ; Буфер для вывода числа
    NumBuf  DB 6 DUP(?),'$'

.CODE
ORG 100h

start:
;==============================================================
; ВАРИАНТ 1: Простая косвенно-регистровая адресация [bx]
; Заполняем чётные строки (0,2,4,6,8) числами 1,2,3,...
; Адрес вычисляется вручную: bx = bx + 2 на каждом шаге
;==============================================================
    mov  dx, OFFSET MsgTitle1
    mov  ah, 9
    int  21h

    ; Обнуляем массив
    lea  di, Array
    mov  cx, ROWS*COLS
    xor  ax, ax
Clear1:
    mov  [di], ax
    add  di, 2
    loop Clear1

    ; Заполнение чётных строк
    lea  bx, Array          ; BX = начало массива
    mov  ax, 1              ; значение для записи
    mov  si, 0              ; номер строки

RowLoop1:
    ; Проверяем: строка чётная? (si & 1 == 0)
    test si, 1
    jnz  SkipRow1           ; если нечётная - пропускаем

    ; Заполняем COLS элементов текущей строки
    mov  cx, COLS
ColLoop1:
    mov  [bx], ax           ; запись через [bx]
    add  bx, 2              ; ручной сдвиг указателя
    inc  ax                 ; следующее значение
    loop ColLoop1
    jmp  NextRow1

SkipRow1:
    ; Пропускаем нечётную строку: сдвигаем bx на COLS*2
    add  bx, COLS*2

NextRow1:
    inc  si
    cmp  si, ROWS
    jl   RowLoop1

    ; Вывод массива
    call PrintArray
    call WaitEnter 

;==============================================================
; ВАРИАНТ 2: Базово-индексная адресация [bx+si]
; BX = база (начало массива), SI = индекс (смещение в строке)
; Не нужно вручную двигать указатель на каждой итерации
;==============================================================
    mov  dx, OFFSET MsgTitle2
    mov  ah, 9
    int  21h

    ; Обнуляем массив
    lea  di, Array
    mov  cx, ROWS*COLS
    xor  ax, ax
Clear2:
    mov  [di], ax
    add  di, 2
    loop Clear2

    ; Заполнение чётных строк
    lea  bx, Array          ; BX = база (начало массива)
    mov  ax, 1              ; значение для записи
    xor  di, di             ; DI = номер строки

RowLoop2:
    test di, 1
    jnz  SkipRow2

    ; Заполняем строку через [bx+si]
    xor  si, si             ; SI = 0 (начало строки)
    mov  cx, COLS
ColLoop2:
    mov  [bx+si], ax        ; <-- базово-индексная адресация!
    add  si, 2              ; SI += 2 (следующий столбец)
    inc  ax
    loop ColLoop2
    jmp  NextRow2

SkipRow2:
    ; Ничего не делаем, просто переходим к след. строке

NextRow2:
    inc  di
    ; BX не меняем! Адрес строки = BX + DI*COLS*2
    ; Переход к след. строке: сдвигаем базу
    add  bx, COLS*2
    cmp  di, ROWS
    jl   RowLoop2

    ; Вывод массива
    call PrintArray
    call WaitEnter

;==============================================================
; ВАРИАНТ 3: Строковая команда STOSW
; Максимально компактно: процессор сам инкрементирует DI
;==============================================================
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

    ; Заполнение чётных строк через STOSW
    lea  bx, Array          ; база для вычисления адреса строки
    mov  ax, 1              ; значение
    xor  di, di             ; номер строки

RowLoop3:
    test di, 1
    jnz  SkipRow3

    ; Вычисляем адрес начала чётной строки
    push bx
    mov  cx, di
    mov  ax, COLS*2
    mul  cx                 ; AX = di * COLS * 2
    lea  bx, Array
    add  bx, ax             ; BX = адрес начала строки
    mov  di, bx             ; DI = адрес для STOSW

    ; Заполняем строку через STOSW
    mov  cx, COLS
    mov  ax, di             ; сохраним DI
    sub  ax, bx
    shr  ax, 1
    add  ax, 1             ; восстанавливаем значение

    ; Пересчитываем значение для записи
    ; Значение = номер_строки/2 * COLS + 1
    push di
    mov  ax, di
    sub  ax, bx
    shr  ax, 1             ; AX = 0 для первой строки
    ; Упростим: просто запишем 1..COLS для каждой чётной строки
    pop  di

    mov  cx, COLS
    push cx
    ; Вычислим начальное значение
    mov  ax, bx
    lea  cx, Array
    sub  ax, cx
    shr  ax, 1             ; AX = номер элемента
    inc  ax                 ; значение = номер + 1
    pop  cx

FillRow3:
    stosw                   ; [DI] = AX; DI += 2  <-- строковая команда!
    inc  ax
    loop FillRow3

    pop  bx
    jmp  NextRow3

SkipRow3:
    ; пропускаем
NextRow3:
    inc  di
    cmp  di, ROWS
    jl   RowLoop3

    ; Вывод массива
    call PrintArray
    call WaitEnter 

;==============================================================
; Выход
;==============================================================
    mov  ah, 4Ch
    int  21h

;==============================================================
; WaitEnter: ожидание нажатия Enter
;==============================================================
WaitEnter PROC
wait_for_enter:
    mov ah, 00h         ; Функция 00h прерывания 14h/16h — чтение символа с клавиатуры
    int 16h             ; Вызов прерывания BIOS для работы с клавиатурой
                        ; После вызова: AL = ASCII-код клавиши, AH = скан-код

    cmp al, 0Dh         ; Проверяем, равен ли ASCII-код клавиши коду Enter (0Dh / 13 в дес.)
    jne wait_for_enter  ; Если это НЕ Enter (Not Equal), возвращаемся к началу и ждем снова



WaitEnter ENDP

;==============================================================
; PrintArray: вывод двумерного массива на экран
;==============================================================
PrintArray PROC
    push ax
    push bx
    push cx
    push dx
    push si

    lea  bx, Array
    mov  si, 0              ; номер строки

PrintRow:
    push si
    mov  cx, COLS
PrintCol:
    mov  ax, [bx]
    call PrintNum
    ; пробел
    mov  dx, OFFSET MsgSpace
    mov  ah, 9
    int  21h
    add  bx, 2
    loop PrintCol
    ; новая строка
    mov  dx, OFFSET MsgNewLn
    mov  ah, 9
    int  21h
    pop  si
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

;==============================================================
; PrintNum: вывод числа из AX (беззнаковое, до 65535)
;==============================================================
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
    test ax, ax
    jnz  ConvLoop

    inc  si
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