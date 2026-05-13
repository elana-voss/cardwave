// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmProviderConfig _$LlmProviderConfigFromJson(Map<String, dynamic> json) =>
    LlmProviderConfig(
      id: json['id'] as String,
      apiKey: json['api_key'] as String,
      providerEnum:
          $enumDecodeNullable(
            _$LLMProviderEnumEnumMap,
            json['provider'],
            unknownValue: LLMProviderEnum.nanogpt,
          ) ??
          LLMProviderEnum.nanogpt,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => LlmModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      baseUrl: json['base_url'] as String?,
      requireZdr: json['require_zdr'] as bool? ?? false,
    );

Map<String, dynamic> _$LlmProviderConfigToJson(LlmProviderConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'api_key': instance.apiKey,
      'base_url': ?instance.baseUrl,
      'provider': _$LLMProviderEnumEnumMap[instance.providerEnum]!,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'require_zdr': instance.requireZdr,
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
