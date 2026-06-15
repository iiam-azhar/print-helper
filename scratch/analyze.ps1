[Reflection.Assembly]::LoadWithPartialName('System.Drawing') | Out-Null
foreach ($file in @('phh_foreground.png')) {
    $img = [System.Drawing.Bitmap]::FromFile("assets/images/$file")
    $minX = $img.Width
    $maxX = 0
    $minY = $img.Height
    $maxY = 0
    for ($y = 0; $y -lt $img.Height; $y += 5) {
        for ($x = 0; $x -lt $img.Width; $x += 5) {
            $c = $img.GetPixel($x, $y)
            if ($c.A -gt 10) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    Write-Host "File: $file"
    Write-Host "  Width: $($img.Width) Height: $($img.Height)"
    Write-Host "  Non-transparent bounds: X($minX to $maxX) Y($minY to $maxY)"
    Write-Host "  Content size: $($maxX - $minX) x $($maxY - $minY)"
    $img.Dispose()
}
