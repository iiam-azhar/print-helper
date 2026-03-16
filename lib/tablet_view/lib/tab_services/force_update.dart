// import 'dart:io';

// import 'package:flutter/material.dart';

// import '../tab_constants/strings.dart';
// import '../screens/onBoarding/force_update_page.dart';
// import '../tab_utils/console_util.dart';
// import '../tab_utils/extensions.dart';
// import '../tab_widgets/tab_custom_prompts.dart';
// import 'api_routes.dart';
// import 'api_service.dart';

// class ForceUpdate {
//   static Future<void> checkForAppUpdate({
//     required BuildContext ctx,
//     required VoidCallback onNoUpdate,
//     required Function(bool isForce) onUpdateAvailable,
//   }) async {
//     try {
//       final isIos = Platform.isIOS;
//       final platform = isIos ? 'ios' : 'android';
//       final build = isIos ? AppStrings.iosBuild : AppStrings.androidBuild;

//       final data = await ApiService().getDataFromApi(
//         api: ApiRoutes.appVersion(platform: platform, build: build),
//       );

//       final remoteBuild = '${data['build']}'.toInt;
//       // TODO chnage the isForce with this on production
//       // final isForce = data?['force_update'] != false;
//       final isForce = data?['force_update'] != true;
//       final hasUpdate = remoteBuild > build.toInt || isForce;
//       // final hasUpdate = data?['updateNeeded'] == true || isForce;

//       if (hasUpdate) {
//         printData(data: '---> update needed');
//         onUpdateAvailable(isForce);
//       } else {
//         printData(data: '---> no update needed');
//         onNoUpdate();
//       }
//     } catch (e) {
//       onNoUpdate();
//       printData(title: 'from checkForAppUpdate', data: '$e', e: true);
//     }
//   }

//   static void showUpdate(bool isForce, {required BuildContext ctx}) async =>
//       await CustomPrompts.showAlert(
//         ctx: ctx,
//         child: ForceUpdatePage(isForce: isForce),
//       );
// }
