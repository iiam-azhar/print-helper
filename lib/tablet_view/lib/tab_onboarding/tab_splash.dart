import 'package:delayed_display/delayed_display.dart';
import 'package:flutter/material.dart';
import '../tab_auth/tab_login_screen.dart';
import '../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tab_constants/strings.dart';
import '../tab_services/helpers.dart';
import '../tab_constants/paths.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../tab_sidePanel/dashboard_wrapper.dart';

class TabSplash extends StatefulWidget {
  const TabSplash({super.key});

  @override
  State<TabSplash> createState() => _TabSplashState();
}

class _TabSplashState extends State<TabSplash> {
  @override
  void initState() {
    super.initState();
    navHome(context);
  }

  void navHome(dynamic context) async {
    await delayed(
      millisec: 2000,
      callback: () async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString("token");
        final role = prefs.getString("role_name");
        debugPrint("$role role nameee");
        if (token != null && token.isNotEmpty) {
          await Provider.of<AuthPro>(
            context,
            listen: false,
          ).loadUserFromPrefs();
          _navigateByRole(role, context);
        } else {
          // Not logged in → show login
          navTo(context: context, page: const TabLoginScreen());
        }
      },
    );
  }

  void _navigateByRole(String? role, BuildContext context) {
    switch (role) {
      case "ADMIN":
        // navTo(context: context, page: AdminBottomBar(pageNum: 0));
        navTo(
          context: context,
          page: DashboardWrapper(role: "ADMIN"),
          removeUntil: true,
        );
        break;
      case "CONTACT":
        navTo(
          context: context,
          page: DashboardWrapper(role: "CONTACT"),
          removeUntil: true,
        );
        break;
      case "STAFF":
        navTo(
          context: context,
          page: DashboardWrapper(role: "STAFF"),
          removeUntil: true,
        );
        break;
      case "CUSTOMER":
        // showToast(message: "Updation currently going on");
        navTo(
          context: context,
          removeUntil: true,
          page: DashboardWrapper(role: "CUSTOMER"),
        );
        break;
      default:
        navTo(
          context: context,
          page: const TabLoginScreen(),
          removeUntil: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // BgWidget.bgImage(true),
        Positioned.fill(
          child: Image.asset(
            Paths.logBg,
            fit: BoxFit.fitWidth,
            opacity: AlwaysStoppedAnimation(.40),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: DelayedDisplay(
            slidingBeginOffset: Offset(0, -0.35),
            slidingCurve: Curves.bounceOut,
            child: Center(
              child: Hero(
                tag: AppStrings.appName,
                child: ImageWidget(image: Paths.logoWhite, width: 250),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
