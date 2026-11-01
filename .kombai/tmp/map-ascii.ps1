Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap((Resolve-Path "site\gwars\apps\web\public\city\base.jpg").Path)
$imgW = $bmp.Width
$imgH = $bmp.Height
$nCols = 64
$nRows = 48
$cellW = $imgW / $nCols
$cellH = $imgH / $nRows

$h1 = "    "
$h2 = "    "
for ($ci = 0; $ci -lt $nCols; $ci++) {
    $h1 += [string]([math]::Floor($ci / 10))
    $h2 += [string]($ci % 10)
}
Write-Output $h1
Write-Output $h2

for ($ri = 0; $ri -lt $nRows; $ri++) {
    $line = ""
    for ($ci = 0; $ci -lt $nCols; $ci++) {
        $px = [math]::Min($imgW - 1, [int](($ci + 0.5) * $cellW))
        $py = [math]::Min($imgH - 1, [int](($ri + 0.5) * $cellH))
        $pixel = $bmp.GetPixel($px, $py)
        $rr = $pixel.R
        $gg = $pixel.G
        $bb = $pixel.B
        $mark = "."
        if ($bb -gt ($rr + 10) -and $bb -gt 60) { $mark = "~" }
        elseif (($rr - $bb) -gt 30 -and $rr -gt 110 -and $gg -gt ($bb + 8)) { $mark = "P" }
        elseif ($gg -gt ($rr + 4) -and $gg -gt 70) { $mark = "g" }
        elseif ($rr -gt 145 -and $gg -gt 140 -and $bb -gt 125) { $mark = "S" }
        $line += $mark
    }
    Write-Output ("{0,3} {1}" -f $ri, $line)
}
$bmp.Dispose()
