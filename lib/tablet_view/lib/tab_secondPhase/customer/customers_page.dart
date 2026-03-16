// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../../tab_constants/colors.dart';
// import '../../tab_models/tab_customer_models.dart';
// import 'package:provider/provider.dart';

// import 'package:print_helper/providers/${name}_pro.dart';
// import '../../tab_services/helpers.dart';
// import '../../tab_widgets/loaders.dart';
// import '../../tab_widgets/tab_spacers.dart';
// import '../../tab_widgets/tab_text_widget.dart';

// class CustomersScreen extends StatefulWidget {
//   const CustomersScreen({super.key});

//   @override
//   State<CustomersScreen> createState() => _CustomersScreenState();
// }

// class _CustomersScreenState extends State<CustomersScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final custPro = getCustPro(context);
//       custPro.getCustomers(ctx: context);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: _appBar(),
//       body: SafeArea(
//         child: Consumer<CustomerPro>(
//           builder: (context, pro, child) {
//             if (pro.customersLoad) {
//               return Center(child: showLoader());
//             }
//             final list = pro.customers;
//             return ListView(
//               padding: EdgeInsets.symmetric(horizontal: 14.w),
//               children: [
//                 Spacers.sb15(),
//                 _contactButton(),
//                 Spacers.sb15(),
//                 for (var item in list)
//                   item.contacts.length == 1
//                       ? _customerCard(
//                           title: item.title,
//                           type: item.type,
//                           date: item.date,
//                           projects: item.projectsFiles,
//                           phone: item.phone ?? "",
//                           email: item.email ?? "",
//                           lang: item.language ?? "",
//                         )
//                       : _multiCustomerCardDynamic(item),
//                 Spacers.sb30(),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   AppBar _appBar() {
//     return AppBar(
//       backgroundColor: AppColors.white,
//       surfaceTintColor: AppColors.white,
//       elevation: 0,
//       title: Row(
//         crossAxisAlignment: .end,
//         children: [
//           Icon(CupertinoIcons.person_2, color: AppColors.black, size: 25),
//           Spacers.sbw12(),
//           TextWidget(
//             text: "Customers",
//             fontWeight: FontWeight.bold,
//             fontSize: 20,
//             fontFam: MyFontFam.poppins,
//             color: Color(0XFF414345),
//           ),
//         ],
//       ),
//       actions: [
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(10.r),
//             border: Border.all(color: AppColors.primary),
//           ),
//           child: TextWidget(
//             text: "+ Customer",
//             fontWeight: FontWeight.w400,
//             fontSize: 10,
//             fontFam: MyFontFam.poppins,
//             color: Color(0XFF414345),
//           ),
//         ),
//         Spacers.sbw5(),
//         Icon(Icons.filter_alt_outlined, size: 25),
//         Spacers.sbw10(),
//       ],
//     );
//   }

//   Widget _contactButton() {
//     return Container(
//       height: 43.h,
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: AppColors.primary,
//         borderRadius: BorderRadius.circular(14.r),
//       ),
//       child: Center(
//         child: TextWidget(
//           text: "Contact Customers",
//           fontWeight: FontWeight.bold,
//           fontSize: 14,
//         ),
//       ),
//     );
//   }

//   Widget _customerCard({
//     required String title,
//     required String type,
//     required String date,
//     required String projects,
//     required String phone,
//     required String email,
//     required String lang,
//   }) {
//     return Card(
//       color: AppColors.white,
//       margin: EdgeInsets.only(bottom: 22.h),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
//       elevation: 3,
//       child: Padding(
//         padding: EdgeInsets.all(12.w),
//         child: Column(
//           crossAxisAlignment: .start,
//           children: [
//             Row(
//               crossAxisAlignment: .start,
//               children: [
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     crossAxisAlignment: .start,
//                     children: [
//                       TextWidget(
//                         text: title,
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       TextWidget(
//                         text: date,
//                         color: Colors.grey,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Spacer(),
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     crossAxisAlignment: .end,
//                     children: [
//                       TextWidget(
//                         text: type,
//                         fontWeight: FontWeight.w400,
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                       ),
//                       TextWidget(
//                         text: projects,
//                         fontWeight: FontWeight.w500,
//                         fontSize: 12,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             Divider(color: Colors.grey.shade300),
//             Row(
//               children: [
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       TextWidget(
//                         text: phone,
//                         fontSize: 12,
//                         color: AppColors.black,
//                         fontWeight: FontWeight.w400,
//                       ),
//                       Spacers.sb5(),
//                       TextWidget(
//                         text: email,
//                         fontSize: 12,
//                         color: AppColors.black,
//                         fontWeight: FontWeight.w400,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Spacer(),
//                 Expanded(flex: 5, child: _contactIcons(lang)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _contactIcons(String lang) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16.r),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: .spaceBetween,
//             children: [
//               Icon(CupertinoIcons.mail),
//               // Spacers.sbw15(),
//               Icon(CupertinoIcons.phone),
//               // Spacers.sbw15(),
//               Icon(CupertinoIcons.text_bubble),
//             ],
//           ),
//           Spacers.sb5(),
//           TextWidget(
//             text: lang,
//             fontSize: 11,
//             color: Colors.grey.shade600,
//             fontWeight: FontWeight.w400,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _multiCustomerCardDynamic(CustomerModel customer) {
//     return Card(
//       color: AppColors.white,
//       margin: EdgeInsets.only(bottom: 22.h),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
//       elevation: 3,
//       child: Padding(
//         padding: EdgeInsets.all(12.w),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               crossAxisAlignment: .start,
//               children: [
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     crossAxisAlignment: .start,
//                     children: [
//                       TextWidget(
//                         text: customer.title,
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       Spacers.sb5(),
//                       TextWidget(
//                         text: customer.date,
//                         color: Colors.grey,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Spacer(),
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     crossAxisAlignment: .end,
//                     children: [
//                       TextWidget(
//                         text: customer.type,
//                         fontWeight: FontWeight.w400,
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                       ),
//                       TextWidget(
//                         text: customer.projectsFiles,
//                         fontWeight: FontWeight.w500,
//                         fontSize: 12,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             Divider(color: Colors.grey.shade300),
//             for (var contact in customer.contacts)
//               Padding(
//                 padding: EdgeInsets.only(bottom: 10.h),
//                 child: _subContactDynamic(contact),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _subContactDynamic(ContactModel contact) {
//     return Container(
//       padding: EdgeInsets.all(12.w),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(14.r),
//         color: Colors.grey.shade50,
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 5,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 TextWidget(
//                   text: contact.name,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 Spacers.sb5(),
//                 TextWidget(
//                   text: contact.phone,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 TextWidget(
//                   text: contact.email,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w400,
//                 ),
//               ],
//             ),
//           ),
//           Spacer(),
//           Expanded(flex: 5, child: _contactIcons(contact.language)),
//         ],
//       ),
//     );
//   }
// }
