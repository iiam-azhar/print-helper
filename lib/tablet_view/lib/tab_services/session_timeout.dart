// import 'dart:async';

// import 'package:flutter/material.dart';

// import '../tab_constants/strings.dart';
// import '../screens/auth/login_page.dart';
// import '../tab_utils/console_util.dart';
// import '../tab_utils/transitions_util.dart';
// import '../tab_widgets/tab_toasts.dart';
// import 'helpers.dart';
// import 'navigation_service.dart';

// class SessionTimeout {
//   static Timer? sessionTimer;

//   static bool startUserSession() {
//     final route = NavigationService.navigatorKey.currentState!;
//     bool timeOut = false;

//     final userPro = getUserPro(route.context);
//     final user = userPro.user;

//     if (user.tokenExpiry.isNotEmpty) {
//       const int sessionMins = 0;
//       final now = DateTime.now();
//       const sessionDurtn = Duration(minutes: sessionMins);

//       final tokenExpiry = user.tokenExpiry;
//       printData(title: '----->', data: tokenExpiry);

//       final tokenExp = DateTime.parse(tokenExpiry);
//       printData(title: '----->', data: tokenExp);

//       final timeUntilExp = tokenExp.difference(now);
//       printData(title: '----->', data: timeUntilExp.inMinutes);

//       if (timeUntilExp > sessionDurtn) {
//         // for logged in user before expiry
//         final duration = timeUntilExp - sessionDurtn;
//         sessionTimer?.cancel(); // Cancel previous timer if exists
//         sessionTimer = Timer(duration, () async {
//           _sessionRouteClear(route);
//           userPro.deleteUserData();
//           sessionTimer = null; // Reset sessionTimer after canceling
//           timeOut = true;
//           printData(title: '----->', data: 'Session timedout now');
//           showToast(message: AppStrings.sessionTimedOut);
//         });
//       } else {
//         // for logged in user after expiry
//         _sessionRouteClear(route);
//         userPro.deleteUserData();
//         timeOut = true;
//         printData(title: '----->', data: 'Session timeout already');
//         showToast(message: AppStrings.sessionTimedOut);
//       }
//     }
//     return timeOut;
//   }

//   static void _sessionRouteClear(NavigatorState route) {
//     route.pushAndRemoveUntil(
//         FadeRoute(page: const LoginPage()), (route) => false);
//   }
// }
