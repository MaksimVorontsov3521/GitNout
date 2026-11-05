#include <stdio.h>
#include <conio.h>

int A[90] = {0,1,2,3,4,5,6,7,8,9};
int i, j;

void main(void)
{

    asm  mov si, 0;
    asm  mov di, 0;
e2:
    asm  lea bx, A;
    asm  add bx, si;
    asm  mov cx, 5;
e1:
    asm  mov [bx], di;
    asm  add bx, 2;
    asm  inc di;
    asm  loop e1;
    asm  add si, 10;
    asm  mov ax, 100;
    asm  cmp ax, si;
    asm  ja  e2;

    for (i = 0; i < 50; i = i + 5)
    {
        printf("\n");
        for (j = 0; j < 5; j++)
            printf("%6d", A[i + j]);
    }
    printf("\nPress any key...");
    getch();
}