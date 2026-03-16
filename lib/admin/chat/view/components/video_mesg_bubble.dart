import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/constants/colors.dart';

import '../../../../widgets/loaders.dart';

class VideoMessageBubbleUI extends StatefulWidget {
  final String videoUrl;
  final int? duration;
  final bool isMe;
  final bool isVideoCallRecording;

  const VideoMessageBubbleUI({
    super.key,
    required this.videoUrl,
    this.duration,
    required this.isMe,
    this.isVideoCallRecording = false,
  });

  @override
  State<VideoMessageBubbleUI> createState() => _VideoMessageBubbleUIState();
}

class _VideoMessageBubbleUIState extends State<VideoMessageBubbleUI> {
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
      constraints: BoxConstraints(maxWidth: 280.w, maxHeight: 280.h),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Video player or loading/error state
          Flexible(
            fit: FlexFit.tight,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 200.h, maxHeight: 250.h),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.passthrough,
                  children: [
                    // Background/error/loading/video content
                    if (_hasError)
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48.sp,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Failed to load video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isInitializing)
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: showLoader(color: AppColors.primary),
                        ),
                      )
                    else if (!_isInitialized)
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 64.sp,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tap to play video',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.sp,
                                ),
                              ),
                              if (widget.duration != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Text(
                                    _formatDuration(widget.duration),
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else if (_chewieController != null)
                      AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      )
                    else
                      Container(color: Colors.black),
                    // Tap to play overlay
                    if (!_isInitialized && !_isInitializing && !_hasError)
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _initializePlayer,
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Video info row
          if (_isInitialized && !_hasError)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    widget.isVideoCallRecording
                        ? Icons.videocam
                        : Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      widget.isVideoCallRecording
                          ? 'Video call recording'
                          : 'Video',
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  if (widget.duration != null)
                    Text(
                      _formatDuration(widget.duration),
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
