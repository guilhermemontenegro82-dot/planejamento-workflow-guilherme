Add-Type -AssemblyName System.Drawing
$src = "D:\12- Claude - works\01 - EP Engenharia\Instagram EP\00-Marca\logo\EP Logo Nova.jpg"
$out = "D:\12- Claude - works\01 - EP Engenharia\Instagram EP\00-Marca\logo"
$bmp = New-Object Drawing.Bitmap $src
$w = $bmp.Width; $h = $bmp.Height
$rect = New-Object Drawing.Rectangle 0,0,$w,$h
$fmt = [Drawing.Imaging.PixelFormat]::Format32bppArgb
$data = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride*$h)
[Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data); $bmp.Dispose()

$white = New-Object byte[] $bytes.Length
$color = New-Object byte[] $bytes.Length
$rowInk = New-Object int[] $h
$minX = $w; $maxX = 0
for ($y=0; $y -lt $h; $y++) {
  $off = $y*$stride
  for ($x=0; $x -lt $w; $x++) {
    $i = $off + $x*4
    $b=$bytes[$i]; $g=$bytes[$i+1]; $r=$bytes[$i+2]
    $minc = $r; if ($g -lt $minc) {$minc=$g}; if ($b -lt $minc) {$minc=$b}
    $a = (255 - $minc) * 2.5; if ($a -gt 255) {$a = 255}; $a = [int]$a
    if ($a -lt 12) { $a = 0 }
    if ($a -gt 0) { $rowInk[$y]++; if ($x -lt $minX) {$minX=$x}; if ($x -gt $maxX) {$maxX=$x} }
    $white[$i]=255; $white[$i+1]=255; $white[$i+2]=255; $white[$i+3]=$a
    $color[$i]=$b; $color[$i+1]=$g; $color[$i+2]=$r; $color[$i+3]=$a
  }
}
# bounding rows
$minY = ($rowInk | ForEach-Object -Begin {$k=-1} -Process {$k++; if ($_ -gt 0 -and $minY -eq $null) {$k}} | Select-Object -First 1)
$rowsWithInk = @(); for ($y=0; $y -lt $h; $y++) { if ($rowInk[$y] -gt 0) { $rowsWithInk += $y } }
$minY = $rowsWithInk[0]; $maxY = $rowsWithInk[-1]
# largest vertical gap in lower half = separation symbol/text
$bestGap=0; $gapStart=0; $prev=$rowsWithInk[0]
foreach ($y in $rowsWithInk) { if (($y - $prev -gt $bestGap) -and ($prev -gt $h*0.5)) { $bestGap = $y - $prev; $gapStart = $prev }; $prev = $y }
$symbolBottom = $gapStart
"ink box: x $minX..$maxX  y $minY..$maxY ; gap simbolo/texto: $bestGap px a partir de y=$symbolBottom"

function Save-Crop($buf, $x0, $y0, $x1, $y1, $path) {
  $cw = $x1-$x0+1; $ch = $y1-$y0+1
  $o = New-Object Drawing.Bitmap $cw,$ch,$fmt
  $r2 = New-Object Drawing.Rectangle 0,0,$cw,$ch
  $d = $o.LockBits($r2, [Drawing.Imaging.ImageLockMode]::WriteOnly, $fmt)
  $line = New-Object byte[] ($cw*4)
  for ($yy=0; $yy -lt $ch; $yy++) {
    [Array]::Copy($buf, ($y0+$yy)*$stride + $x0*4, $line, 0, $cw*4)
    [Runtime.InteropServices.Marshal]::Copy($line, 0, [IntPtr]::Add($d.Scan0, $yy*$d.Stride), $cw*4)
  }
  $o.UnlockBits($d); $o.Save($path, [Drawing.Imaging.ImageFormat]::Png); $o.Dispose()
  "salvo $cw x $ch  $(Split-Path $path -Leaf)"
}
$pad = 8
$x0=[Math]::Max(0,$minX-$pad); $x1=[Math]::Min($w-1,$maxX+$pad); $y0=[Math]::Max(0,$minY-$pad); $y1=[Math]::Min($h-1,$maxY+$pad)
Save-Crop $white $x0 $y0 $x1 $y1 (Join-Path $out "logo-ep-branco.png")
Save-Crop $color $x0 $y0 $x1 $y1 (Join-Path $out "logo-ep-azul.png")
# symbol only: horizontal bounds of the symbol rows
$sMinX=$w; $sMaxX=0
for ($y=$minY; $y -le $symbolBottom; $y++) { $off=$y*$stride; for ($x=0;$x -lt $w;$x++){ if ($white[$off+$x*4+3] -gt 0){ if($x -lt $sMinX){$sMinX=$x}; if($x -gt $sMaxX){$sMaxX=$x} } } }
Save-Crop $white ([Math]::Max(0,$sMinX-$pad)) $y0 ([Math]::Min($w-1,$sMaxX+$pad)) ($symbolBottom+$pad) (Join-Path $out "simbolo-ep-branco.png")
Save-Crop $color ([Math]::Max(0,$sMinX-$pad)) $y0 ([Math]::Min($w-1,$sMaxX+$pad)) ($symbolBottom+$pad) (Join-Path $out "simbolo-ep-azul.png")