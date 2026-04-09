import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../utils/textstyle_util.dart';
import '../../../widgets/image_widget.dart';
import '../../chat/provider/chat_pro.dart';
import '../../chat/view/chat_list.dart';
import '../../client/clients_list.dart';
import '../../drawer/drawer.dart';
import '../../../widgets/toasts.dart';

class StaffBottomBar extends StatefulWidget {
  final int pageNum;
  const StaffBottomBar({super.key, required this.pageNum});

  @override
  State<StaffBottomBar> createState() => _StaffBottomBarState();
}

class _StaffBottomBarState extends State<StaffBottomBar>
    with WidgetsBindingObserver {
  DateTime? currentBackPressTime;
  bool canPopNow = false;
  int pageNum = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    pageNum = widget.pageNum;
    _screens = [
      ClientScreen(
        isFromAdmin: false,
        isFromStaff: true,
        isFromClient: false,
        onChatTap: () => setState(() => pageNum = 2),
      ),
      const SizedBox(),
      const ChatList(),
      const SizedBox(),
      const SizedBox(),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() => pageNum = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Handle back button: go to first tab instead of exiting app
        if (pageNum != 0) {
          setState(() => pageNum = 0);
          return;
        }

        DateTime now = DateTime.now();
        if (currentBackPressTime == null ||
            now.difference(currentBackPressTime!) >
                const Duration(seconds: 2)) {
          currentBackPressTime = now;
          showToast(message: "press again to exit");
          setState(() {
            canPopNow = true;
          });

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                canPopNow = false;
              });
            }
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: CustomDrawer(
          isFromAdmin: false,
          isFromClient: false,
          isFromStaff: true,
        ),
        extendBody: true,
        body: IndexedStack(index: pageNum, children: _screens),
        bottomNavigationBar: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: decor(),
            child: Consumer<ChatPro>(
              builder: (_, chatPro, _) {
                final unread = chatPro.totalUnreadCount;
                return BottomNavigationBar(
                  onTap: _onItemTapped,
                  elevation: 0,
                  currentIndex: pageNum,
                  items: tabItems(unreadCount: unread),
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: AppColors.black,
                  selectedItemColor: AppColors.white,
                  unselectedItemColor: AppColors.white,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  selectedLabelStyle: TextStyleData.selectedNavLbl,
                  unselectedLabelStyle: TextStyleData.unSelectedNavLbl,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

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
        badgeCount: badgeCount,
        child: ImageWidget(image: icon, width: 26, color: AppColors.white),
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
    final display = badgeCount > 99 ? '99+' : '$badgeCount';
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
