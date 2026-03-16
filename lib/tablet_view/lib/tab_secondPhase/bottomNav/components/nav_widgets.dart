import 'package:flutter/cupertino.dart';

// import 'package:print_helper/secondPhase/chat/chat_list.dart';
import 'package:print_helper/secondPhase/projects/projects.dart';

import '../../../tab_constants/colors.dart';
import '../../Files/files_list.dart';

class NavWidgets {
  static List<Widget> screens = [
    // CustomersScreen(),
    const SizedBox(),
    FilesScreen(),
    // ChatList(),
    ProjectsPage(),
    const SizedBox(),
  ];

  static List<BottomNavigationBarItem> tabItems = [
    _buildNavItem(CupertinoIcons.person_2, CupertinoIcons.person_2, ''),
    _buildNavItem(CupertinoIcons.folder, CupertinoIcons.folder, ''),
    _buildNavItem(CupertinoIcons.text_bubble, CupertinoIcons.text_bubble, ''),
    _buildNavItem(CupertinoIcons.square_list, CupertinoIcons.square_list, ''),
    _buildNavItem(
      CupertinoIcons.line_horizontal_3_decrease,
      CupertinoIcons.line_horizontal_3_decrease,
      '',
    ),
  ];

  static BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 26, color: AppColors.black),
      activeIcon: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(8),
        child: Icon(activeIcon, size: 26, color: AppColors.black),
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
