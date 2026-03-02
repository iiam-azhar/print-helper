import 'package:flutter/cupertino.dart';

import '../../tab_widgets/tab_image_widget.dart';

import '../../tab_client/tab_clients_list.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';

class NavWidgets {
  static List<Widget> screens = [
    ClientScreen(isFromAdmin: true),
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
  ];

  static List<BottomNavigationBarItem> tabItems = [
    _buildNavItem(Paths.clientprofile, Paths.clientprofile, ''),
    _buildNavItem(Paths.foldr, Paths.foldr, ''),
    _buildNavItem(Paths.chat, Paths.chat, ''),
    _buildNavItem(Paths.task, Paths.task, ''),
    _buildNavItem(Paths.menu, Paths.menu, ''),
  ];

  static BottomNavigationBarItem _buildNavItem(
    String icon,
    String activeIcon,
    String label,
  ) {
    return BottomNavigationBarItem(
      icon: ImageWidget(image: icon, width: 26, color: AppColors.white),
      activeIcon: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(8),
        child: ImageWidget(image: icon, width: 26, color: AppColors.black),
      ),
      label: label,
    );
  }

  static BoxDecoration decor() {
    return BoxDecoration(
      color: AppColors.white,
      boxShadow: [
        BoxShadow(
          spreadRadius: 1,
          blurRadius: 8,
          color: AppColors.grey.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}
