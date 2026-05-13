// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_providers_recovery.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmProvidersRecovery _$LlmProvidersRecoveryFromJson(
  Map<String, dynamic> json,
) => LlmProvidersRecovery(
  characterPath: json['character_path'] as String,
  schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
  providers:
      (json['providers'] as List<dynamic>?)
          ?.map(
            (e) => LlmProviderRecoveryEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$LlmProvidersRecoveryToJson(
  LlmProvidersRecovery instance,
) => <String, dynamic>{
  'schema_version': instance.schemaVersion,
  'character_path': instance.characterPath,
  'providers': instance.providers.map((e) => e.toJson()).toList(),
};

LlmProviderRecoveryEntry _$LlmProviderRecoveryEntryFromJson(
  Map<String, dynamic> json,
) => LlmProviderRecoveryEntry(
  id: json['id'] as String,
  providerType: $enumDecode(
    _$LLMProviderEnumEnumMap,
    json['provider_type'],
    unknownValue: LLMProviderEnum.nanogpt,
  ),
  apiKey: json['api_key'] as String,
  baseUrl: json['base_url'] as String?,
);

Map<String, dynamic> _$LlmProviderRecoveryEntryToJson(
  LlmProviderRecoveryEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'provider_type': _$LLMProviderEnumEnumMap[instance.providerType]!,
  'api_key': instance.apiKey,
  'base_url': ?instance.baseUrl,
};

const _$LLMProviderEnumEnumMap = {
  LLMProviderEnum.nanogpt: 'nanogpt',
  LLMProviderEnum.grok: 'grok',
  LLMProviderEnum.openrouter: 'openrouter',
  LLMProviderEnum.anthropic: 'anthropic',
  LLMProviderEnum.google: 'google',
  LLMProviderEnum.openai: 'openai',
  LLMProviderEnum.localOpenAi: 'localOpenAi',
};
