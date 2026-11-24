;==============================================================
;  Лабораторная работа 7, ШАГ 1  (A7.txt, строки 26-29)
;
;  "1. Напишите программу на Асс (см пример): Введите в диалоге три
;   числа, загрузите их в регистры FPU, просуммируйте, выведите
;   результат. Проследите работу FPU в TD. Как используются регистры
;   FPU ? Как сказывается ограниченность разрядной сетки мантиссы."
;
;  Чистый ассемблер (TASM 4.1, .286 + .MODEL TINY -> .COM).
;  Разрядная сетка мантиссы проверяется ДВУМЯ способами:
;     - побитовый дамп 80-битного ST(0) (видно хвост и потерю разрядов);
;     - разность (a+b)-a маленьким числом, которое удобно печатать.
;  Ввод: клавиатура (int 21h/0Ah); под /dNOWAIT та же программа
;  читает строку из d:\in.txt - парсер общий, код не дублируется.
;
;  Сборка:  tasm /zi lab7_1.asm  +  tlink /v /t lab7_1   (задача VS Code)
;  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab7_1
;==============================================================

.286                    ; нужны SHR/SHL по CL, MUL CX, XLAT, индексация [bx+const]
.MODEL TINY

.CODE
ORG 100h                        ; COM: PSP занимает 00h..0FFh

START:
       ; в TINY/COM DOS загружает CS = DS = SS одинаково, assume не нужен
       finit
       lea  dx, MsgTitle
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

       ;----------------------------------------------------------
       ; 1. ВВОД ТРЁХ ЧИСЕЛ
       ;    интерактивно - клавиатура;  под NOWAIT - файл d:\in.txt
       ;----------------------------------------------------------
       lea  dx, MsgHead1
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

       ;  Разбор ОДИН И ТОТ ЖЕ для клавиатуры и для файла: строка ложится в
       ;  Line+2, а EndPtr замыкает цикл пропуска пробелов (без терминатора
       ;  ParseNum уходит за буфер и зацикливается - проверено прогоном).
IFDEF NOWAIT            ; /dNOWAIT: автономный прогон без клавиатуры
       lea  dx, FName
       mov  ax, 3D00h            ; AH=3Dh, AL=0 - чтение
       int  21h
       jc   L_useDefault
       mov  bx, ax
       lea  dx, Line + 2
       mov  ah, 3Fh
       mov  cx, 80
       int  21h
       mov  ah, 3Eh              ; закрыть файл
       int  21h
       mov  byte ptr Line, 80
       mov  byte ptr Line + 1, al
       jmp  L_close_line
L_useDefault:                   ; файла нет - встроенная демо-строка
       lea  si, DefLine
       lea  di, Line + 2
       mov  cx, DefLen
       rep movsb
       mov  byte ptr Line, 80
       mov  byte ptr Line + 1, DefLen
ELSE
       lea  dx, MsgPrompt
       mov  ah, 09h
       int  21h
       mov  byte ptr Line, 80
       mov  byte ptr Line + 1, 0
       lea  dx, Line
       mov  ah, 0Ah
       int  21h
ENDIF

L_close_line:
       lea  si, Line + 2
       mov  al, Line + 1
       mov  ah, 0
       add  si, ax
       mov  byte ptr [si], 0     ; терминатор строки
       mov  EndPtr, si
       lea  si, Line + 2
       finit
       call ParseNum
       fstp tbyte ptr NumTA          ; каноническое значение разбора (80 бит)
       fld  tbyte ptr NumTA
       fstp dword ptr NumA           ; та же величина в одинарной точности
       mov  bx, offset NumA
       call DumpParsed
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call ParseNum
       fstp tbyte ptr NumTB
       fld  tbyte ptr NumTB
       fstp dword ptr NumB
       mov  bx, offset NumB
       call DumpParsed
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call ParseNum
       fstp tbyte ptr NumTC
       fld  tbyte ptr NumTC
       fstp dword ptr NumC
       mov  bx, offset NumC
       call DumpParsed
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

       lea  dx, MsgBlank
       mov  ah, 09h
       int  21h
       ;----------------------------------------------------------
       ; 2. КАК ИСПОЛЬЗУЮТСЯ РЕГИСТРЫ FPU: стек 8 x 80 бит
       ;    три FLD -> три вершины, TOP уменьшается на 3
       ;----------------------------------------------------------
       lea  dx, MsgHead2
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       finit
       fld  dword ptr NumA
       fld  dword ptr NumB
       fld  dword ptr NumC
       fsave FBUF                ; заголовок 14 байт + 8 x 10 байт
       mov  ax, word ptr FBUF
       mov  CWv, ax
       mov  ax, word ptr FBUF + 2
       mov  SWv, ax
       mov  ax, word ptr FBUF + 4
       mov  TAGv, ax
       lea  dx, MsgCW
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgSW
       mov  ah, 09h
       int  21h
       mov  ax, SWv
       call Phex16
       call PswTop
       lea  dx, MsgTAG
       mov  ah, 09h
       int  21h
       mov  ax, TAGv
       call Phex16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call Ptag

       lea  dx, MsgST0
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgST1
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 24
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgST2
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 34
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgStackNote
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgStackNote2
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgStackNote3
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

       lea  dx, MsgBlank
       mov  ah, 09h
       int  21h
       ;----------------------------------------------------------
       ; 3. СУММИРОВАНИЕ И ВЫВОД РЕЗУЛЬТАТА
       ;    FADDP = сложить ST(1) и ST(0) с освобождением вершины
       ;----------------------------------------------------------
       lea  dx, MsgHead3
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       finit
       fld  dword ptr NumA
       fld  dword ptr NumB
       faddp                     ; ST(1)+ST(0) -> ST(0), pop
       fstp dword ptr Part
       finit
       fld  dword ptr Part
       fld  dword ptr NumC
       faddp
       fstp dword ptr Summ

       lea  dx, MsgPart
       mov  ah, 09h
       int  21h
       fld  dword ptr Part
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgRaw
       mov  ah, 09h
       int  21h
       finit
       fld  dword ptr Part
       fsave FBUF
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

       lea  dx, MsgSum
       mov  ah, 09h
       int  21h
       fld  dword ptr Summ
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgRaw
       mov  ah, 09h
       int  21h
       finit
       fld  dword ptr Summ
       fsave FBUF
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call PswFlags

       lea  dx, MsgBlank
       mov  ah, 09h
       int  21h
       ;----------------------------------------------------------
       ; 4. ОГРАНИЧЕННОСТЬ РАЗРЯДНОЙ СЕТКИ МАНТИССЫ
       ;    Precision Control = биты 9..8 слова управления:
       ;      00 -> 24 бита, 10 -> 53, 11 -> 64 (после FINIT стоит 11)
       ;    1e8 + 1: при 24 битах единица НЕ влезает в мантиссу
       ;----------------------------------------------------------
       lea  dx, MsgHead4
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       mov  ax, 007Fh            ; PC=24 бита, маски все сняты? НЕТ:
       mov  word ptr CWtmp, ax   ; 007Fh = маски 0..5 включены, PC=00
       fldcw CWtmp
       fstcw CWv
       lea  dx, MsgPC24
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call PcFromCw
       call MantTest

       mov  ax, 037Fh            ; PC=64 бита (состояние после FINIT)
       mov  word ptr CWtmp, ax
       fldcw CWtmp
       fstcw CWv
       lea  dx, MsgPC64
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       call PcFromCw
       call MantTest

       lea  dx, MsgBlank
       mov  ah, 09h
       int  21h
       ;----------------------------------------------------------
       ; 5. ОДИН И ТОТ ЖЕ КОЭФФИЦИЕНТ В ТЁХ ФОРМАТАХ (КВ/ДВ/ВВ)
       ;    A7.txt, строки 50-66: 32 / 64 / 80 бит, неявный бит
       ;----------------------------------------------------------
       lea  dx, MsgHead5
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       ; Все три ширины - ОДНО и ТО ЖЕ 80-битное значение разбора (NumTA):
       ; сохраняется как КВ (4 байта), как ДВ (8 байтов) и как ВВ (10 байт
       ; регистра). Тогда видно, кто сколько точных десятичных цифр держит
       ; (A7.txt, строки 50-66), и ни одна ширина не наследует ошибку другой.
       fld  tbyte ptr NumTA
       fstp dword ptr KVs
       fld  tbyte ptr NumTA
       fstp qword ptr DblA
       fld  tbyte ptr NumTA
       fsave FBUF
       lea  dx, MsgKV
       mov  ah, 09h
       int  21h
       lea  si, KVs
       mov  cx, 4
       call Pbytes
       lea  dx, MsgDV
       mov  ah, 09h
       int  21h
       lea  si, DblA
       mov  cx, 8
       call Pbytes
       lea  dx, MsgVV
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 14
       mov  cx, 10
       call Pbytes
       lea  dx, MsgKVval
       mov  ah, 09h
       int  21h
       fld  dword ptr KVs
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgDVval
       mov  ah, 09h
       int  21h
       fld  qword ptr DblA
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgVVval
       mov  ah, 09h
       int  21h
       fld  tbyte ptr FBUF + 14
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgFormatsNote
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       lea  dx, MsgFormatsNote2
       mov  ah, 09h
       int  21h
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h

IFNDEF NOWAIT            ; /dNOWAIT: прогон без ожидания клавиши
       lea  dx, MsgPause
       mov  ah, 09h
       int  21h
       mov  ah, 00h
       int  16h
ENDIF
       mov  ax, 4C00h
       int  21h

;==============================================================
;  РАЗБОР ВВЕДЁННОГО ЧИСЛА: знак, целая часть, дробная, масштаб
;  Значение СОБИРАЕТСЯ КОМАНДАМИ FPU (стековые формы FADDP/FDIVP),
;  поэтому этот же код и демонстрирует регистровую модель.
;  Входе: SI -> текущий символ строки. Выход: ST(0) = число,
;  SI за числом; SignFlag/IntP/Frac/Scale заполнены.
;==============================================================
ParseNum PROC
       mov  word ptr SignFlag, 0
       mov  word ptr IntP, 0
       mov  word ptr Frac, 0
       mov  word ptr Scale, 1
L_pn_skip:
       cmp  si, EndPtr
       jb   L_pn_go                    ; короткий переход: ещё есть символы
       jmp  near ptr L_pn_build        ; строка кончилась - собирать что есть
L_pn_go:
       mov  al, [si]
       cmp  al, 20h
       je   L_pn_adv
       cmp  al, 09h
       je   L_pn_adv
       cmp  al, 0Dh
       je   L_pn_adv
       cmp  al, 0Ah
       je   L_pn_adv
       jmp  L_pn_sign
L_pn_adv:
       inc  si
       jmp  L_pn_skip
L_pn_sign:
       cmp  al, 2Dh                    ; "-"
       jne  L_pn_plus
       mov  word ptr SignFlag, 1
       inc  si
       jmp  L_pn_int
L_pn_plus:
       cmp  al, 2Bh                    ; "+"
       jne  L_pn_int
       inc  si
L_pn_int:
       cmp  si, EndPtr
       jb   L_pn_go_i
       jmp  near ptr L_pn_dot
L_pn_go_i:
       mov  al, [si]
       cmp  al, 30h
       jb   L_pn_dot
       cmp  al, 39h
       ja   L_pn_dot
       and  al, 0Fh
       mov  bx, ax
       mov  bh, 0
       mov  ax, word ptr IntP
       mov  cx, 10
       mul  cx
       add  ax, bx
       mov  word ptr IntP, ax
       inc  si
       jmp  L_pn_int
L_pn_dot:
       cmp  al, 2Eh                    ; "."
       jne  L_pn_build
       inc  si
L_pn_frac:
       cmp  si, EndPtr
       jb   L_pn_go_f
       jmp  near ptr L_pn_build
L_pn_go_f:
       mov  al, [si]
       cmp  al, 30h
       jb   L_pn_build
       cmp  al, 39h
       ja   L_pn_build
       and  al, 0Fh
       mov  bx, ax
       mov  bh, 0
       mov  ax, word ptr Frac
       cmp  ax, 6553
       ja   L_pn_fskip                 ; не переполнять 16 бит
       mov  cx, 10
       mul  cx
       add  ax, bx
       mov  word ptr Frac, ax
       mov  ax, word ptr Scale
       cmp  ax, 6553
       ja   L_pn_fskip
       mov  cx, 10
       mul  cx
       mov  word ptr Scale, ax
L_pn_fskip:
       inc  si
       jmp  L_pn_frac
L_pn_build:
       fild word ptr Frac              ; ST(0) = дробная часть
       fild word ptr Scale             ; ST(0) = 10^n, ST(1) = дробная
       fdivp                           ; ST(1)/ST(0) -> ST(0), pop
       fild word ptr IntP              ; ST(0) = целая, ST(1) = дробная/масштаб
       faddp                           ; ST(1)+ST(0) -> ST(0), pop
       cmp  word ptr SignFlag, 0
       je   L_pn_ret
       fchs                            ; знак числа
L_pn_ret:
       ret
ParseNum ENDP

;==============================================================
;  Печать разбора + значения. Входе: BX = адрес dword-числа
;==============================================================
DumpParsed PROC
       push ax bx cx dx si
       lea  dx, MsgParsed
       mov  ah, 09h
       int  21h
       mov  ax, SignFlag
       call Pdec16
       lea  dx, MsgIntLbl
       mov  ah, 09h
       int  21h
       mov  ax, IntP
       call Pdec16
       lea  dx, MsgFracLbl
       mov  ah, 09h
       int  21h
       mov  ax, Frac
       call Pdec16
       lea  dx, MsgScaleLbl
       mov  ah, 09h
       int  21h
       mov  ax, Scale
       call Pdec16
       lea  dx, MsgValLbl
       mov  ah, 09h
       int  21h
       fld  dword ptr [bx]
       call Pfloat
       pop  si dx cx bx ax
       ret
DumpParsed ENDP

;==============================================================
;  Печать 80-битного числа: 5 слов (порядок/знак, мантисса 4 слова)
;  Входе: SI = адрес 10 байт
;==============================================================
Pst PROC
       push ax bx cx dx si
       mov  bx, si
       mov  ax, word ptr [bx + 8]
       call Phex16
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       mov  ax, word ptr [bx + 6]
       call Phex16
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       mov  ax, word ptr [bx + 4]
       call Phex16
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       mov  ax, word ptr [bx + 2]
       call Phex16
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       mov  ax, word ptr [bx]
       call Phex16
       pop  si dx cx bx ax
       ret
Pst ENDP

;==============================================================
;  Печать dword с 8 знаками после точки (MIC = значение * 10^8)
;==============================================================
PMic PROC
       push ax
       push bx
       push cx
       push dx
       push si
       push di
       mov  ax, word ptr MIC
       mov  dx, word ptr MIC + 2
       mov  word ptr Negf, 0
       test dx, 8000h
       jz   L_m_pos
       mov  word ptr Negf, 1
       not  ax
       not  dx
       add  ax, 1
       adc  dx, 0
L_m_pos:
       mov  word ptr MIClo, ax
       mov  word ptr MIChi, dx
       cmp  word ptr Negf, 0
       je   L_m_digits
       lea  dx, MsgMinus
       mov  ah, 09h
       int  21h
L_m_digits:
       lea  di, DigBuf + 18
       mov  si, 10
       mov  word ptr Nd, 0
L_m_loop:
       mov  ax, word ptr MIClo
       mov  dx, word ptr MIChi
       mov  cx, ax                     ; низшее слово делимого
       mov  ax, dx                     ; старшее слово
       xor  dx, dx
       div  si                         ; AX = старшая часть частного, DX = остаток
       mov  bx, ax                     ; BX = старшая часть частного
       mov  ax, cx                     ; DX:AX = остаток : низшее слово
       div  si                         ; AX = младшая часть частного, DX = цифра
       mov  word ptr MIClo, ax
       mov  word ptr MIChi, bx
       mov  ax, dx
       add  al, 30h
       dec  di
       mov  [di], al
       inc  word ptr Nd
       or   word ptr MIChi, 0
       jnz  L_m_loop
       cmp  word ptr MIClo, 0
       jne  L_m_loop
       mov  bx, word ptr Nd
L_m_pad:
       cmp  bx, 9
       jae  L_m_print
       dec  di
       mov  byte ptr [di], 30h
       inc  bx
       jmp  L_m_pad
L_m_print:
       mov  si, bx
       sub  si, 8                      ; цифр целой части
       jns  L_m_int
       xor  si, si
L_m_int:
       or   si, si
       jz   L_m_dot
       mov  dl, [di]
       mov  ah, 02h
       int  21h
       inc  di
       dec  si
       jmp  L_m_int
L_m_dot:
       mov  dl, 2Eh
       mov  ah, 02h
       int  21h
       mov  cx, 8
L_m_fr:
       mov  dl, [di]
       mov  ah, 02h
       int  21h
       inc  di
       loop L_m_fr
       pop  di
       pop  si
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       ret
PMic ENDP
;==============================================================
;  Pfloat: напечатать число, лежащее в ST(0), с 8 знаками
;  Умножение на 10^8 командами FPU, целое - FISTP dword
;==============================================================
Pfloat PROC
       fild dword ptr Ten8
       fmulp                         ; ST(1)*ST(0) -> ST(0), pop
       fistp dword ptr MIC
       call PMic
       ret
Pfloat ENDP

;==============================================================
;  MantTest: опыт на разрядную сетку мантиссы
;  1e8 + 1 и 1e8 + 0.01; результат - побитово, потерянная величина -
;  разностью (sum - 1e8), которая мала и потому печатается точно
;==============================================================
MantTest PROC
       ; Режим берётся из CWtmp, который выставил вызывающий код, и ПОВТОРЯЕТСЯ
       ; после каждого FSAVE: FSAVE не только сохраняет состояние, но и
       ; реинициализирует FPU, то есть сбрасывает слово управления к 037Fh.
       ; FINIT ЗДЕСЬ НЕЛЬЗЯ: он сбросил бы Precision Control, заданный вызывающим
       ; кодом (проверено прогоном: при PC=24 и PC=64 результаты становились равны).
       ; Разность хранится в 80-bit слоте, чтобы не добавлять ошибку одинарной точности.
       push ax
       push cx
       push dx
       push si
       fild dword ptr OneE8              ; ST(0) = 1.0e8 (точно из целого)
       fld1                              ; ST(0) = 1.0
       faddp                             ; ST(1) + ST(0) -> ST(0), pop
       fsave FBUF
       fldcw CWtmp                       ; FSAVE реинициализирует FPU (сбрасывает
                                         ; и слово управления) - возвращаем PC
       lea  dx, MsgM1
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       fld  tbyte ptr FBUF + 14
       fild dword ptr OneE8
       fsubp
       fstp tbyte ptr DiffT
       lea  dx, MsgDiffLbl
       mov  ah, 09h
       int  21h
       fld  tbyte ptr DiffT
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       fild dword ptr OneE8
       fild word ptr OneI                ; ST(0) = 1
       fild word ptr CentI               ; ST(0) = 100, ST(1) = 1
       fdivp                             ; ST(1) / ST(0) = 0.01 -> ST(0), pop
       faddp                             ; 1.0e8 + 0.01 -> ST(0), pop
       fsave FBUF
       fldcw CWtmp                       ; см. выше: без этого второй опыт идёт
                                         ; при PC=64 (проверено прогоном)
       lea  dx, MsgM2
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       fld  tbyte ptr FBUF + 14
       fild dword ptr OneE8
       fsubp
       fstp tbyte ptr DiffT
       lea  dx, MsgDiffLbl
       mov  ah, 09h
       int  21h
       fld  tbyte ptr DiffT
       call Pfloat
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  si
       pop  dx
       pop  cx
       pop  ax
       ret
MantTest ENDP

;==============================================================
;  Разбор слова состояния: TOP (биты 13..11)
;==============================================================
PswTop PROC
       push ax bx cx dx
       lea  dx, MsgTopLbl
       mov  ah, 09h
       int  21h
       mov  ax, SWv
       mov  cx, 11
       shr  ax, cl
       and  ax, 7
       call Pdec16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  dx cx bx ax
       ret
PswTop ENDP

;==============================================================
;  Разбор слова состояния: флаги 0..7 (I D Z O U P SF ES)
;==============================================================
PswFlags PROC
       push ax bx cx dx si
       lea  dx, MsgFlagsLbl
       mov  ah, 09h
       int  21h
       mov  cx, 0
L_fl_loop:
       mov  ax, SWv
       mov  bx, cx                ; номер бита -> BL (Pbit читает BL)
       call Pbit
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       inc  cx
       cmp  cx, 8
       jb   L_fl_loop
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  si dx cx bx ax
       ret
PswFlags ENDP

Pbit PROC                       ; AX = слово, BL = номер бита -> печать 0/1
       push bx cx dx
       mov  cl, bl
       shr  ax, cl
       and  ax, 1
       call Pdec16
       pop  dx cx bx
       ret
Pbit ENDP

;==============================================================
;  Разбор слова тэгов: 2 бита на регистр (00 valid, 01 zero,
;  10 special, 11 empty) - печать символами V Z S E
;==============================================================
Ptag PROC
       push ax bx cx dx si
       lea  dx, MsgTagVals
       mov  ah, 09h
       int  21h
       mov  si, 0
L_tg_loop:
       mov  ax, TAGv
       mov  bx, si
       shl  bx, 1
       mov  cx, bx
       shr  ax, cl
       and  ax, 3
       mov  bx, offset TagTab
       xlat
       mov  dl, al
       mov  ah, 02h
       int  21h
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       inc  si
       cmp  si, 8
       jb   L_tg_loop
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  si dx cx bx ax
       ret
Ptag ENDP

;==============================================================
;  Разбор слова управления: PC (9..8), RC (11..10), IC (12),
;  маски исключений (0..5)
;==============================================================
PcFromCw PROC
       push ax bx cx dx
       lea  dx, MsgPcLbl
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       mov  cx, 8
       shr  ax, cl
       and  ax, 3
       call Pdec16
       lea  dx, MsgPcMap
       mov  ah, 09h
       int  21h
       lea  dx, MsgRcLbl
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       mov  cx, 10
       shr  ax, cl
       and  ax, 3
       call Pdec16
       lea  dx, MsgRcMap
       mov  ah, 09h
       int  21h
       lea  dx, MsgIcLbl
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       mov  cx, 12
       shr  ax, cl
       and  ax, 1
       call Pdec16
       lea  dx, MsgMaskLbl
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       and  ax, 3Fh
       call Phex16
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  dx cx bx ax
       ret
PcFromCw ENDP

;==============================================================
;  Phex16 / Phex8 / Pnib / Pdec16 - печать чисел
;  ВНИМАНИЕ: цифры 30h..39h (не 48h/57h - иначе печатается HHHH)
;==============================================================
Phex16 PROC
       push ax bx cx dx
       mov  cx, 4
L_ph_loop:
       rol  ax, 4
       push ax
       mov  dl, al
       and  dl, 0Fh
       call Pnib
       pop  ax
       dec  cx
       jnz  L_ph_loop
       pop  dx cx bx ax
       ret
Phex16 ENDP

Pnib PROC                       ; DL = байт -> печать его МЛАДШЕГО ниббла
       and  dl, 0Fh
       add  dl, 30h
       cmp  dl, 39h
       jbe  L_nib_ok
       add  dl, 7
L_nib_ok:
       mov  ah, 02h
       int  21h
       ret
Pnib ENDP

Phex8 PROC                      ; AL = байт -> печать двух цифр
       push ax bx cx dx
       mov  bl, al
       shr  al, 4
       mov  dl, al
       call Pnib
       mov  dl, bl
       call Pnib
       pop  dx cx bx ax
       ret
Phex8 ENDP

Pbytes PROC                     ; SI = адрес, CX = количество байт
       push ax cx dx si di
       mov  di, si
       mov  si, cx
       xor  cx, cx
L_by_loop:
       mov  al, [di]
       call Phex8
       lea  dx, MsgSp
       mov  ah, 09h
       int  21h
       inc  di
       inc  cx
       cmp  cx, si
       jb   L_by_loop
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       pop  di si dx cx ax
       ret
Pbytes ENDP

Pdec16 PROC                     ; AX = беззнаковое 16-битное
       push bx cx dx si
       lea  bx, Buf + 6
       mov  byte ptr [bx], 24h
       mov  si, 10
L_d1:
       xor  dx, dx
       div  si
       add  dl, 30h
       dec  bx
       mov  [bx], dl
       test ax, ax
       jnz  L_d1
       lea  dx, [bx]
       mov  ah, 09h
       int  21h
       pop  si dx cx bx
       ret
Pdec16 ENDP

;==============================================================
;  ДАННЫЕ - ПОСЛЕ кода (обязательно для .COM)
;==============================================================
.DATA
NumA      DD  ?
NumB      DD  ?
NumC      DD  ?
NumTA     DB  10 DUP(?)
NumTB     DB  10 DUP(?)
NumTC     DB  10 DUP(?)
KVs       DD  ?
Part      DD  ?
Summ      DD  ?
Diff      DD  ?
DiffT     DB  10 DUP(?)
DblA      DB  8 DUP(?)
FBUF      DB  110 DUP(?)
CWtmp     DW  ?
CWv       DW  ?
SWv       DW  ?
TAGv      DW  ?
SignFlag  DW  ?
IntP      DW  ?
Frac      DW  ?
Scale     DW  ?
MIC       DD  ?
MIClo     DW  ?
MIChi     DW  ?
Negf      DW  ?
Nd        DW  ?
DigBuf    DB  20 DUP(?)
Buf       DB  7 DUP(?)
; ВНИМАНИЕ: плавающие константы (DD/DQ/DT с десятичным значением) в TASM 4.1
; кодируются С ОБМЕНОМ НИББЛОВ В КАЖДОМ БАЙТЕ - проверено зондом:
;   DD 16.02 -> 6F 82 08 14 вместо измеренных F6 28 80 41.
; Поэтому все величины строятся ИЗ ЦЕЛЫХ констант командами FPU.
Ten8      DD  100000000              ; 10^8   (целое, для FILD)
OneE8     DD  100000000              ; 1.0e8  (целое, для FILD)
OneI      DW  1
CentI     DW  100
TagTab    DB  56h, 5Ah, 53h, 45h        ; V Z S E
Line      DB  84 DUP(?)
EndPtr    DW  ?
DefLen    EQU 16
DefLine   DB  16h, 2Eh, 30h, 32h, 20h, 33h, 2Eh, 35h, 20h, 2Dh, 30h, 2Eh, 31h, 32h, 35h, 0Dh
FName     DB  64h, 3Ah, 5Ch, 69h, 6Eh, 2Eh, 74h, 78h, 74h, 0
MsgCr     DB  13, 10, '$'              ; перевод строки
MsgSp DB  ' ','$'
MsgMinus DB  '-','$'
MsgTitle DB  '=== Lab7 step 1 (ASM): three numbers in the FPU stack, their sum, mantissa limits ===','$'
MsgHead1 DB  '--- 1) INPUT: three numbers in a dialog ---','$'
MsgPrompt DB  '  enter three numbers separated by spaces (e.g. 16.02 3.5 -0.125):','$'
MsgParsed DB  '  parsed: sign=','$'
MsgIntLbl DB  '  int=','$'
MsgFracLbl DB  '  frac=','$'
MsgScaleLbl DB  '  scale=','$'
MsgValLbl DB  '  value in FPU = ','$'
MsgBlank DB  13, 10, 13, 10, '$'
MsgHead2 DB  '--- 2) HOW THE FPU REGISTERS ARE USED: a stack of 8 x 80 bits ---','$'
MsgCW DB  '  control word = ','$'
MsgSW DB  '  status word  = ','$'
MsgTopLbl DB  '  TOP (status bits 13..11) = ','$'
MsgTAG DB  '  tag word     = ','$'
MsgTagVals DB  '  tags R0..R7 (V=valid Z=zero S=special E=empty): ','$'
MsgST0 DB  '  ST(0) = ','$'
MsgST1 DB  '  ST(1) = ','$'
MsgST2 DB  '  ST(2) = ','$'
MsgStackNote DB  '  note: FLD pushes (TOP decreases), FADDP/FDIVP/FSTP pop; FSAVE stores the','$'
MsgStackNote2 DB  '  whole stack and resets it. Header of FSAVE is 14 bytes (386 mode):','$'
MsgStackNote3 DB  '  CW, SW, TAG, opcode offset+sel, operand offset+sel.','$'
MsgHead3 DB  '--- 3) SUMMING (FADD/FADDP) AND THE RESULT ---','$'
MsgPart DB  '  A + B        = ','$'
MsgSum DB  '  (A + B) + C  = ','$'
MsgRaw DB  '  80-bit view: ','$'
MsgFlagsLbl DB  '  status flags I D Z O U P SF ES = ','$'
MsgHead4 DB  '--- 4) MANTISSA WIDTH: precision control = CW bits 9..8 ---','$'
MsgPC24 DB  '  PC=24 bit : CW = ','$'
MsgPC64 DB  '  PC=64 bit : CW = ','$'
MsgPcLbl DB  '   PC=','$'
MsgPcMap DB  ' (00=24, 10=53, 11=64)','$'
MsgRcLbl DB  '  RC=','$'
MsgRcMap DB  ' (00=nearest, 01=down, 10=up, 11=truncate)','$'
MsgIcLbl DB  '  IC=','$'
MsgMaskLbl DB  '  exception masks = ','$'
MsgM1 DB  '  1.0e8 + 1.0  -> ST(0) = ','$'
MsgM2 DB  '  1.0e8 + 0.01 -> ST(0) = ','$'
MsgDiffLbl DB  '  (sum - 1.0e8) = ','$'
MsgHead5 DB  '--- 5) THE SAME NUMBER IN THE THREE FORMATS (A7.txt lines 50-66) ---','$'
MsgKV DB  '  KV (single, 32 bit) bytes: ','$'
MsgDV DB  '  DV (double, 64 bit) bytes: ','$'
MsgVV DB  '  VV (temp,   80 bit) bytes: ','$'
MsgKVval DB  '  KV value  = ','$'
MsgDVval DB  '  DV value  = ','$'
MsgVVval DB  '  VV value  = ','$'
MsgFormatsNote DB  '  note: KV and DV hide the leading mantissa bit (implicit), VV shows it,','$'
MsgFormatsNote2 DB  '  so 16.02 is exact only in the 80-bit register; KV loses the digits.','$'
MsgPause DB  '>>> Press any key to finish... ','$'
END START
