#!/usr/bin/env node
// Batched lab runner: N JSON specs -> projects in the share -> ONE guest job that
// compiles and functionally simulates each design -> reports pulled back -> per-design check.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const HOME = 'C:/Users/User/VirtualBox VMs/Microelectronics';
const SHARE = 'D:/Desktop/NF';
const JOBS = SHARE + '/dshagent/jobs';
const NODE = process.execPath;

const argv = process.argv.slice(2);
const VALUE_OPTS = ['folder', 'timeout', 'sample-at', 'tries'];
const opt = (k, d) => { const i = argv.indexOf('--' + k); return i >= 0 ? argv[i + 1] : d; };
const flag = (k) => argv.indexOf('--' + k) >= 0;
// Positional spec files: skip every --flag and, for value options, its operand too.
const specs = [];
for (let i = 0; i < argv.length; i++) {
  const t = argv[i];
  if (!t.startsWith('--')) { specs.push(t); continue; }
  if (VALUE_OPTS.includes(t.slice(2))) i++;
}
if (!specs.length) { console.error('usage: run.mjs <spec.json>... [--folder lab10] [--timeout 300] [--sample-at 0.75] [--asm] [--tan]'); process.exit(2); }
const folder = opt('folder', 'qwork');
const SAMPLE_AT = Number(opt('sample-at', '0.75'));
const TIMEOUT = Number(opt('timeout', '300'));
const C = await import(pathToFileURL(HOME + '/tools/bdf/simcheck.mjs').href);

const built = [];
for (const sp of specs) {
  const spec = JSON.parse(fs.readFileSync(sp, 'utf8'));
  const proj = spec.project || spec.entity;
  const outDir = path.join(SHARE, folder, proj);
  const effPath = path.join(HOME, 'tools/out/' + proj + '.effective.json');
  fs.mkdirSync(path.dirname(effPath), { recursive: true });
  fs.writeFileSync(effPath, JSON.stringify({ ...spec, specDir: path.resolve(path.dirname(sp)) }, null, 1));
  const bo = execFileSync(NODE, [path.join(HOME, 'tools/bdf/build.mjs'), effPath, '--out', outDir], { encoding: 'utf8' });
  console.log(bo.trim());
  built.push({ spec, outDir, entity: spec.entity, proj });
}

const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 12);
const jobName = 'r' + stamp + '_' + built.map((b) => b.entity).join('-').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 60);
const L = ['@echo off', 'set QB=C:\\altera\\quartus50\\bin'];
for (const { spec, entity, proj } of built) {
  const W = 'C:\\dsh\\' + proj;
  const S = 'Z:\\' + folder + '\\' + proj;
  const O = 'Z:\\' + folder + '\\' + proj + '_out';
  L.push('echo ########## ' + entity + ' ##########');
  L.push('rmdir /s /q "' + W + '" 2>nul');
  L.push('mkdir "' + W + '"');
  for (const ext of ['bdf', 'qsf', 'qpf', 'vwf', 'bsf', 'vhd']) L.push('copy /y "' + S + '\\*.' + ext + '" "' + W + '\\" >nul 2>&1');
  L.push('dir /b "' + W + '"');
  L.push('cd /d "' + W + '"');
  L.push('echo --- MAP');
  L.push('"%QB%\\quartus_map.exe" ' + entity + ' 2>&1');
  L.push('echo MAP_EXIT=%ERRORLEVEL%');
  if (spec.simulationMode === 'FUNCTIONAL') {
    L.push('echo --- FNET');
    L.push('"%QB%\\quartus_map.exe" ' + entity + ' --generate_functional_sim_netlist 2>&1');
    L.push('echo FNET_EXIT=%ERRORLEVEL%');
  }
  L.push('echo --- SIM');
  L.push('"%QB%\\quartus_sim.exe" ' + entity + ' 2>&1');
  L.push('echo SIM_EXIT=%ERRORLEVEL%');
  L.push('echo --- FIT');
  L.push('"%QB%\\quartus_fit.exe" ' + entity + ' 2>&1');
  L.push('echo FIT_EXIT=%ERRORLEVEL%');
  if (flag('asm')) {
    L.push('echo --- ASM');
    L.push('"%QB%\\quartus_asm.exe" ' + entity + ' 2>&1');
    L.push('echo ASM_EXIT=%ERRORLEVEL%');
  }
  if (flag('tan')) {
    L.push('echo --- TAN');
    L.push('"%QB%\\quartus_tan.exe" ' + entity + ' 2>&1');
    L.push('echo TAN_EXIT=%ERRORLEVEL%');
  }
  L.push('rmdir /s /q "' + O + '" 2>nul');
  L.push('mkdir "' + O + '"');
  L.push('copy /y "' + W + '\\*.rpt" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\*.sof" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\*.bsf" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\*.vhd" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\*.eqn" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\*.pin" "' + O + '\\" >nul 2>&1');
  L.push('copy /y "' + W + '\\db\\*.sim.vwf" "' + O + '\\' + entity + '.sim.vwf" >nul 2>&1');
  L.push('copy /y "' + W + '\\db\\*.vo" "' + O + '\\' + entity + '.vo" >nul 2>&1');
  L.push('copy /y "' + W + '\\db\\*.vm" "' + O + '\\' + entity + '.vm" >nul 2>&1');
  L.push('dir /b "' + O + '"');
}
L.push('echo ########## ALL DONE ##########');
const jobText = L.join('\r\n');
if (flag('dryjob')) { fs.writeFileSync(path.join(HOME, 'lab10/evidence/' + jobName + '.preview.bat'), jobText, 'latin1'); console.log('[dryjob] ' + path.join(HOME, 'lab10/evidence/' + jobName + '.preview.bat')); console.log(jobText.replace(/\r/g, '')); process.exit(0); }
fs.writeFileSync(path.join(JOBS, jobName + '.bat'), jobText, 'latin1');
console.log('\n[job] submitted: ' + jobName);

const t0 = Date.now();
const doneF = path.join(JOBS, jobName + '.done');
while (!fs.existsSync(doneF)) {
  if ((Date.now() - t0) / 1000 > TIMEOUT) { console.error('[timeout] after ' + TIMEOUT + 's; job ' + jobName + ' still queued/running'); process.exit(124); }
  await new Promise((r) => setTimeout(r, 2000));
}
const log = fs.readFileSync(path.join(JOBS, jobName + '.out'), 'latin1').replace(/\r/g, '');
fs.writeFileSync(path.join(HOME, 'lab10/evidence/' + jobName + '.log'), log, 'latin1');
const KEEP = /^(#|---|MAP_EXIT|FIT_EXIT|ASM_EXIT|SIM_EXIT|TAN_EXIT|FNET_EXIT|Error|Warning|Critical|Info: (Quartus|Analysis|Elaborating|Found|Total|Device|Processing ended|Elapsed)|.*was (successful|unsuccessful)|[A-Za-z0-9_.\-]+\.(rpt|sof|vwf|vo|vm|bsf|vhd|eqn|pin)$)/;
console.log('\n[guest log]');
console.log(log.split('\n').filter((x) => KEEP.test(x.trim())).join('\n'));

console.log('\n================ VERDICTS ================');
let fail = 0;
for (const { spec, entity, proj } of built) {
  const simVwf = path.join(SHARE, folder, proj + '_out', entity + '.sim.vwf');
  if (!fs.existsSync(simVwf)) { console.log(entity + ': NO SIMULATION OUTPUT'); fail++; continue; }
  const r = C.checkSim(fs.readFileSync(simVwf, 'latin1'), spec, SAMPLE_AT);
  const status = r.errs.length ? 'FAIL' : 'PASS';
  console.log(entity + ': ' + status + ' rows=' + r.rows + ' mismatches=' + r.errs.length + ' (sample at ' + SAMPLE_AT + ')');
  if (r.errs.length) { fail++; console.log(r.errs.slice(0, 8).join('\n')); }
}
process.exit(fail ? 1 : 0);