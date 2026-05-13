import 'package:json_annotation/json_annotation.dart';

enum LlmParameterDefinitionIdEnum {
  @JsonValue('temperature')
  temperature('temperature'),
  @JsonValue('max_response_length')
  maxResponseLength('max_response_length'),
  @JsonValue('context_size')
  contextSize('context_size'),
  @JsonValue('top_p')
  topP('top_p'),
  @JsonValue('min_p')
  minP('min_p'),
  @JsonValue('top_k')
  topK('top_k'),
  @JsonValue('top_a')
  topA('top_a'),
  @JsonValue('repetition_penalty')
  repetitionPenalty('repetition_penalty'),
  @JsonValue('frequency_penalty')
  frequencyPenalty('frequency_penalty'),
  @JsonValue('presence_penalty')
  presencePenalty('presence_penalty'),
  @JsonValue('seed')
  seed('seed')
  ;

  final String jsonKey;
  const LlmParameterDefinitionIdEnum(this.jsonKey);
}
