import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/providers/email_pro.dart';
import 'package:print_helper/providers/navigation_pro.dart';
import 'package:print_helper/splash/splash.dart';
import 'package:print_helper/tablet_view/lib/tab_onboarding/tab_splash.dart';
import 'package:print_helper/widgets/global_upload_overlay.dart';
import 'package:provider/provider.dart';
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
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _lastHandledLink;

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

    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check for initial link when app is opened from a cold start
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen for incoming links while the app is in background or foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("DEEP LINK RECEIVED: $uri");

    // Deduplicate: ignore if we already handled this exact link
    if (_lastHandledLink == uri) return;
    _lastHandledLink = uri;

    final section = uri.queryParameters['section'];
    final status = uri.queryParameters['status'];

    if (section == 'email') {
      // Use NavigationPro to signal DashboardWrapper to switch to the email page
      context.read<NavigationPro>().setTargetPage('email');

      // If it was a success, refresh the mail data automatically
      if (status == 'success') {
        context.read<EmailPro>().fetchMailData(context);
      }
    }
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
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: FlutterQuillLocalizations.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.white),
              scaffoldBackgroundColor: AppColors.white,
            ),
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  const GlobalUploadOverlay(),
                ],
              );
            },
            home: _isTablet(context) ? const TabSplash() : const Splash(),
          ),
        );
      },
    );
  }
}
