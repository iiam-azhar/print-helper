const fs = require('fs');

let code = fs.readFileSync('extract2.js', 'utf-8');

code = code.replace(/Future<void> _showShareToEmailSheet\({[\s\S]*?}\) async {/, 
`static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
  }) async {`);

code = code.replace(/context\.read<FilesPro>\(\)/g, "Provider.of<FilesPro>(context, listen: false)");

code = code.replace(/final success = await pro\.shareItemToEmail\([\s\S]*?isFolder: isFolder,\n[\s]*\);/, 
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

code = code.replace(/showToast\([\s\S]*?message:\s*'Email share prepared.*/, `showToast(message: 'Email share prepared successfully');`);

let finalFile = `import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
${code}
}
`;

fs.writeFileSync('d:/Development Projects/GITHUB/printHelper/lib/tablet_view/lib/tab_widgets/tab_email_share_sheet.dart', finalFile);
console.log('Successfully completed');
