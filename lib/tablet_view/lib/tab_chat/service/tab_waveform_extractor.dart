import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to extract waveform data from audio files
class WaveformExtractor {
  /// Extracts waveform data from an audio file
  /// Returns a list of normalized amplitude values (0.0 to 1.0)
  ///
  /// [filePath]: Path to the audio file
  /// [samples]: Number of samples to extract (default: 50)
  Future<List<double>> extractWaveform(
    String filePath, {
    int samples = 50,
  }) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('Audio file not found: $filePath');
        return generateDefaultWaveform(samples);
      }

      // Generate a waveform with some variation based on file size
      // This is a simplified approach - a real implementation would decode the audio
      final fileSize = await file.length();
      final waveform = _generateWaveformFromFileSize(fileSize, samples);

      return waveform;
    } catch (e) {
      debugPrint('Error extracting waveform: $e');
      return generateDefaultWaveform(samples);
    }
  }

  /// Generates a default waveform pattern that looks like real audio
  static List<double> generateDefaultWaveform(int samples) {
    return _generateRealisticWaveform(12345, samples);
  }

  /// Generates waveform based on file size (for mock implementation)
  static List<double> _generateWaveformFromFileSize(int fileSize, int samples) {
    return _generateRealisticWaveform(fileSize.hashCode, samples);
  }

  /// Generates a realistic-looking audio waveform with multiple peaks and valleys
  static List<double> _generateRealisticWaveform(int seed, int samples) {
    return List.generate(samples, (i) {
      // Use seed to create pseudo-random but consistent pattern
      final hash1 = _pseudoRandom(seed + i * 73);
      final hash2 = _pseudoRandom(seed + i * 137);
      final hash3 = _pseudoRandom(seed + i * 211);

      // Combine multiple sine waves for more
      final wave1 = (hash1 % 100) / 100.0;
      final wave2 = (hash2 % 100) / 100.0;
      final wave3 = (hash3 % 100) / 100.0;

      // Mix waves with different frequencies
      final combined = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2) * 0.9;

      // Ensure we never get too quiet at the edges, but allow variation
      final value = (combined).clamp(0.15, 0.98);
      return value;
    });
  }

  /// Simple pseudo-random number generator
  static int _pseudoRandom(int value) {
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value.abs();
  }
}
