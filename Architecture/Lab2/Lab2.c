#include <stdio.h>
#include <string.h>
#include <conio.h>
#include <dos.h>

void task1(void)
{
    int a = 10, b = 3;
    int arr[4] = { 100, 200, 300, 400 };
    int r_sub, r_xor, r_rol;
    int jump_taken = 0;
 
    // SUB: register - register   
    asm {
        mov ax, a       // 8B 46 FE   01 000 110 
                        // MOV AX, [BP - 2] 
        mov bx, b       // 8B 5E FC   01 011 110 
                        // MOV BX, [BP - 4] 
        sub ax, bx      // 29 D8      11 011 000 
                        //SUB AX, BX
        mov r_sub, ax   // 89 46 F2   01 000 110 
    }
    
    // SUB: register - memory with pointer access   
    asm {
        mov ax, a       
        lea bx, arr     // 8D 5E F4   01 011 110 
        sub ax, [bx]    // 2B 07      00 000 111 
    }

    // SUB: memory - register   
    asm {
        mov ax, a       
        lea bx, arr     // 8D 5E F4   01 011 110 
        sub [bx], ax    // 29 07      00 000 111 
    }

    // SUB: register - offset memory 
    asm {
        mov ax, a           
        lea bx, arr         // 8D 5E F4   01 011 110 
        sub ax, [bx + 4]    // 2B 47 04   01 000 111 
    }
   
    // XOR 
    asm {
        mov ax, a       
        mov bx, b       // 8B 5E FC   01 011 110 
        xor ax, bx      // 31 D8      11 011 000 
        mov r_xor, ax   // 89 46 F0   01 000 110 
    }
 
    // JL
    asm {
        mov ax, a       
        mov bx, b       
        cmp ax, bx      // 39 D8      11 011 000 
        jl  jl_taken_1  // 7C D8      
        mov jump_taken, 0 // C7 46 EC 00 00  01 000 110
        jmp jl_done_1   // EB EC        
    }
jl_taken_1: ;
    asm { 
        mov jump_taken, 1
    }
jl_done_1: ;

    
    // ROL
    asm {
        mov ax, a       // 8B 46 FE   01 000 110 
        mov cl, 2       // B1 02      00 000 010
        rol ax, cl      // D3 C0      11 000 000 
        mov r_rol, ax   // 89 46 EE   01 000 110 
    }

    printf("sub=%d xor=%d jl=%d rol=%d\n", r_sub, r_xor, jump_taken, r_rol);
}


 // Задание 2
void task2(void)
{
    int A[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    int B[10] = { 0 };
    int i;

    asm {
        lea si, A       // 8D 76 EA   01 110 110 
        lea di, B       // 8D 7E D6   01 111 110 
        mov cx, 10      // B9 0A 00   
    }
L1_task2: ;
    asm {
        mov ax, ss:[si] // 36 8B 04   00 000 100
        mov ss:[di], ax // 36 89 05   00 000 101
        add si, 2       // 83 C6 02   11 000 110
        add di, 2       // 83 C7 02   11 000 111
        loop L1_task2   // E2 F2
    }

    printf("B: ");
    for (i = 0; i < 10; i++) printf("%d ", B[i]);
    printf("\n");
}

// Задание 3
void task3(void)
{
    unsigned char A[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    unsigned char B[10] = { 0 };
    unsigned char C[10] = { 0 };
    int i;

    asm {
        cld
        lea si, A       // 8D 76 F6   01 110 110 
        lea di, B       // 8D 7E EC   01 111 110 
        mov cx, 10      // B9 0A 00
        rep movsb       // F3 A4
    }

    asm {
        cld
        lea si, A       // 8D 76 F6   01 110 110 
        lea di, C       // 8D 7E E2   01 111 110 
        mov cx, 10      // B9 0A 00
    }
L2_task3: ;
    asm {
        lodsb           // AC
        stosb           // AA
        loop L2_task3   // E2 FC
    }

    printf("A: "); for (i = 0; i < 10; i++) printf("%d ", A[i]); printf("\n");
    printf("B: "); for (i = 0; i < 10; i++) printf("%d ", B[i]); printf("\n");
    printf("C: "); for (i = 0; i < 10; i++) printf("%d ", C[i]); printf("\n");
}

// Задание 4
unsigned short far src_buf[10] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
unsigned short far dst_buf[10] = { 0 };

void task4(void)
{
    unsigned short src_fp[2];
    unsigned short dst_fp[2];
    int i;

    src_fp[0] = (unsigned short)FP_OFF(src_buf); // Смещение (младшее слово)
    src_fp[1] = (unsigned short)FP_SEG(src_buf); // Сегмент (старшее слово)
    
    // для массива-приемника
    dst_fp[0] = (unsigned short)FP_OFF(dst_buf);
    dst_fp[1] = (unsigned short)FP_SEG(dst_buf);

    asm {
        push ds
        push es
        push si
        push di
        push cx

        lds si, src_fp  // C5 76 XX   01 110 110 . 

        les di, dst_fp  // C4 7E YY   01 111 110 .

        mov cx, 10      // B9 0A 00
        cld
        rep movsw       // F3 A5

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

// Задание 5
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

        mov cx, 2000
        cld
        rep movsw

        pop cx
        pop di
        pop si
        pop es
        pop ds
    }

    // Проверка в C: побайтовое сравнение 4000 байт
    for (i = 0; i < 4000; i++)
        if (src[i] != dst[i]) mism++;

    printf("Copied 4000 bytes: B800:0000 -> B900:0000\n");
    printf("Mismatches: %u\n", mism);
}



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

    printf("\nPress any key...\n");
    getch();
    return 0;
}