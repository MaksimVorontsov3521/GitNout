// Lab Work N 0
// Measuring the execution time of a program fragment
// Students of group 000.0 Ivanoff, Petrof, & Sidoroff

#include <dos.h>
#include <bios.h>
#include <stdio.h>
#include <conio.h>

#define PortCan0 0x40

void beep(unsigned iTone, unsigned iDlit);  // Prototype (not used now)

void main(void)
{
    // --- Variable declarations (C89: all at the top) ---
    long int lCnt = 0;          // Repetition counter for C loop
    int iA = 0x1234;            // Dummy variable used in the instruction under test
    char far *pT;
    int i;
    unsigned char Tmm;
    long far *pTime;
    int Time;
    long startTicks, endTicks;  // For tick measurement
    long cLoopTicks, asmLoopTicks; // Results

    // --- Part 1: Reading memory via far pointer ---
    pT = (char *)0x46C;
    printf("\n Printing 10 times the value of the byte at a known address \n");
    for (i = 0; i < 10; i++) {
        printf(" \n  %d ", *pT);
    }

    printf("\n Press any key to continue \n");
    getch();

    // --- Part 2: Reading port 0x40 via C function ---
    printf("\n Reading the port at address 40 using C functions \n");
    printf("\n Press any key to exit the loop \n");

    while (bioskey(1) == 0) {
        printf(" \n Port40 = %d ", inp(PortCan0));
        delay(500);
    }
    getch();

    // --- Part 3: Reading port 0x40 via inline assembly ---
    printf("\n Reading the port at address 40 using assembly \n");

    while (bioskey(1) == 0) {
        asm {
            push ax
            in al, 0x40
        }
        Tmm = _AL;
        asm pop ax
        delay(500);
        printf(" \n Port40 = %d ", Tmm);
    }
    getch();

    printf("\n Press any key to continue \n ");
    getch();

    // --- Part 4: Reading long variable from 0x46C via C ---
    pTime = (long *)0x46C;  // Pointer to the tick counter

    while (bioskey(1) == 0) {
        printf("\n %ld", *pTime);
        delay(1000);
    }
    getch();

    // --- Part 5: Reading two-byte variable from 0x46C via assembly ---
    while (bioskey(1) == 0) {
        asm push ds
        asm push si
        asm mov ax, 40h
        asm mov ds, ax
        asm mov si, 0x6C
        asm mov ax, [ds:si]
        asm mov Time, ax
        asm pop si
        asm pop ds

        printf("\n %d", Time);
        delay(300);
    }
    getch();

    // ============================================================
    // TIMING SECTION
    // ============================================================
    printf("\n\n--- Timing measurement using system ticks at 0x46C ---\n");

    // --- Measure C loop ---
    printf("\n Running C loop (1,000,000 iterations of 10 MOVs)...\n");
    startTicks = *pTime;

    for (lCnt = 0; lCnt < 1000000; lCnt++) {
a1:
        asm {
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
            mov ax, iA
a2:
            mov ax, iA
        }
    }

    endTicks = *pTime;
    cLoopTicks = endTicks - startTicks;
    printf(" C loop took %ld ticks.\n", cLoopTicks);


    // --- Measure assembly loop ---
    beep(400, 200);
    // --- Measure assembly loop ---
    // --- Measure assembly loop (pure assembly, 2 nested loops) ---
    printf("\n Running assembly loop (100 * 10000 = 1,000,000 iterations)...\n");
    startTicks = *pTime;

    asm {
        push bx
        push cx
        mov bx, 100         // Внешний счётчик: 100 итераций
    }

outer_loop:                 // C-метка для внешнего цикла
    asm {
        mov cx, 10000       // Внутренний счётчик: 10000 итераций
    }

inner_loop:                 // C-метка для внутреннего цикла
    asm {
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        mov ax, iA
        loop inner_loop     // Уменьшить CX и перейти, если CX != 0
        dec bx              // Уменьшить внешний счётчик
        jnz outer_loop      // Перейти, если BX != 0
        pop cx
        pop bx
    }

    endTicks = *pTime;
    asmLoopTicks = endTicks - startTicks;
    beep(400, 200);
    printf(" Assembly loop took %ld ticks.\n", asmLoopTicks);
    getch();
}

// Sound function (kept for reference, but not used)
void beep(unsigned iTone, unsigned iDlit)
{
    sound(iTone);
    delay(iDlit);
    nosound();
}