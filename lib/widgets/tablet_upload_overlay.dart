import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/files_pro.dart';

class TabletUploadOverlay extends StatefulWidget {
  const TabletUploadOverlay({super.key});

  @override
  State<TabletUploadOverlay> createState() => _TabletUploadOverlayState();
}

class _TabletUploadOverlayState extends State<TabletUploadOverlay> {
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FilesPro>(
      builder: (context, pro, _) {
        if (!pro.uploadInProgress && pro.uploadQueue.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDone = pro.uploadQueue.every((q) => q['status'] == 'done');
        final hasError = pro.uploadQueue.any((q) => q['status'] == 'failed');

        return Positioned(
          bottom: 24,
          right: 24,
          width: 380, // Fixed width for tablet
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        padding: const EdgeInsets.all(8),
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
                          size: 20,
                          color: hasError ? Colors.red : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusText(pro, isDone, hasError),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            if (!isDone && !hasError)
                              Text(
                                pro.currentUploadFileName.isNotEmpty 
                                  ? 'Uploading ${pro.currentUploadFileName}'
                                  : 'Preparing...',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black54,
                                ),
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
                          size: 20,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  if (!_isMinimized && !isDone && !hasError) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pro.uploadProgress,
                        backgroundColor: Colors.black.withValues(alpha: 0.05),
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(pro.uploadProgress * 100).toInt()}% complete',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.black45,
                          ),
                        ),
                        Text(
                          '${pro.uploadQueue.where((q) => q['status'] == 'done').length}/${pro.uploadQueue.length} files',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.black45,
                          ),
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
