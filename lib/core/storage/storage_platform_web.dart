import 'package:web/web.dart' as web;

/// Browser-native localStorage implementation for Flutter Web.
class WebStorageImpl {
  String? getItem(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void setItem(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  void removeItem(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }

  void clear() {
    try {
      web.window.localStorage.clear();
    } catch (_) {}
  }

  String getUserAgent() {
    try {
      return web.window.navigator.userAgent;
    } catch (_) {
      return 'FlutterWeb/Unknown';
    }
  }
}
