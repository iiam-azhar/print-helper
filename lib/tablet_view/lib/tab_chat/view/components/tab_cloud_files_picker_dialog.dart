import 'package:flutter/material.dart';
import 'package:print_helper/models/filefolder_models.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/files_pro.dart';
import 'package:provider/provider.dart';

import '../../../tab_widgets/loaders.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import '../../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/services/api_routes.dart';

class TabCloudFilesPickerDialog extends StatefulWidget {
  final int? conversationId;
  final int receiverUserId;

  const TabCloudFilesPickerDialog({
    super.key,
    required this.conversationId,
    required this.receiverUserId,
  });

  @override
  State<TabCloudFilesPickerDialog> createState() =>
      _TabCloudFilesPickerDialogState();
}

class _TabCloudFilesPickerDialogState extends State<TabCloudFilesPickerDialog> {
  final List<String> _pathStack = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<FilesPro>(context, listen: false);
      pro.clearSelection();
      pro.getFiles(ctx: context, path: pro.homePath);
    });
  }

  Future<void> _attachSelected() async {
    final pro = Provider.of<FilesPro>(context, listen: false);
    if (!pro.isSelecting) {
      showToast(message: 'Please select items to attach');
      return;
    }

    int? conversationId = widget.conversationId;
    if (conversationId == null || conversationId <= 0) {
      final chatPro = Provider.of<ChatPro>(context, listen: false);
      conversationId = chatPro.findPrivateConversationWithUser(
        widget.receiverUserId,
      );

      if (conversationId == null) {
        final authPro = Provider.of<AuthPro>(context, listen: false);
        Loaders.show();
        conversationId = await chatPro.createConvId(
          type: 'private',
          userIds: [widget.receiverUserId],
          context: context,
        );
        Loaders.hide();

        if (conversationId != null) {
          await chatPro.initConversationSocket(
            conversationId: conversationId,
            currentUserId: authPro.user!.id,
          );
        }
      }
    }

    if (conversationId == null || conversationId <= 0) {
      showToast(message: 'Could not resolve conversation');
      return;
    }

    Loaders.show();
    final success = await pro.shareSelectedToChat(
      conversationId: conversationId,
    );
    Loaders.hide();

    if (success) {
      showToast(message: 'Items attached successfully');
      if (mounted) Navigator.pop(context);
    } else {
      showToast(message: 'Failed to attach items');
    }
  }

  void _openFolder(FolderModel folder) {
    final pro = Provider.of<FilesPro>(context, listen: false);
    _pathStack.add(pro.currentPath);
    pro.getFiles(ctx: context, path: folder.internalPath);
  }

  void _goBack() {
    if (_pathStack.isEmpty) return;
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

  String _resolveUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    String cleanPath = raw;
    if (cleanPath.startsWith('/')) {
      final apiUri = Uri.parse(ApiRoutes.baseUrl);
      final origin = apiUri.hasPort
          ? '${apiUri.scheme}://${apiUri.host}:${apiUri.port}'
          : '${apiUri.scheme}://${apiUri.host}';
      return '$origin$cleanPath';
    }
    return raw;
  }

  Widget _fileThumbnail(FileModel file) {
    final resolvedThumbnail = _resolveUrl(file.thumbnail);
    if (resolvedThumbnail.isNotEmpty) {
      // If it's a doc with thumbnail, show it (API provides thumbnails for PDFs etc.)
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ImageWidget(
          image: resolvedThumbnail,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorWidget: _buildDocIcon(file),
        ),
      );
    }

    return _buildDocIcon(file);
  }

  Widget _buildDocIcon(FileModel file) {
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
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: const TextWidget(
                text: 'Select Files',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            // Navigation and Path
            Consumer<FilesPro>(
              builder: (context, pro, _) {
                final folderName = pro.currentPath.split('/').last;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildBackButton(),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_rounded,
                              color: Color(0xffFFC107),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            TextWidget(
                              text: folderName,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Select All Toggle
            Consumer<FilesPro>(
              builder: (context, pro, _) {
                final allItemsCount = pro.folders.length + pro.files.length;
                final allSelected =
                    allItemsCount > 0 && pro.selected.length == allItemsCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        activeColor: const Color(0xffFFC107),
                        onChanged: (val) {
                          pro.toggleSelectAll(val ?? false);
                        },
                      ),
                      const TextWidget(
                        text: 'Select All',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 24, thickness: 1, color: Color(0xffF1F1F1)),

            // Content Grid
            Expanded(
              child: Consumer<FilesPro>(
                builder: (context, pro, _) {
                  if (pro.filesLoad) {
                    return Center(child: showLoader());
                  }

                  if (pro.folders.isEmpty && pro.files.isEmpty) {
                    return _buildEmptyState();
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 24,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: pro.folders.length + pro.files.length,
                    itemBuilder: (context, index) {
                      if (index < pro.folders.length) {
                        return _buildFolderItem(pro.folders[index], pro);
                      } else {
                        return _buildFileItem(
                          pro.files[index - pro.folders.length],
                          pro,
                        );
                      }
                    },
                  );
                },
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    final canGoBack = _pathStack.isNotEmpty;
    return GestureDetector(
      onTap: canGoBack ? _goBack : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: canGoBack ? const Color(0xffF6F7F9) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffE1E1E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              size: 18,
              color: canGoBack ? Colors.black87 : Colors.grey,
            ),
            const SizedBox(width: 4),
            TextWidget(
              text: 'Back',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: canGoBack ? Colors.black87 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(FolderModel folder, FilesPro pro) {
    final isSelected = pro.selected.contains(folder.id);
    return GestureDetector(
      onTap: () => _openFolder(folder),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffFFC107)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.folder_rounded,
                      color: Color(0xffFFC107),
                      size: 64,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildCheckbox(
                    isSelected,
                    () => pro.toggleSelect(folder.id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextWidget(
            text: folder.title,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileModel file, FilesPro pro) {
    final isSelected = pro.selected.contains(file.id);
    return GestureDetector(
      onTap: () => pro.toggleSelect(file.id),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffFFC107)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(child: _fileThumbnail(file)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildCheckbox(
                    isSelected,
                    () => pro.toggleSelect(file.id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextWidget(
            text: file.filename,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffFFC107) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xffFFC107) : Colors.grey.shade300,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }

  Widget _buildFooter() {
    return Consumer<FilesPro>(
      builder: (context, pro, _) {
        int selectedFiles = 0;
        int selectedFolders = 0;

        for (final id in pro.selected) {
          if (pro.files.any((f) => f.id == id)) selectedFiles++;
          if (pro.folders.any((f) => f.id == id)) selectedFolders++;
        }

        final canAttach = pro.isSelecting;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xffF1F1F1))),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Row(
            children: [
              TextWidget(
                text: '$selectedFiles files, $selectedFolders folders selected',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffF1F3F5),
                  elevation: 0,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const TextWidget(
                  text: 'Cancel',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: canAttach ? _attachSelected : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAttach
                      ? const Color(0xffFFF3C4)
                      : Colors.grey.shade100,
                  elevation: 0,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const TextWidget(
                  text: 'Attach',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          const TextWidget(
            text: 'No items found in this folder',
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
