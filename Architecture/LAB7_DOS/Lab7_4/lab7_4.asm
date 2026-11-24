;==============================================================
;  Лабораторная работа N7, ШАГ 4  (A7.txt, строки 33-36)
;
;  "4. Напишите программу, выполняющую команды FPU, вызывающую и
;   реагирующую на особый случай FPU (обработчик прерывания сообщает
;   о наступлении особого случая по результату анализа регистра
;   состояния)."
;
;  Чистый ассемблер, TASM 4.1: .286 + .MODEL TINY -> .COM.
;  .386 НЕ используется: tlink /v /t отвечает
;  "32-bit record encountered in module ... use /3 option" (замерено).
;  Данные - ПОСЛЕ кода (обязательно для .COM), выход через
;  mov ax,4C00h / int 21h, поэтому программа завершается сама.
;  Все выводимые строки - ASCII: кириллица в cp866 DOSBox даёт мусор.
;
;  ПОРЯДОК СЕКЦИЙ ВЫВОДА = ПОРЯДОК ЗАДАНИЯ:
;    1) сохранить и напечатать существующие вектора 75h (математический
;       сопроцессор, IRQ13, путь при NE=0) и 16h (исключение x87, путь
;       при NE=1) через int 21h/AH=35h;
;    2) прочитать CR0 машинным кодом (под .286 TASM не принимает
;       "mov eax, cr0") и напечатать двумя 16-битными частями, НЕ делая
;       из этого значения никаких выводов о бите NE;
;    3) установить СВОЙ обработчик на вектор 75h через int 21h/AH=25h
;       (DS:DX = адрес), перечитать и напечатать; 16h ставится тем же
;       кодом как альтернативный путь при NE=1, со своим счётчиком;
;    4) снять маску ОДНОГО класса - Z (деление на нуль, бит 2 CW):
;       FSTCW -> очистить бит 2 -> FLDCW; печать CW до/после и разбор
;       шести битов маски P,U,O,Z,D,I с подписями;
;    5) спровоцировать именно этот случай: 1.0/0.0, делимое и делитель
;       из ЦЕЛЫХ констант (FILD word ptr OneI / FILD word ptr ZeroI),
;       затем FDIVP (ST(1)/ST(0) с всплытием) и обязательно FWAIT;
;    6) прочитать слово состояния (FSTSW), разобрать его ПО БИТАМ
;       (A7.txt 154-185) и выбрать класс, обслуживаемый первым, по
;       таблице приоритета (A7.txt 84-99); напечатать, что замеренный
;       бит ES = 0, то есть суммарный признак ошибки НЕ взведён;
;    7) ВЫЗВАТЬ свой обработчик программно: int 75h;
;    8) напечатать: число входов обработчика, класс по его слову
;       состояния, какое слово он застал и сколько входов добавил
;       аппаратный путь (ноль) - с сравнением ожидания на реальном
;       железе (NE=1 -> 16h, NE=0 -> 75h, A7.txt 105-110);
;    9) второй опыт: маска класса I (бит 0), 0.0/0.0 -> NaN, снова
;       разбор по приоритету, снова int 75h, плюс таблица
;       "приоритет - это не порядок битов";
;   10) восстановить ОБА вектора через int 21h/AH=25h и перечитать их;
;   11) блок "почему так работает".
;
;  КЛЮЧЕВОЙ ФАКТ, УСТАНОВЛЕННЫЙ РЕАЛЬНЫМИ ЗАМЕРАМИ НА ЭТОМ ИНСТРУМЕНТЕ
;  (зонд P5 в Zond_Lab7.txt, воспроизводился дважды) - и программа
;  ПЕЧАТАЕТ это различие явно, а не делает вид, что прерывание пришло
;  само:
;    DOSBox 0.74-3 НЕ ДОСТАВЛЯЕТ немаскированные исключения x87. При
;    CW=037B (маска бита 2, ZE, снята) и операции 1.0/0.0 слово
;    состояния после FWAIT = 3904h (ZE=1, TOP=7, C0=1), но счётчик
;    входов установленного обработчика 75h равен 0, обработчика 16h
;    тоже 0, бит ES (бит 7 слова состояния) = 0, а сам вектор 75h до
;    установки был 0000:0000h. Значит, реагировать надо на ФЛАГ в слове
;    состояния, а настоящий обработчик (PROC + IRET, ставится через
;    int 21h/AH=25h) вызывать программно через int 75h. На реальном
;    8087/387 немаскированный случай сам останавливает программу и
;    передаёт управление обработчику.
;
;  Сборка:  tasm /zi /dNOWAIT ..\lab7_4.asm   +   tlink /v /t lab7_4
;  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab7_4;
;           автопрогон: ..\autotest.ps1 -Root .. -Dir Lab7_4
;==============================================================

.286
.MODEL TINY

.CODE
ORG 100h                            ; .COM: PSP занимает 0000h..00FFh

START:
       finit                         ; привести FPU в известное состояние
       lea  dx, MsgTitle
       call Pstr
       lea  dx, MsgTitle2
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 1. Вектора как они есть: сохранить и напечатать.
       ; int 21h/AH=35h возвращает вектор в ES:BX.
       ;==========================================================
       lea  dx, MsgH1
       call Pstr

       mov  al, 75h                  ; вектор мат. сопроцессора (IRQ13)
       mov  ah, 35h
       int  21h
       mov  word ptr Old75Seg, es
       mov  word ptr Old75Ofs, bx
       lea  dx, MsgV75
       call Pstr
       mov  ax, word ptr Old75Seg
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, word ptr Old75Ofs
       call Phex16
       lea  dx, MsgCr
       call Pstr

       mov  al, 16h                  ; вектор исключения x87 при NE=1
       mov  ah, 35h
       int  21h
       mov  word ptr Old16Seg, es
       mov  word ptr Old16Ofs, bx
       lea  dx, MsgV16
       call Pstr
       mov  ax, word ptr Old16Seg
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, word ptr Old16Ofs
       call Phex16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgVnote1
       call Pstr
       lea  dx, MsgVnote2
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 2. CR0 машинным кодом:
       ; MOV EAX,CR0   = 0F 20 C0
       ; MOV [var],EAX = 66 A3 + dw offset   (32-битный операнд)
       ;==========================================================
       lea  dx, MsgH2
       call Pstr
       db   0Fh, 20h, 0C0h           ; MOV EAX, CR0
       db   66h, 0A3h                ; MOV [var], EAX (операнд 32 бита)
       dw   offset CR0v
       lea  dx, MsgCR0
       call Pstr
       mov  ax, word ptr CR0v + 2    ; СТАРШАЯ 16-битная часть
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, word ptr CR0v        ; МЛАДШАЯ 16-битная часть
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgNeLbl
       call Pstr
       mov  ax, word ptr CR0v + 2
       and  ax, 1                    ; бит 16 CR0 (NE) = бит 0 старшего слова
       mov  word ptr NEv, ax
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgCR0n1
       call Pstr
       lea  dx, MsgCR0n2
       call Pstr
       lea  dx, MsgCR0n3
       call Pstr
       lea  dx, MsgCR0n4
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 3. Установить СВОЙ обработчик на 75h (и 16h).
       ; В .COM DS = CS, поэтому offset обработчика в DX - верный.
       ;==========================================================
       lea  dx, MsgH3
       call Pstr
       xor  ax, ax
       mov  word ptr H75, ax         ; счётчики входов обнулены
       mov  word ptr H16, ax
       mov  word ptr SW75v, ax
       mov  word ptr CL75v, ax
       mov  word ptr MS75v, ax
       mov  word ptr SW16v, ax
       mov  word ptr CL16v, ax
       mov  word ptr MS16v, ax

       lea  dx, ISR75
       mov  al, 75h
       mov  ah, 25h
       int  21h
       lea  dx, MsgInst75
       call Pstr
       mov  ax, cs
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, offset ISR75
       call Phex16
       lea  dx, MsgCr
       call Pstr

       lea  dx, ISR16
       mov  al, 16h
       mov  ah, 25h
       int  21h
       lea  dx, MsgInst16
       call Pstr
       mov  ax, cs
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, offset ISR16
       call Phex16
       lea  dx, MsgCr
       call Pstr

       mov  al, 75h                  ; перечитать, что стоит в таблице
       mov  ah, 35h
       int  21h
       lea  dx, MsgRead75
       call Pstr
       mov  ax, es
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, bx
       call Phex16
       lea  dx, MsgCr
       call Pstr

       mov  al, 16h
       mov  ah, 35h
       int  21h
       lea  dx, MsgRead16
       call Pstr
       mov  ax, es
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, bx
       call Phex16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgInstOk
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 4. Снять маску ОДНОГО класса: Z - деление на нуль.
       ; FSTCW -> and 0FFFBh -> FLDCW; печать CW до/после и разбор
       ; шести битов маски (A7.txt 134-140).
       ;==========================================================
       lea  dx, MsgH4
       call Pstr
       finit
       fstcw CWsave                  ; 037Fh: все шесть классов замаскированы
       fldcw CWsave
       lea  dx, MsgCWbef
       call Pstr
       mov  ax, word ptr CWsave
       call Phex16
       lea  dx, MsgCr
       call Pstr
       fstsw SW0                     ; слово состояние сразу после FINIT
       lea  dx, MsgSW0
       call Pstr
       mov  ax, word ptr SW0
       call Phex16
       lea  dx, MsgCr
       call Pstr
       mov  ax, word ptr CWsave
       call PcwMask

       mov  ax, word ptr CWsave
       and  ax, 0FFFBh               ; бит 2 (ZE) -> 0, остальные маски целы
       mov  word ptr CWunm, ax
       fldcw CWunm
       lea  dx, MsgCWaft
       call Pstr
       mov  ax, word ptr CWunm
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgOnlyZ
       call Pstr
       lea  dx, MsgCr
       call Pstr
       mov  ax, word ptr CWunm
       call PcwMask
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 5. Спровоцировать именно этот случай: 1.0 / 0.0.
       ; Оба операнда - из ЦЕЛЫХ констант: TASM 4.1 кодирует DD/DQ/DT
       ; с десятичным значением С ОБМЕНОМ НИББЛОВ в каждом байте
       ; (замерено: DD 16.02 -> 6F 82 08 14 вместо F6 28 80 41),
       ; поэтому плавающие литералы в данных здесь неприменимы.
       ;==========================================================
       lea  dx, MsgH5
       call Pstr
       lea  dx, MsgOp1
       call Pstr
       lea  dx, MsgOp2
       call Pstr
       lea  dx, MsgOp3
       call Pstr
       fild word ptr OneI            ; ST(0) = 1.0
       fild word ptr ZeroI           ; ST(0) = 0.0, следовательно ST(1) = 1.0
       fdivp                         ; ST(1) := ST(1)/ST(0) = 1.0/0.0, всплытие
       fwait                         ; синхронизация: без неё слово состояния
                                     ; может быть прочитано до завершения
                                     ; операции (A7.txt 194-199, 218-224)
       fstsw SW1                     ; слово состояния ПОСЛЕ операции
       lea  dx, MsgOp4
       call Pstr
       lea  dx, MsgOp5
       call Pstr
       lea  dx, MsgOp6
       call Pstr
       lea  dx, MsgOp7
       call Pstr
       lea  dx, MsgOp8
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 6. Разбор слова состояния ПО БИТАМ (A7.txt 154-185)
       ; и выбор класса, обслуживаемого первым (A7.txt 84-99).
       ;==========================================================
       lea  dx, MsgH6
       call Pstr
       lea  dx, MsgSWval
       call Pstr
       mov  ax, word ptr SW1
       call Phex16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgFlagsLbl
       call Pstr
       mov  ax, word ptr SW1
       call PswBits
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgSp2
       call Pstr
       mov  ax, word ptr SW1
       call PswExtra
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgPrioChain
       call Pstr
       lea  dx, MsgPrioChain2
       call Pstr
       mov  ax, word ptr SW1
       call DecodeClass              ; BX = код класса 0..7
       mov  word ptr CLmain1, bx
       lea  dx, MsgVerdict
       call Pstr
       mov  ax, word ptr CLmain1
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       call PClsName
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgRespLbl
       call Pstr
       call PRespTxt
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgESobs
       call Pstr
       mov  ax, word ptr SW1
       shr  ax, 7
       and  ax, 1
       mov  word ptr ESv, ax
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgESn1
       call Pstr
       lea  dx, MsgESn2
       call Pstr
       lea  dx, MsgESn3
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 7. Вход в обработчик: программный int 75h - тот самый
       ; вектор, который использует процессор при NE=0. Счётчики,
       ; напечатанные ДО вызова, и есть доказательство недоставки.
       ;==========================================================
       lea  dx, MsgH7
       call Pstr
       mov  ax, word ptr H75
       mov  word ptr HBef75, ax
       mov  ax, word ptr H16
       mov  word ptr HBef16, ax
       lea  dx, MsgHbef
       call Pstr
       mov  ax, word ptr HBef75
       call Pdec16
       lea  dx, MsgH16lbl
       call Pstr
       mov  ax, word ptr HBef16
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHwn1
       call Pstr
       lea  dx, MsgHwn2
       call Pstr
       lea  dx, MsgHwn3
       call Pstr
       lea  dx, MsgHwn4
       call Pstr
       int  75h                      ; наш вызов, а не доставка эмулятора
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 8. Что зафиксировал обработчик. Печатает main: печать
       ; внутри обработчика прерывания недопустима (int 21h не
       ; реентерабелен и измеренно вешает стенд).
       ;==========================================================
       lea  dx, MsgH8
       call Pstr
       lea  dx, MsgHaft
       call Pstr
       mov  ax, word ptr H75
       call Pdec16
       lea  dx, MsgH16lbl
       call Pstr
       mov  ax, word ptr H16
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHdel
       call Pstr
       mov  ax, word ptr H75
       sub  ax, word ptr HBef75
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgHdel16
       call Pstr
       mov  ax, word ptr H16
       sub  ax, word ptr HBef16
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHdeln
       call Pstr
       lea  dx, MsgHSW
       call Pstr
       mov  ax, word ptr SW75v
       call Phex16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHflags
       call Pstr
       mov  ax, word ptr SW75v
       call PswBits
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHcls
       call Pstr
       mov  ax, word ptr CL75v
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       call PClsName
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHresp
       call Pstr
       call PRespTxt
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHmsgidx
       call Pstr
       mov  ax, word ptr MS75v
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgHmsgidx2
       call Pstr
       lea  dx, MsgCr
       call Pstr
       ; чем обработчик закончил: маска возвращена, флаги сброшены
       fstsw SWafter
       fstcw CWafter
       lea  dx, MsgHcw
       call Pstr
       mov  ax, word ptr CWafter
       call Phex16
       lea  dx, MsgSp
       call Pstr
       mov  ax, word ptr CWafter
       and  ax, 3Fh
       cmp  ax, 3Fh
       jne  L_hcw_ne
       lea  dx, MsgAllMsk
       jmp  L_hcw_ok
L_hcw_ne:
       lea  dx, MsgNotMsk
L_hcw_ok:
       call Pstr
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHsw2
       call Pstr
       mov  ax, word ptr SWafter
       call Phex16
       lea  dx, MsgSp
       call Pstr
       mov  ax, word ptr SWafter
       and  ax, 003Fh
       jnz  L_hcl_ne
       lea  dx, MsgCleared
       jmp  L_hcl_ok
L_hcl_ne:
       lea  dx, MsgNotCleared
L_hcl_ok:
       call Pstr
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgCln
       call Pstr
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHcln1
       call Pstr
       lea  dx, MsgHcln2
       call Pstr
       lea  dx, MsgHcln3
       call Pstr
       lea  dx, MsgHcln4
       call Pstr
       lea  dx, MsgReal1
       call Pstr
       lea  dx, MsgReal2
       call Pstr
       lea  dx, MsgCr
       call Pstr
       ; ответ FPU по умолчанию как значение: ST(0) после 1.0/0.0.
       ; FSAVE инициирует FPU и СБРАСЫВАЕТ слово управления, поэтому
       ; после FSAVE маска загружается повторно.
       lea  dx, MsgSt0lbl
       call Pstr
       fild word ptr OneI
       fild word ptr ZeroI
       fdivp
       fwait
       fsave FB                      ; заголовок 14 байт + 8 регистров по 10 байт
       fldcw CWsave                  ; повтор FLDCW после FSAVE
       lea  dx, MsgSt0e
       call Pstr
       mov  ax, word ptr FB + 22     ; экспонента со знаком (бит 15 - знак)
       call Phex16
       lea  dx, MsgSt0m
       call Pstr
       mov  ax, word ptr FB + 20
       call Phex16
       mov  ax, word ptr FB + 18
       call Phex16
       mov  ax, word ptr FB + 16
       call Phex16
       mov  ax, word ptr FB + 14
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgSt0k
       call Pstr
       call PstKind
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgSt0n1
       call Pstr
       fclex                         ; флаги сбросить: пока взведён хоть один,
                                     ; следующая команда FPU считается особой
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 9. Второй опыт: снять маску класса I (бит 0 CW) и
       ; получить 0.0/0.0 -> NaN. Разбор по приоритету снова, вызов
       ; обработчика снова. Это показывает, что класс выбирается по
       ; таблице 84-99, а не по порядку битов.
       ;==========================================================
       lea  dx, MsgH9
       call Pstr
       finit
       fstcw CW2bef
       fldcw CW2bef
       lea  dx, MsgCWbef
       call Pstr
       mov  ax, word ptr CW2bef
       call Phex16
       lea  dx, MsgCr
       call Pstr
       mov  ax, word ptr CW2bef
       and  ax, 0FFFEh               ; бит 0 (IE) -> 0
       mov  word ptr CW2unm, ax
       fldcw CW2unm
       lea  dx, MsgCWaft
       call Pstr
       mov  ax, word ptr CW2unm
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgOnlyI
       call Pstr
       lea  dx, MsgCr
       call Pstr
       mov  ax, word ptr CW2unm
       call PcwMask
       lea  dx, MsgN1
       call Pstr
       lea  dx, MsgN2
       call Pstr
       fldz                          ; ST(0) = 0.0
       fldz                          ; ST(0) = 0.0, ST(1) = 0.0
       fdivp                         ; ST(1) := ST(1)/ST(0) = 0.0/0.0, всплытие
       fwait
       fstsw SW2
       lea  dx, MsgSWval
       call Pstr
       mov  ax, word ptr SW2
       call Phex16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgFlagsLbl
       call Pstr
       mov  ax, word ptr SW2
       call PswBits
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgSp2
       call Pstr
       mov  ax, word ptr SW2
       call PswExtra
       lea  dx, MsgCr
       call Pstr
       mov  ax, word ptr SW2
       call DecodeClass
       mov  word ptr CLmain2, bx
       lea  dx, MsgVerdict
       call Pstr
       mov  ax, word ptr CLmain2
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       call PClsName
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgRespLbl
       call Pstr
       call PRespTxt
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgESobs
       call Pstr
       mov  ax, word ptr SW2
       shr  ax, 7
       and  ax, 1
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       ; счётчик ДО второго вызова - вторая точка доказательства
       mov  ax, word ptr H75
       mov  word ptr HBef75b, ax
       lea  dx, MsgHbef2
       call Pstr
       mov  ax, word ptr HBef75b
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgHbef2b
       call Pstr
       int  75h                      ; тот же обработчик, тот же программный вход
       lea  dx, MsgHaft
       call Pstr
       mov  ax, word ptr H75
       call Pdec16
       lea  dx, MsgH16lbl
       call Pstr
       mov  ax, word ptr H16
       call Pdec16
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgHSW
       call Pstr
       mov  ax, word ptr SW75v
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgHcls
       call Pstr
       mov  ax, word ptr CL75v
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       call PClsName
       lea  dx, MsgCr
       call Pstr
       ; тот же случай в виде значения: что FPU положил в ST(0)
       fldcw CWsave
       fldz
       fldz
       fdivp
       fwait
       fsave FB
       fldcw CWsave                  ; FSAVE снова сбросил слово управления
       lea  dx, MsgSt0e
       call Pstr
       mov  ax, word ptr FB + 22
       call Phex16
       lea  dx, MsgSt0m
       call Pstr
       mov  ax, word ptr FB + 20
       call Phex16
       mov  ax, word ptr FB + 18
       call Phex16
       mov  ax, word ptr FB + 16
       call Phex16
       mov  ax, word ptr FB + 14
       call Phex16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgSt0k
       call Pstr
       call PstKind
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgSt0n2
       call Pstr
       fclex
       lea  dx, MsgCr
       call Pstr
       ; приоритет - это порядок ТАБЛИЦЫ, а не номер бита
       lea  dx, MsgRank0
       call Pstr
       lea  dx, MsgRank1
       call Pstr
       lea  dx, MsgRank2
       call Pstr
       lea  dx, MsgRank3
       call Pstr
       lea  dx, MsgRank4
       call Pstr
       lea  dx, MsgRank5
       call Pstr
       lea  dx, MsgRank6
       call Pstr
       lea  dx, MsgRank7
       call Pstr
       lea  dx, MsgRank8
       call Pstr
       lea  dx, MsgRankn1
       call Pstr
       lea  dx, MsgRankn2
       call Pstr
       lea  dx, MsgRankn3
       call Pstr
       lea  dx, MsgRankn4
       call Pstr
       lea  dx, MsgRankn5
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 10. Восстановить ОБА вектора (int 21h/AH=25h) и
       ; перечитать их. Без этого программа оставляет эмулятор с
       ; вектором, указывающим в уже несуществующую программу.
       ; AH=25h берёт новый вектор из DS:DX, поэтому DS временно
       ; становится сегментом сохранённого вектора (для 75h в DOSBox
       ; это 0000h); DOS только копирует DS:DX, не разыменовывая его.
       ;==========================================================
       lea  dx, MsgH10
       call Pstr
       push ds
       mov  dx, word ptr Old16Ofs
       mov  ax, word ptr Old16Seg
       mov  ds, ax
       mov  al, 16h
       mov  ah, 25h
       int  21h
       pop  ds
       push ds
       mov  dx, word ptr Old75Ofs
       mov  ax, word ptr Old75Seg
       mov  ds, ax
       mov  al, 75h
       mov  ah, 25h
       int  21h
       pop  ds
       fldcw CWsave                  ; слово управления тоже обратно к 037Fh
       fclex

       mov  al, 75h
       mov  ah, 35h
       int  21h
       lea  dx, MsgRest75
       call Pstr
       mov  ax, es
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, bx
       call Phex16
       lea  dx, MsgSp
       call Pstr
       mov  ax, bx
       cmp  ax, word ptr Old75Ofs
       jne  L_r75_bad
       mov  ax, es
       cmp  ax, word ptr Old75Seg
       jne  L_r75_bad
       lea  dx, MsgOk
       jmp  L_r75_go
L_r75_bad:
       lea  dx, MsgBad
L_r75_go:
       call Pstr
       lea  dx, MsgCr
       call Pstr

       mov  al, 16h
       mov  ah, 35h
       int  21h
       lea  dx, MsgRest16
       call Pstr
       mov  ax, es
       call Phex16
       lea  dx, MsgColon
       call Pstr
       mov  ax, bx
       call Phex16
       lea  dx, MsgSp
       call Pstr
       mov  ax, bx
       cmp  ax, word ptr Old16Ofs
       jne  L_r16_bad
       mov  ax, es
       cmp  ax, word ptr Old16Seg
       jne  L_r16_bad
       lea  dx, MsgOk
       jmp  L_r16_go
L_r16_bad:
       lea  dx, MsgBad
L_r16_go:
       call Pstr
       lea  dx, MsgCr
       call Pstr
       lea  dx, MsgRestn1
       call Pstr
       lea  dx, MsgRestn2
       call Pstr
       lea  dx, MsgRestn3
       call Pstr
       lea  dx, MsgCr
       call Pstr

       ;==========================================================
       ; СЕКЦИЯ 11. ПОЧЕМУ ТАК
       ;==========================================================
       lea  dx, MsgH11
       call Pstr
       lea  dx, MsgWhy1
       call Pstr
       lea  dx, MsgWhy2
       call Pstr
       lea  dx, MsgWhy3
       call Pstr
       lea  dx, MsgWhy4
       call Pstr
       lea  dx, MsgWhy5
       call Pstr
       lea  dx, MsgWhy6
       call Pstr
       lea  dx, MsgWhy7
       call Pstr
       lea  dx, MsgWhy8
       call Pstr
       lea  dx, MsgDone
       call Pstr

IFNDEF NOWAIT                        ; автопрогон передаёт /dNOWAIT
       lea  dx, MsgPause
       call Pstr
       mov  ah, 00h
       int  16h
ENDIF
       mov  ax, 4C00h
       int  21h

;==============================================================
;  ОБРАБОТЧИКИ ПРЕРЫВАНИЙ. ПЕЧАТАТЬ ОНИ НЕ МОГУТ НИЧЕГО: int 21h не
;  реентерабелен, а печать в обработчике измеренно вешает стенд.
;  Обработчик только фиксирует результат анализа в глобальных
;  переменных, а сообщение, построенное по этому анализу, печатает
;  main после возврата - это и есть "обработчик сообщил о случае,
;  проанализировав регистр состояния".
;
;  Порядок действий продиктован защитой от повторного входа:
;    1) инкремент счётчика входов;
;    2) СНАЧАЛА FLDCW сохранённой маски - иначе FSTSW (WAIT-форма,
;       A7.txt 194-199) при немаскированном флаге сам стал бы точкой
;       доставки и обработчик вызвал бы сам себя;
;    3) FSTSW в глобальную переменную: смена маски флаги не сбрасывает,
;       поэтому разбор идёт по тому же самому слову состояния;
;    4) разбор по приоритету -> код класса (0..7) и индекс печатного
;       сообщения - обе величины в глобальные переменные;
;    5) FCLEX - без него флаг остаётся взведённым и следующая команда
;       FPU снова была бы посчитана особым случаем;
;    6) EOI мастер-8259 (mov al,20h / out 20h,al) - нужен только при
;       настоящем аппаратном входе по IRQ13; при NE=1 ошибка x87 является
;       исключением процессора, а не внешним IRQ, поэтому ISR16 EOI не
;       посылает;
;    7) IRET. Все использованные регистры сохранены и восстановлены.
;
;  Замечание для реального железа: операнды FLDCW/FSTSW здесь
;  относительны DS, что в .COM безопасно (DS = CS). Резидентному
;  обработчику пришлось бы адресовать их через CS, иначе он зависит от
;  сегмента данных прерванной программы.
;==============================================================
ISR75  PROC
       push ax bx cx dx si di
       inc  word ptr H75              ; счётчик входов по вектору 75h
       fldcw CWsave                   ; вернуть маски ДО чтения состояния
       fstsw SW75v                    ; слово состояния, застатое внутри
       mov  ax, word ptr SW75v
       call DecodeClass               ; BX = класс по таблице приоритета
       mov  word ptr CL75v, bx        ; код класса 0..7
       mov  word ptr MS75v, bx        ; индекс печатного сообщения
       fclex                          ; сбросить флаги и коды условий
       mov  al, 20h
       out  20h, al                   ; EOI мастеру 8259 (нужен при IRQ13)
       pop  di si dx cx bx ax
       iret
ISR75  ENDP

ISR16  PROC
       push ax bx cx dx si di
       inc  word ptr H16              ; счётчик входов по вектору 16h
       fldcw CWsave
       fstsw SW16v
       mov  ax, word ptr SW16v
       call DecodeClass
       mov  word ptr CL16v, bx
       mov  word ptr MS16v, bx
       fclex
       pop  di si dx cx bx ax
       iret                           ; исключения CPU идут без EOI
ISR16  ENDP

;==============================================================
;  DecodeClass: AX = слово состояния -> BX = код класса, который
;  обслуживается ПЕРВЫМ. Цепочка (A7.txt строки 84-99; ошибка стека -
;  часть недействительной операции, строки 70-71 и 86):
;     I(bit0) > SF(bit6) > Z(bit2) > O(bit3) > U(bit4) > P(bit5) > D(bit1)
;  Коды: 0=I, 1=SF, 2=Z, 3=O, 4=U, 5=P, 6=D, 7=ни один флаг не взведён.
;  Ни печати, ни int 21h: процедуру вызывает обработчик прерывания.
;==============================================================
DecodeClass PROC
       push ax cx dx si di
       mov  di, ax                    ; копия слова состояния
       lea  si, PrioBits              ; DB 0, 6, 2, 3, 4, 5, 1
       xor  bx, bx
L_dc_loop:
       mov  ch, 0
       mov  cl, byte ptr [si+bx]      ; номер бита этого класса
       mov  ax, di
       shr  ax, cl
       and  ax, 1
       jnz  L_dc_end                  ; первый взведённый флаг = высший приоритет
       inc  bx
       cmp  bx, 7
       jb   L_dc_loop
       mov  bx, 7                     ; ни один из шести флагов не взведён
L_dc_end:
       pop  di si dx cx ax
       ret
DecodeClass ENDP

;==============================================================
;  Служебные процедуры: печать (их вызывает только main)
;==============================================================
PClsName PROC                        ; BX = код класса -> печать его имени
       push ax bx cx dx
       shl  bx, 1
       mov  dx, word ptr [bx+ClsNames]
       call Pstr
       pop  dx cx bx ax
       ret
PClsName ENDP

PRespTxt PROC                        ; BX = код класса -> печать ответа FPU
       push ax bx cx dx
       shl  bx, 1
       mov  dx, word ptr [bx+ClsResp]
       call Pstr
       pop  dx cx bx ax
       ret
PRespTxt ENDP

;--------------------------------------------------------------
;  PswBits: AX = слово состояния -> печать флагов бит 0..7
;  (A7.txt 168-174: I D Z O U P; 167: SF; 164-166: ES)
;--------------------------------------------------------------
PswBits PROC
       push ax bx cx dx si
       mov  word ptr SWx, ax
       xor  si, si
L_pb_loop:
       cmp  si, 0
       jne  L_pb_sp
       lea  dx, MsgSp2
       call Pstr
       jmp  L_pb_nosp
L_pb_sp:
       lea  dx, MsgSp
       call Pstr
L_pb_nosp:
       mov  bx, si
       shl  bx, 1                     ; в имени флага два символа
       add  bx, offset FlNames
       mov  dl, byte ptr [bx]
       mov  ah, 02h
       int  21h
       mov  dl, byte ptr [bx+1]
       mov  ah, 02h
       int  21h
       lea  dx, MsgEq
       call Pstr
       mov  ax, word ptr SWx
       mov  cx, si
       shr  ax, cl
       and  ax, 1
       call Pdec16
       inc  si
       cmp  si, 8
       jb   L_pb_loop
       pop  si dx cx bx ax
       ret
PswBits ENDP

;--------------------------------------------------------------
;  PswExtra: AX = слово состояния -> печать TOP (биты 13..11), кодов
;  условия C0..C3 (8, 9, 10, 14) и BUSY (15). A7.txt 161-163, 176-184
;--------------------------------------------------------------
PswExtra PROC
       push ax bx cx dx
       mov  word ptr SWx, ax
       lea  dx, MsgTopLbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 11
       and  ax, 7
       call Pdec16
       lea  dx, MsgSp2
       call Pstr
       lea  dx, MsgC0lbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 8
       and  ax, 1
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgC1lbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 9
       and  ax, 1
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgC2lbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 10
       and  ax, 1
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       lea  dx, MsgC3lbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 14
       and  ax, 1
       call Pdec16
       lea  dx, MsgSp2
       call Pstr
       lea  dx, MsgBusyLbl
       call Pstr
       mov  ax, word ptr SWx
       shr  ax, 15
       and  ax, 1
       call Pdec16
       pop  dx cx bx ax
       ret
PswExtra ENDP

;--------------------------------------------------------------
;  PcwMask: AX = слово управления -> печать шести битов маски
;  (A7.txt 134-140: 5=P, 4=U, 3=O, 2=Z, 1=D, 0=I) с подписями о том,
;  какой класс немаскирован.
;--------------------------------------------------------------
PcwMask PROC
       push ax bx cx dx si
       mov  word ptr CWx, ax
       lea  dx, MsgMaskLbl
       call Pstr
       mov  si, 5
L_cm_loop:
       lea  dx, MsgSp2
       call Pstr
       mov  bx, offset MskNames
       mov  dl, byte ptr [bx+si]
       mov  ah, 02h
       int  21h
       lea  dx, MsgEq
       call Pstr
       mov  ax, word ptr CWx
       mov  cx, si
       shr  ax, cl
       and  ax, 1
       mov  word ptr BITv, ax
       call Pdec16
       lea  dx, MsgSp
       call Pstr
       cmp  word ptr BITv, 1
       jne  L_cm_unm
       lea  dx, MsgMskd
       jmp  L_cm_next
L_cm_unm:
       lea  dx, MsgUnmsk
L_cm_next:
       call Pstr
       lea  dx, MsgCr
       call Pstr
       dec  si
       jns  L_cm_loop
       pop  si dx cx bx ax
       ret
PcwMask ENDP

;--------------------------------------------------------------
;  PstKind: классификация 80-битного ST(0) из буфера FSAVE (FB+14)
;  по кодированию A7.txt 226-253: экспонента вся из единиц и мантисса ровно
;  1.0 -> бесконечность; экспонента вся из единиц, мантисса со
;  старшим разрядом 1 -> QNaN, с 0 -> SNaN.
;--------------------------------------------------------------
PstKind PROC
       push ax bx cx dx
       mov  ax, word ptr FB + 22
       and  ax, 7FFFh
       cmp  ax, 7FFFh
       jne  L_sk_fin                  ; экспонента не вся из единиц
       mov  ax, word ptr FB + 20
       cmp  ax, 8000h
       jne  L_sk_nanchk
       mov  ax, word ptr FB + 18
       or   ax, word ptr FB + 16
       or   ax, word ptr FB + 14
       jnz  L_sk_nanchk
       lea  dx, MsgIsInf              ; мантисса ровно 1.0 -> бесконечность
       jmp  L_sk_pr
L_sk_nanchk:
       mov  ax, word ptr FB + 20
       test ax, 8000h
       jz   L_sk_snan
       lea  dx, MsgIsQNaN             ; старший разряд мантиссы 1 -> QNaN
       jmp  L_sk_pr
L_sk_snan:
       lea  dx, MsgIsSNaN             ; иначе SNaN
       jmp  L_sk_pr
L_sk_fin:
       lea  dx, MsgIsFin
L_sk_pr:
       call Pstr
       pop  dx cx bx ax
       ret
PstKind ENDP

Pstr PROC                            ; DX = адрес строки с '$'
       push ax
       mov  ah, 09h
       int  21h
       pop  ax
       ret
Pstr ENDP

;--------------------------------------------------------------
;  Phex16 / Pnib / Pdec16 - печать чисел.
;  Цифры 30h..39h и add dl,7 для A..F (НЕ 48h/57h - иначе печатается
;  HHHH, замерено). Ниббл маскируется and dl,0Fh до сравнения.
;--------------------------------------------------------------
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

Pnib PROC                            ; DL = байт -> печать его младшего ниббла
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

Pdec16 PROC                          ; AX = беззнаковое 16-битное число
       push bx cx dx si
       lea  bx, Buf + 6
       mov  byte ptr [bx], 24h        ; терминатор int 21h/09h
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
;  ДАННЫЕ - ПОСЛЕ кода (обязательно для .MODEL TINY / .COM)
;==============================================================
.DATA
; --- вектора, сохранённые в секции 1 ---
Old75Ofs  DW  ?
Old75Seg  DW  ?
Old16Ofs  DW  ?
Old16Seg  DW  ?
; --- CR0: заполняется машинным кодом, печатается двумя половинами ---
CR0v      DD  ?
NEv       DW  ?
; --- слова управления и состояния ---
CWsave    DW  ?                      ; 037Fh: все шесть классов замаскированы
CWunm     DW  ?                      ; 037Bh: снята маска Z
CW2bef    DW  ?
CW2unm    DW  ?                      ; 037Eh: снята маска I
CWafter   DW  ?                      ; CW после обработчика
SW0       DW  ?                      ; SW сразу после FINIT
SW1       DW  ?                      ; main: слово состояния после 1.0/0.0
SW2       DW  ?                      ; main: слово состояния после 0.0/0.0
SWafter   DW  ?                      ; SW после обработчика
ESv       DW  ?                      ; бит 7 слова SW1
SWx       DW  ?                      ; локальные копии для процедур печати
CWx       DW  ?
BITv      DW  ?
; --- то, что фиксирует обработчик ---
H75       DW  ?                      ; счётчик входов по вектору 75h
H16       DW  ?                      ; счётчик входов по вектору 16h
SW75v     DW  ?                      ; слово состояния, прочитанное внутри
CL75v     DW  ?                      ; код класса 0..7, определённый внутри
MS75v     DW  ?                      ; индекс печатного сообщения
SW16v     DW  ?
CL16v     DW  ?
MS16v     DW  ?
HBef75    DW  ?                      ; значение счётчика до нашего int 75h
HBef16    DW  ?
HBef75b   DW  ?                      ; до второго int 75h
CLmain1   DW  ?                      ; класс, определённый main (первый случай)
CLmain2   DW  ?                      ; класс, определённый main (второй случай)
; --- целые константы: плавающие литералы TASM 4.1 кодирует неверно ---
OneI      DW  1
ZeroI     DW  0
; --- приоритет: номера битов в ПОРЯДКЕ УБЫВАНИЯ приоритета ---
PrioBits  DB  0, 6, 2, 3, 4, 5, 1
FlNames   DB  'I ','D ','Z ','O ','U ','P ','SF','ES'
MskNames  DB  'I','D','Z','O','U','P'
; --- буферы ---
FB        DB  120 DUP(?)             ; FSAVE: заголовок 14 байт + 8 x 10 байт
Buf       DB  7 DUP(?)               ; рабочая область Pdec16

; --- имена классов, индекс = код класса (таблица ClsNames) ---
ClsNames  DW offset MsgC0I, offset MsgC1SF, offset MsgC2Z, offset MsgC3O
           DW offset MsgC4U, offset MsgC5P, offset MsgC6D, offset MsgC7None
; --- ответ FPU по умолчанию, A7.txt строки 85-96 (таблица ClsResp) ---
ClsResp   DW offset MsgR0I, offset MsgR1SF, offset MsgR2Z, offset MsgR3O
           DW offset MsgR4U, offset MsgR5P, offset MsgR6D, offset MsgR7None

;==============================================================
;  Строки вывода - ТОЛЬКО ASCII, ровно один '$' на строку.
;==============================================================
MsgCr       DB  13,10,'$'
MsgSp       DB  ' ','$'
MsgSp2      DB  '  ','$'
MsgEq       DB  '=','$'
MsgColon    DB  ':','$'
MsgOk       DB  'OK: it matches the value saved in section 1','$'
MsgBad      DB  'MISMATCH with the value saved in section 1!','$'
MsgPause    DB  '>>> Press any key to finish... ','$'
MsgDone     DB  '  lab7_4 is over: both vectors restored, CW back to 037Fh, flags cleared.',13,10,'$'

MsgTitle    DB  '=== Lab 7 step 4 (ASM): FPU special case - the handler reacts on the status word ===',13,10,'$'
MsgTitle2   DB  '  task A7.txt 33-36: unmask one class, provoke it, decode SW, enter the handler.','$'

MsgH1       DB  '--- 1) VECTORS AS FOUND BEFORE ANY CHANGE (int 21h/AH=35h gives ES:BX) ---',13,10,'$'
MsgV75      DB  '  vector 75h (math coprocessor, IRQ13, the path used when NE=0) = ','$'
MsgV16      DB  '  vector 16h (x87 exception,              path used when NE=1) = ','$'
MsgVnote1   DB  '  both values are saved here and restored in section 10: a .COM program that',13,10,'$'
MsgVnote2   DB  '  leaves its own address in the vector table breaks the next run of the box.','$'

MsgH2       DB  '--- 2) CR0 BY MACHINE CODE (.286 cannot encode MOV EAX,CR0; .386 breaks tlink /t) ---',13,10,'$'
MsgCR0      DB  '  CR0 hi:lo = ','$'
MsgNeLbl    DB  '  bit 16 of that value, called NE = ','$'
MsgCR0n1    DB  '  the number above is printed as two 16-bit halves ONLY. It is not used to',13,10,'$'
MsgCR0n2    DB  '  conclude anything about NE: this emulator returns an undefined CR0 for such',13,10,'$'
MsgCR0n3    DB  '  a probe (measured twice: 0000:0000h), so the NE bit is not readable here.',13,10,'$'
MsgCR0n4    DB  '  Per the documentation of a real PC the NE bit is normally 1 (the BIOS sets it).','$'

MsgH3       DB  '--- 3) INSTALL OUR OWN HANDLER (int 21h/AH=25h, DS:DX = handler address) ---',13,10,'$'
MsgInst75   DB  '  set vector 75h -> DS:DX = ','$'
MsgInst16   DB  '  set vector 16h -> DS:DX = ','$'
MsgRead75   DB  '  read vector 75h back (AH=35h) = ','$'
MsgRead16   DB  '  read vector 16h back (AH=35h) = ','$'
MsgInstOk   DB  '  both vectors now point to our handler; each of them has its own counter.','$'

MsgH4       DB  '--- 4) UNMASK EXACTLY ONE CLASS: Z = division by zero (clear CW bit 2) ---',13,10,'$'
MsgCWbef    DB  '  control word BEFORE  CW = ','$'
MsgCWaft    DB  '  control word AFTER   CW = ','$'
MsgOnlyZ    DB  '  (only the Z mask bit became 0)','$'
MsgOnlyI    DB  '  (only the I mask bit became 0)','$'
MsgMaskLbl  DB  '  exception mask bits of CW (A7.txt lines 134-140):',13,10,'$'
MsgMskd     DB  '  masked   -> the FPU handles it by itself, the program continues','$'
MsgUnmsk    DB  '  UNMASKED -> this class has to be reported to a software handler','$'

MsgH5       DB  '--- 5) PROVOKE THAT CLASS: 1.0 / 0.0, operands built FROM INTEGER constants ---',13,10,'$'
MsgOp1      DB  '  FILD word ptr OneI  -> ST(0) = 1.0',13,10,'$'
MsgOp2      DB  '  FILD word ptr ZeroI -> ST(0) = 0.0, therefore ST(1) = 1.0',13,10,'$'
MsgOp3      DB  '  FDIVP               -> ST(1) := ST(1)/ST(0) = 1.0/0.0, then the stack pops',13,10,'$'
MsgOp4      DB  '  FWAIT               -> synchronisation, so that SW is read afterwards',13,10,'$'
MsgOp5      DB  '  FSTSW SW1           -> the status word of the finished operation',13,10,'$'
MsgOp6      DB  '  no float literals in the data: TASM 4.1 encodes DD/DQ/DT with a decimal',13,10,'$'
MsgOp7      DB  '  value using nibbles swapped inside every byte (measured), so only the',13,10,'$'
MsgOp8      DB  '  integer constants above are safe (A7.txt 194-199 and 218-224 on WAIT).','$'

MsgH6       DB  '--- 6) STATUS WORD DECODED BIT BY BIT (FSTSW, A7.txt lines 154-185) ---',13,10,'$'
MsgSW0      DB  '  status word right after FINIT  SW = ','$'
MsgSWval    DB  '  status word SW = ','$'
MsgFlagsLbl DB  '  exception flags of bits 0..5 and the two summary bits 6 and 7:',13,10,'$'
MsgTopLbl   DB  '  TOP (bits 13..11) = ','$'
MsgC0lbl    DB  'C0(8) = ','$'
MsgC1lbl    DB  'C1(9) = ','$'
MsgC2lbl    DB  'C2(10) = ','$'
MsgC3lbl    DB  'C3(14) = ','$'
MsgBusyLbl  DB  'BUSY(15) = ','$'
MsgPrioChain DB '  priority chain (A7.txt 84-99; a stack fault is a part of invalid, lines 70, 86):',13,10,'$'
MsgPrioChain2 DB '    I(bit0) > SF(bit6) > Z(bit2) > O(bit3) > U(bit4) > P(bit5) > D(bit1) > none',13,10,'$'
MsgVerdict  DB  '  first class by priority = ','$'
MsgRespLbl  DB  '  default FPU response    = ','$'
MsgESobs    DB  '  ES (bit 7, error summary) = ','$'
MsgESn1     DB  '  measured, not assumed: the UNMASKED Z flag is set (bit 2 = 1) while the',13,10,'$'
MsgESn2     DB  '  summary bit ES (bit 7) stays 0. A test that looks only at ES would report',13,10,'$'
MsgESn3     DB  '  that nothing happened. The per-class flag in SW is the reliable evidence.','$'

MsgH7       DB  '--- 7) ENTER THE HANDLER: a SOFTWARE int 75h, the very vector used when NE=0 ---',13,10,'$'
MsgHbef     DB  '  handler entries BEFORE our int 75h:  75h = ','$'
MsgH16lbl   DB  '   16h = ','$'
MsgHbef2    DB  '  handler entries BEFORE the second int 75h: 75h = ','$'
MsgHbef2b   DB  '  (the one entry there is our own call of section 7)',13,10,'$'
MsgHwn1     DB  '  both counters read 0 at this moment: the case is FLAGGED in SW but it is',13,10,'$'
MsgHwn2     DB  '  NOT VECTORED by DOSBox 0.74-3 (measured). On real 8087/387 hardware the',13,10,'$'
MsgHwn3     DB  '  counters would already be 1 here - the CPU would stop the program and route',13,10,'$'
MsgHwn4     DB  '  control to the handler by itself. The int 75h below is OUR OWN call.',13,10,'$'

MsgH8       DB  '--- 8) WHAT THE HANDLER RECORDED (main prints it; a handler must not print) ---',13,10,'$'
MsgHaft     DB  '  handler entries AFTER  our int 75h:  75h = ','$'
MsgHdel     DB  '  entries made by our software int 75h: 75h = ','$'
MsgHdel16   DB  '   16h = ','$'
MsgHdeln    DB  '  the hardware path added nothing: before our call both counters were 0.',13,10,'$'
MsgHSW      DB  '  SW found inside the handler (its own FSTSW) = ','$'
MsgHflags   DB  '  the handler decoded that status word and got:',13,10,'$'
MsgHcls     DB  '  class decoded by the handler = ','$'
MsgHresp    DB  '  default FPU response         = ','$'
MsgHmsgidx  DB  '  message index stored in a global = ','$'
MsgHmsgidx2 DB  '  (the class code; main uses it to pick the printed text)','$'
MsgHcw      DB  '  CW after the handler (it did FLDCW of the saved mask) = ','$'
MsgHsw2     DB  '  SW after the handler (it did FCLEX)                   = ','$'
MsgAllMsk   DB  '  (all six classes masked again)','$'
MsgNotMsk   DB  '  (mask NOT fully restored!)','$'
MsgCleared  DB  '  (all exception flags cleared)','$'
MsgNotCleared DB '  (some exception flags are still set!)','$'
MsgCln      DB  '  FCLEX clears the six exception flags; C0..C3 are condition codes, not flags.','$'
MsgHcln1    DB  '  FCLEX is mandatory: while a flag stays set the NEXT FPU instruction would be',13,10,'$'
MsgHcln2    DB  '  counted as a special case again. The FLDCW done first stops a re-entry:',13,10,'$'
MsgHcln3    DB  '  FSTSW is a WAIT-form command (A7.txt 194-199) and with an unmasked flag it',13,10,'$'
MsgHcln4    DB  '  would be a second delivery point for the very same condition.',13,10,'$'
MsgReal1    DB  '  EOI (mov al,20h / out 20h,al) matters only for a real IRQ13 arrival.',13,10,'$'
MsgReal2    DB  '  Real hardware, A7.txt 105-110: NE=1 -> the CPU enters vector 16h itself;','$'
MsgSt0lbl   DB  '  NE=0 -> INT 75h / IRQ13. In this box only our own call reached vector 75h.',13,10,'$'
MsgSt0e     DB  '  ST(0) exponent:sign = ','$'
MsgSt0m     DB  '  mantissa hi..lo     = ','$'
MsgSt0k     DB  '  encoding = ','$'
MsgSt0n1    DB  '  Compare with A7.txt line 88: the answer of the FPU to division by zero is Inf.',13,10,'$'
MsgSt0n2    DB  '  Compare with A7.txt lines 86-87: the answer to an invalid operation is a NaN.',13,10,'$'
MsgIsInf    DB  'INFINITY (exponent all ones, mantissa exactly 1.0; A7.txt lines 235 and 247)','$'
MsgIsQNaN   DB  'QNaN (exponent all ones, mantissa MSB set; A7.txt lines 231-232)','$'
MsgIsSNaN   DB  'SNaN (exponent all ones, mantissa MSB clear; A7.txt lines 233-234)','$'
MsgIsFin    DB  'a finite value (the exponent is not all ones)','$'

MsgH9       DB  '--- 9) SECOND CLASS: unmask I (CW bit 0), take 0.0 / 0.0, decode, call again ---',13,10,'$'
MsgN1       DB  '  FLDZ / FLDZ -> ST(0) = 0.0 and ST(1) = 0.0; FDIVP -> ST(1) := 0.0/0.0, pop;',13,10,'$'
MsgN2       DB  '  FWAIT; both operands are zero, so the class here is I - invalid operation.',13,10,'$'
MsgRank0    DB  '  priority is the TABLE order (A7.txt 84-99), NOT the order of bits (168-174):',13,10,'$'
MsgRank1    DB  '    class            SW bit    priority rank    provoked in this run',13,10,'$'
MsgRank2    DB  '    I  invalid         0            1            yes - second experience',13,10,'$'
MsgRank3    DB  '    SF stack fault     6            2            no (a part of invalid)',13,10,'$'
MsgRank4    DB  '    Z  zero divide     2            3            yes - first experience',13,10,'$'
MsgRank5    DB  '    O  overflow        3            4            no',13,10,'$'
MsgRank6    DB  '    U  underflow       4            5            no',13,10,'$'
MsgRank7    DB  '    P  precision       5            6            no',13,10,'$'
MsgRank8    DB  '    D  denormal        1            7            no',13,10,'$'
MsgRankn1   DB  '  the two orders differ: D is bit 1 but ranks LAST, P is bit 5 yet outranks D,',13,10,'$'
MsgRankn2   DB  '  SF is bit 6 but ranks second. Scanning bits upward would pick D before P,',13,10,'$'
MsgRankn3   DB  '  which is wrong. Each of the two experiences above set exactly ONE exception',13,10,'$'
MsgRankn4   DB  '  flag - it is visible in the printed bit decode - so the chain order changes',13,10,'$'
MsgRankn5   DB  '  nothing here; it is what makes the verdict right when flags come in a set.','$'

MsgH10      DB  '--- 10) RESTORE BOTH VECTORS (int 21h/AH=25h) AND READ THEM BACK ---',13,10,'$'
MsgRest75   DB  '  restored vector 75h = ','$'
MsgRest16   DB  '  restored vector 16h = ','$'
MsgRestn1   DB  '  AH=25h takes the new vector from DS:DX, so DS is briefly the segment of the',13,10,'$'
MsgRestn2   DB  '  saved vector (0000h for 75h in this box); DOS only copies DS:DX into the',13,10,'$'
MsgRestn3   DB  '  table. CW is loaded back to 037Fh and FCLEX clears the flags afterwards.','$'

MsgH11      DB  '--- 11) WHY IT WORKS THIS WAY ---',13,10,'$'
MsgWhy1     DB  '  1. On a real 8087/387 an UNMASKED special case stops the program: the FPU',13,10,'$'
MsgWhy2     DB  '     raises its flag, the CPU vectors to INT 16h when NE=1 or to INT 75h /',13,10,'$'
MsgWhy3     DB  '     IRQ13 when NE=0, and the handler finds the CAUSE from the status word.',13,10,'$'
MsgWhy4     DB  '  2. In DOSBox 0.74-3 the flags accumulate but the interrupt is NOT generated',13,10,'$'
MsgWhy5     DB  '     (measured: entry counters 0, ES = 0, old vector 75h = 0000:0000h)',13,10,'$'
MsgWhy6     DB  '     so the reaction here is a flag analysis of SW plus a SOFTWARE int 75h',13,10,'$'
MsgWhy7     DB  '     into the same handler code, and the program prints that arrival as OURS.',13,10,'$'
MsgWhy8     DB  '  3. EOI is needed only on a real hardware arrival; FCLEX is needed always.',13,10,'$'

MsgC0I      DB  'I  - invalid operation (A7.txt lines 70, 86-87)','$'
MsgC1SF     DB  'SF - stack fault, a part of invalid (A7.txt lines 70, 86, 167)','$'
MsgC2Z      DB  'Z  - division by zero (A7.txt lines 72, 88)','$'
MsgC3O      DB  'O  - numeric overflow (A7.txt lines 74, 91-92)','$'
MsgC4U      DB  'U  - numeric underflow (A7.txt lines 75, 93-94)','$'
MsgC5P      DB  'P  - precision, an inexact result (A7.txt lines 76, 95-96)','$'
MsgC6D      DB  'D  - denormalized operand (A7.txt lines 73, 89-90)','$'
MsgC7None   DB  'none - no exception flag is set in this status word','$'

MsgR0I      DB  'QNaN for a stack fault, invalid for an SNaN operand (A7.txt 86-87)','$'
MsgR1SF     DB  'QNaN, the stack pointer is left as it is (A7.txt line 86)','$'
MsgR2Z      DB  '+infinity or -infinity (A7.txt line 88)','$'
MsgR3O      DB  '+Inf, -Inf, Nmax or Nmin depending on the rounding mode (A7.txt 91-92)','$'
MsgR4U      DB  'a denormalized operand or 0 (A7.txt lines 93-94)','$'
MsgR5P      DB  'the rounded result (A7.txt lines 95-96)','$'
MsgR6D      DB  'the denormalized operand, the rules tend to normalize it (A7.txt 89-90)','$'
MsgR7None   DB  'nothing to report: no unmasked condition in this status word','$'

END START
