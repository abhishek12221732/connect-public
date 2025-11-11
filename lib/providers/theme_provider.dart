
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feelings/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _currentTheme = AppTheme.themes[AppThemeType.defaultLight]!;
  AppThemeType _currentThemeType = AppThemeType.defaultLight;
  bool _isLoaded = false;

  ThemeData get currentTheme => _currentTheme;
  AppThemeType get currentThemeType => _currentThemeType;
  bool get isLoaded => _isLoaded;

  Future<void> loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme') ?? 'light';
    final themeType = AppThemeType.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppThemeType.defaultLight,
    );
    _currentTheme = AppTheme.themes[themeType]!;
    _currentThemeType = themeType;
    _isLoaded = true;
    notifyListeners();
  }

  void setTheme(AppThemeType themeType) async {
    _currentTheme = AppTheme.themes[themeType]!;
    _currentThemeType = themeType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeType.name);
    notifyListeners();
  }
}