import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../tab_constants/strings.dart';
import '../tab_utils/console_util.dart';
import '../tab_utils/extensions.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_toasts.dart';
import 'api_service.dart';

class FileService {
  static Future<(String?, String?)> loadFile(String url) async {
    Loaders.show();
    try {
      printData(data: url);
      final uri = Uri.parse(url);
      final filename = uri.fileName; // extn used
      printData(data: filename);
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/$filename';
      printData(data: tempFilePath);
      final file = File(tempFilePath);

      final response = await ApiService().getDataFromApi(
        api: '',
        url: '$url?',
        showRes: false,
        decode: false,
        timeOut: 180,
      );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return (filename, tempFilePath);
      } else {
        showToast(message: AppStrings.error);
        return (null, null);
      }
    } catch (e) {
      printData(title: 'from loadFileFromUrl', data: '$e', e: true);
      showToast(message: AppStrings.error);
      return (null, null);
    } finally {
      Loaders.hide();
    }
  }
}
