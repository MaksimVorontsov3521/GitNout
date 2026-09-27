// Lab Work N 0
// Measuring the execution time of a program fragment
// Students of group 000.0 Ivanoff, Petrof, & Sidoroff

#include <dos.h>
#include <bios.h>
#include <stdio.h>
#include <conio.h>

#define PortCan0 0x40

void beep(unsigned iTone, unsigned iDlit);  // Prototype of the sound function

void main(void)
{
    // Variable declarations (C89 requires all declarations at the top)
    long int lCnt = 0;   // Repetition counter
    int iA = 0x1234;     // Dummy variable used in the instruction under test
    char far *pT;
    int i;
    unsigned char Tmm;
    long far *pTime;
    int Time;

    /************************************************
     * How to view the contents of a byte at a known
     * physical address in C
     ************************************************/
    // If we want to print the contents of the byte at address 0046Ch,
    // declare a far pointer to a char variable and initialize
    // this pointer with the address value, having previously cast it to char *
    pT = (char *)0x46C;  // (1)

    printf("\n Printing 10 times the value of the byte at a known address \n");
    
    // Removed 'int' from the loop for C89 compliance
    for (i = 0; i < 10; i++) {
        printf(" \n  %d ", *pT);   // (1)
    }

    printf("\n Press any key to continue \n");
    getch();  // Wait for a keypress

    /************************************************
     * How to view the contents of a port in C
     ************************************************/
    // Reading the port at address 40 using C functions
    printf("\n Reading the port at address 40 using C functions \n");
    // The loop repeats every 0.5 seconds
    printf("\n Press any key to exit the loop \n");

    while (bioskey(1) == 0)  // until any key is pressed
    {
        printf(" \n Port40 = %d ", inp(PortCan0));  // (2)
        // Use Turbo Debugger to see how the inp() function translates
        // into machine instructions
        delay(500);  // 500 ms delay
    }

    getch();  // Clear keyboard buffer

    /************************************************
     * Notes:
     * The printf(...) function allows you to print variable values
     * and arbitrary text on the screen.
     * The bioskey(1) function allows you to check if a key is pressed.
     * The inp(uPort) function allows you to read a byte from the Port.
     * The outp(uPort, iValue) function allows you to output the iValue
     * to the uPort.
     * The delay(uTime) function creates a software delay for uTime
     * milliseconds.
     * The getch() function reads a single character from the keyboard buffer.
     *
     * In this case, it is needed to clear the keyboard buffer.
     ************************************************/

    // Reading the same port again using inline assembly
    printf("\n Reading the port at address 40 using assembly \n");

    while (bioskey(1) == 0)  // This loop will repeat until a key is pressed
    {
        // Examples of using inline assembly (3)
        asm {
            push ax   // Inline assembly syntax variant 1
            in al, 0x40
        }

        Tmm = _AL;  // This is equivalent to mov Tmm, al
                    // !! Verify this with Turbo Debugger

        asm pop ax  // Inline assembly syntax variant 2

        delay(500);
        printf(" \n Port40 = %d ", Tmm);
        // If a key is pressed - exit
    }

    getch();

    printf("\n Press any key to continue \n ");
    getch();

    /************************************************
     * How to view the contents of a long (e.g.,
     * four-byte) variable at address 0046C
     * using C tools
     ************************************************/
    pTime = (long *)0x46C;  // Pointer to the tick counter

    while (bioskey(1) == 0)
    {
        printf("\n %ld", *pTime);
        delay(1000);
    }

    getch();

    // Reading and printing the contents of a two-byte variable
    // at address 0046C using inline assembly
    while (bioskey(1) == 0)
    {
        asm push ds       // Save registers just in case
        asm push si

        // In inline assembly
        asm mov ax, 40h   // hex constants can be written like this ...
        asm mov ds, ax
        asm mov si, 0x6C  // ... or like this
        asm mov ax, [ds:si]
        asm mov Time, ax

        asm pop si        // Now restore the registers
        asm pop ds        // (do not mix up the order !!!)

        printf("\n %d", Time);
        delay(300);
    }

    /************************************************
     * Example of completing a Type I task
     * You need to measure the execution time of a given instruction
     * (in the example - the mov reg, mem instruction, but ask your
     * teacher which instruction you should take).
     * Measuring execution time of a code fragment
     ************************************************/
    beep(400, 200);  // Signal marks the start of the interval (5)

    for (lCnt = 0; lCnt < 1000000; lCnt++)
    {
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

    beep(400, 200);  // Signal marks the end of the interval (5)
}

// Function to produce a sound signal of a given tone and duration (5)
void beep(unsigned iTone, unsigned iDlit)
{
    sound(iTone);
    delay(iDlit);
    nosound();
}