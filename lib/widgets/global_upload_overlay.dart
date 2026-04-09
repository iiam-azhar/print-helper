import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/files_pro.dart';
import '../widgets/text_widget.dart';

import 'tablet_upload_overlay.dart';

class GlobalUploadOverlay extends StatefulWidget {
  const GlobalUploadOverlay({super.key});

  @override
  State<GlobalUploadOverlay> createState() => _GlobalUploadOverlayState();
}

class _GlobalUploadOverlayState extends State<GlobalUploadOverlay> {
  bool _isMinimized = false;

  bool _isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= 600;
  }

  @override
  Widget build(BuildContext context) {
    if (_isTablet(context)) {
      return const TabletUploadOverlay();
    }

    return Consumer<FilesPro>(
      builder: (context, pro, _) {
        if (!pro.uploadInProgress && pro.uploadQueue.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDone = pro.uploadQueue.every((q) => q['status'] == 'done');
        final hasError = pro.uploadQueue.any((q) => q['status'] == 'failed');
        
        if (isDone && !_isMinimized) {
          // Auto-hide success after some time could be added, but for now, 
          // let the user dismiss it.
        }

        return Positioned(
          bottom: 16.h,
          left: 16.w,
          right: 16.w,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasError ? Colors.red.withValues(alpha: 0.2) : Colors.black12,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: hasError 
                            ? Colors.red.withValues(alpha: 0.1) 
                            : AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasError 
                            ? Icons.error_outline 
                            : (isDone ? Icons.check_circle_outline : Icons.cloud_upload_outlined),
                          size: 20.sp,
                          color: hasError ? Colors.red : AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: _getStatusText(pro, isDone, hasError),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            if (!isDone && !hasError)
                              TextWidget(
                                text: pro.currentUploadFileName.isNotEmpty 
                                  ? 'Uploading ${pro.currentUploadFileName}'
                                  : 'Preparing...',
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.black54,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (hasError)
                        TextButton(
                          onPressed: () => pro.retryUpload(ctx: context),
                          child: const Text('Retry'),
                        ),
                      IconButton(
                        onPressed: () {
                          if (isDone || hasError) {
                            pro.dismissUploadQueue();
                          } else {
                            setState(() => _isMinimized = !_isMinimized);
                          }
                        },
                        icon: Icon(
                          (isDone || hasError) ? Icons.close : (_isMinimized ? Icons.expand_less : Icons.expand_more),
                          size: 20.sp,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  if (!_isMinimized && !isDone && !hasError) ...[
                    SizedBox(height: 12.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: pro.uploadProgress,
                        backgroundColor: Colors.black.withValues(alpha: 0.05),
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 6.h,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextWidget(
                          text: '${(pro.uploadProgress * 100).toInt()}% complete',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Colors.black45,
                        ),
                        TextWidget(
                          text: '${pro.uploadQueue.where((q) => q['status'] == 'done').length}/${pro.uploadQueue.length} files',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(FilesPro pro, bool isDone, bool hasError) {
    if (hasError) return 'Upload Failed';
    if (isDone) return 'Upload Complete';
    return 'Uploading Files...';
  }
}
