import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tab_utils/extensions.dart';

enum MyFontFam { titillium, poppins }

enum ViewCase { lower, upper, title, caps }

class FontUtils {
  static TextStyle getFontStyle({
    required MyFontFam fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    Color color = Colors.black,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    List<Shadow>? shadows,
  }) {
    final fontFam = _getFontFamily(fontFamily);
    return GoogleFonts.getFont(
      fontFam,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      shadows: shadows,
    );
  }

  static String _getFontFamily(MyFontFam fontFam) {
    switch (fontFam) {
      case MyFontFam.titillium:
        return 'Titillium Web';
      // case MyFontFam.monteserrat:
      //   return 'Montserrat';
      case MyFontFam.poppins:
        return 'Poppins';
    }
  }
}

class TextWidget extends StatelessWidget {
  final String text;
  final String t2;
  final String t3;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final MyFontFam fontFam;
  final bool trOn;
  final bool t2TrOn;
  final bool t3TrOn;
  final double? height;
  final int? maxLines;
  final TextAlign? textAlign;
  final double? letterSpacing;
  final TextOverflow? overflow;
  final TextDecoration? decoration;
  final Color? decorationColor;
  final ViewCase? viewCase;
  final List<Shadow> shadows;

  const TextWidget({
    super.key,
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    this.color = Colors.black,
    this.fontFam = MyFontFam.poppins,
    this.t2 = '',
    this.t3 = '',
    this.trOn = false,
    this.t2TrOn = false,
    this.t3TrOn = false,
    this.height,
    this.letterSpacing,
    this.textAlign,
    this.maxLines,
    this.decoration,
    this.decorationColor,
    this.viewCase,
    this.shadows = const [],
    TextOverflow? overflow,
  }) : overflow = maxLines != null ? (overflow ?? TextOverflow.ellipsis) : null;

  @override
  Widget build(BuildContext context) {
    final textStyle = FontUtils.getFontStyle(
      fontFamily: fontFam,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
      shadows: shadows,
    );

    final txt = trOn ? text.tr() : text;
    final txt2 = (t2.isNotEmpty && t2TrOn) ? t2.tr() : t2;
    final txt3 = (t3.isNotEmpty && t3TrOn) ? t3.tr() : t3;

    final vct = _applyViewCase(txt);
    final vct2 = t2.isNotEmpty ? _applyViewCase(txt2) : txt2;
    final vct3 = txt3.isNotEmpty ? _applyViewCase(txt3) : txt3;

    return Text(
      _buildText(vct, vct2, vct3),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: textStyle,
    );
  }

  String _applyViewCase(String text) {
    switch (viewCase) {
      case ViewCase.lower:
        return text.toLowerCase();
      case ViewCase.upper:
        return text.toUpperCase();
      case ViewCase.title:
        return text.toTitleCase;
      case ViewCase.caps:
        return text.capitalize;
      default:
        return text;
    }
  }

  String _buildText(String vct, String vct2, String vct3) {
    if (vct2.isEmpty && vct3.isEmpty) return vct;
    if (vct3.isEmpty) return '$vct $vct2';
    return '$vct $vct2  $vct3';
  }
}

class RichTextWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final List<TextSpan>? children;

  const RichTextWidget({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(text: text, style: style, children: children),
    );
  }
}
