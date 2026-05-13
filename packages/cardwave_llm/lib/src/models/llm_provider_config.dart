import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_preset_config.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'llm_provider_config.g.dart';

/// Represents an authenticated connection setup to a specific large
/// language model provider. Owns the set of [LlmModel]s the user has adopted
/// from this provider; each model in turn owns its [LlmPresetConfig]s.
@JsonSerializable()
class LlmProviderConfig {
  LlmProviderConfig({
    required this.id,
    required this.apiKey,
    required this.providerEnum,
    required this.models,
    this.baseUrl,
    this.requireZdr = false,
  });

  factory LlmProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderConfigFromJson(json);
  String id;
  String apiKey;
  @JsonKey(includeIfNull: false)
  String? baseUrl;
  @JsonKey(
    name: 'provider',
    defaultValue: LLMProviderEnum.nanogpt,
    unknownEnumValue: LLMProviderEnum.nanogpt,
  )
  LLMProviderEnum providerEnum;
  @JsonKey(defaultValue: [])
  List<LlmModel> models;
  @JsonKey(defaultValue: false)
  bool requireZdr;

  /// Flattened view of all presets across the provider's models.
  /// Computed — not serialized.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Iterable<LlmPresetConfig> get allPresets => models.expand((m) => m.presets);

  /// Flattened (model, preset) pairs — needed when the UI must show the
  /// model a preset belongs to.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Iterable<({LlmModel model, LlmPresetConfig preset})> get allModelPresets => [
    for (final m in models)
      for (final p in m.presets) (model: m, preset: p),
  ];
  Map<String, dynamic> toJson() => _$LlmProviderConfigToJson(this);
}
