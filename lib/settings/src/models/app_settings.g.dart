// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) =>
    AppSettings(
        characterPath: json['character_path'] as String?,
        themeMode:
            $enumDecodeNullable(_$ThemeModeEnumMap, json['theme_mode']) ??
            ThemeMode.dark,
        chatTheme: json['chat_theme'] == null
            ? ChatTheme.azure
            : ChatTheme.fromJson(json['chat_theme'] as Map<String, dynamic>),
        domainPresetIds:
            (json['domain_preset_ids'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(
                $enumDecode(_$LlmProviderDomainEnumEnumMap, k),
                e as String,
              ),
            ) ??
            {},
        configMedia: json['config_media'] == null
            ? null
            : ConfigMediaApp.fromJson(
                json['config_media'] as Map<String, dynamic>,
              ),
        defaultAssistantId: json['default_assistant_id'] as String?,
        personas: (json['personas'] as List<dynamic>?)
            ?.map((e) => ChatPersona.fromJson(e as Map<String, dynamic>))
            .toList(),
        defaultPersonaId: json['default_persona_id'] as String?,
        globalVariables:
            (json['global_variables'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as String),
            ) ??
            {},
        autoChatDelaySeconds:
            (json['auto_chat_delay_seconds'] as num?)?.toInt() ?? 4,
        groupActivationStrategy:
            $enumDecodeNullable(
              _$GroupActivationStrategyEnumEnumMap,
              json['group_activation_strategy'],
            ) ??
            GroupActivationStrategyEnum.natural,
        onboardingComplete: json['onboarding_complete'] as bool? ?? false,
        chatImageVisible: json['chat_image_visible'] as bool? ?? true,
        editorImageVisible: json['editor_image_visible'] as bool? ?? false,
        drawerSectionAdvanced:
            (json['drawer_section_advanced'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as bool),
            ) ??
            {},
        refreshPolicy:
            $enumDecodeNullable(
              _$ModelRefreshPolicyEnumEnumMap,
              json['refresh_policy'],
            ) ??
            ModelRefreshPolicyEnum.daily,
        lastModelRefreshAtMillis: (json['last_model_refresh_at_millis'] as num?)
            ?.toInt(),
        schemaVersion:
            json['schema_version'] as String? ?? AppConstants.cacheVersion,
      )
      ..providerConfigs = (json['provider_configs'] as List<dynamic>)
          .map((e) => LlmProviderConfig.fromJson(e as Map<String, dynamic>))
          .toList();

Map<String, dynamic> _$AppSettingsToJson(
  AppSettings instance,
) => <String, dynamic>{
  'character_path': instance.characterPath,
  'provider_configs': instance.providerConfigs.map((e) => e.toJson()).toList(),
  'theme_mode': _$ThemeModeEnumMap[instance.themeMode]!,
  'chat_theme': instance.chatTheme.toJson(),
  'domain_preset_ids': instance.domainPresetIds.map(
    (k, e) => MapEntry(_$LlmProviderDomainEnumEnumMap[k]!, e),
  ),
  'config_media': ?instance.configMedia?.toJson(),
  'personas': instance.personas.map((e) => e.toJson()).toList(),
  'default_persona_id': instance.defaultPersonaId,
  'default_assistant_id': instance.defaultAssistantId,
  'global_variables': instance.globalVariables,
  'auto_chat_delay_seconds': instance.autoChatDelaySeconds,
  'group_activation_strategy':
      _$GroupActivationStrategyEnumEnumMap[instance.groupActivationStrategy]!,
  'onboarding_complete': instance.onboardingComplete,
  'chat_image_visible': instance.chatImageVisible,
  'editor_image_visible': instance.editorImageVisible,
  'drawer_section_advanced': instance.drawerSectionAdvanced,
  'refresh_policy': _$ModelRefreshPolicyEnumEnumMap[instance.refreshPolicy]!,
  'last_model_refresh_at_millis': instance.lastModelRefreshAtMillis,
  'schema_version': instance.schemaVersion,
};

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

const _$LlmProviderDomainEnumEnumMap = {
  LlmProviderDomainEnum.chat: 'chat',
  LlmProviderDomainEnum.system: 'system',
  LlmProviderDomainEnum.assistant: 'assistant',
  LlmProviderDomainEnum.image: 'image',
  LlmProviderDomainEnum.audioTts: 'audioTts',
  LlmProviderDomainEnum.audioMusic: 'audioMusic',
  LlmProviderDomainEnum.video: 'video',
};

const _$GroupActivationStrategyEnumEnumMap = {
  GroupActivationStrategyEnum.natural: 'natural',
  GroupActivationStrategyEnum.list: 'list',
  GroupActivationStrategyEnum.random: 'random',
};

const _$ModelRefreshPolicyEnumEnumMap = {
  ModelRefreshPolicyEnum.never: 'never',
  ModelRefreshPolicyEnum.daily: 'daily',
};
