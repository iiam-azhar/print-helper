import 'package:flutter/material.dart';

import '../../tab_constants/colors.dart';
import '../../tab_utils/textstyle_util.dart';
import 'components/nav_widgets.dart';

class BottomNavBar extends StatefulWidget {
  final int pageNum;

  const BottomNavBar({super.key, required this.pageNum});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with WidgetsBindingObserver {
  int pageNum = 0;

  @override
  void initState() {
    super.initState();
    // ConnectivityCheck.initialize();
    pageNum = widget.pageNum;
    // WidgetsBinding.instance.addObserver(this);
    // final notiPro = getNotiPro(context);
    // notiPro.firebaseInit(context);
  }

  @override
  void didChangeAppLifecycleState(state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      // final notiPro = getNotiPro(context);
      // notiPro.getNotiUnreadCount(context);
    }
  }

  void _onItemTapped(int index) => setState(() => pageNum = index);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(index: pageNum, children: NavWidgets.screens),
          bottomNavigationBar: Theme(
            data: ThemeData(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
              decoration: NavWidgets.decor(),
              child: BottomNavigationBar(
                onTap: _onItemTapped,
                elevation: 0,
                currentIndex: pageNum,
                items: NavWidgets.tabItems,
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.tr,
                selectedItemColor: AppColors.white,
                unselectedItemColor: AppColors.white,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                selectedLabelStyle: TextStyleData.selectedNavLbl,
                unselectedLabelStyle: TextStyleData.unSelectedNavLbl,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
