// import 'dart:async';

// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:internet_connection_checker/internet_connection_checker.dart';

// import '../tab_utils/console_util.dart';
// import '../tab_utils/globals.dart' as globals;
// import 'navigation_service.dart';

// class ConnectivityCheck {
//   static void initialize() async {
//     await checkConnection();
//     // dataChannelCheck();
//     networkCheck();
//   }

//   static Future<bool> checkConnection() async {
//     // printData(data: '--> awaiting connectivity check result');
//     bool isOnline = false;
//     await Connectivity().checkConnectivity().then((connectivityResult) async {
//       final hasChannel = !(connectivityResult == ConnectivityResult.none);
//       if (hasChannel) {
//         await InternetConnectionChecker().connectionStatus.then((hasNet) {
//           if (hasNet == InternetConnectionStatus.connected) {
//             isOnline = true;
//             offlineNavState(true);
//             printData(data: '--> init channel and internet found');
//           } else {
//             isOnline = false;
//             offlineNavState(false);
//             printData(data: '--> no init channel and internet found');
//           }
//         });
//       } else {
//         isOnline = false;
//         offlineNavState(false);
//         printData(data: '-->  no init channel found');
//       }
//     });
//     return isOnline;
//   }

//   // static Future<void> dataChannelCheck() async {
//   //   // printData(data: '--> listening to onConnectivityChange activated');
//   //   Connectivity().onConnectivityChanged.listen((connectivityResult) async {
//   //     // printData(data: '--> checking for Connectivity Changes');
//   //     final hasChannel = !(connectivityResult == ConnectivityResult.none);
//   //     if (hasChannel) {
//   //       printData(data: '--> data channel found');
//   //       final hasNet = await InternetConnectionChecker().connectionStatus;
//   //       if (hasNet == InternetConnectionStatus.connected) {
//   //         offlineNavState(true);
//   //         printData(data: '--> data channel and internet found');
//   //       } else {
//   //         offlineNavState(false);
//   //         printData(data: '--> no data channel and internet found');
//   //       }
//   //     } else {
//   //       offlineNavState(false);
//   //       printData(data: '--> no data channel found');
//   //     }
//   //   });
//   // }

//   static void networkCheck() {
//     // printData(data: '--> listening to onStatusChange activated');
//     InternetConnectionChecker().onStatusChange.listen((status) {
//       // printData(data: '--> checking for InternetConnectionChecker Changes');
//       final hasInternet = (status == InternetConnectionStatus.connected);
//       printData(data: hasInternet ? '--> has internet' : '--> no internet');
//       offlineNavState(hasInternet);
//     });
//   }

//   static Future<void> refreshConnection() async {
//     await Connectivity().checkConnectivity().then((connectivityResult) async {
//       final hasChannel = !(connectivityResult == ConnectivityResult.none);
//       if (hasChannel) {
//         await InternetConnectionChecker().connectionStatus.then((hasNet) {
//           if (hasNet == InternetConnectionStatus.connected) {
//             offlineNavState(true);
//             printData(data: '--> refreshed data channel and internet found');
//           }
//         });
//       }
//     });
//   }

//   static void offlineNavState(bool hasInternet) {
//     if (globals.isAtOfflinePage && hasInternet) {
//       globals.isAtOfflinePage = false;
//       printData(title: ' offline : ', data: globals.isAtOfflinePage);
//       NavigationService.popNav();
//     } else if (!globals.isAtOfflinePage && !hasInternet) {
//       globals.isAtOfflinePage = true;
//       printData(title: ' offline : ', data: globals.isAtOfflinePage);
//       NavigationService.pushNav();
//     }
//   }
// }
