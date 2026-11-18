#==============================================================================
#  autotest.ps1 - автопрогон лабораторной работы 6 в MS-DOS эмуляторе
#  с ПЕРЕХВАТОМ вывода программы в файл.
#
#  Использование:
#     powershell -NoProfile -ExecutionPolicy Bypass -File autotest.ps1
#     powershell ... -File autotest.ps1 -Only Lab6_3      (одна папка)
#     из VS Code: открыть папку задачи -> Ctrl+Shift+B -> задача "Selftest ..."
#
#  КАК ЭТО РАБОТАЕТ (три обязательных условия, найтые опытным путём):
#
#  1) DOSBox - GUI-процесс. Обычный запуск из PowerShell ("& dosbox.exe ..."
#     или Start-Process без ожидания) НЕ СИНХРОНИЗИРУЕТСЯ: PowerShell
#     возвращается мгновенно, а файлы вывода ещё не созданы. Поэтому здесь
#     Start-Process -PassThru и явный $p.WaitForExit().
#
#  2) DOSBox закрывается сам только по ВНУТРЕННЕЙ команде "exit", переданной
#     через -c. Ключ -exit сам по себе привязан к позиционному аргументу
#     (запуск программы-имени) и в цепочке "-c ..." не срабатывает - эмулятор
#     висит с открытым окном. Ключи -log/-nogui вывод DOS-программы не дают:
#     -log пишет только журнал эмулятора, которого здесь нет.
#
#  3) Вывод программы берётся НЕ из консоли Windows (его перехватить нельзя),
#     а из редиректа ВНУТРИ DOS:  prog > d:\build\run.txt
#     Двоичный вывод TCC/TASM-диагностики - в d:\build\cc.txt.
#
#  Дополнительно: программы содержат ожидание клавиши (getch / int 16h),
#     которое для автотеста выключено символом NOWAIT:
#        TCC  -> -DNOWAIT          TASM -> /dNOWAIT
#     Интерактивный запуск через Ctrl+Shift+B ("Compile and Run") NOWAIT не
#     использует, поэтому ожидание клавиши там работает как раньше.
#==============================================================================
param(
  [string]$Only = "",
  [int]$TimeoutSec = 90
)
$ErrorActionPreference = "Stop"

# --- пути инструментария (см. Plan_Lab6.md) ---
$Arch  = "D:" + [char]92 + "Desktop" + [char]92 + "NF" + [char]92 + "GitNout" + [char]92 + "Architecture"
$Box   = Join-Path $Arch ("DOSBox" + [char]92 + "DOSBox.exe")
$CRoot  = Join-Path $Arch "C"
$Tcc   = "c:" + [char]92 + "TCC" + [char]92 + "TC" + [char]92 + "tcc"   # DOS-путь: C: внутри DOSBox = Architecture\C
if (-not (Test-Path -LiteralPath $Box)) { throw "DOSBox не найден: $Box" }

$Labs = @(
  @{ Dir="Lab6_1"; Kind="C";   Src="Lab6.c";     Exe="lab6"   },
  @{ Dir="Lab6_2"; Kind="ASM"; Src="lab6_2.asm"; Exe="lab6_2" },
  @{ Dir="Lab6_3"; Kind="C";   Src="Lab6.c";     Exe="lab6"   },
  @{ Dir="Lab6_4"; Kind="C";   Src="Lab6.c";     Exe="lab6"   },
  @{ Dir="Lab6_5"; Kind="ASM"; Src="lab6_5.asm"; Exe="lab6_5" }
)
if ($Only) {
  $leaf = Split-Path -Leaf ($Only.Trim([char]34))
  $Labs = @($Labs | Where-Object { $_.Dir -eq $leaf })
  if (-not $Labs) { throw "Неизвестная папка задачи: $Only" }
}

$BS = [char]92
foreach ($L in $Labs) {
  $lab   = Join-Path $PSScriptRoot $L.Dir
  $build = Join-Path $lab ("build")
  New-Item -ItemType Directory -Force -Path $build | Out-Null
  foreach ($f in @("cc.txt","run.txt","lab6.exe","lab6.obj","lab6_2.obj","lab6_2.com","lab6_5.obj","lab6_5.com","lab6.map","lab6_2.map","lab6_5.map")) {
    $dead = Join-Path $build $f
    if (Test-Path -LiteralPath $dead) { Remove-Item -LiteralPath $dead -Force }
  }

  $cmds = New-Object System.Collections.ArrayList
  [void]$cmds.Add("mount c " + [char]39 + $CRoot + [char]39)
  [void]$cmds.Add("mount d " + [char]39 + $lab + [char]39)
  [void]$cmds.Add("d:")
  if ($L.Kind -eq "C") {
    [void]$cmds.Add("set PATH=%PATH%;c:" + $BS + "TCC" + $BS + "TC")
    [void]$cmds.Add($Tcc + " -B -ms -DNOWAIT -nd:" + $BS + "build d:" + $BS + $L.Src + " > d:" + $BS + "build" + $BS + "cc.txt")
    [void]$cmds.Add("cd build")
  } else {
    [void]$cmds.Add("set PATH=%PATH%;c:" + $BS + "NTA")
    [void]$cmds.Add("cd build")
    [void]$cmds.Add("tasm /zi /dNOWAIT .." + $BS + $L.Src + " > d:" + $BS + "build" + $BS + "cc.txt")
    [void]$cmds.Add("tlink /v /t " + $L.Exe + " >> d:" + $BS + "build" + $BS + "cc.txt")
  }
  [void]$cmds.Add($L.Exe + " > d:" + $BS + "build" + $BS + "run.txt")
  [void]$cmds.Add("exit")            # - закрывает DOSBox

  $q = [char]34
  $argline = "-exit " + (($cmds | ForEach-Object { "-c " + $q + $_ + $q }) -join " ")

  Write-Output ""
  Write-Output ("=" * 78)
  Write-Output ("АВТОПРОГОН: " + $L.Dir + "   (" + $L.Kind + ", " + $L.Src + ")")
  Write-Output ("=" * 78)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $Box -ArgumentList $argline -PassThru -WindowStyle Minimized
  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill() } catch {}
    throw "DOSBox не завершился за $TimeoutSec с: " + $L.Dir
  }
  $sw.Stop()
  Write-Output ("DOSBox завершился: код=" + $p.ExitCode + "  время=" + $sw.ElapsedMilliseconds + " мс")

  $ccFile  = Join-Path $build "cc.txt"
  $runFile = Join-Path $build "run.txt"
  Write-Output ("--- диагностика компилятора (build" + [char]92 + "cc.txt) ---")
  if (Test-Path -LiteralPath $ccFile) { Get-Content -LiteralPath $ccFile } else { Write-Output "(файл не создан)" }
  Write-Output ""
  Write-Output ("--- вывод программы (build" + [char]92 + "run.txt) ---")
  if (Test-Path -LiteralPath $runFile) {
    $txt = Get-Content -LiteralPath $runFile -Raw
    Write-Output ($txt.TrimEnd())
    # CP866 -> читаемый вид в консоли Windows не требуется: файл остаётся
    # в кодировке DOS, для отчёта используется как есть.
  } else { Write-Output "(файл не создан - программа не запустилась)" }
}
Write-Output ""
Write-Output "Автопрогон завершён."
