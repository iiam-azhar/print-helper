import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../tab_constants/colors.dart';

Future showToast({required dynamic message}) {
  return Fluttertoast.showToast(
    msg: '$message'.tr(),
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: const Color(0xFFDFDFDF),
    textColor: AppColors.black,
    fontSize: 16,
  );
}
