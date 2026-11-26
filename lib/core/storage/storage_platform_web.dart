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

  List<String> getKeys() {
    final keys = <String>[];
    try {
      final len = web.window.localStorage.length;
      for (int i = 0; i < len; i++) {
        final k = web.window.localStorage.key(i);
        if (k != null) keys.add(k);
      }
    } catch (_) {}
    return keys;
  }

  String getUserAgent() {
    try {
      return web.window.navigator.userAgent;
    } catch (_) {
      return 'FlutterWeb/Unknown';
    }
  }
}
