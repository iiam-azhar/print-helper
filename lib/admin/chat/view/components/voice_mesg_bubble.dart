import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';
import 'package:print_helper/admin/chat/view/components/audio_cache.dart';
import 'package:print_helper/admin/chat/view/components/audio_manager.dart';
import 'package:print_helper/admin/chat/view/components/waveform_cache.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:print_helper/widgets/loaders.dart';

import '../../../../widgets/spacers.dart';
import '../../../../utils/console_util.dart';

class VoiceMessageBubbleUI extends StatefulWidget {
  final String path;
  final int duration;
  final bool isMe;
  final bool isUploading;
  final List<double>? voiceWaveform;

  const VoiceMessageBubbleUI({
    super.key,
    required this.path,
    required this.duration,
    required this.isMe,
    this.isUploading = false,
    this.voiceWaveform,
  });

  @override
  State<VoiceMessageBubbleUI> createState() => _VoiceMessageBubbleUIState();
}

class _VoiceMessageBubbleUIState extends State<VoiceMessageBubbleUI>
    with AutomaticKeepAliveClientMixin {
  late final PlayerController _waveController;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerPositionSub;

  bool _isMePlaying = false; // Is THIS specific bubble playing?
  Duration _currentPosition = Duration.zero;
  bool _isReady = false;
  List<double>? _localWaveform;

  // 2. Override wantKeepAlive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _localWaveform = widget.voiceWaveform;
    _waveController = PlayerController();
    _initWaveform();
    _listenToGlobalPlayer();
  }

  /// 1. Only load the visual waveform (no audio loading yet)
  // ... inside _VoiceMessageBubbleUIState

  Future<void> _initWaveform() async {
    if (_localWaveform != null && _localWaveform!.isNotEmpty) {
      if (mounted) setState(() => _isReady = true);
      return; // Skip extraction since we already have the waveform
    }

    try {
      final cachedWaveform = await WaveformCache.getWaveform(widget.path);
      if (cachedWaveform != null && cachedWaveform.isNotEmpty) {
        if (mounted) {
          setState(() {
            _localWaveform = cachedWaveform;
            _isReady = true;
          });
        }
        return;
      }

      final file = await AudioCacheService.getCachedAudio(widget.path);
      // Safety check before starting heavy async work
      if (!mounted) return;

      // Convert file path to proper URI format for audio_waveforms package
      final fileUri = file.uri.toString();
      final extractedWaveform = await _waveController.waveformExtraction
          .extractWaveformData(path: fileUri, noOfSamples: 50);

      if (extractedWaveform.isNotEmpty) {
        await WaveformCache.saveWaveform(widget.path, extractedWaveform);
      }

      if (mounted) {
        setState(() {
          _localWaveform = extractedWaveform.isNotEmpty
              ? extractedWaveform
              : null;
          _isReady = true;
        });
      }
    } catch (e) {
      printData(title: "Waveform error:", data: e, e: true);
      if (mounted) {
        setState(() => _isReady = false);
      }
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    if (_isReady) {
      // Suppress platform exceptions during dispose (codec release)
      runZonedGuarded(
        () {
          _waveController.dispose();
        },
        (e, st) {
          // Swallow codec release errors quietly
        },
      );
    }
    super.dispose();
  }

  void _listenToGlobalPlayer() {
    final manager = VoiceAudioManager.instance;
    _playerStateSub = manager.playerStateStream.listen(
      (state) {
        if (!mounted) return;
        final isMyFile = manager.currentPath == widget.path;
        final isPlaying = state.playing && isMyFile;
        // Handle Completion (Fix for "Codec Released" crash)
        if (state.processingState == ProcessingState.completed && isMyFile) {
          try {
            if (_localWaveform == null || _localWaveform!.isEmpty) {
              _waveController.pausePlayer();
              _waveController.seekTo(0);
            }
          } catch (e) {
            printData(title: "Error on completion:", data: e, e: true);
          }
          if (mounted) {
            setState(() {
              _isMePlaying = false;
              _currentPosition = Duration.zero;
            });
          }
          return;
        }
        // Handle Play/Pause
        if (isPlaying && !_isMePlaying) {
          try {
            if (_localWaveform == null || _localWaveform!.isEmpty) {
              _waveController.startPlayer();
            }
            if (mounted) {
              setState(() => _isMePlaying = true);
            }
          } catch (e) {
            printData(title: "Error starting player:", data: e, e: true);
          }
        } else if (!isPlaying && _isMePlaying) {
          try {
            if (_localWaveform == null || _localWaveform!.isEmpty) {
              _waveController.pausePlayer();
            }
            if (mounted) {
              setState(() => _isMePlaying = false);
            }
          } catch (e) {
            printData(title: "Error pausing player:", data: e, e: true);
          }
        }
      },
      onError: (e) {
        printData(title: "PlayerState stream error:", data: e, e: true);
      },
    );

    _playerPositionSub = manager.positionStream.listen(
      (pos) {
        if (!mounted) return;
        // Only update position if it's MY file
        if (VoiceAudioManager.instance.currentPath == widget.path) {
          try {
            if (_localWaveform == null || _localWaveform!.isEmpty) {
              _waveController.seekTo(pos.inMilliseconds);
            }
            if (mounted) {
              setState(() {
                // If the manager reset the position to zero, ensure the visual resets completely
                if (pos.inMilliseconds <= 100 && !_isMePlaying) {
                  _currentPosition = Duration.zero;
                } else {
                  _currentPosition = pos;
                }
              });
            }
          } catch (e) {
            printData(title: "Error seeking position:", data: e, e: true);
          }
        }
      },
      onError: (e) {
        printData(title: "Position stream error:", data: e, e: true);
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
      printData(title: "Toggle error:", data: e, e: true);
    }
  }

  Future<void> _downloadVoice() async {
    Loaders.show();
    try {
      final file = await AudioCacheService.downloadAudioToDevice(widget.path);
      Loaders.hide();
      if (file != null) {
        printData(title: "Downloaded to:", data: file.path);
        showToast(message: "Saved to: Download/printhelper/voice record");
      } else {
        showToast(message: "Failed to download voice message");
      }
    } catch (e) {
      Loaders.hide();
      printData(title: "Download error:", data: e, e: true);
      showToast(message: "Error: ${e.toString()}");
    }
  }

  String _fmt(int sec) =>
      "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xfff1f1f2) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isMe ? Colors.grey[300] : Colors.grey[400],
                ),
                child: widget.isUploading
                    ? Center(
                        child: SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _isReady ? _toggle : null,
                        icon: Icon(
                          _isMePlaying ? Icons.pause : Icons.play_arrow,
                          color: _isReady ? Colors.black : Colors.grey,
                        ),
                      ),
              ),
              Spacers.sbw8(),
              SizedBox(
                width: 150.w,
                height: 32,
                child: _localWaveform != null && _localWaveform!.isNotEmpty
                    ? CustomPaint(
                        painter: _StaticWaveformPainter(
                          waveform: _localWaveform!,
                          progress: widget.duration > 0
                              ? (_currentPosition.inMilliseconds /
                                        (widget.duration * 1000))
                                    .clamp(0.0, 1.0)
                              : 0.0,
                        ),
                      )
                    : AudioFileWaveforms(
                        playerController: _waveController,
                        size: const Size(120, 32),
                        waveformType: WaveformType.fitWidth,
                        playerWaveStyle: PlayerWaveStyle(
                          fixedWaveColor: Colors.black,
                          liveWaveColor: Colors.blueAccent,
                          spacing: 4,
                        ),
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
            padding: EdgeInsets.only(left: 12.w),
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

class _StaticWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;

  _StaticWaveformPainter({required this.waveform, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final activePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final spacing = size.width / waveform.length;
    double maxVal = waveform.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * spacing + (spacing / 2);
      final normalizedHeight = (waveform[i] / maxVal) * size.height;
      final barHeight = normalizedHeight < 2.0 ? 2.0 : normalizedHeight;
      final yOffset = (size.height - barHeight) / 2;

      final paint =
          (progress > 0.0 &&
              progress < 1.0 &&
              (i / waveform.length) <= progress)
          ? activePaint
          : inactivePaint;
      canvas.drawLine(
        Offset(x, yOffset),
        Offset(x, yOffset + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveform != waveform;
  }
}
