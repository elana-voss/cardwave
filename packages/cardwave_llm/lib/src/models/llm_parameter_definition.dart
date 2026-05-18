import 'dart:convert';

import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_type_enum.dart';
import 'package:cardwave_llm/src/utils/llm_constants.dart';
import 'package:json_annotation/json_annotation.dart';

part 'llm_parameter_definition.g.dart';

/// Represents the definition and constraints of a single configurable
/// parameter for a large language model.
@JsonSerializable(explicitToJson: true)
class LlmParameterDefinition {
  const LlmParameterDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.type,
  });

  factory LlmParameterDefinition.fromJson(Map<String, dynamic> json) =>
      _$LlmParameterDefinitionFromJson(json);
  final LlmParameterDefinitionIdEnum id;
  final String name;
  final String description;
  final double min;
  final double max;
  final double defaultValue;
  final LlmParameterDefinitionTypeEnum type;
  Map<String, dynamic> toJson() => _$LlmParameterDefinitionToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}

final List<LlmParameterDefinition> commonParameters = List.unmodifiable([
  // not const: `max`/`defaultValue` use `.toDouble()`, not a const expression
  LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.contextSize,
    name: 'Context Size',
    description: 'Limit of tokens to send to the model (Input).',
    min: 512,
    max: LlmConstants.fallbackContextLength.toDouble(),
    defaultValue: LlmConstants.fallbackContextLength.toDouble(),
    type: LlmParameterDefinitionTypeEnum.integer,
  ),
  // not const: `max` uses `.toDouble()`, not a const expression
  LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.maxResponseLength,
    name: 'Response Length',
    description: 'Maximum number of tokens to generate (Response).',
    min: 1,
    max: LlmConstants.fallbackMaxResponseTokens.toDouble(),
    defaultValue: LlmConstants.defaultMaxResponseTokens,
    type: LlmParameterDefinitionTypeEnum.integer,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.temperature,
    name: 'Temperature',
    description: 'Higher values make output more random.',
    min: 0,
    max: 2,
    defaultValue: 1,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.topP,
    name: 'Top P',
    description: 'Limits choices to the top percentage of probability.',
    min: 0,
    max: 1,
    defaultValue: 1,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.minP,
    name: 'Min P',
    description: 'Removes tokens less likely than a % of the best token.',
    min: 0,
    max: 1,
    defaultValue: 0,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.topK,
    name: 'Top K',
    description: 'Limits choices to the top K most likely tokens.',
    min: 0,
    max: 100,
    defaultValue: 0,
    type: LlmParameterDefinitionTypeEnum.integer,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.topA,
    name: 'Top A',
    description: 'Removes tokens with probability < (max_prob * top_a)^2.',
    min: 0,
    max: 1,
    defaultValue: 0,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.repetitionPenalty,
    name: 'Repetition Penalty',
    description: 'Penalty for repeating tokens (1.0 = no penalty).',
    min: 1,
    max: 2,
    defaultValue: 1,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.frequencyPenalty,
    name: 'Frequency Penalty',
    description: 'Penalizes tokens based on their frequency so far.',
    min: -2,
    max: 2,
    defaultValue: 0,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.presencePenalty,
    name: 'Presence Penalty',
    description: 'Penalizes tokens if they appear in the text at all.',
    min: -2,
    max: 2,
    defaultValue: 0,
    type: LlmParameterDefinitionTypeEnum.double,
  ),
  const LlmParameterDefinition(
    id: LlmParameterDefinitionIdEnum.seed,
    name: 'Seed',
    description: 'Deterministic generation seed.',
    min: -1,
    max: 4294967295, // Standard uint32 max
    defaultValue: -1,
    type: LlmParameterDefinitionTypeEnum.integer,
  ),
]);
