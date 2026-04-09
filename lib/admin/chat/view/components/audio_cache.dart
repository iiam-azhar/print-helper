import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../../utils/console_util.dart';
import '../../../../utils/extensions.dart';

class AudioCacheService {
  static Future<File> getCachedAudio(String url) async {
    final dir = await getTemporaryDirectory();
    final fileName = Uri.parse(url).fileName;
    final file = File('${dir.path}/$fileName');

    if (await file.exists()) return file;

    final res = await http.get(Uri.parse(url));
    await file.writeAsBytes(res.bodyBytes);

    return file;
  }

  /// Download voice message to Download/printhelper folder
  static Future<File?> downloadAudioToDevice(String url) async {
    try {
      Directory downloadDir;
      if (Platform.isAndroid) {
        // Android: Use Downloads folder - construct path directly
        // Standard Android Downloads path: /storage/emulated/0/Download/
        final downloadPath =
            '/storage/emulated/0/Download/printhelper/voice record';
        downloadDir = Directory(downloadPath);
      } else if (Platform.isIOS) {
        // iOS: Use Documents directory with subfolder
        final docsDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${docsDir.path}/printhelper/voice record');
      } else {
        throw Exception("Unsupported platform");
      }
      // Create the folder if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      // Generate filename with timestamp to avoid duplicates
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalFileName = Uri.parse(url).fileName;
      final fileName = '${timestamp}_$originalFileName';
      final file = File('${downloadDir.path}/$fileName');
      // Download the file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Failed to download file (${response.statusCode})");
      }
      // Save to device storage
      await file.writeAsBytes(response.bodyBytes);
      printData(title: "Voice file saved to:", data: file.path);
      return file;
    } catch (e) {
      printData(title: "Download error:", data: e, e: true);
      return null;
    }
  }
}
