import 'package:flutter/material.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../../../tab_constants/paths.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';

void showMessageOptionsDialog({
  required BuildContext context,
  required Offset position,
  required Size size,
  required ChatMessage msg,
  required VoidCallback onEdit,
  required VoidCallback onForward,
  required VoidCallback onDelete,
}) {
  final auth = context.read<AuthPro>();
  final bool isAdmin = auth.user?.roleName == 'ADMIN';

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
              top: position.dy + size.height + 6,
              left: isAdmin ? position.dx - 150 : position.dx - 50,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdmin && msg.type != 'voice') ...[
                        Spacers.sbw8(),
                        _popupIcon(
                          icon: Paths.edit,
                          label: "Edit",
                          onTap: () {
                            Navigator.pop(context);
                            onEdit();
                          },
                        ),
                        Spacers.sbw15(),
                        Spacers.sbw2(),
                      ],
                      _popupIcon(
                        icon: Paths.share,
                        label: "Forward",
                        onTap: () {
                          Navigator.pop(context);
                          onForward();
                        },
                      ),
                      if (isAdmin) ...[
                        Spacers.sbw15(),
                        _popupIcon(
                          icon: Paths.delete,
                          label: "Delete",
                          onTap: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                        ),
                      ],
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

Widget _popupIcon({
  required String icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageWidget(image: icon, width: 22, height: 22),
        Spacers.sb2(),
        TextWidget(
          text: label,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          decoration: TextDecoration.none,
        ),
      ],
    ),
  );
}
