import 'package:flutter/material.dart';

class NavigationPro extends ChangeNotifier {
  String? _targetPage;
  String? get targetPage => _targetPage;

  void setTargetPage(String? page) {
    _targetPage = page;
    notifyListeners();
  }

  void clearTargetPage() {
    _targetPage = null;
    notifyListeners();
  }
}
