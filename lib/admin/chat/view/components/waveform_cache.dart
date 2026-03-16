

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WaveformCache {
  static const String _prefix = 'waveform_';

  /// Saves the waveform data to SharedPreferences using the URL as a key.
  static Future<void> saveWaveform(String url, List<double> waveform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$url';
      final jsonString = jsonEncode(waveform);
      await prefs.setString(key, jsonString);
    } catch (e) {
      // Ignore cache save errors silently
    }
  }

  /// Retrieves the waveform data from SharedPreferences using the URL as a key.
  static Future<List<double>?> getWaveform(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$url';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded
            .map((e) => double.tryParse(e.toString()) ?? 0.0)
            .toList();
      }
    } catch (e) {
      // Ignore cache read errors silently
    }
    return null;
  }
}
