import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/text_widget.dart';

import '../../../constants/paths.dart';

class FileInformationSheet extends StatelessWidget {
  final String folderName;
  final String fileCount;
  final String file;
  final String fileSize;
  final String type;
  final String fileLocation;
  final String addedDate;
  final String addedBy;
  final String addedByAvatar;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const FileInformationSheet({
    super.key,
    this.folderName = "filenamegoeshere.jpg",
    this.file = "filenamegoeshere.jpg",
    this.fileCount = "541 files",
    this.fileSize = "5mb",
    this.fileLocation =
        "Main/Projects/Website Design/Tasks/Homepage/filename.jpg",
    this.addedDate = "10/10/2025 - 4:56pm",
    this.addedBy = "Jesus Martinez",
    this.addedByAvatar = "assets/images/ppls.png",
    this.type = "image",
    this.onShare,
    this.onDownload,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.r),
          topRight: Radius.circular(25.r),
        ),
      ),
      child: Column(
        children: [
          _header(context),
          Divider(height: .8),
          Spacers.sb20(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 120.w,
                      height: 120.h,
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        color: Colors.white,
                      ),
                      child: ImageWidget(
                        image: type == "image" ? file : Paths.folder,
                        height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Spacers.sb20(),
                  _actions(),
                  _fileInfo(),
                  Spacers.sb40(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        children: [
          _actionRow(
            CupertinoIcons.cloud_download,
            "Download",
            Icons.edit_square,
            "Rename",
            leftOnTap: onDownload,
            rightOnTap: onRename,
          ),
          const Divider(height: 1),
          _actionRow(
            Icons.share_outlined,
            "Share",
            CupertinoIcons.delete,
            "Delete",
            leftOnTap: onShare,
            rightOnTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    IconData leftIcon,
    String leftText,
    IconData rightIcon,
    String rightText, {
    VoidCallback? leftOnTap,
    VoidCallback? rightOnTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacers.sbw15(),
          Expanded(child: _actionButton(leftIcon, leftText, onTap: leftOnTap)),
          Spacers.sbw30(),
          Expanded(
            child: _actionButton(rightIcon, rightText, onTap: rightOnTap),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 25.sp),
          Spacers.sbw8(),
          TextWidget(text: text, fontSize: 13, fontWeight: FontWeight.w400),
        ],
      ),
    );
  }

  Widget _fileInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          infoItem(type == "image" ? "File name" : "Folder name", folderName),
          type == "image" ? const SizedBox() : Spacers.sb5(),
          type == "image"
              ? const SizedBox()
              : infoItem("Folder file count", fileCount),
          Spacers.sb5(),
          infoItem(type == "image" ? "File size" : "Folder size", fileSize),
          Spacers.sb5(),
          infoItem(
            type == "image" ? "File Location" : "Folder Location",
            fileLocation,
          ),
          Spacers.sb5(),
          infoItem("Added date and time", addedDate),
          Spacers.sb5(),
          infoItem("Added through", "APP Chat"),
          Spacers.sb5(),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50.r),
                child: ImageWidget(
                  image: addedByAvatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              Spacers.sbw12(),
              TextWidget(
                text: addedBy,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 45.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          Spacers.sb10(),
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 22.sp,
                fontWeight: FontWeight.w800,
              ),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "File Information",
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  size: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget infoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: title, fontWeight: FontWeight.bold, fontSize: 14),
        Spacers.sb5(),
        TextWidget(
          text: value,
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w400,
        ),
      ],
    );
  }
}
