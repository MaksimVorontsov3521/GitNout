;============================================================================
;  Lab7_3.asm  -  Задание 3 (A7.txt, строки 31-32):
;  "Прочитайте и проанализируйте состояния регистров FPU в TD:
;   регистра состояния и регистра управления."
;
;  ЯЗЫК И ТУЛЧЕЙН: ассемблер TASM 4.1 (.286, .MODEL TINY, формат .COM),
;                    TLINK /v /t, запуск в DOSBox 0.74-3.
;  ПОЧЕМУ АССЕМБЛЕР, А НЕ C (задание изначально звучало как C + asm):
;    встроенный asm в TCC 2.01 здесь неприменим. Замерено: компилятор эмитит
;    каждую asm-строку как "  { instr } ", а TASM 4.1 отвергает скобки
;    ("Unknown character", 1 строка = 2 ошибки сборки). Ключа -8 (8087) у
;    TCC 2.01 тоже нет ("Incorrect command line option"), а файла 8087.h в
;    комплекте INCLUDE нет вовсе, поэтому _status87/_control87 недоступны.
;    Слово состояния из C достаётся только отображением на флаги процессора,
;    и оно теряёт часть информации (это измерено и разобрано в Lab7_2, раздел 4).
;    Побитово прочитать CW и SW может ТОЛЬКО ассемблер - отсюда выбор языка.
;
;  ЧТО ДЕЛАЕТ ПРОГРАММА
;    1) FINIT -> FSTCW: слово управления в HEX, 16 бит строкой, разбор каждого
;       поля по A7.txt (строки 128-152): маски 5..0, резерв 7..6, PC 9..8,
;       RC 11..10, IC 12, резерв 15..13.
;    2) Эксперимент над PC (биты 9..8): 00=24, 01=резерв, 10=53, 11=64 - на
;       примере 1.0/3.0 и -1.0/3.0 печатается 80-битный образ ST(0) и его
;       десятичное значение: видно, СКОЛЬКО значащих бит мантиссы остаётся.
;    3) Эксперимент над RC (биты 11..10) по A7.txt (строки 142-146): 00 до
;       ближайшего/чётного, 01 вниз, 10 вверх, 11 усечение. Матрица на
;       1.0/3.0 и -1.0/3.0: на отрицательном числе "вниз" и "к нулю"
;       расходятся, на положительном совпадают - в этом весь смысл четырёх
;       режимов.
;    4) FINIT -> FSTSW: слово состояния, 16 бит строкой, разбор полей по
;       A7.txt (строки 160-184): флаги 0..5, SF 6, ES 7, C0 8, C1 9, C2 10,
;       TOP 11..13, C3 14, BUSY 15. Отдельно доказательство, что TOP именно в
;       11..13: замеренное значение 2900h даёт TOP=5.
;    5) Определение класса особого случая ПО ПРИОРИТЕТУ (A7.txt, строки 84-95):
;       1 недействительная операция, 2 деление на нуль, 3 денормализованный
;       операнд, 4 переполнение, 5 антипереполнение, 6 неточный результат.
;    6) Чтение слова состояния ВТОРЫМ способом: FSTSW AX (A7.txt, строки 157-159)
;       и FSTSW памятью - сравнение двух образов.
;    7) Каждый флаг исключений по очереди: опыт -> SW -> расшифровка.
;    8) Коды условия C0..C3 на четырёх сравнениях (больше/меньше/равно/unordered).
;    9) FCLEX: сброс флагов, SW до и после.
;   10) TAG-слово из заголовка FSAVE и FINCSTP/FDECSTP (A7.txt, строки 186-205):
;       ротация указателя TOP без движения данных.
;   11) Инструкция для TD (интерактив, автозахвату не поддаётся) и ответы.
;
;  ОСОБЕННОСТИ (все - результат прогонов, см. Zond_Lab7.txt)
;    - ВСЕ выводимые литералы ASCII (в DOSBox кодировка cp866, кириллица в
;      строках превращается в мусор); комментарии по-русски; ровно один "$"
;      на строку для int 21h/09h.
;    - НИКАКИХ плавающих констант в данных: TASM 4.1 кодирует DD/DQ/DT с
;      десятичным значением С ОБМЕНОМ НИББЛОВ В КАЖДОМ БАЙТЕ (DD 16.02 ->
;      6F 82 08 14 вместо измеренного F6 28 80 41; директива .387 не помогает).
;      Все величины строятся из ЦЕЛЫХ констант командами FILD/FLDZ/FSTP,
;      а особые 80-битные шаблоны задаются побайтово через DB.
;    - FSAVE реинициализирует FPU и СБРАСЫВАЕТ слово управления, поэтому после
;      каждого FSAVE повторяется FLDCW (иначе следующий опыт идёт при PC=64 -
;      проверено прогоном Lab7_1).
;    - Цифры печатаются 30h..39h (не 48h/57h, иначе выходит HHHH); ниббл
;      маскируется через and dl, 0Fh.
;    - Делимое в PMic держится в глобальных словах: печать минуса через
;      int 21h/09h портит DX, а DX - старшее слово делимого (проверено).
;    - TASM 4.1: mov bl, si запрещён ("Operand types do not match"); дальние
;      условные переходы требуют jmp near ptr.
;    - Программа завершается сама; ожидание клавиша спрятано под IFNDEF NOWAIT.
;      При зависании capture пуст (буферизация теряет всё), поэтому все
;      петли здесь ограничены счётчиком Idx с явным сравнением.
;============================================================================
.286
.MODEL TINY
.CODE
ORG 100h

START:
       lea  dx, MsgHead
       mov  ah, 09h
       int  21h
       call Pnl
;------------------------------------------------------------- 1) CW: Fields
       lea  dx, MsgH1
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fstcw CWv
       lea  dx, MsgCwHex
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       call Pnl
       call Pcw
;--------------------------------------------------------------- 2) PC test
       lea  dx, MsgH2
       mov  ah, 09h
       int  21h
       call Pnl
       mov  word ptr Idx, 0
L_h2:
       mov  ax, 037Fh                 ; базовое CW: маски все взведены
       and  ax, 0FCFFh                ; сбросить PC (биты 9..8)
       mov  bx, word ptr Idx
       mov  cx, bx
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       or   ax, cx
       mov  CWtmp, ax
       fldcw CWtmp
       fstcw CWv
       lea  dx, MsgPcSet
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       call Pnl
       call PcFromCw
       lea  dx, MsgRes13
       mov  ah, 09h
       int  21h
       call Div3
       lea  dx, MsgRes13b
       mov  ah, 09h
       int  21h
       call DivM3
       inc  word ptr Idx
       mov  ax, word ptr Idx
       cmp  ax, 4
       jb   near ptr L_h2
;--------------------------------------------------------------- 3) RC test
       lea  dx, MsgH3
       mov  ah, 09h
       int  21h
       call Pnl
       mov  word ptr Idx, 0
L_h3:
       mov  ax, 037Fh                 ; PC = 64 бит (полная мантисса)
       and  ax, 0F3FFh                ; сбросить RC (биты 11..10)
       mov  bx, word ptr Idx
       mov  cx, bx
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       shl  cx, 1
       or   ax, cx
       mov  CWtmp, ax
       fldcw CWtmp
       fstcw CWv
       lea  dx, MsgRcSet
       mov  ah, 09h
       int  21h
       mov  ax, CWv
       call Phex16
       call Pnl
       lea  dx, MsgRcIs
       mov  ah, 09h
       int  21h
       mov  ax, word ptr Idx
       mov  bx, ax
       mov  ax, 64
       xor  dx, dx
       mul  bx
       lea  si, RcNames
       add  si, ax
       mov  dx, si
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgRes13
       mov  ah, 09h
       int  21h
       call Div3
       lea  dx, MsgRes13b
       mov  ah, 09h
       int  21h
       call DivM3
       inc  word ptr Idx
       mov  ax, word ptr Idx
       cmp  ax, 4
       jb   near ptr L_h3
;------------------------------------------------------------- 4) SW: Fields
       lea  dx, MsgH4
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fstsw SWv
       lea  dx, MsgSwHex
       mov  ah, 09h
       int  21h
       mov  ax, SWv
       call Phex16
       call Pnl
       call Psw
       lea  dx, MsgTopProof
       mov  ah, 09h
       int  21h
       mov  ax, 2900h
       call Phex16
       call Pnl
       lea  dx, MsgTopProof2
       mov  ah, 09h
       int  21h
       mov  ax, 2900h                ; Phex16 вернул AX изменённым - берём заново
       mov  cx, 11
       shr  ax, cl
       and  ax, 7
       call Pdec16
       call Pnl
       lea  dx, MsgTopProof3
       mov  ah, 09h
       int  21h
       call Pnl
;------------------------------------------------------- 5) FSTSW AX vs mem
       lea  dx, MsgH5
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fld1
       fild word ptr Three
       fdivp                          ; 1.0/3.0 -> взводится PE
       fstsw ax                       ; ВТОРОЙ способ (A7.txt, строка 197)
       mov  SWax, ax
       fstsw SWmem
       lea  dx, MsgSwAx
       mov  ah, 09h
       int  21h
       mov  ax, SWax
       call Phex16
       call Pnl
       lea  dx, MsgSwMem
       mov  ah, 09h
       int  21h
       mov  ax, SWmem
       call Phex16
       call Pnl
       lea  dx, MsgSwSame
       mov  ah, 09h
       int  21h
       mov  ax, SWax
       cmp  ax, SWmem
       je   L_h5_eq
       lea  dx, MsgNo
       mov  ah, 09h
       int  21h
       call Pnl
       jmp  near ptr L_h5_end
L_h5_eq:
       lea  dx, MsgYes
       mov  ah, 09h
       int  21h
       call Pnl
L_h5_end:
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
       mov  ax, SWax
       mov  SWv, ax
       call Psw
;------------------------------------------- 6) КАЖДЫЙ ФЛАГ ИСКЛЮЧЕНИЙ ОТДЕЛЬНО
       lea  dx, MsgH6
       mov  ah, 09h
       int  21h
       call Pnl
       ; Все маски после FINIT взведены (CW=037Fh), поэтому опыты безопасны:
       ; флаги только накапливаются в слове состояния, прерываний нет.
       finit
       fldz
       fldz
       fdivp                        ; 0.0 / 0.0
       lea  dx, MsgIE
       call RepSw
       finit
       fld  tbyte ptr DenT            ; денормализованный операнд (2^-16383)
       fld1
       faddp
       lea  dx, MsgDE
       call RepSw
       finit
       fld1
       fldz
       fdivp                        ; 1.0 / 0.0
       lea  dx, MsgZE
       call RepSw
       finit
       fld  tbyte ptr BigT            ; 2^16383 (максимальное конечное)
       fld  tbyte ptr BigT
       fmul                         ; 2^32766 - переполнение
       lea  dx, MsgOE
       call RepSw
       finit
       fld  tbyte ptr DenT
       fld  tbyte ptr DenT
       fmul                         ; 2^-32766 - исчезновение порядка
       lea  dx, MsgUE
       call RepSw
       finit
       fild word ptr OneI
       fild word ptr Three
       fdivp                        ; 1/3 - бесконечная двоичная дробь
       lea  dx, MsgPE
       call RepSw
       finit
       fld1
       fld1
       fld1
       fld1
       fld1
       fld1
       fld1
       fld1
       fld1                         ; 10-й FLD в 8-регистровый стек
       lea  dx, MsgSF
       call RepSw
       lea  dx, MsgSfNote
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgSfNote2
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgSfNote3
       mov  ah, 09h
       int  21h
       call Pnl
       finit

;-------------------------------------------------- 6b) коды условия C0..C3
       lea  dx, MsgH6b
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgCondIntro
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fild word ptr Two
       fild word ptr Two
       fcompp                         ; сравнение равных (всплывает ST(0))
       fstsw SWv
       call Pcond
       finit
       fild word ptr OneI
       fild word ptr Two
       fcompp                         ; ST(0)=2, ST(1)=1 -> ST(0) больше ST(1)
       fstsw SWv
       call Pcond
       finit
       fild word ptr Two
       fild word ptr OneI
       fcompp                         ; ST(0)=1, ST(1)=2 -> ST(0) меньше ST(1)
       fstsw SWv
       call Pcond
       finit
       fldz
       fldz
       fdivp
       fstp tbyte ptr Nant            ; NaN в память (измеренный путь)
       fld  tbyte ptr Nant
       fild word ptr OneI
       fcompp                         ; unordered: NaN против числа
       fstsw SWv
       call Pcond
       finit
       lea  dx, MsgCondIntel
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgCondIntel2
       mov  ah, 09h
       int  21h
       call Pnl

;----------------------------------------------------------------- 7) FCLEX
       lea  dx, MsgH7
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fldz
       fldz
       fdivp
       fstsw SWv
       lea  dx, MsgBefore
       mov  ah, 09h
       int  21h
       mov  ax, SWv
       call Phex16
       call Pnl
       fclex
       fstsw SWv
       lea  dx, MsgAfter
       mov  ah, 09h
       int  21h
       mov  ax, SWv
       call Phex16
       call Pnl
       lea  dx, MsgFclexNote
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgFclexNote2
       mov  ah, 09h
       int  21h
       call Pnl

;---------------------------------------- 8) TAG-слово и FINCSTP/FDECSTP
       lea  dx, MsgH8
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fld1
       fild word ptr Two
       fild word ptr Three
       fsave FBUF
       fldcw CWtmp                    ; (FSAVE сбрасывает CW - здесь это безвредно,
                                      ; но показываем приём обязательным: после
                                      ; FSAVE режим точности надо восстанавливать)
       lea  dx, MsgSaveHdr
       mov  ah, 09h
       int  21h
       mov  ax, word ptr FBUF + 0
       call Phex16
       call Pnl
       lea  dx, MsgSaveHdr2
       mov  ah, 09h
       int  21h
       mov  ax, word ptr FBUF + 2
       call Phex16
       call Pnl
       lea  dx, MsgSaveHdr3
       mov  ah, 09h
       int  21h
       mov  ax, word ptr FBUF + 4
       call Phex16
       call Pnl
       mov  ax, word ptr FBUF + 2
       mov  SWv, ax
       mov  ax, word ptr FBUF + 4
       mov  TAGv, ax
       lea  dx, MsgTagTop
       mov  ah, 09h
       int  21h
       call Pnl
       call PswTop
       call Pnl
       lea  dx, MsgTagDecode
       mov  ah, 09h
       int  21h
       call Pnl
       call Ptag
       call Pnl
       lea  dx, MsgSt0
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 14
       call Pst
       call Pnl
       lea  dx, MsgSt1
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 24
       call Pst
       call Pnl
       lea  dx, MsgSt2
       mov  ah, 09h
       int  21h
       lea  si, FBUF + 34
       call Pst
       call Pnl
       lea  dx, MsgRot
       mov  ah, 09h
       int  21h
       call Pnl
       finit
       fild word ptr OneI
       fild word ptr Two
       fild word ptr Three
       fstsw SWv
       lea  dx, MsgRotBefore
       mov  ah, 09h
       int  21h
       call PswTop
       call Pnl
       fincstp
       fstsw SWv
       lea  dx, MsgIncstp
       mov  ah, 09h
       int  21h
       call PswTop
       call Pnl
       fdecstp
       fdecstp
       fstsw SWv
       lea  dx, MsgDecstp
       mov  ah, 09h
       int  21h
       call PswTop
       call Pnl
       lea  dx, MsgRotNote
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgRotNote2
       mov  ah, 09h
       int  21h
       call Pnl

;--------------------------------------------------------------- 9) инструкция TD
       lea  dx, MsgH9
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd1
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd2
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd3
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd4
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd5
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgTd6
       mov  ah, 09h
       int  21h
       call Pnl

;--------------------------------------------------------------- 10) ответы
       lea  dx, MsgH10
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgA1
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgA2
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgA3
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgA4
       mov  ah, 09h
       int  21h
       call Pnl
       lea  dx, MsgA5
       mov  ah, 09h
       int  21h
       call Pnl

IFNDEF NOWAIT            ; /dNOWAIT: автопрогон без ожидания клавиши
       lea  dx, MsgPause
       mov  ah, 09h
       int  21h
       mov  ah, 00h
       int  16h
ENDIF
       mov  ax, 4C00h
       int  21h

;============================================================================
;  Pnl - перевод строки (13,10). Нужен потому, что все сообщения печатаются
;  через int 21h/09h, а "$" сам по себе перевод строки не даёт.
;============================================================================
Pnl PROC
       push ax dx
       mov  dl, 13
       mov  ah, 02h
       int  21h
       mov  dl, 10
       mov  ah, 02h
       int  21h
       pop  dx ax
       ret
Pnl ENDP

;============================================================================
;  Pbin - 16 бит слова AX, старший слева, пробел каждые 4 бита
;============================================================================
Pbin PROC
       push ax bx cx dx
       mov  bx, ax
       mov  cx, 16
L_bin:
       mov  ax, bx
       and  ax, 8000h
       jz   L_bin_0
       mov  dl, 31h
       jmp  near ptr L_bin_pr
L_bin_0:
       mov  dl, 30h
L_bin_pr:
       mov  ah, 02h
       int  21h
       shl  bx, 1
       dec  cx
       jz   L_bin_end
       mov  ax, cx
       and  ax, 3
       jnz  near ptr L_bin
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       jmp  near ptr L_bin
L_bin_end:
       pop  dx cx bx ax
       ret
Pbin ENDP

;============================================================================
;  Pcw - слово УПРАВЛЕНИЯ (A7.txt, строки 128-152). Счётчик в DI.
;============================================================================
Pcw PROC
       push ax bx cx dx di
       lea  dx, MsgBits15_0
       mov  ah, 09h
       int  21h

       mov  ax, CWv
       call Pbin
       call Pnl
       lea  dx, MsgCwMasks
       mov  ah, 09h
       int  21h
       call Pnl
       call Pnl

       mov  cx, 6
       mov  di, 0
L_cw_m:
       mov  ax, CWv
       mov  bx, di
       call Pbit
       mov  dl, 3Ah
       mov  ah, 02h
       int  21h
       mov  ax, di
       mov  bx, ax
       mov  ax, 26
       xor  dx, dx
       mul  bx
       lea  si, MaskNames
       add  si, ax
       mov  dx, si
       mov  ah, 09h
       int  21h
       call Pnl
       inc  di
       loop L_cw_m
       call PcFromCw
       call Pnl
       pop  di dx cx bx ax
       ret
Pcw ENDP

;============================================================================
;  Psw - слово СОСТОЯНИЯ (A7.txt, строки 160-184), каждый бит с именем
;============================================================================
Psw PROC
       push ax bx cx dx di
       lea  dx, MsgBits15_0b
       mov  ah, 09h
       int  21h

       mov  ax, SWv
       call Pbin
       call Pnl
       lea  dx, MsgSwFields
       mov  ah, 09h
       int  21h
       call Pnl
       call Pnl

       mov  cx, 16
       mov  di, 0
L_sw_l:
       mov  ax, SWv
       mov  bx, di
       call Pbit
       mov  dl, 3Ah
       mov  ah, 02h
       int  21h
       mov  ax, di
       mov  bx, ax
       mov  ax, 30
       xor  dx, dx
       mul  bx
       lea  si, SwNames
       add  si, ax
       mov  dx, si
       mov  ah, 09h
       int  21h
       call Pnl
       inc  di
       loop L_sw_l
       call Pprio
       pop  di dx cx bx ax
       ret
Psw ENDP

;============================================================================
;  Pprio - класс особого случая ПО ПРИОРИТЕТУ (A7.txt, строки 84-95)
;============================================================================
Pprio PROC
       push ax bx cx dx
       lea  dx, MsgPrioLbl
       mov  ah, 09h
       int  21h

       mov  ax, SWv
       test ax, 01h
       jnz  L_pr_1
       test ax, 04h
       jnz  L_pr_2
       test ax, 02h
       jnz  L_pr_3
       test ax, 08h
       jnz  L_pr_4
       test ax, 10h
       jnz  L_pr_5
       test ax, 20h
       jnz  L_pr_6
       jmp  near ptr L_pr_0
L_pr_1:
       lea  dx, MsgP1
       jmp  near ptr L_pr_sh
L_pr_2:
       lea  dx, MsgP2
       jmp  near ptr L_pr_sh
L_pr_3:
       lea  dx, MsgP3
       jmp  near ptr L_pr_sh
L_pr_4:
       lea  dx, MsgP4
       jmp  near ptr L_pr_sh
L_pr_5:
       lea  dx, MsgP5
       jmp  near ptr L_pr_sh
L_pr_6:
       lea  dx, MsgP6
       jmp  near ptr L_pr_sh
L_pr_0:
       lea  dx, MsgP0
L_pr_sh:
       mov  ah, 09h
       int  21h
       call Pnl
       mov  ax, SWv
       test ax, 40h
       jz   L_pr_ns
       lea  dx, MsgPsf
       mov  ah, 09h
       int  21h
       call Pnl
L_pr_ns:
       mov  ax, SWv
       test ax, 80h
       jz   L_pr_ne
       lea  dx, MsgPes
       jmp  near ptr L_pr_show
L_pr_ne:
       lea  dx, MsgPes0
L_pr_show:
       mov  ah, 09h
       int  21h
       call Pnl
       pop  dx cx bx ax
       ret
Pprio ENDP

;============================================================================
;  Pflags7 - одна строка: номер бита, сокращение, значение (биты 0..7)
;============================================================================
Pflags7 PROC
       push ax bx cx dx di
       mov  cx, 8
       mov  di, 0
L_f7:
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       mov  ax, di
       call Pdec16
       mov  dl, 3Ah
       mov  ah, 02h
       int  21h
       mov  bx, di
       add  bx, bx
       mov  si, bx
       mov  dl, FlagAbbr[si]
       mov  ah, 02h
       int  21h
       inc  si
       mov  dl, FlagAbbr[si]
       mov  ah, 02h
       int  21h
       mov  dl, 3Dh
       mov  ah, 02h
       int  21h
       mov  ax, SWv
       mov  bx, di
       call Pbit
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       inc  di
       loop L_f7
       call Pnl
       pop  di dx cx bx ax
       ret
Pflags7 ENDP

;============================================================================
;  RepSw - метка из DX, свежее FSTSW, hex, флаги, приоритетный класс
;============================================================================
RepSw PROC
       push ax bx cx dx
       mov  ah, 09h
       int  21h
       lea  dx, MsgSwIs
       mov  ah, 09h
       int  21h
       fstsw SWv
       mov  ax, SWv
       call Phex16
       call Pnl
       call Pflags7
       call Pprio
       pop  dx cx bx ax
       ret
RepSw ENDP

;============================================================================
;  Pcond - коды условия C0..C3. РАСШИФРОВКА ПО ЗАМЕРЕННОМУ, а не по Intel:
;  зонд W/V/U (см. Zond_Lab7.txt) дал в DOSBox 0.74-3 такую таблицу FCOMPP/FTST:
;    выше (ST(0) > ST(1))  -> 0000h     равно -> 4000h     ниже -> 0100h
;    не сравниваемы (NaN)  -> 4500h     (C3=1, C2=1, C0=1)
;  У Intel 8087 иначе: выше = 4100h (C3=1,C0=1), ниже = 0000h. Различие
;  принципиально: оно и объясняет, почему в Lab7_2 сравнения NaN ведут себя
;  так, как ведут (код TCC строит FCOMPP + FSTSW AX + SAHF + jbe).
;============================================================================
Pcond PROC
       push ax bx cx dx
       lea  dx, MsgCondLbl
       mov  ah, 09h
       int  21h

       mov  ax, SWv
       mov  bx, 8
       call Pbit
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       mov  ax, SWv
       mov  bx, 9
       call Pbit
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       mov  ax, SWv
       mov  bx, 10
       call Pbit
       mov  dl, 20h
       mov  ah, 02h
       int  21h
       mov  ax, SWv
       mov  bx, 14
       call Pbit
        lea  dx, MsgCondSWx
        mov  ah, 09h
        int  21h
        mov  ax, SWv
        call Phex16
        lea  dx, MsgCondH
        mov  ah, 09h
        int  21h
       lea  dx, MsgCondEq
       mov  ah, 09h
       int  21h

       mov  ax, SWv
       and  ax, 4500h                ; маска C3 (14), C2 (10), C0 (8)
       cmp  ax, 4500h
       je   L_cd_un
       cmp  ax, 4000h
       je   L_cd_eq
       cmp  ax, 0100h
       je   L_cd_lt
       cmp  ax, 0000h
       je   L_cd_gt
       jmp  near ptr L_cd_other
L_cd_un:
       lea  dx, MsgCondU
       jmp  near ptr L_cd_sh
L_cd_eq:
       lea  dx, MsgCondE
       jmp  near ptr L_cd_sh
L_cd_lt:
       lea  dx, MsgCondLt
       jmp  near ptr L_cd_sh
L_cd_gt:
       lea  dx, MsgCondGt
       jmp  near ptr L_cd_sh
L_cd_other:
       lea  dx, MsgCondOther
L_cd_sh:
       mov  ah, 09h
       int  21h
       call Pnl
       pop  dx cx bx ax
       ret
Pcond ENDP

;============================================================================
;  Div3 / DivM3 - 1.0/3.0 и -1.0/3.0: 80-битный образ ST(0) и значение.
;  FSAVE сбрасывает CW, поэтому сразу FLDCW CWtmp (CWtmp ставится вызывающим).
;============================================================================
Div3 PROC
       push ax si
       fld1
       fild word ptr Three
       fdivp
       fsave FBUF
       fldcw CWtmp
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgValIs
       mov  ah, 09h
       int  21h

       fld  tbyte ptr FBUF + 14
       call Pfloat
       call Pnl
       pop  si
       pop  ax
       ret
Div3 ENDP

DivM3 PROC
       push ax si
       fld1
       fild word ptr Three
       fdivp
       fchs
       fsave FBUF
       fldcw CWtmp
       lea  si, FBUF + 14
       call Pst
       lea  dx, MsgValIs
       mov  ah, 09h
       int  21h

       fld  tbyte ptr FBUF + 14
       call Pfloat
       call Pnl
       pop  si
       pop  ax
       ret
DivM3 ENDP
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

Pbit PROC                       ; AX = слово, BL = номер бита -> печать 0/1
       push bx cx dx
       mov  cl, bl
       shr  ax, cl
       and  ax, 1
       call Pdec16
       pop  dx cx bx
       ret
Pbit ENDP

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

Pfloat PROC
       fild dword ptr Ten8
       fmulp                         ; ST(1)*ST(0) -> ST(0), pop
       fistp dword ptr MIC
       call PMic
       ret
Pfloat ENDP

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
;============================================================================
;  ДАННЫЕ - ПОСЛЕ кода (обязательно для .COM)
;  Плавающих констант НЕТ (TASM 4.1 меняет нибблы в каждом байте - проверено):
;  величины либо целые константы для FILD, либо побайтовые 80-битные шаблоны.
;  Таблицы имён имеют ФИКСИРОВАННУЮ ширину записи (пробелы дописаны ВНУТРЬ
;  строки), поэтому индексация через mul даёт точный адрес следующей записи.
;============================================================================
.DATA
Idx       DW  ?                        ; счётчик циклов в main
SWax      DW  ?                        ; слово состояния из FSTSW AX
SWmem     DW  ?                        ; слово состояния из FSTSW памяти
Two       DW  2
Three     DW  3
; 80-битный образ: b9 b8 - порядок (смещение 16383), b7..b0 - мантисса, где
; бит 7 байта b7 - ЯВНЫЙ старший разряд J (в КВ/ДВ он неявный). У
; денормализованного числа порядок = 0 И J = 0.
DenT      DB   0,  0,  0,  0,  0,  0,  0, 40h,  0h,  0h   ; exp=0, J=0, bit62 -> 2^-16445
BigT      DB   0,  0,  0,  0,  0,  0,  0, 80h, 0FEh, 7Fh  ; exp=7FFEh, J=1    -> 2^16383
Nant      DB  10 DUP(?)                                    ; сюда кладётся полученный NaN
; --- взято из Lab7_1 (прогнанные определения) ---
FBUF      DB  110 DUP(?)
CWtmp     DW  ?
CWv       DW  ?
SWv       DW  ?
TAGv      DW  ?
MIC       DD  ?
MIClo     DW  ?
MIChi     DW  ?
Negf      DW  ?
Nd        DW  ?
DigBuf    DB  20 DUP(?)
Buf       DB  7 DUP(?)
Ten8      DD  100000000              ; 10^8   (целое, для FILD)
OneI      DW  1
CentI     DW  100
TagTab    DB  56h, 5Ah, 53h, 45h        ; V Z S E
MsgCr     DB  13, 10, '$'              ; перевод строки (в Lab7_1 тоже исправлен)
MsgSp DB  ' ','$'
MsgMinus DB  '-','$'
MsgTopLbl DB  '  TOP (status bits 13..11) = ','$'
MsgTagVals DB  '  tags R0..R7 (V=valid Z=zero S=special E=empty): ','$'
MsgPcLbl DB  '   PC=','$'
MsgPcMap DB  ' (00=24, 10=53, 11=64)','$'
MsgRcLbl DB  '  RC=','$'
MsgRcMap DB  ' (00=nearest, 01=down, 10=up, 11=truncate)','$'
MsgIcLbl DB  '  IC=','$'
MsgMaskLbl DB  '  exception masks = ','$'
MsgPause DB  '>>> Press any key to finish... ','$'
; --- таблицы фиксированной ширины: 6 x 26, 16 x 30, 4 x 64 ---
MaskNames    DB  '0 invalid operation (IE) ', '$'
             DB  '1 denormal operand (DE)  ', '$'
             DB  '2 zero divide (ZE)       ', '$'
             DB  '3 overflow (OE)          ', '$'
             DB  '4 underflow (UE)         ', '$'
             DB  '5 precision (PE)         ', '$'
SwNames      DB  '0  invalid operation IE      ', '$'
             DB  '1  denormal operand DE       ', '$'
             DB  '2  zero divide      ZE       ', '$'
             DB  '3  overflow         OE       ', '$'
             DB  '4  underflow         UE      ', '$'
             DB  '5  precision         PE      ', '$'
             DB  '6  stack fault       SF      ', '$'
             DB  '7  error summary     ES      ', '$'
             DB  '8  condition code    C0      ', '$'
             DB  '9  condition code    C1      ', '$'
             DB  '10 condition code    C2      ', '$'
             DB  '11 top pointer 13..11        ', '$'
             DB  '12 top pointer 13..11        ', '$'
             DB  '13 top pointer 13..11        ', '$'
             DB  '14 condition code    C3      ', '$'
             DB  '15 FPU busy        BUSY      ', '$'
FlagAbbr    DB  'IE','DE','ZE','OE','UE','PE','SF','ES'
RcNames      DB  '00 nearest, ties to even                                       ', '$'
             DB  '01 down (toward minus infinity)                                ', '$'
             DB  '10 up (toward plus infinity)                                   ', '$'
             DB  '11 truncate (toward zero)                                      ', '$'
MsgHead        DB  '=== Lab7 step 3: reading and analysing the FPU control and status words ===','$'
MsgH1          DB  '--- 1) CONTROL WORD: fields as given by A7.txt lines 128-152 ---','$'
MsgCwHex       DB  '  CW = ','$'
MsgBits15_0    DB  '  bits 15..0 (most significant bit first): ','$'
MsgCwMasks     DB  '  exception masks, bits 5..0 (0 = unmasked, 1 = masked):','$'
MsgH2          DB  '--- 2) PRECISION CONTROL (bits 9..8): the same 1.0/3.0 at every PC ---','$'
MsgPcSet       DB  '  CW set to ','$'
MsgRes13       DB  '    1.0 / 3.0 -> ','$'
MsgRes13b      DB  '   -1.0 / 3.0 -> ','$'
MsgValIs       DB  '    = ','$'
MsgH3          DB  '--- 3) ROUNDING CONTROL (bits 11..10), A7.txt lines 142-146 ---','$'
MsgRcSet       DB  '  CW = ','$'
MsgRcIs        DB  '    mode ','$'
MsgH4          DB  '--- 4) STATUS WORD: fields as given by A7.txt lines 160-184 ---','$'
MsgSwHex       DB  '  SW = ','$'
MsgBits15_0b   DB  '  bits 15..0 (most significant bit first): ','$'
MsgSwFields    DB  '  every bit of the status word:','$'
MsgPrioLbl     DB  '  class by PRIORITY (A7.txt lines 84-95): ','$'
MsgP1          DB  '1) invalid operation (bit 0)','$'
MsgP2          DB  '2) zero divide (bit 2)','$'
MsgP3          DB  '3) denormalized operand (bit 1)','$'
MsgP4          DB  '4) overflow (bit 3)','$'
MsgP5          DB  '5) underflow (bit 4)','$'
MsgP6          DB  '6) inexact result (bit 5)','$'
MsgP0          DB  'no unmasked special case detected','$'
MsgPsf         DB  '   also: stack fault (bit 6) - NOT in the priority list of A7.txt','$'
MsgPes         DB  '   ES (bit 7) = 1: an UNMASKED case is pending','$'
MsgPes0        DB  '   ES (bit 7) = 0: no unmasked case (all masks are set)','$'
MsgTopProof    DB  '  proof that TOP lives in bits 13..11 (MEASURED in Lab7_1): SW = ','$'
MsgTopProof2   DB  '    bits 13..11 of it give TOP = ','$'
MsgTopProof3   DB  '  note: Phex16 changes AX, so the value is reloaded before the shift','$'
MsgH5          DB  '--- 5) FSTSW AX vs FSTSW memory (A7.txt lines 157-159) ---','$'
MsgSwIs        DB  '  SW = ','$'
MsgSwAx        DB  '  FSTSW AX    -> ','$'
MsgSwMem       DB  '  FSTSW memory-> ','$'
MsgSwSame      DB  '  identical: ','$'
MsgNo          DB  'NO','$'
MsgYes         DB  'YES','$'
MsgH6          DB  '--- 6) EVERY EXCEPTION FLAG, ONE EXPERIMENT AT A TIME (masks all set) ---','$'
MsgIE          DB  '  0.0 / 0.0                :','$'
MsgDE          DB  '  FADD with a denormal operand:','$'
MsgZE          DB  '  1.0 / 0.0                :','$'
MsgOE          DB  '  2^16383 * 2^16383        :','$'
MsgUE          DB  '  2^-16445 * 2^-16445      :','$'
MsgPE          DB  '  1.0 / 3.0                :','$'
MsgSF          DB  '  the 10th FLD into 8 registers:','$'
MsgH6b         DB  '--- 6b) CONDITION CODES C0..C3 (A7.txt lines 181-184) ---','$'
MsgCondIntro   DB  '  only FCOM/FTST/FXAM change C0..C3; arithmetic leaves them unchanged','$'
MsgCondLbl     DB  '  C0 C1 C2 C3 = ','$'
MsgCondSWx     DB  '   SW = ','$'
MsgCondH       DB  'h ','$'
MsgCondEq      DB  '   -> meaning: ','$'
MsgCondGt      DB  'ST(0) greater than ST(1)','$'
MsgCondLt      DB  'ST(0) less than ST(1)','$'
MsgCondE       DB  'ST(0) equal to ST(1)','$'
MsgCondU       DB  'UNORDERED (at least one operand is a NaN)','$'
MsgCondOther   DB  'any other combination','$'
MsgH7          DB  '--- 7) FCLEX: clearing the flags ---','$'
MsgBefore      DB  '  SW before FCLEX = ','$'
MsgAfter       DB  '   SW after  FCLEX = ','$'
MsgFclexNote   DB  '  Without FCLEX the flag stays set: the next WAIT-form instruction would','$'
MsgFclexNote2  DB  '  report the SAME special case again, over and over.','$'
MsgH8          DB  '--- 8) TAG WORD AND STACK ROTATION (A7.txt lines 186-205) ---','$'
MsgSaveHdr     DB  '  FSAVE header, bytes 0..1  (control word)      = ','$'
MsgSaveHdr2    DB  '  FSAVE header, bytes 2..3  (status word)      = ','$'
MsgSaveHdr3    DB  '  FSAVE header, bytes 4..5  (tag word)         = ','$'
MsgTagTop      DB  '  TOP taken from the saved status word:','$'
MsgTagDecode   DB  '  tag word decoded:','$'
MsgSt0         DB  '  ST(0) (the last pushed, 3.0) : ','$'
MsgSt1         DB  '  ST(1)               (2.0)   : ','$'
MsgSt2         DB  '  ST(2)               (1.0)   : ','$'
MsgRot         DB  '  rotation without moving data: FINCSTP / FDECSTP change TOP only','$'
MsgRotBefore   DB  '  three values pushed, TOP =','$'
MsgIncstp      DB  '  after FINCSTP (TOP + 1 mod 8):','$'
MsgDecstp      DB  '  after two FDECSTP (TOP - 2 mod 8):','$'
MsgRotNote     DB  '  The data did not move: only the circular pointer changed, so the same','$'
MsgRotNote2    DB  '  physical register is now seen as another logical ST(i).','$'
MsgH9          DB  '--- 9) HOW TO TRACE THE SAME THINGS IN TURBO DEBUGGER (interactive) ---','$'
MsgTd1         DB  '  TD cannot be captured by the autotest (it is a full-screen debugger), so','$'
MsgTd2         DB  '  this is the manual procedure for the defence:','$'
MsgTd3         DB  '    1. Run the "Compile and Debug in TD" task (Ctrl+Shift+B, second task).','$'
MsgTd4         DB  '    2. View -> Floating Point: ST(0)..ST(7) as 10-byte values, the tag word','$'
MsgTd5         DB  '       and the Control/Status words live there. F2 sets a breakpoint, F7 steps','$'
MsgTd6         DB  '       one instruction - watch TOP decrease on FLD and increase on FSTP.','$'
MsgSfNote      DB  '  MEASURED: the 9th and 10th FLD did NOT set SF (bit 6) here.','$'
MsgSfNote2     DB  '  DOSBox 0.74-3 does not report stack overflow at all, so a real','$'
MsgSfNote3     DB  '  8087 must be consulted for the SF behaviour (A7.txt line 167).','$'
MsgCondIntel   DB  '  Intel 8087 differs: greater = C3=1,C0=1 (4100h), less = 0000h.','$'
MsgCondIntel2  DB  '  The table above is the MEASURED DOSBox behaviour, not the book.','$'
MsgH10         DB  '--- 10) ANSWERS ---','$'
MsgA1          DB  '  1. The control word selects MODES (PC, RC, IC, six masks); the status word','$'
MsgA2          DB  '     reports FACTS (six flags, SF, ES, TOP, four condition codes, BUSY).','$'
MsgA3          DB  '  2. TOP occupies bits 13..11, the condition codes are split: C0,C1,C2 in bits','$'
MsgA4          DB  '     8,9,10 and C3 in bit 14 - that is why FSTSW AX + SAHF maps only C0 and C3','$'
MsgA5          DB  '     onto CF and ZF, and C2 (the unordered indicator) is lost in C code.','$'

END START
