import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../models/filefolder_models.dart';
import '../../../../providers/auth_pro.dart';
import '../../../../providers/files_pro.dart';
import '../../../../widgets/image_widget.dart';
import '../../../../widgets/loaders.dart';
import '../../../../widgets/text_widget.dart';
import '../../../../widgets/toasts.dart';
import '../../provider/chat_pro.dart';

/// Bottom sheet that shows the cloud files section for attaching to chat.
class CloudFilesPickerSheet extends StatefulWidget {
  final int? conversationId;
  final int receiverUserId;

  const CloudFilesPickerSheet({
    super.key,
    required this.conversationId,
    required this.receiverUserId,
  });

  @override
  State<CloudFilesPickerSheet> createState() => _CloudFilesPickerSheetState();
}

class _CloudFilesPickerSheetState extends State<CloudFilesPickerSheet> {
  final List<String> _pathStack = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<FilesPro>(context, listen: false);
      pro.getFiles(ctx: context, path: pro.homePath);
    });
  }

  Future<void> _shareFile(FileModel file) async {
    final pro = Provider.of<FilesPro>(context, listen: false);
    Navigator.pop(context);

    int? conversationId = widget.conversationId;

    // If no conversationId, resolve or create one
    if (conversationId == null) {
      final chatPro = Provider.of<ChatPro>(context, listen: false);
      conversationId = chatPro.findPrivateConversationWithUser(
        widget.receiverUserId,
      );
      if (conversationId == null) {
        final authPro = Provider.of<AuthPro>(context, listen: false);
        conversationId = await chatPro.createConvId(
          type: 'private',
          userIds: [widget.receiverUserId],
          context: context,
        );
        if (conversationId != null) {
          await chatPro.initConversationSocket(
            conversationId: conversationId,
            currentUserId: authPro.user!.id,
          );
        }
      }
    }

    if (conversationId == null) {
      showToast(message: 'Could not resolve conversation');
      return;
    }

    Loaders.show();
    final success = await pro.shareItemToChat(
      conversationId: conversationId,
      itemPath: file.internalPath.isNotEmpty
          ? file.internalPath
          : file.storagePath,
      itemName: file.filename,
      isFolder: false,
    );
    Loaders.hide();

    if (success) {
      showToast(message: 'File shared successfully');
    } else {
      showToast(message: 'Failed to share file');
    }
  }

  void _openFolder(FolderModel folder) {
    final pro = Provider.of<FilesPro>(context, listen: false);
    _pathStack.add(pro.currentPath);
    pro.getFiles(ctx: context, path: folder.internalPath);
  }

  void _goBack() {
    if (_pathStack.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final pro = Provider.of<FilesPro>(context, listen: false);
    final prev = _pathStack.removeLast();
    pro.getFiles(ctx: context, path: prev);
  }

  bool _isImageFile(String type) =>
      type == 'jpg' ||
      type == 'jpeg' ||
      type == 'png' ||
      type == 'webp' ||
      type == 'gif';

  Widget _fileThumbnail(FileModel file) {
    if (_isImageFile(file.type) && file.thumbnail.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: ImageWidget(
          image: file.thumbnail,
          width: 44.w,
          height: 44.w,
          fit: BoxFit.cover,
        ),
      );
    }
    IconData icon = Icons.insert_drive_file_rounded;
    Color color = Colors.grey;
    if (file.type == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red.shade700;
    } else if (file.type == 'doc' || file.type == 'docx') {
      icon = Icons.description_rounded;
      color = Colors.blue.shade700;
    } else if (file.type == 'xls' || file.type == 'xlsx') {
      icon = Icons.table_chart_rounded;
      color = Colors.green.shade700;
    } else if (file.type == 'zip' || file.type == 'rar') {
      icon = Icons.folder_zip_rounded;
      color = Colors.orange.shade700;
    } else if (_isImageFile(file.type)) {
      icon = Icons.image_rounded;
      color = Colors.purple.shade700;
    }
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: color, size: 22.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
            child: Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xffd9d9d9),
                borderRadius: BorderRadius.circular(100.r),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _goBack,
                  child: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
                SizedBox(width: 10.w),
                const Expanded(
                  child: TextWidget(
                    text: 'Cloud Files',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // File list
          Expanded(
            child: Consumer<FilesPro>(
              builder: (context, pro, _) {
                if (pro.filesLoad) {
                  return Center(child: showLoader());
                }
                final items = <Widget>[];

                // Folders
                for (final folder in pro.folders) {
                  items.add(
                    ListTile(
                      leading: Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF3C4),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          color: const Color(0xffFFC107),
                          size: 22.sp,
                        ),
                      ),
                      title: TextWidget(
                        text: folder.title,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openFolder(folder),
                    ),
                  );
                }

                // Files
                for (final file in pro.files) {
                  items.add(
                    ListTile(
                      leading: _fileThumbnail(file),
                      title: TextWidget(
                        text: file.filename,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: TextWidget(
                        text: file.size,
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                      trailing: GestureDetector(
                        onTap: () => _shareFile(file),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFC107),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: const TextWidget(
                            text: 'Send',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onTap: () => _shareFile(file),
                    ),
                  );
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48.sp,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 12.h),
                        const TextWidget(
                          text: 'No files found',
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.only(bottom: 20.h),
                  children: items,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
