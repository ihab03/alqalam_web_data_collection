import '../../../core/storage/storage_service.dart';
import '../domain/prompt_models.dart';
import 'manifest_repository.dart';

class SessionResolutionResult {
  final String writerId;
  final String tier; // "eval_50", "eval_short_15", "train_120"
  final String assignment; // "EVAL", "EVAL_SHORT", "TRAIN"
  final List<PromptItem> prompts;
  final int initialPromptIndex; // 0-indexed into prompts
  final String contributorDirectoryKey;
  final String contributorName;
  final String contributorUid;

  const SessionResolutionResult({
    required this.writerId,
    required this.tier,
    required this.assignment,
    required this.prompts,
    required this.initialPromptIndex,
    this.contributorDirectoryKey = '',
    this.contributorName = 'anonymous',
    this.contributorUid = '',
  });
}

class SessionManager {
  static const String contributorUidKey = 'hafs_contributor_uid';
  static const String contributorNameKey = 'hafs_contributor_name';

  final StorageService storage;

  SessionManager({StorageService? storage})
      : storage = storage ?? StorageService.instance;

  /// Generates a unique 6-character alphanumeric contributor UID.
  static String generateContributorUid() {
    final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    if (ms.length >= 6) {
      return ms.substring(ms.length - 6);
    }
    return ms.padLeft(6, '0');
  }

  /// Persistent user session ID stored in localStorage['hafs_contributor_uid'].
  /// If it does not exist, generates and persists one.
  String get contributorUid {
    final existing = storage.getItem(contributorUidKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final newUid = generateContributorUid();
    storage.setItem(contributorUidKey, newUid);
    return newUid;
  }

  set contributorUid(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isNotEmpty) {
      storage.setItem(contributorUidKey, trimmed);
    }
  }

  void setContributorUid(String uid) => contributorUid = uid;

  /// Custom contributor name, stored in localStorage['hafs_contributor_name'].
  /// Defaults to 'anonymous' if not set or empty.
  String get contributorName {
    final name = storage.getItem(contributorNameKey);
    if (name == null || name.trim().isEmpty) {
      return 'anonymous';
    }
    return name.trim();
  }

  set contributorName(String name) {
    final trimmed = name.trim();
    storage.setItem(contributorNameKey, trimmed.isEmpty ? 'anonymous' : trimmed);
  }

  void setContributorName(String name) => contributorName = name;

  /// Whether a valid custom contributor name has been entered (not empty and not 'anonymous').
  bool get hasCustomContributorName {
    final name = storage.getItem(contributorNameKey);
    return name != null &&
        name.trim().isNotEmpty &&
        name.trim().toLowerCase() != 'anonymous';
  }

  /// Sanitizes contributor name: converts to lowercase, replaces spaces with
  /// underscores, and strips non-alphanumeric and non-Arabic characters.
  static String sanitizeContributorName(String name) {
    String sanitized = name.trim().toLowerCase();
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');
    sanitized = sanitized.replaceAll(
      RegExp(r'[^a-z0-9_\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]'),
      '',
    );
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.isEmpty) {
      return 'anonymous';
    }
    return sanitized;
  }

  /// Isolated directory key for storage uploads formatted as:
  /// "${sanitizedName}_${contributorUid}" (e.g. ahmed_k8f2a1 or anonymous_9x3m1q).
  String get contributorDirectoryKey {
    final sanitizedName = sanitizeContributorName(contributorName);
    return '${sanitizedName}_$contributorUid';
  }

  /// Extracts the writer parameter from the URL, handling both standard query
  /// parameters and hash fragment query parameters (e.g. ?writer=e01 or /#/?writer=e01).
  static String? extractWriterParam(Uri uri) {
    String? writerParam = uri.queryParameters['writer']?.trim().toLowerCase();
    if (writerParam != null && writerParam.isNotEmpty) {
      return writerParam;
    }
    if (uri.fragment.isNotEmpty) {
      final fragment = uri.fragment;
      final questionIndex = fragment.indexOf('?');
      if (questionIndex != -1) {
        final queryStr = fragment.substring(questionIndex + 1);
        final fragmentQuery = Uri.splitQueryString(queryStr);
        writerParam = fragmentQuery['writer']?.trim().toLowerCase();
        if (writerParam != null && writerParam.isNotEmpty) {
          return writerParam;
        }
      } else {
        final fragmentUri = Uri.tryParse(fragment);
        writerParam = fragmentUri?.queryParameters['writer']?.trim().toLowerCase();
        if (writerParam != null && writerParam.isNotEmpty) {
          return writerParam;
        }
      }
    }
    return null;
  }

  /// Resolves the writer ID based on Section 1 & 5.1 of flutter_collection_spec_v2.md.
  ///
  /// v2 has named slots only (26 keys: e01..e03, s01..s20, t01..t03).
  /// If ?writer is missing, empty, or not found in manifest.writers, returns null.
  /// Never auto-assigns or falls back to crowd batches.
  String? resolveWriterId(
    Uri uri,
    ManifestData manifest,
  ) {
    final writerParam = extractWriterParam(uri);
    if (writerParam != null && manifest.hasWriter(writerParam)) {
      return writerParam;
    }
    return null;
  }

  /// Resolves full session state including starting index at the lowest incomplete seq_index.
  /// Returns null if the writer link is missing or invalid.
  SessionResolutionResult? resolveSession(
    Uri uri,
    ManifestData manifest,
  ) {
    final writerId = resolveWriterId(uri, manifest);
    if (writerId == null) {
      return null;
    }

    final prompts = manifest.getPromptsForWriter(writerId) ?? [];
    if (prompts.isEmpty) {
      return null;
    }

    final tier = prompts.first.tier;
    final assignment = prompts.first.assignment;

    // Auto-resume: lowest incomplete seq_index
    int startIndex = 0;
    for (int i = 0; i < prompts.length; i++) {
      final promptId = prompts[i].promptId;
      final isCompleted = isPromptCompleted(promptId);
      if (!isCompleted) {
        startIndex = i;
        break;
      }
      if (i == prompts.length - 1) {
        // If all completed, point to last or celebration
        startIndex = prompts.length - 1;
      }
    }

    return SessionResolutionResult(
      writerId: writerId,
      tier: tier,
      assignment: assignment,
      prompts: prompts,
      initialPromptIndex: startIndex,
      contributorDirectoryKey: contributorDirectoryKey,
      contributorName: contributorName,
      contributorUid: contributorUid,
    );
  }

  /// Whether a specific prompt has already been completed and uploaded.
  bool isPromptCompleted(String promptId) {
    return storage.getItem('hafs_completed_$promptId') == 'true';
  }

  /// Marks a prompt as completed in local storage.
  void markPromptCompleted(String promptId) {
    storage.setItem('hafs_completed_$promptId', 'true');
  }
}
