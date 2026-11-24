#include <stdio.h>
#include <conio.h>


int mem_op1 = 100;
int mem_op2 = 200;
int mem_result = 0;


/* Передача параметров через регистры */

int add_via_registers(int a, int b) {
    int res;
    asm mov ax, a
    asm mov bx, b 
    asm add ax, bx
    asm mov res, ax
    return res; 
}

/* Передача параметров через память */

void add_via_memory(void) {
    asm mov ax, mem_op1
    asm add ax, mem_op2
    asm mov mem_result, ax
}

void main(void) {
    int reg_res;

    clrscr();

    printf("1. Transfer registers (AX, BX):\n");
    printf("   Input data: 500 & 250\n");
    
    reg_res = add_via_registers(500, 250);
    
    printf("   Result: %d\n\n", reg_res);

    printf("2. Transfer via a shared memory area:\n");
    printf("   Initial data: mem_op1=%d, mem_op2=%d\n", mem_op1, mem_op2);
    
    add_via_memory();
    
    printf("   Result (mem_result): %d\n", mem_result);

    getch();
}