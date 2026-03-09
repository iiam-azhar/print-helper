import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/Files/components/fab.dart';
import 'package:print_helper/Files/components/filter_sheet.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/paths.dart';
import '../models/filefolder_models.dart';
import '../providers/files_pro.dart';
import '../services/helpers.dart';
import '../widgets/custom_prompts.dart';
import '../widgets/spacers.dart';
import '../widgets/text_widget.dart';
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
        padding: EdgeInsets.only(bottom: 60.h),
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
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Column(
                    children: [
                      Spacers.sb15(),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
        children: [
          Icon(CupertinoIcons.folder, size: 25.sp),
          Spacers.sbw12(),
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
                        icon: Icon(CupertinoIcons.cloud_upload),
                      ),

                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.drive_file_move_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(CupertinoIcons.delete),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          CustomPrompts.showBottomSheet(
                            ctx: context,
                            bgColor: AppColors.tr,
                            child: FilterFilesSheet(),
                          );
                        },
                        icon: Icon(Icons.filter_alt_outlined),
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
                        CustomPrompts.showBottomSheet(
                          ctx: context,
                          bgColor: AppColors.tr,
                          child: FileInformationSheet(type: 'folder'),
                        );
                      },
                      child: Container(
                        width: 35.w,
                        height: 30.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13.r),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Icon(Icons.more_vert, size: 20.sp),
                      ),
                    ),
            ),
            GestureDetector(
              onLongPress: () => pro.toggleSelect(folder.id),
              onTap: () {
                if (pro.isSelecting) {
                  pro.toggleSelect(folder.id);
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
                      }
                    },
                    child: _fileThumbnail(file),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _avatar(file.uploadedBy.first, 30),
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
                              CustomPrompts.showBottomSheet(
                                ctx: context,
                                bgColor: AppColors.tr,
                                child: FileInformationSheet(
                                  file: file.thumbnail,
                                  folderName: file.filename,
                                  fileSize: "5mb",
                                  fileLocation:
                                      "Main/Projects/.../filename.jpg",
                                  addedDate: "10/10/2025 - 4:56pm",
                                  addedBy: "Jesus Martinez",
                                  addedByAvatar: file.uploadedBy.first,
                                ),
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
    return ImageWidget(image: file.thumbnail, height: 140, fit: BoxFit.cover);
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
