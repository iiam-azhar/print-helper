import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/colors.dart';
import '../../../../constants/paths.dart';
import '../../../../widgets/image_widget.dart';
import '../../../../widgets/text_widget.dart';
import '../../models/chat_models.dart';

class ProjectChatPebble extends StatelessWidget {
  final ChatSystemCard card;
  final bool isMe;
  final String metaText;
  final IconData statusIcon;
  final Color statusColor;
  final VoidCallback? onAttachmentTap;

  const ProjectChatPebble({
    super.key,
    required this.card,
    required this.isMe,
    required this.metaText,
    required this.statusIcon,
    required this.statusColor,
    this.onAttachmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final attachmentItems = card.attachmentItems;
    final allFiles = <String>{...card.files, ...card.attachments}.toList();
    final primaryAttachment =
        attachmentItems.isNotEmpty ? attachmentItems.first : null;
    final primaryName =
        primaryAttachment != null && primaryAttachment.name.trim().isNotEmpty
            ? primaryAttachment.name.trim()
            : (allFiles.isNotEmpty ? allFiles.first : '');
    final primaryPreviewUrl =
        (primaryAttachment?.url.trim().isNotEmpty ?? false)
            ? primaryAttachment!.url.trim()
            : null;
    final primaryMime = primaryAttachment?.mime.trim().toLowerCase() ?? '';
    final isPreviewMedia =
        primaryPreviewUrl != null &&
        (primaryMime.startsWith('image/') ||
            primaryMime.startsWith('video/') ||
            _isImageByName(primaryName));
    final hasFile = allFiles.isNotEmpty;
    final hasComment = (card.comment ?? '').trim().isNotEmpty;
    final hasTask = (card.task ?? '').trim().isNotEmpty;
    final hasProject = (card.project ?? '').trim().isNotEmpty;
    final event = card.event.trim();

    final isProjectCreatedOnly =
        event.toLowerCase() == 'project created' &&
        hasProject &&
        !hasComment &&
        !hasTask &&
        !hasFile;
    final showProjectUnderEventHeader =
        hasProject && !hasComment && !hasTask && !hasFile;

    final bgColor = isMe ? Colors.white : AppColors.primary;
    final eventFontSize = isProjectCreatedOnly ? 12.8 : 13.5;
    final eventFontWeight =
        isProjectCreatedOnly ? FontWeight.w600 : FontWeight.w700;
    final projectTitleFontSize = isProjectCreatedOnly ? 15.0 : 13.5;
    final projectTitleFontWeight =
        isProjectCreatedOnly ? FontWeight.w700 : FontWeight.w700;
    final metaFontSize = isProjectCreatedOnly ? 10.2 : 9.5;
    final metaColor =
        isProjectCreatedOnly ? const Color(0xFF1E1E1E) : Colors.black54;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasFile) ...[
            GestureDetector(
              onTap: onAttachmentTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ...List.generate(
                        allFiles.length > 3 ? 3 : allFiles.length,
                        (index) {
                          final item = index < attachmentItems.length
                              ? attachmentItems[index]
                              : null;
                          final name = item?.name ?? allFiles[index];
                          final url = item?.url;
                          final mime = item?.mime.toLowerCase() ?? '';
                          final isImg = url != null &&
                              (mime.startsWith('image/') ||
                                  mime.startsWith('video/') ||
                                  _isImageByName(name));

                          return Padding(
                            padding: EdgeInsets.only(
                              right: 6.w,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: isImg
                                  ? ImageWidget(
                                      image: url,
                                      width: 66.w,
                                      height: 66.w,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 66.w,
                                      height: 66.w,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                      child: Center(
                                        child: ImageWidget(
                                          image: _fileIconPath(name),
                                          width: 36.w,
                                          height: 36.w,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      if (allFiles.length > 3)
                        Padding(
                          padding: EdgeInsets.only(left: 2.w),
                          child: TextWidget(
                            text: "+${allFiles.length - 3}",
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  TextWidget(
                    text: allFiles.length == 1
                        ? _formatAttachmentName(allFiles.first)
                        : "${allFiles.length} files",
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
          ],
          if (event.isNotEmpty && !hasFile) ...[
            TextWidget(
              text: '$event:',
              fontSize: eventFontSize,
              fontWeight: eventFontWeight,
              color: Colors.black,
            ),
            if (showProjectUnderEventHeader)
              TextWidget(
                text: card.project!.trim(),
                fontSize: projectTitleFontSize,
                fontWeight: projectTitleFontWeight,
                color: Colors.black,
              ),
            SizedBox(height: isProjectCreatedOnly ? 4.h : 7.h),
          ],
          if (hasComment) ...[
            TextWidget(
              text: 'Comment:',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            SizedBox(height: 1.h),
            TextWidget(
              text: card.comment!.trim(),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            SizedBox(height: 9.h),
          ],
          if (hasTask) ...[
            TextWidget(
              text: 'Task:',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            SizedBox(height: 1.h),
            TextWidget(
              text: card.task!.trim(),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            SizedBox(height: 7.h),
          ],
          if (hasProject && (hasFile || hasComment || hasTask)) ...[
            TextWidget(
              text: 'Project:',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            SizedBox(height: 1.h),
            TextWidget(
              text: card.project!.trim(),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ],
          if (!hasFile &&
              event.isEmpty &&
              !hasComment &&
              !hasTask &&
              !hasProject)
            TextWidget(
              text: card.text.trim().isEmpty ? 'Project update' : card.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: TextWidget(
                  text: metaText,
                  fontSize: metaFontSize,
                  color: metaColor,
                  fontWeight: FontWeight.w400,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMe) ...[
                SizedBox(width: 5.w),
                Icon(statusIcon, size: 14.sp, color: statusColor),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fileIconPath(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.psd')) return Paths.psd;
    if (lower.endsWith('.pdf')) return Paths.pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Paths.docx;
    if (lower.endsWith('.txt')) return Paths.txt;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Paths.zip;
    return Paths.foldr;
  }

  bool _isImageByName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _formatAttachmentName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final dot = value.lastIndexOf('.');
    final hasExt = dot > 0 && dot < value.length - 1;
    final ext = hasExt ? value.substring(dot) : '';
    final base = hasExt ? value.substring(0, dot) : value;
    if (base.length <= 8) return value;

    final first = base.substring(0, 4);
    final last = base.substring(base.length - 4);
    return '$first.....$last$ext';
  }
}
