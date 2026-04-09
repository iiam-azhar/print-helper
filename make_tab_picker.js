const fs = require('fs');

let content = fs.readFileSync('lib/Files/components/email_recipient_picker.dart', 'utf-8');

// Remove screenutil import
content = content.replace("import 'package:flutter_screenutil/flutter_screenutil.dart';\n", '');

// Replace widget imports with tablet equivalents
content = content
  .replace("import '../../constants/paths.dart';", "import '../tab_constants/paths.dart';")
  .replace("import '../../widgets/image_widget.dart';", "import '../tab_widgets/tab_image_widget.dart';")
  .replace("import '../../widgets/text_widget.dart';", "import '../tab_widgets/tab_text_widget.dart';");

// Rename class
content = content
  .replace(/class EmailRecipientPicker extends StatefulWidget/g, 'class TabEmailRecipientPicker extends StatefulWidget')
  .replace(/State<EmailRecipientPicker>/g, 'State<TabEmailRecipientPicker>')
  .replace(/_EmailRecipientPickerState/g, '_TabEmailRecipientPickerState')
  .replace(/const EmailRecipientPicker\(/g, 'const TabEmailRecipientPicker(');

// Remove all ScreenUtil extensions
content = content
  .replace(/(\d+(?:\.\d+)?)\.sp\b/g, '$1')
  .replace(/(\d+(?:\.\d+)?)\.r\b/g, '$1')
  .replace(/(\d+(?:\.\d+)?)\.h\b/g, '$1')
  .replace(/(\d+(?:\.\d+)?)\.w\b/g, '$1');

fs.writeFileSync('lib/tablet_view/lib/tab_widgets/tab_email_recipient_picker.dart', content);
console.log('Done');
