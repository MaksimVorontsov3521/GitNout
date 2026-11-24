/*==============================================================
  lab7_5.c  -  Лабораторная работа N7, ШАГ 5 (DOS, FPU, IEEE 754)

  ЦИТАТА ЗАДАНИЯ (A7.txt, строки 37-38, дословно):
    "5. При сдаче работы покажите преподавателю механизм перевода
       числа, например 16.02, в формат с плавающей запятой."

  ФОРМУЛИРОВКА ЗАЩИТЫ (из постановления шага 5):
    "Защиту начинать с вопроса: покажите механизм превращения числа
     16.02 в плавающий формат."
  Примечание: дословно такого текста в A7.txt нет (проверено поиском по
  всему каталогу LAB7_DOS) - это пересказ строк 37-38. Реализован именно
  тот механизм: пошагово, со всеми промежуточными результатами, и с
  обратным ходом (из битов снова в десятичное), чтобы была видна ошибка.

  ЯЗЫК / ТУЛЧЕЙН
    C (ANSI C89), Turbo C 2.01 (TCC.EXE), модель -ms (small), формат EXE.
    Сборка:  tcc -B -ms -nd:\build d:\lab7_5.c
    Запуск:  DOSBox 0.74-3, консоль в кодировке cp866.
    Автопрогон: autotest.ps1 -> build\run.txt (redirect внутри DOS).

  ЧТО ДЕЛАЕТ ПРОГРАММА
    1. Секция 1. 16.02 раскладывается на целую часть 16 и дробную 1/50.
       Целая часть переводится в двоичное делением на 2 с остатком
       (печатается вся цепочка). Дробная часть переводится ВРУЧНУЮ
       умножением на 2, с печатью КАЖДОГО шага: множимое, произведение,
       извлечённая цифра, остаток. Шагов 36 (больше требуемых 30).
       Начало и длина периода находятся автоматически, печатается запись
       0.02 = 0.(period)(period)... Вывод: 16.02 ТОЧНО НЕ ПРЕДСТАВИМО.
    2. Секция 2. Нормализация: сдвиг двоичной точки до мантиссы в [1,2),
       истинный порядок e=4, знак S=0, характеристика E = e + bias для
       всех трёх ширин (127 / 1023 / 16383) в двоичном и HEX-виде.
    3. Секция 3. Мантисса: поля 23 бита (KV), 52 (DV), 64 (VV). Печатаются
       первые 36 битов дробной части мантиссы с номерами, затем явно
       отбрасываемый хвост и разряды округления guard/round/sticky,
       правило "до ближайшего, при равных - к чётному" (RC=00), величина
       приращения и проверка выхода за старший бит поля.
    4. Секция 4. Сборка слова: знак, порядок, мантисса - по битам и в HEX,
       итоговое слово целиком и его байты в порядке памяти (little-endian)
       с подписью, какие биты лежат в каждом байте.
    5. Секция 5. Обратная реконструкция: первые слагаемые суммы
       b_i * 2^-i, мантисса в [1,2), умножение на 2^e, восстановленное
       десятичное число, абсолютная и относительная ошибка и позиция
       первой неверной десятичной цифры - для KV, DV и VV.
    6. Секция 6. Сверка с реальностью: байты float, double и 80-битного
       long double из памяти ЭТОГО компилятора сравниваются с расчётными
       байтами секции 4 и с контрольной записью реального прогона;
       вердикт OK / RAZNICHA. Отдельно: расширение double -> 80 бит,
       пояснение про явный старший бит мантиссы в VV и чтение слова
       управления FPU (RC/PC) - чтобы показать, что железо округляет
       по тому же правилу.
    7. Секция 7. Краткий ответ для защиты (5 тезисов) и таблица
       параметров форматов из A7.txt, строки 57-66.

  ОСОБЕННОСТИ
    - ВЕСЬ ВЫВОД - ASCII. Консоль DOSBox работает в cp866, и не-ASCII
      символ внутри printf дал бы мусор. Кириллица - только в комментариях.
    - НИКАКИХ getch(), kbhit() и пауз: программа завершается сама,
      автопрогон захватывает stdout в файл.
    - ВСЯ РАСЧЁТНАЯ АРИФМЕТИКА - ЦЕЛОЧИСЛЕННАЯ. В TCC 2.01 int = 16 бит,
      unsigned long = 32 бита, а "unsigned long long" ОТСУТСТВУЕТ, поэтому
      32/64/80-битные величины собираются из массива 16-битных слов
      word_t[NW], NW = 6 (96 бит). Запас до 96 бит нужен вот где: в
      секции 5 считается 50 * SIG и 801 * 2^k, и 801 * 2^59 уже не
      помещается в 64 бита.
    - Плавающие литералы - НЕ источник истины для байтов. Они появляются
      только в секции 6, как предмет сверки. Если бы битовый образ брали
      из float, исчез бы ровно тот шаг (округление), который и нужно
      показать.
    - Точность печати: все десятичные строки выдаёт точный целочисленный
      алгоритм w_digits() ("школьное" извлечение цифры за цифрой), а не
      %f - иначе собственное округление printf спрятало бы то, что здесь
      демонстрируется.
    - Inline asm: TCC 2.01 порождает ASM без директивы .386, поэтому
      32-битные регистры использовать нельзя ("Undefined symbol: eax",
      зонд P1 в Zond_Lab7.txt). Форма "asm { ... }" TASM 4.1 тоже
      отвергает ("Unknown character", зонды _zond16/A,C). Здесь только
      проверенная форма: одна команда на строку, без скобок, операнд -
      глобальная переменная: asm finit / asm fstcw hw_cw / asm fstsw hw_sw
      (зонд P2: после FINIT CW=037F, SW=0000).
    - 80-битное значение берётся БЕЗ asm: "long double" в TCC - это 80 бит
      / 10 байт (float.h: LDBL_MANT_DIG = 64), и тот же прогон
      (_zond16/H1) дал для "long double lf = (long double) 16.02;" ровно
      контрольную запись F6 28 5C 8F C2 F5 28 80 03 40. Эта дорожка
      надёжнее, чем "fstp tbyte ptr": tbyte ptr в порождённом ASM без
      .386 этим тулчейном не проверен. Оба варианта 80-битного образа
      (литерал и расширение double) напечатаны раздельно, 6c и 6d.
    - Байты из памяти - только через memcpy в unsigned char[]; union с
      32-битными полями не используется.
    - Объявления переменных - в начале блока (C89, без объявлений внутри
      for и без C99-синтаксиса).
    - Все печатаемые строки зафиксированы короче 80 колонок, чтобы в
      DOSBox не было переносов, ломающих выравнивание битовых диаграмм.
    - Контрольные значения (получены РЕАЛЬНЫМ прогоном на том же
      тулчейне) - это СРАВНЕНИЕ, а не ожидание: расчёт обязан прийти к
      ним сам, и вердикт печатается словами.
        float  16.02: F6 28 80 41
        double 16.02: 85 EB 51 B8 1E 05 30 40
        VV     16.02: F6 28 5C 8F C2 F5 28 80 03 40
        printf: %.8f float -> 16.02000046 ; %.8lf double -> 16.02000000
    - Замечание о задании: в тексте шага 5 приводятся шестнадцатеричное
      слово DV 0x40305EB8B851EB85 и мантисса 0x8028F5C28F5C2. По байтам
      реального прогона (85 EB 51 B8 1E 05 30 40) это слово читается как
      0x4030051EB851EB85, а мантисса - 0x0051EB851EB85. Сверка в программе
      идёт ПО БАЙТАМ, а не по цитируемому HEX: байты - единственный
      источник, совпадающий с памятью компилятора.
==============================================================*/

#include <stdio.h>
#include <string.h>
#include <conio.h>

/*--------------------------------------------------------------
  Целочисленный калькулятор: 6 слов по 16 бит = 96 бит.
  a[0] - младшее слово (биты 0..15), a[5] - старшее (биты 80..95).
  Битовые поля никогда не перекрываются, поэтому сборка идёт через OR.
  --------------------------------------------------------------*/
#define NW 6

typedef unsigned word_t;

static void w_zero(word_t *a)
{
    int i;
    for (i = 0; i < NW; i++) a[i] = 0u;
}

static void w_copy(word_t *d, const word_t *s)
{
    int i;
    for (i = 0; i < NW; i++) d[i] = s[i];
}

static void w_or(word_t *d, const word_t *s)
{
    int i;
    for (i = 0; i < NW; i++) d[i] = (word_t) (d[i] | s[i]);
}

/* a |= v << pos, где v < 2^16 */
static void w_or_shl(word_t *a, int pos, unsigned v)
{
    int wi, bo;
    if (v == 0u) return;
    wi = pos / 16;
    bo = pos % 16;
    if (wi >= 0 && wi < NW) a[wi] = (word_t) (a[wi] | (word_t) (v << bo));
    if (bo != 0 && wi + 1 < NW)
        a[wi + 1] = (word_t) (a[wi + 1] | (word_t) (v >> (16 - bo)));
}

/* биты pos..pos+n-1 как 16-битное число (1 <= n <= 16) */
static unsigned w_bits(const word_t *a, int pos, int n)
{
    int wi, bo;
    unsigned v, mask;
    wi = pos / 16;
    bo = pos % 16;
    v = 0u;
    if (wi < NW) v = (unsigned) (a[wi] >> bo);
    if (bo + n > 16 && wi + 1 < NW) v |= (unsigned) (a[wi + 1] << (16 - bo));
    mask = (n >= 16) ? 0xFFFFu : ((1u << n) - 1u);
    return (unsigned) (v & mask);
}

/* сбросить все биты >= pos */
static void w_clear_ge(word_t *a, int pos)
{
    int i, wi, bo;
    wi = pos / 16;
    bo = pos % 16;
    if (wi < NW) {
        if (bo == 0) a[wi] = 0u;
        else a[wi] = (word_t) (a[wi] & (word_t) ((1u << bo) - 1u));
    }
    for (i = wi + 1; i < NW; i++) a[i] = 0u;
}

/* Есть ли хоть один бит >= pos. Сдвиг слова применяется ТОЛЬКО когда он
   меньше 16: на 8086 счётчик сдвига маскируется младшими 5 битами, и
   сдвиг на 32+ дал бы мусор вместо нуля. */
static int w_any_above(const word_t *a, int pos)
{
    int i, s;
    for (i = 0; i < NW; i++) {
        s = pos - i * 16;
        if (s <= 0) { if (a[i] != 0u) return 1; }
        else if (s < 16) { if ((word_t) (a[i] >> s) != 0u) return 1; }
    }
    return 0;
}

static void w_shl(word_t *a, int n)
{
    word_t t[NW];
    int i, wi, bo;
    w_zero(t);
    wi = n / 16;
    bo = n % 16;
    for (i = 0; i < NW; i++) {
        if (i + wi < NW) t[i + wi] = (word_t) (t[i + wi] | (word_t) (a[i] << bo));
        if (bo != 0 && i + wi + 1 < NW)
            t[i + wi + 1] = (word_t) (t[i + wi + 1] | (word_t) (a[i] >> (16 - bo)));
    }
    w_copy(a, t);
}

/* a *= k; возвращается перенос за старшее слово */
static unsigned w_mul_k(word_t *a, unsigned k)
{
    unsigned long t;
    unsigned c;
    int i;
    c = 0u;
    for (i = 0; i < NW; i++) {
        t = (unsigned long) a[i] * (unsigned long) k + (unsigned long) c;
        a[i] = (word_t) (t & 0xFFFFul);
        c = (unsigned) (t >> 16);
    }
    return c;
}

static void w_inc(word_t *a)
{
    int i;
    for (i = 0; i < NW; i++) {
        a[i] = (word_t) (a[i] + 1u);
        if (a[i] != 0u) break;
    }
}

static int w_cmp(const word_t *a, const word_t *b)
{
    int i;
    for (i = NW - 1; i >= 0; i--) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
}

/* a -= b; предполагается a >= b */
static void w_sub(word_t *a, const word_t *b)
{
    long t, br;
    int i;
    br = 0;
    for (i = 0; i < NW; i++) {
        t = (long) a[i] - (long) b[i] - br;
        if (t < 0L) { t += 65536L; br = 1; } else br = 0;
        a[i] = (word_t) t;
    }
}

/* деление на 10 "в столбик", возвращается остаток */
static unsigned w_div10(word_t *a)
{
    unsigned long t, rem;
    int i;
    rem = 0;
    for (i = NW - 1; i >= 0; i--) {
        t = (rem << 16) | (unsigned long) a[i];
        a[i] = (word_t) (t / 10ul);
        rem = t % 10ul;
    }
    return (unsigned) rem;
}

/*--------------------------------------------------------------
  Печать битов, HEX и байтов.
  --------------------------------------------------------------*/
static const char hexdig[] = "0123456789ABCDEF";

static void p_nib(unsigned v)
{
    putchar(hexdig[v & 15u]);
}

/* шестнадцатеричная запись низших nbit, MSB первым */
static void p_hexbits(const word_t *a, int nbits)
{
    int rem, pos, v;
    rem = nbits % 4;
    pos = nbits - rem;
    if (rem != 0) { v = (int) w_bits(a, pos, rem); p_nib((unsigned) v); }
    while (pos > 0) { pos -= 4; v = (int) w_bits(a, pos, 4); p_nib((unsigned) v); }
}

static void p_bin(unsigned v, int n)
{
    int i;
    for (i = n - 1; i >= 0; i--) putchar((char) ('0' + (int) ((v >> i) & 1u)));
}

/* n бит поля a, начиная с бита pos, MSB первым; точка каждые 4 бита */
static void p_field_bits(const word_t *a, int pos, int n)
{
    int i;
    for (i = n - 1; i >= 0; i--) {
        putchar((char) ('0' + (int) w_bits(a, pos + i, 1)));
        if (i > 0 && (i % 4) == 0) putchar('.');
    }
}

/* те же биты без разделителя (длинные поля - чтобы строка не переносилась) */
static void p_field_raw(const word_t *a, int pos, int n)
{
    int i;
    for (i = n - 1; i >= 0; i--) putchar((char) ('0' + (int) w_bits(a, pos + i, 1)));
}

/* байты расчётного слова в порядке памяти (little-endian) */
static void p_word_bytes_le(const word_t *a, int nbytes)
{
    int i;
    unsigned b;
    for (i = 0; i < nbytes; i++) {
        b = (unsigned) ((a[i >> 1] >> (8 * (i & 1))) & 0xFFu);
        printf("%02X ", b);
    }
}

static void p_bytes_le(const unsigned char *b, int n)
{
    int i;
    for (i = 0; i < n; i++) printf("%02X ", (unsigned) b[i]);
}

/* десятичная запись целого a (до 96 бит) */
static void w_print_dec(const word_t *a)
{
    word_t t[NW];
    char s[32];
    int p, n;
    w_copy(t, a);
    p = 0;
    do {
        s[p++] = (char) ('0' + (int) w_div10(t));
    } while (w_any_above(t, 1) || t[0] != 0u);
    for (n = p - 1; n >= 0; n--) putchar(s[n]);
}

/* Точные десятичные цифры числа  num / (dsmall * 2^k).
   Нужно num < 2^(k+16) - это проверяется перед печатью.
   "Школьный" алгоритм: целая часть берётся отдельно, дробная умножается
   на 10 по кругу, поэтому переполнения нет и всё остаётся точным. */
static void w_digits(const word_t *num, int k, unsigned dsmall, int nd, char *out)
{
    word_t t[NW];
    unsigned h, tot, d, ip;
    int i, p;

    if (w_any_above(num, k + 16)) { sprintf(out, "<overflow: num >= 2^(k+16)>"); return; }
    w_copy(t, num);
    h = w_bits(t, k, 16);                  /* num >> k  (целая часть) */
    w_clear_ge(t, k);                      /* осталась num mod 2^k    */
    ip = h / dsmall;
    h = h - ip * dsmall;
    p = sprintf(out, "%u.", ip);
    for (i = 0; i < nd; i++) {
        w_mul_k(t, 10u);
        tot = h * 10u + w_bits(t, k, 16);
        w_clear_ge(t, k);
        d = tot / dsmall;
        h = tot - d * dsmall;
        out[p++] = (char) ('0' + (int) d);
    }
    out[p] = '\0';
}

/*--------------------------------------------------------------
  Глобальные данные.
  Поток битов числа 801/50:
    sb[0]      - старший бит мантиссы (в KV/DV подразумеваемый),
    sb[1..4]   - младшие 4 бита целой части 16,
    sb[5..84]  - двоичные цифры дробной части 0.02 (NSF = 80 штук).
  --------------------------------------------------------------*/
#define NSF   80
#define SBLEN (1 + 4 + NSF)                /* 85 */
#define WIN   36                           /* сколько бит дробной части показываем */

static unsigned char sb[SBLEN];
static unsigned char fbit[NSF];
static int whole_bits[8];
static int n_whole;
static int period_len, period_first;
static char period_pat[NSF + 1];

static int expo;
static unsigned e_kv, e_dv, e_vv;

static word_t t_kv[NW], t_dv[NW], t_vv[NW];            /* поля ДО округления */
static word_t m_kv[NW], m_dv[NW], m_vv[NW];            /* поля ПОСЛЕ округления */
static word_t img_kv[NW], img_dv[NW], img_vv[NW];      /* итоговые битовые образы */
static word_t sig_kv[NW], sig_dv[NW], sig_vv[NW];      /* мантисса как целое */
static int p_kv, p_dv, p_vv;               /* вес старшего бита мантиссы: 23/52/63 */
static int k_kv, k_dv, k_vv;               /* знаменатель 2^k итогового значения */
static int g_kv, r_kv, s_kv, inc_kv, ovfl_kv;
static int g_dv, r_dv, s_dv, inc_dv, ovfl_dv;
static int g_vv, r_vv, s_vv, inc_vv, ovfl_vv;
static int fe_kv, fe_dv, fe_vv;            /* номер первой неверной цифры после точки */
static word_t exact_num[NW];                   /* 801: 16.02 = 801/50 точно */

static unsigned hw_cw, hw_sw;              /* слова управления и состояния FPU */

/*--------------------------------------------------------------
  Поток битов: целая часть делением, дробная умножением.
  --------------------------------------------------------------*/
static void build_bits(void)
{
    unsigned pos[51];
    unsigned n;
    int i, j, r, prod, bit, v;

    n = 16u;
    i = 0;
    while (n > 0u) {                       /* младший бит первым */
        whole_bits[i++] = (int) (n % 2u);
        n = n / 2u;
    }
    n_whole = i;
    for (i = 0; i < n_whole / 2; i++) {    /* разворачиваем: MSB первым */
        v = whole_bits[i];
        whole_bits[i] = whole_bits[n_whole - 1 - i];
        whole_bits[n_whole - 1 - i] = v;
    }

    sb[0] = 1;
    for (i = 1; i < n_whole; i++) sb[i] = (unsigned char) whole_bits[i];

    for (i = 0; i <= 50; i++) pos[i] = 0u;
    r = 1;
    pos[1] = 1u;                           /* остаток 1 был до 1-го бита: счёт 1 */
    period_len = 0;
    period_first = 0;
    for (i = 0; i < NSF; i++) {
        prod = r * 2;
        bit = (prod >= 50) ? 1 : 0;
        r = prod - bit * 50;
        fbit[i] = (unsigned char) bit;
        sb[n_whole + i] = (unsigned char) bit;
        j = (int) pos[r];
        if (j == 0) pos[r] = (unsigned) (i + 2);
        else if (period_len == 0) {
            period_first = j - 1;          /* 0-based индекс первого бита периода */
            period_len = (i + 1) - period_first;
        }
    }
    for (i = 0; i < period_len && i < NSF; i++)
        period_pat[i] = (char) ('0' + (int) fbit[period_first + i]);
    period_pat[period_len] = '\0';

    w_zero(exact_num);
    w_or_shl(exact_num, 0, 801u);
    expo = n_whole - 1;                    /* сдвиг точки до вида 1.xxxxx */
    e_kv = (unsigned) (expo + 127);
    e_dv = (unsigned) (expo + 1023);
    e_vv = (unsigned) (expo + 16383);
}

static void show_frac_steps(int nsteps)
{
    int i, r, prod, bit;
    r = 1;
    printf("   no.   mnozhimoe  x2   proizvedenie   bit   ostatok\n");
    printf("   ---- ---------- ---  -------------- ----- ----------\n");
    for (i = 1; i <= nsteps; i++) {
        prod = r * 2;
        bit = (prod >= 50) ? 1 : 0;
        printf("   %2d    %2d/50     x2     %3d/50         %d     %2d/50\n",
               i, r, prod, bit, prod - bit * 50);
        r = prod - bit * 50;
    }
}

/* Линейка под строкой битов дробной части: '<' на бите lo, '>' на бите hi,
   '=' между ними, 'G' на hi+1 (guard), 'R' на hi+2 (round), 's' дальше
   (sticky). Пробелы расставлены ровно как в строке битов. */
static void p_ruler(int lo, int hi)
{
    int i;
    char c;
    for (i = 1; i <= WIN; i++) {
        c = ' ';
        if (i == lo) c = '<';
        else if (i == hi) c = '>';
        else if (i > lo && i < hi) c = '=';
        else if (i == hi + 1) c = 'G';
        else if (i == hi + 2) c = 'R';
        else if (i > hi + 2) c = 's';
        putchar(c);
        if (i % 4 == 0) putchar(' ');
    }
    putchar('\n');
}

/*--------------------------------------------------------------
  Округление поля "до ближайшего, при равных - к чётному" (RC=00).
  start - индекс в sb() первого бита поля, width - ширина поля,
  lead  - 1, если старший бит поля ЯВНЫЙ (VV), 0 для скрытого (KV/DV).
  --------------------------------------------------------------*/
static void round_field(int start, int width, int lead, word_t *tr, word_t *ou,
                        int *pg, int *pr_, int *ps, int *pinc, int *povfl)
{
    int i, gg, rr, ss;
    w_zero(tr);
    for (i = 0; i < width; i++)
        if (sb[start + i]) w_or_shl(tr, width - 1 - i, 1u);

    gg = (start + width < SBLEN)      ? (int) sb[start + width]     : 0;
    rr = (start + width + 1 < SBLEN)  ? (int) sb[start + width + 1] : 0;
    ss = 0;
    for (i = start + width + 2; i < SBLEN; i++) if (sb[i]) ss = 1;

    *pg = gg; *pr_ = rr; *ps = ss;
    *pinc = 0;
    if (gg == 1) {
        if (rr == 1 || ss == 1) *pinc = 1;                 /* больше половины -> вверх */
        else *pinc = (int) (w_bits(tr, 0, 1) & 1u);        /* ровно 1/2 -> к чётному  */
    }
    w_copy(ou, tr);
    if (*pinc) w_inc(ou);

    *povfl = w_any_above(ou, width);                   /* выход за старший бит поля */
    if (*povfl) {
        /* мантисса стала 2.0: у KV/DV поле обнуляется, у VV единица уходит
           в явный старший бит; порядок увеличивает вызывающий код */
        w_zero(ou);
        if (lead) w_or_shl(ou, width - 1, 1u);
    } else {
        w_clear_ge(ou, width);
    }
}

static void compute_images(void)
{
    round_field(1, 23, 0, t_kv, m_kv, &g_kv, &r_kv, &s_kv, &inc_kv, &ovfl_kv);
    round_field(1, 52, 0, t_dv, m_dv, &g_dv, &r_dv, &s_dv, &inc_dv, &ovfl_dv);
    round_field(0, 64, 1, t_vv, m_vv, &g_vv, &r_vv, &s_vv, &inc_vv, &ovfl_vv);
    if (ovfl_kv) e_kv++;
    if (ovfl_dv) e_dv++;
    if (ovfl_vv) e_vv++;

    /* KV:  S(1) | E(8) | M(23); знак 0, поэтому бит 31 = 0 */
    w_zero(img_kv);
    w_or_shl(img_kv, 23, e_kv);
    w_or(img_kv, m_kv);
    w_zero(sig_kv); w_copy(sig_kv, m_kv); w_or_shl(sig_kv, 23, 1u);
    p_kv = 23;  k_kv = p_kv - expo;

    /* DV:  S(1) | E(11) | M(52) */
    w_zero(img_dv);
    w_or_shl(img_dv, 52, e_dv);
    w_or(img_dv, m_dv);
    w_zero(sig_dv); w_copy(sig_dv, m_dv); w_or_shl(sig_dv, 52, 1u);
    p_dv = 52;  k_dv = p_dv - expo;

    /* VV:  S(1) | E(15) | M(64); старший бит мантиссы ЯВНЫЙ, уже в m_vv */
    w_zero(img_vv);
    w_or_shl(img_vv, 64, e_vv);
    w_or(img_vv, m_vv);
    w_zero(sig_vv); w_copy(sig_vv, m_vv);
    p_vv = 63;  k_vv = p_vv - expo;
}

/*--------------------------------------------------------------
  Секция 5: реконструкция значения и точная ошибка.
  --------------------------------------------------------------*/
static void report_value(const char *lbl, const word_t *sig, int pp, int kk,
                         const char *exact_str, int *pfirst_err_digit)
{
    word_t t1[NW], t2[NW], err[NW];
    char buf[96], ebuf[96], vbuf[96];
    int sgn, common, i, firstnz, found;

    w_copy(t1, sig); w_mul_k(t1, 50u);            /* 50 x SIG   */
    w_copy(t2, exact_num); w_shl(t2, kk);         /* 801 x 2^k  */
    sgn = w_cmp(t1, t2);
    w_copy(err, (sgn >= 0) ? t1 : t2);
    w_sub(err, (sgn >= 0) ? t2 : t1);

    w_digits(sig, pp, 1u, 24, buf);
    printf("   %s: SIG = ", lbl); w_print_dec(sig);
    printf("  / 2^%d\n", pp);
    printf("        mantissa v [1,2) = %s\n", buf);
    w_digits(sig, kk, 1u, 24, vbuf);
    printf("        x 2^%d (pjorjadok e) = SIG/2^%d ->  V = %s\n", expo, kk, vbuf);
    w_digits(err, kk, 50u, 24, ebuf);
    printf("        oshibka absolyutnaja V - 16.02 = %s%s\n",
           (sgn >= 0) ? "+" : "-", ebuf);
    w_digits(err, kk, 801u, 24, buf);
    printf("        oshibka otnositel'naja         = %s\n", buf);

    /* номер первой ненулевой цифры абсолютной ошибки после точки */
    firstnz = 0; found = 0;
    if (ebuf[0] == '0' && ebuf[1] == '.') {
        i = 2;
        while (ebuf[i] != '\0' && ebuf[i] == '0') { i++; firstnz++; }
        if (ebuf[i] != '\0') { firstnz++; found = 1; }
    }
    *pfirst_err_digit = found ? firstnz : 25;
    if (found) {
        printf("        pervaja nenulevaja cifra - na %d-m znake posle tochki,\n", firstnz);
        printf("        to est' vernyh cifr posle tochki: %d\n", firstnz - 1);
    } else {
        printf("        v 24 znakax posle tochki oshibki ne vidno (ona < 1e-24)\n");
    }

    common = 0;
    while (vbuf[common] != '\0' && vbuf[common] == exact_str[common]) common++;
    printf("        sovpadenie ZAPISI s tochnym 16.02: pervye %d simvola\n", common);
    printf("        (sravnivajte zapisi, a ne verit' im: 16.01999... rascxoditsja\n");
    printf("         rano, hotja oshibka v njom mala)\n");
}

static void decode_kv_bytes(const unsigned char *b)
{
    unsigned long mant;
    unsigned exp;
    exp  = (unsigned) (((b[3] & 0x7Fu) << 1) | (b[2] >> 7));
    mant = ((unsigned long) (b[2] & 0x7Fu) << 16) | ((unsigned long) b[1] << 8)
         | (unsigned long) b[0];
    printf("        razbor baytov iz pamyati: znak=%d  E=%02Xh (%d)  M=%06lXh\n",
           (int) (b[3] >> 7), exp, (int) exp, mant);
    printf("        -> e = %d - 127 = %d,  V = (1 + M/2^23) x 2^%d\n",
           (int) exp, (int) exp - 127, (int) exp - 127);
}

static void decode_dv_bytes(const unsigned char *b)
{
    unsigned long mhi, ml;
    unsigned exp;
    exp = (unsigned) (((b[7] & 0x7Fu) << 4) | (b[6] >> 4));
    mhi = ((unsigned long) (b[6] & 0x0Fu) << 16) | ((unsigned long) b[5] << 8)
        | (unsigned long) b[4];
    ml  = ((unsigned long) b[3] << 24) | ((unsigned long) b[2] << 16)
        | ((unsigned long) b[1] << 8) | (unsigned long) b[0];
    printf("        razbor baytov iz pamyati: znak=%d  E=%03Xh (%d)\n",
           (int) (b[7] >> 7), exp, (int) exp);
    printf("        M = %05lX:%08lXh -> e = %d - 1023 = %d, V = (1 + M/2^52) x 2^%d\n",
           mhi, ml, (int) exp, (int) exp - 1023, (int) exp - 1023);
}

/*--------------------------------------------------------------*/
int main(void)
{
    char buf[96], exact_str[96];
    word_t t1[NW], expct[NW];
    float cf;
    double cd;
    long double cl, cwiden;
    unsigned char mb[4], md[8], ml[10], mw[10];
    static const unsigned char ctrl_f[4]  = { 0xF6u, 0x28u, 0x80u, 0x41u };
    static const unsigned char ctrl_d[8]  = { 0x85u, 0xEBu, 0x51u, 0xB8u,
                                              0x1Eu, 0x05u, 0x30u, 0x40u };
    static const unsigned char ctrl_l[10] = { 0xF6u, 0x28u, 0x5Cu, 0x8Fu,
                                              0xC2u, 0xF5u, 0x28u, 0x80u,
                                              0x03u, 0x40u };
    int i;

    printf("=== Lab7 shag 5 (C): mehanizm prevrashhenija 16.02 v plavajushhij format ===\n");
    printf("    KV = 32 bita (float), DV = 64 bita (double),\n");
    printf("    VV = 80 bitov (long double / ST(0) u FPU)\n");
    printf("    Sekcii 1-5: vsja arifmetika celochislennaja (96 bit iz 16-bitnyh slov).\n");
    printf("    Plavajushhie literaly - tol'ko kak kontrol' v sekcii 6.\n\n");

    build_bits();
    compute_images();
    w_digits(exact_num, 0, 50u, 24, exact_str);

    /*================== SEKCIA 1 ==================*/
    printf("--- 1) ISHODNOE CHISLO 16.02: CELOJA I DROBNAYA CHASTI ---\n");
    printf("  16.02 = 1602/100 = 801/50, to est' celaja 16 + drobnaja 1/50.\n");
    printf("  Drobnaja chast' vedetsja kak para chislitel/50: ostatok vsegda beretsja\n");
    printf("  po modulju 50, pojetomu nikakogo okruglenija zdes' voobshhe net.\n\n");

    printf("  1a) celaja chast' 16 -> dvoinoe, delenie na 2 s ostatkom:\n");
    {
        unsigned n = 16u;
        i = 0;
        while (n > 0u) {
            printf("        %3u / 2 = %3u  ostatok %u   ->  bit %d  (ves 2^%d)\n",
                   n, n / 2u, (unsigned) (n % 2u), (int) (n % 2u), i);
            n = n / 2u;
            i++;
        }
    }
    printf("        bity ot mladshago k starsnemu: ");
    for (i = n_whole - 1; i >= 0; i--) printf("%d ", whole_bits[i]);
    printf("\n        16 = ");
    for (i = 0; i < n_whole; i++) printf("%d", whole_bits[i]);
    printf("b    (starsnij bit = 1; v KV/DV on stanet PODRAZUMEVAEMYM)\n\n");

    printf("  1b) drobnaja chast' 1/50 -> dvoinoe, umnozhenie na 2 (36 shagov):\n");
    show_frac_steps(36);
    printf("\n        dvoinye cifry drobi (pervye 32): ");
    for (i = 0; i < 32; i++) { printf("%d", fbit[i]); if ((i % 4) == 3) putchar(' '); }
    printf("\n\n        Ostatki povtarjajutsja, znachit povtarjajutsja i cifry:\n");
    printf("        golovka (bity do perioda) = %d bit(ov), period = %d bitov\n",
           period_first, period_len);
    printf("        period: (%s)\n", period_pat);
    printf("        0.02 = 0.");
    for (i = 0; i < period_first; i++) printf("%d", fbit[i]);
    printf("(%s)(%s)...  - beskonechno\n", period_pat, period_pat);
    printf("        Proverka po tablice vyshe: ostatok 2/50 voznik posle shaga 1 i\n");
    printf("        voznik snova posle shaga %d. Znachit bity %d..%d povtoryajutsja\n",
           period_first + period_len, period_first + 1, period_first + period_len);
    printf("        v bity %d..%d, i tak beskonechno (period %d).\n",
           period_first + period_len + 1, period_first + 2 * period_len, period_len);

    printf("\n  1c) VYVOD: 0.02 v dvoinoj sisteme - BESKONECHNAYA periodicheskaja drob':\n");
    printf("      znamenatel' 50 = 2 x 5^2 soderzhit mnozhitel' 5, kotoryj v dvoinoj\n");
    printf("      sisteme ne skorat'sja. Znachit 16.02 TOCHNO NE PREDSTAVIMO ni v KV,\n");
    printf("      ni v DV, ni v VV: luboj sokhranennyj bitovoj obraz - eto OKRUGLENIE.\n");
    printf("      Dalshe pokazano, kakie bita vyzhivajut i kakaja oshibka ostajetsja.\n\n");

    /*================== SEKCIA 2 ==================*/
    printf("--- 2) NORMALIZACIJA: sdvig dvoinoj tochki do mantissy v [1,2) ---\n");
    printf("        ishodnoe:  ");
    for (i = 0; i < n_whole; i++) printf("%d", whole_bits[i]);
    putchar('.');
    for (i = 0; i < 20; i++) printf("%d", fbit[i]);
    printf("...\n");
    printf("        tochka svinuta na %d mesta vlevo:\n", expo);
    printf("                     1.");
    for (i = 1; i < n_whole; i++) printf("%d", whole_bits[i]);
    for (i = 0; i < 20; i++) printf("%d", fbit[i]);
    printf("...  x 2^%d\n", expo);
    printf("        (starsnaja 1 v pole KV/DV bol'she NE pishetsja - ona PODRAZUMEVAEMAYA;\n");
    printf("         v 80-bitnov VV ona, naoborot, IZOBRAZHAETSJA: A7.txt, stroki 65-66)\n\n");
    printf("        znak               S = 0   (chislo polozhitel'noe)\n");
    printf("        istinnyj pjorjadok     e = %d\n", expo);
    printf("        harakteristika      E = e + bias:\n");
    printf("          KV (bias 2^7-1  = 127)  : E = %3d + 127   = %3d = ", expo, (int) e_kv);
    p_bin(e_kv, 8);  printf("b = %02Xh\n", e_kv);
    printf("          DV (bias 2^10-1 = 1023) : E = %3d + 1023  = %4d = ", expo, (int) e_dv);
    p_bin(e_dv, 11); printf("b = %03Xh\n", e_dv);
    printf("          VV (bias 2^14-1 = 16383): E = %3d + 16383 = %5d = ", expo, (int) e_vv);
    p_bin(e_vv, 15); printf("b = %04Xh\n", e_vv);
    printf("\n        Smeshchenie nuzhno, chtoby pjorjadki sravnivalis kak bezznakovie\n");
    printf("        celye i chtoby ne vodyt' otdel'nyj bit znaka pjorjadka. Znachenija\n");
    printf("        E=0 i E=max rezervirujutsja pod nuli/denormali i pod Inf/NaN, pojetomu\n");
    printf("        rabochij diapazon e uzhe ne vsja shirina polja.\n\n");

    /*================== SEKCIA 3 ==================*/
    printf("--- 3) MANTISSA: bity, otdbrosyvaemaja chast', guard/round/sticky ---\n");
    printf("        Normalizovannaja mantissa = 1.[bity nizhe]; starsnaja 1 v pole\n");
    printf("        KV/DV ne hodit, pojetomu pole - eto imenno drob'naja chast'.\n\n");
    printf("        Drob'naja chast' mantissy, bity 1..%d (numeracija s 1):\n", WIN);
    printf("        bit   : ");
    for (i = 1; i <= WIN; i++) { putchar((char) ('0' + (int) sb[i])); if ((i % 4) == 0) putchar(' '); }
    printf("\n        tens  : ");
    for (i = 1; i <= WIN; i++) { putchar((char) ('0' + (int) ((i / 10) % 10))); if ((i % 4) == 0) putchar(' '); }
    printf("\n        ones  : ");
    for (i = 1; i <= WIN; i++) { putchar((char) ('0' + (int) (i % 10))); if ((i % 4) == 0) putchar(' '); }
    printf("\n        pole KV:\n");
    p_ruler(1, 23);
    printf("        (<..=> 23 bita pola KV; G bit 24 guard; R bit 25 round;\n");
    printf("         s bity 26.. - sticky: vse, cto ostalos' za round)\n");
    printf("        Pole DV (52 bita) v etom okne ne pomestitsja - sm. 3b.\n");
    printf("        Pole VV (64 bita) nachinaetsja s YVNOGO starsnogo bita - sm. 3c.\n\n");

    printf("  3a) KV: pole 23 bita\n");
    printf("        otschyomnye 23 bita : 0x"); p_hexbits(t_kv, 23);
    printf("   ("); p_field_bits(t_kv, 0, 23); printf(")\n");
    printf("        otdbrosyvaetsja     : ");
    for (i = 24; i <= 34; i++) printf("%d", sb[i]);
    printf("...  [bit 24 guard, bit 25 round, bity 26+ sticky]\n");
    printf("        G=%d  R=%d  S=%d\n", g_kv, r_kv, s_kv);
    printf("        pravilo RC=00: G=0 -> syom;  G=1 i (R|S)=1 -> +1;\n");
    printf("                       G=1, R=0, S=0 (roavno 1/2 ulp) -> +1 tol'ko pri\n");
    printf("                       netchetnom pole\n");
    printf("        priroshchenie = %d,  vykhod za starsnij bit pola = %d\n", inc_kv, ovfl_kv);
    printf("        itogovoe pole 23 bita: 0x"); p_hexbits(m_kv, 23);
    printf("   ("); p_field_bits(m_kv, 0, 23); printf(")\n\n");

    printf("  3b) DV: pole 52 bita\n");
    printf("        otschyomnye 52 bita : 0x"); p_hexbits(t_dv, 52); printf("\n");
    printf("        (bity 1..52): "); p_field_raw(t_dv, 0, 52); printf("\n");
    printf("        otdbrosyvaetsja     : ");
    for (i = 53; i <= 66; i++) printf("%d", sb[i]);
    printf("...  [bit 53 guard, bit 54 round, bity 55+ sticky]\n");
    printf("        G=%d  R=%d  S=%d  ->  priroshchenie = %d,  vykhod za pole = %d\n",
           g_dv, r_dv, s_dv, inc_dv, ovfl_dv);
    printf("        Zdes' otdbrosyvaetsja MENSHE poloviny ulp (G=0), pojetomu DV lezhit\n");
    printf("        SNUZU ot 16.02.\n");
    printf("        itogovoe pole 52 bita: 0x"); p_hexbits(m_dv, 52); printf("\n");
    printf("        (bity 1..52): "); p_field_raw(m_dv, 0, 52); printf("\n\n");

    printf("  3c) VV: pole 64 bita (starsnij bit - YVNYJ, eto zhe sb[0])\n");
    printf("        otschyomnye 64 bita : 0x"); p_hexbits(t_vv, 64); printf("\n");
    printf("        otdbrosyvaetsja     : ");
    for (i = 64; i <= 76; i++) printf("%d", sb[i]);
    printf("...  [bit 65 guard, bit 66 round, bity 67+ sticky]\n");
    printf("        G=%d  R=%d  S=%d  ->  priroshchenie = %d,  vykhod za pole = %d\n",
           g_vv, r_vv, s_vv, inc_vv, ovfl_vv);
    printf("        itogovoe pole 64 bita: 0x"); p_hexbits(m_vv, 64); printf("\n\n");
    printf("        Podskazka dlya zashhity: u 1/50 beskonechnyj dvoinoj period, i v njom\n");
    printf("        est' edinitcy, pojetomu S vsegda = 1 vsled za G=1. Sluchaj 'roavno\n");
    printf("        1/2 ulp' (R=0, S=0) byvaet tol'ko u chisel s konechnym dvoinym\n");
    printf("        razlozheniem - 16.02 k nim ne otnositsja. Vykhoda za pole (mantissy\n");
    printf("        2.0) zdes' net ni v odnom formate: ovfl = %d/%d/%d.\n\n",
           ovfl_kv, ovfl_dv, ovfl_vv);

    /*================== SEKCIA 4 ==================*/
    printf("--- 4) SBORKA SLOVA: pola po bitam, HEX, bayty v pjorjadke pamjati ---\n\n");
    printf("  4a) KV (32 bita): S(1) | E(8) | M(23)\n");
    printf("        bit  31      : %d   (znak)\n", (int) w_bits(img_kv, 31, 1));
    printf("        bity 30..23  : "); p_field_bits(img_kv, 23, 8);
    printf("  = %02Xh = %d\n", e_kv, (int) e_kv);
    printf("        bity 22..0   : "); p_field_bits(img_kv, 0, 23);
    printf("  = 0x"); p_hexbits(m_kv, 23); printf("\n");
    printf("          S EEEEEEEE MMMMMMMMMMMMMMMMMMMMMMM\n");
    printf("          ");
    printf("%d ", (int) w_bits(img_kv, 31, 1));
    p_field_raw(img_kv, 23, 8); putchar(' ');
    p_field_raw(img_kv, 0, 23);
    printf("\n        slovo tselikom : 0x"); p_hexbits(img_kv, 32); printf("\n");
    printf("        bayty (LE)     : "); p_word_bytes_le(img_kv, 4); printf("\n");
    printf("           byte[0] = bity 7..0    (mladshie 8 bitov mantissy)\n");
    printf("           byte[1] = bity 15..8\n");
    printf("           byte[2] = bity 23..16  (starsnij bit mantissy + 7 bitov E)\n");
    printf("           byte[3] = bity 31..24  (ZNAK + 7 starsnih bitov E)\n\n");

    printf("  4b) DV (64 bita): S(1) | E(11) | M(52)\n");
    printf("        bit  63      : %d   (znak)\n", (int) w_bits(img_dv, 63, 1));
    printf("        bity 62..52  : "); p_field_bits(img_dv, 52, 11);
    printf("  = %03Xh = %d\n", e_dv, (int) e_dv);
    printf("        bity 51..0   : 0x"); p_hexbits(m_dv, 52); printf("\n");
    printf("          S EEEEEEEEEEE MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM\n");
    printf("          ");
    printf("%d ", (int) w_bits(img_dv, 63, 1));
    p_field_raw(img_dv, 52, 11); putchar(' ');
    p_field_raw(img_dv, 0, 52);
    printf("\n        slovo tselikom : 0x"); p_hexbits(img_dv, 64); printf("\n");
    printf("        bayty (LE)     : "); p_word_bytes_le(img_dv, 8); printf("\n");
    printf("           byte[7] = ZNAK + 7 starsnih bitov E (E=403h -> bayt 40h)\n");
    printf("           byte[0] = mladshie 8 bitov 52-bitnogo pola mantissy\n\n");

    printf("  4c) VV (80 bitov): S(1) | E(15) | M(64, starsnij bit IZOBRAZHEN)\n");
    printf("        bit  79      : %d   (znak)\n", (int) w_bits(img_vv, 79, 1));
    printf("        bity 78..64  : "); p_field_bits(img_vv, 64, 15);
    printf("  = %04Xh = %d\n", e_vv, (int) e_vv);
    printf("        bity 63..0   : 0x"); p_hexbits(m_vv, 64); printf("\n");
    printf("        slovo tselikom : 0x"); p_hexbits(img_vv, 80); printf("\n");
    printf("        bayty (LE)     : "); p_word_bytes_le(img_vv, 10); printf("\n");
    printf("           bayty 0..7 - mantissa (byte[7] soderzhit YVNYJ starsnij bit = 1)\n");
    printf("           bayty 8..9 - pjorjadok (znak v bit 7 bayta 9)\n\n");
    printf("        Raznica: v KV/DV starsnaja 1 v pole NE hodit (ekonomija odnogo bita),\n");
    printf("        v VV ona IZOBRAZHEMA - otuda 64 znashhih bita pri 80-bitnovom sleve.\n\n");

    /*================== SEKCIA 5 ==================*/
    printf("--- 5) OBRATNAYA REKONSTRUKCIYA: iz bitov snova v desjatichnoe, i oshibka ---\n");
    printf("        Formula: V = (-1)^S x (1 + sum M_i x 2^-i) x 2^e   dlya KV/DV,\n");
    printf("                 V = (-1)^S x (M s yvnym bitom) x 2^(E - 16383 - 63) dlya VV.\n");
    printf("        V celikh chislakh: V = SIG / 2^k, gde k = (ves starsnogo bita) - e.\n\n");

    printf("  5a) pervye 12 slagaemyh drobnoj chasti mantissy (tochnye desjatichnye):\n");
    for (i = 1; i <= 12; i++) {
        w_zero(t1);
        w_or_shl(t1, 20 - i, 1u);
        w_digits(t1, 20, 1u, i, buf);
        printf("        M_%2d = %d   x   2^-%2d = %-14s  %s\n", i, (int) sb[i], i, buf,
               sb[i] ? "uchastvuet" : "nol'");
    }
    printf("        (podrazumevaemaja 1 davaet 1.000000..., dalshe idut bity pola;\n");
    printf("         pervaja edinitca v pole - eto bit 10, ves 2^-10)\n\n");

    printf("  5b) rekonstrukcija i oshibka po kazhdomu formatu:\n");
    printf("        tochnoe 16.02 = 801/50 = %s\n", exact_str);
    report_value("KV", sig_kv, p_kv, k_kv, exact_str, &fe_kv);
    putchar('\n');
    report_value("DV", sig_dv, p_dv, k_dv, exact_str, &fe_dv);
    putchar('\n');
    report_value("VV", sig_vv, p_vv, k_vv, exact_str, &fe_vv);
    putchar('\n');
    printf("        Vyvod: pervaja oshibka posle tochki - na %d-m znake u KV, na %d-m u DV,\n",
           fe_kv, fe_dv);
    printf("        na %d-m u VV; to est' vernyh cifr posle tochki %d, %d i %d.\n",
           fe_vv, fe_kv - 1, fe_dv - 1, fe_vv - 1);
    printf("        Garantirovannaja tochnost' iz A7.txt (stroka 63): 6, 15 i 19 vernyh\n");
    printf("        desjatichnyh cifr. U KV i DV eta cifra - rovno chislo vernyh cifr posle\n");
    printf("        tochki; u VV k nim dobavljajutsja dve cifry celoj chasti (16), to est'\n");
    printf("        na 2 bolshe, chem ukazano vyshe, i garant 19 perekryvaetsja.\n");
    printf("        Chislo okrugljaetsja uzhe na shage 3 (sekciya 3) i bolshe ne menyatsja:\n");
    printf("        rekonstrukcija dajet to zhe samoe, chto lezit v pamjati.\n");
    printf("        Umnozenie na 2^%d vcheno v k = (ves starsnogo bita) - e, pojetomu\n", expo);
    printf("        otdel'nogo 'plavajushhego' shaga net: vse tochno v celikh.\n\n");

    /*================== SEKCIA 6 ==================*/
    printf("--- 6) SRAVNENIE S REAL'NOST'YU: bayty kompilyatora protiv rascheta ---\n\n");
    cf = 16.02f;
    cd = 16.02;
    cl = (long double) 16.02;
    cwiden = cd;                            /* rashirenie double -> 80 bit v FPU */
    memcpy(mb, &cf, 4);
    memcpy(md, &cd, 8);
    memcpy(ml, &cl, 10);
    memcpy(mw, &cwiden, 10);

    printf("        razmery v etom kompilyatore: sizeof float=%u  double=%u\n",
           (unsigned) sizeof(float), (unsigned) sizeof(double));
    printf("        sizeof long double=%u\n\n", (unsigned) sizeof(long double));

    printf("  6a) KV\n");
    printf("        raschet (sekciya 4a) : "); p_word_bytes_le(img_kv, 4); printf("\n");
    printf("        iz pamjati (float)   : "); p_bytes_le(mb, 4); printf("\n");
    printf("        kontrol'nyi progon   : "); p_bytes_le(ctrl_f, 4); printf("\n");
    decode_kv_bytes(mb);
    printf("        verdit raschet-vs-pamyat'  : %s\n",
           (memcmp(mb, img_kv, 4) == 0) ? "OK" : "RAZNICHA");
    printf("        verdit raschet-vs-kontrol' : %s\n",
           (memcmp(mb, ctrl_f, 4) == 0) ? "OK" : "RAZNICHA");
    printf("        tot zhe float cherez printf: %%.8f -> %.8f\n", cf);
    printf("        (sravnit' s oshibkoj iz 5b: v 8 znakax ona uzhe vidna)\n\n");

    printf("  6b) DV\n");
    printf("        raschet (sekciya 4b) : "); p_word_bytes_le(img_dv, 8); printf("\n");
    printf("        iz pamjati (double)  : "); p_bytes_le(md, 8); printf("\n");
    printf("        kontrol'nyi progon   : "); p_bytes_le(ctrl_d, 8); printf("\n");
    decode_dv_bytes(md);
    printf("        verdit raschet-vs-pamyat'  : %s\n",
           (memcmp(md, img_dv, 8) == 0) ? "OK" : "RAZNICHA");
    printf("        verdit raschet-vs-kontrol' : %s\n",
           (memcmp(md, ctrl_d, 8) == 0) ? "OK" : "RAZNICHA");
    printf("        tot zhe double cherez printf: %%.8lf -> %.8lf\n", cd);
    printf("        (oshibka DV v 8 znakax ne projavljaetsja - no eto NE znachit, chto\n");
    printf("         predstavlenie tochnoe: sm. 5b)\n\n");

    printf("  6c) VV (80 bit, to chto lezit v registre FPU)\n");
    printf("        raschet (sekciya 4c) : "); p_word_bytes_le(img_vv, 10); printf("\n");
    printf("        iz pamjati, (long double)16.02 : "); p_bytes_le(ml, 10); printf("\n");
    printf("        kontrol'nyi progon             : "); p_bytes_le(ctrl_l, 10); printf("\n");
    printf("        verdit raschet-vs-pamyat'      : %s\n",
           (memcmp(ml, img_vv, 10) == 0) ? "OK" : "RAZNICHA");
    printf("        verdit raschet-vs-kontrol'     : %s\n",
           (memcmp(ml, ctrl_l, 10) == 0) ? "OK" : "RAZNICHA");
    printf("\n");

    printf("  6d) rashirenie double -> 80 bit (to zhe chislo, no zagruzhennoe v FPU iz DV)\n");
    printf("        iz pamjati (cwiden = cd) : "); p_bytes_le(mw, 10); printf("\n");
    w_zero(expct);
    w_copy(expct, m_dv);
    w_or_shl(expct, 52, 1u);                /* 53-bitnaya sigmantra 2^52 + M52 */
    w_shl(expct, 11);                       /* ona zhe kak 64-bitnaya mantissa VV */
    w_or_shl(expct, 64, e_vv);              /* tot ze e, no bias 16383 (ne 1023) */
    printf("        raschet (53 bita -> 64, mladshie 11 bitov = 0):\n");
    printf("           mantissa 64 bita: 0x"); p_hexbits(expct, 64);
    printf("   pjorjadok: %04Xh\n", e_vv);
    printf("        verdit tol'ko po mantisse (bayty 0..7): %s\n",
           (memcmp(mw, expct, 8) == 0) ? "OK" : "RAZNICHA");
    printf("        Smysl: DV-chislo, zagruzhennoe v FPU, NE stanovit tochnee - k ego\n");
    printf("        mantisse prosto dobavlyajutsja nuli, i tochnost' 16.02 ogranichena\n");
    printf("        uzhe 53 bitami DV. Nastojashhij 80-bitnyi obraz (6c) ima druguju\n");
    printf("        mantissu: on okrugljaetsja po pravilu 64 bitov, a ne 52, i potomu\n");
    printf("        on tochnee oboikh.\n\n");

    printf("  6e) pochemu v 80-bitnov formate 16.02 lejit TOCHNEE vsego:\n");
    printf("        1) pole mantissy 64 bita protiv 23 (KV) i 52 (DV);\n");
    printf("        2) starsnij bit v nem IZOBRAZHEN, a ne podrazumevaetsja, to est' vse\n");
    printf("           64 bita real'no znashhie (A7.txt, stroki 62-66: 'Neyavnyj bit:\n");
    printf("           opushchen / izobrazhaetsja'), i okruglenie idet po 64, a ne po 52\n");
    printf("           dvoinym cifram;\n");
    printf("        3) pjorjadok 15 bit daet diapazon 10^-4931 .. 10^4932 - sdvig zdes'\n");
    printf("           daleko ot granicy, pojetomu ogranichenie tol'ko na mantissu.\n");
    printf("        Otdel'no: 80-bitnyi format - eto arifmeticheskij format REGISTRA, a ne\n");
    printf("        format xranenija; TCC xranit long double tem zhe obrazom (10 bayt),\n");
    printf("        chto i proveryeno vyshe v 6c.\n\n");

    asm finit
    asm fstcw hw_cw
    asm fstsw hw_sw
    printf("  6f) slovo upravlenija FPU posle FINIT (inline asm, bez 386-registrov):\n");
    printf("        CW = %04Xh   SW = %04Xh\n", hw_cw, hw_sw);
    printf("        bity 11..10 (RC, okruglenie) = ");
    p_bin((hw_cw >> 10) & 3u, 2);
    printf("\n");
    printf("        -> 00 = do blizhajshego, pri ravnyh k chetnomu.\n");
    printf("           Eto rovno to pravilo, chto primenjeno v sekicii 3.\n");
    printf("        bity  9..8  (PC, tochnost')  = ");
    p_bin((hw_cw >> 8) & 3u, 2);
    printf("\n");
    printf("        -> 11 = 64 bita (rasshirennaja tochnost').\n");
    printf("           FPU schitaet s 64-bitnovoj mantissoj, a pola KV/DV okrugljajutsja\n");
    printf("           pri xranenii - otuda i raznica mezhdu 16.02f, 16.02 (double) i\n");
    printf("           80-bitnov ST(0).\n");
    printf("        maski iskluchenij (bity 5..0) = %02Xh -> vse zamaskirovany: FPU\n",
           (unsigned) (hw_cw & 0x3Fu));
    printf("           obrabatyvaet osobyye sluchai sam; osobennyh situacij eta programma\n");
    printf("           ne provociruet.\n\n");

    /*================== SEKCIA 7 ==================*/
    printf("--- 7) KRATKYY OTVET (dlya zashhity) ---\n");
    printf("  1. 16.02 = 801/50, a 50 = 2 x 5^2. Dvojnaya drob' konechna tol'ko pri\n");
    printf("     znamenatele vida 2^n; mnozhitel' 5 skorat' nechem. Znachit 0.02 -\n");
    printf("     beskonechnaja periodicheskaja drob' (period %d bitov), i 16.02 TOCHNO\n",
           period_len);
    printf("     ne predstavimo ni v 32, ni v 64, ni v 80 bitov: luboj bitovoj obraz -\n");
    printf("     eto priblizhenie.\n");
    printf("  2. Mehanizm: 16.02 -> 10000.0000010100011110...b ->\n");
    printf("     1.00000000001010001111...b x 2^4 -> znak 0, harakteristika\n");
    printf("     4+127=131=83h (KV) / 4+1023=1027=403h (DV), mantissa 23/52 bita s\n");
    printf("     okrugleniem do blizhajshego (pri ravnyh - k chetnomu).\n");
    printf("  3. Garantirovannye tochnye desjatichnye cifry: KV 6, DV 15, VV 19\n");
    printf("     (A7.txt, stroka 63). Po etomu chislu: oshibka KV na %d-m znake posle\n",
           fe_kv);
    printf("     tochki, DV na %d-m, VV na %d-m (25 = ne vidno v 24 znakax) - eto i est'\n",
           fe_dv, fe_vv);
    printf("     nakoplennaja oshibka razryadnoj setki mantissy.\n");
    printf("  4. Oshibka terjaetsja na DVOH shagah: (a) pri otbrosa 23/52 bitov mantissy\n");
    printf("     (sekciya 3) i (b) pri peresypanii iz 80-bitnova registra v 32/64-bitnovoe\n");
    printf("     slovo pamjati. Pervyj shag neizbezhon (chislo ne predstavimo), vtoroj\n");
    printf("     zavisit ot razryadnosti xraneniya.\n");
    printf("  5. Raschytnye bayty sovpali s pamyat'ju kompilyatora i s kontrol'noj\n");
    printf("     zapis'ju progonov (verdit'y OK v sekicii 6a-6c): IEEE 754 v TCC\n");
    printf("     real'no rabotaet tak,\n");
    printf("     kak opisano v A7.txt, stroki 50-66 i 226-257.\n\n");
    printf("        Tablica parametr formata (A7.txt, stroki 57-66):\n");
    printf("        format  bitov  pole E  smeshchenie  pole M  tochn. cifr  neyavnyj bit\n");
    printf("        KV (C)     32       8          127      23            6  opushchen\n");
    printf("        DV (L)     64      11         1023      52           15  opushchen\n");
    printf("        VV (T)     80      15        16383      64           19  izobrazhaetsja\n");
    printf("        (C - korotkoe, L - dlinnoe, T - temporal'noe veshchestvennoe,\n");
    printf("         A7.txt, stroki 52-55)\n\n");
    printf("=== KONETS Lab7_5 (pod -DNOWAIT vyhod bez ozhidaniya klawishi) ===\n");
#ifndef NOWAIT
    getch();   /* конвенция HOWTO §2: интерактивная задача ждёт клавишу */
#endif
    return 0;
}
