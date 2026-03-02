import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import '../tab_constants/strings.dart';
import 'tab_image_widget.dart';
import 'tab_spacers.dart';
import 'tab_text_widget.dart';

class CustomPrompts {
  static Future<void> showAlert({
    required BuildContext ctx,
    String message = '',
    VoidCallback? onConfirmTap,
    bool isPositive = false,
    Widget? child,
  }) async {
    await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) =>
          child ?? CustomAlert(message: message, isPositive: isPositive),
    ).then((confirmed) {
      if (confirmed == true) onConfirmTap!();
    });
  }

  static void showInfo({
    required String img,
    required String title,
    String subTitle = '',
    required BuildContext ctx,
  }) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) =>
          CustomInfo(img: img, title: title, subTitle: subTitle),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required Widget child,
    required BuildContext ctx,
    Color bgColor = AppColors.white,
  }) async {
    return await showModalBottomSheet<T>(
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      context: ctx,
      builder: (BuildContext context) => child,
    );
  }

  static Widget showEmptyInfo({
    required String text,
    String image = '',
    IconData? icon,
    String? subText,
    double ht = 180,
    double wt = 180,
    double fs = 16,
    double iconSize = 60,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image.isNotEmpty)
            ImageWidget(image: image, height: ht, width: wt)
          else
            Icon(
              icon,
              size: iconSize,
              // color: const Color(0x87D0D1D2),
              color: AppColors.grey,
            ),
          Spacers.sb20(),
          TextWidget(
            text: text,
            fontSize: fs,
            fontWeight: FontWeight.w500,
            // color: const Color(0xCCD0D1D2),
            color: AppColors.grey,
            textAlign: TextAlign.center,
          ),
          if (subText != null)
            TextWidget(
              text: subText,
              fontSize: fs - 2,
              fontWeight: FontWeight.w400,
              // color: const Color(0xCCD0D1D2),
              color: AppColors.grey,
              textAlign: TextAlign.center,
            ),
          Spacers.sb50(),
        ],
      ),
    );
  }
}

class CustomAlert extends StatelessWidget {
  final String message;
  final bool isPositive;
  const CustomAlert({
    super.key,
    required this.message,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, color: AppColors.white, size: 20),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: AppColors.formHint,
                  ),
                ),
              ),
            ),
            TextWidget(
              text: message,
              textAlign: TextAlign.center,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
            Spacers.sb30(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  buttons(AppStrings.yes, 0, context, isPositive: isPositive),
                  Spacers.sbw15(),
                  buttons(AppStrings.no, 1, context, isPositive: isPositive),
                ],
              ),
            ),
            SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget buttons(
    String text,
    int index,
    BuildContext ctx, {
    bool isPositive = false,
  }) {
    final isPosBtn = isPositive ? index == 0 : index == 1;
    final txtColor = isPosBtn ? AppColors.white : AppColors.black;

    const linearGradient = LinearGradient(
      colors: [AppColors.tertiary, Color(0xFFA38A50)],
    );

    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pop(ctx, index == 0),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: ShapeDecoration(
            gradient: isPosBtn ? linearGradient : null,
            shape: StadiumBorder(
              side: isPosBtn
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xff6D7278)),
            ),
          ),
          child: Center(
            child: TextWidget(
              text: text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: txtColor,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomInfo extends StatelessWidget {
  final String img;
  final String title;
  final String subTitle;
  const CustomInfo({
    super.key,
    required this.img,
    required this.title,
    required this.subTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 57),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      child: Padding(padding: EdgeInsets.all(12), child: infoWidget(context)),
    );
  }

  Widget infoWidget(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 14),
        Align(
          alignment: Alignment.topRight,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 30),
            ),
          ),
        ),
        ImageWidget(image: img, height: 120, width: 120),
        SizedBox(height: 11),
        TextWidget(
          text: title,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xff6D7278),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        if (subTitle.isNotEmpty) ...[
          TextWidget(
            text: subTitle,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xff6D7278),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 60),
        ],
      ],
    );
  }
}
