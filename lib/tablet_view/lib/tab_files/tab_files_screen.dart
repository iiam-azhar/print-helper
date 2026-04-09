import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/loaders.dart';
import 'package:provider/provider.dart';
import '../../../services/download_service.dart';
import '../tab_widgets/tab_fab_menu.dart';
import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../models/filefolder_models.dart';
import '../../../providers/files_pro.dart';
import '../../../services/api_routes.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../../../widgets/toasts.dart';
import '../tab_services/helpers.dart';
import '../tab_widgets/tab_share_popup.dart';
import '../tab_widgets/tab_share_chat_popup.dart';
import '../tab_widgets/tab_text_widget.dart' as tab_text;
import '../tab_widgets/tab_email_share_sheet.dart';
import '../tab_widgets/tab_location_picker.dart';
import '../tab_widgets/tab_files_filter.dart';
import '../tab_widgets/tab_item_info.dart';
import 'package:permission_handler/permission_handler.dart';

class TabFilesScreen extends StatefulWidget {
  const TabFilesScreen({super.key, this.onMenuTap, this.onBackHandled});

  final Function(String)? onMenuTap;
  final VoidCallback? onBackHandled;

  @override
  State<TabFilesScreen> createState() => _TabFilesScreenState();
}

class _TabFilesScreenState extends State<TabFilesScreen> {
  final Map<String, GlobalKey> _dotsKeys = {};

  GlobalKey _dotsKey(String itemId) =>
      _dotsKeys.putIfAbsent(itemId, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filesPro = Provider.of<FilesPro>(context, listen: false);
      filesPro.getFiles(ctx: context);
    });
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  bool _isImageType(String type) {
    const imageTypes = {
      'image',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'svg',
    };
    return imageTypes.contains(type.toLowerCase());
  }

  Widget _fileThumbnail(FileModel file, double height) {
    if (file.type == 'psd') {
      return Image.asset(Paths.psd, height: height, fit: BoxFit.contain);
    }

    final resolvedThumbnail = _resolvedLink(file.thumbnail);
    if (resolvedThumbnail.isNotEmpty) {
      return ImageWidget(
        image: resolvedThumbnail,
        height: height,
        fit: BoxFit.cover,
        errorWidget: _buildDocIcon(file, height),
      );
    }

    return _buildDocIcon(file, height);
  }

  Widget _buildDocIcon(FileModel file, double height) {
    final t = file.type.toLowerCase();
    String? iconPath;
    if (t == 'pdf') {
      iconPath = Paths.pdf;
    } else if (t == 'zip' || t == 'rar') {
      iconPath = Paths.zip;
    } else if (t == 'doc' || t == 'docx') {
      iconPath = Paths.docx;
    } else if (t == 'txt') {
      iconPath = Paths.txt;
    }
    if (iconPath != null) {
      return Image.asset(
        iconPath,
        height: height * 0.75,
        fit: BoxFit.contain,
      );
    }
    return Icon(
      Icons.insert_drive_file_rounded,
      size: 48,
      color: Colors.grey.shade400,
    );
  }

  Widget _avatar(String img, double size) {
    if (img.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: ImageWidget(
        image: img,
        height: size,
        width: size,
        fit: BoxFit.cover,
      ),
    );
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _handleFolderTap(FolderModel folder, FilesPro pro) {
    if (pro.isSelecting) {
      pro.toggleSelect(folder.id);
      return;
    }
    if (folder.internalPath.isNotEmpty) {
      pro.getFiles(ctx: context, path: folder.internalPath);
    }
  }

  void _handleFileTap(FileModel file, FilesPro pro) {
    if (pro.isSelecting) {
      pro.toggleSelect(file.id);
      return;
    }
    if (_isImageType(file.type)) {
      _showImageGallery(initialFileId: file.id, allFiles: pro.files);
    }
  }

  // ─── Item Options Menu ───────────────────────────────────────────────────────

  String _resolvedLink(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) {
      final apiUri = Uri.parse(ApiRoutes.baseUrl);
      final origin = apiUri.hasPort
          ? '${apiUri.scheme}://${apiUri.host}:${apiUri.port}'
          : '${apiUri.scheme}://${apiUri.host}';
      return '$origin$v';
    }
    return v;
  }

  Future<void> _handleDownload({
    required bool isFolder,
    required String fileUrl,
    required String itemPath,
    required String itemName,
  }) async {
    final rawLink = fileUrl.isNotEmpty ? fileUrl : itemPath;
    final link = _resolvedLink(rawLink);

    if (link.isEmpty) {
      showToast(message: 'Invalid file link');
      return;
    }

    // Storage permission request
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }

      if (!status.isGranted) {
        showToast(message: 'Storage permission is required for downloads');
        return;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        showToast(message: 'Storage permission is required for downloads');
        return;
      }
    }

    try {
      if (isFolder) {
        await DownloadService.instance.downloadFile(
          url: link,
          fileName: '$itemName.zip',
        );
      } else {
        await DownloadService.instance.downloadFile(
          url: link,
          fileName: itemName,
        );
      }
    } catch (e) {
      debugPrint('Single download error for $itemName: $e');
    }
  }

  Future<void> _handleBulkDownload() async {
    final pro = context.read<FilesPro>();
    final selectedIds = pro.selected.toList();
    if (selectedIds.isEmpty) return;

    // Storage permission request
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      if (!status.isGranted) {
        showToast(message: 'Storage permission is required for downloads');
        return;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        showToast(message: 'Storage permission is required for downloads');
        return;
      }
    }

    showToast(
      message: 'Downloading ${selectedIds.length} items in background...',
    );
    int successCount = 0;

    for (final id in selectedIds) {
      final fileList = pro.files.where((f) => f.id == id).toList();
      final folderList = pro.folders.where((f) => f.id == id).toList();

      final isFile = fileList.isNotEmpty;
      final isFolder = folderList.isNotEmpty;

      if (!isFile && !isFolder) continue;

      try {
        final itemName = isFile
            ? fileList.first.filename
            : folderList.first.title;
        final rawLink = isFile
            ? (fileList.first.storagePath.isNotEmpty
                  ? fileList.first.storagePath
                  : fileList.first.internalPath)
            : folderList.first.internalPath;

        final link = _resolvedLink(rawLink);
        if (link.isEmpty) continue;

        await DownloadService.instance.downloadFile(
          url: link,
          fileName: isFile ? itemName : '$itemName.zip',
        );
        successCount++;
      } catch (e) {
        debugPrint('Bulk download error: $e');
      }
    }

    if (mounted) {
      pro.clearSelection();
      showToast(
        message: successCount > 0
            ? 'Successfully downloaded $successCount items'
            : 'Failed to download items',
      );
    }
  }

  Future<void> _promptRename({
    required String itemId,
    required bool isFolder,
    required String currentName,
  }) async {
    String lockedExtension = '';
    String editableName = currentName;
    if (!isFolder) {
      final dotIndex = currentName.lastIndexOf('.');
      if (dotIndex > 0 && dotIndex < currentName.length - 1) {
        lockedExtension = currentName.substring(dotIndex + 1);
        editableName = currentName.substring(0, dotIndex);
      }
    }
    final controller = TextEditingController(text: editableName);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 0, right: 0),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(0),
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(-4, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                    child: Row(
                      children: [
                        ImageWidget(image: Paths.edit, width: 22, height: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: tab_text.TextWidget(
                            text: isFolder ? 'Rename Folder' : 'Rename File',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: const Icon(
                            Icons.close,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: isFolder
                            ? 'Enter new name'
                            : (lockedExtension.isEmpty
                                  ? 'Enter new name'
                                  : 'Enter name (.$lockedExtension is fixed)'),
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black38),
                        ),
                      ),
                    ),
                  ),
                  // Save button — full width
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.btnClr,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: tab_text.TextWidget(
                          text: 'Save',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (submitted != true || !mounted) return;
    final typedName = controller.text.trim();
    if (typedName.isEmpty) return;
    final newName = (!isFolder && lockedExtension.isNotEmpty)
        ? '$typedName.$lockedExtension'
        : typedName;
    if (newName == currentName.trim()) return;

    await getFilePro(context).renameItem(
      ctx: context,
      itemId: itemId,
      isFolder: isFolder,
      newName: newName,
    );
  }

  Future<void> _showDeleteConfirmation({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 0, right: 0),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  topLeft: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(-4, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                    child: Row(
                      children: [
                        ImageWidget(
                          image: Paths.delete,
                          width: 22,
                          height: 22,
                          color: AppColors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: tab_text.TextWidget(
                            text: title,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: const Icon(
                            Icons.close,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: tab_text.TextWidget(
                      text: message,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  // Footer Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              side: const BorderSide(color: Colors.black12),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: tab_text.TextWidget(
                              text: 'Cancel',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: tab_text.TextWidget(
                              text: 'Delete',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      onConfirm();
    }
  }

  Future<void> _confirmDelete({
    required String itemId,
    required bool isFolder,
    required String itemName,
  }) async {
    await _showDeleteConfirmation(
      title: isFolder ? 'Delete Folder' : 'Delete File',
      message:
          'Are you sure you want to delete "$itemName"? This action cannot be undone.',
      onConfirm: () async {
        await getFilePro(
          context,
        ).deleteItem(ctx: context, itemId: itemId, isFolder: isFolder);
      },
    );
  }

  Future<void> _confirmBulkDelete(FilesPro pro) async {
    final count = pro.selected.length;
    if (count == 0) return;

    await _showDeleteConfirmation(
      title: 'Delete Selected Items',
      message:
          'Are you sure you want to delete these $count selected items? This action cannot be undone.',
      onConfirm: () async {
        await pro.deleteSelectedItems(ctx: context);
      },
    );
  }

  Future<void> _showItemOptions({
    required String itemId,
    required bool isFolder,
    required bool isSystem,
    required String itemName,
    required String itemPath,
    required String fileUrl,
    required GlobalKey dotsKey,
    required double cardWidth,
    required String size,
    required String date,
    required String ownerName,
    required String ownerAvatar,
    String thumbnail = '',
    String fileCount = '0',
  }) async {
    final actions = [
      (
        icon: CupertinoIcons.cloud_download,
        image: null as String?,
        label: 'Download',
        color: Colors.black87,
        weight: FontWeight.w500,
      ),
      (
        icon: Icons.drive_file_move_outlined,
        image: null as String?,
        label: 'Move',
        color: Colors.black87,
        weight: FontWeight.w500,
      ),
      (
        icon: Icons.copy_outlined,
        image: null as String?,
        label: 'Copy',
        color: Colors.black87,
        weight: FontWeight.w500,
      ),
      (
        icon: null as IconData?,
        image: Paths.edit,
        label: 'Rename',
        color: Colors.black87,
        weight: FontWeight.w500,
      ),
      (
        icon: Icons.share_outlined,
        image: null as String?,
        label: 'Share',
        color: Colors.black87,
        weight: FontWeight.w700,
      ),
      (
        icon: CupertinoIcons.info,
        image: null as String?,
        label: 'Info',
        color: const Color(0xFFE9B210),
        weight: FontWeight.w700,
      ),
      (
        icon: null as IconData?,
        image: Paths.delete,
        label: 'Delete',
        color: AppColors.red,
        weight: FontWeight.w500,
      ),
    ];

    final disabledLabels = (isFolder && isSystem)
        ? const {'Download', 'Move', 'Rename', 'Delete'}
        : const <String>{};

    final screenSize = MediaQuery.of(context).size;
    final menuW = cardWidth;
    const menuH = 310.0;

    // Anchor popup to the exact position of the three-dot button
    double left = 8;
    double top = 8;
    final box = dotsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      // Right-align popup with the dots button's right edge so it sits
      // directly below the card (popup right = dots right ≈ card right)
      left = pos.dx + box.size.width - menuW;
      top = pos.dy;
    }
    // Clamp so popup stays on screen
    if (left + menuW > screenSize.width - 8) {
      left = screenSize.width - menuW - 8;
    }
    if (top + menuH > screenSize.height - 8) {
      top = screenSize.height - menuH - 8;
    }
    if (left < 8) left = 8;
    if (top < 8) top = 8;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (sheetCtx) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuW,
                  constraints: BoxConstraints(minWidth: menuW),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Color(0xFFEEEEEE),
                          ),
                        InkWell(
                          onTap: disabledLabels.contains(actions[i].label)
                              ? null
                              : () async {
                                  Navigator.pop(sheetCtx);
                                  if (!mounted) return;
                                  final pro = context.read<FilesPro>();
                                  switch (actions[i].label) {
                                    case 'Download':
                                      await _handleDownload(
                                        isFolder: isFolder,
                                        fileUrl: fileUrl,
                                        itemPath: itemPath,
                                        itemName: itemName,
                                      );
                                      break;
                                    case 'Rename':
                                      await _promptRename(
                                        itemId: itemId,
                                        isFolder: isFolder,
                                        currentName: itemName,
                                      );
                                      break;
                                    case 'Delete':
                                      await _confirmDelete(
                                        itemId: itemId,
                                        isFolder: isFolder,
                                        itemName: itemName,
                                      );
                                      break;
                                    case 'Move':
                                      if (pro.selected.isEmpty) {
                                        pro.toggleSelect(itemId);
                                      }
                                      pro.stageSelectedItemsForMove();
                                      final dest = await TabLocationPicker.show(
                                        context: context,
                                        actionType: 'Move',
                                        items: [],
                                      );
                                      if (dest != null && mounted) {
                                        await pro.executeStagedMove(
                                          ctx: context,
                                          destinationPath: dest,
                                        );
                                      } else {
                                        pro.clearSelection();
                                      }
                                      break;

                                    case 'Copy':
                                      if (pro.selected.isEmpty) {
                                        pro.toggleSelect(itemId);
                                      }
                                      pro.stageSelectedItemsForCopy();
                                      final dest = await TabLocationPicker.show(
                                        context: context,
                                        actionType: 'Copy',
                                        items: [],
                                      );
                                      if (dest != null && mounted) {
                                        await pro.pasteCopiedItems(
                                          ctx: context,
                                          destinationPath: dest,
                                        );
                                      } else {
                                        pro.clearSelection();
                                      }
                                      break;
                                    case 'Info':
                                      if (!mounted) return;
                                      await TabItemInfo.show(
                                        context: context,
                                        title: itemName,
                                        size: size,
                                        location: itemPath,
                                        date: date,
                                        ownerName: ownerName,
                                        ownerAvatar: ownerAvatar,
                                        type: isFolder ? 'folder' : 'image',
                                        thumbnail: thumbnail,
                                        fileCount: fileCount,
                                      );
                                      break;

                                    case 'Share':
                                      if (!mounted) return;
                                      TabSharePopup.show(
                                        context: context,
                                        onEmail: () => _handleShareEmail(
                                          itemName: itemName,
                                          itemPath: itemPath,
                                          isFolder: isFolder,
                                        ),
                                        onChat: () => _handleShareChat(
                                          itemName: itemName,
                                          itemPath: itemPath,
                                          isFolder: isFolder,
                                        ),
                                      );
                                      break;

                                    default:
                                      showToast(
                                        message:
                                            '${actions[i].label} coming soon',
                                      );
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width:
                                      actions[i].label == 'Rename' ||
                                          actions[i].label == 'Delete'
                                      ? 18
                                      : 22,
                                  height:
                                      actions[i].label == 'Rename' ||
                                          actions[i].label == 'Delete'
                                      ? 18
                                      : 22,
                                  child: actions[i].image != null
                                      ? ImageWidget(
                                          image: actions[i].image!,
                                          width:
                                              actions[i].label == 'Rename' ||
                                                  actions[i].label == 'Delete'
                                              ? 18
                                              : 22,
                                          height:
                                              actions[i].label == 'Rename' ||
                                                  actions[i].label == 'Delete'
                                              ? 18
                                              : 22,
                                          color:
                                              disabledLabels.contains(
                                                actions[i].label,
                                              )
                                              ? Colors.black26
                                              : actions[i].label == 'Delete'
                                              ? AppColors.red
                                              : null,
                                        )
                                      : Icon(
                                          actions[i].icon,
                                          size: 20,
                                          color:
                                              disabledLabels.contains(
                                                actions[i].label,
                                              )
                                              ? Colors.black26
                                              : actions[i].color,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                tab_text.TextWidget(
                                  text: actions[i].label,
                                  fontSize: 12,
                                  fontWeight:
                                      disabledLabels.contains(actions[i].label)
                                      ? FontWeight.w400
                                      : actions[i].weight,
                                  color:
                                      disabledLabels.contains(actions[i].label)
                                      ? Colors.black26
                                      : actions[i].color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeaderRow(FilesPro pro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E9EB), width: 1)),
      ),
      child: Row(
        children: [
          ImageWidget(image: Paths.foldr, width: 22),
          const SizedBox(width: 10),
          tab_text.TextWidget(
            text: 'Files',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: tab_text.TextWidget(
              text:
                  '${pro.storageUsed.trim().isEmpty ? '--' : pro.storageUsed} Used / ${pro.storageTotal.trim().isEmpty ? '--' : pro.storageTotal}',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.black45,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  final result = await TabFilesFilter.show(context: context);
                  if (result != null && context.mounted) {
                    if (result.containsKey(TabFilesFilter.clearFiltersKey)) {
                      await pro.getFiles(ctx: context, clearFilters: true);
                    } else {
                      await pro.getFiles(ctx: context, filters: result);
                    }
                  }
                },
                icon: Image.asset(
                  Paths.filter,
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
              if (pro.appliedFilterCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: tab_text.TextWidget(
                        text: pro.appliedFilterCount.toString(),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Breadcrumb + Storage Bar ────────────────────────────────────────────────

  Widget _buildBreadcrumb(FilesPro pro) {
    // Human-readable folder names from API
    var apiSegments = pro.displayPath
        .trim()
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Remove a leading 'home' from API to avoid duplication — we always add it
    if (apiSegments.isNotEmpty && apiSegments.first.toLowerCase() == 'home') {
      apiSegments = apiSegments.sublist(1);
    }

    // 'Home' is always the first visible segment
    final segments = ['Home', ...apiSegments];

    // Build actual nav paths aligned to segments:
    //   segments[0] = 'Home'  → pro.homePath
    //   segments[i] (i>0)     → homePath + i sub-parts from currentPath
    final homePartsCount = pro.homePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .length;
    final allParts = pro.currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final navPaths = <String>[pro.homePath];
    for (int j = 1; j < segments.length; j++) {
      navPaths.add(allParts.take(homePartsCount + j).join('/'));
    }

    final safePercent = (pro.usagePercent.clamp(0.0, 100.0) / 100.0).toDouble();
    final showStorage = pro.storageTotal.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: showStorage ? 5 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCDDE1), width: 1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    tab_text.TextWidget(
                      text: 'Path',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    for (int i = 0; i < segments.length; i++) ...[
                      tab_text.TextWidget(
                        text: '  /  ',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.black38,
                      ),
                      GestureDetector(
                        onTap: i < segments.length - 1
                            ? () =>
                                  pro.getFiles(ctx: context, path: navPaths[i])
                            : null,
                        child: tab_text.TextWidget(
                          text: segments[i],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: i < segments.length - 1
                              ? AppColors.btnClr
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showStorage) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDCDDE1), width: 1),
                ),
                child: Row(
                  children: [
                    tab_text.TextWidget(
                      text: 'Storage',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: safePercent,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE8E9EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE9B210),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    tab_text.TextWidget(
                      text:
                          '${pro.storageUsed.trim().isEmpty ? '--' : pro.storageUsed}  ${pro.storageTotal.trim().isEmpty ? '--' : pro.storageTotal}${pro.usagePercent > 0 ? '  ${pro.usagePercent.toStringAsFixed(1)}%' : ''}',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(FilesPro pro) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBE6), // Light yellow bg
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD540), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD540),
                shape: BoxShape.circle,
              ),
              child: tab_text.TextWidget(
                text: pro.selected.length.toString(),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            const tab_text.TextWidget(
              text: 'item(s) selected',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF58616A),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    final payloadItems = pro.selected
                        .map((id) {
                          final fileIdx = pro.files.indexWhere(
                            (f) => f.id == id,
                          );
                          if (fileIdx >= 0) {
                            return {
                              'type': 'file',
                              'path': pro.files[fileIdx].storagePath,
                              'name': pro.files[fileIdx].filename,
                            };
                          }
                          final folderIdx = pro.folders.indexWhere(
                            (f) => f.id == id,
                          );
                          if (folderIdx >= 0) {
                            return {
                              'type': 'folder',
                              'path': pro.folders[folderIdx].internalPath,
                              'name': pro.folders[folderIdx].title,
                            };
                          }
                          return <String, dynamic>{};
                        })
                        .where((item) => item.isNotEmpty)
                        .toList();
                    TabEmailShareSheet.show(
                      context: context,
                      items: payloadItems,
                    );
                  },
                  icon: Image.asset(
                    Paths.email,
                    width: 23,
                    height: 23,
                    color: Colors.black87,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 5),
                IconButton(
                  onPressed: () async {
                    pro.stageSelectedItemsForCopy();
                    final dest = await TabLocationPicker.show(
                      context: context,
                      actionType: 'Copy',
                      items: [],
                    );
                    if (dest != null && context.mounted) {
                      await pro.pasteCopiedItems(
                        ctx: context,
                        destinationPath: dest,
                      );
                    } else {
                      pro.clearSelection();
                    }
                  },
                  icon: const Icon(
                    Icons.content_copy_outlined,
                    size: 20,
                    color: Colors.black87,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                IconButton(
                  onPressed: () async {
                    pro.stageSelectedItemsForMove();
                    final dest = await TabLocationPicker.show(
                      context: context,
                      actionType: 'Move',
                      items: [],
                    );
                    if (dest != null && context.mounted) {
                      await pro.executeStagedMove(
                        ctx: context,
                        destinationPath: dest,
                      );
                    } else {
                      pro.clearSelection();
                    }
                  },
                  icon: const Icon(
                    Icons.drive_file_move_outlined,
                    size: 23,
                    color: Colors.black87,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                IconButton(
                  onPressed: _handleBulkDownload,
                  icon: const Icon(
                    CupertinoIcons.cloud_download,
                    size: 22,
                    color: Colors.black87,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                IconButton(
                  onPressed: () => _confirmBulkDelete(pro),
                  icon: Image.asset(
                    Paths.delete,
                    width: 18,
                    height: 18,
                    color: AppColors.red,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => pro.clearSelection(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDCDDE1)),
                    ),
                    child: const tab_text.TextWidget(
                      text: 'Clear',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => pro.clearSelection(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const tab_text.TextWidget(
                      text: 'Cancel',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Folder Card ─────────────────────────────────────────────────────────────

  Widget _buildFolderCard(FolderModel folder, FilesPro pro, double cardWidth) {
    final bool selected = pro.selected.contains(folder.id);
    final double folderHeight = cardWidth * 0.72;

    return GestureDetector(
      onLongPress: () => pro.toggleSelect(folder.id),
      onTap: () => _handleFolderTap(folder, pro),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: AppColors.btnClr, width: 2.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                SizedBox(
                  width: cardWidth,
                  height: folderHeight,
                  child: Image.asset(Paths.folder, fit: BoxFit.fill),
                ),
                if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A650),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                if (!selected && pro.isSelecting)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!selected && !pro.isSelecting)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _showItemOptions(
                        itemId: folder.id,
                        isFolder: true,
                        isSystem: folder.isSystem,
                        itemName: folder.title,
                        itemPath: folder.internalPath,
                        fileUrl: folder.storagePath,
                        dotsKey: _dotsKey(folder.id),
                        cardWidth: cardWidth,
                        size: folder.size,
                        date: folder.createdAt,
                        ownerName: folder.ownerName,
                        ownerAvatar: folder.ownerAvatar,
                        fileCount: folder.fileCount.toString(),
                      ),
                      child: Container(
                        key: _dotsKey(folder.id),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.more_vert,
                            size: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            tab_text.TextWidget(
              text: folder.title,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              color: Colors.black87,
              textAlign: TextAlign.center,
            ),
            if (folder.isSystem) ...[
              const SizedBox(height: 3),
              tab_text.TextWidget(
                text: 'System Folder',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFD97706),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── File Card ───────────────────────────────────────────────────────────────

  Widget _buildFileCard(FileModel file, FilesPro pro, double cardWidth) {
    final bool selected = pro.selected.contains(file.id);
    final double thumbHeight = cardWidth * 0.75;
    final String avatar = file.uploadedBy.isNotEmpty
        ? file.uploadedBy.first
        : file.ownerAvatar;

    return GestureDetector(
      onLongPress: () => pro.toggleSelect(file.id),
      onTap: () => _handleFileTap(file, pro),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // color: Colors.white,
          border: selected
              ? Border.all(color: AppColors.btnClr, width: 2.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: cardWidth,
              height: thumbHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFFF5F5F5),
                      child: Center(child: _fileThumbnail(file, thumbHeight)),
                    ),
                  ),

                  // Top-Left Avatar with white border
                  if (avatar.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _avatar(avatar, 28),
                      ),
                    ),
                  // Selection Checkmark
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 10,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A650),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                  if (!selected && pro.isSelecting)
                    Positioned(
                      top: 0,
                      right: 10,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                  // Top-Right Dots Menu
                  if (!selected && !pro.isSelecting)
                    Positioned(
                      top: 0,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _showItemOptions(
                          itemId: file.id,
                          isFolder: false,
                          isSystem: false,
                          itemName: file.filename,
                          itemPath: file.internalPath,
                          fileUrl: file.storagePath,
                          dotsKey: _dotsKey(file.id),
                          cardWidth: cardWidth,
                          size: file.size,
                          date: file.createdAt,
                          ownerName: file.ownerName,
                          ownerAvatar: file.ownerAvatar,
                          thumbnail: file.thumbnail,
                        ),
                        child: Container(
                          key: _dotsKey(file.id),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: tab_text.TextWidget(
                text: file.filename,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                color: Colors.black87,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Upload Queue Tile ────────────────────────────────────────────────────────

  Widget _buildUploadQueueTile(
    Map<String, dynamic> queueItem,
    double cardWidth,
  ) {
    final filePath = (queueItem['path'] ?? '').toString().trim();
    final fileName = (queueItem['name'] ?? '').toString().trim().isEmpty
        ? 'Uploading file...'
        : (queueItem['name'] ?? '').toString().trim();
    final progress = (queueItem['progress'] as num?)?.toDouble() ?? 0;
    final status = (queueItem['status'] ?? '').toString();
    final isFailed = status == 'failed';
    final isDone = status == 'done';
    final canPreview = filePath.isNotEmpty && File(filePath).existsSync();
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    const localPreviewTypes = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};
    final isImagePreview = canPreview && localPreviewTypes.contains(ext);
    final hasPreviewBackground = isImagePreview;
    final progressColor = isFailed
        ? AppColors.red
        : (isDone ? Colors.green : AppColors.primary);
    final statusText = (!isFailed && !isDone)
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : (isDone ? 'Done' : 'Failed');
    final tileHeight = cardWidth * 0.75;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: tileHeight,
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: isFailed
                ? Border.all(
                    color: AppColors.red.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: isImagePreview
                    ? Image.file(
                        File(filePath),
                        width: cardWidth,
                        height: tileHeight,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: cardWidth,
                        height: tileHeight,
                        color: isFailed
                            ? AppColors.red.withValues(alpha: 0.06)
                            : const Color(0xfff1f2f3),
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.doc,
                          size: 44,
                          color: Colors.black45,
                        ),
                      ),
              ),
              if (hasPreviewBackground)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: isFailed ? 0.35 : 0.18,
                    ),
                  ),
                ),
              if (isFailed)
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 28,
                    color: AppColors.red,
                  ),
                )
              else
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    // null = indeterminate spinner until first chunk arrives
                    value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
                    backgroundColor: progress > 0
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              Positioned(
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: tab_text.TextWidget(
                    text: statusText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: tab_text.TextWidget(
            text: fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isFailed) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.read<FilesPro>().retryUpload(ctx: context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      tab_text.TextWidget(
                        text: 'Retry',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.read<FilesPro>().dismissUploadQueue(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0f0f0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 13, color: Colors.black54),
                      SizedBox(width: 3),
                      tab_text.TextWidget(
                        text: 'Dismiss',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── Combined Grid ───────────────────────────────────────────────────────────

  Widget _buildGrid(FilesPro pro) {
    // Upload queue items appear first — mixed into the same grid as folders/files,
    // exactly matching the mobile layout.
    final List<dynamic> items = [
      ...pro.uploadQueue.map((e) => {'type': 'upload_queue', 'data': e}),
      ...pro.folders,
      ...pro.files,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        int cols = 3;
        if (available >= 900) {
          cols = 6;
        } else if (available >= 700) {
          cols = 5;
        } else if (available >= 500) {
          cols = 4;
        }

        const spacing = 16.0;
        final cardWidth = (available - spacing * (cols - 1)) / cols;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is Map && item['type'] == 'upload_queue') {
              return _buildUploadQueueTile(
                item['data'] as Map<String, dynamic>,
                cardWidth,
              );
            }
            if (item is FolderModel) {
              return _buildFolderCard(item, pro, cardWidth);
            }
            return _buildFileCard(item as FileModel, pro, cardWidth);
          },
        );
      },
    );
  }

  // ─── FAB Actions ──────────────────────────────────────────────────────────────

  Future<void> _captureAndUpload(FilesPro pro) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo == null) return;
    if (!mounted) return;
    await pro.uploadFile(
      ctx: context,
      filePaths: [photo.path],
      fileNames: [photo.name],
    );
  }

  Future<void> _pickAndUploadFiles(FilesPro pro) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      final names = result.files
          .where((f) => f.path != null)
          .map((f) => f.name)
          .toList();
      if (paths.isEmpty) return;
      if (!mounted) return;
      await pro.uploadFile(ctx: context, filePaths: paths, fileNames: names);
    } catch (e, st) {
      debugPrint('File Picker Error: $e\n$st');
      if (mounted) {
        showToast(
          message: 'Failed to pick file. Ensure device has enough free space.',
        );
      }
    }
  }

  Future<void> _promptCreateFolder() async {
    final controller = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 0, right: 0),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(-4, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                    child: Row(
                      children: [
                        ImageWidget(image: Paths.edit, width: 22, height: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: tab_text.TextWidget(
                            text: 'New Folder',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: const Icon(
                            Icons.close,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Enter Folder name',
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black38),
                        ),
                      ),
                    ),
                  ),
                  // Save button — full width
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.btnClr,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const tab_text.TextWidget(
                          text: 'Save',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldCreate != true || !mounted) return;

    final folderName = controller.text.trim();
    if (folderName.isEmpty) return;

    final pro = getFilePro(context);
    await pro.createFolder(
      ctx: context,
      name: folderName,
      parentPath: pro.currentPath,
      currentPathOverride: pro.currentPath,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: Consumer<FilesPro>(
        builder: (context, pro, _) {
          if (!pro.canShowFloatingActions) return const SizedBox.shrink();
          return TabFabMenu(
            onUpload: () => _pickAndUploadFiles(pro),
            onNewFolder: _promptCreateFolder,
            onCamera: () => _captureAndUpload(pro),
          );
        },
      ),
      body: Consumer<FilesPro>(
        builder: (context, pro, _) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (pro.canGoBackFolder) {
                widget.onBackHandled?.call();
                await pro.navigateToParentFolder(ctx: context);
              } else if (widget.onMenuTap != null) {
                widget.onBackHandled?.call();
                widget.onMenuTap!("accounts");
              }
            },
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeaderRow(pro),
                  if (pro.isSelecting)
                    _buildSelectionHeader(pro)
                  else
                    _buildBreadcrumb(pro),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Consumer<FilesPro>(
                              builder: (context, pro, _) {
                                return Column(
                                  children: [
                                    if (pro.filesLoad)
                                      SizedBox(
                                        height: 480,
                                        child: Center(child: showLoader()),
                                      )
                                    else if (pro.folders.isEmpty &&
                                        pro.files.isEmpty &&
                                        pro.uploadQueue.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 60,
                                        ),
                                        child: Center(
                                          child: tab_text.TextWidget(
                                            text: 'No files found',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      )
                                    else
                                      _buildGrid(pro),
                                    const SizedBox(height: 80),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<FilesPro>(
        builder: (context, pro, _) => _buildPagination(pro),
      ),
    );
  }

  Future<void> _showImageGallery({
    required String initialFileId,
    required List<FileModel> allFiles,
  }) async {
    final imageFiles = allFiles
        .where(
          (file) => _isImageType(file.type) && file.thumbnail.trim().isNotEmpty,
        )
        .toList();

    if (imageFiles.isEmpty) return;

    var initialIndex = imageFiles.indexWhere(
      (file) => file.id == initialFileId,
    );
    if (initialIndex < 0) initialIndex = 0;

    var currentIndex = initialIndex;
    final pageController = PageController(initialPage: initialIndex);

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: imageFiles.length,
                      onPageChanged: (index) {
                        setState(() {
                          currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final image = imageFiles[index];
                        return Center(
                          child: ImageWidget(
                            image: image.thumbnail,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 48,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: tab_text.TextWidget(
                          text: '${currentIndex + 1}/${imageFiles.length}',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 48,
                    right: 66,
                    child: GestureDetector(
                      onTap: () {
                        final image = imageFiles[currentIndex];
                        _handleDownload(
                          isFolder: false,
                          fileUrl: image.storagePath,
                          itemPath: image.internalPath,
                          itemName: image.filename,
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 48,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    pageController.dispose();
  }

  void _handleShareEmail({
    required String itemName,
    required String itemPath,
    required bool isFolder,
  }) {
    TabEmailShareSheet.show(
      context: context,
      items: [
        {
          'type': isFolder ? 'folder' : 'file',
          'path': itemPath,
          'name': itemName,
        },
      ],
    );
  }

  void _handleShareChat({
    required String itemName,
    required String itemPath,
    required bool isFolder,
  }) {
    TabShareChatPopup.show(
      context: context,
      itemName: itemName,
      itemPath: itemPath,
      isFolder: isFolder,
    );
  }

  Widget _buildPagination(FilesPro provider) {
    if (provider.filesLastPage <= 1) return const SizedBox.shrink();

    final int currentPage = provider.filesCurrentPage;
    final int lastPage = provider.filesLastPage;

    // Generate visible page numbers (1,2,3,...,last)
    List<int> pages = [];

    if (lastPage <= 7) {
      // If few pages, show all
      pages = List.generate(lastPage, (i) => i + 1);
    } else {
      // Many pages → dynamic sliding window with ellipsis
      pages.add(1);

      if (currentPage > 3) pages.add(-1); // -1 = "..."

      int start = (currentPage - 1).clamp(2, lastPage - 2);
      int end = (currentPage + 1).clamp(2, lastPage - 1);

      for (int i = start; i <= end; i++) {
        pages.add(i);
      }

      if (currentPage < lastPage - 2) pages.add(-1); // -1 = "..."

      pages.add(lastPage);
    }

    return SafeArea(
      bottom: true,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// FIRST <<
              _pageCircle(
                label: "«",
                enabled: currentPage > 1,
                onTap: () => provider.getFiles(
                  ctx: context,
                  path: provider.currentPath,
                  page: 1,
                ),
              ),

              /// PREVIOUS <
              _pageCircle(
                label: "<",
                enabled: currentPage > 1,
                onTap: () => provider.getFiles(
                  ctx: context,
                  path: provider.currentPath,
                  page: currentPage - 1,
                ),
              ),

              const SizedBox(width: 8),

              /// PAGE NUMBERS + ELLIPSIS
              ...pages.map((p) {
                if (p == -1) {
                  // ELLIPSIS
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: const Text("...", style: TextStyle(fontSize: 16)),
                  );
                }

                final bool isActive = p == currentPage;

                return GestureDetector(
                  onTap: () {
                    if (!isActive) {
                      provider.getFiles(
                        ctx: context,
                        path: provider.currentPath,
                        page: p,
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.yellow[700] : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      "$p",
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 8),

              /// NEXT >
              _pageCircle(
                label: ">",
                enabled: currentPage < lastPage,
                onTap: () => provider.getFiles(
                  ctx: context,
                  path: provider.currentPath,
                  page: currentPage + 1,
                ),
              ),

              /// LAST >>
              _pageCircle(
                label: "»",
                enabled: currentPage < lastPage,
                onTap: () => provider.getFiles(
                  ctx: context,
                  path: provider.currentPath,
                  page: lastPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget for circle buttons
  Widget _pageCircle({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    IconData? icon;
    if (label == "<") icon = Icons.chevron_left;
    if (label == ">") icon = Icons.chevron_right;
    if (label == "«") icon = Icons.keyboard_double_arrow_left;
    if (label == "»") icon = Icons.keyboard_double_arrow_right;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade200,
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: enabled ? Colors.black : Colors.grey,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? Colors.black : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
