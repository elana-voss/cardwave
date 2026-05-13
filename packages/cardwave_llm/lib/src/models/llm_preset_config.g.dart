// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_preset_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmPresetConfig _$LlmPresetConfigFromJson(Map<String, dynamic> json) =>
    LlmPresetConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      parameterValues:
          (json['parameter_values'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              $enumDecode(_$LlmParameterDefinitionIdEnumEnumMap, k),
              (e as num).toDouble(),
            ),
          ) ??
          {},
      reasoningEffort:
          $enumDecodeNullable(
            _$LlmPresetConfigReasoningEffortEnumEnumMap,
            json['reasoning_effort'],
            unknownValue: LlmPresetConfigReasoningEffortEnum.off,
          ) ??
          LlmPresetConfigReasoningEffortEnum.off,
    );

Map<String, dynamic> _$LlmPresetConfigToJson(
  LlmPresetConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'parameter_values': instance.parameterValues.map(
    (k, e) => MapEntry(_$LlmParameterDefinitionIdEnumEnumMap[k]!, e),
  ),
  'reasoning_effort':
      _$LlmPresetConfigReasoningEffortEnumEnumMap[instance.reasoningEffort]!,
};

const _$LlmParameterDefinitionIdEnumEnumMap = {
  LlmParameterDefinitionIdEnum.temperature: 'temperature',
  LlmParameterDefinitionIdEnum.maxResponseLength: 'max_response_length',
  LlmParameterDefinitionIdEnum.contextSize: 'context_size',
  LlmParameterDefinitionIdEnum.topP: 'top_p',
  LlmParameterDefinitionIdEnum.minP: 'min_p',
  LlmParameterDefinitionIdEnum.topK: 'top_k',
  LlmParameterDefinitionIdEnum.topA: 'top_a',
  LlmParameterDefinitionIdEnum.repetitionPenalty: 'repetition_penalty',
  LlmParameterDefinitionIdEnum.frequencyPenalty: 'frequency_penalty',
  LlmParameterDefinitionIdEnum.presencePenalty: 'presence_penalty',
  LlmParameterDefinitionIdEnum.seed: 'seed',
};

const _$LlmPresetConfigReasoningEffortEnumEnumMap = {
  LlmPresetConfigReasoningEffortEnum.off: 'off',
  LlmPresetConfigReasoningEffortEnum.low: 'low',
  LlmPresetConfigReasoningEffortEnum.medium: 'medium',
  LlmPresetConfigReasoningEffortEnum.high: 'high',
};
