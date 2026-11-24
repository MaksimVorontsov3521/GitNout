#include <stdio.h>
#include <dos.h>
#include <conio.h>

unsigned Dividend  = 0x6068;
unsigned Divisor   = 0x0000;
unsigned SafeDiv   = 0x0007;
unsigned Quotient  = 0;
unsigned Remainder = 0;

#define NWORDS 12
unsigned Frame[NWORDS];
unsigned FrSS = 0, FrBP = 0;
unsigned SpMain = 0, SpIsr = 0;
unsigned IpBefore = 0, IpAfter = 0;
unsigned CsIn = 0, FlIn = 0;
int Entries = 0;
int DeltaSp = 0;

static unsigned rdw(unsigned seg, unsigned ofs)
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

void interrupt isr_div0(unsigned wBP, unsigned wDI, unsigned wSI,
                        unsigned wDS, unsigned wES, unsigned wDX,
                        unsigned wCX, unsigned wBX, unsigned wAX)
{
    int i;

    Entries++;

    // 1. Снять адрес кадра и вершину стека
    asm mov FrSS, ss
    asm mov FrBP, bp
    asm mov SpIsr, sp

    // 2. Скопировать весь кадр в массив анализа
    for (i = 0; i < NWORDS; i++)
        Frame[i] = rdw(FrSS, FrBP + i * 2);

    IpBefore = Frame[9];
    CsIn     = Frame[10];
    FlIn     = Frame[11];

    // 3. Обработка данных в ПП
    Quotient  = Dividend / SafeDiv;
    Remainder = Dividend % SafeDiv;

    wrw(FrSS, FrBP + 16, Quotient);
    wrw(FrSS, FrBP + 10, Remainder);

    // 4. Пропуск команды, вызвавшей особый случай
    asm add word ptr [bp+18], 2

    IpAfter = rdw(FrSS, FrBP + 18);
}

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

    asm mov SpMain, sp

    asm mov  ax, Dividend
    asm mov  dx, 0
    asm mov  bx, Divisor
    asm div  bx

    asm mov  Quotient,  ax
    asm mov  Remainder, dx

    disable();
    setvect(0x00, old_div0);
    enable();

    // 5. Анализ заполнения стека
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
#ifndef NOWAIT
    getch();
#endif
}