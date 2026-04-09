import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../constants/paths.dart';
import '../../models/chat_models.dart';
import '../../../../providers/auth_pro.dart';
import '../../../../widgets/image_widget.dart';
import '../../../../widgets/text_widget.dart';
import 'package:provider/provider.dart';

void showMessageOptionsDialog({
  required BuildContext context,
  required Offset position,
  required Size size,
  required ChatMessage msg,
  required VoidCallback onEdit,
  required VoidCallback onForward,
  required VoidCallback onDelete,
  VoidCallback? onDownload,
}) {
  final auth = context.read<AuthPro>();
  final bool isAdmin = auth.user?.roleName == 'ADMIN';
  final canEdit = (msg.isMe || isAdmin) && msg.type == 'text';
  final canDownload =
      (msg.type == 'image' || msg.type == 'file') && onDownload != null;
  final itemCount =
      (canEdit ? 1 : 0) + 1 + (canDownload ? 1 : 0) + (isAdmin ? 1 : 0);
  final screenSize = MediaQuery.of(context).size;
  final menuWidth = 130.w;
  final menuHeight = (itemCount * 38.h) + 16.h;
  final preferredLeft = position.dx - 8.w;
  final preferredTop = position.dy + size.height + 6.h;
  final left = preferredLeft.clamp(8.w, screenSize.width - menuWidth - 8.w);
  final top = preferredTop.clamp(8.h, screenSize.height - menuHeight - 8.h);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "PopupMenu",
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    pageBuilder: (_, _, _) {
      return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: menuWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canEdit)
                        _popupOptionRow(
                          icon: Paths.edit,
                          label: "Edit",
                          onTap: () {
                            Navigator.pop(context);
                            onEdit();
                          },
                        ),
                      _popupOptionRow(
                        icon: Paths.share,
                        label: "Forward",
                        onTap: () {
                          Navigator.pop(context);
                          onForward();
                        },
                      ),
                      if (canDownload)
                        _popupOptionRow(
                          iconData: CupertinoIcons.cloud_download,
                          label: "Download",
                          onTap: () {
                            Navigator.pop(context);
                            onDownload();
                          },
                        ),
                      if (isAdmin)
                        _popupOptionRow(
                          icon: Paths.delete,
                          label: "Delete",
                          onTap: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _popupOptionRow({
  String? icon,
  IconData? iconData,
  required String label,
  required VoidCallback onTap,
}) {
  final Widget leading = iconData != null
      ? Icon(iconData, size: 18, color: Colors.black87)
      : ImageWidget(image: icon ?? '', width: 18, height: 18);

  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: 8.w),
          TextWidget(
            text: label,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
        ],
      ),
    ),
  );
}
