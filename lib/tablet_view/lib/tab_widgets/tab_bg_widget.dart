import 'package:delayed_display/delayed_display.dart';
import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';
import 'tab_image_widget.dart';

class BgWidget {
  static Widget bgWidget({Color? color, required DelayedDisplay child}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          gradient: color != null ? null : _gradient(),
        ),
        child: Column(
          children: [
            const Spacer(flex: 3),
            Expanded(
              flex: 4,
              child: bgImage(color != null && color == AppColors.primary),
            ),
          ],
        ),
      );

  static LinearGradient _gradient() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.secondary, AppColors.secondary],
    );
  }

  static Widget bgImage(bool isPrimary) {
    return ImageWidget(
      width: double.infinity,
      image: Paths.bg,
      fit: BoxFit.cover,
      color: isPrimary ? null : AppColors.primary,
    );
  } //color: Color(0x5AD0D1D2)

  static Widget bgImage2(bool isPrimary) {
    return ImageWidget(
      width: double.infinity,
      image: Paths.bg2,
      fit: BoxFit.cover,
      color: isPrimary ? null : AppColors.primary,
    );
  } //color: Color(0x5AD0D1D2)
}
