// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_parameter_definition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmParameterDefinition _$LlmParameterDefinitionFromJson(
  Map<String, dynamic> json,
) => LlmParameterDefinition(
  id: $enumDecode(_$LlmParameterDefinitionIdEnumEnumMap, json['id']),
  name: json['name'] as String,
  description: json['description'] as String,
  min: (json['min'] as num).toDouble(),
  max: (json['max'] as num).toDouble(),
  defaultValue: (json['default_value'] as num).toDouble(),
  type: $enumDecode(_$LlmParameterDefinitionTypeEnumEnumMap, json['type']),
);

Map<String, dynamic> _$LlmParameterDefinitionToJson(
  LlmParameterDefinition instance,
) => <String, dynamic>{
  'id': _$LlmParameterDefinitionIdEnumEnumMap[instance.id]!,
  'name': instance.name,
  'description': instance.description,
  'min': instance.min,
  'max': instance.max,
  'default_value': instance.defaultValue,
  'type': _$LlmParameterDefinitionTypeEnumEnumMap[instance.type]!,
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

const _$LlmParameterDefinitionTypeEnumEnumMap = {
  LlmParameterDefinitionTypeEnum.integer: 'integer',
  LlmParameterDefinitionTypeEnum.double: 'double',
};
