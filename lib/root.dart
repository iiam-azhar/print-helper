import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/splash/splash.dart';
import 'package:print_helper/tablet_view/lib/tab_onboarding/tab_splash.dart';
import 'constants/colors.dart';
import 'constants/strings.dart';
import 'services/navigation_service.dart';
import 'services/call_device_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Helper function to detect if the device is a tablet
  /// Returns true if the shortest dimension is >= 600 dp
  bool _isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= 600;
  }

  @override
  void initState() {
    super.initState();
    // Setup call event listeners after the app is initialized
    CallDeviceService.setupCallListeners(
      onCallAnswered: (callerName, callerNumber) {
        // Android native ConnectionService UI handles the call interface.
        // No custom CallScreen needed.
        debugPrint("Call connected: $callerName ($callerNumber)");
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 830),
      minTextAdapt: true,
      builder: (context, child) {
        return SafeArea(
          top: false,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appName,
            navigatorKey: NavigationService.navigatorKey,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
              scaffoldBackgroundColor: AppColors.scaffold,
            ),
            home: _isTablet(context) ? const TabSplash() : const Splash(),
          ),
        );
      },
    );
  }
}
