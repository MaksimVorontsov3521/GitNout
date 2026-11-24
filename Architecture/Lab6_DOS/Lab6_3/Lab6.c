#include <stdio.h>
#include <dos.h>
#include <conio.h>

unsigned Dividend = 0x6068;         
unsigned Divisor  = 0x0000;         
unsigned Quotient = 0;              
unsigned Remainder= 0;              


int      IsrEntries   = 0;          
unsigned CaughtAX = 0, CaughtDX = 0, CaughtBX = 0;
unsigned FixedBX  = 0;              

void interrupt (*old_div0)();    

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

void interrupt isr_div0(unsigned wBP, unsigned wDI, unsigned wSI,
                        unsigned wDS, unsigned wES, unsigned wDX,
                        unsigned wCX, unsigned wBX, unsigned wAX)
{
    IsrEntries++;

    CaughtAX = wAX;                 
    CaughtDX = wDX;                 
    CaughtBX = wBX;                 

    if (wBX == 0) {                 
        wBX = 1;                    
        FixedBX = 1;
    }

}

void main(void)
{
    clrscr();
    puts("=== Lab6 step 3: subroutine called via an EXCEPTION (divide by zero) ===");
    puts("");

    
    printf("IVT[00h] before install : %04X:%04X\n", rdw(0, 2), rdw(0, 0));

    // 1. запомнить старый вектор, 2. установить новый
    old_div0 = getvect(0x00);
    disable();
    setvect(0x00, isr_div0);
    enable();
    printf("IVT[00h] after  install : %04X:%04X\n", rdw(0, 2), rdw(0, 0));
    puts("");

    printf("Dividend = %u (0x%04X),  Divisor = %u  -> DIV by zero\n",
           Dividend, Dividend, Divisor);
    puts("");

    // 3. возбудить особый случай: делимое и знаменатель в регистрах 
    asm mov  ax, Dividend
    asm mov  dx, 0
    asm mov  bx, Divisor
    asm div  bx                     

    
    asm mov  Quotient,  ax
    asm mov  Remainder, dx

    // 4. восстановить старый вектор ---- 
    disable();
    setvect(0x00, old_div0);
    enable();
    printf("IVT[00h] restored       : %04X:%04X\n", rdw(0, 2), rdw(0, 0));
    puts("");

    // 5. вывести результат ---- 
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
#ifndef NOWAIT                 
    getch();
#endif
}
