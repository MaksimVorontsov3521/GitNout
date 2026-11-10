#include <stdio.h>
#include <conio.h>

/* Глобальные переменные для результатов */
long res_near = 0;
long res_far = 0;

/* 
 * NEAR функция: сложение двух long через стек
 * Модель памяти: Tiny/Small
 */
void add_near(long a, long b, long *res) {
    asm mov ax, word ptr a        /* Младшее слово a */
    asm add ax, word ptr b        /* + младшее слово b */
    asm mov dx, word ptr a+2      /* Старшее слово a */
    asm adc dx, word ptr b+2      /* + старшее слово b + перенос */
    
    /* Запись результата по указателю res */
    asm mov di, word ptr res      /* DI = адрес результата */
    asm mov [di], ax              /* Младшее слово */
    asm mov [di+2], dx            /* Старшее слово */
}

/* 
 * FAR функция: сложение двух long через стек
 * Модель памяти: Large
 */
void far add_far(long a, long b, long far *res) {
    asm mov ax, word ptr a        /* Младшее слово a */
    asm add ax, word ptr b        /* + младшее слово b */
    asm mov dx, word ptr a+2      /* Старшее слово a */
    asm adc dx, word ptr b+2      /* + старшее слово b + перенос */
    
    /* Запись результата по FAR указателю res (сегмент:смещение) */
    asm mov di, word ptr res      /* DI = смещение */
    asm mov es, word ptr res+2    /* ES = сегмент */
    asm mov es:[di], ax           /* Младшее слово */
    asm mov es:[di+2], dx         /* Старшее слово */
}

void main(void) {
    long num1 = 0x12345678L;
    long num2 = 0x87654321L;

    clrscr();
    
    printf("Operand 1: 0x%08lX\n", num1);
    printf("Operand 2: 0x%08lX\n\n", num2);

    /* NEAR вызов */
    add_near(num1, num2, &res_near);
    printf("Result (NEAR): 0x%08lX\n", res_near);

    /* FAR вызов */
    add_far(num1, num2, &res_far);
    printf("Result (FAR):  0x%08lX\n", res_far);

    getch();
}