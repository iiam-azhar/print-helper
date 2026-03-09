import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:print_helper/tablet_view/lib/tab_utils/console_util.dart';
import 'package:print_helper/constants/colors.dart';

class TabVideoMessageBubbleUI extends StatefulWidget {
  final String videoUrl;
  final int? duration;
  final bool isMe;
  final bool isVideoCallRecording;

  const TabVideoMessageBubbleUI({
    super.key,
    required this.videoUrl,
    this.duration,
    required this.isMe,
    this.isVideoCallRecording = false,
  });

  @override
  State<TabVideoMessageBubbleUI> createState() =>
      _TabVideoMessageBubbleUIState();
}

class _TabVideoMessageBubbleUIState extends State<TabVideoMessageBubbleUI> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // Don't auto-initialize - wait for user to tap play
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || _isInitialized) return;

    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      // Check if URL is valid
      if (widget.videoUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isInitializing = false;
          });
        }
        return;
      }

      // Add delay to ensure platform channels are fully ready
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Determine if the video is a network URL or local file
      if (widget.videoUrl.startsWith('http://') ||
          widget.videoUrl.startsWith('https://')) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        // Local file
        _videoPlayerController = VideoPlayerController.file(
          File(widget.videoUrl),
        );
      }

      // Add error listener before initializing
      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.hasError) {
          printData(
            title: "Video player has error",
            data: _videoPlayerController!.value.errorDescription,
            e: true,
          );
          if (mounted) {
            setState(() {
              _hasError = true;
              _isInitializing = false;
            });
          }
        }
      });

      await _videoPlayerController!.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoInitialize: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading video',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      printData(title: "Video player error", data: e, e: true);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0:00';
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(secs)}';
    }
    return '$minutes:${twoDigits(secs)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 320, maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video player or loading/error state
          if (_hasError)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (_isInitializing)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (!_isInitialized)
            GestureDetector(
              onTap: _initializePlayer,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to play video',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      if (widget.duration != null)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            _formatDuration(widget.duration),
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (_chewieController != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            ),

          // Video info row
          if (_isInitialized && !_hasError)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isVideoCallRecording
                          ? Icons.videocam
                          : Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.isVideoCallRecording
                            ? 'Video call recording'
                            : 'Video',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6),
                    if (widget.duration != null)
                      Text(
                        _formatDuration(widget.duration),
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
