import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/llm_app/src/models/config_media.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Resolves the effective media-generation config across app / character /
/// session layers into a single [ConfigMediaResolved].
///
/// Two merge patterns:
/// - **Coupled tuples** — preset id + its secondary fields per domain
///   (preset+aspect, preset+resolution+aspect+duration, preset+voice+
///   language). Take-the-tuple-as-a-whole: the first layer with a non-null
///   preset id wins the entire tuple. App layer is preset-id-only — if
///   it wins, the secondary fields are seeded from the resolved model's
///   first available option.
/// - **Independent fields** — NSFW gate, prompt prefix, tool flags,
///   review flags. Field-by-field merge, session > character > app
///   precedence, falling back to the listed default when no layer sets
///   them.
///
/// Each layer is consulted only for fields it actually has — [ConfigMediaApp]
/// carries no NSFW or tool fields, [ConfigMediaCharacter] carries no
/// review fields, etc. — so reading missing fields on a layer is a
/// compile error, not a silent runtime no-op.
ConfigMediaResolved resolveMedia({
  required AppSettings settings,
  required LlmPureHelpers pureHelpers,
  ChatSession? session,
  CharacterFile? character,
}) {
  final appConfig = settings.configMedia;
  final characterConfig = character?.configMedia;
  final sessionConfig = session?.configMedia;
  final providers = settings.providerConfigs;

  // Layer-supplied secondaries sit in `layer*` locals and only promote
  // to the output when the preset resolves — keeps the invariant
  // "secondaries non-null iff preset non-null" structural.
  ResolvedPreset? imagePreset;
  String? imageAspectRatioId;
  {
    String? presetId;
    String? layerAspectRatioId;
    if (sessionConfig?.imagePresetId != null) {
      presetId = sessionConfig!.imagePresetId;
      layerAspectRatioId = sessionConfig.imageAspectRatioId;
    } else if (characterConfig?.imagePresetId != null) {
      presetId = characterConfig!.imagePresetId;
      layerAspectRatioId = characterConfig.imageAspectRatioId;
    } else {
      presetId = appConfig?.imagePresetId;
    }
    if (presetId != null && presetId.isNotEmpty) {
      final preset = pureHelpers.resolvePresetOrNull(
        configId: presetId,
        providers: providers,
      );
      if (preset != null) {
        imagePreset = preset;
        imageAspectRatioId =
            layerAspectRatioId ?? firstImageAspectRatioId(preset.model);
      }
    }
  }

  // Video preset is dropped entirely if the model has no video roster
  // (no resolutions/aspects/durations to seed from).
  ResolvedPreset? videoPreset;
  String? videoResolutionId;
  String? videoAspectRatioId;
  int? videoDurationSeconds;
  {
    String? presetId;
    String? layerResolutionId;
    String? layerAspectRatioId;
    int? layerDurationSeconds;
    if (sessionConfig?.videoPresetId != null) {
      presetId = sessionConfig!.videoPresetId;
      layerResolutionId = sessionConfig.videoResolutionId;
      layerAspectRatioId = sessionConfig.videoAspectRatioId;
      layerDurationSeconds = sessionConfig.videoDurationSeconds;
    } else if (characterConfig?.videoPresetId != null) {
      presetId = characterConfig!.videoPresetId;
      layerResolutionId = characterConfig.videoResolutionId;
      layerAspectRatioId = characterConfig.videoAspectRatioId;
      layerDurationSeconds = characterConfig.videoDurationSeconds;
    } else {
      presetId = appConfig?.videoPresetId;
    }
    if (presetId != null && presetId.isNotEmpty) {
      final preset = pureHelpers.resolvePresetOrNull(
        configId: presetId,
        providers: providers,
      );
      final seed = preset == null ? null : firstVideoOptions(preset.model);
      if (preset != null && seed != null) {
        videoPreset = preset;
        videoResolutionId = layerResolutionId ?? seed.resolutionId;
        videoAspectRatioId = layerAspectRatioId ?? seed.aspectRatioId;
        videoDurationSeconds = layerDurationSeconds ?? seed.durationSeconds;
      }
    }
  }

  // TTS preset is dropped entirely if the model has no voice roster.
  ResolvedPreset? ttsPreset;
  String? ttsVoiceId;
  String? ttsLanguageCode;
  {
    String? presetId;
    String? layerVoiceId;
    String? layerLanguageCode;
    if (sessionConfig?.ttsPresetId != null) {
      presetId = sessionConfig!.ttsPresetId;
      layerVoiceId = sessionConfig.ttsVoiceId;
      layerLanguageCode = sessionConfig.ttsLanguageCode;
    } else if (characterConfig?.ttsPresetId != null) {
      presetId = characterConfig!.ttsPresetId;
      layerVoiceId = characterConfig.ttsVoiceId;
      layerLanguageCode = characterConfig.ttsLanguageCode;
    } else {
      presetId = appConfig?.ttsPresetId;
    }
    if (presetId != null && presetId.isNotEmpty) {
      final preset = pureHelpers.resolvePresetOrNull(
        configId: presetId,
        providers: providers,
      );
      final seed = preset == null ? null : firstTtsOptions(preset.model);
      if (preset != null && seed != null) {
        ttsPreset = preset;
        ttsVoiceId = layerVoiceId ?? seed.voiceId;
        ttsLanguageCode = layerLanguageCode ?? seed.languageCode;
      }
    }
  }

  return ConfigMediaResolved(
    // --- Image ---
    imagePreset: imagePreset,
    imageAspectRatioId: imageAspectRatioId,
    imageNsfwAllowed:
        sessionConfig?.imageNsfwAllowed ??
        characterConfig?.imageNsfwAllowed ??
        false,
    imagePromptPrefix: characterConfig?.imagePromptPrefix ?? '',
    imageToolSelfieAllowed:
        sessionConfig?.imageToolSelfieAllowed ??
        characterConfig?.imageToolSelfieAllowed ??
        false,
    imageToolSelfieCaptionsAllowed:
        sessionConfig?.imageToolSelfieCaptionsAllowed ??
        characterConfig?.imageToolSelfieCaptionsAllowed ??
        false,
    imagePromptReview: sessionConfig?.imagePromptReview ?? false,
    imageToolPromptReview: sessionConfig?.imageToolPromptReview ?? false,
    // --- Video ---
    videoPreset: videoPreset,
    videoResolutionId: videoResolutionId,
    videoAspectRatioId: videoAspectRatioId,
    videoDurationSeconds: videoDurationSeconds,
    videoNsfwAllowed:
        sessionConfig?.videoNsfwAllowed ??
        characterConfig?.videoNsfwAllowed ??
        false,
    videoPromptPrefix: characterConfig?.videoPromptPrefix ?? '',
    videoPromptReview: sessionConfig?.videoPromptReview ?? false,
    videoToolSendAllowed:
        sessionConfig?.videoToolSendAllowed ??
        characterConfig?.videoToolSendAllowed ??
        false,
    // --- TTS ---
    ttsPreset: ttsPreset,
    ttsVoiceId: ttsVoiceId,
    ttsLanguageCode: ttsLanguageCode,
    // --- Web ---
    webToolFetchAllowed:
        sessionConfig?.webToolFetchAllowed ??
        characterConfig?.webToolFetchAllowed ??
        false,
    webToolFetchReview: sessionConfig?.webToolFetchReview ?? false,
    // --- Names ---
    nameToolSuggestAllowed:
        sessionConfig?.nameToolSuggestAllowed ??
        characterConfig?.nameToolSuggestAllowed ??
        false,
  );
}

/// First aspect ratio id from [model]'s image roster, or `null` when the
/// model exposes no aspect control (legacy Grok image, some OpenRouter
/// models). Caller writes the result through the paired image setter; the
/// provider dispatcher falls back to its default size when null.
String? firstImageAspectRatioId(LlmModel model) {
  final aspects = model.optionsImage?.aspectRatios;
  if (aspects == null || aspects.isEmpty) return null;
  return aspects.first.id;
}

/// First-of-each video roster entry from [model], or `null` when the model
/// has no video roster at all. Used both by the resolver fallthrough and
/// by tap handlers that swap presets via the paired video setter.
({String resolutionId, String aspectRatioId, int durationSeconds})?
firstVideoOptions(LlmModel model) {
  final options = model.optionsVideo;
  if (options == null) return null;
  // A model that exposes a video roster always carries at least one
  // resolution, aspect ratio, and duration (provider definitions never
  // build an empty `OptionsVideo`).
  return (
    // ignore: qcheck/avoid_unsafe_collection_methods
    resolutionId: options.resolutions.first.id,
    // ignore: qcheck/avoid_unsafe_collection_methods
    aspectRatioId: options.aspectRatios.first.id,
    // ignore: qcheck/avoid_unsafe_collection_methods
    durationSeconds: options.durations.first.seconds,
  );
}

/// First voice from [model] paired with the auto-detect language code, or
/// `null` when the model has no voice roster.
({String voiceId, String languageCode})? firstTtsOptions(LlmModel model) {
  final voices = model.optionsTts?.voices;
  if (voices == null || voices.isEmpty) return null;
  return (voiceId: voices.first.id, languageCode: TtsLanguage.autoCode);
}
