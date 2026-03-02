import 'package:flutter/material.dart';
import '../../tab_constants/colors.dart';
import '../../tab_utils/textstyle_util.dart';
import '../tab_drawer/tab_drawer.dart';
import 'tab_nav_widgets.dart';

class AdminBottomBar extends StatefulWidget {
  final int pageNum;
  const AdminBottomBar({super.key, required this.pageNum});

  @override
  State<AdminBottomBar> createState() => _AdminBottomBarState();
}

class _AdminBottomBarState extends State<AdminBottomBar>
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: CustomDrawer(),
      extendBody: true,
      body: IndexedStack(index: pageNum, children: NavWidgets.screens),
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Container(
          decoration: NavWidgets.decor(),
          child: BottomNavigationBar(
            onTap: _onItemTapped,
            elevation: 0,
            currentIndex: pageNum,
            items: NavWidgets.tabItems,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.black,
            selectedItemColor: AppColors.white,
            unselectedItemColor: AppColors.white,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedLabelStyle: TextStyleData.selectedNavLbl,
            unselectedLabelStyle: TextStyleData.unSelectedNavLbl,
          ),
        ),
      ),
    );
  }
}
