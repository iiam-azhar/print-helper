$file = 'lib\tablet_view\lib\tab_widgets\tab_email_share_sheet.dart'
$content = Get-Content -Raw $file

# Remove flutter_screenutil import
$content = $content -replace "import 'package:flutter_screenutil/flutter_screenutil\.dart';\r?\n", ''

# Replace .r, .h, .w, .sp extensions - order matters (longer first)
$content = $content -replace '(\d+(?:\.\d+)?)\.sp', '$1'
$content = $content -replace '(\d+(?:\.\d+)?)\.r\b', '$1'
$content = $content -replace '(\d+(?:\.\d+)?)\.h\b', '$1'
$content = $content -replace '(\d+(?:\.\d+)?)\.w\b', '$1'

Set-Content -NoNewline -Encoding UTF8 -Path $file -Value $content
Write-Output "Done"
