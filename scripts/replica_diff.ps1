param(
  [Parameter(Mandatory=$true)][string]$A,
  [Parameter(Mandatory=$true)][string]$B,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Tol = 24
)
Add-Type -AssemblyName System.Drawing
$imgA = [System.Drawing.Bitmap]::new((Resolve-Path $A).Path)
$imgB = [System.Drawing.Bitmap]::new((Resolve-Path $B).Path)
$w = [Math]::Min($imgA.Width, $imgB.Width); $h = [Math]::Min($imgA.Height, $imgB.Height)
$d = [System.Drawing.Bitmap]::new([int]$w, [int]$h)
$diff = 0
# 行带统计：每 20px 一带，找差异集中的区域
$bands = @{}
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    $pa = $imgA.GetPixel($x, $y); $pb = $imgB.GetPixel($x, $y)
    $dr = [Math]::Abs($pa.R - $pb.R); $dg = [Math]::Abs($pa.G - $pb.G); $db = [Math]::Abs($pa.B - $pb.B)
    if (($dr -gt $Tol) -or ($dg -gt $Tol) -or ($db -gt $Tol)) {
      $diff++
      $d.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 255, 40, 40))
      $k = [int]($y / 20); $bands[$k] = 1 + $(if ($bands.ContainsKey($k)) { $bands[$k] } else { 0 })
    } else {
      $g = [int](($pa.R + $pa.G + $pa.B) / 3 * 0.35)
      $d.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $g, $g, $g))
    }
  }
}
$d.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$pct = [Math]::Round(100.0 * $diff / ($w * $h), 2)
Write-Output "diff pixels: $diff / $($w*$h) = $pct%"
$bands.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 12 | ForEach-Object { Write-Output ("  y {0,4}-{1,4}: {2}" -f ($_.Key*20), ($_.Key*20+19), $_.Value) }
$imgA.Dispose(); $imgB.Dispose(); $d.Dispose()
