/*==============================================================
  Лабораторная работа 6, ШАГ 1  (A6.txt, строки 42-46)

  Реализовать выполнение ПП (подпрограммы) через ПРОГРАММНОЕ
  ПРЕРЫВАНИЕ командой int:
     - запомнить старый вектор прерывания   -> getvect(0xF0)
     - установить новый вектор               -> setvect(0xF0, isr)
     - ввести параметры ПП                  -> память и регистры
     - выполнить программное прерывание      -> geninterrupt(0xF0)
     - обработать данные внутри ПП           -> сумма, произведение
     - выйти в основную программу           -> iret (генерирует компилятор)
     - вывести результат                    -> printf в main
     - восстановить старый вектор            -> setvect(0xF0, old_f0)

  Вектор 0xF0 - пользовательский (разрешённый): он не занят ни DOS,
  ни BIOS, ни аппаратными источниками.

  Параметры ПП передаются ДВУМЯ способами (оба разбираются в отчёте):
     (a) общая область памяти - глобальные переменные Си,
         к ним обращаемся из встроенного ассемблера по offset;
     (b) регистры процессора  - AX/BX загружаются перед int,
         обработчик читает их из СВОЕГО стекового кадра
         (порядок параметров Borland: bp, di, si, ds, es, dx, cx, bx, ax).

  Сборка:  tcc -B -ms -nd:\build d:\Lab6.c     (задача VS Code)
  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab6_1
==============================================================*/
#include <stdio.h>
#include <dos.h>
#include <conio.h>

/* ---------- (a) параметры через ОБЩУЮ ОБЛАСТЬ ПАМЯТИ ---------- */
unsigned memA    = 0x1234;              /* 1-й операнд            */
unsigned memB    = 0x0007;              /* 2-й операнд            */
unsigned memSum  = 0;                   /* результат работы ПП    */
unsigned memProd = 0;                   /* второй результат ПП    */

/* ---------- (b) параметры через РЕГИСТРЫ ---------- */
unsigned regIn1  = 0x00A5;              /* передадим в AX         */
unsigned regIn2  = 0x001C;              /* передадим в BX         */
unsigned regSum  = 0;                   /* результат работы ПП    */
unsigned gotAX   = 0, gotBX = 0;        /* что обработчик прочёл  */

/* ---------- служебная информация ---------- */
int      hits        = 0;               /* число входов в ПП      */
unsigned flagsBefore = 0;               /* FLAGS до int           */
unsigned flagsAfter  = 0;               /* FLAGS после возврата   */
unsigned ivtOldOfs = 0, ivtOldSeg = 0;  /* старый вектор  (IVT)   */
unsigned ivtNewOfs = 0, ivtNewSeg = 0;  /* новый   вектор  (IVT)  */
unsigned ivtResOfs = 0, ivtResSeg = 0;  /* восстановленный вектор */

void interrupt (*old_f0)();          /* сюда сохраняем старый вектор */

/*--------------------------------------------------------------
  Доступ по абсолютному адресу seg:ofs.

  Макросы peek/poke/MK_FP в DOS.H объявлены под условием
  #if !__STDC__ (DOS.H, строки 238-249), поэтому в ANSI-режиме TCC
  они НЕвидны, и #undef __STDC__ перед #include <dos.h> не помогает.
  Читаем и пишем по абсолютному адресу собственным ассемблером.
--------------------------------------------------------------*/
static unsigned rdw(unsigned seg, unsigned ofs)     /* слово по seg:ofs */
{
    unsigned r;
    asm push ds
    asm mov  ax, seg
    asm mov  ds, ax
    asm mov  bx, ofs
    asm mov  ax, word ptr [bx]
    asm mov  r, ax
    asm pop  ds
    return r;
}

static void wrw(unsigned seg, unsigned ofs, unsigned v)
{
    asm push ds
    asm mov  ax, seg
    asm mov  ds, ax
    asm mov  bx, ofs
    asm mov  ax, v
    asm mov  word ptr [bx], ax
    asm pop  ds
}


/*--------------------------------------------------------------
  Программа обработки прерывания (ПП).

  Обработчик прерывания ВСЕГДА far; компилятор сам:
     - сохраняет регистры в кадр (9 слов: ax..bp),
     - оформляет возврат командой IRET.
  Параметры-регистры лежат в кадре так:
     [bp+0]=BP  [bp+2]=DI  [bp+4]=SI  [bp+6]=DS  [bp+8]=ES
     [bp+10]=DX [bp+12]=CX [bp+14]=BX [bp+16]=AX
     [bp+18]=IP [bp+20]=CS [bp+22]=FLAGS   <- кадр самого INT
  -------------------------------------------------------------*/
void interrupt isr_f0(unsigned bp, unsigned di, unsigned si,
                      unsigned ds, unsigned es, unsigned dx,
                      unsigned cx, unsigned bx, unsigned ax)
{
    hits++;                       /* фиксируем вход в ПП */

    gotAX = ax;                   /* значения регистров в момент прерывания */
    gotBX = bx;

    memSum  = memA + memB;        /* обработка данных из общей памяти  */
    memProd = memA * memB;        /* (младшие 16 бит произведения)     */

    regSum  = ax + bx;            /* обработка данных из регистров     */
}

void main(void)
{
    clrscr();
    puts("=== Lab6 step 1: software interrupt INT 0xF0 as a subroutine call ===");
    puts("");

    /* ---- 1. запомнить старый вектор прерывания ---- */
    old_f0    = getvect(0xF0);
    ivtOldOfs = rdw(0, 0xF0 * 4);        /* слово IP   в IVT[0xF0] */
    ivtOldSeg = rdw(0, 0xF0 * 4 + 2);    /* слово CS   в IVT[0xF0] */

    /* ---- 2. установить новый вектор (IVT правим с IF=0) ---- */
    disable();
    setvect(0xF0, isr_f0);
    enable();
    ivtNewOfs = rdw(0, 0xF0 * 4);
    ivtNewSeg = rdw(0, 0xF0 * 4 + 2);

    printf("IVT[0xF0] before install : %04X:%04X\n", ivtOldSeg, ivtOldOfs);
    printf("IVT[0xF0] after  install : %04X:%04X\n", ivtNewSeg, ivtNewOfs);
    puts("");

    /* ---- 3a. параметры в ПАМЯТИ, вызов через geninterrupt() ---- */
    asm pushf
    asm pop  ax
    asm mov  flagsBefore, ax

    geninterrupt(0xF0);           /* программное прерывание = вызов ПП */

    asm pushf
    asm pop  ax
    asm mov  flagsAfter, ax

    /* ---- 3b. параметры в РЕГИСТРАХ: загрузка и INT подряд,
                чтобы компилятор ничего не перезаписал между ними ---- */
    asm push ax
    asm push bx
    asm mov  ax, regIn1
    asm mov  bx, regIn2
    asm int  0F0h
    asm pop  bx
    asm pop  ax

    /* ---- 4. восстановить старый вектор ---- */
    disable();
    setvect(0xF0, old_f0);
    enable();
    ivtResOfs = rdw(0, 0xF0 * 4);
    ivtResSeg = rdw(0, 0xF0 * 4 + 2);

    /* ---- 5. вывести результат ---- */
    puts("--- results of the subroutine (PP) ---");
    printf("entries into the handler   : %d\n", hits);
    printf("(a) shared memory : A=%04X B=%04X -> SUM=%04X PROD=%04X\n",
           memA, memB, memSum, memProd);
    printf("(b) registers     : AX=%04X BX=%04X -> SUM=%04X\n",
           regIn1, regIn2, regSum);
    printf("    handler really read : AX=%04X BX=%04X\n", gotAX, gotBX);
    puts("");
    printf("FLAGS before INT  = %04X\n", flagsBefore);
    printf("FLAGS after return= %04X   (IF/TF restored by IRET)\n", flagsAfter);
    puts("");
    printf("IVT[0xF0] restored         : %04X:%04X\n", ivtResSeg, ivtResOfs);

    puts("");
    puts("Press any key...");
#ifndef NOWAIT                 /* -DNOWAIT: пакетная самопроверка без ожидания клавиши */
    getch();
#endif
}
