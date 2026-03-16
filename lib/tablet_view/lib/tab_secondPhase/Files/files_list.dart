import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import 'components/file_info.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
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
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FabMenu(onUpload: () {}, onNewFolder: () {}, onCamera: () {}),
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
                return SingleChildScrollView(
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
                            if (pro.storageSummary.isNotEmpty)
                              TextWidget(
                                text: pro.storageSummary,
                                fontSize: 11,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
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
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.80,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: Row(
        children: const [
          Icon(CupertinoIcons.folder, size: 25),
          SizedBox(width: 12),
          TextWidget(text: "Files", fontWeight: FontWeight.bold, fontSize: 20),
        ],
      ),
      actions: [
        Consumer<FilesPro>(
          builder: (context, pro, _) {
            return pro.isSelecting
                ? Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(CupertinoIcons.cloud_upload),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.drive_file_move_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
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
                      IconButton(
                        onPressed: () {
                          CustomPrompts.showBottomSheet(
                            ctx: context,
                            bgColor: AppColors.tr,
                            child: const FilterFilesSheet(),
                          );
                        },
                        icon: const Icon(Icons.filter_alt_outlined),
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
                      }
                    },
                    child: _fileThumbnail(file),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _avatar(avatar, 30),
                  ),
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
    if (!_isImageType(file.type)) {
      return const Icon(
        Icons.insert_drive_file_rounded,
        size: 56,
        color: Colors.grey,
      );
    }
    return ImageWidget(image: file.thumbnail, height: 140, fit: BoxFit.cover);
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
