import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../models/filefolder_models.dart';
import '../../../providers/files_pro.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart' as tab_text;

class TabLocationPicker extends StatefulWidget {
  final String actionType; // 'Move' or 'Copy'
  final List<Map<String, dynamic>> itemsToProcess;

  const TabLocationPicker({
    super.key,
    required this.actionType,
    required this.itemsToProcess,
  });

  static Future<String?> show({
    required BuildContext context,
    required String actionType,
    required List<Map<String, dynamic>> items,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: TabLocationPicker(actionType: actionType, itemsToProcess: items),
      ),
    );
  }

  @override
  State<TabLocationPicker> createState() => _TabLocationPickerState();
}

class _TabLocationPickerState extends State<TabLocationPicker> {
  late FilesPro _pickerPro;

  @override
  void initState() {
    super.initState();
    // Create an isolated instance of FilesPro for the picker navigation
    _pickerPro = FilesPro();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickerPro.getFiles(ctx: context);
    });
  }

  @override
  void dispose() {
    _pickerPro.dispose();
    super.dispose();
  }

  void _handleUp() {
    _pickerPro.navigateToParentFolder(ctx: context);
  }

  void _handleHome() {
    _pickerPro.getFiles(ctx: context, path: _pickerPro.homePath);
  }

  void _promptAddFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _pickerPro.createFolder(ctx: context, name: name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pickerPro,
      child: Consumer<FilesPro>(
        builder: (context, pro, child) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(pro),
                _buildToolbar(pro),
                Flexible(child: _buildGrid(pro)),
                _buildFooter(pro),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(FilesPro pro) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xfff5f6f7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(Paths.foldr, width: 22, height: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tab_text.TextWidget(
                  text: 'Choose a Location',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                tab_text.TextWidget(
                  text: pro.currentPath == pro.homePath
                      ? 'Please select a subfolder'
                      : '${widget.actionType} into: ${pro.displayPath}',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: pro.currentPath == pro.homePath
                      ? Colors.redAccent
                      : Colors.black45,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _promptAddFolder,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(
              Icons.create_new_folder_outlined,
              size: 20,
              color: Colors.black87,
            ),
            label: tab_text.TextWidget(
              text: 'Add Folder',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.black45),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(FilesPro pro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xfffafafa),
      child: Row(
        children: [
          _toolbarButton('Up', _handleUp),
          const SizedBox(width: 8),
          _toolbarButton('Home', _handleHome),
          const SizedBox(width: 16),
          tab_text.TextWidget(
            text: 'PATH',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black12),
              ),
              child: tab_text.TextWidget(
                text: pro.displayPath,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.black12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: Colors.white,
        minimumSize: Size.zero,
      ),
      child: tab_text.TextWidget(
        text: label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildGrid(FilesPro pro) {
    final items = [...pro.folders, ...pro.files];

    return Container(
      padding: const EdgeInsets.all(20),
      child: pro.filesLoad
          ? const Center(child: CircularProgressIndicator())
          : pro.folders.isEmpty && pro.files.isEmpty
          ? const Center(
              child: tab_text.TextWidget(
                text: 'Empty Folder',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black38,
              ),
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is FolderModel) {
                  return _buildGridFolder(item, pro);
                }
                return _buildGridFile(item as FileModel);
              },
            ),
    );
  }

  Widget _buildGridFolder(FolderModel folder, FilesPro pro) {
    return GestureDetector(
      onTap: () => pro.getFiles(ctx: context, path: folder.internalPath),
      child: Column(
        children: [
          Expanded(child: Image.asset(Paths.folder, fit: BoxFit.contain)),
          const SizedBox(height: 8),
          tab_text.TextWidget(
            text: folder.title,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGridFile(FileModel file) {
    return Opacity(
      opacity: 0.5, // Visual hint that files are just context
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xfff5f5f5),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _fileThumbnail(file),
            ),
          ),
          const SizedBox(height: 8),
          tab_text.TextWidget(
            text: file.filename,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _fileThumbnail(FileModel file) {
    if (file.thumbnail.isNotEmpty) {
      return ImageWidget(image: file.thumbnail, fit: BoxFit.cover);
    }
    const types = {
      'pdf': Paths.pdf,
      'zip': Paths.zip,
      'rar': Paths.zip,
      'docx': Paths.docx,
      'doc': Paths.docx,
      'txt': Paths.txt,
    };
    final icon = types[file.type.toLowerCase()] ?? '';
    if (icon.isNotEmpty) {
      return Center(child: Image.asset(icon, width: 32, fit: BoxFit.contain));
    }
    return const Icon(Icons.insert_drive_file_outlined, color: Colors.black26);
  }

  Widget _buildFooter(FilesPro pro) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              side: const BorderSide(color: Colors.black12),
            ),
            child: tab_text.TextWidget(
              text: 'Cancel',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: pro.currentPath == pro.homePath
                ? null
                : () => Navigator.pop(context, pro.currentPath),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: tab_text.TextWidget(
              text: 'Select',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
