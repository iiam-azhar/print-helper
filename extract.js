const fs = require('fs');

const mobileFilesList = fs.readFileSync('d:/Development Projects/GITHUB/printHelper/lib/Files/files_list.dart', 'utf-8');

const startStr = '  Future<void> _showShareToEmailSheet({';
const startIdx = mobileFilesList.indexOf(startStr);
let endIdx = -1;

if(startIdx !== -1) {
  let depth = 0;
  let inString = false;
  let inChar = false;
  for(let i=startIdx; i<mobileFilesList.length; i++) {
    const c = mobileFilesList[i];
    if(c === '\'' && !inString) inChar = !inChar;
    if(c === '"' && !inChar) inString = !inString;
    if(!inString && !inChar) {
      if(c === '{') depth++;
      else if(c === '}') {
        depth--;
        if(depth === 0) {
          endIdx = i + 1;
          break;
        }
      }
    }
  }
}

if (startIdx === -1 || endIdx === -1) {
  console.error("Method not found");
  process.exit(1);
}

let sheetCode = mobileFilesList.substring(startIdx, endIdx);

// Convert to static method
sheetCode = sheetCode.replace('Future<void> _showShareToEmailSheet({', 'static Future<void> show({');

// Replace parameters
sheetCode = sheetCode.replace(
  /required String itemName,[\s\S]*?bool isFolder = false,\s*}\) async {/,
  'required BuildContext context,\n    required List<Map<String, dynamic>> items,\n  }) async {'
);

// Replace context.read with Provider.of
sheetCode = sheetCode.replace(/context\.read<FilesPro>\(\)/g, "Provider.of<FilesPro>(context, listen: false)");

// Replace pro.shareItemToEmail(...) with shareItemsToEmail
// We can just use a simple regex replacing from 'final success = await pro.shareItemToEmail(' to ');'
sheetCode = sheetCode.replace(/final success = await pro\.shareItemToEmail\([\s\S]*?isFolder: isFolder,\n[\s]*\);/, 
  `final success = await pro.shareItemsToEmail(
                                      subject: subject,
                                      message: message,
                                      sentToUserIds: selectedSentToUsers.map((u) => u['id'] as int).toList(),
                                      sentToEmails: [...selectedSentToEmails, ...recipients],
                                      replyToUserIds: selectedReplyTo != null ? [selectedReplyTo!['id'] as int] : [],
                                      replyToEmail: selectedReplyToEmail,
                                      items: items,
                                    );`
);

// We change the success Toast message
sheetCode = sheetCode.replace(/showToast\([\s\S]*?message:\s*'Email share prepared.*/, `showToast(message: 'Email share prepared successfully');`);

// We change TextWidget to tab_text.TextWidget since the tablet has a namespace for it usually
// But we actually import it directly as tab_text.TextWidget ? Let's use it without alias for simplicity
// Actually, `tab_text_widget.dart` has `TextWidget`.
sheetCode = sheetCode.replace(/TextWidget\(/g, "TextWidget(");
sheetCode = sheetCode.replace(/ImageWidget\(/g, "ImageWidget(");

let finalFile = `import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../providers/files_pro.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/loaders.dart';
import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../../../Files/components/email_recipient_picker.dart';

class TabEmailShareSheet {
${sheetCode}
}
`;

fs.writeFileSync('d:/Development Projects/GITHUB/printHelper/lib/tablet_view/lib/tab_widgets/tab_email_share_sheet.dart', finalFile);
console.log('Successfully created TabEmailShareSheet');
