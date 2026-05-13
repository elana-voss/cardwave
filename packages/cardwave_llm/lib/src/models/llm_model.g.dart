// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmModel _$LlmModelFromJson(Map<String, dynamic> json) => LlmModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  created: (json['created'] as num?)?.toInt(),
  ownedBy: json['owned_by'] as String?,
  contextLength:
      (json['context_length'] as num?)?.toInt() ??
      LlmConstants.fallbackContextLength,
  maxOutputTokens:
      (json['max_output_tokens'] as num?)?.toInt() ??
      LlmConstants.fallbackMaxResponseTokens,
  capabilities: json['capabilities'] == null
      ? const LlmCapabilities()
      : LlmCapabilities.fromJson(json['capabilities'] as Map<String, dynamic>),
  supportedParameters:
      (json['supported_parameters'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$LlmParameterDefinitionIdEnumEnumMap, e))
          .toList() ??
      const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.maxResponseLength,
      ],
  defaultParameters:
      (json['default_parameters'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$LlmParameterDefinitionIdEnumEnumMap, k),
          (e as num).toDouble(),
        ),
      ) ??
      const {},
  pricing: json['pricing'] == null
      ? null
      : LlmPricing.fromJson(json['pricing'] as Map<String, dynamic>),
  costEstimate: (json['cost_estimate'] as num?)?.toDouble(),
  iconUrl: json['icon_url'] as String?,
  category: json['category'] as String?,
  subscription: json['subscription'] == null
      ? null
      : LlmSubscription.fromJson(json['subscription'] as Map<String, dynamic>),
  optionsTts: json['options_tts'] == null
      ? null
      : OptionsTts.fromJson(json['options_tts'] as Map<String, dynamic>),
  optionsVideo: json['options_video'] == null
      ? null
      : OptionsVideo.fromJson(json['options_video'] as Map<String, dynamic>),
  optionsImage: json['options_image'] == null
      ? null
      : OptionsImage.fromJson(json['options_image'] as Map<String, dynamic>),
  presets:
      (json['presets'] as List<dynamic>?)
          ?.map((e) => LlmPresetConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  isUnavailable: json['is_unavailable'] as bool? ?? false,
);

Map<String, dynamic> _$LlmModelToJson(LlmModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'created': instance.created,
  'owned_by': instance.ownedBy,
  'context_length': instance.contextLength,
  'max_output_tokens': instance.maxOutputTokens,
  'capabilities': instance.capabilities.toJson(),
  'supported_parameters': instance.supportedParameters
      .map((e) => _$LlmParameterDefinitionIdEnumEnumMap[e]!)
      .toList(),
  'default_parameters': instance.defaultParameters.map(
    (k, e) => MapEntry(_$LlmParameterDefinitionIdEnumEnumMap[k]!, e),
  ),
  'pricing': instance.pricing?.toJson(),
  'cost_estimate': instance.costEstimate,
  'icon_url': instance.iconUrl,
  'category': instance.category,
  'subscription': instance.subscription?.toJson(),
  'options_tts': instance.optionsTts?.toJson(),
  'options_video': instance.optionsVideo?.toJson(),
  'options_image': instance.optionsImage?.toJson(),
  'presets': instance.presets.map((e) => e.toJson()).toList(),
  'is_unavailable': instance.isUnavailable,
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

LlmCapabilities _$LlmCapabilitiesFromJson(Map<String, dynamic> json) =>
    LlmCapabilities(
      inputModalities: json['input_modalities'] == null
          ? const {LlmModelCapabilitiesEnum.text}
          : _modalitiesFromJson(json['input_modalities']),
      outputModalities: json['output_modalities'] == null
          ? const {LlmModelCapabilitiesEnum.text}
          : _modalitiesFromJson(json['output_modalities']),
      reasoning: json['reasoning'] as bool? ?? false,
      toolCalling: json['tool_calling'] as bool? ?? false,
      parallelToolCalls: json['parallel_tool_calls'] as bool? ?? false,
      structuredOutput: json['structured_output'] as bool? ?? false,
    );

Map<String, dynamic> _$LlmCapabilitiesToJson(LlmCapabilities instance) =>
    <String, dynamic>{
      'input_modalities': _modalitiesToJson(instance.inputModalities),
      'output_modalities': _modalitiesToJson(instance.outputModalities),
      'reasoning': instance.reasoning,
      'tool_calling': instance.toolCalling,
      'parallel_tool_calls': instance.parallelToolCalls,
      'structured_output': instance.structuredOutput,
    };

LlmPricing _$LlmPricingFromJson(Map<String, dynamic> json) => LlmPricing(
  prompt: (json['prompt'] as num?)?.toDouble() ?? 0.0,
  completion: (json['completion'] as num?)?.toDouble() ?? 0.0,
  currency: json['currency'] as String? ?? 'USD',
);

Map<String, dynamic> _$LlmPricingToJson(LlmPricing instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
      'completion': instance.completion,
      'currency': instance.currency,
    };

LlmSubscription _$LlmSubscriptionFromJson(Map<String, dynamic> json) =>
    LlmSubscription(
      included: json['included'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );

Map<String, dynamic> _$LlmSubscriptionToJson(LlmSubscription instance) =>
    <String, dynamic>{'included': instance.included, 'note': instance.note};
