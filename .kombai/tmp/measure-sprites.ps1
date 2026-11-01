Add-Type -AssemblyName System.Drawing

$dir = "site\gwars\apps\web\public\city"
$base = [System.Drawing.Image]::FromFile((Resolve-Path (Join-Path $dir "base.jpg")).Path)
Write-Output ("BASE " + $base.Width + "x" + $base.Height)
$base.Dispose()

$grids = [ordered]@{ "civic.png" = @(3, 2); "military.png" = @(3, 2); "industry.png" = @(2, 2); "outer.png" = @(2, 2) }

foreach ($name in $grids.Keys) {
    $path = Join-Path $dir $name
    $bmp = New-Object System.Drawing.Bitmap((Resolve-Path $path).Path)
    $w = $bmp.Width
    $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $bmp.Dispose()

    $cols = $grids[$name][0]
    $rows = $grids[$name][1]
    $cw = [int]($w / $cols)
    $ch = [int]($h / $rows)

    for ($cy = 0; $cy -lt $rows; $cy++) {
        for ($cx = 0; $cx -lt $cols; $cx++) {
            $x0 = 999999
            $y0 = 999999
            $x1 = -1
            $y1 = -1
            for ($y = $cy * $ch; $y -lt (($cy + 1) * $ch); $y++) {
                $rowStart = $y * $stride
                for ($x = $cx * $cw; $x -lt (($cx + 1) * $cw); $x++) {
                    $alpha = $bytes[$rowStart + ($x * 4) + 3]
                    if ($alpha -gt 24) {
                        if ($x -lt $x0) { $x0 = $x }
                        if ($x -gt $x1) { $x1 = $x }
                        if ($y -lt $y0) { $y0 = $y }
                        if ($y -gt $y1) { $y1 = $y }
                    }
                }
            }
            if ($x1 -ge 0) {
                $bw = $x1 - $x0 + 1
                $bh = $y1 - $y0 + 1
                Write-Output ("SPRITE|$name|$cx|$cy|$x0|$y0|$bw|$bh|$w|$h")
            }
        }
    }
}
