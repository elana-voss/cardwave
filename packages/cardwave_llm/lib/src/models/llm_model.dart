import 'package:cardwave_llm/src/image/image_options.dart';
import 'package:cardwave_llm/src/models/llm_model_capabilities_enum.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';
import 'package:cardwave_llm/src/models/llm_preset_config.dart';
import 'package:cardwave_llm/src/models/tts_option.dart';
import 'package:cardwave_llm/src/models/video_option.dart';
import 'package:cardwave_llm/src/utils/llm_constants.dart';
import 'package:json_annotation/json_annotation.dart';

part 'llm_model.g.dart';

/// Persisted model descriptor. A [LlmModel] is snapshotted from the transient
/// fetch pipeline into `settings.json` when the user adopts it, and owns the
/// presets the user has defined against it.
@JsonSerializable()
class LlmModel {
  LlmModel({
    required this.id,
    required this.name,
    this.description,
    this.created,
    this.ownedBy,
    this.contextLength = LlmConstants.fallbackContextLength,
    this.maxOutputTokens = LlmConstants.fallbackMaxResponseTokens,
    this.capabilities = const LlmCapabilities(),
    this.supportedParameters = const [
      LlmParameterDefinitionIdEnum.temperature,
      LlmParameterDefinitionIdEnum.maxResponseLength,
    ],
    this.defaultParameters = const {},
    this.pricing,
    this.costEstimate,
    this.iconUrl,
    this.category,
    this.subscription,
    this.optionsTts,
    this.optionsVideo,
    this.optionsImage,
    List<LlmPresetConfig>? presets,
    this.isUnavailable = false,
  }) : presets = presets ?? [];

  factory LlmModel.fallback(String id) => LlmModel(id: id, name: id);

  factory LlmModel.fromJson(Map<String, dynamic> json) =>
      _$LlmModelFromJson(json);
  final String id;
  final String name;
  final String? description;
  final int? created;
  final String? ownedBy;
  final int contextLength;
  final int maxOutputTokens;
  final LlmCapabilities capabilities;
  final List<LlmParameterDefinitionIdEnum> supportedParameters;
  final Map<LlmParameterDefinitionIdEnum, double> defaultParameters;
  final LlmPricing? pricing;
  final double? costEstimate;
  final String? iconUrl;
  final String? category;
  final LlmSubscription? subscription;
  OptionsTts? optionsTts;

  /// Per-model video generation rosters (resolutions, aspect ratios,
  /// durations). Populated by `LlmPureHelpers.populateVideoOptions` at
  /// adoption time and on manual refresh from the provider's hardcoded
  /// per-model tables — no network round-trip. Null for non-video
  /// models (chat/image/audio) and for video models the provider didn't
  /// wire up in v1 (see the per-provider `_videoModelIds` sets).
  OptionsVideo? optionsVideo;

  /// Per-model image generation rosters (aspect ratios). Populated by
  /// `LlmPureHelpers.populateImageOptions` at the same three sites as
  /// [optionsVideo]. Null for non-image models and for image models the
  /// provider didn't wire up in v1 — in that case the drawer tile hides
  /// and the image request ships the provider's default size.
  OptionsImage? optionsImage;
  @JsonKey(defaultValue: [])
  List<LlmPresetConfig> presets;
  @JsonKey(defaultValue: false)
  bool isUnavailable;

  /// Deep clone via JSON round-trip. Canonical cloning pattern in this repo.
  static LlmModel clone(LlmModel model) => LlmModel.fromJson(model.toJson());

  int get contextSize => contextLength;

  int get maxResponseLength => maxOutputTokens;

  String get contextLabel => contextLength >= 1000
      ? '${contextLength ~/ 1000}k ctx'
      : '$contextLength ctx';

  String? get priceLabel {
    final p = pricing;
    if (p == null || (p.prompt == 0 && p.completion == 0)) return null;
    return '\$${_formatPrice(p.prompt)} / \$${_formatPrice(p.completion)} per Mtok';
  }

  static String _formatPrice(double v) {
    if (v == 0) return '0';
    if (v >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(3);
  }

  bool isParameterSupported(LlmParameterDefinitionIdEnum paramId) {
    if (paramId == LlmParameterDefinitionIdEnum.contextSize) return true;
    return supportedParameters.contains(paramId);
  }

  Map<String, dynamic> toJson() => _$LlmModelToJson(this);
}

@JsonSerializable()
class LlmCapabilities {
  const LlmCapabilities({
    this.inputModalities = const {LlmModelCapabilitiesEnum.text},
    this.outputModalities = const {LlmModelCapabilitiesEnum.text},
    this.reasoning = false,
    this.toolCalling = false,
    this.parallelToolCalls = false,
    this.structuredOutput = false,
  });

  factory LlmCapabilities.fromJson(Map<String, dynamic> json) =>
      _$LlmCapabilitiesFromJson(json);
  @JsonKey(fromJson: _modalitiesFromJson, toJson: _modalitiesToJson)
  final Set<LlmModelCapabilitiesEnum> inputModalities;
  @JsonKey(fromJson: _modalitiesFromJson, toJson: _modalitiesToJson)
  final Set<LlmModelCapabilitiesEnum> outputModalities;
  final bool reasoning;
  final bool toolCalling;
  final bool parallelToolCalls;
  final bool structuredOutput;
  Map<String, dynamic> toJson() => _$LlmCapabilitiesToJson(this);

  static Set<LlmModelCapabilitiesEnum> parseModalities(
    List<dynamic>? modalities,
  ) {
    if (modalities == null || modalities.isEmpty) {
      return {LlmModelCapabilitiesEnum.text};
    }
    final result = <LlmModelCapabilitiesEnum>{};
    for (final m in modalities) {
      switch (m.toString().toLowerCase()) {
        case 'text':
          result.add(LlmModelCapabilitiesEnum.text);
        case 'image':
          result.add(LlmModelCapabilitiesEnum.image);
        case 'audio':
        case 'audio_tts':
        case 'tts':
          result.add(LlmModelCapabilitiesEnum.audioTts);
        case 'audio_music':
        case 'music':
          result.add(LlmModelCapabilitiesEnum.audioMusic);
        case 'video':
          result.add(LlmModelCapabilitiesEnum.video);
        case 'file':
        case 'pdf':
          result.add(LlmModelCapabilitiesEnum.file);
        default:
          result.add(LlmModelCapabilitiesEnum.unknown);
      }
    }
    return result.isNotEmpty ? result : {LlmModelCapabilitiesEnum.text};
  }
}

Set<LlmModelCapabilitiesEnum> _modalitiesFromJson(dynamic raw) {
  if (raw is! List) return {LlmModelCapabilitiesEnum.text};
  final result = <LlmModelCapabilitiesEnum>{};
  for (final entry in raw) {
    final name = entry?.toString();
    if (name == null) continue;
    for (final v in LlmModelCapabilitiesEnum.values) {
      if (v.name == name) {
        result.add(v);
        break;
      }
    }
  }
  return result.isEmpty ? {LlmModelCapabilitiesEnum.text} : result;
}

List<String> _modalitiesToJson(Set<LlmModelCapabilitiesEnum> s) =>
    s.map((e) => e.name).toList();

/// Pricing in USD per 1,000,000 tokens. All provider parsers normalize to
/// this unit at parse time, so downstream code never branches on unit.
@JsonSerializable()
class LlmPricing {
  const LlmPricing({
    this.prompt = 0.0,
    this.completion = 0.0,
    this.currency = 'USD',
  });

  factory LlmPricing.fromJson(Map<String, dynamic> json) =>
      _$LlmPricingFromJson(json);
  final double prompt;
  final double completion;
  final String currency;
  Map<String, dynamic> toJson() => _$LlmPricingToJson(this);
}

@JsonSerializable()
class LlmSubscription {
  const LlmSubscription({this.included = false, this.note = ''});

  factory LlmSubscription.fromJson(Map<String, dynamic> json) =>
      _$LlmSubscriptionFromJson(json);
  final bool included;
  final String note;
  Map<String, dynamic> toJson() => _$LlmSubscriptionToJson(this);
}
