import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SysChromes {
  static void setSystemChromes() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    // TODO: implement landscape as per new google policy (android 16+)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  static SystemUiOverlayStyle lightSystemChromes() =>
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      );
}
