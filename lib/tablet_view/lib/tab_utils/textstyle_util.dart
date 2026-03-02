import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';
import '../tab_widgets/tab_text_widget.dart';

class TextStyleData {
  static TextStyle selectedNavLbl = FontUtils.getFontStyle(
    fontFamily: MyFontFam.poppins,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  static TextStyle unSelectedNavLbl = FontUtils.getFontStyle(
    fontFamily: MyFontFam.poppins,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.grey,
  );

  static TextStyle formHintStyle = FontUtils.getFontStyle(
    fontFamily: MyFontFam.poppins,
    color: AppColors.hint,
    fontWeight: FontWeight.w400,
    fontSize: 15.0,
  );

  static TextStyle formErrorStyle = FontUtils.getFontStyle(
    fontFamily: MyFontFam.poppins,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.red,
  );
}
