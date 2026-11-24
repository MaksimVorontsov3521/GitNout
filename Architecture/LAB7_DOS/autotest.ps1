#============================================================================
#  dosbox_autotest.ps1 - UNIVERSALNYJ sborka+zapusk DOS-programmy v DOSBox
#                     s PEREHVATOM ee vyvoda v tekstovyj fail.
#  Prednaznachen IИ-agentu i cheloveku: odin i tot ze sposob daet chytaemyj
#  rezultat bez okna, v kotoroe nuzhno chto-to nazhimat.
#
#  POLNAYA INSTRUKCIYA: Architecture\HOWTO_for_AI.md
#
#  PRIMERY
#    powershell -NoProfile -ExecutionPolicy Bypass -File dosbox_autotest.ps1 -Scan
#       -> prognat vse podpapki tekushhego kornya, gde rovno odin .c ili .asm
#    ... -File dosbox_autotest.ps1 -Root D:\x\Lab6_DOS -Dir Lab6_3
#       -> odna papka: yazyk i ishhodnik opredelyayutsya avtomaticheski
#    ... -File dosbox_autotest.ps1 -Dir Lab6_2 -Kind ASM -Src lab6_2.asm -Exe lab6_2
#       -> to zhe s yvnymi parametrami
#    ... -File dosbox_autotest.ps1 -Dir Lab5_1 -Compile "tcc -B -mt -nd:\build d:\Lab5.c"
#       -> svoya komanda sborki (perekryvaet -Kind)
#    ... -File dosbox_autotest.ps1 -Dir Lab6_1 -Only Lab6_1 -TimeoutSec 30
#       -> sokrat tajmaut
#
#  REZULTAT RABOTY
#    <papka>\build\cc.txt  - diagnostika translatora (TCC/TASM/TLINK)
#    <papka>\build\run.txt  - vyvod samoj programmy
#  V konsoli pechataetsya i to i drugoe, plus stroka itoga:
#    RESULT: <papka>  STATUS=OK|FAIL|TIMEOUT  BUILD_ERRORS=<n>  RUN_BYTES=<n>
#  Kod vozvrata skripta: 0 - vse progony uspešny, 1 - est provally.
#
#  TRI USLOVIYA, BEZ KOTORYH PEREHVAT NE RABOTAET (proveryeno opytnym putyom)
#
#  1) DOSBox - GUI-process. "& dosbox.exe ..." i Start-Process bez ozhidaniya
#     vozvrayayut upravlenie MGNOVENNO, chytenie faila vyvoda daet "net takogo
#     faila": emulyator eschyo rabotaet. Nuzhno -PassThru i yvnyj WaitForExit().
#     Imenno eta prichina vyglyadit kak "log ne sozdaetsya".
#  2) Emulyator zakryivaetsya sam TOKO vnutrennej komandoj "exit", peredannoj
#     cherez -c. Klyuch -exit privyazan k pozicionnomu argumentu (imya programmy)
#     i v tsepochke "-c ..." ne dejstvuet: okno ostayotsya otkrytym.
#  3) Vyvod beretsya iz redirecta VNUTRI DOS:  prog > d:\build\run.txt
#     Perekhvatyt stdio GUI-protsessa iz Windows nelzya; klyuch -log pishet
#     zhurnal emulyatora, a ne vyvod programmy.
#
#  CHETVYORTOE USLOVIE: programma ne dolzhna zdat nazhaniya klavishi. Ozhidanie
#  v ishhodnikakh pryachetsya pod simvol NOWAIT:
#     C:   #ifndef NOWAIT  ...  getch();  ...  #endif
#     ASM: IFNDEF NOWAIT  ...  mov ah,00h / int 16h  ...  ENDIF
#  Skript peredayot -DNOWAIT (TCC) i /dNOWAIT (TASM). Interaktivnaya zadacha
#  VS Code "Compile and Run" simvol NOWAIT NE peredayot, tam ozhidanie rabotaet.
#  YESLI guard net - progon ukhodit v TIMEOUT (etot simptom sm. v HOWTO).
#============================================================================
param(
  [string]$Root    = "",
  [string]$Dir     = "",
  [string]$Only    = "",
  [string]$Kind    = "",
  [string]$Src     = "",
  [string]$Exe     = "",
  [string]$Compile = "",
  [switch]$Scan,
  [switch]$Cp866,
  [int]$TimeoutSec = 90
)
$ErrorActionPreference = "Stop"
$BS = [char]92
$Q  = [char]34
$SQ = [char]39

# --- puti instrumentariya ---
if (-not $Root) { $Root = $PSScriptRoot }
$Arch  = $Root
while ($Arch -and -not (Test-Path -LiteralPath (Join-Path $Arch ("DOSBox" + $BS + "DOSBox.exe")))) {
  $parent = Split-Path -Parent $Arch
  if (-not $parent -or $parent -eq $Arch) { break }
  $Arch = $parent
}
$Box   = Join-Path $Arch ("DOSBox" + $BS + "DOSBox.exe")
$CRoot = Join-Path $Arch "C"
$Tcc   = "c:" + $BS + "TCC" + $BS + "TC" + $BS + "tcc"
if (-not (Test-Path -LiteralPath $Box))   { throw ("DOSBox ne najden: "    + $Box) }
if (-not (Test-Path -LiteralPath $CRoot)) { throw ("Komplekt C ne najden: " + $CRoot) }

function Get-DosTask {
  param([string]$Folder, [string]$Kind, [string]$Src, [string]$Exe)
  $leaf = Split-Path -Leaf ($Folder.Trim($Q, $SQ, $BS))
  if (-not (Test-Path -LiteralPath $Folder)) { throw ("Papka zadachi ne najdena: " + $Folder) }
  $cFiles = @(Get-ChildItem -LiteralPath $Folder -File -Filter *.c   -ErrorAction SilentlyContinue)
  $aFiles = @(Get-ChildItem -LiteralPath $Folder -File -Filter *.asm -ErrorAction SilentlyContinue)
  if (-not $Src) {
    $all = @($cFiles) + @($aFiles)
    if ($all.Count -eq 0) { throw ("V papke " + $leaf + " net ni .c, ni .asm") }
    if ($all.Count -gt 1) { throw ("V papke " + $leaf + " neskolko ishhodnikov (" + ($all.Name -join ", ") + ") - ukazhite -Src <imya>") }
    $Src = $all[0].Name
  }
  if (-not $Kind) {
    if     ($Src -like "*.c")   { $Kind = "C" }
    elseif ($Src -like "*.asm") { $Kind = "ASM" }
    else { throw ("Neponyatnyy yazyk dlya " + $Src + " - ukazhite -Kind C ili -Kind ASM") }
  }
  if (-not $Exe) { $Exe = [IO.Path]::GetFileNameWithoutExtension($Src).ToLower() }
  return @{ Dir = $leaf; Kind = $Kind.ToUpper(); Src = $Src; Exe = $Exe }
}

$Tasks = @()
if ($Scan) {
  foreach ($sub in (Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name)) {
    if ($sub.Name -like ".*") { continue }
    $c = @(Get-ChildItem -LiteralPath $sub.FullName -File -Filter *.c   -ErrorAction SilentlyContinue).Count
    $a = @(Get-ChildItem -LiteralPath $sub.FullName -File -Filter *.asm -ErrorAction SilentlyContinue).Count
    if (($c + $a) -eq 1) { $Tasks += Get-DosTask $sub.FullName "" "" "" }
    else { Write-Output ("PROPUSHCHENO: " + $sub.Name + " (ishhodnikov: " + ($c + $a) + ")") }
  }
} elseif ($Dir) {
  $folder = if ([IO.Path]::IsPathRooted($Dir)) { $Dir } else { Join-Path $Root $Dir }
  $Tasks = @(Get-DosTask $folder $Kind $Src $Exe)
} elseif ($Only) {
  $Tasks = @(Get-DosTask (Join-Path $Root (Split-Path -Leaf ($Only.Trim($Q, $SQ, $BS)))) $Kind $Src $Exe)
} else {
  $Tasks = @(Get-DosTask $Root $Kind $Src $Exe)
}
if ($Tasks.Count -eq 0) { throw "Ni odna zadacha ne vybrana dlya progona" }

function Invoke-DosTask {
  param($T, [string]$CompileOverride, [int]$Timeout, [bool]$Decode866)
  $lab   = Join-Path $Root $T.Dir
  $build = Join-Path $lab "build"
  New-Item -ItemType Directory -Force -Path $build | Out-Null
  foreach ($pat in @("cc.txt", "run.txt")) {
    $dead = Join-Path $build $pat
    if (Test-Path -LiteralPath $dead) { Remove-Item -LiteralPath $dead -Force }
  }
  foreach ($ext in @("exe", "obj", "com", "map")) {
    foreach ($f in (Get-ChildItem -LiteralPath $build -File -Filter ($T.Exe + "." + $ext) -ErrorAction SilentlyContinue)) {
      Remove-Item -LiteralPath $f.FullName -Force
    }
  }

  $cmds = New-Object System.Collections.ArrayList
  [void]$cmds.Add("mount c " + $SQ + $CRoot + $SQ)
  [void]$cmds.Add("mount d " + $SQ + $lab + $SQ)
  [void]$cmds.Add("d:")
  # PATH един для всех веток: -Compile может вызывать и tcc, и tasm
  [void]$cmds.Add("set PATH=%PATH%;" + "c:" + $BS + "TCC" + $BS + "TC;c:" + $BS + "NTA")
  if ($CompileOverride) {
    # своя команда: редирект на cc.txt добавляем, только если её нет в команде
    $own = $CompileOverride
    if ($own -notmatch ">") { $own = $own + " > d:" + $BS + "build" + $BS + "cc.txt" }
    [void]$cmds.Add($own)
    # артефакты ожидаются в d:\build (флаг -nd:\build), туда и переходим
    [void]$cmds.Add("cd build")
  } elseif ($T.Kind -eq "C") {
    [void]$cmds.Add($Tcc + " -B -ms -DNOWAIT -nd:" + $BS + "build d:" + $BS + $T.Src + " > d:" + $BS + "build" + $BS + "cc.txt")
    [void]$cmds.Add("cd build")
  } else {
    [void]$cmds.Add("cd build")
    [void]$cmds.Add("tasm /zi /dNOWAIT .." + $BS + $T.Src + " > d:" + $BS + "build" + $BS + "cc.txt")
    [void]$cmds.Add("tlink /v /t " + $T.Exe + " >> d:" + $BS + "build" + $BS + "cc.txt")
  }
  [void]$cmds.Add($T.Exe + " > d:" + $BS + "build" + $BS + "run.txt")
  [void]$cmds.Add("exit")

  $argline = "-exit " + (($cmds | ForEach-Object { "-c " + $Q + $_ + $Q }) -join " ")

  Write-Output ""
  Write-Output ("=" * 78)
  Write-Output ("AVTOPROGON: " + $T.Dir + "   (" + $T.Kind + ", " + $T.Src + " -> " + $T.Exe + ")")
  Write-Output ("=" * 78)
  Write-Output ("KOMANDA: " + $argline)

  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $Box -ArgumentList $argline -PassThru -WindowStyle Minimized
  $finished = $p.WaitForExit($Timeout * 1000)
  $sw.Stop()
  if (-not $finished) {
    try { $p.Kill() } catch {}
    Write-Output ("RESULT: " + $T.Dir + "  STATUS=TIMEOUT  (DOSBox ne zapersilsya za " + $Timeout + " s)")
    Write-Output "  Verojatnaja prichina: programa zdet nazhanija klavishi - net guard NOWAIT."
    $script:Failed += 1
    return
  }
  Write-Output ("DOSBox zapersilsya: kod=" + $p.ExitCode + "  vremya=" + $sw.ElapsedMilliseconds + " ms")

  $ccFile  = Join-Path $build "cc.txt"
  $runFile = Join-Path $build "run.txt"
  $errors = 0
  Write-Output ("--- diagnostika kompilyatora (build" + $BS + "cc.txt) ---")
  if (Test-Path -LiteralPath $ccFile) {
    foreach ($line in (Get-Content -LiteralPath $ccFile)) {
      Write-Output $line
      $noise = ($line -like "*Error messages:*") -or ($line -like "*Warning messages:*") -or ($line -like "*errors in Compile*")
      if (-not $noise -and (($line -like "*Error*") -or ($line -like "*Fatal*"))) { $errors++ }
    }
  } else { Write-Output "(cc.txt ne sozdan - sborka ne vypolnyalas?)"; $errors++ }

  $bytes = 0
  Write-Output ("--- vyvod programmy (build" + $BS + "run.txt) ---")
  if (Test-Path -LiteralPath $runFile) {
    $bytes = (Get-Item -LiteralPath $runFile).Length
    if ($Decode866) {
      $raw = [IO.File]::ReadAllBytes($runFile)
      $txt = [Text.Encoding]::GetEncoding(866).GetString($raw)
    } else {
      $txt = Get-Content -LiteralPath $runFile -Raw
    }
    Write-Output ($txt.TrimEnd())
  } else { Write-Output "(run.txt ne sozdan - programma ne zapustilas)"; $errors++ }

  $status = if ($errors -eq 0 -and $bytes -gt 0) { "OK" } else { "FAIL" }
  Write-Output ("RESULT: " + $T.Dir + "  STATUS=" + $status + "  BUILD_ERRORS=" + $errors + "  RUN_BYTES=" + $bytes)
  if ($status -ne "OK") { $script:Failed += 1 }
}

# VAZHNO: rezultat funksii NE prisvaivaetsya peremennoj. V PowerShell
# konstrukciya "$x = Invoke-Something" (i lyuboy pipe vid "Invoke-Something |
# v peremennuyu x, i v konsol ne popadaet nichego (vyglyadit kak "skript
# molchat"). Schetchik provalov lezhit v $script:Failed.
$script:Failed = 0
foreach ($t in $Tasks) {
  Invoke-DosTask -T $t -CompileOverride $Compile -Timeout $TimeoutSec -Decode866 ([bool]$Cp866)
}
Write-Output ""
Write-Output ("Progon zavershen: zadach " + $Tasks.Count + ", provaleno " + $script:Failed)
if ($script:Failed -gt 0) { exit 1 } else { exit 0 }
