#include <stdio.h>
#include <dos.h>
#include <conio.h>


unsigned memA    = 0x1234;              
unsigned memB    = 0x0007;              
unsigned memSum  = 0;                   
unsigned memProd = 0;                   


unsigned regIn1  = 0x00A5;              
unsigned regIn2  = 0x001C;              
unsigned regSum  = 0;                   
unsigned gotAX   = 0, gotBX = 0;        


int      hits        = 0;               
unsigned flagsBefore = 0;               
unsigned flagsAfter  = 0;               
unsigned ivtOldOfs = 0, ivtOldSeg = 0;  
unsigned ivtNewOfs = 0, ivtNewSeg = 0;  
unsigned ivtResOfs = 0, ivtResSeg = 0;  

void interrupt (*old_f0)();


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


/* Программа обработки прерывания (ПП). */
void interrupt isr_f0(unsigned bp, unsigned di, unsigned si,
                      unsigned ds, unsigned es, unsigned dx,
                      unsigned cx, unsigned bx, unsigned ax)
{
    hits++;

    gotAX = ax; 
    gotBX = bx;

    memSum  = memA + memB;
    memProd = memA * memB;

    regSum  = ax + bx;
}

void main(void)
{
    clrscr();
    puts("=== Lab6 step 1: software interrupt INT 0xF0 as a subroutine call ===");
    puts("");

    /* 1. запомнить старый вектор прерывания*/
    old_f0    = getvect(0xF0);
    ivtOldOfs = rdw(0, 0xF0 * 4);
    ivtOldSeg = rdw(0, 0xF0 * 4 + 2);

    /* 2 Установить новый вектор*/
    disable();
    setvect(0xF0, isr_f0);
    enable();
    ivtNewOfs = rdw(0, 0xF0 * 4);
    ivtNewSeg = rdw(0, 0xF0 * 4 + 2);

    printf("IVT[0xF0] before install : %04X:%04X\n", ivtOldSeg, ivtOldOfs);
    printf("IVT[0xF0] after  install : %04X:%04X\n", ivtNewSeg, ivtNewOfs);
    puts("");

    /*3a Параметры в памяти, вызов через geninterrupt()*/
    asm pushf
    asm pop  ax
    asm mov  flagsBefore, ax

    geninterrupt(0xF0);           /* программное прерывание*/

    asm pushf
    asm pop  ax
    asm mov  flagsAfter, ax

    /* 3b Параметры в регистрах: загрузка и INT подряд, чтобы компилятор ничего не перезаписал между ними*/
    asm push ax
    asm push bx
    asm mov  ax, regIn1
    asm mov  bx, regIn2
    asm int  0F0h
    asm pop  bx
    asm pop  ax



    disable();
    setvect(0xF0, old_f0);
    enable();
    ivtResOfs = rdw(0, 0xF0 * 4);
    ivtResSeg = rdw(0, 0xF0 * 4 + 2);



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
#ifndef NOWAIT
    getch();
#endif
}
