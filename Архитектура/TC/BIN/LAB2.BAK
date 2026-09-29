/* Lab2_3rd_column.c
   Turbo C++ / Borland C++ (DOS)
   Команды 3-го столбца: SUB, XOR, JL, ROL
*/

#include <stdio.h>
#include <conio.h>

int main() {
    int res;
    int arr[4] = {0x1111, 0x2222, 0x3333, 0x4444};
    int *p = arr;

    clrscr();

    /* ================== SUB ================== */
    printf("=== SUB ===\n");

    asm {
        mov ax, 0x5000
        mov bx, 0x1234
        sub ax, bx
        mov res, ax
    }
    printf("sub ax,bx      => %04X\n", res);

    asm {
        mov bx, p
        mov ax, 0x5000
        sub ax, [bx]
        mov res, ax
    }
    printf("sub ax,[bx]    => %04X\n", res);

    asm {
        mov ax, 0x1000
        mov bx, 0x5000
        sub bx, ax
        mov res, bx
    }
    printf("sub bx,ax      => %04X\n", res);

    asm {
        mov bx, p
        mov ax, 0x5000
        sub ax, [bx+2]
        mov res, ax
    }
    printf("sub ax,[bx+2]  => %04X\n", res);

    /* ================== XOR ================== */
    printf("\n=== XOR ===\n");

    asm {
        mov ax, 0x0F0F
        mov bx, 0x00FF
        xor ax, bx
        mov res, ax
    }
    printf("xor ax,bx      => %04X\n", res);

    asm {
        mov bx, p
        mov ax, 0xFFFF
        xor ax, [bx]
        mov res, ax
    }
    printf("xor ax,[bx]    => %04X\n", res);

    asm {
        mov ax, 0xAAAA
        mov bx, 0x5555
        xor bx, ax
        mov res, bx
    }
    printf("xor bx,ax      => %04X\n", res);

    asm {
        mov bx, p
        mov ax, 0xFFFF
        xor ax, [bx+2]
        mov res, ax
    }
    printf("xor ax,[bx+2]  => %04X\n", res);

    /* ================== JL ================== */
    printf("\n=== JL ===\n");
    {
        int a = 5, b = 10;
        int result = 0;

        asm mov ax, a
        asm mov bx, b
        asm cmp ax, bx
        asm jl  less_label
        goto not_less_label;

    less_label:
        result = 1;
        goto done_label;

    not_less_label:
        result = 0;

    done_label:
        printf("JL: %d < %d ? %d\n", a, b, result);
    }

    /* ================== ROL ================== */
    printf("\n=== ROL ===\n");

    asm {
        mov ax, 0xA00A
        rol ax, 1
        mov res, ax
    }
    printf("rol ax,1       => %04X\n", res);

    asm {
        mov ax, 0xA00A
        mov cl, 2
        rol ax, cl
        mov res, ax
    }
    printf("rol ax,cl (2)  => %04X\n", res);

    /* rol ax,3 через три rol ax,1 (набор 8086) */
    asm {
        mov ax, 0xA00A
        rol ax, 1
        rol ax, 1
        rol ax, 1
        mov res, ax
    }
    printf("rol ax,3       => %04X\n", res);

    getch();
    return 0;
}