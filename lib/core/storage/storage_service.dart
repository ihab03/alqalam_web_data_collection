import 'storage_platform_stub.dart'
    if (dart.library.js_interop) 'storage_platform_web.dart';

/// Unified storage service abstracting browser localStorage on Flutter Web
/// with in-memory persistence fallback for unit testing in the Dart VM.
class StorageService {
  static final StorageService instance = StorageService._internal();

  factory StorageService() => instance;

  StorageService._internal();

  final WebStorageImpl _impl = WebStorageImpl();
  final Map<String, String> _inMemoryFallback = {};

  /// Retrieves a stored string value by [key].
  String? getItem(String key) {
    return _impl.getItem(key) ?? _inMemoryFallback[key];
  }

  /// Stores a [value] under [key].
  void setItem(String key, String value) {
    _impl.setItem(key, value);
    _inMemoryFallback[key] = value;
  }

  /// Removes an item identified by [key].
  void removeItem(String key) {
    _impl.removeItem(key);
    _inMemoryFallback.remove(key);
  }

  /// Returns the browser User-Agent string.
  String getUserAgent() => _impl.getUserAgent();

  /// Operator overloads for convenient dictionary-style access.
  String? operator [](String key) => getItem(key);
  void operator []=(String key, String value) => setItem(key, value);

  /// Clears in-memory fallback and platform storage (primarily for test resets).
  void clearMemoryFallback() {
    _impl.clear();
    _inMemoryFallback.clear();
  }
}
