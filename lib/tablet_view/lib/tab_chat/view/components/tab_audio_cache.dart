import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService instance = AudioCacheService._();

  Future<File> getCachedAudio(String url) async {
    return await _downloadIfNeeded(url);
  }

  Future<File> _downloadIfNeeded(String url) async {
    final tempDir = await getTemporaryDirectory();
    // Safely extract filename
    final fileName = Uri.parse(url).pathSegments.last;
    // FIX: Use p.join() to create a valid Windows path (e.g., C:\Users\Temp\file.mp3)
    // instead of manually adding '/' which breaks MPV on Windows.
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    if (await file.exists()) return file;
    debugPrint('⬇ Downloading audio: $url');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download audio (${response.statusCode})');
    }

    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<File?> downloadAudioToDevice(String url) async {
    try {
      Directory downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory(
          '/storage/emulated/0/Download/printhelper/voice record',
        );
      } else if (Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${docs.path}/printhelper/voice record');
      } else if (Platform.isWindows) {
        final home =
            Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
        if (home == null) throw Exception('Home dir not found');
        // Use p.join here as well for safety
        downloadDir = Directory(
          p.join(home, 'Downloads', 'printhelper', 'voice record'),
        );
      } else {
        final home = Platform.environment['HOME'];
        if (home == null) throw Exception('Home dir not found');
        downloadDir = Directory('$home/Downloads/printhelper/voice record');
      }
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Download failed');
      }
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${url.split('/').last}';
      // Use p.join for the final file path too
      final file = File(p.join(downloadDir.path, fileName));
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('✔ Saved voice to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }
}
