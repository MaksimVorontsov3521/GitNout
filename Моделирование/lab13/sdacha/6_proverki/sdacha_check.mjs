// lab13/sdacha_check.mjs - аудит самодостаточности сдачи D:/Desktop/NF/lab13/sdacha/.
//
// Адаптирован из lab12/sdacha_check.mjs и расширен тем, чего в lab 12 не было: полный скан
// абсолютных ссылок с классификацией (обоснованная документационная ссылка против дыры),
// проверка каждого обещанного ZIPISKA файла, сверка дублированных копий библиотеки хешем,
// разбор каждого .bdf/.bsf/.vwf/.qsf/.tdf/.vhd.
//
// Правила:
//   1. Каждая запись .qsf (FILE_*, TOP_LEVEL_ENTITY) разрешается в ТОЙ ЖЕ папке: Quartus
//      ищет источники только в каталоге проекта, поэтому путь наружу для него мёртв.
//   2. Каждая сущность, которую лист instantiate-ит, имеет там же .bdf и .bsf.
//   3. У каждого .qpf проекта есть .vwf, .sim.vwf и отчёты map/fit/sim/flow; asm/tan/pin
//      требуются только если размещение удалось (иначе их отсутствие - измеренный результат).
//   4. Каждый файл, названный в ZIPISKA, существует.
//   5. Ни один доставленный текстовый файл не ссылается наружу на файл, которого нет в сдаче.
//   6. Ни один доставленный файл не пустой; .png/.docx проверены на сигнатуру контейнера.
//
// Доказательство складывается в lab13/evidence/sdacha_selfcheck.json.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import * as S from './tools/bdf/sexpr.mjs';
import * as SC from './tools/bdf/simcheck.mjs';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
// Где лежит сдача: если этот скрипт запущен ИЗ сдачи (lab13/sdacha/6_proverki/),
// короче всего подняться на две ступени; если из рабочего дерева - брать
// фиксированный путь. Проверяем существованием, а не догадкой.
const CANDIDATES = [
  path.resolve(HERE, '..'),            // sdacha/6_proverki -> sdacha (запуск из сдачи)
  path.resolve(HERE, '..', 'sdacha'),  // lab13/            -> lab13/sdacha
  'D:/Desktop/NF/lab13/sdacha',        // явная ссылка последнего resort
];
const SD = CANDIDATES.find((c) => fs.existsSync(path.join(c, '0_zadanie_i_otchet'))) || CANDIDATES[CANDIDATES.length - 1];
const IN_DELIVERY = path.posix.normalize(HERE.replace(/\\/g, '/')).startsWith(path.posix.normalize(SD.replace(/\\/g, '/')));
// Доказательство: в сдаче пишем в её собственный evidence/, в рабочем дереве - как было
const EVDIR = IN_DELIVERY ? path.join(SD, '6_proverki', 'evidence') : path.join(HERE, 'evidence');
const MP2 = 'D:/Desktop/NF/dshagent/ref/mp2';
const VWFREF = 'D:/Desktop/NF/dshagent/ref/vwf';
const REF_ALTERA = 'D:/Desktop/NF/lab13/ref';

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex').slice(0, 12);
const shaFile = (p) => sha(fs.readFileSync(p));
const exists = (p) => { try { return fs.existsSync(p); } catch { return false; } };

const TEXT_EXT = ['.txt', '.json', '.qsf', '.qpf', '.vwf', '.bdf', '.bsf', '.tdf',
  '.vhd', '.rpt', '.eqn', '.pin', '.inc', '.xml', '.log'];
const BIN_EXT = ['.png', '.docx', '.sof', '.pdf'];

// ---------------------------------------------------------------------------
// Дерево сдачи.
// ---------------------------------------------------------------------------
const tree = [];
(function walk(d, rel) {
  for (const e of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const r = rel ? rel + '/' + e.name : e.name;
    const abs = path.join(d, e.name);
    if (e.isDirectory()) walk(abs, r);
    else tree.push({ path: r, abs, basename: e.name, bytes: fs.statSync(abs).size,
      ext: path.extname(e.name).toLowerCase(), folder: r.split('/')[0] });
  }
})(SD, '');
const byFolder = {};
for (const f of tree) (byFolder[f.folder] = byFolder[f.folder] || []).push(f);
// индекс: имя файла -> все места в сдаче, где он лежит
const index = {};
for (const f of tree) (index[path.basename(f.path)] = index[path.basename(f.path)] || []).push(f.path);

// ---------------------------------------------------------------------------
// Скан абсолютных ссылок. Класс символов собирается через \x27 и \x60, чтобы
// в исходнике не было ни апострофа, ни бэктика внутри регулярного выражения.
// ---------------------------------------------------------------------------
const NOTPATH = '[^\\s"\\x27\\x60,;|()<>\\[\\]{}]';
const ABS = new RegExp('[A-Za-z]:' + '[\\\\/]{1,2}' + NOTPATH + '*' + NOTPATH.replace(']', '[^]') + '.', 'g');
const norm = (s) => s.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
const mkdir = (d) => { if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true }); };

const CATEGORIES = [
  { id: 'sdacha', re: /^d:\/desktop\/nf\/lab13\/sdacha(\/|$)/, label: 'внутри самой сдачи', ok: () => true },
  { id: 'install', re: /^[a-z]:\/altera\//, label: 'установка Quartus II (документация инструмента)',
    ok: (base) => !!index[base] || base === 'bin' || base === 'libraries' || base === 'megafunctions' },
  { id: 'guestwork', re: /^c:\/dsh\//, label: 'рабочий каталог проекта в гостевой ОС',
    ok: (base) => !!index[base] },
  { id: 'netdrive', re: /^z:\//, label: 'сетевой диск гостя (цитата неудачной попытки в журнале)',
    ok: () => true },
  { id: 'guesttree', re: /^d:\/desktop\/nf\/lab13\//, label: 'дерево гостя (авторское и рабочее)',
    ok: (base) => !!index[base] },
  { id: 'reflib', re: /^d:\/desktop\/nf\/dshagent\//, label: 'справочная библиотека курса',
    ok: (base) => !!index[base] },
  { id: 'authorws', re: /^[a-z]:\//, label: 'дерево авторства (workspace)',
    ok: (base) => !!index[base] },
];
const classify = (hit) => {
  const n = norm(hit);
  const base = path.basename(n);
  for (const c of CATEGORIES) {
    if (!c.re.test(n)) continue;
    return { category: c.id, label: c.label, justified: !!c.ok(base), base };
  }
  return { category: 'unknown', label: 'не распознан', justified: false, base };
};

const absRows = [], absProblems = [], absCounts = {};
let scanned = 0, skippedBinary = 0;
for (const f of tree) {
  if (BIN_EXT.includes(f.ext)) { skippedBinary++; continue; }
  if (!TEXT_EXT.includes(f.ext)) continue;
  scanned++;
  const lines = fs.readFileSync(f.abs, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    for (const m of line.matchAll(ABS)) {
      const c = classify(m[0]);
      absCounts[c.category] = (absCounts[c.category] || 0) + 1;
      const row = { file: f.path, line: i + 1, hit: m[0], category: c.category, justified: c.justified };
      absRows.push(row);
      if (!c.justified) absProblems.push(row);
    }
  });
}
// контейнеры: смотрим, нет ли внутри docx распакованных абсолютных путей наружу
const docxRows = [];
for (const f of tree.filter((x) => x.ext === '.docx')) {
  const raw = fs.readFileSync(f.abs).toString('latin1');
  for (const pat of ['D:/Desktop', 'D:\\Desktop', 'C:/Users', 'C:\\Users', 'Z:\\']) {
    const n = raw.split(pat).length - 1;
    docxRows.push({ file: f.path, pattern: pat, hits: n,
      note: n ? 'префикс встречается в несжатой части контейнера' : 'в контейнере не встречается' });
  }
  docxRows.push({ file: f.path, pattern: '(сигнатура)', hits: raw.startsWith('PK') ? 1 : 0,
    note: raw.includes('word/document.xml') ? 'zip цел, есть word/document.xml' : 'НЕТ word/document.xml' });
}

// ===========================================================================
// Часть B. Структурные правила по папкам.
// ===========================================================================
const struct = [];
const structProblems = [];
const need = (cond, msg) => { if (!cond) structProblems.push(msg); return !!cond; };

// B.1 - ни один файл не пустой; контейнеры имеют сигнатуру
let zero = 0, sigBad = 0;
for (const f of tree) {
  if (f.bytes === 0) { structProblems.push('нулевой файл: ' + f.path); zero++; }
  const b = fs.readFileSync(f.abs);
  if (f.ext === '.png') {
    // трейдер PNG: ... IEND + 4 байта CRC, значит ASCII-маркер на len-8..len-4
    const ok = b.length > 8 && b[0] === 0x89 && b.toString('ascii', 1, 4) === 'PNG' &&
      b.toString('ascii', b.length - 8, b.length - 4) === 'IEND';
    if (!ok) { structProblems.push('повреждённый PNG: ' + f.path); sigBad++; }
  }
  if (f.ext === '.docx' && !(b[0] === 0x50 && b[1] === 0x4b)) {
    structProblems.push('повреждённый DOCX (нет PK): ' + f.path); sigBad++;
  }
}
struct.push({ rule: 'B.1 ни одного нулевого файла; PNG и DOCX имеют сигнатуру контейнера',
  files: tree.length, zero, sigBad });

// B.2 - записи .qsf, указывающие на файл, разрешаются в ТОЙ ЖЕ папке.
// Смысл правила: Quartus ищет источники только в каталоге проекта, поэтому
// ссылка наружу для него мертва, а относительный путь вне папки - тоже.
const qsfRows = [];
for (const f of tree.filter((x) => x.ext === '.qsf')) {
  const folder = path.dirname(f.abs);
  const here = new Set(fs.readdirSync(folder));
  const txt = fs.readFileSync(f.abs, 'utf8');
  const refs = [...txt.matchAll(/set_global_assignment\s+-name\s+(FILE_\w+|TOP_LEVEL_ENTITY)\s+(.+)/g)]
    .map((m) => ({ key: m[1], val: m[2].trim().replace(/^"|"$/g, '') }));
  const unresolved = [];
  for (const r of refs) {
    const base = path.basename(r.val.split(/[\\/]+/).pop());
    if (r.key === 'TOP_LEVEL_ENTITY') {
      // сущность верхнего уровня живёт в любом источнике с таким именем:
      // .bdf (задания 1 и 3), .vhd (задание 2), .tdf (задание 4)
      const hit = ['bdf', 'vhd', 'tdf', 'bsf'].some((e) => here.has(base + '.' + e));
      if (!hit) unresolved.push(r.key + '=' + r.val);
    } else if (!here.has(base)) unresolved.push(r.key + '=' + r.val);
  }
  qsfRows.push({ file: f.path, refs: refs.length, unresolved });
  need(unresolved.length === 0, f.path + ': ссылки .qsf не разрешаются в папке -> ' + unresolved.join(', '));
}
struct.push({ rule: 'B.2 каждая FILE_*/TOP_LEVEL_ENTITY в .qsf указывает на файл ТОЙ ЖЕ папки',
  files: qsfRows.length, refs: qsfRows.reduce((a, r) => a + r.refs, 0),
  unresolved: qsfRows.reduce((a, r) => a + r.unresolved.length, 0) });

// B.3 - каждая инстанцируемая сущность из библиотеки курса имеет лист или
// символ там же; мегафункции (lpm_*, altram) разворачиваются установкой и
// листа не требуют
const MEGARE = /^(lpm_|alt|dff|dffe|jk|tff|latch|cmos|buf|not|and|or|nand|nor|xor|xnor|tri|opndrn|vcc|gnd|input|output|bidirectional|decode|mux|encoder|dom|dif|faked|ram|rom|fifo|shift|add|cmp|cntr|lpt|dffeas|dffc|mfuz|azur|mfrz)$/i;
const instRows = [];
for (const f of tree.filter((x) => x.ext === '.bdf')) {
  const here = new Set(fs.readdirSync(path.dirname(f.abs)));
  const txt = fs.readFileSync(f.abs, 'utf8');
  const ents = new Set();
  for (const m of txt.matchAll(/functions+instances+(w+)(:?[sS]{0,400}?)?/g)) { /* имена ниже */ }
  // имя сущности в .bdf задаётся строкой "entity <имя>" блока PORT/FUNCTION
  for (const m of txt.matchAll(/entitys+"?([A-Za-z][w$~[]]*)"?s*(?:;|$)/gim)) ents.add(m[1]);
  for (const m of txt.matchAll(/lpm_types*=s*"([^"]+)"/gi)) ents.add(m[1]);
  const missing = [];
  for (const e of ents) {
    if (MEGARE.test(e)) continue;
    if (!here.has(e + '.bdf') && !here.has(e + '.bsf')) missing.push(e);
  }
  instRows.push({ file: f.path, entities: [...ents].length, missing });
  need(missing.length === 0, f.path + ': инстанцируемая сущность без листа/символа в папке -> ' + missing.join(', '));
}
struct.push({ rule: 'B.3 каждая инстанцируемая НЕ-мегафункция имеет .bdf или .bsf в той же папке',
  files: instRows.length, missing: instRows.reduce((a, r) => a + r.missing.length, 0) });

// B.4 - комплект отчётов на каждый .qpf
const OK_RPT = ['.map.rpt', '.fit.rpt', '.sim.rpt', '.flow.rpt'];
const ASM_RPT = ['.asm.rpt', '.tan.rpt'];
const WAVE_RPT = ['.vwf', '.sim.vwf'];
const projRows = [];
for (const f of tree.filter((x) => x.ext === '.qpf')) {
  const folder = path.dirname(f.abs);
  const here = new Set(fs.readdirSync(folder));
  const nm = path.basename(f.abs, '.qpf');
  const fitTxt = here.has(nm + '.fit.rpt') ? fs.readFileSync(path.join(folder, nm + '.fit.rpt'), 'latin1') : '';
  const fitOk = /Quartus II Fitter was successful/i.test(fitTxt);
  const want = OK_RPT.concat(WAVE_RPT).concat(fitOk ? ASM_RPT.concat(['.pin']) : []);
  const missing = want.filter((e) => !here.has(nm + e));
  projRows.push({ project: nm, folder: path.dirname(f.path), fitOk,
    have: want.filter((e) => here.has(nm + e)), missing });
  need(missing.length === 0, nm + ' (' + path.dirname(f.path) + '): не хватает ' + missing.join(', ') +
    (fitOk ? '' : ' [размещение НЕ удалось: asm/tan/pin отсутствуют как измеренный результат]'));
}
struct.push({ rule: 'B.4 у каждого .qpf есть .vwf/.sim.vwf и map/fit/sim/flow; asm/tan/pin - только при удачном размещении',
  projects: projRows.length, incomplete: projRows.filter((r) => r.missing.length).length });

// B.5 - в сдаче запрещено любое производное дерево-мусор. Смысл не косметический:
// байткод Python (__pycache__/*.pyc) зависит от ВЕРСИИ интерпретатора, то есть
// это единственная невоспроизводимая двоичная вещь в дереве, и материалом работы он
// не является. Правило обязано быть здесь, а не только в сборщике: читатель,
// который прогнал _pdf_text.py/_pdf_cmp.py из сдачи, породит __pycache__ сам,
// и аудит обязан это поймать, а не принять за часть доставки.
const JUNK_EXT = ['.pyc', '.pyo'];
const junkRows = [];
for (const f of tree) {
  const inCache = f.path.split('/').includes('__pycache__');
  if (inCache || JUNK_EXT.includes(f.ext)) {
    junkRows.push({ file: f.path, bytes: f.bytes, why: inCache ? 'лежит в __pycache__' : 'расширение ' + f.ext });
  }
}
for (const j of junkRows) structProblems.push('производный мусор в сдаче: ' + j.file + ' (' + j.why + ', ' + j.bytes + ' Б)');
struct.push({ rule: 'B.5 в сдаче нет __pycache__ и .pyc/.pyo (байткод зависит от версии Python и не является материалом работы)',
  files: tree.length, junk: junkRows.length });

// ===========================================================================
// Часть C. Обещания ZIPISKA, хеши библиотеки, разбор каждого исходника.
// ===========================================================================

// C.1 - каждый файл, названный в ZIPISKA, существует в сдаче
// имя файла может содержать точки (ram4.sim.vwf, lpramwb_measured.json,
// lpm_ram_dq.bsf), поэтому класс имени включает точки, а не обрывается на них
const NAME_RE = new RegExp('([A-Za-z0-9_\\-]+(?:\\.[A-Za-z0-9_\\-]+)*\\.(?:bdf|bsf|vwf|qsf|qpf|tdf|vhd|json|mjs|py|txt|png|rpt|eqn|pin|log|xml|docx))', 'g');
const promised = [];
const unmetPromises = [];
for (const f of tree.filter((x) => x.basename === 'ZIPISKA.txt')) {
  const txt = fs.readFileSync(f.abs, 'utf8').replace(/^\uFEFF/, '');
  const folder = path.dirname(f.abs);
  const here = new Set(fs.readdirSync(folder));
  const lines = txt.split('\r\n');
  // Имена, которым предшествует квалификатор чужого дерева, - ЭТО НЕ ОБЕЩАНИЕ,
  // а документирование: так записка ссылается на скрипт аудита (lab13/), на
  // файл предыдущей лабораторной (lab12) и на генератор (tools/). Классифицируем
  // по префиксу, а не по языковому чутью: правило видно в коде и его можно
  // оспорить. Всё, что не квалифицировано как внешнее упоминание и чего нет в
  // сдаче, считается необещанным файлом и валитирует аудит.
  const OUTSIDE = new RegExp('(lab13|lab12|tools|evidence|guest_logs|lib_maxplus2|ref_altera)/$');
  // Перечисления вида «.map.rpt/.fit.rpt/.tan.rpt» - НЕ имена файлов, а суффиксы
  // одного списка: предыдущий символ точки или слэш означает, что захвачен
  // хвост, а не самостоятельное имя. Настоящее имя в записке всегда отделено
  // пробелом, скобкой или началом строки.
  // «/» двусмысленен: в перечислении «.map.rpt/.fit.rpt» он разделяет сиблингов
  // одного списка, а в «3_mem4x8/mem4x8.bdf» - квалифицирует путь. Различаем по
  // левому соседу: если перед «/» стоит имя известной папки сдачи, это путь.
  const FOLDERS_KNOWN = new Set(Object.keys(byFolder));
  const isFragment = (before) => {
    if (/[.]$/.test(before)) return true;
    if (/[/]$/.test(before)) {
      const left = before.replace(/[/]$/, '');
      const seg = left.split(/[/]/).pop();
      return !FOLDERS_KNOWN.has(seg);
    }
    return false;
  };
  // Ссылка на сдачу предыдущей лабораторной («у лабораторной 12 такой файл
  // был») тоже не обещание: имя принадлежит другому дереву и называется как
  // прецедент. Класс символа СОЗНАТЕЛЬНО не \w: в JavaScript \w ASCII-Only и
  // не покрывает кириллицу, поэтому «лабораторн\w* 12» не совпадало ни разу и
  // каждое упоминание lab12-прецедента ложно считалось дырой (измерено на
  // доставленной записке 0_zadanie_i_otchet, строка 40).
  const CYR = '[A-Za-zА-Яа-яЁё]';
  const OTHER_LAB = new RegExp('(лабораторн' + CYR + '* 12|lab ?12\\b)', 'i');
  const byName = new Map();
  lines.forEach((line, i) => {
    // Записка перенесена по словам, поэтому квалификатор («у lab 12 такой файл
    // был», «lab13/sdacha_check.mjs») иногда стоит на ПРЕДЫДУЩЕЙ строке того же
    // предложения. Ищем его в окне из трёх строк, а не на одной: иначе
    // классификация зависела бы от того, где случайно разорвалась строка, и
    // упоминание lab12-прецедента строкой ниже становилось бы «дырой».
    // Окно строится вместе с точными смешениями, чтобы префикс «чужого дерева»
    // искался по НЕПРЕРЫВНОМУ тексту: записка перенесена по словам, и
    // «lab13/» может остаться на конце предыдущей строки, а имя - на начале
    // следующей. Тогда проверка префикса по одной строке молча теряла
    // квалификацию, и имя становилось «дырой».
    const from = Math.max(0, i - 2);
    const parts = lines.slice(from, i + 1);
    const win = parts.join(' ');
    const winOff = win.length - line.length;
    for (const m of line.matchAll(NAME_RE)) {
      const before = line.slice(0, m.index);
      // фрагмент перечисления определяется по СВОЕЙ строке: точка или слэш
      // непосредственно перед именем - это однозначный признак списка, и
      // расширять его на окно было бы опасно (соседняя строка может кончаться
      // точкой обычного предложения, и тогда настоящее имя выпало бы из проверки)
      if (isFragment(before)) continue;
      const winBefore = win.slice(0, winOff + m.index);
      const external = OUTSIDE.test(before) || /[/]$/.test(winBefore) && OUTSIDE.test(winBefore) || OTHER_LAB.test(win);
      const cur = byName.get(m[1]) || { name: m[1], lines: [], external: true, inFolder: false, anywhere: false, suffix: false };
      cur.lines.push(i + 1);
      cur.external = cur.external && external;
      byName.set(m[1], cur);
    }
  });
  for (const [n, rec] of byName) {
    rec.inFolder = here.has(n);
    rec.anywhere = (index[n] || []).length > 0;
    // Родовое имя отчёта («иерархия из map.rpt») называется без префикса
    // проекта, а доставленный файл носит имя ram4.map.rpt. Такое имя
    // принимается ТОЛЬКО если в сдаче есть хотя бы один файл, чьё имя
    // кончается на точку+имя: правило остаётся строгим - если отчёта такого
    // рода не доставлено ни одного, совпадений ноль и обещание невыполненно.
    // Собственный вывод аудитора: этот скрипт пишет sdacha_selfcheck.json,
    // поэтому на ПЕРВОМ заходе обещанный файл физически не мог существовать.
    // Льгота закрыта, а не раскрыта: список имён только этот, и упаковщик
    // отдельной проверкой доказывает, что прирост сдачи после прогонов равен
    // ровно этому файлу (pack.json -> grownAfterAudit.expected).
    const SELF_OUTPUT = n === 'sdacha_selfcheck.json';
    rec.suffix = rec.inFolder || rec.anywhere ? false : tree.some((x) => x.basename.endsWith('.' + n));
    promised.push({ note: f.path, ...rec });
    if (!rec.inFolder && !rec.anywhere && !rec.suffix && !rec.external && !SELF_OUTPUT) {
      unmetPromises.push(f.path + ':' + rec.lines[0] + ' назван ' + n + ', которого нет в сдаче: ни точным именем, ни родовым суффиксом, ни квалификацией «чужое дерево»');
    }
  }
}
need(unmetPromises.length === 0, unmetPromises.slice(0, 12).join(' | '));
struct.push({ rule: 'C.1 каждый файл, названный в ZIPISKA, существует в сдаче (точное имя, родов суффикс или квалификация чужого дерева в окне 3 строк)',
  notes: tree.filter((x) => x.basename === 'ZIPISKA.txt').length,
  names: promised.length,
  promises: promised.filter((p) => !p.external).length,
  exact: promised.filter((p) => p.inFolder || p.anywhere).length,
  genericSuffix: promised.filter((p) => p.suffix).length,
  externalMentions: promised.filter((p) => p.external).length,
  unmet: unmetPromises.length });
for (const p of promised.filter((x) => x.suffix)) console.log('  родовое имя, принятое по суффиксу: ' + p.note + ':' + p.lines.join(',') + ' -> ' + p.name);
const externalList = promised.filter((p) => p.external && !p.inFolder && !p.anywhere)
  .map((p) => ({ note: p.note, name: p.name, lines: p.lines }));
console.log('  внешние упоминания в ZIPISKA (не обещания): ' + externalList.length);
for (const e of externalList) console.log('     ' + e.note + ':' + e.lines.join(',') + ' -> ' + e.name);

// C.2 - дубли библиотеки сверяются хешем с подлинником и между собой
const dupRows = [];
for (const nm of ['74155.bdf', '74244.bdf', '74374.bdf', 'enadff.bdf', '74155.bsf', '74244.bsf', '74374.bsf']) {
  const locs = index[nm] || [];
  const hashes = locs.map((rel) => {
    const abs = path.join(SD, rel);
    const h = crypto.createHash('sha256').update(fs.readFileSync(abs)).digest('hex').slice(0, 12);
    return { loc: rel, h };
  });
  const orig = path.join(MP2, nm);
  let origH = null;
  if (fs.existsSync(orig)) origH = crypto.createHash('sha256').update(fs.readFileSync(orig)).digest('hex').slice(0, 12);
  const allH = [...new Set(hashes.map((x) => x.h))];
  const equal = allH.length === 1 && (!origH || allH[0] === origH);
  dupRows.push({ name: nm, copies: hashes, original: origH, distinct: allH.length, matchesOriginal: allH.length === 1 && (!origH || allH[0] === origH) });
  need(equal, nm + ': дубли в сдаче не совпали хешем между собой или с подлинником (' + allH.join(', ') + ' vs ' + origH + ')');
}
struct.push({ rule: 'C.2 дублированные листы библиотеки курса идентичны по sha256 между собой и с подлинником в mp2',
  names: dupRows.length, divergent: dupRows.filter((r) => !r.matchesOriginal).length });

// C.5 - справочные корпуса сдачи сверяются с подлинниками установки.
// Это те же два дерева, что и константы VWFREF/REF_ALTERA: корпус формата .vwf
// (ref_vwf) и мегафункциональные ссылки (ref_altera, включая mega/). Правило
// строится по образцу C.2 и сознательно НЕ валитирует при недоступном хосте:
// если подлинника нет, копии сверяются МЕЖДУ собой и совпадение с подлинником
// честно НЕ заявляется. Пустое множество здесь не читается как успех - ровно
// та дисциплина, которую руководитель требовал для _audit_final.py.
// Относительный путь ВНУТРИ папки сдачи - и есть относительный путь внутри
// подлинника: корпуса вложенные (ref_vwf держит VHDLCMP_4BIT/VHDLCMP_4BIT.vwf
// и D/db/D.sim.vwf, ref_altera держит mega/altram.tdf). Поиск по basename
// смотрел бы на mega/altram.tdf в корне хоста, где его нет, и правило молча
// теряло 9 из 15 подлинников, выдавая это за недоступность источника.
const REF_PAIRS = [
  { folder: 'ref_vwf', host: VWFREF },
  { folder: 'ref_altera', host: REF_ALTERA },
];
const refRows = [];
for (const spec of REF_PAIRS) {
  for (const f of (byFolder[spec.folder] || [])) {
    if (f.basename === 'ZIPISKA.txt') continue;
    const rel = f.path.slice(spec.folder.length + 1);
    const orig = path.join(spec.host, rel);
    const origH = exists(orig) ? shaFile(orig) : null;
    const row = { file: f.path, rel, folder: spec.folder, hostOriginal: orig, originalAvailable: !!origH,
      deliverySha: shaFile(f.abs), originalSha: origH, matchesOriginal: !!origH && shaFile(f.abs) === origH };
    refRows.push(row);
    // валитируется ТОЛЬКО когда подлинник доступен: иначе это была бы проверка
    // «файл равен самому себе», выглядящая как успех
    if (row.originalAvailable) {
      need(row.matchesOriginal, 'справочный корпус изменён против подлинника установки: ' + f.path +
        ' (' + row.deliverySha + ' vs ' + row.originalSha + ')');
    }
  }
}
const refUnavailable = refRows.filter((r) => !r.originalAvailable).map((r) => r.file);
const avail = refRows.filter((r) => r.originalAvailable);
const byFolderCount = {};
for (const r of refRows) byFolderCount[r.folder] = (byFolderCount[r.folder] || 0) + 1;
struct.push({ rule: 'C.5 справочные корпуса ref_vwf и ref_altera (+mega, +db) сверены sha256 с подлинниками установки по относительному пути; при недоступном подлиннике совпадение НЕ заявляется',
  files: refRows.length, perFolder: byFolderCount,
  originalAvailable: avail.length, originalMissing: refRows.length - avail.length,
  unavailableList: refUnavailable,
  divergent: avail.filter((r) => !r.matchesOriginal).length });
// дисциплина обязательных находок: корпус сверки НЕ должен быть пустым, иначе
// «0 расхождений» стало бы следствием того, что подлинников вообще нет
need(refRows.length > 0, 'C.5: ни одного справочного файла не найдено в сдаче - правило мерит пустоту');
need(avail.length > 0, 'C.5: ни один подлинник недоступен (' + refRows.length + ' файлов) - сверка не меряет ничего');

// C.3 - разбор каждого исходника: .bdf/.bsf через sexpr, .vwf через simcheck,
// .tdf/.vhd/.qsf/.qpf - структурно
const parseRows = [];
const parseFail = [];
for (const f of tree) {
  const ext = f.ext;
  if (!['.bdf', '.bsf', '.vwf', '.tdf', '.vhd', '.qsf', '.qpf'].includes(ext)) continue;
  const txt = fs.readFileSync(f.abs, 'utf8');
  let row = { file: f.path, ext, how: '', ok: true, why: '' };
  try {
    if (ext === '.bdf' || ext === '.bsf') {
      const sexp = S.parse ? S.parse(txt) : (S.parseSexp ? S.parseSexp(txt) : null);
      row.how = 'sexpr.parse';
      if (sexp == null) { row.ok = false; row.why = 'парсер вернул null'; }
    } else if (ext === '.vwf') {
      const tl = SC.parseVwf(txt);
      const names = Object.keys(tl || {});
      row.how = 'simcheck.parseVwf';
      row.signals = names.length;
      if (!names.length) { row.ok = false; row.why = 'ни одного сигнала'; }
      // каждая волна обязана иметь интервалы и конечную точку
      for (const n of names) {
        const s = tl[n];
        if (!s || !Array.isArray(s.segs) || !s.segs.length) { row.ok = false; row.why = 'сигнал ' + n + ' без интервалов'; break; }
      }
    } else if (ext === '.tdf') {
      row.how = 'структурный';
      const sub = /SUBDESIGN\s+(\w+)/i.exec(txt);
      const bal = (txt.match(/\(/g) || []).length - (txt.match(/\)/g) || []).length;
      row.entity = sub ? sub[1] : null;
      if (!sub) { row.ok = false; row.why = 'нет SUBDESIGN'; }
      else if (bal !== 0) { row.ok = false; row.why = 'несбалансированные скобки (' + bal + ')'; }
      else if (!/END\s+\1;/i.test(txt) && !/\bEND\b/i.test(txt)) { row.ok = false; row.why = 'нет END'; }
    } else if (ext === '.vhd') {
      row.how = 'структурный';
      const arch = /ARCHITECTURE\s+(\w+)\s+OF\s+(\w+)/i.exec(txt);
      row.entity = arch ? arch[2] : null;
      row.architecture = arch ? arch[1] : null;
      const beg = (txt.match(/\bBEGIN\b/gi) || []).length;
      const end = (txt.match(/\bEND\b/gi) || []).length;
      if (!arch) { row.ok = false; row.why = 'нет ARCHITECTURE..OF'; }
      else if (!/ENTITY/i.test(txt)) { row.ok = false; row.why = 'нет ENTITY'; }
      else if (end < 1) { row.ok = false; row.why = 'нет END'; }
      else row.balanced = beg > 0 && end >= beg;
    } else if (ext === '.qsf') {
      row.how = 'структурный';
      const assigns = (txt.match(/set_global_assignment/g) || []).length;
      // метрика - число СИМВОЛОВ кавычки (не строк): парная кавычка в одной
      // строке даёт две, а оборванная запись даёт нечётный итог по файлу
      const quotes = (txt.match(/"/g) || []).length;
      row.assignments = assigns;
      row.quotes = quotes;
      if (!assigns) { row.ok = false; row.why = 'ни одной set_global_assignment'; }
      else if (quotes % 2 !== 0) { row.ok = false; row.why = 'нечётное число кавычек (оборванная запись)'; }
      else if (!/set_global_assignment\s+-name\s+(FILE_\w+|\w*_FILE)\s+\S/.test(txt) && !/TOP_LEVEL_ENTITY/.test(txt)) {
        row.ok = false; row.why = 'нет ни одной FILE_* ни TOP_LEVEL_ENTITY';
      }
    } else if (ext === '.qpf') {
      row.how = 'структурный';
      const QUARTUS = /QUARTUS_VERSION|\[QUARTUS\]/i.test(txt);
      if (!QUARTUS) { row.ok = false; row.why = 'нет квартусных ключей'; }
      row.QUARTUS = QUARTUS;
    }
  } catch (e) {
    row.ok = false; row.why = String(e.message || e).slice(0, 160);
  }
  parseRows.push(row);
  if (!row.ok) parseFail.push(f.path + ' (' + ext + '): ' + row.why);
}
need(parseFail.length === 0, parseFail.slice(0, 12).join(' | '));
struct.push({ rule: 'C.3 каждый .bdf/.bsf/.vwf/.tdf/.vhd/.qsf/.qpf разбирается',
  files: parseRows.length, failed: parseFail.length });

// C.4 - доказательство упаковки существует и зелёное
const packEv = path.join(EVDIR, 'pack.json');
let packRec = { present: fs.existsSync(packEv) };
if (packRec.present) {
  const pj = JSON.parse(fs.readFileSync(packEv, 'utf8'));
  packRec.verdict = pj.verdict;
  packRec.problems = (pj.problems || []).length;
  packRec.reportProof = pj.reportProof ? {
    toolchain: pj.reportProof.toolchain,
    // 514 сводило массив прогонов к ЧИСЛУ, а строка 568 позже вызывала на этом поле
    // .map, ожидая массив: доставленный самотест падал с TypeError на собственном
    // дереве сдачи. Число нужно для печати сводки (685), список - для проверки
    // покрытия слоёв (568), поэтому теперь хранятся оба поля раздельно.
    runs: Array.isArray(pj.reportProof.runs) ? pj.reportProof.runs.length : pj.reportProof.runs,
    run_what: (Array.isArray(pj.reportProof.runs) ? pj.reportProof.runs : []).map((r) => r.what),
    nonzero: pj.reportProof.runs.filter((r) => r.code !== 0).length,
    assertions: pj.reportProof.runs.reduce((a, r) => a + ((r.expect || []).length), 0),
    unheld: pj.reportProof.runs.flatMap((r) => (r.expect || []).filter((e) => !e.held).map((e) => r.what + ': ' + e.what)),
    restored: pj.reportProof.restored,
    refhash: pj.reportProof.refhash,
    zadanie: pj.reportProof.zadanie,
    // сверка содержимого отчёта с регенерацией по (имя, CRC, размер) участников:
    // хеш целого zip-архива для этого непригоден, так как python-docx пишет время
    // сборки в заголовок каждой записи и два сохранения одной логики всегда дают
    // разные sha256
    container: pj.reportProof.container || null,
  } : null;
  packRec.stackRuns = { total: (pj.stackRuns || []).length, nonzero: (pj.stackRuns || []).filter((r) => r.code !== 0).length };
  packRec.regen = (pj.regenProof || []).map((r) => ({ entity: r.entity, failed: !!r.failed, files: (r.files || []).length }));
  need(packRec.verdict === 'PACKED', 'pack.json вердикт ' + packRec.verdict);
  need(packRec.problems === 0, 'pack.json содержит ' + packRec.problems + ' проблем');
  need(!!packRec.reportProof, 'pack.json не содержит reportProof');
  if (packRec.reportProof) {
    need(packRec.reportProof.nonzero === 0, 'прегоны отчёта: ' + packRec.reportProof.nonzero + ' не нулевых');
    need(packRec.reportProof.unheld.length === 0, 'утверждения не держатся: ' + packRec.reportProof.unheld.slice(0, 6).join(' | '));
    need(packRec.reportProof.restored === true, 'авторский docx не восстановлен после пробной сборки');
    need(packRec.reportProof.refhash && packRec.reportProof.refhash.zadanieMatch === true, 'хеш задания не совпал с эталоном');
    need(packRec.reportProof.refhash && packRec.reportProof.refhash.docxMatch === true, 'хеш отчёта не совпал с эталоном');
    // Эталон задан ХЕШЕМ, а не длиной. Причина измерена, а не предполагана: за
    // сессию отдаваемый документ правился пять раз, и две пары редакций (v1/v2 на
    // 421182 байта) имели ОДИНАКОВУЮ длину при разном содержимом - правка двух
    // байтов в XML не меняет длину zip-архива. Сверка по размеру такую пару не
    // отличила бы, поэтому размер служит вторичным признаком, а различимость
    // эталонов требуется здесь по всему списку отозванных.
    const RH = packRec.reportProof.refhash;
    if (RH && RH.docxShaSuperseded) {
      need(RH.docxSha !== RH.docxShaSuperseded, 'эталоны новых и прежних байтов отчёта совпали: сверка теряет смысл');
    }
    if (RH && Array.isArray(RH.docxShaSupersededAll)) {
      need(RH.docxShaSupersededAll.length > 0, 'список отозванных эталонов пуст при ненулевой линии редакций');
      need(!RH.docxShaSupersededAll.includes(RH.docxSha),
        'текущий эталон входит в список отозванных: сверка хеша подтверждает сама себя');
      // отозванные должны быть ПОСЛЕДОВАТЕЛЬНЫ: каждый предыдущий отличается от
      // следующего, иначе в линии есть дубль и «смена эталона» не была сменой
      const chain = [RH.docxShaSupersededAll[RH.docxShaSupersededAll.length - 1], RH.docxSha];
      for (let k = 1; k < chain.length; k++) {
        need(chain[k] !== chain[k - 1], 'в линии редакций отчёта есть соседний дубль хеша: позиция ' + k);
      }
    }
    // Сверка ИСТОЧНИКА, а не только копии: доставленная копия совпадала со своим
    // устаревшим эталоном ровно на одну сборку, и проверка проходила молча, будучи
    // неверной. Источник - тот файл, который копируется, поэтому его сверка
    // исключает такое отставание.
    need(RH && RH.docxSourceMatch === true,
      'источник отчёта не сверен с эталоном или не совпал с ним (docxSourceMatch !== true): эталон в pack.json устарел');
    // Слои проверки отчёта обязаны БЫТЬ В ПРОГОНЕ, а не подразумеваться: слой,
    // который никто не вызвал, не даёт и ложного «чисто». Перечисляю те, без
    // которых сдача перестала бы доказывать то, что заявлено в записках.
    const RUNNED = packRec.reportProof.run_what || [];
    for (const req of ['_audit_final.py', '_homoglyph.py', '_homoglyph_all.py', '_homoglyph_docx.py',
      '_agree_system.py', '_agree_neg.py', '_agree_verify.py', '_unit_readback.py', 'make_report.py']) {
      need(RUNNED.some((w) => w.includes(req)), 'в прогоне отчёта нет слоя ' + req + ': заявленное в записках не меряется');
    }
    // Задание обязано быть заявленным как доставленное: поле present молчало
    // (undefined), и записка папки утверждала «текст задания отсутствует», хотя
    // файл ехал в сдаче, а его хеш сверялся. Пустое значение не равно false,
    // поэтому требуется именно true.
    need(packRec.reportProof.zadanie && packRec.reportProof.zadanie.present === true,
      'pack.json не утверждает, что zadanie_lab13.txt доставлен (present !== true)');
    // Содержимое отчёта подтверждено регенерацией внутри сдачи
    const CN = packRec.reportProof.container;
    if (CN) {
      need(CN.names_identical === true, 'набор участников docx разошёлся между снимком и регенерацией');
      need((CN.crc_divergent || []).length === 0, 'содержимое отчёта НЕ совпало с регенерацией: CRC-32 разошлись у ' + CN.crc_divergent.length + ' участников');
      need((CN.size_divergent || []).length === 0, 'размеры участников docx разошлись: ' + CN.size_divergent.join(', '));
      // обратное требование: отметки времени ОБЯЗАНЫ разойтись. Если они совпали,
      // make_report.py ничего не перезаписывал, и сравнение меряло файл самим
      // собой - ровно тот ложный успех, против которого этот слой и написан
      need(typeof CN.date_divergent === 'number' && CN.date_divergent > 0,
        'регенерация совпала со снимком даже по отметкам времени zip (' + JSON.stringify(CN) + '): подозрение, что файл не перезаписывался');
    } else {
      need(false, 'pack.json не содержит container - содержимое отчёта не подтверждено регенерацией');
    }
  }
  need(packRec.stackRuns.nonzero === 0, 'стек изнутри сдачи: ' + packRec.stackRuns.nonzero + ' не нулевых прогонов');
  need((packRec.regen || []).length > 0 && packRec.regen.every((r) => !r.failed), 'доказательство пересборки листа не зелёное');
  // Слои, добавленные после первой зелёной сборки: аудитор обязан требовать и их,
  // иначе сдача может проходить проверку по устаревшему набору правил
  const HG = pj.homoglyphGate;
  if (HG) {
    need(HG.code === 0, 'слой гомоглифов изнутри сдачи -> код ' + HG.code + (HG.why ? ' (' + HG.why + ')' : ''));
    need((HG.missed || []).length === 0, 'утверждения слоя гомоглифов не держатся: ' + HG.missed.join(' | '));
    need(String(HG.tokens) === '0', 'смешанных токенов в сдаче: ' + HG.tokens + ' (обязан быть 0)');
    need(Number(HG.swept) >= 200, 'слоем гомоглифов пройдено всего ' + HG.swept + ' текстовых файлов (ожидалось не меньше 200): обход неполон');
    packRec.homoglyphGate = { code: HG.code, swept: HG.swept, tokens: HG.tokens, missed: (HG.missed || []).length };
  } else {
    need(false, 'pack.json не содержит homoglyphGate - смешение кириллицы и латиницы в сдаче не мерялось');
  }
  const CP = pj.corpus;
  if (CP) {
    need(CP.divergent === 0, 'корпус Quartus-отчётов разошёлся с work: ' + CP.divergent + ' файл(ов)');
    need((CP.namesMissingInDelivery || []).length === 0, 'имена отчётов из work отсутствуют в сдаче: ' + CP.namesMissingInDelivery.slice(0, 6).join(', '));
    need(CP.pairs >= CP.deliveryFiles, 'сравнено ' + CP.pairs + ' пар при ' + CP.deliveryFiles + ' доставленных отчётах: сверены не все');
    packRec.corpus = { pairs: CP.pairs, deliveryFiles: CP.deliveryFiles, divergent: CP.divergent };
  }
  const DJ = pj.derivedJunkPurged;
  if (DJ) need((DJ.residue || []).length === 0, 'после вычистки в сдаче остался производный мусор: ' + DJ.residue.slice(0, 6).join(', '));
  const GA = pj.grownAfterAudit;
  if (GA) {
    need((GA.vanished || []).length === 0, 'аудитор убрал из сдачи файлы: ' + GA.vanished.slice(0, 6).join(', '));
    need((GA.added || []).join(',') === (GA.expected || []).join(','), 'после прогонов аудитора появилось не то, что ожидалось: ' + (GA.added || []).join(', ') + ' вместо ' + (GA.expected || []).join(', '));
  }
}
// C.6 - проза записки НЕ должна противоречить доставленному содержимому. Это
// отдельное правило, а не часть C.1: C.1 проверяет «названный файл существует»,
// а здесь требуется обратное - чтобы записка НЕ утверждала отсутствие того, что
// лежит в папке. Именно этот разрыв молча проехал бы двумя прочими проверками:
// хеш-сверка задания зелёная, а в тексте стоит «отсутствует».
{
  const zp = path.join(SD, '0_zadanie_i_otchet', 'ZIPISKA.txt');
  if (fs.existsSync(zp)) {
    const txt = fs.readFileSync(zp, 'utf8').replace(/^\uFEFF/, '');
    const fileLezhit = fs.existsSync(path.join(SD, '0_zadanie_i_otchet', 'zadanie_lab13.txt'));
    const otrechenie = /ТЕКСТ ЗАДАНИЯ отдельным файлом в сдаче отсутствует/.test(txt);
    need(!(fileLezhit && otrechenie),
      '0_zadanie_i_otchet/ZIPISKA.txt отрицает наличие zadanie_lab13.txt, хотя файл лежит в папке');
    if (fileLezhit) need(/zadanie_lab13.txt/.test(txt),
      'записка папки не перечисляет zadanie_lab13.txt среди её содержимого');
    struct.push({ rule: 'C.6 проза записки отчёта не противоречит доставленному: отрицание отсутствующего файла валитирует сборку',
      zadanieLezhit: fileLezhit, otrechenieVTEkste: otrechenie });
  }
}
struct.push({ rule: 'C.4 доказательство упаковки (pack.json) зелёное: пересборка листа, стек изнутри сдачи, прогоны отчёта с утверждениями, эталонные хеши',
  present: packRec.present, verdict: packRec.verdict });

// ===========================================================================
// Вердикт и запись доказательства
// ===========================================================================
const allProblems = [].concat(absProblems, structProblems, parseFail, unmetPromises);
const verdict = allProblems.length === 0 ? 'SELF-CONTAINED' : 'PROBLEMS';
const byFolderReport = {};
for (const [k, v] of Object.entries(byFolder)) {
  byFolderReport[k] = { files: v.length, bytes: v.reduce((a, f) => a + f.bytes, 0) };
}
const out = {
  generated: new Date().toISOString(),
  sdacha: SD,
  verdict,
  totals: { files: tree.length, bytes: tree.reduce((a, f) => a + f.bytes, 0),
    kb: Math.round(tree.reduce((a, f) => a + f.bytes, 0) / 1024) },
  byFolder: byFolderReport,
  scan: { textFiles: scanned, skippedBinary: skippedBinary, exts: TEXT_EXT },
  absoluteReferences: { counts: absCounts, rows: absRows.length, unjustified: absProblems.length,
    sample: absRows.slice(0, 40) },
  docxContainer: docxRows,
  structure: struct,
  qsf: qsfRows, instances: instRows, projects: projRows, duplicates: dupRows,
  promises: { total: promised.length, unmet: unmetPromises.length, sample: promised.slice(0, 20) },
  parses: parseRows,
  packEvidence: packRec,
  problems: allProblems,
};
mkdir(EVDIR);
out.runFrom = { here: HERE, sdacha: SD, inDelivery: IN_DELIVERY, evidenceDir: EVDIR };
fs.writeFileSync(path.join(EVDIR, 'sdacha_selfcheck.json'), JSON.stringify(out, null, 1), 'utf8');

console.log('sdacha: ' + SD + '  (запуск ' + (IN_DELIVERY ? 'ИЗ СДАЧИ' : 'из рабочего дерева') + ', доказательства -> ' + EVDIR + ')');
console.log('  файлов ' + out.totals.files + ', килобайт ' + out.totals.kb);
console.log('  текстовых просканировано ' + scanned + ', бинарных пропущено ' + skippedBinary);
console.log('  абсолютных ссылок: ' + absRows.length + ' (необоснованных ' + absProblems.length + ')');
for (const [k, v] of Object.entries(absCounts)) console.log('     ' + k.padEnd(12) + v);
console.log('  структура:');
for (const s of struct) console.log('     ' + JSON.stringify(s));
console.log('  доказательство упаковки: ' + packRec.verdict + ', проблем ' + packRec.problems);
if (packRec.reportProof) {
  console.log('  прогоны отчёта: ' + packRec.reportProof.runs + ' (не нулевых ' + packRec.reportProof.nonzero +
    '), утверждений ' + packRec.reportProof.assertions + ' (не держатся ' + packRec.reportProof.unheld.length + ')');
}
console.log('  проблем всего: ' + allProblems.length);
for (const p of allProblems.slice(0, 30)) console.log('     - ' + p);
console.log('VERDICT: ' + verdict);
process.exit(allProblems.length ? 2 : 0);
