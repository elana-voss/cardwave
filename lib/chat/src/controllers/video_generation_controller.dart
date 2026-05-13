import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/repositories/chat_repository.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';

/// Owns the per-job UI state for in-flight video generations and persists
/// the resulting MP4. Drives the actual submit/poll/download via the (pure)
/// [VideoGenerationService], passing an `onProgress` callback that updates
/// the in-memory job map and notifies listeners.
class VideoGenerationController extends ChangeNotifier {
  VideoGenerationController({
    required VideoGenerationService videoService,
    required ChatRepository chatRepository,
  }) : _videoService = videoService,
       _chatRepository = chatRepository;

  final VideoGenerationService _videoService;
  final ChatRepository _chatRepository;
  final Map<int, VideoJobStatus> _jobs = {};

  /// Snapshot of job state for the UI — null when no job is in flight for
  /// [messageTimestamp].
  VideoJobView? jobFor(int messageTimestamp) {
    final status = _jobs[messageTimestamp];
    if (status == null) return null;
    return VideoJobView(
      state: status.state,
      progressPct: status.progressPct,
      errorMessage: status.errorMessage,
    );
  }

  /// Submits a generation job for the pre-built [finalPrompt], polls until
  /// done, writes the mp4 under the session, and returns its cards-domain
  /// relative path. The caller (the chat mixin) stamps
  /// `placeholder.swipes[0].videoPath` and swaps the placeholder content.
  /// Throws [LlmFetchException] (or rethrows the provider's own throw) on
  /// failure — the mixin catches and drops the placeholder.
  Future<VideoGenerationResult> generateFromCompactedPrompt({
    required ChatMessage placeholder,
    required String finalPrompt,
    required ConfigMediaResolved resolved,
    required ChatSession session,
    required CharacterFile characterFile,
  }) async {
    // Caller (the chat mixin) pre-checks `resolved.videoPreset != null`.
    // Resolver guarantees non-null secondaries when videoPreset is non-null.
    final videoPreset = resolved.videoPreset!;
    final config = ConfigVideo(
      resolutionId: resolved.videoResolutionId!,
      aspectRatioId: resolved.videoAspectRatioId!,
      durationSeconds: resolved.videoDurationSeconds!,
    );
    final messageTimestamp = placeholder.timestamp;
    try {
      final bytes = await _videoService.executeVideoJob(
        providerConfig: videoPreset.provider,
        modelId: videoPreset.model.id,
        prompt: finalPrompt,
        config: config,
        onProgress: (status) => _updateJob(messageTimestamp, status),
      );
      final relativePath = await _chatRepository.saveMessageVideo(
        characterFile,
        session,
        placeholder,
        config,
        bytes,
      );
      // Drop the completed job so the bubble switches from progress UI to
      // the saved video player on the next rebuild.
      _jobs.remove(messageTimestamp);
      notifyListeners();
      return VideoGenerationResult(relativePath: relativePath);
    } catch (_) {
      _jobs.remove(messageTimestamp);
      notifyListeners();
      rethrow;
    }
  }

  /// Settings test button: submit + poll + download and return the raw MP4
  /// bytes so the caller can preview playback. Uses the model's shortest
  /// allowed duration + first resolution/aspect to minimize generation
  /// latency and cost during an interactive test.
  Future<Uint8List> testGenerateFor({
    required LlmProviderConfig provider,
    required String modelId,
  }) {
    // Test jobs don't appear in any chat bubble — the settings button has
    // its own spinner, so no `_jobs` entry is needed.
    return _videoService.testGenerateFor(
      provider: provider,
      modelId: modelId,
      onProgress: (_) {/* test job has its own spinner — ignore progress */},
    );
  }

  void _updateJob(int messageTimestamp, VideoJobStatus status) {
    _jobs[messageTimestamp] = status;
    notifyListeners();
  }
}

/// Persisted result of a video generation job: the cards-domain-relative
/// path, ready to stamp on `ChatSwipe.videoPath`. Kept as a class (not a
/// raw `String`) so future fields (actual duration, provider cost,
/// content moderation result) can land without churning call-sites.
class VideoGenerationResult {
  const VideoGenerationResult({required this.relativePath});
  final String relativePath;
}

/// Read-only projection of a job for consumers in the widget tree.
/// `==` is required so `context.select` can skip rebuilds when the job's
/// visible fields haven't changed between polls.
@immutable
class VideoJobView {
  const VideoJobView({
    required this.state,
    this.progressPct,
    this.errorMessage,
  });
  final VideoJobStateEnum state;
  final int? progressPct;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoJobView &&
          other.state == state &&
          other.progressPct == progressPct &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(state, progressPct, errorMessage);
}
