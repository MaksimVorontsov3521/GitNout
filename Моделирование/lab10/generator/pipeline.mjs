#!/usr/bin/env node
// One-shot pipeline: JSON spec -> BDF/QSF/QPF in share -> Quartus compile inside the guest
// -> reports pulled back. No user interaction at any step.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const HOME = 'C:/Users/User/VirtualBox VMs/Microelectronics';
const SHARE = 'D:/Desktop/NF';
const AGENT = SHARE + '/dshagent';
const JOBS = AGENT + '/jobs';
const QWORK = SHARE + '/qwork';
const NODE = process.execPath;

const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf('--' + k); return i >= 0 ? argv[i + 1] : d; };
const flag = (k) => argv.indexOf('--' + k) >= 0;
const specPath = argv.find((a) => !a.startsWith('--'));
if (!specPath) { console.error('usage: pipeline.mjs <spec.json> [--skip-compile] [--timeout SEC]'); process.exit(2); }

const spec0 = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const entity = spec0.entity;
const SAMPLE_AT = Number(opt('sample-at', '0.75'));
const MAX_TIMING_TRIES = Number(opt('timing-tries', '3'));
const outDir = path.join(QWORK, entity);

async function once(spec) {
console.log('[1/4] generating BDF for ' + entity + ' (period=' + (spec.period || 40) + 'ns)');
const effPath = path.join(HOME, 'tools/out/' + entity + '.effective.json');
fs.mkdirSync(path.dirname(effPath), { recursive: true });
fs.writeFileSync(effPath, JSON.stringify(spec, null, 1));
const buildOut = execFileSync(NODE, [path.join(HOME, 'tools/bdf/build.mjs'), effPath, '--out', outDir, '--dry', path.join(HOME, 'tools/out/' + entity + '.bdf')], { encoding: 'utf8', shell: false });
console.log(buildOut.trim());

if (flag('skip-compile')) { console.log('[skip-compile] project at ' + outDir); process.exit(0); }

const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 12);
const jobName = 'q' + entity.replace(/[^A-Za-z0-9_]/g, '_') + '_' + stamp;
const local = 'C:\\dsh\\' + entity;
const qb = 'C:\\altera\\quartus50\\bin';
const lines = [
  '@echo off',
  'set QB=' + qb,
  'set W=' + local,
  'rmdir /s /q "%W%" 2>nul',
  'mkdir "%W%"',
  'copy /y "Z:\\qwork\\' + entity + '\\*.bdf" "%W%\" >nul',
  'copy /y "Z:\\qwork\\' + entity + '\\*.qsf" "%W%\" >nul',
  'copy /y "Z:\\qwork\\' + entity + '\\*.qpf" "%W%\" >nul',
  'copy /y "Z:\\qwork\\' + entity + '\\*.vwf" "%W%\" >nul 2>&1',
  'copy /y "Z:\\qwork\\' + entity + '\\*.bsf" "%W%\" >nul 2>&1',
  'copy /y "Z:\\qwork\\' + entity + '\\*.vhd" "%W%\" >nul 2>&1',
  'dir /b "%W%"',
  'cd /d "%W%"',
  'echo === MAP ===',
  '"%QB%\\quartus_map.exe" ' + entity + ' 2>&1',
  'echo MAP_EXIT=%ERRORLEVEL%',
  'echo === FIT ===',
  '"%QB%\\quartus_fit.exe" ' + entity + ' 2>&1',
  'echo FIT_EXIT=%ERRORLEVEL%',
  'echo === ASM ===',
  '"%QB%\\quartus_asm.exe" ' + entity + ' 2>&1',
  'echo ASM_EXIT=%ERRORLEVEL%',
  ...(spec.simulationMode === 'FUNCTIONAL' ? [
    'echo === FUNCTIONAL NETLIST ===',
    '"%QB%\quartus_map.exe" ' + entity + ' --generate_functional_sim_netlist 2>&1',
    'echo FNET_EXIT=%ERRORLEVEL%',
  ] : []),
  'echo === SIM ===',
  '"%QB%\\quartus_sim.exe" ' + entity + ' 2>&1',
  'echo SIM_EXIT=%ERRORLEVEL%',
  'echo === TAN ===',
  '"%QB%\\quartus_tan.exe" ' + entity + ' 2>&1',
  'echo TAN_EXIT=%ERRORLEVEL%',
  'echo === EXPORT ===',
  'set O=Z:\\qwork\\' + entity + '_out',
  'rmdir /s /q "%O%" 2>nul',
  'mkdir "%O%"',
  'copy /y "%W%\\*.rpt" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.summary" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.sof" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.vwf" "%O%\" >nul 2>&1',
  'copy /y "%W%\\db\\*.sim.vwf" "%O%\\' + entity + '.sim.vwf" >nul 2>&1',
  'copy /y "%W%\\*.eqn" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.bsf" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.vhd" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.vo" "%O%\" >nul 2>&1',
  'copy /y "%W%\\*.pin" "%O%\" >nul 2>&1',
  'dir /b "%O%"',
  'echo === DONE ===',
];
fs.writeFileSync(path.join(JOBS, jobName + '.bat'), lines.join('\r\n'), 'latin1');
console.log('[2/4] job submitted: ' + jobName);

const timeoutSec = Number(opt('timeout', '240'));
const t0 = Date.now();
const doneF = path.join(JOBS, jobName + '.done');
const outF = path.join(JOBS, jobName + '.out');
while (!fs.existsSync(doneF)) {
  if ((Date.now() - t0) / 1000 > timeoutSec) { console.error('[timeout] after ' + timeoutSec + 's'); process.exit(124); }
  await new Promise((r) => setTimeout(r, 2000));
}
const log = fs.existsSync(outF) ? fs.readFileSync(outF, 'latin1') : '';
console.log('[3/4] guest compile log:');
console.log(log.replace(/\r/g, '').split('\n').filter((l) => /^(===|MAP_EXIT|FIT_EXIT|ASM_EXIT|SIM_EXIT|TAN_EXIT|FNET_EXIT|Error|Warning|Critical|\s+Error|\s+Warning|Info: (Found|Elaborating|Quartus|Starting|Total|Processing ended|Elapsed)|[A-Za-z].*was (successful|unsuccessful))/.test(l.trim()) || /^[A-Za-z0-9_.\-]+\.(rpt|summary|sof|vwf|bdf|qsf|qpf)$/.test(l.trim())).join('\n'));

const repDir = path.join(QWORK, entity + '_out');
const simVwf = path.join(repDir, entity + '.sim.vwf');
console.log('[4/4] exported artefacts in ' + repDir + ': ' + (fs.existsSync(repDir) ? fs.readdirSync(repDir).join(', ') : 'none'));
const flow = path.join(repDir, entity + '.flow.rpt');
if (fs.existsSync(flow)) {
  const t = fs.readFileSync(flow, 'latin1');
  console.log('\n--- flow.rpt excerpt ---\n' + t.split('\r\n').filter((l) => /Quartus II Version|Revision name|Fitter|Assembler|Time|Logic elements|Total|Status/i.test(l)).slice(0, 24).join('\n'));
}
  return { log, repDir, simVwf, spec };
}

let verdict = null;
for (let tryNo = 0; tryNo < MAX_TIMING_TRIES; tryNo++) {
  const spec = { ...spec0, period: Number(spec0.period || 40) * (1 << tryNo) };
  verdict = await once(spec);
  const C = await import(pathToFileURL(HOME + '/tools/bdf/simcheck.mjs').href);
  if (!fs.existsSync(verdict.simVwf)) { console.error('no simulation output produced'); process.exit(5); }
  const r = C.checkSim(fs.readFileSync(verdict.simVwf, 'latin1'), verdict.spec, SAMPLE_AT);
  console.log('\n[functional check] rows=' + r.rows + ' mismatches=' + r.errs.length + ' (sample at ' + SAMPLE_AT + ' of each window)');
  if (!r.errs.length) {
    console.log('[functional check] PASS: simulated outputs match the expected table for ' + entity);
    if (tryNo) console.log('[functional check] note: needed ' + verdict.spec.period + 'ns window (propagation settling)');
    process.exit(0);
  }
  const tl = C.parseVwf(fs.readFileSync(verdict.simVwf, 'latin1'));
  let maxDelay = 0;
  for (const sig of Object.keys(tl)) {
    const e2 = tl[sig].segs;
    if (e2.length) maxDelay = Math.max(maxDelay, e2[0].t1);
  }
  console.log('[functional check] ' + r.errs.length + ' mismatch(es), first few:');
  console.log(r.errs.slice(0, 6).join('\n'));
  console.log('[diagnosis] earliest output transition at ' + maxDelay.toFixed(2) + 'ns vs window ' + verdict.spec.period + 'ns');
  if (/Error:/.test(verdict.log)) { console.error('compile error present; not a timing issue'); process.exit(1); }
  console.log('[retry] widening the stimulus window');
}
console.error('VERIFICATION FAILED for ' + entity + ' after ' + MAX_TIMING_TRIES + ' timing windows');
process.exit(1);