import 'package:flutter/material.dart';

// import '../tab_utils/transitions_util.dart';
// import '../tab_widgets/offline_widget.dart';

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // static void pushNav() {
  //   final route = NavigationService.navigatorKey.currentState;
  //   if (route != null) {
  //     route.push(FadeRoute(page: const OfflineWidget()));
  //   }
  // }

  // static void pushReplcUntilBottom() {
  // final route = NavigationService.navigatorKey.currentState;
  // if (route != null) {
  //   route.pushAndRemoveUntil(
  //       FadeRoute(page: const BottomNavBar(pageNum: 0)), (route) => false);
  // }
  // }

  // static void popNav() {
  //   final route = NavigationService.navigatorKey.currentState;
  //   if (route != null) {
  //     route.pop();
  //   }
  // }
}
