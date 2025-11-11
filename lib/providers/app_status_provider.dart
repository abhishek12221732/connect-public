import 'package:flutter/material.dart';

class AppStatusProvider with ChangeNotifier {
  bool _isAppLoading = true;
  PageController? _pageController;

  bool get isAppLoading => _isAppLoading;

  // ✨ FIX: Add a public getter for the page controller
  PageController? get pageController => _pageController;
  
  void setAppLoading(bool status) {
    if (_isAppLoading != status) {
      _isAppLoading = status;
      notifyListeners();
    }
  }

  void setPageController(PageController controller) {
    _pageController = controller;
  }

  void navigateToTab(int index) {
    _pageController?.jumpToPage(index);
  }
}