import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath =
            '${appDocDir.path}/voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<String?> stop() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      debugPrint("Error stopping record: $e");
      return null;
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
