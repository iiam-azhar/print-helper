import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/admin/customers/single_customer.dart';
import 'package:print_helper/services/helpers.dart';
import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../utils/textstyle_util.dart';
import '../../../widgets/image_widget.dart';
import '../../chat/view/chat_list.dart';
import '../../drawer/drawer.dart';
import '../../../utils/console_util.dart';

class CustBottomBar extends StatefulWidget {
  final int pageNum;
  const CustBottomBar({super.key, required this.pageNum});

  @override
  State<CustBottomBar> createState() => _CustBottomBarState();
}

class _CustBottomBarState extends State<CustBottomBar>
    with WidgetsBindingObserver {
  int pageNum = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    pageNum = widget.pageNum;
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
    final pro = getAuthPro(context);
    printData(title: "Cust Client ID:", data: pro.custClientId);
    return Scaffold(
      key: _scaffoldKey,
      drawer: CustomDrawer(
        isFromAdmin: false,
        // isFromClient: false,
        isFromClient: true,
        isFromStaff: false,
      ),
      extendBody: true,
      body: IndexedStack(
        index: pageNum,
        children: [
          // CustomersScreen(
          //   isFromAdmin: false,
          //   isFromStaff: false,
          //   isFromClient: false,
          //   id: pro.custClientId ?? 0,
          // ),
          SingleCustomer(
            isFromAdmin: false,
            isFromStaff: false,
            isFromClient: false,
            id: pro.custClientId ?? 0,
          ),
          const SizedBox(),
          ChatList(),
          const SizedBox(),
        ],
      ),
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
    );
  }

  // static List<Widget> screens = ;
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
