import 'package:flutter/material.dart';
import 'tab_onboarding/tab_splash.dart';
import 'tab_chat/view/components/tab_audio_manager.dart';
import 'tab_constants/colors.dart';
import 'tab_constants/strings.dart';
import 'tab_services/navigation_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void reassemble() {
    VoiceAudioManager.instance.reset();
    super.reassemble();
  }

  @override
  void dispose() {
    // Ensure cleanup on full exit
    VoiceAudioManager.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        // localizationsDelegates: context.localizationDelegates,
        // supportedLocales: context.supportedLocales,
        // locale: context.locale,
        home: const TabSplash(),

        // LoginScreen(),
      ),
    );
  }
}
