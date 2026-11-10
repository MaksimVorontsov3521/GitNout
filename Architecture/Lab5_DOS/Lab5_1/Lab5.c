#include <stdio.h>
#include <conio.h>

/* Глобальные переменные — операнды в памяти (средствами Си) */
int iNWords = 3;
int iNShift = 5;
int iMas1[3] = {0x1234, 0x0000, 0x8000};
unsigned int flags;

/* Подпрограмма эмуляции арифметического сдвига вправо (SAR) */
void asr_long(void) {
    /* Счётчик внешних сдвигов */
    asm mov bx, iNShift
    asm test bx, bx
    asm jz end_all

    /* Счётчик слов */
    asm mov cx, iNWords
    asm test cx, cx
    asm jz end_all

    /* SI -> адрес старшего слова массива */
    asm mov si, offset iMas1
    asm mov ax, iNWords
    asm dec ax
    asm shl ax, 1
    asm add si, ax

outer_loop:
    /* Проверка знакового бита старшего слова для расширения знака */
    asm test word ptr [si-2], 0x8000
    asm jns clear_cf
    asm stc
    asm jmp do_shift

clear_cf:
    asm clc

do_shift:
    /* Внутренний цикл: сдвиг всех слов на 1 бит через перенос */
    asm mov cx, iNWords
    asm mov di, si

inner_loop:
    asm dec di
    asm dec di
    asm rcr word ptr [di], 1
    asm loop inner_loop

    asm dec bx
    asm jg outer_loop

    /* === Вычисление флагов ZF и CF === */
    /* CF уже корректный после последнего rcr. Сохраняем FLAGS. */
    asm pushf
    asm pop ax

    /* Вычисляем ZF: OR всех слов массива */
    asm mov cx, iNWords
    asm mov di, offset iMas1
    asm xor dx, dx

or_loop:
    asm or dx, word ptr [di]
    asm inc di
    asm inc di
    asm loop or_loop

    asm or dx, dx
    asm jz set_zf
    asm and ax, 0FFBFh
    asm jmp restore_flags

set_zf:
    asm or ax, 0040h

restore_flags:
    asm push ax
    asm popf

end_all:
    asm nop
}

void main(void) {
    int i;

    clrscr();
    printf("=== Emulation of Multi-word Arithmetic Shift Right ===\n\n");

    printf("Before shift:\n");
    for (i = 0; i < iNWords; i++) {
        printf("Word[%d] = 0x%04X\n", i, iMas1[i]);
    }

    /* Вызов подпрограммы */
    asr_long();

    /* Считываем регистр флагов после выполнения */
    asm pushf
    asm pop ax
    asm mov flags, ax

    printf("\nAfter shift (by %d bits):\n", iNShift);
    for (i = 0; i < iNWords; i++) {
        printf("Word[%d] = 0x%04X\n", i, iMas1[i]);
    }

    printf("\n--- Flags Status ---\n");
    printf("CF (Carry Flag) = %d  (last shifted-out bit)\n", flags & 1);
    printf("ZF (Zero Flag)  = %d  (1 if all words == 0)\n", (flags >> 6) & 1);

    getch();
}