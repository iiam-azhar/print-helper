import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/Files/components/fab.dart';
import 'package:print_helper/Files/components/filter_sheet.dart';
import 'package:print_helper/providers/files_pro.dart';
import '../../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import 'package:print_helper/models/filefolder_models.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_custom_prompts.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_toasts.dart';
import 'components/file_info.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Future<void> _promptCreateFolderInPicker({
    required BuildContext dialogContext,
    required FilesPro filesPro,
  }) async {
    final controller = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.fromLTRB(0, 86, 0, 0),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.folder,
                        size: 24,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: TextWidget(
                          text: 'New Folder',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Folder Name',
                      hintStyle: const TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18, top: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.btnClr,
                      minimumSize: const Size(92, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const TextWidget(
                      text: 'Save',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldCreate != true) return;

    final folderName = controller.text.trim();
    if (folderName.isEmpty) return;

    await filesPro.createFolder(
      ctx: dialogContext,
      name: folderName,
      parentPath: filesPro.currentPath,
      currentPathOverride: filesPro.currentPath,
    );
  }

  Future<String?> _pickDestination({
    required String title,
    required String confirmLabel,
  }) async {
    final pro = getFilePro(context);
    final originPath = pro.currentPath;

    await pro.getFiles(ctx: context, path: pro.homePath);
    if (!mounted) return null;

    final selectedPath = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.86,
            child: Consumer<FilesPro>(
              builder: (sheetContext, filesPro, _) {
                final List<dynamic> combined = [
                  ...filesPro.folders.map((e) => {'type': 'folder', 'data': e}),
                  ...filesPro.files.map((e) => {'type': 'file', 'data': e}),
                ];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          if (filesPro.currentPath != filesPro.homePath)
                            IconButton(
                              onPressed: () {
                                filesPro.navigateToParentFolder(ctx: sheetCtx);
                              },
                              icon: const Icon(Icons.arrow_back_ios_new),
                            )
                          else
                            const SizedBox(width: 40),
                          Expanded(
                            child: TextWidget(
                              text: title,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (filesPro.canShowFloatingActions)
                            IconButton(
                              onPressed: () {
                                _promptCreateFolderInPicker(
                                  dialogContext: sheetCtx,
                                  filesPro: filesPro,
                                );
                              },
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: TextWidget(
                          text: 'Path: ${filesPro.displayPath}',
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Spacers.sb10(),
                    Expanded(
                      child: filesPro.filesLoad
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: combined.length,
                              itemBuilder: (context, index) {
                                final item = combined[index];
                                if (item['type'] == 'folder') {
                                  final folder = item['data'] as FolderModel;
                                  return GestureDetector(
                                    onTap: () {
                                      if (folder.internalPath.isNotEmpty) {
                                        filesPro.getFiles(
                                          ctx: sheetCtx,
                                          path: folder.internalPath,
                                        );
                                      }
                                    },
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: 120,
                                          width: 160,
                                          child: ImageWidget(
                                            image: Paths.folder,
                                            height: 108,
                                          ),
                                        ),
                                        Spacers.sb8(),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: TextWidget(
                                            text: folder.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final file = item['data'] as FileModel;
                                return Opacity(
                                  opacity: 0.6,
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 120,
                                        width: 160,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: _fileThumbnail(file),
                                      ),
                                      Spacers.sb8(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: TextWidget(
                                          text: file.filename,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black26),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(sheetCtx, filesPro.currentPath),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(confirmLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (mounted) {
      await pro.getFiles(ctx: context, path: originPath);
    }

    return selectedPath;
  }

  Future<void> _copySelection() async {
    final pro = getFilePro(context);
    final copiedCount = pro.stageSelectedItemsForCopy();
    if (copiedCount == 0) return;

    final destination = await _pickDestination(
      title: 'Choose Location',
      confirmLabel: 'Select',
    );
    if (destination == null || !mounted) {
      pro.clearCopiedItems();
      return;
    }

    await pro.pasteCopiedItems(ctx: context, destinationPath: destination);
  }

  Future<void> _moveSelection() async {
    final pro = getFilePro(context);
    final movedCount = pro.stageSelectedItemsForMove();
    if (movedCount == 0) return;

    final destination = await _pickDestination(
      title: 'Select Destination',
      confirmLabel: 'Move',
    );
    if (destination == null || !mounted) {
      pro.clearMovedItems();
      return;
    }

    await pro.executeStagedMove(ctx: context, destinationPath: destination);
  }

  Future<void> _deleteSelection() async {
    final pro = getFilePro(context);
    final selectedCount = pro.selected.length;
    if (selectedCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.delete_solid,
                    color: AppColors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 16),
                const TextWidget(
                  text: 'Delete Selected',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                const SizedBox(height: 8),
                TextWidget(
                  text:
                      'Are you sure you want to delete $selectedCount selected item${selectedCount == 1 ? '' : 's'}?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: const Color(0xfff5f5f5),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await pro.deleteSelectedItems(ctx: context);
  }

  Future<void> _promptCreateFolder() async {
    final controller = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.fromLTRB(0, 86, 0, 0),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.folder,
                        size: 24,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: TextWidget(
                          text: 'New Folder',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Folder Name',
                      hintStyle: const TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18, top: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.btnClr,
                      minimumSize: const Size(92, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const TextWidget(
                      text: 'Save',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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

  Future<void> _showSharePopup({
    String itemName = '',
    String fileUrl = '',
    String itemPath = '',
    bool isFolder = false,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              color: const Color(0xfff5f6f8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'Share',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                const TextWidget(
                  text:
                      'Choose where you want to share this item now. More apps can be added here later.',
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff6f7785),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Future<void>.delayed(
                            const Duration(milliseconds: 120),
                          );
                          if (!mounted) return;
                          _showShareToEmailSheet(
                            itemName: itemName,
                            fileUrl: fileUrl,
                            itemPath: itemPath,
                            isFolder: isFolder,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffcfd4dc)),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff1f3f7),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  CupertinoIcons.mail,
                                  size: 20,
                                  color: Color(0xff4e596c),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: 'Email',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(height: 2),
                                    TextWidget(
                                      text: 'Send via email',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xff6f7785),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showShareToChatSheet(
                            itemName: itemName,
                            fileUrl: fileUrl,
                            itemPath: itemPath,
                            isFolder: isFolder,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.secondary),
                            color: const Color(0xfffffbea),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff3e275),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  CupertinoIcons.chat_bubble_2,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: 'Chat',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(height: 2),
                                    TextWidget(
                                      text: 'Share to conversation',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xff6f7785),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShareToEmailSheet({
    String itemName = '',
    String fileUrl = '',
    String itemPath = '',
    bool isFolder = false,
  }) async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final manualEmailController = TextEditingController();
    final sentToController = TextEditingController();
    final List<String> recipients = [];

    void addRecipient(StateSetter setModalState, String rawValue) {
      final value = rawValue.trim();
      if (value.isEmpty) return;
      final alreadyExists = recipients.any(
        (existing) => existing.toLowerCase() == value.toLowerCase(),
      );
      if (alreadyExists) return;
      setModalState(() {
        recipients.add(value);
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.90,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.mail_solid,
                            size: 21,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: TextWidget(
                              text: 'Email File(s)',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TextWidget(
                              text: 'Subject',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: subjectController,
                              decoration: InputDecoration(
                                hintText: 'Type subject',
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 14,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black26,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TextWidget(
                              text: 'Message',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: messageController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Type message',
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 14,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black26,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TextWidget(
                              text: 'Select reply to email',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffdce89c),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      children: [
                                        _avatar(Paths.user, 20),
                                        const SizedBox(width: 6),
                                        const TextWidget(
                                          text: 'System Admin',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const TextWidget(
                                            text: 'Admin',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          CupertinoIcons.delete,
                                          size: 13,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TextWidget(
                              text: 'Select sent to email',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: sentToController,
                              decoration: InputDecoration(
                                hintText: 'Select Email Recipients',
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 14,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                suffixIcon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.black54,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black26,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TextWidget(
                              text: 'Select email',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      0,
                                    ),
                                    child: TextWidget(
                                      text: 'Add recipient email manually.',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      12,
                                    ),
                                    child: TextField(
                                      controller: manualEmailController,
                                      onSubmitted: (value) {
                                        addRecipient(setModalState, value);
                                        manualEmailController.clear();
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Type email and press Enter',
                                        hintStyle: const TextStyle(
                                          color: Colors.black38,
                                          fontSize: 14,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 11,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black12,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black26,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (recipients.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        10,
                                      ),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: recipients
                                            .map(
                                              (email) => Chip(
                                                label: Text(email),
                                                deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                                onDeleted: () {
                                                  setModalState(() {
                                                    recipients.remove(email);
                                                  });
                                                },
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.black12,
                                          ),
                                        ),
                                      ),
                                      child: const TextWidget(
                                        text:
                                            'No suggested emails. You can add manually above.',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black38,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                side: const BorderSide(color: Colors.black26),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const TextWidget(
                                text: 'Cancel',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final typedRecipient = manualEmailController
                                    .text
                                    .trim();
                                if (typedRecipient.isNotEmpty) {
                                  addRecipient(setModalState, typedRecipient);
                                  manualEmailController.clear();
                                }

                                if (recipients.isEmpty &&
                                    sentToController.text.trim().isEmpty) {
                                  showToast(
                                    message:
                                        'Please add at least one email recipient',
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);
                                showToast(
                                  message:
                                      'Email share prepared for ${itemName.isEmpty ? (isFolder ? 'folder' : 'file') : itemName}',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                minimumSize: const Size(0, 42),
                                backgroundColor: AppColors.btnClr,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const TextWidget(
                                text: 'Share',
                                fontSize: 16,
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
            );
          },
        );
      },
    );

    subjectController.dispose();
    messageController.dispose();
    manualEmailController.dispose();
    sentToController.dispose();
  }

  Future<void> _showShareToChatSheet({
    String itemName = '',
    String fileUrl = '',
    String itemPath = '',
    bool isFolder = false,
  }) async {
    final chatPro = getChatPro(context);
    final filesPro = getFilePro(context);
    final searchCtrl = TextEditingController();

    Future<bool> sendToConversation({
      required ChatPro pro,
      int? conversationId,
      int? userId,
      required String conversationTitle,
    }) async {
      Loaders.show();
      final success = await filesPro.shareItemToChat(
        conversationId: conversationId,
        userId: userId,
        itemPath: itemPath,
        itemName: itemName,
        isFolder: isFolder,
      );
      Loaders.hide();

      if (!success) {
        showToast(message: 'Failed to share to $conversationTitle');
        return false;
      }
      showToast(message: 'Shared to $conversationTitle');
      return true;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xfff1f1f2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: chatPro.onSearchGlobalChanged,
                        decoration: const InputDecoration(
                          hintText: 'Find People or Groups',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Expanded(
                child: Consumer<ChatPro>(
                  builder: (context, pro, _) {
                    if (pro.searchResults.isNotEmpty) {
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: pro.searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xffe6e7e6)),
                        itemBuilder: (context, index) {
                          final user = pro.searchResults[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: ImageWidget(
                                image: user.image?.isNotEmpty == true
                                    ? user.image!
                                    : Paths.user,
                                height: 40,
                                width: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: TextWidget(
                              text: '${user.name} ${user.lastName}',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            onTap: () async {
                              final sent = await sendToConversation(
                                pro: pro,
                                userId: user.id,
                                conversationTitle: user.name,
                              );
                              if (mounted && sent) {
                                Navigator.pop(ctx);
                              }
                            },
                          );
                        },
                      );
                    }
                    if (pro.conversations.isEmpty) {
                      return Center(
                        child: TextWidget(
                          text: 'No conversations found',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: pro.conversations.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xffe6e7e6)),
                      itemBuilder: (context, index) {
                        final chat = pro.conversations[index];
                        return ListTile(
                          leading: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: const Color(0xffe6e7e6),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: ImageWidget(
                                image: chat.image.isNotEmpty
                                    ? chat.image
                                    : Paths.user,
                                height: 40,
                                width: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: TextWidget(
                            text: chat.title,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          onTap: () async {
                            final sent = await sendToConversation(
                              pro: pro,
                              conversationId: chat.id,
                              conversationTitle: chat.title,
                            );
                            if (mounted && sent) {
                              Navigator.pop(ctx);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    searchCtrl.dispose();
    chatPro.clearUserSearch();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filesPro = getFilePro(context);
      filesPro.getFiles(ctx: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final pro = getFilePro(context);
        final handled = await pro.navigateToParentFolder(ctx: context);
        return !handled;
      },
      child: Scaffold(
        floatingActionButton: Consumer<FilesPro>(
          builder: (context, pro, _) {
            if (!pro.canShowFloatingActions) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: FabMenu(
                onUpload: () {},
                onNewFolder: _promptCreateFolder,
                onCamera: () {},
              ),
            );
          },
        ),
        appBar: _appBar(),
        body: Stack(
          children: [
            IgnorePointer(
              ignoring: true,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.asset(
                  Paths.chatbg,
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(.3),
                ),
              ),
            ),
            SafeArea(
              child: Consumer<FilesPro>(
                builder: (context, pro, child) {
                  if (pro.filesLoad) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<dynamic> combined = [
                    ...pro.folders.map((e) => {"type": "folder", "data": e}),
                    ...pro.files.map((e) => {"type": "file", "data": e}),
                  ];
                  return RefreshIndicator(
                    onRefresh: () =>
                        pro.getFiles(ctx: context, path: pro.currentPath),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: "Path: ${pro.displayPath}",
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                          Spacers.sb15(),
                          if (combined.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 30),
                              child: TextWidget(
                                text: "No files or folders",
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: combined.length,
                              itemBuilder: (context, i) {
                                final item = combined[i];
                                if (item["type"] == "folder") {
                                  return _folderTile(item["data"]);
                                } else {
                                  return _fileTile(item["data"]);
                                }
                              },
                            ),
                          Spacers.sb20(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: Consumer<FilesPro>(
        builder: (context, pro, _) {
          return Row(
            children: [
              const Icon(CupertinoIcons.folder, size: 25),
              const SizedBox(width: 12),
              const TextWidget(
                text: "Files",
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ],
          );
        },
      ),
      actions: [
        Consumer<FilesPro>(
          builder: (context, pro, _) {
            return pro.isSelecting
                ? Row(
                    children: [
                      IconButton(
                        onPressed: _showSharePopup,
                        icon: const Icon(CupertinoIcons.cloud_upload),
                      ),
                      IconButton(
                        onPressed: _copySelection,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      IconButton(
                        onPressed: _moveSelection,
                        icon: const Icon(Icons.drive_file_move_outlined),
                      ),
                      IconButton(
                        onPressed: _deleteSelection,
                        icon: const Icon(CupertinoIcons.delete),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (pro.currentPath != pro.homePath)
                        IconButton(
                          onPressed: () {
                            pro.getFiles(ctx: context, path: pro.homePath);
                          },
                          icon: const Icon(Icons.home_outlined),
                        ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final result =
                                  await CustomPrompts.showBottomSheet<
                                    Map<String, dynamic>
                                  >(
                                    ctx: context,
                                    bgColor: AppColors.tr,
                                    child: const FilterFilesSheet(),
                                  );

                              if (result == null) return;

                              final clear =
                                  result[FilterFilesSheet.clearFiltersKey] ==
                                  true;
                              if (clear) {
                                await pro.getFiles(
                                  ctx: context,
                                  path: pro.currentPath,
                                  clearFilters: true,
                                );
                                return;
                              }

                              final filters = result.map(
                                (key, value) => MapEntry(key, value.toString()),
                              );
                              await pro.getFiles(
                                ctx: context,
                                path: pro.currentPath,
                                filters: filters,
                              );
                            },
                            icon: const Icon(Icons.filter_alt_outlined),
                          ),
                          if (pro.appliedFilterCount > 0)
                            Positioned(
                              right: 6,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    pro.appliedFilterCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _folderTile(FolderModel folder) {
    return Consumer<FilesPro>(
      builder: (context, pro, _) {
        bool selected = pro.selected.contains(folder.id);
        return Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: selected
                  ? Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        CustomPrompts.showBottomSheet(
                          ctx: context,
                          bgColor: AppColors.tr,
                          child: FileInformationSheet(
                            type: 'folder',
                            folderName: folder.title,
                            fileSize: folder.size,
                            fileLocation: folder.internalPath,
                            addedDate: folder.createdAt,
                            addedBy: folder.ownerName,
                            addedByAvatar: folder.ownerAvatar,
                            onShare: () {
                              Navigator.pop(context);
                              _showSharePopup(
                                itemName: folder.title,
                                itemPath: folder.internalPath,
                                isFolder: true,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        width: 35,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: const Icon(Icons.more_vert, size: 20),
                      ),
                    ),
            ),
            GestureDetector(
              onLongPress: () => pro.toggleSelect(folder.id),
              onTap: () {
                if (pro.isSelecting) {
                  pro.toggleSelect(folder.id);
                  return;
                }
                if (folder.internalPath.isNotEmpty) {
                  pro.getFiles(ctx: context, path: folder.internalPath);
                }
              },
              child: ImageWidget(image: Paths.folder, height: 140),
            ),
            TextWidget(
              text: folder.title,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ],
        );
      },
    );
  }

  Widget _fileTile(FileModel file) {
    return Consumer<FilesPro>(
      builder: (context, pro, _) {
        bool selected = pro.selected.contains(file.id);
        final avatar = file.uploadedBy.isNotEmpty
            ? file.uploadedBy.first
            : file.ownerAvatar;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 140,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onLongPress: () => pro.toggleSelect(file.id),
                    onTap: () {
                      if (pro.isSelecting) {
                        pro.toggleSelect(file.id);
                        return;
                      }
                      if (_isImageType(file.type)) {
                        _showImageGallery(
                          initialFileId: file.id,
                          allFiles: pro.files,
                        );
                      }
                    },
                    child: _fileThumbnail(file),
                  ),
                  Positioned(top: 8, left: 8, child: _avatar(avatar, 30)),
                  Positioned(
                    top: 0,
                    right: 6,
                    child: selected
                        ? Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              CustomPrompts.showBottomSheet(
                                ctx: context,
                                bgColor: AppColors.tr,
                                child: FileInformationSheet(
                                  file: file.thumbnail,
                                  folderName: file.filename,
                                  fileSize: file.size,
                                  fileLocation: file.internalPath,
                                  addedDate: file.createdAt,
                                  addedBy: file.ownerName,
                                  addedByAvatar: avatar,
                                  onShare: () {
                                    Navigator.pop(context);
                                    _showSharePopup(
                                      itemName: file.filename,
                                      fileUrl: file.thumbnail,
                                      itemPath: file.internalPath,
                                      isFolder: false,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              width: 35,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(Icons.more_vert, size: 20),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Spacers.sb8(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextWidget(
                text: file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fileThumbnail(FileModel file) {
    if (file.type == "psd") {
      return ImageWidget(image: Paths.psd, height: 120);
    }

    // If there's a separate thumbnail URL (different from the storage path),
    // we should show it even if the file itself isn't an image.
    final bool hasSeparateThumbnail = file.thumbnail.isNotEmpty &&
        file.thumbnail != file.storagePath &&
        file.thumbnail != file.internalPath;

    if (!_isImageType(file.type) && !hasSeparateThumbnail) {
      return const Icon(
        Icons.insert_drive_file_rounded,
        size: 56,
        color: Colors.grey,
      );
    }
    return ImageWidget(image: file.thumbnail, height: 140, fit: BoxFit.cover);
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
                        child: TextWidget(
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

  Widget _avatar(String img, double size) {
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
}
