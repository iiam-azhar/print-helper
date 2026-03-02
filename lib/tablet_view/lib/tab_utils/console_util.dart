import 'dart:developer';

import 'package:flutter/foundation.dart';

void printData({String title = '', required dynamic data, bool e = false}) {
  if (kDebugMode) {
    //if (title=='') {
    final dataString = data.toString();
    if (e) {
      debugPrint('\x1B[31m$title $dataString\x1B[0m');
    } else {
      debugPrint('\x1B[35m$title $dataString\x1B[0m');
    }
    //}
  }
}

void logData({String title = '', required dynamic data}) {
  if (kDebugMode) {
    //if (title=='') {
    final dataString = data.toString();
    log('$title $dataString');
    //}
  }
}
