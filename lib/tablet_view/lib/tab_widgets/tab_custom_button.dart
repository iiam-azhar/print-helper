import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import 'tab_spacers.dart';
import 'tab_text_widget.dart';

class CustomButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Icon? icon;
  final double height;
  final double fontSize;
  final double borderWidth;
  final Color textColor;
  final Color buttonColor;
  final Color borderColor;
  final List<BoxShadow>? shadows;
  final bool stadium;
  final double width;
  final Gradient? gradient;
  final ViewCase? viewCase;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final String? t2;
  final Widget? iconSpacing;
  final bool showBorder;
  final bool leadIcon;
  final bool disabled;
  final FontWeight fontWeight;

  const CustomButton({
    super.key,
    required this.title,
    required this.onTap,
    this.height = 48,
    this.fontSize = 18,
    this.borderWidth = 1.2,
    this.borderRadius = 10,
    this.width = double.infinity,
    this.textColor = AppColors.white,
    this.buttonColor = AppColors.primary,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.stadium = true,
    this.showBorder = false,
    this.leadIcon = true,
    this.disabled = false,
    this.gradient,
    this.viewCase,
    this.shadows,
    this.t2,
    this.icon,
    this.iconSpacing,
    this.fontWeight = FontWeight.w600,
    Color? borderColor,
  }) : borderColor = borderColor ?? textColor;

  @override
  Widget build(BuildContext context) {
    final rippleClr = textColor.withValues(alpha: 0.08);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        margin: margin,
        clipBehavior: Clip.antiAlias,
        decoration: _buttonDecor(),
        child: Material(
          color: AppColors.tr,
          child: InkWell(
            onTap: disabled ? null : onTap,
            highlightColor: rippleClr,
            splashColor: rippleClr,
            child: Ink(
              width: width,
              height: height,
              child: Padding(
                padding: padding,
                child: Center(
                  child: icon != null ? _iconButton() : _buildTitle(title),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton() {
    final btList = [icon!, iconSpacing ?? Spacers.sbw8(), _buildTitle(title)];
    return FittedBox(
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: leadIcon ? btList : btList.reversed.toList(),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return t2 != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _title(title)),
              Spacers.sbw5(),
              Flexible(child: _title(t2!)), // for value items
            ],
          )
        : _title(title);
  }

  Widget _title(String title) {
    return Center(
      child: FittedBox(
        child: TextWidget(
          text: title,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          viewCase: viewCase,
        ),
      ),
    );
  }

  Decoration _buttonDecor() {
    final clr = gradient != null ? null : buttonColor;

    if (stadium) {
      final borderSide = BorderSide(color: borderColor, width: borderWidth);
      return ShapeDecoration(
        color: clr,
        gradient: gradient,
        shadows: shadows,
        shape: StadiumBorder(side: showBorder ? borderSide : BorderSide.none),
      );
    }

    final border = Border.all(color: borderColor, width: borderWidth);
    return BoxDecoration(
      color: clr,
      gradient: gradient,
      boxShadow: shadows,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder ? border : null,
    );
  }
}

class BackBtn extends StatelessWidget {
  const BackBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Align(
          alignment: AlignmentGeometry.centerLeft,
          child: Icon(
            Icons.keyboard_backspace,
            size: 30,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}
