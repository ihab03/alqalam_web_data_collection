/// Storage platform implementation for Dart VM and unit tests.
class WebStorageImpl {
  final Map<String, String> _mem = {};

  String? getItem(String key) => _mem[key];

  void setItem(String key, String value) {
    _mem[key] = value;
  }

  void removeItem(String key) {
    _mem.remove(key);
  }

  void clear() {
    _mem.clear();
  }

  String getUserAgent() => 'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
}
