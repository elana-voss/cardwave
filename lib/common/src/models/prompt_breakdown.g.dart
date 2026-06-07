// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_breakdown.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromptSegmentEntry _$PromptSegmentEntryFromJson(Map<String, dynamic> json) =>
    PromptSegmentEntry(
      kind: $enumDecode(_$PromptSegmentKindEnumEnumMap, json['kind']),
      tokens: (json['tokens'] as num).toInt(),
    );

Map<String, dynamic> _$PromptSegmentEntryToJson(PromptSegmentEntry instance) =>
    <String, dynamic>{
      'kind': _$PromptSegmentKindEnumEnumMap[instance.kind]!,
      'tokens': instance.tokens,
    };

const _$PromptSegmentKindEnumEnumMap = {
  PromptSegmentKindEnum.identity: 'identity',
  PromptSegmentKindEnum.systemPrompt: 'systemPrompt',
  PromptSegmentKindEnum.nsfwMode: 'nsfwMode',
  PromptSegmentKindEnum.scenarioMode: 'scenarioMode',
  PromptSegmentKindEnum.description: 'description',
  PromptSegmentKindEnum.personality: 'personality',
  PromptSegmentKindEnum.scenario: 'scenario',
  PromptSegmentKindEnum.userPersona: 'userPersona',
  PromptSegmentKindEnum.memory: 'memory',
  PromptSegmentKindEnum.situation: 'situation',
  PromptSegmentKindEnum.cardData: 'cardData',
  PromptSegmentKindEnum.tools: 'tools',
  PromptSegmentKindEnum.postHistory: 'postHistory',
  PromptSegmentKindEnum.depthPrompt: 'depthPrompt',
  PromptSegmentKindEnum.worldInfo: 'worldInfo',
  PromptSegmentKindEnum.injected: 'injected',
  PromptSegmentKindEnum.exampleDialogue: 'exampleDialogue',
  PromptSegmentKindEnum.history: 'history',
  PromptSegmentKindEnum.currentMessage: 'currentMessage',
  PromptSegmentKindEnum.reservedReply: 'reservedReply',
};

PromptContextBreakdown _$PromptContextBreakdownFromJson(
  Map<String, dynamic> json,
) => PromptContextBreakdown(
  contextSize: (json['context_size'] as num).toInt(),
  reservedReply: (json['reserved_reply'] as num).toInt(),
  segments: (json['segments'] as List<dynamic>)
      .map((e) => PromptSegmentEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  realInputTokens: (json['real_input_tokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$PromptContextBreakdownToJson(
  PromptContextBreakdown instance,
) => <String, dynamic>{
  'context_size': instance.contextSize,
  'reserved_reply': instance.reservedReply,
  'real_input_tokens': ?instance.realInputTokens,
  'segments': instance.segments.map((e) => e.toJson()).toList(),
};
