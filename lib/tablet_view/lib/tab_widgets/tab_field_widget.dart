import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tab_constants/colors.dart';
import '../tab_utils/regx.dart';
import '../tab_utils/textstyle_util.dart';
import 'tab_text_widget.dart';

class CustomTextField extends StatelessWidget {
  final String? regErrorText;
  final String? errorText;
  final String? hintText;
  final String? labelText;
  final String? prefixText;
  final bool digit;
  final bool isDouble;
  final bool alphaWithSpaceOnly;
  final bool readOnly;
  final bool enabled;
  final bool passField;
  final bool obscureText;
  final bool? outlined;
  final bool? filled;
  final Color? fillColor;
  final int? minLines;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final RegExp regExpCondition;
  final InputBorder? border;
  final TextEditingController? controller;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? outPadding;
  final double bRadius;
  final bool? isDence;
  final TextStyle? style;
  final TextStyle? errorStyle;
  final bool autoValidate;
  final bool autofocus;
  final FloatingLabelBehavior floatingLabelBehavior;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final void Function()? onTapOutside;
  const CustomTextField({
    super.key,
    required this.regExpCondition,
    this.maxLines = 1,
    this.digit = false,
    this.isDouble = false,
    this.alphaWithSpaceOnly = false,
    this.readOnly = false,
    this.enabled = true,
    this.passField = false,
    this.obscureText = false,
    this.minLines,
    this.regErrorText,
    this.outlined,
    this.filled,
    this.fillColor,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.focusNode,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.prefixText,
    this.border,
    this.padding,
    this.outPadding,
    this.bRadius = 10,
    this.isDence,
    this.style,
    this.errorStyle,
    this.autoValidate = true,
    this.autofocus = false,
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      focusNode: focusNode,
      obscuringCharacter: '●',
      obscureText: obscureText && passField,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      keyboardType: digit
          ? TextInputType.number
          : isDouble
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: digit
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength ?? 8),
            ]
          : isDouble
          ? [
              FilteringTextInputFormatter.allow(Regx.double2RegExp),
              LengthLimitingTextInputFormatter(maxLength ?? 8),
            ]
          : alphaWithSpaceOnly
          ? [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))]
          : null,
      style:
          style ??
          FontUtils.getFontStyle(
            fontFamily: MyFontFam.poppins,
            color: AppColors.black,
            fontWeight: FontWeight.w400,
            fontSize: 15.0,
          ),
      autovalidateMode: autoValidate
          ? AutovalidateMode.onUserInteraction
          : null,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText?.tr(),
        labelText: labelText?.tr(),
        filled: filled,
        fillColor: fillColor,
        isDense: isDence,
        enabled: enabled,
        hintStyle: FontUtils.getFontStyle(
          fontFamily: MyFontFam.poppins,
          color: AppColors.hint,
          fontWeight: FontWeight.w400,
          fontSize: 12.0,
        ),
        labelStyle: labelStyle(AppColors.hint),
        floatingLabelStyle: labelStyle(AppColors.hint),
        errorStyle:
            errorStyle ??
            FontUtils.getFontStyle(
              fontFamily: MyFontFam.poppins,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.red,
            ),
        floatingLabelBehavior: floatingLabelBehavior,
        prefixIcon: prefixIcon,
        prefix: prefix,
        suffix: suffix,
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints(minWidth: 55, minHeight: 2),
        prefixText: prefixText,
        errorMaxLines: 4,
        border: outlined == null ? InputBorder.none : null,
        contentPadding: (outlined != null && outlined == true)
            ? outPadding ?? EdgeInsets.symmetric(vertical: 10, horizontal: 10)
            : padding,
        focusedBorder: _border(color: AppColors.tertiary, radius: bRadius),
        enabledBorder: _border(color: AppColors.formHint, radius: bRadius),
        errorBorder: _border(color: AppColors.red, radius: bRadius),
        focusedErrorBorder: _border(color: AppColors.red, radius: bRadius),
        disabledBorder: _border(radius: bRadius),
      ),
      validator: (value) {
        if (value!.trim().isEmpty) {
          return errorText?.tr();
        }
        if (!regExpCondition.hasMatch(value)) {
          return regErrorText?.tr();
        }
        return null;
      },
    );
  }

  static TextStyle labelStyle(Color color) {
    return TextStyleData.formHintStyle.copyWith(fontSize: 15, color: color);
  }

  InputBorder _border({
    Color color = AppColors.formHint,
    double radius = 10.0,
    double width = 1.2,
  }) {
    if (outlined != null && outlined == false) {
      return UnderlineInputBorder(borderSide: BorderSide(color: color));
    } else {
      return OutlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
        borderRadius: BorderRadius.circular(radius),
      );
    }
  }
}

class CustomDropdownField<T> extends StatelessWidget {
  final List<T> items;
  final T? value;
  final void Function(T?)? onChanged;
  final Widget? hint;
  final Widget? icon;
  final bool outlined;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final BoxConstraints? prefixIconConstraints;
  final String? errorText;
  final bool autoValidate;
  final bool noBorder;
  final Color fillColor;
  final Color labelColor;
  final Color selectedItemColor;
  final double fontSize;
  final String? labelText;
  final bool alignedDropdown;
  final List<T> disabledItems;
  final String Function(T item)? displayText;

  const CustomDropdownField({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.icon,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.labelText,
    this.displayText,
    this.prefixIconConstraints,
    this.labelColor = AppColors.grey,
    this.selectedItemColor = AppColors.black,
    this.fontSize = 14,
    this.disabledItems = const [],
    this.outlined = true,
    this.autoValidate = true,
    this.fillColor = AppColors.tr,
    this.noBorder = false,
    this.alignedDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
      alignedDropdown: alignedDropdown,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        onChanged: onChanged,
        icon: icon,
        hint: hint,
        iconSize: 24,
        isExpanded: true,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        dropdownColor: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        style: TextStyleData.formHintStyle.copyWith(color: AppColors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefixIconConstraints: prefixIconConstraints,
          labelText: labelText?.tr(),
          labelStyle: labelStyle(fontSize, labelColor),
          border: _fieldBorder(noBorder: noBorder),
          focusedBorder: _fieldBorder(
            color: AppColors.tertiary,
            noBorder: noBorder,
          ),
          enabledBorder: _fieldBorder(
            color: AppColors.formHint,
            noBorder: noBorder,
          ),
          errorBorder: _fieldBorder(color: AppColors.red, noBorder: noBorder),
          focusedErrorBorder: _fieldBorder(
            color: AppColors.red,
            noBorder: noBorder,
          ),
          disabledBorder: _fieldBorder(
            color: AppColors.primary,
            noBorder: noBorder,
          ),
        ),
        items: items.map((item) {
          final enabled = !disabledItems.contains(item);
          final isSelected = value == item;
          final itemText = displayText?.call(item) ?? item.toString();
          final index = items.indexOf(item);
          return DropdownMenuItem<T>(
            value: item,
            enabled: enabled,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              decoration: BoxDecoration(
                // color: AppColors.white,
                // borderRadius: BorderRadius.circular(10.r)
                border: Border(
                  bottom: index != items.length - 1
                      ? const BorderSide(color: AppColors.formHint, width: 1.0)
                      : BorderSide.none,
                ),
              ),
              child: TextWidget(
                text: itemText,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: enabled
                    ? isSelected
                          ? AppColors.primary
                          : AppColors.black
                    : AppColors.formHint,
              ),
            ),
          );
        }).toList(),
        selectedItemBuilder: (BuildContext context) => items
            .map(
              (item) => FittedBox(
                child: TextWidget(
                  text: displayText?.call(item) ?? item.toString(),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: selectedItemColor,
                ),
              ),
            )
            .toList(),
        validator: (value) {
          if (value == null) {
            return errorText?.tr();
          }
          return null;
        },
      ),
    );
  }

  static TextStyle labelStyle(double fontSize, Color color) {
    return TextStyleData.formHintStyle.copyWith(
      fontSize: fontSize,
      color: color,
    );
  }

  InputBorder _fieldBorder({
    Color color = AppColors.primary,
    bool noBorder = false,
  }) {
    if (outlined) {
      return OutlineInputBorder(
        borderSide: BorderSide(color: color, width: (1.2)),
        borderRadius: BorderRadius.circular(10),
      );
    } else if (!noBorder) {
      return UnderlineInputBorder(borderSide: BorderSide(color: color));
    } else {
      return InputBorder.none;
    }
  }
}

class EmailListTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const EmailListTextField({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: "Type Email",
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        focusedBorder: _border(color: AppColors.tertiary, radius: 12),
        enabledBorder: _border(color: AppColors.formHint, radius: 12),
        errorBorder: _border(color: AppColors.red, radius: 12),
        focusedErrorBorder: _border(color: AppColors.red, radius: 12),
        disabledBorder: _border(radius: 12),
      ),
      validator: (value) {
        final text = value?.trim() ?? "";
        if (text.isEmpty) {
          // 🔥 Allow empty field (NO error)
          return null;
        }
        if (!Regx.emailRegExp.hasMatch(text)) {
          return "Please enter a valid email";
        }
        return null;
      },
    );
  }

  InputBorder _border({
    Color color = AppColors.formHint,
    double radius = 10.0,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

class WebTextField extends StatelessWidget {
  final String? regErrorText;
  final String? errorText;
  final String? hintText;
  final String? labelText;
  final String? prefixText;
  final bool digit;
  final bool isDouble;
  final bool readOnly;
  final bool enabled;
  final bool passField;
  final bool obscureText;
  final bool? outlined;
  final bool? filled;
  final Color? fillColor;
  final int? minLines;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final RegExp regExpCondition;
  final InputBorder? border;
  final TextEditingController? controller;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? outPadding;
  final double bRadius;
  final bool? isDence;
  final TextStyle? style;
  final TextStyle? errorStyle;
  final bool autoValidate;
  final bool autofocus;
  final FloatingLabelBehavior floatingLabelBehavior;
  final void Function(String)? onChanged;
  final void Function()? onTap;

  const WebTextField({
    super.key,
    required this.regExpCondition,
    this.maxLines = 1,
    this.digit = false,
    this.isDouble = false,
    this.readOnly = false,
    this.enabled = true,
    this.passField = false,
    this.obscureText = false,
    this.minLines,
    this.regErrorText,
    this.outlined,
    this.filled,
    this.fillColor,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.focusNode,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.prefixText,
    this.border,
    this.padding,
    this.outPadding,
    this.bRadius = 10,
    this.isDence,
    this.style,
    this.errorStyle,
    this.autoValidate = true,
    this.autofocus = false,
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      focusNode: focusNode,
      obscuringCharacter: '●',
      obscureText: obscureText && passField,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      keyboardType: digit
          ? TextInputType.number
          : isDouble
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: digit
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength ?? 8),
            ]
          : isDouble
          ? [
              FilteringTextInputFormatter.allow(Regx.double2RegExp),
              LengthLimitingTextInputFormatter(maxLength ?? 8),
            ]
          : null,
      style:
          style ??
          FontUtils.getFontStyle(
            fontFamily: MyFontFam.poppins,
            color: AppColors.black,
            fontWeight: FontWeight.w400,
            fontSize: 15.0,
          ),
      autovalidateMode: autoValidate
          ? AutovalidateMode.onUserInteraction
          : null,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText?.tr(),
        labelText: labelText?.tr(),
        filled: filled,
        fillColor: fillColor,
        isDense: isDence,
        enabled: enabled,
        hintStyle: FontUtils.getFontStyle(
          fontFamily: MyFontFam.poppins,
          color: AppColors.hint,
          fontWeight: FontWeight.w400,
          fontSize: 15.0,
        ),
        labelStyle: labelStyle(AppColors.hint),
        floatingLabelStyle: labelStyle(AppColors.hint),
        errorStyle:
            errorStyle ??
            FontUtils.getFontStyle(
              fontFamily: MyFontFam.poppins,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.red,
            ),
        floatingLabelBehavior: floatingLabelBehavior,
        prefixIcon: prefixIcon,
        prefix: prefix,
        suffix: suffix,
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints(minWidth: 55, minHeight: 2),
        prefixText: prefixText,
        errorMaxLines: 4,
        border: outlined == null ? InputBorder.none : null,
        contentPadding: (outlined != null && outlined == true)
            ? outPadding ?? EdgeInsets.symmetric(vertical: 10, horizontal: 10)
            : padding,
        focusedBorder: _border(color: AppColors.tertiary, radius: bRadius),
        enabledBorder: _border(color: AppColors.formHint, radius: bRadius),
        errorBorder: _border(color: AppColors.red, radius: bRadius),
        focusedErrorBorder: _border(color: AppColors.red, radius: bRadius),
        disabledBorder: _border(radius: bRadius),
      ),
      validator: (value) {
        if (value!.trim().isEmpty) {
          return errorText?.tr();
        }
        if (!regExpCondition.hasMatch(value)) {
          return regErrorText?.tr();
        }
        return null;
      },
    );
  }

  static TextStyle labelStyle(Color color) {
    return TextStyleData.formHintStyle.copyWith(fontSize: 15, color: color);
  }

  InputBorder _border({
    Color color = AppColors.formHint,
    double radius = 10.0,
    double width = 1.2,
  }) {
    if (outlined != null && outlined == false) {
      return UnderlineInputBorder(borderSide: BorderSide(color: color));
    } else {
      return OutlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
        borderRadius: BorderRadius.circular(radius),
      );
    }
  }
}
