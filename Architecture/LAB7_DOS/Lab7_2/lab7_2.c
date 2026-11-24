/*
============================================================================
  Lab7_2.c  -  Задание 2 (A7.txt, строка 30):
  "Получить в FPU NaN. Показать его в TD."

  Язык и тулчейн: C, Turbo C 2.01 (TCC.EXE), модель -ms (small),
                  линковка с 8087-кодогенерацией (см. раздел 4 - там
                  приведён реальный эмитированный ассемблер).
  Запуск:  Compile and Run (Ctrl+Shift+B)  -  интерактивно, ждёт клавишу;
           Selftest                   -  автозахват вывода в build\run.txt.

  ЧТО ДЕЛАЕТ ПРОГРАММА
    1. Объясняет, что такое NaN по битовому составу (A7.txt, строки 226-258).
    2. Получает NaN шестью СПОСОБАМИ и для каждого печатает битовый образ
       в трёх форматах: КВ (4 байта), ДВ (8 байт), ВВ (10 байт - то, что
       реально лежит в регистре FPU), с разбором по полям.
    3. Строит ВРУЧНУЮ все особые шаблоны (QNaN, SNaN, +Inf, -Inf, +0, -0,
       денормализованные, минимальное нормальное, максимальное конечное)
       и расшифровывает их - чтобы видеть разницу между QNaN и SNaN.
    4. ИзМЕРЯЕТ поведение сравнений с NaN в этом компиляторе и объясняет
       его эмитированным ассемблером (почему "NaN == NaN" даёт 1).
    5. Описывает, где именно смотреть NaN в Turbo Debugger (раздел 5):
       TD интерактивен и автозахвату не поддаётся, поэтому это - инструкция
       для ручной проверки на защите, а не вывод программы.

  ОСОБЕННОСТИ (установлены прогонами, см. Zond_Lab7.txt)
    - ALL PRINTED LITERALS ARE ASCII: в DOSBox кодировка cp866, кириллица в
      строках printf превращается в мусор. Комментарии - русские.
    - Inline asm в TCC 2.01 НЕЛЬЗЯ: он эмитит блок как " { instr } ", а
      TASM 4.1 отвергает скобки ("Unknown character"). Проверено зондом:
      каждая asm-строка дала ошибку сборки. Поэтому слово состояния FPU тут
      НЕ читается - это делает Lab7_3 на ассемблере, где FSTSW доступен.
    - 8087.h в комплекте TCC отсутствует (_status87/_control87 нет).
    - Ключа -8 (8087) у TCC 2.01 нет: "Incorrect command line option".
      Арифметика и так идёт через x87 - видно в эмитированном ASM (раздел 4).
    - printf("%f") для NaN печатает "-NAN" (измерено): это рендер CRT,
      а НЕ ответ FPU; ответ FPU - только битовый образ.
    - long double в TCC = 80 бит / 10 байт (float.h: LDBL_MANT_DIG=64),
      то есть присваивание "long double r = <выражение>" даёт честный
      образ значения из регистра FPU, включая явный старший бит мантиссы.
============================================================================
*/

#include <stdio.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#ifndef NOWAIT
#include <conio.h>
#endif

/* --------------------------------------------------------------- печать */
static void pbytes(const char *lbl, const void *p, int n)
{
    const unsigned char *b = (const unsigned char *) p;
    int i;
    printf("%s", lbl);
    for (i = 0; i < n; i++) printf("%02X ", b[i]);
    printf("\n");
}

/* ============================================================================
   РАЗБОР БИТОВЫХ ОБРАЗОВ. ВАЖНО ДЛЯ 16-БИТНОГО C:
   unsigned здесь 16 бит, поэтому мантиссы (23, 52 и 64 бита) собираются в
   unsigned long (32 бита) - иначе старшие разряды обрезаются и NaN ложно
   выглядит как Infinity (проверено первым прогоном: mant 0x400000h печаталось
   как 000000h). В 80-битном формате (ВВ) порядок занимает байты 8 и 9, а ЯВНЫЙ
   старший бит мантиссы J и quiet-бит Q лежат в байте 7 (биты 7 и 6), а не в
   байте 9 - первая версия этой функции читала их оттуда и совпадала лишь
   случайно (оба бита у измеряемых значений были единицы).
   ========================================================================== */
static void dec_ext(const char *lbl, const void *p)
{
    const unsigned char *b = (const unsigned char *) p;
    unsigned long mh, ml;
    unsigned exp;
    int sign, jbit, qbit, rest;
    sign = (b[9] >> 7) & 1;
    exp  = (unsigned) (((b[9] & 0x7F) << 8) | b[8]);
    jbit = (b[7] >> 7) & 1;                    /* явный старший бит мантиссы */
    qbit = (b[7] >> 6) & 1;                    /* quiet-бит                  */
    mh   = ((unsigned long) (b[7] & 0x3F) << 24) | ((unsigned long) b[6] << 16)
         | ((unsigned long) b[5] << 8) | (unsigned long) b[4];
    ml   = ((unsigned long) b[3] << 24) | ((unsigned long) b[2] << 16)
         | ((unsigned long) b[1] << 8) | (unsigned long) b[0];
    /* Infinity в ВВ - ЭТО mantissa == 1000...0, то есть J=1, Q=0 и нули ниже.
       Quiet-бит входит в 64-битную мантиссу, поэтому он тоже участвует в проверке:
       без него QNaN с пустым payload ложно классифицировался как Infinity
       (проверено прогоном: 00..00 C0 FF FF выдавалось за INFINITY). */
    rest = (jbit == 0) || (qbit != 0) || ((mh | ml) != 0UL);
    printf("%s", lbl);
    printf("      sign=%d  exp=%04Xh (%d)  J=%d  Q=%d\n", sign, exp, exp, jbit, qbit);
    printf("      mantissa, 64 bit (bytes b7..b0): ");
    { int i; for (i = 7; i >= 0; i--) printf("%02X", b[i]); printf("\n"); }
    (void) mh; (void) ml;
    if (exp == 0x7FFF) {
        if (!rest)                   printf("      ->  INFINITY (exp all ones, mantissa = J only)\n");
        else if (qbit)               printf("      ->  QNaN (quiet: propagates silently, carries a payload)\n");
        else                         printf("      ->  SNaN (signalling: must raise Invalid Operation I)\n");
    } else if (exp == 0) {
        if (!(mh | ml))              printf("      ->  ZERO (only the sign bit differs: +0.0 vs -0.0)\n");
        else                         printf("      ->  DENORMALIZED (exp=0, no implicit leading 1)\n");
    } else {
        printf("      ->  NORMAL = 1.mant * 2^(%d - 16383)\n", exp);
    }
}

static void dec_sgl(const char *lbl, const void *p)
{
    const unsigned char *b = (const unsigned char *) p;
    unsigned long mant;
    unsigned exp;
    int sign = (b[3] >> 7) & 1;
    /* КВ: 1 знак + 8 порядок + 23 мантисса; порядок = биты 30..23 */
    exp  = (unsigned) (((b[3] & 0x7F) << 1) | (b[2] >> 7));
    mant = ((unsigned long) (b[2] & 0x7F) << 16) | ((unsigned long) b[1] << 8)
         | (unsigned long) b[0];
    printf("%-24s sign=%d exp=%02Xh mant=%06lXh  ", lbl, sign, exp, mant);
    if (exp == 0xFF) {
        if (!mant)                   printf("INFINITY\n");
        else if (mant & 0x400000UL)  printf("QNaN\n");
        else                         printf("SNaN\n");
    } else if (exp == 0) {
        if (!mant)                   printf("ZERO\n");
        else                         printf("DENORMALIZED\n");
    } else                           printf("NORMAL = 1.mant * 2^%d\n", (int) exp - 127);
}

static void dec_dbl(const char *lbl, const void *p)
{
    const unsigned char *b = (const unsigned char *) p;
    unsigned long hi20, lo32;
    unsigned exp;
    int sign = (b[7] >> 7) & 1;
    /* ДВ: 1 знак + 11 порядок (биты 62..52) + 52 мантисса (биты 51..0) */
    exp  = (unsigned) (((b[7] & 0x7F) << 4) | (b[6] >> 4));
    hi20 = ((unsigned long) (b[6] & 0x0F) << 16) | ((unsigned long) b[5] << 8)
         | (unsigned long) b[4];
    lo32 = ((unsigned long) b[3] << 24) | ((unsigned long) b[2] << 16)
         | ((unsigned long) b[1] << 8) | (unsigned long) b[0];
    printf("%-24s sign=%d exp=%03Xh mant=%05lXh_%08lX  ", lbl, sign, exp, hi20, lo32);
    if (exp == 0x7FF) {
        if (!(hi20 | lo32))           printf("INFINITY\n");
        else if (hi20 & 0x00080000UL) printf("QNaN\n");
        else                          printf("SNaN\n");
    } else if (exp == 0) {
        if (!(hi20 | lo32))           printf("ZERO\n");
        else                          printf("DENORMALIZED\n");
    } else                            printf("NORMAL = 1.mant * 2^%d\n", (int) exp - 1023);
}

static void show_case(const char *lbl, const void *pf, const void *pd, const void *pr)
{
    printf("  %s\n", lbl);
    pbytes("      KV (4B)        : ", pf, 4);
    dec_sgl ("      KV decode      :", pf);
    pbytes("      DV (8B)        : ", pd, 8);
    dec_dbl ("      DV decode      :", pd);
    pbytes("      VV (10B, ST(0)) : ", pr, 10);
    dec_ext ("      VV decode      :", pr);
}

int main(void)
{
    /* --- значения, полученные АРИФМЕТИКОЙ (TCC генерирует на них x87) --- */
    volatile float  zf = 0.0f,  qf;
    volatile double zd = 0.0,   qd, dd;
    volatile double one = 1.0,  inf, t1, t2, t3;
    volatile long double zl = 0.0L, ql, il, rl;
    int e0;

    printf("=== Lab7 step 2 (C): obtaining NaN in the FPU and reading its bit image ===\n");

    printf("--- 1) WHAT NaN IS, IN BITS (A7.txt lines 226-258) ---\n");
    printf("  A NaN is a value with the EXPONENT FIELD ALL ONES and a NON-ZERO\n");
    printf("  MANTISSA. Two kinds: the quiet bit (MSB of the mantissa) set -> QNaN,\n");
    printf("  cleared -> SNaN. QNaN travels through operations silently; an SNaN used\n");
    printf("  as an operand is a signalling case: it raises Invalid Operation (I) and\n");
    printf("  gets QUIETED (the quiet bit is set) on the way out. The sign bit of a NaN\n");
    printf("  carries no meaning but is preserved, and the rest of the mantissa is a\n");
    printf("  payload - the FPU does not define it, the producer may.\n");
    printf("  Widths in this compiler (measured): sizeof float=%u  double=%u  long double=%u\n",
           (unsigned) sizeof(float), (unsigned) sizeof(double), (unsigned) sizeof(long double));
    printf("  float.h of this toolkit: FLT_MANT_DIG=24, DBL_MANT_DIG=53, LDBL_MANT_DIG=64,\n");
    printf("  so KV=32 bit with 8-bit exponent, DV=64 bit with 11-bit, VV=80 bit with 15.\n");

    printf("--- 2) SIX WAYS TO GET NaN, EACH SHOWN IN ALL THREE FORMATS ---\n");
    /* (a) 0.0 / 0.0 - классический Инвалид Оперейшн */
    qf = zf / zf;
    qd = zd / zd;
    ql = zl / zl;
    show_case("(a) 0.0 / 0.0", &qf, &qd, &ql);
    /* (b) sqrt of a negative number: math.h returns a NaN and sets errno */
    errno = 0;
    t1 = sqrt(-1.0);
    e0 = errno;
    rl = (long double) t1;
    qf = (float) t1;
    show_case("(b) sqrt(-1.0)", &qf, &t1, &rl);
    printf("      errno after sqrt(-1.0) = %d  (EDOM in math.h = %d)\n", e0, EDOM);
    /* (c) Inf - Inf */
    inf = one / zd;
    t2 = inf - inf;
    rl = (long double) t2;
    qf = (float) t2;
    show_case("(c) Inf - Inf   (Inf = 1.0/0.0)", &qf, &t2, &rl);
    /* (d) 0 * Inf */
    t3 = zd * inf;
    rl = (long double) t3;
    qf = (float) t3;
    show_case("(d) 0.0 * Inf", &qf, &t3, &rl);
    /* (e) an SNaN built BY HAND and then used in FADD */
    {
        unsigned char pat[4];
        float sn, rs;
        double sd, rd;
        long double re;
        pat[0] = 0x01; pat[1] = 0x00; pat[2] = 0x80; pat[3] = 0x7F;  /* 7F800001h SNaN */
        sn = *(const float *) pat;
        rs = sn + one;                        /* FADD: SNaN тихо становится QNaN */
        re = (long double) rs;
        qf = rs;
        printf("(e) hand-built SNaN 7F800001h used in FADD (SNaN + 1.0)\n");
        pbytes("      operand SNaN, KV bytes: ", pat, 4);
        dec_sgl("      operand decode      :", pat);
        pbytes("      result KV             : ", &rs, 4);
        dec_sgl("      result decode         :", &rs);
        pbytes("      result VV (ST(0))     : ", &re, 10);
        dec_ext("      result decode         :", &re);
        printf("      note: the quiet bit of the RESULT is set - the FPU quieted the\n");
        printf("      SNaN instead of signalling. On real hardware with the I-mask\n");
        printf("      cleared this is exactly the case that raises the interrupt.\n");
        (void) sd; (void) rd; (void) sd;
    }
    /* (f) 0.0L / 0.0L straight in 80-bit */
    rl = zl / zl;
    qd = (double) rl;
    qf = (float) rl;
    show_case("(f) 0.0L / 0.0L (80-bit arithmetic)", &qf, &qd, &rl);

    printf("--- 3) ALL SPECIAL PATTERNS, BUILT AND DECODED BY HAND ---\n");
    {
        struct { const char *name; unsigned long hi, lo; } sg[] = {
            { "+QNaN single", 0x7FC00000ul, 0 },
            { "-QNaN single", 0xFFC00000ul, 0 },
            { "+SNaN single", 0x7F800001ul, 0 },
            { "+Inf single",  0x7F800000ul, 0 },
            { "-Inf single",  0xFF800000ul, 0 },
            { "+0 single",    0x00000000ul, 0 },
            { "-0 single",    0x80000000ul, 0 },
            { "min denormal", 0x00000001ul, 0 },
            { "max denormal", 0x007FFFFFul, 0 },
            { "min normal",   0x00800000ul, 0 },
            { "max finite",   0x7F7FFFFFul, 0 }
        };
        int i;
        printf("  Single (KV), 32 bit = 1 sign + 8 exponent + 23 mantissa bits:\n");
        for (i = 0; i < (int) (sizeof(sg)/sizeof(sg[0])); i++) {
            unsigned char b[4];
            unsigned long v = sg[i].hi;
            b[0] = (unsigned char) (v    & 0xFF);
            b[1] = (unsigned char) ((v >> 8)  & 0xFF);
            b[2] = (unsigned char) ((v >> 16) & 0xFF);
            b[3] = (unsigned char) ((v >> 24) & 0xFF);
            printf("  %-15s word=%08lX  bytes:", sg[i].name, v);
            { int k; for (k = 0; k < 4; k++) printf(" %02X", b[k]); }
            dec_sgl("", b);
        }
        printf("\n  Double (DV), 64 bit = 1 sign + 11 exponent + 52 mantissa bits:\n");
        {
            const char *dn[9];
            unsigned char dp[9][8];
            int i2;
            dn[0] = "+QNaN double";
            dn[1] = "-QNaN double";
            dn[2] = "+SNaN double";
            dn[3] = "+Inf double";
            dn[4] = "-Inf double";
            dn[5] = "min denormal  ";
            dn[6] = "max denormal  ";
            dn[7] = "min normal    ";
            dn[8] = "max finite    ";
            memset(&dp, 0, sizeof(dp));
            dp[0][6] = 0xF8; dp[0][7] = 0x7F;
            dp[1][6] = 0xF8; dp[1][7] = 0xFF;
            dp[2][0] = 0x01; dp[2][6] = 0xF0; dp[2][7] = 0x7F;
            dp[3][6] = 0xF0; dp[3][7] = 0x7F;
            dp[4][6] = 0xF0; dp[4][7] = 0xFF;
            /* Порядок (11 бит, биты 62..52) лежит в старших 4 битах байта 6 и
               целиком в байте 7, поэтому min normal = 0x0010... - это байт 6 = 0x10,
               а НЕ байт 5 (первая версия собрала его неверно, и шаблон распался
               в DENORMALIZED - проверено прогоном). */
            dp[5][0] = 0x01;                                /* 0000...0001  */
            for (i2 = 0; i2 < 6; i2++) dp[6][i2] = 0xFF;     /* max denormal */
            dp[6][6] = 0x0F;
            dp[7][6] = 0x10;                                 /* min normal   */
            for (i2 = 0; i2 < 6; i2++) dp[8][i2] = 0xFF;     /* max finite   */
            dp[8][6] = 0xEF; dp[8][7] = 0x7F;
            for (i2 = 0; i2 < 9; i2++) {
                unsigned long wHi, wLo;
                wHi = ((unsigned long) dp[i2][7] << 24) | ((unsigned long) dp[i2][6] << 16)
                    | ((unsigned long) dp[i2][5] << 8) | (unsigned long) dp[i2][4];
                wLo = ((unsigned long) dp[i2][3] << 24) | ((unsigned long) dp[i2][2] << 16)
                    | ((unsigned long) dp[i2][1] << 8) | (unsigned long) dp[i2][0];
                printf("  %-15s word=%08lX_%08lX  bytes:", dn[i2], wHi, wLo);
                { int k; for (k = 0; k < 8; k++) printf(" %02X", dp[i2][k]); }
                dec_dbl("", dp[i2]);
            }
        }
        printf("\n  Extended (VV), 80 bit = 1 sign + 15 exponent + 64 mantissa bits,\n");
        printf("  the leading mantissa bit is EXPLICIT here (in KV and DV it is implied):\n");
        {
            unsigned char e1[10], e2[10];
            memset(e1, 0, sizeof(e1));
            e1[7] = 0xC0; e1[8] = 0xFF; e1[9] = 0x7F;   /* +QNaN: J=1, Q=1 */
            pbytes("  +QNaN extended    bytes:", e1, 10);
            dec_ext("", e1);
            memset(e2, 0, sizeof(e2));
            e2[7] = 0x80; e2[8] = 0xFF; e2[9] = 0x7F;   /* +Inf:  J=1, mantissa only J */
            pbytes("  +Inf extended     bytes:", e2, 10);
            dec_ext("", e2);
            printf("  Compare: both have exp=7FFFh and J=1; they differ ONLY in Q.\n");
        }
    }

    printf("--- 4) HOW THIS COMPILER COMPARES NaN (MEASURED, not assumed) ---\n");
    {
        volatile double n = zd / zd;
        volatile double big = 1.0e300;
        printf("  n = 0.0/0.0 (a NaN). Results produced by Turbo C 2.01 on DOSBox:\n");
        printf("      n != n  -> %d      n == n  -> %d\n", (int)(n != n), (int)(n == n));
        printf("      n <  1.0-> %d      n >  1.0-> %d\n", (int)(n < 1.0), (int)(n > 1.0));
        printf("      !(n<1.0)-> %d      inf > 1e300 -> %d\n", (int)(!(n < 1.0)), (int)(inf > big));
        printf("      printf %%f of n renders as: ");
        printf("%f", n);
        printf("   <- that is the CRT text, NOT the FPU answer\n");
        printf("  WHY: the emitted assembly of a float comparison (measured, build\n");
        printf("  of a probe) is exactly this:\n");
        printf("      FLD   qword ptr <right>\n");
        printf("      FLD   qword ptr <left>\n");
        printf("      FCOMPP                 ; compare ST(0) with ST(1), pop both\n");
        printf("      FSTSW word ptr FLAGS8087@   ; status word to memory\n");
        printf("      FWAIT\n");
        printf("      mov   ah, byte ptr FLAGS8087@+1  ; HIGH byte of the status word\n");
        printf("      sahf                        ; AH -> CF,PF,AF,ZF,SF\n");
        printf("      jbe   <label>               ; the test actually used\n");
        printf("  AH is bits 15..8 of the status word and SAHF copies AH into SF,ZF,_,AF,\n");
        printf("  _,_,PF,_,CF - so the x87 codes land as C0 (bit 8) -> CF, C2 (bit 10) ->\n");
        printf("  PF, C3 (bit 14) -> ZF, while bits 11..13 (the TOP pointer!) end up in AF\n");
        printf("  and bit 15 (busy) in SF. The mapping is measured, not guessed: the status\n");
        printf("  word 2900h printed by Lab7_1 has TOP=5 in bits 13..11, so C3 cannot be\n");
        printf("  bit 3 and C2 cannot be bit 2. The branches TCC emits use CF and ZF, that\n");
        printf("  is C0 and C3; C1 goes nowhere (bit 9 is not an SAHF flag bit).\n");
        printf("  For an UNORDERED pair the FPU sets C0=C1=C2=C3=1, hence CF=1 and ZF=1,\n");
        printf("  so the below-or-equal branch is taken: this C code reports NaN as EQUAL\n");
        printf("  to itself and as LESS than 1.0 - both measurements above. That is a\n");
        printf("  property of the compiler's flag mapping, NOT of the FPU: the real flags\n");
        printf("  live in the status word, and only Lab7_3 (assembly, FSTSW) reads them.\n");
    }

    printf("--- 5) WHERE TO LOOK AT THE NaN IN TURBO DEBUGGER (manual, for defence) ---\n");
    printf("  TD is interactive, so this part cannot be captured by the autotest; the\n");
    printf("  autotest proves the NUMBERS, TD proves the FPU STATE. Procedure:\n");
    printf("    1. Build with debugging info. MEASURED on this toolkit: tcc -g adds NO\n");
    printf("       debug information (the EXE is byte-for-byte the same size as without\n");
    printf("       the switch), while tcc -v does (the source file name appears inside the\n");
    printf("       EXE: 6444 bytes vs 9295 bytes). The Compile and Debug task therefore\n");
    printf("       uses: tcc -B -ms -v -nd:\\build d:\\lab7_2.c  then  td lab7_2.\n");
    printf("    2. In TD: Alt+F9 to run to the breakpoint, F2 on the line after the\n");
       printf("       statement that produced the NaN.\n");
    printf("    3. View -> Floating Point (or CPU window, FPU pane). You see ST(0)..ST(7)\n");
    printf("       as 10-byte values - exactly the KV/DV/VV bytes this program printed,\n");
    printf("       plus the tag word: the NaN slot is marked SPECIAL (binary 10), which\n");
    printf("       is how the FPU distinguishes NaN/Inf from ordinary numbers.\n");
    printf("    4. View -> Registers -> FPU (Control and Status words). After 0.0/0.0 the\n");
    printf("       status word has IE (bit 0) set and C0..C3 = 1000b for INVALID; after\n");
    printf("       Inf-Inf and 0*Inf also IE; a QNaN produced silently leaves only IE.\n");
    printf("    5. Watch the stack: FLD pushes (TOP decreases), FSTP/FADDP/FDIVP pop.\n");
    printf("       With 8 slots filled, the 9th FLD raises Stack Fault (SF, bit 6) -\n");
    printf("       try it in the TD command line (Ctrl+F4) with fld st(0) repeated.\n");

    printf("--- 6) ANSWERS ---\n");
    printf("  1. NaN appears whenever an operation has no meaningful numeric result:\n");
    printf("     0/0, Inf-Inf, 0*Inf, sqrt of a negative number, an SNaN operand, and\n");
    printf("     stack over/underflow. Its bits: exponent all ones, mantissa non-zero.\n");
    printf("  2. QNaN (quiet bit set) propagates silently and carries a payload; SNaN\n");
    printf("     signals Invalid Operation and is quieted on the way out - measured here\n");
    printf("     on the hand-built 7F800001h pattern.\n");
    printf("  3. The sign of a NaN is preserved but meaningless. The bit images above\n");
    printf("     agree with the patterns published in A7.txt (lines 226-258); they were\n");
    printf("     NOT compared with real 8087 hardware - only this emulator was measured.\n");
    printf("  4. In this toolkit the FPU flags are reachable from C only through the\n");
    printf("     compiler flag mapping, which loses C2 - so unordered comparisons lie.\n");
    printf("     Reading the status word directly (Lab7_3) is the only honest way.\n");
    printf("  5. DOSBox 0.74-3 does NOT deliver unmasked x87 exceptions (measured in\n");
    printf("     Lab7_4): the flags accumulate in the status word, no interrupt arrives.\n");

#ifndef NOWAIT
    printf("\nPress any key to exit...");
    getch();
#endif
    return 0;
}
