import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/llm_app/src/media/media_resolver.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_row_shared.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Stateless orchestrator for media-settings write / clear / read paths.
/// Row widgets dispatch user taps to these static methods; the controller
/// branches on field type, mutates the right configMedia in place, and
/// hits the right service / controller to persist.
class MediaSettingsController {
  const MediaSettingsController._();

  // --- Writes / clears --------------------------------------------------

  static void writePreset({
    required SettingsService settingsService,
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required String presetId,
    required LlmModel model,
    required CharacterFile? character,
    required ChatSession? session,
    required ChatPageController? chatPageController,
  }) {
    switch (layer) {
      case MediaSettingsGridLayer.app:
        unawaited(
          settingsService.setDomainPreset(
            domainForPresetField(field),
            presetId,
          ),
        );
      case MediaSettingsGridLayer.character:
        if (character == null) return;
        ensureCharacterConfigMedia(character);
        final cm = character.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(presetId, firstImageAspectRatioId(model));
          case MediaSettingsGridField.videoModel:
            final opts = firstVideoOptions(model);
            if (opts == null) return;
            cm.setVideoPreset(
              presetId,
              opts.resolutionId,
              opts.aspectRatioId,
              opts.durationSeconds,
            );
          case MediaSettingsGridField.ttsModel:
            final opts = firstTtsOptions(model);
            if (opts == null) return;
            cm.setTtsPreset(presetId, opts.voiceId, opts.languageCode);
          default:
            return;
        }
        characterService.queueJsonInCacheDebounced(character);
      case MediaSettingsGridLayer.session:
        if (session == null || chatPageController == null) return;
        ensureSessionConfigMedia(session);
        final cm = session.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(presetId, firstImageAspectRatioId(model));
          case MediaSettingsGridField.videoModel:
            final opts = firstVideoOptions(model);
            if (opts == null) return;
            cm.setVideoPreset(
              presetId,
              opts.resolutionId,
              opts.aspectRatioId,
              opts.durationSeconds,
            );
          case MediaSettingsGridField.ttsModel:
            final opts = firstTtsOptions(model);
            if (opts == null) return;
            cm.setTtsPreset(presetId, opts.voiceId, opts.languageCode);
          default:
            return;
        }
        unawaited(chatPageController.persistActiveChat());
    }
  }

  static void clearPreset({
    required SettingsService settingsService,
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required CharacterFile? character,
    required ChatSession? session,
    required ChatPageController? chatPageController,
  }) {
    switch (layer) {
      case MediaSettingsGridLayer.app:
        unawaited(
          settingsService.setDomainPreset(domainForPresetField(field), null),
        );
      case MediaSettingsGridLayer.character:
        final cm = character?.configMedia;
        if (character == null || cm == null) return;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(null, null);
          case MediaSettingsGridField.videoModel:
            cm.setVideoPreset(null, null, null, null);
          case MediaSettingsGridField.ttsModel:
            cm.setTtsPreset(null, null, null);
          default:
            return;
        }
        characterService.queueJsonInCacheDebounced(character);
      case MediaSettingsGridLayer.session:
        final cm = session?.configMedia;
        if (session == null || chatPageController == null || cm == null) {
          return;
        }
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(null, null);
          case MediaSettingsGridField.videoModel:
            cm.setVideoPreset(null, null, null, null);
          case MediaSettingsGridField.ttsModel:
            cm.setTtsPreset(null, null, null);
          default:
            return;
        }
        unawaited(chatPageController.persistActiveChat());
    }
  }

  static void writeDropdown({
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required String value,
    required CharacterFile? character,
    required ChatSession? session,
    required ChatPageController? chatPageController,
  }) {
    switch (layer) {
      case MediaSettingsGridLayer.character:
        if (character == null) return;
        ensureCharacterConfigMedia(character);
        final cm = character.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageAspectRatio:
            cm.setImagePreset(cm.imagePresetId, value);
          case MediaSettingsGridField.videoResolution:
            cm.setVideoPreset(
              cm.videoPresetId,
              value,
              cm.videoAspectRatioId,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoAspectRatio:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              value,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoDuration:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              cm.videoAspectRatioId,
              int.parse(value),
            );
          case MediaSettingsGridField.ttsVoice:
            cm.setTtsPreset(cm.ttsPresetId, value, cm.ttsLanguageCode);
          case MediaSettingsGridField.ttsLanguage:
            cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, value);
          default:
            return;
        }
        characterService.queueJsonInCacheDebounced(character);
      case MediaSettingsGridLayer.session:
        if (session == null || chatPageController == null) return;
        ensureSessionConfigMedia(session);
        final cm = session.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageAspectRatio:
            cm.setImagePreset(cm.imagePresetId, value);
          case MediaSettingsGridField.videoResolution:
            cm.setVideoPreset(
              cm.videoPresetId,
              value,
              cm.videoAspectRatioId,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoAspectRatio:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              value,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoDuration:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              cm.videoAspectRatioId,
              int.parse(value),
            );
          case MediaSettingsGridField.ttsVoice:
            cm.setTtsPreset(cm.ttsPresetId, value, cm.ttsLanguageCode);
          case MediaSettingsGridField.ttsLanguage:
            cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, value);
          default:
            return;
        }
        unawaited(chatPageController.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  static void clearDropdown({
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required CharacterFile? character,
    required ChatSession? session,
    required ChatPageController? chatPageController,
  }) {
    // Clearing a dropdown writes null while keeping the preset id intact.
    switch (layer) {
      case MediaSettingsGridLayer.character:
        final cm = character?.configMedia;
        if (character == null || cm == null) return;
        switch (field) {
          case MediaSettingsGridField.imageAspectRatio:
            cm.setImagePreset(cm.imagePresetId, null);
          case MediaSettingsGridField.videoResolution:
            cm.setVideoPreset(
              cm.videoPresetId,
              null,
              cm.videoAspectRatioId,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoAspectRatio:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              null,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoDuration:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              cm.videoAspectRatioId,
              null,
            );
          case MediaSettingsGridField.ttsVoice:
            cm.setTtsPreset(cm.ttsPresetId, null, cm.ttsLanguageCode);
          case MediaSettingsGridField.ttsLanguage:
            cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, null);
          default:
            return;
        }
        characterService.queueJsonInCacheDebounced(character);
      case MediaSettingsGridLayer.session:
        final cm = session?.configMedia;
        if (session == null || chatPageController == null || cm == null) {
          return;
        }
        switch (field) {
          case MediaSettingsGridField.imageAspectRatio:
            cm.setImagePreset(cm.imagePresetId, null);
          case MediaSettingsGridField.videoResolution:
            cm.setVideoPreset(
              cm.videoPresetId,
              null,
              cm.videoAspectRatioId,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoAspectRatio:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              null,
              cm.videoDurationSeconds,
            );
          case MediaSettingsGridField.videoDuration:
            cm.setVideoPreset(
              cm.videoPresetId,
              cm.videoResolutionId,
              cm.videoAspectRatioId,
              null,
            );
          case MediaSettingsGridField.ttsVoice:
            cm.setTtsPreset(cm.ttsPresetId, null, cm.ttsLanguageCode);
          case MediaSettingsGridField.ttsLanguage:
            cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, null);
          default:
            return;
        }
        unawaited(chatPageController.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  static void writeTristate({
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required bool? value,
    required CharacterFile? character,
    required ChatSession? session,
    required ChatPageController? chatPageController,
  }) {
    switch (layer) {
      case MediaSettingsGridLayer.character:
        if (character == null) return;
        ensureCharacterConfigMedia(character);
        final cm = character.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageNsfwAllowed:
            cm.imageNsfwAllowed = value;
          case MediaSettingsGridField.imageToolSelfieAllowed:
            cm.imageToolSelfieAllowed = value;
          case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
            cm.imageToolSelfieCaptionsAllowed = value;
          case MediaSettingsGridField.videoNsfwAllowed:
            cm.videoNsfwAllowed = value;
          case MediaSettingsGridField.videoToolSendAllowed:
            cm.videoToolSendAllowed = value;
          case MediaSettingsGridField.webToolFetchAllowed:
            cm.webToolFetchAllowed = value;
          default:
            return;
        }
        characterService.queueJsonInCacheDebounced(character);
      case MediaSettingsGridLayer.session:
        if (session == null || chatPageController == null) return;
        ensureSessionConfigMedia(session);
        final cm = session.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageNsfwAllowed:
            cm.imageNsfwAllowed = value;
          case MediaSettingsGridField.imageToolSelfieAllowed:
            cm.imageToolSelfieAllowed = value;
          case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
            cm.imageToolSelfieCaptionsAllowed = value;
          case MediaSettingsGridField.videoNsfwAllowed:
            cm.videoNsfwAllowed = value;
          case MediaSettingsGridField.videoToolSendAllowed:
            cm.videoToolSendAllowed = value;
          case MediaSettingsGridField.webToolFetchAllowed:
            cm.webToolFetchAllowed = value;
          default:
            return;
        }
        unawaited(chatPageController.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  static void writePromptPrefix({
    required CharacterService characterService,
    required MediaSettingsGridField field,
    required String? value,
    required CharacterFile? character,
  }) {
    if (character == null) return;
    ensureCharacterConfigMedia(character);
    final cm = character.configMedia!;
    final stored = (value == null || value.isEmpty) ? null : value;
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        cm.imagePromptPrefix = stored;
      case MediaSettingsGridField.videoPromptPrefix:
        cm.videoPromptPrefix = stored;
      // ignore: no_default_cases
      default:
        return;
    }
    characterService.queueJsonInCacheDebounced(character);
  }

  // --- Reads ------------------------------------------------------------

  static String? readCharPresetId(
    CharacterFile? character,
    MediaSettingsGridField field,
  ) {
    final cm = character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return cm.imagePresetId;
      case MediaSettingsGridField.videoModel:
        return cm.videoPresetId;
      case MediaSettingsGridField.ttsModel:
        return cm.ttsPresetId;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  static String? readSessPresetId(
    ChatSession? session,
    MediaSettingsGridField field,
  ) {
    final cm = session?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return cm.imagePresetId;
      case MediaSettingsGridField.videoModel:
        return cm.videoPresetId;
      case MediaSettingsGridField.ttsModel:
        return cm.ttsPresetId;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  static String? readCharDropdownValue(
    CharacterFile? character,
    MediaSettingsGridField field,
  ) {
    final cm = character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return cm.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return cm.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return cm.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return cm.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return cm.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return cm.ttsLanguageCode;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  static String? readSessDropdownValue(
    ChatSession? session,
    MediaSettingsGridField field,
  ) {
    final cm = session?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return cm.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return cm.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return cm.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return cm.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return cm.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return cm.ttsLanguageCode;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  static bool? readCharBool(
    CharacterFile? character,
    MediaSettingsGridField field,
  ) {
    final cm = character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        return cm.imageNsfwAllowed;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        return cm.imageToolSelfieAllowed;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        return cm.imageToolSelfieCaptionsAllowed;
      case MediaSettingsGridField.videoNsfwAllowed:
        return cm.videoNsfwAllowed;
      case MediaSettingsGridField.videoToolSendAllowed:
        return cm.videoToolSendAllowed;
      case MediaSettingsGridField.webToolFetchAllowed:
        return cm.webToolFetchAllowed;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  static bool? readSessBool(
    ChatSession? session,
    MediaSettingsGridField field,
  ) {
    final cm = session?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        return cm.imageNsfwAllowed;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        return cm.imageToolSelfieAllowed;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        return cm.imageToolSelfieCaptionsAllowed;
      case MediaSettingsGridField.videoNsfwAllowed:
        return cm.videoNsfwAllowed;
      case MediaSettingsGridField.videoToolSendAllowed:
        return cm.videoToolSendAllowed;
      case MediaSettingsGridField.webToolFetchAllowed:
        return cm.webToolFetchAllowed;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  /// Returns null for both null storage AND empty strings — callers treat
  /// "no value" as a single concept regardless of which one happens to be
  /// on disk.
  static String? readCharPromptPrefix(
    CharacterFile? character,
    MediaSettingsGridField field,
  ) {
    final cm = character?.configMedia;
    if (cm == null) return null;
    String? raw;
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        raw = cm.imagePromptPrefix;
      case MediaSettingsGridField.videoPromptPrefix:
        raw = cm.videoPromptPrefix;
      // ignore: no_default_cases
      default:
        return null;
    }
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  // --- Domain mapping ---------------------------------------------------

  static LlmProviderDomainEnum domainForPresetField(
    MediaSettingsGridField field,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return LlmProviderDomainEnum.image;
      case MediaSettingsGridField.videoModel:
        return LlmProviderDomainEnum.video;
      case MediaSettingsGridField.ttsModel:
        return LlmProviderDomainEnum.audioTts;
      // ignore: no_default_cases
      default:
        throw StateError('Not a preset field: $field');
    }
  }

  static PromptPrefixDomain domainForTextField(MediaSettingsGridField field) {
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        return PromptPrefixDomain.image;
      case MediaSettingsGridField.videoPromptPrefix:
        return PromptPrefixDomain.video;
      // ignore: no_default_cases
      default:
        throw StateError('Not a prompt prefix field: $field');
    }
  }

}
