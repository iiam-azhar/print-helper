import 'dart:math' as math;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import '../chat/provider/chat_pro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/files/components/fab.dart';
import 'package:print_helper/admin/files/components/filter_sheet.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/filefolder_models.dart';
import '../../providers/files_pro.dart';
import '../../services/helpers.dart';
import '../../widgets/custom_prompts.dart';
import '../../widgets/loaders.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';
import 'components/email_recipient_picker.dart';
import 'components/file_info.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Color? _getFolderColor(BuildContext context) {
    try {
      final authPro = Provider.of<AuthPro>(context, listen: false);
      final custPro = getCustPro(context);
      final clipro = Provider.of<ClientPro>(context, listen: false);

      final role = authPro.user?.roleName;
      final isCustomer = role == "CUSTOMER";
      final isContact = role == "CONTACT"; // Client
      final isStaff = role == "STAFF";

      if (isStaff) {
        return null;
      } else if (isCustomer || isContact) {
        String? primaryHex = custPro.client?.brandingPrimaryColor;
        if (primaryHex == null || primaryHex.isEmpty) {
          primaryHex = clipro.selectedClient?.primaryColor;
        }

        if (primaryHex != null && primaryHex.isNotEmpty) {
          String hex = primaryHex.replaceAll('#', '');
          if (hex.length == 6) hex = 'FF$hex';
          return Color(int.parse(hex, radix: 16));
        }
      }
    } catch (e) {
      debugPrint("Error getting folder color: $e");
    }
    return null;
  }

  void _showStorageDetails(FilesPro pro) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final used = pro.storageUsed.trim().isEmpty ? '--' : pro.storageUsed;
        final available = pro.storageAvailable.trim().isEmpty
            ? '--'
            : pro.storageAvailable;
        final total = pro.storageTotal.trim().isEmpty ? '--' : pro.storageTotal;
        final safePercent = pro.usagePercent.clamp(0, 100).toDouble();

        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xffd9d9d9),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
                SizedBox(height: 18.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: 'Storage',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          SizedBox(height: 4.h),
                          TextWidget(
                            text: pro.storageSummary.trim().isEmpty
                                ? '${safePercent.round()}% used'
                                : pro.storageSummary,
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 78.w,
                      height: 78.w,
                      child: _storageUsageIndicator(pro, size: 78.w),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Row(
                  children: [
                    Expanded(
                      child: _storageStatCard(
                        title: 'Used Space',
                        value: used,
                        accent: const Color(0xffffa000),
                        background: const Color(0xfffff6df),
                        icon: CupertinoIcons.chart_pie_fill,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _storageStatCard(
                        title: 'Available',
                        value: available,
                        accent: AppColors.btnClr,
                        background: const Color(0xffebfff3),
                        icon: CupertinoIcons.tray_full_fill,
                      ),
                    ),
                  ],
                ),
                if (pro.storageTotal.trim().isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7f7f7),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.archivebox_fill,
                          size: 18.sp,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 10.w),
                        TextWidget(
                          text: 'Total Space',
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w400,
                        ),
                        const Spacer(),
                        TextWidget(
                          text: total,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _storageStatCard({
    required String title,
    required String value,
    required Color accent,
    required Color background,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 18.sp, color: accent),
          ),
          SizedBox(height: 14.h),
          TextWidget(text: value, fontSize: 18, fontWeight: FontWeight.w700),
          SizedBox(height: 4.h),
          TextWidget(
            text: title,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }

  Widget _storageUsageIndicator(FilesPro pro, {double? size}) {
    final safePercent = pro.usagePercent.clamp(0, 100).toDouble();
    final indicatorSize = size ?? 56.w;
    final stroke = indicatorSize * 0.09;
    final textSize = indicatorSize * 0.22;

    return GestureDetector(
      onTap: () => _showStorageDetails(pro),
      child: SizedBox(
        width: indicatorSize,
        height: indicatorSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(indicatorSize, indicatorSize),
              painter: _StorageRingPainter(
                progress: safePercent / 100,
                strokeWidth: stroke,
              ),
            ),
            TextWidget(
              text: '${safePercent.round()}%',
              fontSize: textSize,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

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
          insetPadding: EdgeInsets.fromLTRB(0, 86.h, 0, 0),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26.r),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 15.h,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.folder,
                        size: 24.sp,
                        color: Colors.black87,
                      ),
                      Spacers.sbw10(),
                      Expanded(
                        child: TextWidget(
                          text: 'New Folder',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Icon(
                          Icons.close,
                          size: 24.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 20.h, 14.w, 8.h),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Folder Name',
                      hintStyle: TextStyle(
                        color: Colors.black45,
                        fontSize: 14.sp,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 18.h, top: 8.h),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.btnClr,
                      minimumSize: Size(92.w, 40.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: TextWidget(
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
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
                            SizedBox(width: 40.w),
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
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
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
                          ? Center(child: showLoader())
                          : GridView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
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
                                        Container(
                                          height: 120.h,
                                          width: 160.w,
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              9.r,
                                            ),
                                          ),
                                          child: ImageWidget(
                                            image: Paths.folder,
                                            height: 108,
                                            color: _getFolderColor(context),
                                          ),
                                        ),
                                        Spacers.sb8(),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6.w,
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
                                        height: 120.h,
                                        width: 160.w,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            9.r,
                                          ),
                                        ),
                                        child: _fileThumbnail(file),
                                      ),
                                      Spacers.sb8(),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6.w,
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
                      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black26),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          Spacers.sbw10(),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(sheetCtx, filesPro.currentPath),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24.r),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 26.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 18.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.r),
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
                const TextWidget(
                  text: 'Delete Selected',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                SizedBox(height: 8.h),
                TextWidget(
                  text:
                      'Are you sure you want to delete $selectedCount selected item${selectedCount == 1 ? '' : 's'}?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
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
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
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
          alignment: Alignment.topCenter,
          insetPadding: EdgeInsets.fromLTRB(0, 86.h, 0, 0),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26.r),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 15.h,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.folder,
                        size: 24.sp,
                        color: Colors.black87,
                      ),
                      Spacers.sbw10(),
                      Expanded(
                        child: TextWidget(
                          text: 'New Folder',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Icon(
                          Icons.close,
                          size: 24.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 20.h, 14.w, 8.h),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Folder Name',
                      hintStyle: TextStyle(
                        color: Colors.black45,
                        fontSize: 14.sp,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 18.h, top: 8.h),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.btnClr,
                      minimumSize: Size(92.w, 40.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: TextWidget(
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

  Future<void> _showItemOptions({
    required String itemId,
    required bool isFolder,
    required bool isSystemItem,
    required String itemName,
    required String itemPath,
    required String fileUrl,
    required String avatar,
    required VoidCallback onInfo,
  }) async {
    final actions = [
      (
        icon: CupertinoIcons.cloud_download,
        image: null,
        label: 'Download',
        color: Colors.black87,
      ),
      (
        icon: Icons.share_outlined,
        image: null,
        label: 'Share',
        color: Colors.black87,
      ),
      (
        icon: Icons.drive_file_move_outlined,
        image: null,
        label: 'Move',
        color: Colors.black87,
      ),
      (
        icon: Icons.copy_outlined,
        image: null,
        label: 'Copy',
        color: Colors.black87,
      ),
      (icon: null, image: Paths.edit, label: 'Rename', color: Colors.black87),
      if (!isFolder)
        (icon: null, image: Paths.email, label: 'Email', color: Colors.black87),
      (
        icon: CupertinoIcons.info,
        image: null,
        label: 'Info',
        color: Colors.black87,
      ),
      (icon: null, image: Paths.delete, label: 'Delete', color: AppColors.red),
    ];

    final Set<String> disabledLabels = (isFolder && isSystemItem)
        ? {'Download', 'Move', 'Rename', 'Delete'}
        : <String>{};

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26.r),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          // color: const Color(0xfff2f2f2),
                          border: Border(
                            bottom: BorderSide(color: Colors.black12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextWidget(
                                text: isFolder ? 'Folder' : 'File',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx),
                              child: Icon(
                                Icons.close,
                                color: Colors.black87,
                                size: 24.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (int i = 0; i < actions.length; i++)
                        InkWell(
                          onTap: disabledLabels.contains(actions[i].label)
                              ? null
                              : () async {
                                  Navigator.pop(sheetCtx);
                                  if (!mounted) return;
                                  final label = actions[i].label;
                                  switch (label) {
                                    case 'Info':
                                      delayed(callback: onInfo, millisec: 120);
                                      return;
                                    case 'Move':
                                    case 'Copy':
                                      final pro = getFilePro(context);
                                      pro.clearSelection();
                                      pro.toggleSelect(itemId);
                                      if (label == 'Move') {
                                        await _moveSelection();
                                      } else {
                                        await _copySelection();
                                      }
                                      return;
                                    case 'Download':
                                      await _handleDownload(
                                        isFolder: isFolder,
                                        fileUrl: fileUrl,
                                        itemPath: itemPath,
                                      );
                                      return;
                                    case 'Share':
                                      await _showSharePopup(
                                        itemName: itemName,
                                        fileUrl: fileUrl,
                                        itemPath: itemPath,
                                        isFolder: isFolder,
                                      );
                                      return;
                                    case 'Email':
                                      await _handleEmail(
                                        itemName: itemName,
                                        fileUrl: fileUrl,
                                        itemPath: itemPath,
                                        isFolder: isFolder,
                                      );
                                      return;
                                    case 'Rename':
                                      await _promptRename(
                                        itemId: itemId,
                                        isFolder: isFolder,
                                        currentName: itemName,
                                      );
                                      return;
                                    case 'Delete':
                                      await _confirmDelete(
                                        itemId: itemId,
                                        isFolder: isFolder,
                                        itemName: itemName,
                                      );
                                      return;
                                    default:
                                      showToast(message: '$label coming soon');
                                  }
                                },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 22.w,
                              vertical: 12.h,
                            ),
                            child: Row(
                              children: [
                                actions[i].image != null
                                    ? ImageWidget(
                                        image: actions[i].image!,
                                        width: 22,
                                        height: 22,
                                        color: actions[i].label == 'Delete'
                                            ? (disabledLabels.contains(
                                                    actions[i].label,
                                                  )
                                                  ? Colors.black38
                                                  : AppColors.red)
                                            : (disabledLabels.contains(
                                                    actions[i].label,
                                                  )
                                                  ? Colors.black38
                                                  : null),
                                      )
                                    : Icon(
                                        actions[i].icon,
                                        size: 23.sp,
                                        color:
                                            disabledLabels.contains(
                                              actions[i].label,
                                            )
                                            ? Colors.black38
                                            : actions[i].color,
                                      ),
                                SizedBox(width: 16.w),
                                TextWidget(
                                  text: actions[i].label,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      disabledLabels.contains(actions[i].label)
                                      ? Colors.black38
                                      : actions[i].color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      Spacers.sb10(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolvedLink(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return 'https://staging.printhelpers.com$value';
    }
    return 'https://staging.printhelpers.com/$value';
  }

  Future<void> _handleDownload({
    required bool isFolder,
    required String fileUrl,
    required String itemPath,
  }) async {
    if (isFolder) {
      showToast(message: 'Folder download is not supported yet');
      return;
    }

    final link = _resolvedLink(fileUrl);
    if (link.isNotEmpty) {
      await tryLaunchUrl(url: link, message: 'Unable to open download link');
      return;
    }

    if (itemPath.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: itemPath.trim()));
      showToast(message: 'File path copied');
      return;
    }

    showToast(message: 'No file link available');
  }

  Future<void> _showSharePopup({
    required String itemName,
    required String fileUrl,
    required String itemPath,
    required bool isFolder,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 22.h),
            decoration: BoxDecoration(
              color: const Color(0xfff5f6f8),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: 'Share',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: 8.h),
                TextWidget(
                  text:
                      'Choose where you want to share this item now. More apps can be added here later.',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff6f7785),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _handleEmail(
                            itemName: itemName,
                            fileUrl: fileUrl,
                            itemPath: itemPath,
                            isFolder: isFolder,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: const Color(0xffcfd4dc)),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32.w,
                                height: 32.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff1f3f7),
                                  borderRadius: BorderRadius.circular(9.r),
                                ),
                                child: Icon(
                                  CupertinoIcons.mail,
                                  size: 18.sp,
                                  color: const Color(0xff4e596c),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: 'Email',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(height: 2.h),
                                    TextWidget(
                                      text: 'Send via email',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xff6f7785),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: AppColors.secondary),
                            color: const Color(0xfffffbea),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32.w,
                                height: 32.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff3e275),
                                  borderRadius: BorderRadius.circular(9.r),
                                ),
                                child: Icon(
                                  CupertinoIcons.chat_bubble_2,
                                  size: 18.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: 'Chat',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(height: 2.h),
                                    TextWidget(
                                      text: 'Share to conversation',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xff6f7785),
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

  Future<void> _showShareToChatSheet({
    required String itemName,
    required String fileUrl,
    required String itemPath,
    required bool isFolder,
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xfff1f1f2),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.search, color: Colors.grey),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: chatPro.onSearchGlobalChanged,
                        decoration: const InputDecoration(
                          hintText: 'Find People or Groups',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              const Divider(height: 1),
              Expanded(
                child: Consumer<ChatPro>(
                  builder: (context, pro, _) {
                    if (pro.searchResults.isNotEmpty) {
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: pro.searchResults.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xffe6e7e6)),
                        itemBuilder: (context, index) {
                          final user = pro.searchResults[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(50.r),
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
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xffe6e7e6)),
                      itemBuilder: (context, index) {
                        final chat = pro.conversations[index];
                        return ListTile(
                          leading: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50.r),
                              border: Border.all(
                                color: const Color(0xffe6e7e6),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50.r),
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

  Future<void> _showShareToEmailSheet({
    required String itemName,
    required String fileUrl,
    required String itemPath,
    bool isFolder = false,
  }) async {
    final pro = context.read<FilesPro>();
    if (pro.emailShareOptions == null) {
      pro.fetchEmailShareOptions();
    }

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final manualEmailController = TextEditingController();
    final sentToController = TextEditingController();
    final List<String> recipients = [];

    Map<String, dynamic>? selectedReplyTo;
    String? selectedReplyToEmail;
    List<Map<String, dynamic>> selectedSentToUsers = [];
    List<String> selectedSentToEmails = [];

    String? subjectError;
    String? messageError;
    String? replyEmailError;
    String? recipientError;
    String? sentToEmailError;

    void addRecipient(StateSetter setModalState, String rawValue) {
      final value = rawValue.trim();
      if (value.isEmpty) return;
      final exists = recipients.any(
        (existing) => existing.toLowerCase() == value.toLowerCase(),
      );
      if (exists) return;
      setModalState(() {
        recipients.add(value);
        recipientError = null;
        sentToEmailError = null;
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
            return Consumer<FilesPro>(
              builder: (context, pro, child) {
                if (pro.emailOptionsLoading) {
                  return SafeArea(
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24.r),
                        ),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                List<Map<String, dynamic>> availableUsers = [];
                if (pro.emailShareOptions != null) {
                  availableUsers = List<Map<String, dynamic>>.from(
                    pro.emailShareOptions!['users'] ?? [],
                  );

                  if (selectedReplyTo == null) {
                    final defaultIds = List<int>.from(
                      pro.emailShareOptions!['default_reply_to_user_ids'] ?? [],
                    );
                    if (defaultIds.isNotEmpty &&
                        availableUsers.any((e) => e['id'] == defaultIds[0])) {
                      selectedReplyTo = availableUsers.firstWhere(
                        (e) => e['id'] == defaultIds[0],
                      );
                      // Initialize selected email from default
                      final defaultEmail = pro
                          .emailShareOptions!['default_reply_to_email']
                          ?.toString();
                      if (defaultEmail != null && defaultEmail.isNotEmpty) {
                        selectedReplyToEmail = defaultEmail;
                      }
                    } else if (availableUsers.isNotEmpty) {
                      selectedReplyTo = availableUsers.first;
                    }
                  }
                }

                return SafeArea(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 8.h),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.mail_solid,
                                size: 21.sp,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
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
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              14.h,
                              16.w,
                              16.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: 'Subject',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                SizedBox(height: 8.h),
                                TextField(
                                  controller: subjectController,
                                  onChanged: (val) {
                                    if (subjectError != null &&
                                        val.trim().isNotEmpty) {
                                      setModalState(() => subjectError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Type subject',
                                    hintStyle: TextStyle(
                                      color: Colors.black38,
                                      fontSize: 14.sp,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 12.h,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: subjectError != null
                                            ? Colors.red.shade300
                                            : Colors.black12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: subjectError != null
                                            ? Colors.red.shade300
                                            : Colors.black12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: subjectError != null
                                            ? Colors.red.shade400
                                            : Colors.black26,
                                      ),
                                    ),
                                  ),
                                ),
                                if (subjectError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: TextWidget(
                                      text: subjectError!,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                SizedBox(height: 12.h),
                                TextWidget(
                                  text: 'Message',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                SizedBox(height: 8.h),
                                TextField(
                                  controller: messageController,
                                  maxLines: 4,
                                  onChanged: (val) {
                                    if (messageError != null &&
                                        val.trim().isNotEmpty) {
                                      setModalState(() => messageError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Type message',
                                    hintStyle: TextStyle(
                                      color: Colors.black38,
                                      fontSize: 14.sp,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 12.h,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: messageError != null
                                            ? Colors.red.shade300
                                            : Colors.black12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: messageError != null
                                            ? Colors.red.shade300
                                            : Colors.black12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide(
                                        color: messageError != null
                                            ? Colors.red.shade400
                                            : Colors.black26,
                                      ),
                                    ),
                                  ),
                                ),
                                if (messageError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: TextWidget(
                                      text: messageError!,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                SizedBox(height: 12.h),
                                TextWidget(
                                  text: 'Select reply to email',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                SizedBox(height: 8.h),
                                EmailRecipientPicker(
                                  isMultiSelect: false,
                                  hintText: 'Select reply to',
                                  initialSelection: selectedReplyTo != null
                                      ? [selectedReplyTo!]
                                      : [],
                                  users: availableUsers,
                                  onSelectionChanged: (selected) {
                                    setModalState(() {
                                      final newSelected = selected.isNotEmpty
                                          ? selected.first
                                          : null;
                                      if (selectedReplyTo?['id'] !=
                                          newSelected?['id']) {
                                        selectedReplyTo = newSelected;
                                        selectedReplyToEmail = null;
                                        if (selectedReplyTo != null) {
                                          final primary =
                                              selectedReplyTo!['email']
                                                  ?.toString();
                                          if (primary != null &&
                                              primary.isNotEmpty) {
                                            selectedReplyToEmail = primary;
                                          }
                                        }
                                      }
                                      if (selectedReplyTo != null) {
                                        replyEmailError = null;
                                      }
                                    });
                                  },
                                ),
                                if (replyEmailError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: TextWidget(
                                      text: replyEmailError!,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                SizedBox(height: 12.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextWidget(
                                      text: 'Reply Email Address',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    if (selectedReplyTo != null &&
                                        selectedReplyToEmail != null)
                                      TextWidget(
                                        text: '1 user selected',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black38,
                                      ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final List<String> emails = [];
                                      if (selectedReplyTo != null) {
                                        if (selectedReplyTo!['email'] != null) {
                                          emails.add(
                                            selectedReplyTo!['email']
                                                .toString(),
                                          );
                                        }
                                        if (selectedReplyTo!['emails'] !=
                                            null) {
                                          for (var e
                                              in (selectedReplyTo!['emails']
                                                  as List)) {
                                            if (!emails.contains(
                                              e.toString(),
                                            )) {
                                              emails.add(e.toString());
                                            }
                                          }
                                        }
                                      }

                                      if (selectedReplyTo == null ||
                                          emails.isEmpty) {
                                        return Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 40.h,
                                          ),
                                          alignment: Alignment.center,
                                          child: TextWidget(
                                            text:
                                                'No emails found for the selected reply user.',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black38,
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.all(12.w),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        5.r,
                                                      ),
                                                  child: ImageWidget(
                                                    image:
                                                        selectedReplyTo!['image'] ??
                                                        Paths.user,
                                                    height: 24.w,
                                                    width: 24.w,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                TextWidget(
                                                  text:
                                                      selectedReplyTo!['name'] ??
                                                      '',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black54,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1),
                                          ...emails.map((email) {
                                            final isSelected =
                                                selectedReplyToEmail == email;
                                            return InkWell(
                                              onTap: () {
                                                setModalState(() {
                                                  if (isSelected) {
                                                    selectedReplyToEmail = null;
                                                  } else {
                                                    selectedReplyToEmail =
                                                        email;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16.w,
                                                  vertical: 10.h,
                                                ),
                                                color: isSelected
                                                    ? const Color(0xffe9f3df)
                                                    : Colors.transparent,
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      height: 20.w,
                                                      width: 20.w,
                                                      child: Checkbox(
                                                        value: isSelected,
                                                        activeColor:
                                                            const Color(
                                                              0xff27ae60,
                                                            ),
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4.r,
                                                              ),
                                                        ),
                                                        onChanged: (val) {
                                                          setModalState(() {
                                                            if (val == true) {
                                                              selectedReplyToEmail =
                                                                  email;
                                                            } else {
                                                              selectedReplyToEmail =
                                                                  null;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    SizedBox(width: 12.w),
                                                    Expanded(
                                                      child: TextWidget(
                                                        text: email,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: isSelected
                                                            ? Colors.black87
                                                            : Colors.black54,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      TextWidget(
                                                        text: 'Selected',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                          0xff27ae60,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                TextWidget(
                                  text: 'Select sent to email',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                SizedBox(height: 8.h),
                                EmailRecipientPicker(
                                  users: availableUsers,
                                  initialSelection: selectedSentToUsers,
                                  onSelectionChanged: (users) {
                                    setModalState(() {
                                      // Update users
                                      selectedSentToUsers = users;

                                      // Remove emails for users that were unselected
                                      final userIds = users
                                          .map((u) => u['id'])
                                          .toSet();
                                      selectedSentToEmails.removeWhere((email) {
                                        // Find which user this email belongs to
                                        final owner = availableUsers.firstWhere(
                                          (u) {
                                            final primary = u['email']
                                                ?.toString();
                                            final secondary =
                                                (u['emails'] as List?)
                                                    ?.map((e) => e.toString())
                                                    .toList();
                                            return primary == email ||
                                                (secondary?.contains(email) ??
                                                    false);
                                          },
                                          orElse: () => {},
                                        );
                                        return owner.isEmpty ||
                                            !userIds.contains(owner['id']);
                                      });

                                      // Add primary emails for newly selected users if not already present
                                      for (var user in users) {
                                        final primary = user['email']
                                            ?.toString();
                                        if (primary != null &&
                                            primary.isNotEmpty &&
                                            !selectedSentToEmails.contains(
                                              primary,
                                            )) {
                                          selectedSentToEmails.add(primary);
                                        }
                                      }
                                      if (selectedSentToUsers.isNotEmpty ||
                                          recipients.isNotEmpty) {
                                        recipientError = null;
                                      }
                                      if (selectedSentToEmails.isNotEmpty ||
                                          recipients.isNotEmpty) {
                                        sentToEmailError = null;
                                      }
                                    });
                                  },
                                ),
                                if (recipientError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: TextWidget(
                                      text: recipientError!,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                SizedBox(height: 12.h),
                                if (selectedSentToUsers.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Column(
                                      children: selectedSentToUsers.map((user) {
                                        final List<String> userEmails = [];
                                        if (user['email'] != null) {
                                          userEmails.add(
                                            user['email'].toString(),
                                          );
                                        }
                                        if (user['emails'] != null) {
                                          for (var e
                                              in (user['emails'] as List)) {
                                            if (!userEmails.contains(
                                              e.toString(),
                                            )) {
                                              userEmails.add(e.toString());
                                            }
                                          }
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                12.w,
                                                12.h,
                                                12.w,
                                                8.h,
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          50.r,
                                                        ),
                                                    child: ImageWidget(
                                                      image:
                                                          user['image'] ??
                                                          Paths.user,
                                                      height: 24.w,
                                                      width: 24.w,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10.w),
                                                  TextWidget(
                                                    text: user['name'] ?? '',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xff4b5563,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ...userEmails.map((email) {
                                              final isSelected =
                                                  selectedSentToEmails.contains(
                                                    email,
                                                  );
                                              return InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    if (isSelected) {
                                                      selectedSentToEmails
                                                          .remove(email);
                                                    } else {
                                                      selectedSentToEmails.add(
                                                        email,
                                                      );
                                                      sentToEmailError = null;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 16.w,
                                                    vertical: 10.h,
                                                  ),
                                                  color: isSelected
                                                      ? const Color(0xffe9f3df)
                                                      : Colors.transparent,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        height: 20.w,
                                                        width: 20.w,
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          activeColor:
                                                              const Color(
                                                                0xff27ae60,
                                                              ),
                                                          materialTapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4.r,
                                                                ),
                                                          ),
                                                          onChanged: (val) {
                                                            setModalState(() {
                                                              if (val == true) {
                                                                selectedSentToEmails
                                                                    .add(email);
                                                                sentToEmailError =
                                                                    null;
                                                              } else {
                                                                selectedSentToEmails
                                                                    .remove(
                                                                      email,
                                                                    );
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(width: 12.w),
                                                      Expanded(
                                                        child: TextWidget(
                                                          text: email,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: isSelected
                                                              ? Colors.black87
                                                              : Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                            if (selectedSentToUsers.last !=
                                                user)
                                              const Divider(height: 1),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                ],
                                SizedBox(height: 12.h),
                                TextWidget(
                                  text: 'Select email',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                SizedBox(height: 8.h),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          10.h,
                                          12.w,
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
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          10.h,
                                          12.w,
                                          12.h,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                            border: Border.all(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 4.h,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (recipients.isNotEmpty)
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 8.h,
                                                  ),
                                                  child: Wrap(
                                                    spacing: 8.w,
                                                    runSpacing: 8.h,
                                                    children: recipients
                                                        .map(
                                                          (email) => Container(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      10.w,
                                                                  vertical: 6.h,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xfff5f6f1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6.r,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                TextWidget(
                                                                  text: email,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: const Color(
                                                                    0xff4b5563,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 6.w,
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    setModalState(() {
                                                                      recipients
                                                                          .remove(
                                                                            email,
                                                                          );
                                                                    });
                                                                  },
                                                                  child: Icon(
                                                                    Icons.close,
                                                                    size: 14.sp,
                                                                    color: Colors
                                                                        .black54,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ),
                                              TextField(
                                                controller:
                                                    manualEmailController,
                                                onSubmitted: (value) {
                                                  addRecipient(
                                                    setModalState,
                                                    value,
                                                  );
                                                  manualEmailController.clear();
                                                },
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Type email and press Enter',
                                                  hintStyle: TextStyle(
                                                    color: Colors.black38,
                                                    fontSize: 14.sp,
                                                  ),
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 4.w,
                                                        vertical: 8.h,
                                                      ),
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (recipients.isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 14.h,
                                          ),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.black12,
                                              ),
                                            ),
                                          ),
                                          child: TextWidget(
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
                                if (sentToEmailError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: TextWidget(
                                      text: sentToEmailError!,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size(0, 42.h),
                                    side: const BorderSide(
                                      color: Colors.black26,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22.r),
                                    ),
                                  ),
                                  child: TextWidget(
                                    text: 'Cancel',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final typed = manualEmailController.text
                                        .trim();
                                    if (typed.isNotEmpty) {
                                      addRecipient(setModalState, typed);
                                      manualEmailController.clear();
                                    }

                                    if (selectedSentToUsers.isEmpty) {
                                      setModalState(() {
                                        recipientError =
                                            'Please select at least one user';
                                      });
                                      return;
                                    }

                                    if (recipients.isEmpty &&
                                        selectedSentToEmails.isEmpty) {
                                      setModalState(() {
                                        sentToEmailError =
                                            'Please select or add at least one email recipient';
                                      });
                                      return;
                                    }

                                    if (selectedReplyToEmail == null) {
                                      setModalState(() {
                                        replyEmailError =
                                            'Please select a reply email';
                                      });
                                      return;
                                    }

                                    final subject = subjectController.text
                                        .trim();
                                    final message = messageController.text
                                        .trim();

                                    if (subject.isEmpty) {
                                      setModalState(() {
                                        subjectError = 'Please enter a subject';
                                      });
                                      return;
                                    }

                                    if (message.isEmpty) {
                                      setModalState(() {
                                        messageError = 'Please enter a message';
                                      });
                                      return;
                                    }

                                    Loaders.show();
                                    final success = await pro.shareItemToEmail(
                                      subject: subject,
                                      message: message,
                                      sentToUserIds: selectedSentToUsers
                                          .map((u) => u['id'] as int)
                                          .toList(),
                                      sentToEmails: [
                                        ...selectedSentToEmails,
                                        ...recipients,
                                      ],
                                      replyToUserIds: selectedReplyTo != null
                                          ? [selectedReplyTo!['id'] as int]
                                          : [],
                                      replyToEmail: selectedReplyToEmail,
                                      itemPath: itemPath,
                                      itemName: itemName,
                                      isFolder: isFolder,
                                    );
                                    Loaders.hide();

                                    if (success) {
                                      Navigator.pop(ctx);
                                      showToast(
                                        message:
                                            'Email share prepared for ${itemName.isEmpty ? (isFolder ? 'folder' : 'file') : itemName}',
                                      );
                                    } else {
                                      showToast(
                                        message: 'Failed to share via email',
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    minimumSize: Size(0, 42.h),
                                    backgroundColor: AppColors.btnClr,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22.r),
                                    ),
                                  ),
                                  child: TextWidget(
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
      },
    );

    subjectController.dispose();
    messageController.dispose();
    manualEmailController.dispose();
    sentToController.dispose();
  }

  Future<void> _handleEmail({
    required String itemName,
    required String fileUrl,
    required String itemPath,
    bool isFolder = false,
  }) async {
    await _showShareToEmailSheet(
      itemName: itemName,
      fileUrl: fileUrl,
      itemPath: itemPath,
      isFolder: isFolder,
    );
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
          alignment: Alignment.topCenter,
          insetPadding: EdgeInsets.fromLTRB(0, 86.h, 0, 0),
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26.r),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 15.h,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      ImageWidget(image: Paths.edit, width: 20, height: 20),
                      Spacers.sbw10(),
                      Expanded(
                        child: TextWidget(
                          text: 'Rename',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Icon(
                          Icons.close,
                          size: 24.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 20.h, 14.w, 8.h),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: isFolder
                          ? 'Enter new name'
                          : (lockedExtension.isEmpty
                                ? 'Enter new name'
                                : 'Enter name (.$lockedExtension is fixed)'),
                      hintStyle: TextStyle(
                        color: Colors.black45,
                        fontSize: 14.sp,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 18.h, top: 8.h),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.btnClr,
                      minimumSize: Size(92.w, 40.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: TextWidget(
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

  Future<void> _confirmDelete({
    required String itemId,
    required bool isFolder,
    required String itemName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 26.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 18.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.r),
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
                TextWidget(
                  text: isFolder ? 'Delete Folder' : 'Delete File',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                SizedBox(height: 8.h),
                TextWidget(
                  text: 'Are you sure you want to delete "$itemName"?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
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
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
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

    await getFilePro(
      context,
    ).deleteItem(ctx: context, itemId: itemId, isFolder: isFolder);
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
              padding: EdgeInsets.only(bottom: 60.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _storageUsageIndicator(pro),
                  SizedBox(height: 12.h),
                  FabMenu(
                    onUpload: () => _pickAndUploadFiles(pro),
                    onNewFolder: _promptCreateFolder,
                    onCamera: () => _captureAndUpload(pro),
                  ),
                ],
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
                    return Center(child: showLoader());
                  }
                  final List<dynamic> combined = [
                    ...pro.folders.map((e) => {"type": "folder", "data": e}),
                    ...pro.files.map((e) => {"type": "file", "data": e}),
                  ];
                  final List<dynamic> gridItems = [
                    ...pro.uploadQueue.map(
                      (e) => {"type": "upload_queue", "data": e},
                    ),
                    ...combined,
                  ];

                  return Column(
                    children: [
                      if (pro.isSelecting)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 16.h,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xffe6e7e8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {},
                                child: ImageWidget(
                                  image: Paths.email,
                                  height: 28,
                                  width: 28,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: Icon(
                                  Icons.share_outlined,
                                  size: 28.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: _moveSelection,
                                child: Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 28.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: _copySelection,
                                child: Icon(
                                  Icons.copy_outlined,
                                  size: 28.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: Icon(
                                  CupertinoIcons.cloud_download,
                                  size: 28.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: _deleteSelection,
                                child: ImageWidget(
                                  image: Paths.delete,
                                  height: 27,
                                  width: 27,
                                  color: AppColors.red,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => pro.clearSelection(),
                                child: Icon(
                                  Icons.close,
                                  size: 30.sp,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: pro.isSelecting ? 8.h : 8.h),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () =>
                              pro.getFiles(ctx: context, path: pro.currentPath),
                          child: gridItems.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.45,
                                      child: Center(
                                        child: TextWidget(
                                          text: "No files or folders",
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                  ),
                                  child: Column(
                                    children: [
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.82,
                                            ),
                                        itemCount: gridItems.length,
                                        itemBuilder: (context, i) {
                                          final item = gridItems[i];
                                          if (item["type"] == "upload_queue") {
                                            return _uploadQueueTile(
                                              item["data"],
                                            );
                                          }
                                          if (item["type"] == "folder") {
                                            return _folderTile(item["data"]);
                                          }
                                          return _fileTile(item["data"]);
                                        },
                                      ),
                                      Spacers.sb20(),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadQueueTile(Map<String, dynamic> queueItem) {
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
    final isSvgPreview = canPreview && ext == 'svg';
    final hasPreviewBackground = isImagePreview || isSvgPreview;
    final progressColor = isFailed
        ? AppColors.red
        : (isDone ? Colors.green : AppColors.primary);
    final statusText = (!isFailed && !isDone)
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : (isDone ? 'Done' : 'Failed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 140.h,
          width: 160.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9.r),
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
              // Background preview
              ClipRRect(
                borderRadius: BorderRadius.circular(9.r),
                child: isImagePreview
                    ? Image.file(
                        File(filePath),
                        width: 160.w,
                        height: 140.h,
                        fit: BoxFit.cover,
                      )
                    : isSvgPreview
                    ? SizedBox(
                        width: 160.w,
                        height: 140.h,
                        child: SvgPicture.file(
                          File(filePath),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 160.w,
                        height: 140.h,
                        color: isFailed
                            ? AppColors.red.withValues(alpha: 0.06)
                            : const Color(0xfff1f2f3),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.doc,
                          size: 44.sp,
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

              // Progress ring or error icon
              if (isFailed)
                Container(
                  width: 54.w,
                  height: 54.w,
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
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 28.sp,
                    color: AppColors.red,
                  ),
                )
              else
                SizedBox(
                  width: 54.w,
                  height: 54.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 6.w,
                    value: progress.clamp(0, 1),
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),

              // Status badge
              Positioned(
                bottom: 8.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: TextWidget(
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
        Spacers.sb8(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: TextWidget(
            text: fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Retry / Dismiss row — only shown for failed items
        if (isFailed) ...[
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retry
              GestureDetector(
                onTap: () {
                  final pro = context.read<FilesPro>();
                  pro.retryUpload(ctx: context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4.w),
                      TextWidget(
                        text: 'Retry',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Dismiss
              GestureDetector(
                onTap: () {
                  final pro = context.read<FilesPro>();
                  pro.dismissUploadQueue();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0f0f0),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 13.sp, color: Colors.black54),
                      SizedBox(width: 3.w),
                      TextWidget(
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

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: Consumer<FilesPro>(
        builder: (context, pro, _) {
          final totalItems = pro.folders.length + pro.files.length;
          return Row(
            children: [
              ImageWidget(
                image: Paths.foldr,
                width: 25.w,
                color: _getFolderColor(context),
              ),
              Spacers.sbw12(),
              TextWidget(
                text: "Files ($totalItems)",
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
            if (pro.isSelecting) return SizedBox.shrink();
            return Row(
              children: [
                if (pro.currentPath != pro.homePath)
                  IconButton(
                    onPressed: () {
                      pro.getFiles(ctx: context, path: pro.homePath);
                    },
                    icon: Icon(CupertinoIcons.home),
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
                            result[FilterFilesSheet.clearFiltersKey] == true;
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
                      icon: ImageWidget(image: Paths.filter, width: 20),
                    ),
                    if (pro.appliedFilterCount > 0)
                      Positioned(
                        right: 6,
                        top: 0,
                        child: Container(
                          width: 18.w,
                          height: 18.w,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: TextWidget(
                              text: pro.appliedFilterCount.toString(),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 140.h,
              width: 160.w,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                    child: ImageWidget(
                      image: Paths.folder,
                      height: 118,
                      color: _getFolderColor(context),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 6,
                    child: selected
                        ? Container(
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              _showItemOptions(
                                itemId: folder.id,
                                isFolder: true,
                                isSystemItem: folder.isSystem,
                                itemName: folder.title,
                                itemPath: folder.internalPath,
                                fileUrl: '',
                                avatar: folder.ownerAvatar,
                                onInfo: () {
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
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              width: 35.w,
                              height: 30.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13.r),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: Icon(Icons.more_vert, size: 20.sp),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Spacers.sb8(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: TextWidget(
                text: folder.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
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
              height: 140.h,
              width: 160.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Stack(
                alignment: .center,
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
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              _showItemOptions(
                                itemId: file.id,
                                isFolder: false,
                                isSystemItem: false,
                                itemName: file.filename,
                                itemPath: file.internalPath,
                                fileUrl: file.storagePath,
                                avatar: avatar,
                                onInfo: () {
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
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              width: 35.w,
                              height: 30.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13.r),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: Icon(Icons.more_vert, size: 20.sp),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Spacers.sb8(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
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
    final bool hasSeparateThumbnail =
        file.thumbnail.isNotEmpty &&
        file.thumbnail != file.storagePath &&
        file.thumbnail != file.internalPath;

    if (!_isImageType(file.type) && !hasSeparateThumbnail) {
      return Icon(
        Icons.insert_drive_file_rounded,
        size: 56.sp,
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
                    top: 48.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20.r),
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
                    top: 48.h,
                    right: 20.w,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22.sp,
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
      borderRadius: BorderRadius.circular(50.r),
      child: ImageWidget(
        image: img,
        height: size,
        width: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _StorageRingPainter extends CustomPainter {
  const _StorageRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = const Color(0xffe9e9e9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Color(0xffff8a00), Color(0xffffcc33)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    if (sweepAngle > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
