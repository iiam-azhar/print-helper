import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import '../tab_services/navigation_service.dart';
import '../tab_utils/console_util.dart';

class Loaders {
  static final _navKey = NavigationService.navigatorKey;

  static void show() {
    if (_navKey.currentState?.context != null) {
      showDialog(
        barrierDismissible: false,
        context: _navKey.currentState!.context,
        barrierColor: Colors.white.withValues(alpha: 0.6),
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: AppColors.tr,
              child: Center(child: showLoader(centered: true)),
            ),
          );
        },
      );
    }
  }

  static void hide() {
    try {
      if (_navKey.currentState?.overlay?.context != null &&
          Navigator.canPop(_navKey.currentState!.overlay!.context)) {
        Navigator.of(_navKey.currentState!.overlay!.context).pop();
      }
    } catch (e) {
      printData(title: 'From Loader Hide', data: e, e: true);
    }
  }
}

Widget showLoader({
  double size = 12,
  Color color = AppColors.black,
  bool centered = false,
}) => centered ? Center(child: _loader(color, size)) : _loader(color, size);

Widget _loader(Color color, double size) =>
    CupertinoActivityIndicator(color: color, radius: size);

Widget fullLoaderWhite = Container(
  color: Colors.white38,
  height: double.infinity,
  width: double.infinity,
  child: showLoader(),
);

Widget fullLoaderblack = Container(
  color: Colors.black38,
  height: double.infinity,
  width: double.infinity,
  child: showLoader(),
);
