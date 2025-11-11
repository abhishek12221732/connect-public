// Web-specific implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
 
class WebUtils {
  static String getUserAgent() {
    return html.window.navigator.userAgent.toLowerCase();
  }
} 