import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/src/models/chat_persona.dart';
import 'package:cardwave/settings/src/models/chat_theme.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:json_annotation/json_annotation.dart';

part 'app_settings.g.dart';

@JsonSerializable(explicitToJson: true)
class AppSettings {
  AppSettings({
    this.characterPath,
    List<LlmProviderConfig>? connectionProfiles,
    this.themeMode = ThemeMode.dark,
    this.themeStyle = ThemeStyleEnum.standard,
    this.localeTag,
    this.chatTheme = ChatTheme.azure,
    Map<LlmProviderDomainEnum, String>? domainPresetIds,
    this.configMedia,
    String? defaultAssistantId,
    List<ChatPersona>? personas,
    String? defaultPersonaId,
    Map<String, String>? globalVariables,
    this.autoChatDelaySeconds = 4,
    this.groupActivationStrategy = GroupActivationStrategyEnum.natural,
    this.onboardingComplete = false,
    this.chatImageVisible = true,
    this.editorImageVisible = false,
    this.memoryEnabled = false,
    this.showRecalledMemory = false,
    this.showPromptBreakdown = false,
    this.assistantCardEditRequireApprovalForEdits = true,
    this.assistantCardEditRequireApprovalForAdditions = true,
    this.assistantCardEditRequireApprovalForDeletions = true,
    Map<String, bool>? drawerSectionAdvanced,
    this.refreshPolicy = ModelRefreshPolicyEnum.daily,
    this.lastModelRefreshAtMillis,
    this.schemaVersion = AppConstants.cacheVersion,
  }) : providerConfigs = connectionProfiles ?? [],
       domainPresetIds = domainPresetIds ?? {},
       globalVariables = globalVariables ?? {},
       drawerSectionAdvanced = drawerSectionAdvanced ?? {},
       defaultAssistantId =
           defaultAssistantId ?? AppConstants.defaultAssistantId,
       personas = (personas == null || personas.isEmpty)
           ? [
               ChatPersona(
                 name: AppConstants.defaultPersonaName,
                 description: '',
               ),
             ]
           : personas {
    if (defaultPersonaId == null ||
        !this.personas.any((p) => p.id == defaultPersonaId)) {
      // `personas` was normalized to a non-empty list in the initializer above.
      // ignore: qcheck/avoid_unsafe_collection_methods
      this.defaultPersonaId = this.personas.first.id;
    } else {
      this.defaultPersonaId = defaultPersonaId;
    }
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  String? characterPath;

  List<LlmProviderConfig> providerConfigs;

  ThemeMode themeMode;

  ThemeStyleEnum themeStyle;

  /// BCP-47 tag of the UI language ('ru', 'pt-BR', ...). Null follows the
  /// device locale.
  String? localeTag;

  ChatTheme chatTheme;

  /// Default preset id per non-media domain (`chat`, `assistant`, `system`).
  /// Media-domain preset ids live on [configMedia] instead — keep the two
  /// stores aligned with each domain's natural surface (chat/assistant/system
  /// have no aspect/voice/etc. so a flat map fits; media domains carry
  /// secondary fields that benefit from the per-layer config-class shape).
  /// Missing entries mean the user has no preset for that domain yet.
  @JsonKey(defaultValue: <LlmProviderDomainEnum, String>{})
  Map<LlmProviderDomainEnum, String> domainPresetIds;

  /// App-wide media generation defaults — preset id per domain (image, video,
  /// tts) only. Secondary fields (aspect / resolution / voice / language) are
  /// not stored at the app layer; the resolver fills them in from the
  /// resolved model's first available option. Null when no app-wide defaults
  /// are set yet (fresh install, before first AI Settings configuration).
  @JsonKey(includeIfNull: false)
  ConfigMediaApp? configMedia;

  List<ChatPersona> personas;

  String? defaultPersonaId;

  String? defaultAssistantId;

  @JsonKey(defaultValue: {})
  Map<String, String> globalVariables;

  @JsonKey(defaultValue: 4)
  int autoChatDelaySeconds;

  @JsonKey(defaultValue: GroupActivationStrategyEnum.natural)
  GroupActivationStrategyEnum groupActivationStrategy;

  /// True once the user has completed the onboarding flow. Defaults to
  /// false so a fresh install (or a wipe via `--fresh`) routes to onboarding.
  @JsonKey(defaultValue: false)
  bool onboardingComplete;

  @JsonKey(defaultValue: true)
  bool chatImageVisible;

  @JsonKey(defaultValue: false)
  bool editorImageVisible;

  /// Story memory: when on, the app remembers earlier moments in a chat and
  /// brings the relevant ones back into the prompt during long conversations.
  /// Gates both retrieval and background extraction. A power feature surfaced
  /// in Settings, not onboarding.
  @JsonKey(defaultValue: false)
  bool memoryEnabled;

  /// When on, each AI reply shows, beneath its text, the story-memory lines
  /// that informed it (dimmed footnotes). An insight aid for power users; off
  /// by default so basic users never see it. Only meaningful while
  /// [memoryEnabled] is on.
  @JsonKey(defaultValue: false)
  bool showRecalledMemory;

  /// When on, each AI reply shows a thin bar beneath it breaking down how its
  /// prompt filled the model's context window. A power-user insight aid; off
  /// by default. Independent of any other feature and applies to every chat.
  @JsonKey(defaultValue: false)
  bool showPromptBreakdown;

  /// Gate flags for assistant-chat tool-driven card edits. When false the
  /// modality auto-applies; when true the user sees the approval dialog
  /// before any change of that modality lands. All three default to true so
  /// the user reviews a before/after diff before the assistant changes any
  /// card field; a modality can be switched off from the assistant chat
  /// drawer.
  @JsonKey(defaultValue: true)
  bool assistantCardEditRequireApprovalForEdits;

  @JsonKey(defaultValue: true)
  bool assistantCardEditRequireApprovalForAdditions;

  @JsonKey(defaultValue: true)
  bool assistantCardEditRequireApprovalForDeletions;

  /// Per-section "Show advanced" expander state in the chat drawer. Keyed
  /// by section name (e.g. `chat`, `speech`, `video`, `image`); missing or
  /// `false` means the section's advanced rows are collapsed. Persisted so
  /// the user's expand/collapse choices survive a relaunch.
  @JsonKey(defaultValue: <String, bool>{})
  Map<String, bool> drawerSectionAdvanced;

  @JsonKey(defaultValue: ModelRefreshPolicyEnum.daily)
  ModelRefreshPolicyEnum refreshPolicy;

  int? lastModelRefreshAtMillis;

  String schemaVersion;

  ChatPersona get activePersona {
    if (personas.isEmpty) {
      return ChatPersona(
        name: AppConstants.defaultPersonaName,
        description: '',
      );
    }
    return personas.firstWhere(
      (p) => p.id == defaultPersonaId,
      orElse: () => personas.first,
    );
  }

  /// Reads the app-layer default preset id for [domain]. Routes media
  /// domains (image / video / audioTts) to [configMedia] and non-media
  /// domains (chat / assistant / system) to [domainPresetIds]. Returns
  /// null when no preset is set for that domain at the app layer.
  String? getAppDomainPresetId(LlmProviderDomainEnum domain) {
    switch (domain) {
      case LlmProviderDomainEnum.image:
        return configMedia?.imagePresetId;
      case LlmProviderDomainEnum.video:
        return configMedia?.videoPresetId;
      case LlmProviderDomainEnum.audioTts:
        return configMedia?.ttsPresetId;
      case LlmProviderDomainEnum.chat:
      case LlmProviderDomainEnum.assistant:
      case LlmProviderDomainEnum.system:
      case LlmProviderDomainEnum.audioMusic:
        return domainPresetIds[domain];
    }
  }

  /// Writes the app-layer default preset id for [domain]. Routes media
  /// domains (image / video / audioTts) to [configMedia] (allocating it
  /// if null) and other domains (chat / assistant / system / audioMusic)
  /// to [domainPresetIds]. Pass `null` to clear the domain.
  void setAppDomainPresetId(LlmProviderDomainEnum domain, String? presetId) {
    switch (domain) {
      case LlmProviderDomainEnum.image:
        (configMedia ??= ConfigMediaApp()).imagePresetId = presetId;
      case LlmProviderDomainEnum.video:
        (configMedia ??= ConfigMediaApp()).videoPresetId = presetId;
      case LlmProviderDomainEnum.audioTts:
        (configMedia ??= ConfigMediaApp()).ttsPresetId = presetId;
      case LlmProviderDomainEnum.chat:
      case LlmProviderDomainEnum.assistant:
      case LlmProviderDomainEnum.system:
      case LlmProviderDomainEnum.audioMusic:
        if (presetId == null) {
          domainPresetIds.remove(domain);
        } else {
          domainPresetIds[domain] = presetId;
        }
    }
  }

  /// Snapshot of every preset id currently assigned at the app layer,
  /// across all domains (image / video / TTS plus chat / assistant /
  /// system / audio-music). Used by the settings dialogs' "is this
  /// provider/preset in active use?" lock checks and by the preset-edit
  /// route's "active domains" display.
  Set<String> get activeAppDomainPresetIds => {
    for (final d in LlmProviderDomainEnum.values)
      if (getAppDomainPresetId(d) != null) getAppDomainPresetId(d)!,
  };

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
