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

    // =========================================================
    // БЛОК 1: SUB: register - register
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE (-2)
        mov bx, b       // 8B 5E FC      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: FC (-4)
        sub ax, bx      // 29 D8         | ModRM: 11 011 000 (mod=11, reg=BX, r/m=AX) - регистры
        mov r_sub, ax   // 89 46 F2      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: F2
    }

    // =========================================================
    // БЛОК 2: SUB: register - memory with pointer access
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        lea bx, arr     // 8D 5E F4      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: F4
        sub ax, [bx]    // 2B 07         | ModRM: 00 000 111 (mod=00, reg=AX, r/m=BX) - без смещения
    }

    // =========================================================
    // БЛОК 3: SUB: memory - register
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        lea bx, arr     // 8D 5E F4      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: F4
        sub [bx], ax    // 29 07         | ModRM: 00 000 111 (mod=00, reg=AX, r/m=BX) - без смещения
    }

    // =========================================================
    // БЛОК 4: SUB: register - offset memory
    // =========================================================
    asm {
        mov ax, a           // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        lea bx, arr         // 8D 5E F4      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: F4
        sub ax, [bx + 4]    // 2B 47 04      | ModRM: 01 000 111 (mod=01, reg=AX, r/m=BX) + Смещение: 04
    }

    // =========================================================
    // БЛОК 5: XOR
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        mov bx, b       // 8B 5E FC      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: FC
        xor ax, bx      // 31 D8         | ModRM: 11 011 000 (mod=11, reg=BX, r/m=AX) - регистры
        mov r_xor, ax   // 89 46 F0      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: F0
    }

    // =========================================================
    // БЛОК 6: JL (Jump if Less)
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        mov bx, b       // 8B 5E FC      | ModRM: 01 011 110 (mod=01, reg=BX, r/m=BP) + Смещение: FC
        cmp ax, bx      // 39 D8         | ModRM: 11 011 000 (mod=11, reg=BX, r/m=AX) - регистры
        jl  jl_taken_1  // 7C XX         | КОП: 7C (JL rel8) + Смещение: XX (относительный адрес метки)
        mov jump_taken, 0 // C7 46 XX 00 00 | ModRM: 01 000 110 (mod=01, reg=000, r/m=BP) + Смещение: XX + Imm: 0000
        jmp jl_done_1   // EB XX         | КОП: EB (JMP rel8) + Смещение: XX
    }
jl_taken_1: ;
    asm { 
        mov jump_taken, 1 // C7 46 XX 01 00 | ModRM: 01 000 110 (mod=01, reg=000, r/m=BP) + Смещение: XX + Imm: 0001 
    }
jl_done_1: ;

    // =========================================================
    // БЛОК 7: ROL (Rotate Left)
    // =========================================================
    asm {
        mov ax, a       // 8B 46 FE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: FE
        mov cl, 2       // B1 02         | КОП: B1 (MOV CL, imm8) + Непосредственный операнд: 02
        rol ax, cl      // D3 C0         | ModRM: 11 000 000 (mod=11, reg=000 (ROL), r/m=AX) - регистры
        mov r_rol, ax   // 89 46 EE      | ModRM: 01 000 110 (mod=01, reg=AX, r/m=BP) + Смещение: EE
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
        lea si, A       // 8D 76 XX      | ModRM: 01 110 110 (mod=01, reg=SI, r/m=BP) + Смещение: XX
        lea di, B       // 8D 7E XX      | ModRM: 01 111 110 (mod=01, reg=DI, r/m=BP) + Смещение: XX
        mov cx, 10      // B9 0A 00      | КОП: B9 (MOV CX, imm16) + Непосредственный операнд: 000A
    }
L1_task2: ;
    asm {
        mov ax, ss:[si] // 36 8B 04      | Префикс: 36 (SS) + КОП: 8B (MOV AX, r/m16) + ModRM: 00 000 100 (mod=00, reg=AX, r/m=SI)
        mov ss:[di], ax // 36 89 05      | Префикс: 36 (SS) + КОП: 89 (MOV r/m16, AX) + ModRM: 00 000 101 (mod=00, reg=AX, r/m=DI)
        add si, 2       // 83 C6 02      | КОП: 83 (ADD r/m16, imm8) + ModRM: 11 000 110 (mod=11, reg=ADD, r/m=SI) + Imm: 02
        add di, 2       // 83 C7 02      | КОП: 83 (ADD r/m16, imm8) + ModRM: 11 000 111 (mod=11, reg=ADD, r/m=DI) + Imm: 02
        loop L1_task2   // E2 XX         | КОП: E2 (LOOP rel8) + Смещение: XX (относительный переход)
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
        cld             // FC            | Сброс флага направления (DF=0), чтобы SI и DI увеличивались
        lea si, A       // 8D 76 XX      | ModRM: 01 110 110 (mod=01, reg=SI, r/m=BP) + Смещение: XX
        lea di, B       // 8D 7E XX      | ModRM: 01 111 110 (mod=01, reg=DI, r/m=BP) + Смещение: XX
        mov cx, 10      // B9 0A 00      | КОП: B9 (MOV CX, imm16) + Непосредственный операнд: 000A
        rep movsb       // F3 A4         | Префикс: F3 (REP) + КОП: A4 (MOVSB)
    }

    asm {
        cld             // FC            | Сброс флага направления (DF=0)
        lea si, A       // 8D 76 XX      | ModRM: 01 110 110 (mod=01, reg=SI, r/m=BP) + Смещение: XX
        lea di, C       // 8D 7E XX      | ModRM: 01 111 110 (mod=01, reg=DI, r/m=BP) + Смещение: XX
        mov cx, 10      // B9 0A 00      | КОП: B9 (MOV CX, imm16) + Непосредственный операнд: 000A
    }
L2_task3: ;
    asm {
        lodsb           // AC            | КОП: AC (LODSB) - загрузить байт из [DS:SI] в AL, SI++ 
        stosb           // AA            | КОП: AA (STOSB) - сохранить байт из AL в [ES:DI], DI++
        loop L2_task3   // E2 XX         | КОП: E2 (LOOP rel8) + Смещение: XX (относительный переход)
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

    // Получаем смещение (offset) и сегмент (segment) для исходного массива
    src_fp[0] = (unsigned short)FP_OFF(src_buf); // Смещение (младшее слово)
    src_fp[1] = (unsigned short)FP_SEG(src_buf); // Сегмент (старшее слово)
    
    // То же самое для массива-приемника
    dst_fp[0] = (unsigned short)FP_OFF(dst_buf);
    dst_fp[1] = (unsigned short)FP_SEG(dst_buf);

    asm {
        // --- СОХРАНЕНИЕ РЕГИСТРОВ ---
        push ds         // 1E            | Сохраняем сегмент данных (C-программы)
        push es         // 06            | Сохраняем доп. сегмент (C-программы)
        push si         // 56            | Сохраняем индекс источника
        push di         // 57            | Сохраняем индекс приемника
        push cx         // 51            | Сохраняем счетчик цикла

        // --- ЗАГРУЗКА ДАЛЬНИХ УКАЗАТЕЛЕЙ ---
        lds si, src_fp  // C5 76 XX      | ModRM: 01 110 110 (mod=01, reg=SI, r/m=BP) + Смещение: XX. 
                        //               | Загружает в SI смещение, в DS — сегмент источника
        les di, dst_fp  // C4 7E YY      | ModRM: 01 111 110 (mod=01, reg=DI, r/m=BP) + Смещение: YY.
                        //               | Загружает в DI смещение, в ES — сегмент приемника

        // --- ПОДГОТОВКА И ПЕРЕСЫЛКА ---
        mov cx, 10      // B9 0A 00      | КОП: B9 + Непосредственный операнд: 000A (10 элементов)
        cld             // FC            | Сброс флага направления (DF=0, идем вперед)
        rep movsw       // F3 A5         | Префикс: F3 (REP) + КОП: A5 (MOVSW - пересылка слова)

        // --- ВОССТАНОВЛЕНИЕ РЕГИСТРОВ ---
        // Восстанавливаем в ОБРАТНОМ порядке!
        pop cx          // 59
        pop di          // 5F
        pop si          // 5E
        pop es          // 07
        pop ds          // 1F
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
    // Создаем дальние указатели для проверки в C (MK_FP - Make Far Pointer)
    unsigned char far *src = (unsigned char far *)MK_FP(0xB800, 0x0000);
    unsigned char far *dst = (unsigned char far *)MK_FP(0xB900, 0x0000);
    unsigned int i, mism = 0;

    asm {
        // --- СОХРАНЕНИЕ РЕГИСТРОВ ---
        push ds         // 1E            | Сохраняем сегмент данных C-программы
        push es         // 06            | Сохраняем доп. сегмент C-программы
        push si         // 56            | Сохраняем индекс источника
        push di         // 57            | Сохраняем индекс приемника
        push cx         // 51            | Сохраняем счетчик

        // --- НАСТРОЙКА СЕГМЕНТА ИСТОЧНИКА (B800) ---
        mov ax, src_seg // B8 00 B8      | КОП: B8 (MOV AX, imm16) + Операнд: B800
        mov ds, ax      // 8E D8         | ModRM: 11 011 000 (mod=11, reg=011(DS), r/m=AX)
        mov si, src_off // BE 00 00      | КОП: BE (MOV SI, imm16) + Операнд: 0000

        // --- НАСТРОЙКА СЕГМЕНТА ПРИЕМНИКА (B900) ---
        mov ax, dst_seg // B8 00 B9      | КОП: B8 (MOV AX, imm16) + Операнд: B900
        mov es, ax      // 8E C0         | ModRM: 11 000 000 (mod=11, reg=000(ES), r/m=AX)
        mov di, dst_off // BF 00 00      | КОП: BF (MOV DI, imm16) + Операнд: 0000

        // --- ПЕРЕСЫЛКА ---
        mov cx, 2000    // B9 D0 07      | КОП: B9 (MOV CX, imm16) + Операнд: 07D0 (это 2000)
        cld             // FC            | Сброс флага направления (DF=0, идем вперед)
        rep movsw       // F3 A5         | Префикс: F3 (REP) + КОП: A5 (MOVSW - копируем слово = 2 байта)

        // --- ВОССТАНОВЛЕНИЕ РЕГИСТРОВ ---
        pop cx          // 59
        pop di          // 5F
        pop si          // 5E
        pop es          // 07
        pop ds          // 1F
    }

    // Проверка в C: побайтовое сравнение 4000 байт
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
    char target = 'a'; // Искомый символ
    int p, i, found;

    printf("Searching for '%c' in video pages 0..3\n", target);

    // Цикл по 4-м видеостраницам (0, 1, 2, 3)
    for (p = 0; p < 4; p++) {
        
        // Создаем дальний указатель на начало текущей страницы.
        // Сегмент видеопамяти всегда 0xB800. 
        // Смещение = номер_страницы * 4000 байт (размер одной страницы).
        unsigned char far *page = (unsigned char far *)MK_FP(0xB800, (unsigned int)(p * 4000));
        
        found = -1; // Флаг: -1 значит "не найдено"

        // Ищем символ на текущей странице
        // i += 2, потому что каждый символ в видеопамяти занимает 2 байта:
        // [Байт 0: ASCII-код] [Байт 1: Атрибут цвета]
        // Байт 0: ASCII-код] [Байт 1: Атрибут цвета
        for (i = 0; i < 4000; i += 2) {
            if (page[i] == (unsigned char)target) {
                found = i; // Запоминаем смещение, где нашли
                break;     // Дальше на этой странице не ищем
            }
        }

        // Вывод результатов для текущей страницы
        if (found >= 0)
            // Вычисляем физический адрес: 0xB8000 + (p * 4000) + найденное смещение
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