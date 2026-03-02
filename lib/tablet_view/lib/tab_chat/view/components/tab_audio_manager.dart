import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'tab_audio_cache.dart';

class VoiceAudioManager {
  // Singleton Pattern
  static final VoiceAudioManager instance = VoiceAudioManager._();
  VoiceAudioManager._();

  AudioPlayer? _player;
  bool _disposed = false;
  StreamSubscription? _completionSubscription;

  // Track the SOURCE URL (the ID), not just the local path
  String? _currentUrl;
  String? get currentUrl => _currentUrl;

  bool get isPlaying {
    try {
      return _player?.playing ?? false;
    } catch (e) {
      debugPrint("Error checking isPlaying: $e");
      return false;
    }
  }

  Stream<PlayerState> get playerStateStream {
    try {
      return _ensurePlayer().playerStateStream;
    } catch (e) {
      debugPrint("Error getting playerStateStream: $e");
      // Return a stream that never emits to avoid crashing
      return Stream.empty();
    }
  }

  Stream<Duration> get positionStream {
    try {
      return _ensurePlayer().positionStream;
    } catch (e) {
      debugPrint("Error getting positionStream: $e");
      return Stream.empty();
    }
  }

  AudioPlayer _ensurePlayer() {
    if (_disposed) {
      throw StateError('VoiceAudioManager has been disposed');
    }
    if (_player == null) {
      _player = AudioPlayer();
    }
    return _player!;
  }

  /// Sets up a one-time completion listener for the current playback
  void _setupCompletionListener(AudioPlayer player) {
    // Cancel previous subscription if it exists
    _completionSubscription?.cancel();
    _completionSubscription = null;

    // Set up new completion listener with error handling
    _completionSubscription = player.playerStateStream.listen(
      (state) {
        try {
          if (state.processingState == ProcessingState.completed) {
            debugPrint("▶ Playback completed, resetting");
            // We pause and seek to zero so the UI updates to "Play" icon
            player.pause();
            player.seek(Duration.zero);
            // Cancel this subscription after completion
            _completionSubscription?.cancel();
            _completionSubscription = null;
          }
        } catch (e) {
          debugPrint("Error in completion listener: $e");
          _completionSubscription?.cancel();
          _completionSubscription = null;
        }
      },
      onError: (error) {
        debugPrint("Player state stream error: $error");
        _completionSubscription?.cancel();
        _completionSubscription = null;
      },
    );
  }

  // Future<void> play(String url) async {
  //   try {
  //     // Reset player if it might be stale (e.g., after hot reload)
  //     if (_player != null) {
  //       try {
  //         // Try to check if player is still alive by accessing a property
  //         _player!.playing;
  //       } catch (e) {
  //         debugPrint("Player became stale, recreating: $e");
  //         await _player!.dispose();
  //         _player = null;
  //         _currentUrl = null;
  //         _completionSubscription?.cancel();
  //         _completionSubscription = null;
  //       }
  //     }

  //     final player = _ensurePlayer();

  //     // 1. If user clicks play on the audio that is ALREADY playing, do nothing
  //     if (_currentUrl == url && player.playing) {
  //       return;
  //     }

  //     // 2. If user clicks play on the same audio that is PAUSED, just resume
  //     if (_currentUrl == url &&
  //         player.processingState != ProcessingState.idle) {
  //       await player.play();
  //       return;
  //     }

  //     // 3. If it's a DIFFERENT audio, stop the old one and clear the path
  //     if (_currentUrl != url) {
  //       await stop();
  //     }

  //     // 4. Mark this as the current playing URL
  //     _currentUrl = url;

  //     // 5. Get the file (Download/Cache)
  //     // Since we are using Media Kit, this will handle .webm and .mp3 natively
  //     final file = await AudioCacheService.instance.getCachedAudio(url);
  //     debugPrint("▶ Playing local file: ${file.path}");

  //     // 6. Set up completion listener BEFORE loading
  //     _setupCompletionListener(player);

  //     // 7. Load and Play
  //     // 'preload: false' is highly recommended for Windows to prevent
  //     // the UI thread from hanging while the media engine initializes.
  //     await player.setFilePath(file.path, preload: false);
  //     await player.play();
  //   } catch (e) {
  //     debugPrint("Audio Play Error: $e");
  //     _currentUrl = null;
  //     _completionSubscription?.cancel();
  //     _completionSubscription = null;
  //     try {
  //       await _player?.stop();
  //     } catch (stopError) {
  //       debugPrint("Error stopping player on exception: $stopError");
  //     }
  //   }
  // }
  // ... imports

  Future<void> play(String url) async {
    try {
      if (_player != null) {
        try {
          _player!.playing;
        } catch (e) {
          await _player!.dispose();
          _player = null;
          _currentUrl = null;
        }
      }

      final player = _ensurePlayer();

      if (_currentUrl == url && player.playing) return;
      if (_currentUrl == url &&
          player.processingState != ProcessingState.idle) {
        await player.play();
        return;
      }
      if (_currentUrl != url) await stop();

      _currentUrl = url;

      final file = await AudioCacheService.instance.getCachedAudio(url);
      debugPrint("▶ Playing local file: ${file.path}");

      _setupCompletionListener(player);

      // FIX: Use AudioSource.uri with Uri.file, and REMOVE the 'tag' argument
      await player.setAudioSource(
        AudioSource.uri(
          Uri.file(file.path),
          // tag: removed because MediaItem requires extra dependencies
        ),
        preload: false,
      );

      await player.play();
    } catch (e) {
      debugPrint("Audio Play Error: $e");
      _currentUrl = null;
      try {
        await _player?.stop();
      } catch (_) {}
    }
  }

  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint("Error pausing: $e");
    }
  }

  Future<void> stop() async {
    try {
      _completionSubscription?.cancel();
      _completionSubscription = null;
      // Stop the player and reset internal tracking
      await _player?.stop();
      _currentUrl = null;
    } catch (e) {
      debugPrint("Stop error: $e");
      _currentUrl = null;
    }
  }

  void dispose() {
    if (!_disposed) {
      try {
        _completionSubscription?.cancel();
        _completionSubscription = null;
        _player?.dispose();
      } catch (e) {
        debugPrint("Error during dispose: $e");
      }
      _player = null;
      _disposed = true;
      _currentUrl = null;
    }
  }

  /// Resets the manager (useful for hot reload scenarios)
  void reset() {
    try {
      _completionSubscription?.cancel();
      _completionSubscription = null;
      _player?.dispose();
    } catch (e) {
      debugPrint("Error during reset: $e");
    }
    _player = null;
    _currentUrl = null;
  }
}
