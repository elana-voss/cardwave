import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'video_option.g.dart';

/// One entry in a model's resolution roster. [id] is the raw value sent to
/// the provider API (`"720p"`, `"1080p"`, `"4k"` — no normalization, the
/// string must match whatever the provider's endpoint expects). [label] is
/// what the user sees in the drawer tile. Resolutions live on
/// [OptionsVideo] and are populated per-model at adoption time.
@JsonSerializable()
class VideoResolution {
  const VideoResolution({required this.id, required this.label});

  factory VideoResolution.fromJson(Map<String, dynamic> json) =>
      _$VideoResolutionFromJson(json);
  final String id;
  final String label;
  Map<String, dynamic> toJson() => _$VideoResolutionToJson(this);
}

/// One aspect-ratio choice. [id] is the raw value passed to the provider
/// (e.g. `"16:9"`, `"9:16"`, `"1:1"`). For OpenAI's Sora the id is
/// translated into a size string (`1280x720` vs `720x1280`) at request
/// time; other providers accept the ratio directly.
@JsonSerializable()
class VideoAspectRatio {
  const VideoAspectRatio({required this.id, required this.label});

  factory VideoAspectRatio.fromJson(Map<String, dynamic> json) =>
      _$VideoAspectRatioFromJson(json);
  final String id;
  final String label;
  Map<String, dynamic> toJson() => _$VideoAspectRatioToJson(this);
}

/// One discrete duration choice — whole seconds only. Providers vary
/// wildly on which durations they accept (Grok: 1–15s continuous; OpenAI
/// Sora: discrete {4, 8, 12}; Google Veo: discrete {4, 6, 8} with
/// resolution-dependent constraints), so each provider's roster is
/// hardcoded in its `videoOptionsFor`.
@JsonSerializable()
class VideoDuration {
  const VideoDuration({required this.seconds, required this.label});

  factory VideoDuration.fromJson(Map<String, dynamic> json) =>
      _$VideoDurationFromJson(json);
  final int seconds;
  final String label;
  Map<String, dynamic> toJson() => _$VideoDurationToJson(this);
}

/// Per-model video-generation roster. Attached to `LlmModel.optionsVideo`
/// by `LlmPureHelpers.populateVideoOptions` when a video-capable model is
/// adopted. Each list is a static set of choices the provider accepts for
/// that specific model (e.g. Sora-2 → one resolution + two aspects + three
/// durations; Veo-3.1 → a richer grid with its own constraints). The
/// drawer tiles read these lists verbatim to populate their pickers.
@JsonSerializable()
class OptionsVideo {
  const OptionsVideo({
    required this.resolutions,
    required this.aspectRatios,
    required this.durations,
  });

  factory OptionsVideo.fromJson(Map<String, dynamic> json) =>
      _$OptionsVideoFromJson(json);
  final List<VideoResolution> resolutions;
  final List<VideoAspectRatio> aspectRatios;
  final List<VideoDuration> durations;
  Map<String, dynamic> toJson() => _$OptionsVideoToJson(this);
}

/// Concrete video-generation config consumed by provider dispatch. Built
/// from the resolved layer chain at request time; never persisted directly.
@JsonSerializable()
class ConfigVideo {
  ConfigVideo({
    required this.resolutionId,
    required this.aspectRatioId,
    required this.durationSeconds,
  });

  factory ConfigVideo.fromJson(Map<String, dynamic> json) =>
      _$ConfigVideoFromJson(json);
  String resolutionId;
  String aspectRatioId;
  int durationSeconds;
  Map<String, dynamic> toJson() => _$ConfigVideoToJson(this);
}

/// Lifecycle of a single video generation request from the service's
/// perspective. `submitting` → `polling` → `downloading` → `done` on the
/// happy path. `failed` is terminal; the service drops the registry entry
/// and surfaces an error to the caller. Not persisted — jobs exist only
/// in-memory and are discarded on app close.
enum VideoJobStateEnum { submitting, polling, downloading, done, failed }

/// Provider poll response normalized. `resultUrl` is populated once the
/// provider signals completion — some providers (OpenAI, OR) require a
/// separate `/content` GET to fetch bytes, so the service calls
/// `downloadVideoBytes` with this URL regardless; for providers that
/// return a direct URL the URL IS the download endpoint.
@immutable
class VideoJobStatus {
  const VideoJobStatus({
    required this.state,
    this.progressPct,
    this.resultUrl,
    this.errorMessage,
  });
  final VideoJobStateEnum state;
  final int? progressPct;
  final String? resultUrl;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoJobStatus &&
          other.state == state &&
          other.progressPct == progressPct &&
          other.resultUrl == resultUrl &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(state, progressPct, resultUrl, errorMessage);
}
