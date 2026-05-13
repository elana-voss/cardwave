import 'dart:typed_data';

import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_config.dart';
import 'package:cardwave_llm/src/models/video_option.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';

/// Async-polling video generation: submit → poll every [_pollInterval] →
/// download MP4 bytes. Stateless and notifier-free — caller supplies an
/// optional [onProgress] closure to observe state transitions, and owns
/// any UI state and persistence on top.
class VideoGenerationService {
  const VideoGenerationService({required PromptRepository promptRepository})
    : _promptRepository = promptRepository;

  static const Duration _pollInterval = Duration(seconds: 5);
  // 15 min covers Grok in the wild — its `pending` state commonly sits at
  // 90% progress for 4–8 min before flipping to `done`. Shorter timeouts
  // abandon real jobs that would have succeeded. Providers that complete
  // fast (Sora, Veo ~1–3 min) aren't penalised because we break on the
  // first `done` / `failed` poll response.
  static const Duration _pollTimeout = Duration(minutes: 15);

  final PromptRepository _promptRepository;

  /// Settings test button: submit + poll + download and return the raw MP4
  /// bytes so the caller can preview playback. Uses the model's shortest
  /// allowed duration + first resolution/aspect to minimize generation
  /// latency and cost during an interactive test.
  Future<Uint8List> testGenerateFor({
    required LlmProviderConfig provider,
    required String modelId,
    void Function(VideoJobStatus status)? onProgress,
  }) async {
    final providerInfo = LlmProvider.of(provider.providerEnum);
    final options = providerInfo.videoOptionsFor(modelId);
    if (options == null) throw StateError('No video options for $modelId.');
    // A model with a video roster always carries at least one resolution,
    // aspect ratio, and duration.
    final config = ConfigVideo(
      // ignore: qcheck/avoid_unsafe_collection_methods
      resolutionId: options.resolutions.first.id,
      // ignore: qcheck/avoid_unsafe_collection_methods
      aspectRatioId: options.aspectRatios.first.id,
      // ignore: qcheck/avoid_unsafe_collection_methods
      durationSeconds: options.durations.first.seconds,
    );
    return executeVideoJob(
      providerConfig: provider,
      modelId: modelId,
      prompt: _promptRepository.videoTest,
      config: config,
      onProgress: onProgress,
    );
  }

  /// Submit a video generation job, poll until done/failed/timeout, then
  /// download the bytes. [onProgress] receives every state transition so a
  /// caller can drive a UI progress widget. Throws [LlmFetchException] (or
  /// rethrows the provider's own throw) on failure.
  Future<Uint8List> executeVideoJob({
    required LlmProviderConfig providerConfig,
    required String modelId,
    required String prompt,
    required ConfigVideo config,
    void Function(VideoJobStatus status)? onProgress,
  }) async {
    final providerInfo = LlmProvider.of(providerConfig.providerEnum);
    final baseUrl = providerConfig.baseUrl ?? providerInfo.defaultBaseUrl;

    onProgress?.call(const VideoJobStatus(state: VideoJobStateEnum.submitting));

    videoLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.video,
        title: 'SUBMIT OUTGOING',
        body:
            '\nProvider: ${providerConfig.providerEnum.name}'
            '\nModel: $modelId'
            '\nResolution: ${config.resolutionId}'
            '\nAspect: ${config.aspectRatioId}'
            '\nDuration: ${config.durationSeconds}s'
            '\nPromptLen: ${prompt.length}'
            '\nPrompt: $prompt',
        providerEnumName: providerConfig.providerEnum.name,
        modelId: modelId,
      ),
    );

    final stopwatch = Stopwatch()..start();
    try {
      final jobId = await providerInfo.submitVideoJob(
        apiKey: providerConfig.apiKey,
        baseUrl: baseUrl,
        modelId: modelId,
        prompt: prompt,
        resolutionId: config.resolutionId,
        aspectRatioId: config.aspectRatioId,
        durationSeconds: config.durationSeconds,
      );
      videoLogger.info(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.video,
          title: 'SUBMIT INCOMING',
          body:
              '\nProvider: ${providerConfig.providerEnum.name}'
              '\nJobId: $jobId'
              '\nLatencyMs: ${stopwatch.elapsedMilliseconds}',
          providerEnumName: providerConfig.providerEnum.name,
          modelId: modelId,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );

      onProgress?.call(const VideoJobStatus(state: VideoJobStateEnum.polling));

      final deadline = DateTime.now().add(_pollTimeout);
      var latest = const VideoJobStatus(state: VideoJobStateEnum.polling);
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(_pollInterval);
        // A single poll can fail transiently (network blip, provider 5xx,
        // request-level timeout). The outer `deadline` caps total wait, and
        // the provider signals genuine failure via VideoJobStateEnum.failed
        // (returned, not thrown), so any thrown exception here is treated as
        // transient — log and try again on the next iteration.
        try {
          latest = await providerInfo.pollVideoJob(
            apiKey: providerConfig.apiKey,
            baseUrl: baseUrl,
            jobId: jobId,
          );
        } on Exception catch (e) {
          videoLogger.warning(
            LlmStructuredEvent(
              category: LlmEventCategoryEnum.video,
              title: 'POLL_TRANSIENT_ERROR',
              body:
                  '\nProvider: ${providerConfig.providerEnum.name}'
                  '\nError: $e'
                  '\nElapsedMs: ${stopwatch.elapsedMilliseconds}',
              providerEnumName: providerConfig.providerEnum.name,
            ),
          );
          continue;
        }
        onProgress?.call(latest);
        videoLogger.fine(
          LlmStructuredEvent(
            category: LlmEventCategoryEnum.video,
            title: 'POLL',
            body:
                '\nProvider: ${providerConfig.providerEnum.name}'
                '\nState: ${latest.state.name}'
                '\nProgress: ${latest.progressPct ?? "n/a"}'
                '\nElapsedMs: ${stopwatch.elapsedMilliseconds}',
            providerEnumName: providerConfig.providerEnum.name,
          ),
        );
        if (latest.state == VideoJobStateEnum.done ||
            latest.state == VideoJobStateEnum.failed) {
          break;
        }
      }

      if (latest.state != VideoJobStateEnum.done) {
        throw LlmFetchException(
          provider: providerConfig.providerEnum,
          providerLabel: providerInfo.label,
          message:
              latest.errorMessage ??
              (latest.state == VideoJobStateEnum.polling
                  ? 'Video generation timed out.'
                  : 'Video generation failed.'),
        );
      }

      final url = latest.resultUrl;
      if (url == null || url.isEmpty) {
        throw LlmFetchException(
          provider: providerConfig.providerEnum,
          providerLabel: providerInfo.label,
          message: 'Provider returned no download URL.',
        );
      }

      onProgress?.call(
        VideoJobStatus(
          state: VideoJobStateEnum.downloading,
          progressPct: latest.progressPct,
        ),
      );

      final bytes = await providerInfo.downloadVideoBytes(
        apiKey: providerConfig.apiKey,
        url: url,
      );
      videoLogger.info(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.video,
          title: 'DOWNLOADED',
          body:
              '\nProvider: ${providerConfig.providerEnum.name}'
              '\nBytes: ${bytes.length}'
              '\nTotalMs: ${stopwatch.elapsedMilliseconds}',
          providerEnumName: providerConfig.providerEnum.name,
          modelId: modelId,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
      return bytes;
    } catch (e) {
      final detail = e is LlmFetchException
          ? 'status=${e.statusCode ?? '?'} body=${e.message}'
          : e.toString();
      videoLogger.severe(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.video,
          title: 'ERROR',
          body:
              '\nProvider: ${providerConfig.providerEnum.name}'
              '\nModel: $modelId'
              '\nTotalMs: ${stopwatch.elapsedMilliseconds}'
              '\n$detail',
          providerEnumName: providerConfig.providerEnum.name,
          modelId: modelId,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
      rethrow;
    }
  }
}
