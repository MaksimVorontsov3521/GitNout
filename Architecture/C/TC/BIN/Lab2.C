#include <stdio.h>
#include <string.h>
#include <conio.h>
#include <dos.h> /* Для FP_SEG, FP_OFF, MK_FP */

/* =========================================================
 * ЗАДАНИЕ 1
 * ========================================================= */
void task1(void)
{
    int a = 10, b = 3;
    int arr[4] = { 100, 200, 300, 400 };
    int r_sub, r_xor, r_rol;
    int jump_taken = 0;

    asm {
        mov ax, a
        mov bx, b
        sub ax, bx
        mov r_sub, ax
    }

    asm {
        mov ax, a
        lea bx, arr
        sub ax, [bx]
    }

    asm {
        mov ax, a
        lea bx, arr
        sub [bx], ax
    }

    asm {
        mov ax, a
        lea bx, arr
        sub ax, [bx+4]
    }

    asm {
        mov ax, a
        mov bx, b
        xor ax, bx
        mov r_xor, ax
    }

    asm {
        mov ax, a
        mov bx, b
        cmp ax, bx
        jl  jl_taken_1
        mov jump_taken, 0
        jmp jl_done_1
    jl_taken_1:
        mov jump_taken, 1
    jl_done_1:
    }

    asm {
        mov ax, a
        rol ax, 2
        mov r_rol, ax
    }

    printf("sub=%d xor=%d jl=%d rol=%d\n", r_sub, r_xor, jump_taken, r_rol);
}

/* =========================================================
 * ЗАДАНИЕ 2
 * ========================================================= */
void task2(void)
{
    int A[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    int B[10] = { 0 };
    int i;

    asm {
        lea si, A
        lea di, B
        mov cx, 10
    L1_task2:
        mov ax, [si]
        mov [di], ax
        add si, 2   /* int в 16-битном режиме = 2 байта */
        add di, 2
        loop L1_task2
    }

    printf("B: ");
    for (i = 0; i < 10; i++) printf("%d ", B[i]);
    printf("\n");
}

/* =========================================================
 * ЗАДАНИЕ 3
 * ========================================================= */
void task3(void)
{
    unsigned char A[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    unsigned char B[10] = { 0 };
    unsigned char C[10] = { 0 };
    int i;

    asm {
        cld
        lea si, A
        lea di, B
        mov cx, 10
        rep movsb
    }

    asm {
        cld
        lea si, A
        lea di, C
        mov cx, 10
    L2_task3:
        lodsb
        stosb
        loop L2_task3
    }

    printf("A: "); for (i = 0; i < 10; i++) printf("%d ", A[i]); printf("\n");
    printf("B: "); for (i = 0; i < 10; i++) printf("%d ", B[i]); printf("\n");
    printf("C: "); for (i = 0; i < 10; i++) printf("%d ", C[i]); printf("\n");
}

/* =========================================================
 * ЗАДАНИЕ 4
 * ========================================================= */
unsigned short far src_buf[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
unsigned short far dst_buf[10] = { 0 };

void task4(void)
{
    unsigned short src_fp[2];
    unsigned short dst_fp[2];
    int i;

    src_fp[0] = (unsigned short)FP_OFF(src_buf);
    src_fp[1] = (unsigned short)FP_SEG(src_buf);
    dst_fp[0] = (unsigned short)FP_OFF(dst_buf);
    dst_fp[1] = (unsigned short)FP_SEG(dst_buf);

    asm {
        push ds
        push es
        push si
        push di
        push cx

        lds si, src_fp
        les di, dst_fp
        mov cx, 10
        cld
        rep movsw

        pop cx
        pop di
        pop si
        pop es
        pop ds
    }

    printf("src_buf: ");
    for (i = 0; i < 10; i++) printf("%u ", src_buf[i]);
    printf("\n");
    printf("dst_buf: ");
    for (i = 0; i < 10; i++) printf("%u ", dst_buf[i]);
    printf("\n");
}

/* =========================================================
 * ЗАДАНИЕ 5
 * ========================================================= */
void task5(void)
{
    unsigned int src_seg = 0xB800, src_off = 0x0000;
    unsigned int dst_seg = 0xB900, dst_off = 0x0000;
    unsigned char far *src = (unsigned char far *)MK_FP(0xB800, 0x0000);
    unsigned char far *dst = (unsigned char far *)MK_FP(0xB900, 0x0000);
    unsigned int i, mism = 0;

    asm {
        push ds
        push es
        push si
        push di
        push cx

        mov ax, src_seg
        mov ds, ax
        mov si, src_off

        mov ax, dst_seg
        mov es, ax
        mov di, dst_off

        mov cx, 2000 /* 2000 слов = 4000 байт */
        cld
        rep movsw

        pop cx
        pop di
        pop si
        pop es
        pop ds
    }

    for (i = 0; i < 4000; i++)
        if (src[i] != dst[i]) mism++;

    printf("Copied 4000 bytes: B800:0000 -> B900:0000\n");
    printf("Mismatches: %u\n", mism);
}

/* =========================================================
 * ЗАДАНИЕ 6
 * ========================================================= */
void task6(void)
{
    char target = 'a';
    int p, i, found;

    printf("Searching for '%c' in video pages 0..3\n", target);

    for (p = 0; p < 4; p++) {
        unsigned char far *page = (unsigned char far *)MK_FP(0xB800, (unsigned int)(p * 4000));
        found = -1;

        for (i = 0; i < 4000; i += 2) {
            if (page[i] == (unsigned char)target) {
                found = i;
                break;
            }
        }

        if (found >= 0)
            printf("pg%d phys 0x%05lX off 0x%04X\n", p, 0xB8000UL + (unsigned long)p * 4000UL, (unsigned int)found);
        else
            printf("pg%d phys 0x%05lX not found\n", p, 0xB8000UL + (unsigned long)p * 4000UL);
    }
}

/* =========================================================
 * MAIN
 * ========================================================= */
int main(void)
{
    printf("=== Task 1: SUB/XOR/JL/ROL ===\n");
    task1();

    printf("\n=== Task 2: LOOP + LEA ===\n");
    task2();

    printf("\n=== Task 3: MOVS/REP + LODS/STOS ===\n");
    task3();

    printf("\n=== Task 4: LDS/LES (far pointers) ===\n");
    task4();

    printf("\n=== Task 5: B8000 -> B9000 (REP MOVSW) ===\n");
    task5();

    printf("\n=== Task 6: search in 4 video pages ===\n");
    task6();

    printf("\nPress any key...\n");
    getch();
    return 0;
}