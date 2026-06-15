[Reflection.Assembly]::LoadWithPartialName('System.Drawing') | Out-Null
$srcImg = [System.Drawing.Bitmap]::FromFile('assets/images/phh.png')
$dstImg = New-Object System.Drawing.Bitmap 2134, 2134
$g = [System.Drawing.Graphics]::FromImage($dstImg)

$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$srcRect = New-Object System.Drawing.Rectangle 240, 265, 1650, 1595
$dstRect = New-Object System.Drawing.Rectangle 427, 448, 1280, 1237

$g.DrawImage($srcImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$dstImg.Save('assets/images/phh_foreground.png', [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$srcImg.Dispose()
$dstImg.Dispose()
Write-Host "Successfully generated assets/images/phh_foreground.png"
