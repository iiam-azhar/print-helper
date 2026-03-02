import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'tab_audio_cache.dart';
import 'tab_audio_manager.dart';
import '../../service/tab_waveform_extractor.dart';
import 'tab_custom_wave.dart';
import '../../../tab_widgets/tab_toasts.dart';
import '../../../tab_widgets/loaders.dart';

import '../../../tab_widgets/tab_spacers.dart';

class VoiceMessageBubbleUI extends StatefulWidget {
  final String path;
  final int duration;
  final bool isMe;
  final bool isUploading;

  const VoiceMessageBubbleUI({
    super.key,
    required this.path,
    required this.duration,
    required this.isMe,
    this.isUploading = false,
  });

  @override
  State<VoiceMessageBubbleUI> createState() => _VoiceMessageBubbleUIState();
}

class _VoiceMessageBubbleUIState extends State<VoiceMessageBubbleUI>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerPositionSub;

  bool _isMePlaying = false;
  bool _isReady = false;
  Duration _currentPosition = Duration.zero;

  List<double> _waveform = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWaveform();
    _listenToGlobalPlayer();
  }

  /// Load waveform only (NO AUDIO PLAYER HERE)
  Future<void> _loadWaveform() async {
    try {
      final file = await AudioCacheService.instance.getCachedAudio(widget.path);
      if (!mounted) return;

      final extractor = WaveformExtractor();
      final data = await extractor.extractWaveform(file.path, samples: 50);

      if (mounted) {
        setState(() {
          _waveform = data;
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint("Waveform error: $e");
      // Still mark as ready even if waveform fails - user can still play the audio
      if (mounted) {
        setState(() {
          _waveform = WaveformExtractor.generateDefaultWaveform(50);
          _isReady = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    super.dispose();
  }

  // inside _VoiceMessageBubbleUIState

  void _listenToGlobalPlayer() {
    final manager = VoiceAudioManager.instance;
    _playerStateSub = manager.playerStateStream.listen(
      (state) {
        if (!mounted) return;
        try {
          // FIX: Compare the URL passed to this widget vs the URL in the manager
          // No need to await AudioCacheService here anymore.
          final isMyFile = manager.currentUrl == widget.path;
          final isPlaying = state.playing && isMyFile;
          // Handle Completion
          if (state.processingState == ProcessingState.completed && isMyFile) {
            if (mounted) {
              setState(() {
                _isMePlaying = false;
                _currentPosition = Duration.zero;
              });
            }
            return;
          }
          // Only update state if it actually changed to prevent rebuild loops
          if (isPlaying != _isMePlaying) {
            setState(() => _isMePlaying = isPlaying);
          }
        } catch (e) {
          debugPrint("Error in player state listener: $e");
        }
      },
      onError: (error) {
        debugPrint("Player state stream error in UI: $error");
      },
    );
    _playerPositionSub = manager.positionStream.listen(
      (pos) {
        if (!mounted) return;
        try {
          // FIX: Check URL instead of local path
          if (VoiceAudioManager.instance.currentUrl == widget.path) {
            setState(() => _currentPosition = pos);
          }
        } catch (e) {
          debugPrint("Error in position listener: $e");
        }
      },
      onError: (error) {
        debugPrint("Position stream error in UI: $error");
      },
    );
  }

  Future<void> _toggle() async {
    if (!_isReady) return;
    final manager = VoiceAudioManager.instance;

    try {
      if (_isMePlaying) {
        await manager.pause();
      } else {
        await manager.play(widget.path);
      }
    } catch (e) {
      debugPrint("Toggle error: $e");
    }
  }

  Future<void> _downloadVoice() async {
    Loaders.show();
    try {
      final file = await AudioCacheService.downloadAudioToDevice(widget.path);
      Loaders.hide();
      if (file != null) {
        debugPrint("Downloaded to: ${file.path}");
        showToast(message: "Saved to: Download/printhelper/voice record");
      } else {
        showToast(message: "Failed to download voice message");
      }
    } catch (e) {
      Loaders.hide();
      debugPrint("Download error: $e");
      showToast(message: "Error: ${e.toString()}");
    }
  }

  String _fmt(int sec) =>
      "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";

  /// Waveform progress calculation
  int _activeSamples() {
    if (_waveform.isEmpty || widget.duration == 0) return 0;

    final totalMs = widget.duration * 1000;
    final progress = (_currentPosition.inMilliseconds / totalMs).clamp(
      0.0,
      1.0,
    );

    return (_waveform.length * progress).toInt();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xfff1f1f2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isMe ? Colors.grey[300] : Colors.grey[400],
                ),
                child: widget.isUploading || !_isReady
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _toggle,
                        icon: Icon(
                          _isMePlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black,
                        ),
                      ),
              ),
              Spacers.sbw8(),
              SizedBox(
                width: 150,
                height: 32,
                child: CustomWaveform(
                  samples: _waveform,
                  activeSamples: _activeSamples(),
                  inactiveColor: Colors.black.withValues(alpha: 0.3),
                  activeColor: Colors.blueAccent,
                ),
              ),
              IconButton(
                onPressed: _isReady ? _downloadVoice : null,
                icon: Icon(
                  Icons.file_download_outlined,
                  color: _isReady ? Colors.black : Colors.grey,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              widget.isUploading
                  ? "Uploading..."
                  : "${_fmt(_currentPosition.inSeconds)} / ${_fmt(widget.duration)}",
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom waveform display widget
