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
      modelPath: json['model_path'] as String?,
      contextSize: (json['context_size'] as num?)?.toInt(),
      kvCacheType: $enumDecodeNullable(
        _$KvCacheTypeEnumMap,
        json['kv_cache_type'],
      ),
      requireZdr: json['require_zdr'] as bool? ?? false,
    );

Map<String, dynamic> _$LlmProviderConfigToJson(LlmProviderConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'api_key': instance.apiKey,
      'base_url': ?instance.baseUrl,
      'model_path': ?instance.modelPath,
      'context_size': ?instance.contextSize,
      'kv_cache_type': ?_$KvCacheTypeEnumMap[instance.kvCacheType],
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
  LLMProviderEnum.localGguf: 'localGguf',
};

const _$KvCacheTypeEnumMap = {
  KvCacheType.f16: 'f16',
  KvCacheType.q8_0: 'q8_0',
  KvCacheType.q4_0: 'q4_0',
};
