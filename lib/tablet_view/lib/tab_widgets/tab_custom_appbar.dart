import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tab_text_widget.dart';
import '../tab_constants/colors.dart';
import '../tab_services/helpers.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final SystemUiOverlayStyle systemOverlayStyle;

  final bool fromHome;
  final bool hasBack;
  final String? title;
  final bool inverted;
  final VoidCallback? onBackTap;
  // final bool hasLogo;
  // final bool hasHome;
  // final bool showLeading;
  // final bool showTrailing;
  // final Color bgColor;
  // final Widget? action;
  // final String? tag;
  // final Color backBg;

  const CustomAppBar({
    super.key,
    this.fromHome = false,
    this.hasBack = true,
    this.inverted = false,
    this.title,
    this.onBackTap,
    this.systemOverlayStyle = SystemUiOverlayStyle.dark,
    // this.action,
    // this.tag,
    // this.backBg = const Color(0xB6FFFFFF),
    // this.bgColor = AppColors.tr,
    // thisasLogo = false,
    // thisasHome = false,
    // this.showLeading = true,
    // this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 110,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: _buildLeading(context),
      title: TextWidget(
        text: title!,
        fontSize: 19,
        color: AppColors.white,
        fontWeight: FontWeight.w600,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondary, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    return hasBack
        ? IconButton(
            onPressed: onBackTap ?? () => Navigator.pop(context),
            icon: Transform.flip(
              flipX: !isEn,
              child: Icon(
                Icons.reply_outlined,
                size: 20,
                color: inverted ? AppColors.tertiary : AppColors.white,
              ),
            ),
          )
        : fromHome
        ? IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            style: IconButton.styleFrom(shape: const CircleBorder()),
            icon: Icon(
              Icons.sort_rounded,
              size: 26,
              color: AppColors.primary,
            ),
          )
        : SizedBox(
            width: kMinInteractiveDimension,
            height: kMinInteractiveDimension,
          );
  }

  @override
  Size get preferredSize => Size.fromHeight(90);
}
