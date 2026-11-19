# Лабораторная работа №10 — схемы контроля по модулю 2 и мажоритарный элемент

Работа выполнена в Quartus II 5.0 (Build 148 SJ Full Version) на гостевой Windows XP SP3
виртуальной машины Microelectronics, управляемой из Windows 11 через общую папку
(host D:\Desktop\NF = guest Z:). Ни одного действия в GUI Quartus не потребовалось.

## Итог

| Пункт | Артефакты | Компиляция | Моделирование | Ресурсы |
|---|---|---|---|---|
| 1. Ячейка чётности | parity2.bdf, parity2.bsf | OK | PASS 8/8 | 1 LE, 5 пинов |
| 2. Символ ячейки | parity2.bsf | принят Quartus в п.3 и п.4 | — | — |
| 3. Аналог КР1533ИП5 | eo8.bdf, eo8.bsf | OK | PASS 512/512 | 3 LE, 11 пинов |
| 4. Канал с ошибками | dtm.bdf, dtm.bsf, link.bdf | OK | PASS 18/18 и 10/10 | 9 LE / 11 LE |
| 5. VHDL-модель канала | eo8.vhd, dtm.vhd, link_vhd.vhd | OK | PASS 10/10, 27/27 диаграмм совпали с п.4 | 11 LE, 27 пинов |
| 6. Мажоритарный элемент | majority.bdf | OK | PASS 8/8 | 3 LE, 6 пинов |
| 7. VHDL-модель мажоритарного | majority.vhd | OK | PASS 8/8, совпало с п.6 | 3 LE, 6 пинов |
| 8. Синтезируемость eo8 | eo8.vhd + fit/asm/tan | OK | — | 3 LE, 11 пинов, 0 регистров, 0 бит памяти |

Отчёт: lab10_report.docx (14 рисунков, 9 таблиц).

## Структура папки

    specs/        декларативные описания всех восьми схем (JSON)
    vhdl/         eo8.vhd, dtm.vhd, link_vhd.vhd, majority.vhd
    generator/    конвейер: sexpr/library/gen/router/verify/vwf/bsf/build/run/draw
    images/       схемы и временные диаграммы, отрисованные по фактической геометрии файлов
    <пункт>/      файлы проекта Quartus (.bdf .bsf .vwf .qsf .qpf)
    <пункт>_out/  отчёты Quartus из гостевой VM (.map .fit .asm .sim .tan .flow .rpt, .sim.vwf, .sof)
    logs/         журналы гостевых прогонов

## Воспроизведение

    node tools/bdf/build.mjs lab10/specs/eo8.json --out D:/Desktop/NF/lab10/eo8
    node tools/bdf/run.mjs lab10/specs/parity2.json lab10/specs/majority.json lab10/specs/eo8.json ^
        lab10/specs/dtm.json lab10/specs/link.json --folder lab10 --timeout 500 --sample-at 0.75
    node tools/bdf/run.mjs lab10/specs/eo8_vhd.json lab10/specs/majority_vhd.json ^
        lab10/specs/link_vhd.json --folder lab10 --asm --tan

## Главный вывод

Код с одним битом чётности: Smin = 2 → Eобн = 1, Eиспр = 0. Подтверждено моделированием:
одиночная (ERR = 001/080/100), тройная (007) и девятерная (1FF) ошибки обнаружены,
двойная (ERR = 003) прошла незамеченной, хотя данные исказились (A5 → A6).
Мажоритарный элемент (троирование, Smin = 3) исправляет одиночную ошибку голосованием.
