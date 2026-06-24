# Windows 烟测 —— 复现 .github/workflows/smoke.yml 的 Windows 路径。
# DoD #5 明确要求「Windows 有 reproducible 脚本」：本地与 CI 同一份。
#   完整模式（默认）：pub get → analyze → test(--exclude-tags pg) → build windows → boot 检查
#   -BootOnly       ：仅对已构建的 exe 做 boot 检查（CI 在 build step 之后调用本脚本）
#
# Flutter 不在 PATH 时显式指定：
#   $env:FLUTTER = 'C:\Users\Kerro\flutter\bin\flutter.bat'; ./scripts/smoke/windows-smoke.ps1
#
# 设计：嵌入式 PG 不在启动关键路径（见 lib/main.dart），boot 检查不依赖 PG 二进制；
# PG 集成测以 --exclude-tags pg 排除。
param(
  [switch]$BootOnly,
  [int]$BootWait = 12
)
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path "$PSScriptRoot/../..")

$flutter = if ($env:FLUTTER) { $env:FLUTTER } else { 'flutter' }

function Invoke-Step($label, [scriptblock]$block) {
  Write-Host "→ $label"
  & $block
  if ($LASTEXITCODE -ne 0) { Write-Error "[smoke] '$label' 失败 (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
}

if (-not $BootOnly) {
  Invoke-Step 'flutter pub get'       { & $flutter pub get }
  Invoke-Step 'flutter analyze'       { & $flutter analyze }
  Invoke-Step 'flutter test (no pg)'  { & $flutter test --exclude-tags pg }
  Invoke-Step 'flutter build windows' { & $flutter build windows --release }
}

$exe = Get-ChildItem -Path 'build/windows/x64/runner/Release' -Filter '*.exe' -ErrorAction SilentlyContinue |
  Select-Object -First 1
if (-not $exe) { Write-Error '[smoke] 找不到 exe —— 先构建（去掉 -BootOnly）'; exit 1 }

Write-Host "→ boot 检查：$($exe.FullName)（存活 ${BootWait}s 视为启动未崩溃）"
$p = Start-Process -FilePath $exe.FullName -PassThru
Start-Sleep -Seconds $BootWait

if ($p.HasExited) {
  Write-Error "[smoke] 进程在 ${BootWait}s 内退出 code=$($p.ExitCode) —— 启动崩溃"
  exit 1
}

Write-Host "[smoke] 进程存活 ${BootWait}s，启动未崩溃 ✅"
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Write-Host '[smoke] OK'
