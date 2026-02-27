import 'package:delayed_display/delayed_display.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:print_helper/auth/login_screen.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/services/call_device_service.dart';

import '../../constants/strings.dart';
import '../../services/helpers.dart';
import '../admin/adminBottombar/admin_bottombar.dart';
import '../admin/client/bottombar/client_bottombar.dart';
import '../admin/customers/bottombar/cust_bottombar.dart';
import '../admin/staff/bottombar/staff_bottombar.dart';
import '../constants/paths.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _initApp(context);
  }

  Future<void> _initApp(dynamic context) async {
    await delayed(
      millisec: 2000,
      callback: () async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString("token");
        final role = prefs.getString("role_name");
        if (token != null && token.isNotEmpty) {
          await Provider.of<AuthPro>(
            context,
            listen: false,
          ).loadUserFromPrefs();
          await CallDeviceService.bootstrap(forceRegister: false);
          _navigateByRole(role);
        } else {
          navTo(context: context, page: const LoginScreen(), removeUntil: true);
        }
      },
    );
  }

  void _navigateByRole(String? role) {
    switch (role) {
      case "ADMIN":
        navTo(
          context: context,
          page: AdminBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;

      case "CONTACT":
        navTo(
          context: context,
          page: ClientBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;

      case "STAFF":
        navTo(
          context: context,
          page: StaffBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;

      case "CUSTOMER":
        navTo(
          context: context,
          page: CustBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;

      default:
        navTo(context: context, page: const LoginScreen(), removeUntil: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ImageWidget(image: Paths.bgg, fit: BoxFit.cover),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: DelayedDisplay(
            slidingBeginOffset: const Offset(0, -0.35),
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
