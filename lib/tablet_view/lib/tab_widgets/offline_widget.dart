// import 'package:flutter/material.dart';
//
// import 'package:provider/provider.dart';
// import '../tab_constants/colors.dart';
// import '../tab_constants/strings.dart';
// import '../tab_services/helpers.dart';
// import '../tab_utils/textstyle_util.dart';
// import 'button_widgets.dart';
// import 'tab_image_widget.dart';
// import 'loaders.dart';
// import 'tab_text_widget.dart';

// class OfflineWidget extends StatefulWidget {
//   const OfflineWidget({super.key});
//   @override
//   State<OfflineWidget> createState() => _OfflineWidgetState();
// }

// class _OfflineWidgetState extends State<OfflineWidget> {
//   bool loading = false;
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         extendBody: true,
//         body: Center(
//           child: loading
//               ? showLoader
//               : SafeArea(
//                   child: SingleChildScrollView(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         _myCardTile(),
//                         infoWidget(),
//                       ],
//                     ),
//                   ),
//                 ),
//         ),
//         bottomNavigationBar: Theme(
//           data: ThemeData(
//             splashColor: Colors.transparent,
//             highlightColor: Colors.transparent,
//           ),
//           child: Container(
//             margin: EdgeInsets.all(14.w),
//             decoration: NavComponents.decor(),
//             child: BottomNavigationBar(
//               elevation: 0,
//               items: NavComponents().tabItems,
//               type: BottomNavigationBarType.fixed,
//               backgroundColor: AppColors.trColor,
//               selectedItemColor: const Color(0xff6D7278),
//               unselectedItemColor: const Color(0xff6D7278),
//               selectedLabelStyle: TextStyleData.selectedNavLbl,
//               unselectedLabelStyle: TextStyleData.unSelectedNavLbl,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget infoWidget() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 40.w),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           SizedBox(height: 10.w),
//           ImageWidget(
//             image: Paths.noInternet,
//             height: 150.w,
//             width: 150.w,
//           ),
//           const FittedBox(
//             child: TextWidget(
//               text: AppStrings.noConnection,
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Color(0xff6D7278),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           SizedBox(height: 10.w),
//           const FittedBox(
//             child: TextWidget(
//               text: AppStrings.noInternet,
//               fontSize: 20,
//               fontWeight: FontWeight.w300,
//               color: Color(0xff6D7278),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           SizedBox(height: 30.w),
//           customButton(
//             title: AppStrings.retry,
//             padding: EdgeInsets.zero,
//             onPressed: () async {
//               setState(() {
//                 loading = true;
//               });
//               await ConnectivityCheck.refreshConnection();
//               await delayedCallback(milliseconds: 500, () {
//                 setState(() {
//                   loading = false;
//                 });
//               });
//             },
//           ),
//           SizedBox(height: 30.w),
//         ],
//       ),
//     );
//   }

//   Widget _myCardTile() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16.w),
//       child: Consumer<AuthProvider>(builder: (context, snapshot, child) {
//         final crdNo = snapshot.user.myCardNo;
//         final crdName = snapshot.user.myCardName;
//         return crdNo.isEmpty
//             ? const SizedBox()
//             : Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 25.w),
//                 decoration: _decor1(),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         buildUserDetails(crdName),
//                         const Spacer(),
//                         ImageWidget(
//                           image: Paths.logoClr,
//                           height: 35.h,
//                           width: 122.w,
//                           fit: BoxFit.cover,
//                         )
//                       ],
//                     ),
//                     SizedBox(height: 40.h),
//                     buildCardDetails(crdNo),
//                   ],
//                 ),
//               );
//       }),
//     );
//   }

//   Widget buildUserDetails(String name) {
//     return Flexible(
//       flex: 6,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const TextWidget(
//             text: AppStrings.name,
//             fontSize: 14,
//             fontWeight: FontWeight.w300,
//             color: AppColors.whiteColor,
//             viewCase: ViewCase.upper,
//           ),
//           FittedBox(
//             child: TextWidget(
//               text: name,
//               trOn: false,
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: AppColors.whiteColor,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildCardDetails(String cardNo) {
//     return Column(
//       children: [
//         TextWidget(
//           text: cardNo,
//           trOn: false,
//           fontSize: 18,
//           fontWeight: FontWeight.bold,
//           color: AppColors.whiteColor,
//         ),
//         SizedBox(height: 10.h),
//         Container(
//           height: 60.h,
//           width: double.infinity,
//           padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 8.h),
//           decoration: _decor2(),
//           child: _barCode(cardNo),
//         ),
//       ],
//     );
//   }

//   Widget _barCode(String cardNumber) {
//     final cn = cardNumber.removeSpaces;
//     final myBarcode = Barcode.code128();
//     final svgImg = myBarcode.toSvg(
//       cn,
//       drawText: false,
//       width: 340.w,
//       height: 80.h,
//     );
//     return ImageWidget(
//       image: svgImg,
//       svgString: true,
//     );
//   }

//   BoxDecoration _decor1() {
//     return BoxDecoration(
//       borderRadius: BorderRadius.circular(20.r),
//       gradient: const LinearGradient(
//         colors: [
//           Color(0xffD8B10F),
//           Color(0xff00A79D),
//         ],
//         stops: [.1, 1],
//         begin: Alignment.centerLeft,
//         end: Alignment.centerRight,
//       ),
//       image: const DecorationImage(
//         fit: BoxFit.cover,
//         opacity: .3,
//         image: AssetImage(Paths.bg),
//       ),
//     );
//   }

//   BoxDecoration _decor2() {
//     return BoxDecoration(
//       borderRadius: BorderRadius.circular(12.r),
//       color: AppColors.whiteColor,
//     );
//   }
// }
