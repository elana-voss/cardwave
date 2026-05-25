import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_preset_config.dart';
import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:llamadart/llamadart.dart' show KvCacheType;
import 'package:path/path.dart' as p;

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
    this.modelPath,
    this.contextSize,
    this.kvCacheType,
    this.requireZdr = false,
  });

  factory LlmProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderConfigFromJson(json);
  String id;
  String apiKey;
  @JsonKey(includeIfNull: false)
  String? baseUrl;

  /// Filesystem path to a GGUF file. Set only on `localGguf` profiles.
  @JsonKey(includeIfNull: false)
  String? modelPath;

  /// Loaded context size in tokens. Set only on `localGguf` profiles.
  @JsonKey(includeIfNull: false)
  int? contextSize;

  /// KV-cache quantization for the loaded model. Null = llama.cpp default
  /// (fp16). Set only on `localGguf` profiles.
  @JsonKey(includeIfNull: false)
  KvCacheType? kvCacheType;

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
      for (final pres in m.presets) (model: m, preset: pres),
  ];

  /// User-facing name for this profile's section header. Generic
  /// providers (OpenAI, Anthropic) use the provider type label. Local
  /// GGUF profiles use the filename of `modelPath` minus the `.gguf`
  /// extension — each profile is one model file, and the type label
  /// repeats identically across every locally-added profile.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get displayLabel {
    if (providerEnum == LLMProviderEnum.localGguf) {
      final path = modelPath;
      if (path != null && path.isNotEmpty) {
        return p.basenameWithoutExtension(path);
      }
    }
    return LlmProvider.of(providerEnum).label;
  }

  Map<String, dynamic> toJson() => _$LlmProviderConfigToJson(this);
}
