
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/widgets/image_widget.dart';
import '../../Files/files_list.dart';
import '../chat/view/chat_list.dart';
import '../client/clients_list.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';

class NavWidgets {
  static List<Widget> screens = [
    ClientScreen(isFromAdmin: true, isFromStaff: false, isFromClient: false),
    const FilesScreen(),
    ChatList(),
    const SizedBox(),
    // ChatListScreenTest(),
    const SizedBox(),
  ];

  static List<BottomNavigationBarItem> tabItems({int unreadCount = 0}) {
    return [
      _buildNavItem(Paths.clientprofile, Paths.clientprofile, ''),
      _buildNavItem(Paths.foldr, Paths.foldr, ''),
      _buildNavItem(Paths.chat, Paths.chat, '', badgeCount: unreadCount),
      _buildNavItem(Paths.task, Paths.task, ''),
      _buildNavItem(Paths.menu, Paths.menu, ''),
    ];
  }

  static BottomNavigationBarItem _buildNavItem(
    String icon,
    String activeIcon,
    String label, {
    int badgeCount = 0,
  }) {
    return BottomNavigationBarItem(
      icon: _withBadge(
        child: ImageWidget(image: icon, width: 26, color: AppColors.white),
        badgeCount: badgeCount,
      ),
      activeIcon: _withBadge(
        badgeCount: badgeCount,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(8.w),
          child: ImageWidget(image: icon, width: 26, color: AppColors.black),
        ),
      ),
      label: label,
    );
  }

  static Widget _withBadge({required Widget child, required int badgeCount}) {
    if (badgeCount <= 0) return child;
    final String display = badgeCount > 99 ? '99+' : '$badgeCount';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              display,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static BoxDecoration decor() {
    return BoxDecoration(
      color: AppColors.white,
      boxShadow: [
        BoxShadow(
          spreadRadius: 1.r,
          blurRadius: 8.r,
          color: AppColors.grey.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}
