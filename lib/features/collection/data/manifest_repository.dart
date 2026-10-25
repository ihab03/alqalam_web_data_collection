import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/prompt_models.dart';

class ManifestData {
  final Map<String, dynamic> metadata;
  final Map<String, List<PromptItem>> writers;

  const ManifestData({
    required this.metadata,
    required this.writers,
  });

  List<PromptItem>? getPromptsForWriter(String writerId) => writers[writerId];
  bool hasWriter(String writerId) => writers.containsKey(writerId);
}

class ManifestRepository {
  static const String manifestAssetPath = 'assets/data/collection_manifest.json';
  static ManifestData? _cachedData;

  /// Loads and caches the collection manifest.
  static Future<ManifestData> loadManifest() async {
    if (_cachedData != null) return _cachedData!;

    final jsonStr = await rootBundle.loadString(manifestAssetPath);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    final meta = decoded['metadata'] as Map<String, dynamic>? ?? {};
    final rawWriters = decoded['writers'] as Map<String, dynamic>? ?? {};

    final Map<String, List<PromptItem>> parsedWriters = {};
    for (final entry in rawWriters.entries) {
      final list = entry.value as List<dynamic>;
      parsedWriters[entry.key] = list
          .map((item) => PromptItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    _cachedData = ManifestData(
      metadata: meta,
      writers: parsedWriters,
    );
    return _cachedData!;
  }

  /// Invalidate cache (primarily for tests)
  static void clearCache() {
    _cachedData = null;
  }
}
