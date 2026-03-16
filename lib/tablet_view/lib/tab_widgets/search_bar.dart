import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import '../tab_utils/textstyle_util.dart';

class SearchBarUi extends StatelessWidget {
  final String tag;
  final TextEditingController? controller;
  final EdgeInsetsGeometry? margin;
  final void Function(String)? onSearch;
  final void Function(String)? onChanged;

  const SearchBarUi({
    super.key,
    required this.tag,
    this.controller,
    this.margin,
    this.onSearch,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: tag,
        child: Material(
          color: AppColors.tr,
          child: Container(
            margin:
                margin ?? EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x79D0D1D2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: _searchField(context)),
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final bool readOnly = onChanged == null;
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(fontSize: 16),
      cursorColor: AppColors.primary,
      textInputAction: TextInputAction.search,
      autofocus: readOnly ? false : true,
      onTap: () => readOnly ? _navToSearch(context) : null,
      onChanged: onChanged,
      onSubmitted: onSearch,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'AppStringshatsOnMind',
        hintStyle: TextStyleData.formHintStyle,
        prefixIcon: Icon(
          CupertinoIcons.search,
          size: 19,
          color: AppColors.hint,
        ),
        // suffixIcon: readOnly ? null : _suffixLoader(),
        filled: true,
        fillColor: AppColors.tr,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // Widget _suffixLoader() {
  //   return Selector<ProductPro, bool>(
  //     selector: (_, snapshot) => snapshot.isLoading,
  //     builder: (_, load, __) => load ? showLoader() : const SizedBox.shrink(),
  //   );
  // }

  // Widget _searchButton(BuildContext context) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: AppColors.secondary,
  //       shape: BoxShape.circle,
  //       boxShadow: <BoxShadow>[
  //         BoxShadow(
  //           color: Colors.greyithValues(alpha:0.4),
  //           offset: Offset(0, 2),
  //           blurRadius: 8.r,
  //         ),
  //       ],
  //     ),
  //     child: Material(
  //       color: Colors.transparent,
  //       child: InkWell(
  //         customBorder: const CircleBorder(),
  //         onTap: () {
  //           if (onSearch != null && controller != null) {
  //             final query = controller!.text;
  //             onSearch!(query);
  //           } else {
  //             _navToSearch(context);
  //           }
  //         },
  //         child: Padding(
  //           padding: EdgeInsets.all(16),
  //           child: Icon(
  //             Icons.search,
  //             size: 24.sp,
  //             color: AppColorshite,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  void _navToSearch(BuildContext context) {
    // Navigator.push(
    //   context,
    //   SlideRightRoute(page: const SearchPage()),
    // );
  }
}
