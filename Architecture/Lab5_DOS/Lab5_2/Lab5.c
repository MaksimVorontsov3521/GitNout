#include <stdio.h>
#include <conio.h>

long res_near = 0;
long res_far  = 0;


void add_near(long a, long b, long *res) {
    asm push di
    asm mov ax, word ptr a
    asm add ax, word ptr b
    asm mov dx, word ptr a+2
    asm adc dx, word ptr b+2
    asm mov di, word ptr res
    asm mov [di],   ax
    asm mov [di+2], dx
    asm pop di
}

void far add_far(long a, long b, long far *res) {
    asm push di
    asm push es
    asm mov ax, word ptr a
    asm add ax, word ptr b
    asm mov dx, word ptr a+2
    asm adc dx, word ptr b+2
    asm mov di, word ptr res
    asm mov bx, word ptr res+2
    asm mov es, bx
    asm mov es:[di],   ax
    asm mov es:[di+2], dx
    asm pop es
    asm pop di
}

void main(void) {
    long num1 = 0x12345678L;
    long num2 = 0x87654321L;

    clrscr();

    printf("Operand 1: 0x%08lX\n", num1);
    printf("Operand 2: 0x%08lX\n\n", num2);

    add_near(num1, num2, &res_near);
    printf("Result (NEAR): 0x%08lX\n", res_near);

    add_far(num1, num2, (long far *)&res_far);
    printf("Result (FAR):  0x%08lX\n", res_far);

    getch();
}