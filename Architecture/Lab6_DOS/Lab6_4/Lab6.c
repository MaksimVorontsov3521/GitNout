/*==============================================================
  Лабораторная работа 6, ШАГ 4  (A6.txt, строки 51-53)

  Проанализировать ЗАПОЛНЕНИЕ СТЕКА при особом случае (деление
  на нуль, вектор 00h) и ПРИ ВЫХОДЕ ИЗ ОБРАБОТЧИКА ПРОПУСТИТЬ
  КОМАНДУ, ВЫЗЫВАЮЩУЮ ОСОБЫЙ СЛУЧАЙ:   add [bp+18], 2

  Почему именно 2 байта:  DIV BX = F7 /3  -> 2 машинных байта
  (F7 F3).  Прибавление 2 к IP в кадре переносит выполнение на
  команду, СЛЕДУЮЩУЮ за DIV, то есть особый случай больше не
  повторяется (сравните с шагом 3, где IP не менялся и DIV
  исполнился повторно).

  Структура стекового кадра обработчика void interrupt (TCC):
      [bp+0 ]=BP   [bp+2 ]=DI   [bp+4 ]=SI   [bp+6 ]=DS   [bp+8 ]=ES
      [bp+10]=DX   [bp+12]=CX   [bp+14]=BX   [bp+16]=AX   <- 9 слов,
                       сохраняет ПРОЛОГ КОМПИЛЯТОРА
      [bp+18]=IP   [bp+20]=CS   [bp+22]=FLAGS <- 3 слова,
                       их КЛАДЁТ САМ ПРОЦЕССОР при INT/особом случае
      [bp+24]=параметр FAR CALL (если вызов был FAR)

  Отсюда и [bp+18]: 24 байта пролога смещают IP-слот на bp+18.

  СБОР ДАННЫХ: обработчик НЕ печатает (printf не reentrant-safe в
  ПП), а только сохраняет кадр в глобальные массивы; вывод - main.

  Сборка:  tcc -B -ms -nd:\build d:\Lab6.c     (задача VS Code)
  Запуск:  DOSBox, Ctrl+Shift+B в открытой папке Lab6_4
==============================================================*/
#include <stdio.h>
#include <dos.h>
#include <conio.h>

/* ----- параметры ПП ----- */
unsigned Dividend  = 0x6068;        /* 24680                              */
unsigned Divisor   = 0x0000;        /* 0 -> особый случай int 00h         */
unsigned SafeDiv   = 0x0007;        /* чем ПП заменит нулевой делитель    */
unsigned Quotient  = 0;             /* частное  (придёт из кадра!)        */
unsigned Remainder = 0;             /* остаток  (придёт из кадра!)        */

/* ----- анализ стека ----- */
#define NWORDS 12                   /* bp+0 .. bp+22                      */
unsigned Frame[NWORDS];             /* снимок кадра обработчика           */
unsigned FrSS = 0, FrBP = 0;        /* SS:BP кадра                        */
unsigned SpMain = 0, SpIsr = 0;     /* SP до INT и внутри ПП             */
unsigned IpBefore = 0, IpAfter = 0; /* IP в кадре до/после add            */
unsigned CsIn = 0, FlIn = 0;        /* CS и FLAGS, положенные процессором */
int      Entries = 0;
int      DeltaSp = 0;               /* во сколько слов вырос стек          */


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

static const char *Slot[NWORDS] = {
    "[bp+0 ] BP",  "[bp+2 ] DI",  "[bp+4 ] SI",  "[bp+6 ] DS",
    "[bp+8 ] ES",  "[bp+10] DX",  "[bp+12] CX",  "[bp+14] BX",
    "[bp+16] AX",  "[bp+18] IP",  "[bp+20] CS",  "[bp+22] FLAGS"
};
static const char *Who[NWORDS] = {
    "prologue", "prologue", "prologue", "prologue", "prologue",
    "prologue", "prologue", "prologue", "prologue",
    "PROCESSOR", "PROCESSOR", "PROCESSOR"
};

void interrupt (*old_div0)();

/*--------------------------------------------------------------
  ПП: снимает кадр, выдаёт результат САМА (команда DIV будет
  пропущена!) и сдвигает IP в кадре на 2 байта.
  -------------------------------------------------------------*/
void interrupt isr_div0(unsigned wBP, unsigned wDI, unsigned wSI,
                        unsigned wDS, unsigned wES, unsigned wDX,
                        unsigned wCX, unsigned wBX, unsigned wAX)
{
    int i;

    Entries++;

    /* --- 1. снять адрес кадра и вершину стека --- */
    asm mov FrSS, ss
    asm mov FrBP, bp
    asm mov SpIsr, sp

    /* --- 2. скопировать весь кадр в массив анализа --- */
    for (i = 0; i < NWORDS; i++)
        Frame[i] = rdw(FrSS, FrBP + i * 2);

    IpBefore = Frame[9];
    CsIn     = Frame[10];
    FlIn     = Frame[11];

    /* --- 3. ОБРАБОТКА ДАННЫХ в ПП ---
          делитель нулевой, поэтому ПП считает сама и КЛАДЁТ результат
          прямо в чужие слоты кадра: AX <- частное, DX <- остаток.
          После IRET main прочитает их как ни в чём не бывало. */
    Quotient  = Dividend / SafeDiv;
    Remainder = Dividend % SafeDiv;

    wrw(FrSS, FrBP + 16, Quotient);      /* [bp+16] = AX  */
    wrw(FrSS, FrBP + 10, Remainder);     /* [bp+10] = DX  */

    /* --- 4. ПРОПУСК КОМАНДЫ, ВЫЗВАВШЕЙ ОСОБЫЙ СЛУЧАЙ --- */
    asm add word ptr [bp+18], 2                /* IP := IP + 2  */

    IpAfter = rdw(FrSS, FrBP + 18);
}

/* разбор флагов */
void PrintFlags(unsigned f)
{
    printf("FLAGS=%04X  CF=%d PF=%d AF=%d ZF=%d SF=%d TF=%d IF=%d\n",
           f, f & 1, (f >> 2) & 1, (f >> 4) & 1, (f >> 6) & 1,
           (f >> 7) & 1, (f >> 8) & 1, (f >> 9) & 1);
}

void main(void)
{
    int i;

    clrscr();
    puts("=== Lab6 step 4: stack fill of an EXCEPTION + skipping the faulting DIV ===");
    puts("");
    printf("Dividend = %u (0x%04X), Divisor = %u -> DIV BX raises int 00h\n",
           Dividend, Dividend, Divisor);
    puts("");

    old_div0 = getvect(0x00);
    disable();
    setvect(0x00, isr_div0);
    enable();

    /* --- SP до возбуждения особого случая --- */
    asm mov SpMain, sp

    asm mov  ax, Dividend
    asm mov  dx, 0
    asm mov  bx, Divisor
    asm div  bx                     /* особый случай; ПП пропустит её */

    /* выполнение продолжится СРАЗУ здесь (DIV исполнена не была) */
    asm mov  Quotient,  ax
    asm mov  Remainder, dx

    disable();
    setvect(0x00, old_div0);
    enable();

    /* --- 5. АНАЛИЗ ЗАПОЛНЕНИЯ СТЕКА --- */
    DeltaSp = (int)(SpMain - SpIsr);
    puts("--- 1) STACK FILL (snapshot taken inside the handler) ---");
    printf("SS = %04X   BP(frame) = %04X   SP inside PP = %04X\n",
           FrSS, FrBP, SpIsr);
    printf("SP before INT = %04X  ->  stack grew by %d bytes = %d words\n",
           SpMain, DeltaSp, DeltaSp / 2);
    puts("");
    printf("%-14s %-8s %s\n", "SLOT", "VALUE", "WHO PUSHED IT");
    for (i = 0; i < NWORDS; i++)
        printf("%-14s %04Xh     %s\n", Slot[i], Frame[i], Who[i]);
    puts("");
    puts("   9 words (BP..AX) are pushed by the COMPILER prologue,");
    puts("   3 words (IP, CS, FLAGS) are pushed by THE PROCESSOR.");
    puts("   Hence IP lives at bp+18 = 24 bytes above BP.  That is why");
    puts("   the assignment says:  add [bp+18], 2");
    puts("");

    puts("--- 2) RETURN ADDRESS AND FLAGS ---");
    printf("IP in frame before 'add' : %04X  (points AT the DIV instruction)\n", IpBefore);
    printf("IP in frame after  'add' : %04X  (points AFTER it, DIV +2 bytes)\n", IpAfter);
    printf("CS in frame              : %04X\n", CsIn);
    PrintFlags(FlIn);
    puts("");
    puts("   NB: TF and IF were cleared BY THE CPU at the moment of the");
    puts("       exception; the copy in the frame shows their OLD values.");
    puts("");

    puts("--- 3) RESULT SUPPLIED BY THE HANDLER THROUGH THE FRAME ---");
    printf("%u / %u = %u  remainder %u\n", Dividend, SafeDiv, Quotient, Remainder);
    printf("entries into PP = %d  (DIV was NOT re-executed: IP was moved)\n", Entries);
    puts("");
    puts("--- 4) COMPARISON WITH STEP 3 ---");
    puts("   step 3: IP untouched -> processor RE-EXECUTED DIV, PP fixed BX;");
    puts("   step 4: add [bp+18],2 -> DIV SKIPPED, PP wrote AX and DX.");
    puts("   Both push the same 3 words (FLAGS, CS, IP): exception and");
    puts("   software INT fill the stack identically; only the SOURCE of");
    puts("   the event differs (internal fault vs the INT instruction).");

    puts("");
    puts("Press any key...");
#ifndef NOWAIT                 /* -DNOWAIT: пакетная самопроверка без ожидания клавиши */
    getch();
#endif
}
