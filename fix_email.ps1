$file = 'lib\tablet_view\lib\tab_widgets\tab_email_share_sheet.dart'
$lines = Get-Content $file
$result = [System.Collections.Generic.List[string]]::new()

$skipNext = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Replace shareItemToEmail with shareItemsToEmail
    if ($line -match 'shareItemToEmail\(') {
        $result.Add($line -replace 'shareItemToEmail\(', 'shareItemsToEmail(')
        continue
    }

    # Remove lines with old item params
    if ($line -match '^\s+itemPath: itemPath,' -or $line -match '^\s+itemName: itemName,' -or $line -match '^\s+isFolder: isFolder,') {
        continue
    }

    # Replace replyToEmail line AND insert items: items, after
    if ($line -match '^\s+replyToEmail: selectedReplyToEmail,') {
        $indent = '                                      '
        $result.Add($line)
        $result.Add("${indent}items: items,")
        continue
    }

    # Remove stray ); after showToast
    if ($line -match "^\s+\);$" -and $i -gt 0 -and $lines[$i-1] -match "showToast\(message:") {
        continue
    }

    $result.Add($line)
}

Set-Content -Path $file -Value $result -Encoding UTF8
Write-Output "Done: $($result.Count) lines written"
