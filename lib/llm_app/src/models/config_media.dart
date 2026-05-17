import 'package:cardwave_llm/cardwave_llm.dart' show ConfigTts, ResolvedPreset;
import 'package:json_annotation/json_annotation.dart';

part 'config_media.g.dart';

/// App-layer media generation settings.
///
/// Holds the per-domain default preset IDs only — no aspect / resolution /
/// voice / language fields. The resolver seeds those from the model's
/// first available option when no character or session layer supplies them,
/// so the app layer doesn't need to (or want to) carry them.
@JsonSerializable(includeIfNull: false)
class ConfigMediaApp {
  ConfigMediaApp({this.imagePresetId, this.videoPresetId, this.ttsPresetId});

  factory ConfigMediaApp.fromJson(Map<String, dynamic> json) =>
      _$ConfigMediaAppFromJson(json);

  String? imagePresetId;
  String? videoPresetId;
  String? ttsPresetId;

  Map<String, dynamic> toJson() => _$ConfigMediaAppToJson(this);
}

/// Character-layer media generation settings.
///
/// Holds every setting the character editor surfaces — preset selection
/// (coupled with the secondary fields per domain), prompt prefix, NSFW
/// toggle, and the autonomous-tool gates the character ships with.
///
/// Coupled fields (preset+aspect, preset+resolution+aspect+duration,
/// preset+voice+language) live behind paired setters on private storage
/// to make "set preset id but forget the aspect" a compile error rather
/// than a silent runtime no-op. The other fields are independent and
/// stand alone as plain mutable properties.
///
/// Note the asymmetry vs [ConfigMediaSession]: the session has wand- and
/// tool-prompt-review fields the character doesn't, because reviewing a
/// prompt is a user-trust call, not a character property. And the session
/// has no `*PromptPrefix` fields because those are persona flavour the
/// character ships with — there's no per-chat case for overriding the
/// prefix. The class API enforces this asymmetry: trying to write a
/// session-only field on the character class is a compile error.
@JsonSerializable(includeIfNull: false)
class ConfigMediaCharacter {
  ConfigMediaCharacter({
    String? imagePresetId,
    String? imageAspectRatioId,
    this.imageNsfwAllowed,
    this.imagePromptPrefix,
    this.imageToolSelfieAllowed,
    this.imageToolSelfieCaptionsAllowed,
    String? videoPresetId,
    String? videoResolutionId,
    String? videoAspectRatioId,
    int? videoDurationSeconds,
    this.videoNsfwAllowed,
    this.videoPromptPrefix,
    this.videoToolSendAllowed,
    String? ttsPresetId,
    String? ttsVoiceId,
    String? ttsLanguageCode,
    this.webToolFetchAllowed,
    this.nameToolSuggestAllowed,
  }) : _imagePresetId = imagePresetId,
       _imageAspectRatioId = imageAspectRatioId,
       _videoPresetId = videoPresetId,
       _videoResolutionId = videoResolutionId,
       _videoAspectRatioId = videoAspectRatioId,
       _videoDurationSeconds = videoDurationSeconds,
       _ttsPresetId = ttsPresetId,
       _ttsVoiceId = ttsVoiceId,
       _ttsLanguageCode = ttsLanguageCode;

  factory ConfigMediaCharacter.fromJson(Map<String, dynamic> json) =>
      _$ConfigMediaCharacterFromJson(json);

  // --- Image ---

  String? _imagePresetId;
  String? _imageAspectRatioId;

  String? get imagePresetId => _imagePresetId;
  String? get imageAspectRatioId => _imageAspectRatioId;

  /// Atomic write for the coupled image preset tuple. Both fields move
  /// together because the aspect ratio belongs to the preset's model;
  /// independent writes would let them drift out of sync.
  void setImagePreset(String? presetId, String? aspectRatioId) {
    _imagePresetId = presetId;
    _imageAspectRatioId = aspectRatioId;
  }

  bool? imageNsfwAllowed;
  String? imagePromptPrefix;
  bool? imageToolSelfieAllowed;
  bool? imageToolSelfieCaptionsAllowed;

  // --- Video ---

  String? _videoPresetId;
  String? _videoResolutionId;
  String? _videoAspectRatioId;
  int? _videoDurationSeconds;

  String? get videoPresetId => _videoPresetId;
  String? get videoResolutionId => _videoResolutionId;
  String? get videoAspectRatioId => _videoAspectRatioId;
  int? get videoDurationSeconds => _videoDurationSeconds;

  /// Atomic write for the coupled video preset tuple. All four fields
  /// move together — resolution, aspect ratio, and duration all belong
  /// to the preset's model roster.
  void setVideoPreset(
    String? presetId,
    String? resolutionId,
    String? aspectRatioId,
    int? durationSeconds,
  ) {
    _videoPresetId = presetId;
    _videoResolutionId = resolutionId;
    _videoAspectRatioId = aspectRatioId;
    _videoDurationSeconds = durationSeconds;
  }

  bool? videoNsfwAllowed;
  String? videoPromptPrefix;

  /// Lets the chat model call the `send_video` tool when the resolved
  /// flag is true. Mirror of [imageToolSelfieAllowed]; fed into the
  /// resolved flag with session > character > false.
  bool? videoToolSendAllowed;

  // --- TTS ---

  String? _ttsPresetId;
  String? _ttsVoiceId;
  String? _ttsLanguageCode;

  String? get ttsPresetId => _ttsPresetId;
  String? get ttsVoiceId => _ttsVoiceId;
  String? get ttsLanguageCode => _ttsLanguageCode;

  /// Atomic write for the coupled TTS preset tuple. The voice belongs
  /// to the preset's model; the language belongs to the voice (or to
  /// the model's auto-detect default).
  void setTtsPreset(String? presetId, String? voiceId, String? languageCode) {
    _ttsPresetId = presetId;
    _ttsVoiceId = voiceId;
    _ttsLanguageCode = languageCode;
  }

  // --- Web ---

  /// Lets the chat model call the `fetch_website` tool when the
  /// resolved flag is true. Mirror of [imageToolSelfieAllowed].
  bool? webToolFetchAllowed;

  // --- Names ---

  /// Lets the chat model call the `suggest_name` tool when the resolved
  /// flag is true. Mirror of [imageToolSelfieAllowed]; fed into the
  /// resolved flag with session > character > false.
  bool? nameToolSuggestAllowed;

  Map<String, dynamic> toJson() => _$ConfigMediaCharacterToJson(this);
}

/// Session-layer media generation settings.
///
/// Holds every setting the chat drawer surfaces. Same coupled-tuple
/// pattern as [ConfigMediaCharacter] for the preset groups.
///
/// Two field sets distinguish session from character:
///
/// - Session has [imagePromptReview] / [videoPromptReview] (gates the
///   review dialog for *wand-triggered* generation) and
///   [imageToolPromptReview] (gates the dialog for *tool-triggered*
///   generation, e.g. `send_selfie`). These are user-trust calls, not
///   character properties, so they don't appear on [ConfigMediaCharacter].
/// - Session does NOT have `*PromptPrefix` fields. Prompt prefixes are
///   persona flavour the character ships with; there's no per-chat case
///   for overriding them.
@JsonSerializable(includeIfNull: false)
class ConfigMediaSession {
  ConfigMediaSession({
    String? imagePresetId,
    String? imageAspectRatioId,
    this.imageNsfwAllowed,
    this.imageToolSelfieAllowed,
    this.imageToolSelfieCaptionsAllowed,
    this.imagePromptReview,
    this.imageToolPromptReview,
    String? videoPresetId,
    String? videoResolutionId,
    String? videoAspectRatioId,
    int? videoDurationSeconds,
    this.videoNsfwAllowed,
    this.videoPromptReview,
    this.videoToolSendAllowed,
    String? ttsPresetId,
    String? ttsVoiceId,
    String? ttsLanguageCode,
    this.webToolFetchAllowed,
    this.webToolFetchReview,
    this.nameToolSuggestAllowed,
  }) : _imagePresetId = imagePresetId,
       _imageAspectRatioId = imageAspectRatioId,
       _videoPresetId = videoPresetId,
       _videoResolutionId = videoResolutionId,
       _videoAspectRatioId = videoAspectRatioId,
       _videoDurationSeconds = videoDurationSeconds,
       _ttsPresetId = ttsPresetId,
       _ttsVoiceId = ttsVoiceId,
       _ttsLanguageCode = ttsLanguageCode;

  factory ConfigMediaSession.fromJson(Map<String, dynamic> json) =>
      _$ConfigMediaSessionFromJson(json);

  // --- Image ---

  String? _imagePresetId;
  String? _imageAspectRatioId;

  String? get imagePresetId => _imagePresetId;
  String? get imageAspectRatioId => _imageAspectRatioId;

  void setImagePreset(String? presetId, String? aspectRatioId) {
    _imagePresetId = presetId;
    _imageAspectRatioId = aspectRatioId;
  }

  bool? imageNsfwAllowed;
  bool? imageToolSelfieAllowed;
  bool? imageToolSelfieCaptionsAllowed;
  bool? imagePromptReview;
  bool? imageToolPromptReview;

  // --- Video ---

  String? _videoPresetId;
  String? _videoResolutionId;
  String? _videoAspectRatioId;
  int? _videoDurationSeconds;

  String? get videoPresetId => _videoPresetId;
  String? get videoResolutionId => _videoResolutionId;
  String? get videoAspectRatioId => _videoAspectRatioId;
  int? get videoDurationSeconds => _videoDurationSeconds;

  void setVideoPreset(
    String? presetId,
    String? resolutionId,
    String? aspectRatioId,
    int? durationSeconds,
  ) {
    _videoPresetId = presetId;
    _videoResolutionId = resolutionId;
    _videoAspectRatioId = aspectRatioId;
    _videoDurationSeconds = durationSeconds;
  }

  bool? videoNsfwAllowed;
  bool? videoPromptReview;

  /// Lets the chat model call the `send_video` tool when the resolved
  /// flag is true. Mirror of [imageToolSelfieAllowed]; fed into the
  /// resolved flag with session > character > false.
  bool? videoToolSendAllowed;

  // --- TTS ---

  String? _ttsPresetId;
  String? _ttsVoiceId;
  String? _ttsLanguageCode;

  String? get ttsPresetId => _ttsPresetId;
  String? get ttsVoiceId => _ttsVoiceId;
  String? get ttsLanguageCode => _ttsLanguageCode;

  void setTtsPreset(String? presetId, String? voiceId, String? languageCode) {
    _ttsPresetId = presetId;
    _ttsVoiceId = voiceId;
    _ttsLanguageCode = languageCode;
  }

  // --- Web ---

  /// Lets the chat model call the `fetch_website` tool when the
  /// resolved flag is true. Mirror of [imageToolSelfieAllowed]; fed
  /// into the resolved flag with session > character > false.
  bool? webToolFetchAllowed;

  /// Shows the URL review dialog before each `fetch_website` call when
  /// true. Session-only; mirror of [imageToolPromptReview]. Reviewing a
  /// fetch is a per-chat trust call.
  bool? webToolFetchReview;

  // --- Names ---

  /// Lets the chat model call the `suggest_name` tool when the resolved
  /// flag is true. Mirror of [imageToolSelfieAllowed]; fed into the
  /// resolved flag with session > character > false.
  bool? nameToolSuggestAllowed;

  Map<String, dynamic> toJson() => _$ConfigMediaSessionToJson(this);
}

/// Merged result of [resolveMedia]. Holds every resolved field across all
/// three domains in flat prefix-grouped form, matching the input layer
/// classes' shape.
///
/// Each domain carries both the resolved preset object ([imagePreset] /
/// [videoPreset] / [ttsPreset], the `LlmProviderConfig` + `LlmModel`
/// bundle) and the resolved secondary ids (aspect / resolution / voice /
/// language). The preset object is null when no layer supplied a preset
/// id for that domain or the lookup failed — consumers null-check before
/// using the domain.
///
/// Coupled fields are resolved as a tuple — the first layer that supplies
/// the preset id wins the entire tuple (preset + aspect, or preset +
/// resolution + aspect + duration, or preset + voice + language).
/// Independent fields are resolved field-by-field with session > character
/// > app precedence, falling back to the listed default when no layer
/// sets them.
///
/// Not [JsonSerializable] — built only at runtime by the resolver,
/// never persisted.
class ConfigMediaResolved {
  const ConfigMediaResolved({
    // --- Image ---
    this.imagePreset,
    this.imageAspectRatioId,
    this.imageNsfwAllowed = false,
    this.imagePromptPrefix = '',
    this.imageToolSelfieAllowed = false,
    this.imageToolSelfieCaptionsAllowed = false,
    this.imagePromptReview = false,
    this.imageToolPromptReview = false,
    // --- Video ---
    this.videoPreset,
    this.videoResolutionId,
    this.videoAspectRatioId,
    this.videoDurationSeconds,
    this.videoNsfwAllowed = false,
    this.videoPromptPrefix = '',
    this.videoPromptReview = false,
    this.videoToolSendAllowed = false,
    // --- TTS ---
    this.ttsPreset,
    this.ttsVoiceId,
    this.ttsLanguageCode,
    // --- Web ---
    this.webToolFetchAllowed = false,
    this.webToolFetchReview = false,
    // --- Names ---
    this.nameToolSuggestAllowed = false,
  });

  // --- Image ---
  final ResolvedPreset? imagePreset;
  final String? imageAspectRatioId;
  final bool imageNsfwAllowed;
  final String imagePromptPrefix;
  final bool imageToolSelfieAllowed;
  final bool imageToolSelfieCaptionsAllowed;
  final bool imagePromptReview;
  final bool imageToolPromptReview;

  // --- Video ---
  final ResolvedPreset? videoPreset;
  final String? videoResolutionId;
  final String? videoAspectRatioId;
  final int? videoDurationSeconds;
  final bool videoNsfwAllowed;
  final String videoPromptPrefix;
  final bool videoPromptReview;
  final bool videoToolSendAllowed;

  // --- TTS ---
  final ResolvedPreset? ttsPreset;
  final String? ttsVoiceId;
  final String? ttsLanguageCode;

  // --- Web ---
  final bool webToolFetchAllowed;
  final bool webToolFetchReview;

  // --- Names ---
  final bool nameToolSuggestAllowed;

  /// Projects the TTS slice into a `ConfigTts`. Caller must have verified
  /// `ttsPreset != null`; the resolver guarantees the secondary fields are
  /// non-null whenever the preset is.
  ConfigTts toTtsConfig() =>
      ConfigTts(voiceId: ttsVoiceId!, languageCode: ttsLanguageCode!);
}
