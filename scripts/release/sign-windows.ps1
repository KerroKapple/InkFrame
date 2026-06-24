# Windows 代码签名 —— BUILD-RELEASE §7 骨架。
# 骨架契约：缺凭据 → 打印 SKIPPED 退出 0，不阻断。
#
# 注意：EV 证书通常在物理 Dongle，无法以 base64 注入 CI —— 那种情形走「挂载 Dongle 的
# self-hosted runner / 云签服务」（BUILD-RELEASE §7.2 / §14）。本脚本覆盖「软证书 PFX」路径，
# 供测试或 OV 证书使用。
#
# 环境变量（由 release.yml 从 GitHub Secrets 注入）：
#   WINDOWS_CERT_PFX_BASE64   .pfx 证书的 base64
#   WINDOWS_CERT_PASSWORD     .pfx 密码
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path "$PSScriptRoot/../..")

if (-not $env:WINDOWS_CERT_PFX_BASE64) {
  Write-Host '[sign-win] SKIPPED —— 未配置 WINDOWS_CERT_PFX_BASE64（签名凭据缺失）。'
  Write-Host '[sign-win] 产物保持 unsigned；配置 PFX 或挂 Dongle runner 后本步骤自动生效。'
  exit 0
}

$releaseDir = 'build/windows/x64/runner/Release'
if (-not (Test-Path $releaseDir)) { Write-Error "[sign-win] 找不到 $releaseDir —— 先 flutter build windows"; exit 1 }

$pfx = Join-Path $env:RUNNER_TEMP 'inkframe-cert.pfx'
[IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:WINDOWS_CERT_PFX_BASE64))

# 定位 signtool.exe（不在 PATH 时从 Windows SDK 探测）
$signtool = (Get-Command signtool.exe -ErrorAction SilentlyContinue).Source
if (-not $signtool) {
  $cand = Get-ChildItem 'C:/Program Files (x86)/Windows Kits/10/bin' -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'x64' } | Select-Object -First 1
  if (-not $cand) { Write-Error '[sign-win] 找不到 signtool.exe（需 Windows SDK）'; exit 1 }
  $signtool = $cand.FullName
}

# 签 exe + 所有 DLL（含嵌入式 PG / libmpv）
$targets = @(Join-Path $releaseDir 'inkframe.exe')
$targets += Get-ChildItem -Path $releaseDir -Recurse -Filter *.dll | ForEach-Object { $_.FullName }

foreach ($t in $targets) {
  if (-not (Test-Path $t)) { continue }
  Write-Host "[sign-win] sign $t"
  & $signtool sign /f $pfx /p $env:WINDOWS_CERT_PASSWORD `
    /tr http://timestamp.digicert.com /td sha256 /fd sha256 $t
  if ($LASTEXITCODE -ne 0) { Write-Error "[sign-win] 签名失败：$t"; exit $LASTEXITCODE }
}

& $signtool verify /pa /v (Join-Path $releaseDir 'inkframe.exe')
Remove-Item $pfx -Force -ErrorAction SilentlyContinue
Write-Host '[sign-win] 签名完成 ✅'
