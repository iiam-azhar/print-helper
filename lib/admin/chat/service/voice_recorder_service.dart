import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../utils/console_util.dart';

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
      printData(title: "Error starting record:", data: e, e: true);
    }
  }

  Future<String?> stop() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      printData(title: "Error stopping record:", data: e, e: true);
      return null;
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
