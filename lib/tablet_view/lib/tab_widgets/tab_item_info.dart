import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_image_widget.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_text_widget.dart'
    as tab_text;

class TabItemInfo extends StatelessWidget {
  final String title;
  final String size;
  final String location;
  final String date;
  final String ownerName;
  final String ownerAvatar;
  final String type; // 'folder' or 'file'
  final String thumbnail;
  final String fileCount;

  const TabItemInfo({
    super.key,
    required this.title,
    required this.size,
    required this.location,
    required this.date,
    required this.ownerName,
    required this.ownerAvatar,
    required this.type,
    this.thumbnail = '',
    this.fileCount = '0',
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String size,
    required String location,
    required String date,
    required String ownerName,
    required String ownerAvatar,
    required String type,
    String thumbnail = '',
    String fileCount = '0',
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: TabItemInfo(
              title: title,
              size: size,
              location: location,
              date: date,
              ownerName: ownerName,
              ownerAvatar: ownerAvatar,
              type: type,
              thumbnail: thumbnail,
              fileCount: fileCount,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(anim1),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle,
                  size: 24,
                  color: Color(0xFF2D3748),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: tab_text.TextWidget(
                    text: type == 'folder'
                        ? 'Folder Information'
                        : 'File Information',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 20,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Visual Preview
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ImageWidget(
                        image: type == 'image' ? thumbnail : Paths.folder,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem(
                          type == 'folder' ? 'Folder name' : 'File name',
                          title,
                        ),
                        if (type == 'folder') ...[
                          const SizedBox(height: 10),
                          _infoItem('Folder File Count', fileCount),
                        ],
                        const SizedBox(height: 10),
                        _infoItem(
                          type == 'folder' ? 'Folder size' : 'File size',
                          size,
                        ),
                        const SizedBox(height: 10),
                        _infoItem(
                          type == 'folder'
                              ? 'Folder Location'
                              : 'File Location',
                          location,
                        ),
                        const SizedBox(height: 10),
                        _infoItem('Added date and time', date),
                        const SizedBox(height: 10),
                        _infoItem('Added through', 'APP Chat'),
                        const SizedBox(height: 10),
                        // Added By row
                        const tab_text.TextWidget(
                          text: 'Added By',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF718096),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: ImageWidget(
                                image: ownerAvatar,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: tab_text.TextWidget(
                                text: ownerName,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tab_text.TextWidget(
          text: label,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF718096),
        ),
        const SizedBox(height: 6),
        tab_text.TextWidget(
          text: value,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF2D3748),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
