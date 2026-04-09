import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';

import '../../../tab_constants/paths.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          _header(context),
          const Divider(height: .8),
          Spacers.sb20(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ImageWidget(
                    image: type == "image" ? file : Paths.folder,
                    height: 140,
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

  // ---------------- FILE INFO ----------------
  Widget _fileInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
                borderRadius: BorderRadius.circular(50),
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

  // ---------------- ACTION BUTTONS CARD ----------------
  Widget _actions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        children: [
          actionRow(
            CupertinoIcons.cloud_download,
            "Download",
            Icons.edit_square,
            "Rename",
          ),
          const Divider(height: 1),
          actionRow(
            Icons.share_outlined,
            "Share",
            CupertinoIcons.delete,
            "Delete",
            leftOnTap: onShare,
          ),
        ],
      ),
    );
  }

  // ---------------- HEADER ----------------
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Spacers.sb10(),
          Row(
            children: [
              const Icon(CupertinoIcons.info_circle, size: 22),
              Spacers.sbw10(),
              const Expanded(
                child: TextWidget(
                  text: "File Information",
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- ACTION ROW ----------------
  Widget actionRow(
    IconData leftIcon,
    String leftText,
    IconData rightIcon,
    String rightText, {
    VoidCallback? leftOnTap,
    VoidCallback? rightOnTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacers.sbw15(),
          Expanded(child: actionButton(leftIcon, leftText, onTap: leftOnTap)),
          Spacers.sbw30(),
          Expanded(
            child: actionButton(rightIcon, rightText, onTap: rightOnTap),
          ),
        ],
      ),
    );
  }

  // Button inside row
  Widget actionButton(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 25),
          Spacers.sbw8(),
          TextWidget(text: text, fontSize: 13, fontWeight: FontWeight.w400),
        ],
      ),
    );
  }

  // ---------------- INFO ITEM ----------------
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
