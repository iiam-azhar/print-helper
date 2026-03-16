import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../utils/textstyle_util.dart';
import '../drawer/drawer.dart';
import '../../widgets/toasts.dart';
import 'nav_widgets.dart';
import '../chat/provider/chat_pro.dart';

class AdminBottomBar extends StatefulWidget {
  final int pageNum;
  const AdminBottomBar({super.key, required this.pageNum});

  @override
  State<AdminBottomBar> createState() => _AdminBottomBarState();
}

class _AdminBottomBarState extends State<AdminBottomBar>
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
    _screens = NavWidgets.buildScreens(
      onChatTap: () => setState(() => pageNum = 2),
    );
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
          isFromAdmin: true,
          isFromClient: false,
          isFromStaff: false,
        ),
        extendBody: true,
        body: IndexedStack(index: pageNum, children: _screens),
        bottomNavigationBar: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: NavWidgets.decor(),
            child: Consumer<ChatPro>(
              builder: (_, chatPro, _) {
                final unread = chatPro.totalUnreadCount;
                return BottomNavigationBar(
                  onTap: _onItemTapped,
                  elevation: 0,
                  currentIndex: pageNum,
                  items: NavWidgets.tabItems(unreadCount: unread),
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
}
