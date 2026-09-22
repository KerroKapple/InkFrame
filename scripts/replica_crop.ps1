param(
  [Parameter(Mandatory=$true)][string]$In,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$X = 0, [int]$Y = 0, [int]$W = 1600, [int]$H = 1000
)
# 从整页截图里裁出一屏（复刻比对用：稿的 Screens 页是多屏纵排，先找到屏的左上角再裁）。
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::new((Resolve-Path $In).Path)
$dst = $src.Clone([System.Drawing.Rectangle]::new($X, $Y, $W, $H), $src.PixelFormat)
$dst.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$src.Dispose(); $dst.Dispose()
Write-Output "cropped $W x $H at ($X,$Y) -> $Out"
