import '../../../core/storage/storage_service.dart';
import '../domain/prompt_models.dart';
import 'manifest_repository.dart';

class SessionResolutionResult {
  final String writerId;
  final String tier; // "core_130" or "crowd_15"
  final List<PromptItem> prompts;
  final int initialPromptIndex; // 0-indexed into prompts

  const SessionResolutionResult({
    required this.writerId,
    required this.tier,
    required this.prompts,
    required this.initialPromptIndex,
  });
}

class SessionManager {
  final StorageService storage;

  SessionManager({StorageService? storage})
      : storage = storage ?? StorageService.instance;

  /// Resolves the writer ID and tier based on Section 1 & 5.1 of FLUTTER_COLLECTION_SPEC.md.
  String resolveWriterId(
    Uri uri,
    ManifestData manifest,
  ) {
    // 1. Check URL query parameters (e.g. ?writer=w02 or /#/?writer=w02)
    String? writerParam = uri.queryParameters['writer']?.toLowerCase();
    if (writerParam == null && uri.fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(uri.fragment);
      writerParam = fragmentUri?.queryParameters['writer']?.toLowerCase();
    }

    if (writerParam != null && writerParam.isNotEmpty) {
      if (manifest.hasWriter(writerParam)) {
        return writerParam; // Tier 1 Core writer (w01..w04)
      }
    }

    // 2. Check localStorage for existing claimed Crowd batch
    final storedBatch = storage.getItem('hafs_current_crowd_batch');
    if (storedBatch != null && manifest.hasWriter(storedBatch)) {
      final isDone = storage.getItem('hafs_batch_done_$storedBatch') == 'true';
      if (!isDone) {
        return storedBatch;
      }
    }

    // 3. Auto-claim first available crowd batch (c001..c100)
    for (int i = 1; i <= 100; i++) {
      final batchId = 'c${i.toString().padLeft(3, '0')}';
      final isDone = storage.getItem('hafs_batch_done_$batchId') == 'true';
      if (!isDone && manifest.hasWriter(batchId)) {
        storage.setItem('hafs_current_crowd_batch', batchId);
        return batchId;
      }
    }

    return 'c001'; // Fallback
  }

  /// Resolves full session state including starting index at the lowest incomplete seq_index.
  SessionResolutionResult resolveSession(
    Uri uri,
    ManifestData manifest,
  ) {
    final writerId = resolveWriterId(uri, manifest);
    final prompts = manifest.getPromptsForWriter(writerId) ?? [];
    final isCore = writerId.startsWith('w');
    final tier = isCore ? 'core_130' : 'crowd_15';

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
      prompts: prompts,
      initialPromptIndex: startIndex,
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

  /// Marks a crowd batch complete and removes active claimed batch.
  void markBatchComplete(String batchId) {
    storage.setItem('hafs_batch_done_$batchId', 'true');
    storage.removeItem('hafs_current_crowd_batch');
  }

  /// Claims the next batch in sequence (c00X + 1) or next available incomplete batch.
  String claimNextCrowdBatch(ManifestData manifest, String currentBatchId) {
    markBatchComplete(currentBatchId);

    // Try c(current + 1) first
    final currentNum = int.tryParse(currentBatchId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    for (int offset = 1; offset <= 100; offset++) {
      int nextNum = currentNum + offset;
      if (nextNum > 100) nextNum = ((nextNum - 1) % 100) + 1;
      final nextBatchId = 'c${nextNum.toString().padLeft(3, '0')}';
      final isDone = storage.getItem('hafs_batch_done_$nextBatchId') == 'true';
      if (!isDone && manifest.hasWriter(nextBatchId)) {
        storage.setItem('hafs_current_crowd_batch', nextBatchId);
        return nextBatchId;
      }
    }

    // Fallback if all 100 marked done
    final fallback = 'c001';
    storage.setItem('hafs_current_crowd_batch', fallback);
    return fallback;
  }
}
