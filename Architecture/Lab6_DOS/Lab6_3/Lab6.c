/*==============================================================
  Лабораторная работа 6, ШАГ 3  (A6.txt, строки 48-50)

  Реализовать выполнение ПП путём создания ОСОБОГО СЛУЧАЯ
  (деление на нуль), соответствующего ОДНОМУ ИЗ ПЕРВЫХ ДЕСЯТИ
  векторов.

  Вектор 00h  - Divide Error (деление на нуль).  Он входит в
  диапазон 00h..09h (первые десять):
      00h деление на нуль, 01h TRAP (шаговый режим), 02h NMI,
      03h BREAKPOINT, 04h INTO (переполнение при INTO),
      05h BOUND, 06h INVALID OPCODE, 07h DEVICE NOT AVAILABLE,
      08h DOUBLE FAULT, 09h COPROCESSOR SEGMENT OVERRUN.

  ОТЛИЧИЕ ОТ ШАГА 1: особый случай возбуждается САМИМ
  процессором при невыполнимой операции, а не командой int.
  НО механизм заполнения стека тот же: FLAGS, CS, IP.

  Как и в шаге 1, ПП (обработчик) получает параметры и
  обрабатывает данные.  Здесь ПП "чинит" ситуацию: видит, что
  знаменатель = 0, и заменяет его в СВОЁМ стековом кадре на 1.
  После IRET процессор ПОВТОРНО выполняет команду DIV, уже с
  исправленным BX, - и деление завершается успешно.
  (Это классический приём обработки int 0: особый случай
   всегда ПОВТОРЯЕТ команду, если не изменить IP в кадре.)

  Сборка:  tcc -B -ms -nd:\build d:\Lab6.c     (задача VS Code)
  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab6_3
==============================================================*/
#include <stdio.h>
#include <dos.h>
#include <conio.h>

/* ----- параметры ПП (общая область памяти) ----- */
unsigned Dividend = 0x6068;         /* 24680 - делимое                     */
unsigned Divisor  = 0x0000;         /*  знаменатель = 0  -> особый случай  */
unsigned Quotient = 0;              /*  частное  (результат)               */
unsigned Remainder= 0;              /*  остаток  (результат)               */

/* ----- что реально прочитал обработчик ----- */
int      IsrEntries   = 0;          /* сколько раз вошли в ПП              */
unsigned CaughtAX = 0, CaughtDX = 0, CaughtBX = 0;
unsigned FixedBX  = 0;              /* чем обработчик заменил знаменатель  */

void interrupt (*old_div0)();    /* сохраняем старый вектор 00h         */

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
  ПП - программа обработки особого случая int 00h.

  Порядок параметров Borland C = содержимое стекового кадра:
     [bp+0]=BP  [bp+2]=DI  [bp+4]=SI  [bp+6]=DS  [bp+8]=ES
     [bp+10]=DX [bp+12]=CX [bp+14]=BX [bp+16]=AX
     [bp+18]=IP [bp+20]=CS [bp+22]=FLAGS   <- положил процессор
  Присваивание параметру = запись прямо в кадр, поэтому
  изменённый BX будет реально восстановлен при IRET.
  -------------------------------------------------------------*/
void interrupt isr_div0(unsigned wBP, unsigned wDI, unsigned wSI,
                        unsigned wDS, unsigned wES, unsigned wDX,
                        unsigned wCX, unsigned wBX, unsigned wAX)
{
    IsrEntries++;

    CaughtAX = wAX;                 /* делимое, которое было в AX   */
    CaughtDX = wDX;                 /* старшее слово делимого (0)   */
    CaughtBX = wBX;                 /* нулевой знаменатель          */

    if (wBX == 0) {                 /* особая ситуация -> исправляем */
        wBX = 1;                    /* запись в кадр [bp+14]         */
        FixedBX = 1;
    }
    /* IP ( [bp+18] ) НЕ трогаем: команда DIV выполнится повторно,
       но теперь с BX = 1, поэтому результат будет корректным. */
}

void main(void)
{
    /* IVT = 0000:0000 (вектор 00h) читаем по абсолютному адресу: rdw(0,0)=IP, rdw(0,2)=CS */

    clrscr();
    puts("=== Lab6 step 3: subroutine called via an EXCEPTION (divide by zero) ===");
    puts("");

    /* ---- старый вектор 00h (из IVT, абсолютный адрес 0000:0000) ---- */
    printf("IVT[00h] before install : %04X:%04X\n", rdw(0, 2), rdw(0, 0));

    /* ---- 1. запомнить старый вектор, 2. установить новый ---- */
    old_div0 = getvect(0x00);
    disable();
    setvect(0x00, isr_div0);
    enable();
    printf("IVT[00h] after  install : %04X:%04X\n", rdw(0, 2), rdw(0, 0));
    puts("");

    printf("Dividend = %u (0x%04X),  Divisor = %u  -> DIV by zero\n",
           Dividend, Dividend, Divisor);
    puts("");

    /* ---- 3. возбудить особый случай: делимое и знаменатель в регистрах
                (параметры ПП передаются РЕГИСТРАМИ и ПАМЯТЬЮ) ---- */
    asm mov  ax, Dividend
    asm mov  dx, 0
    asm mov  bx, Divisor
    asm div  bx                     /* 0/0 -> процессор возбуждает int 00h */

    /* сюда попадём ПОСЛЕ повторного выполнения div bx из обработчика */
    asm mov  Quotient,  ax
    asm mov  Remainder, dx

    /* ---- 4. восстановить старый вектор ---- */
    disable();
    setvect(0x00, old_div0);
    enable();
    printf("IVT[00h] restored       : %04X:%04X\n", rdw(0, 2), rdw(0, 0));
    puts("");

    /* ---- 5. вывести результат ---- */
    puts("--- results of the subroutine (PP) ---");
    printf("entries into the handler : %d\n", IsrEntries);
    printf("handler saw             : AX=%04X DX=%04X BX=%04X\n",
           CaughtAX, CaughtDX, CaughtBX);
    printf("handler fixed           : BX := %04X (record written into [bp+14])\n",
           FixedBX);
    puts("");
    printf("RESULT  %u / %u (fixed to %u) = %u  remainder %u\n",
           Dividend, 0, FixedBX, Quotient, Remainder);
    puts("");
    puts("NB: the DIV instruction was executed TWICE - the exception");
    puts("    mechanism re-executes the faulting instruction unless IP");
    puts("    ([bp+18]) is advanced by the handler.");

    puts("");
    puts("Press any key...");
#ifndef NOWAIT                 /* -DNOWAIT: пакетная самопроверка без ожидания клавиши */
    getch();
#endif
}
