import 'package:json_annotation/json_annotation.dart';

part 'image_options.g.dart';

/// One aspect-ratio choice offered by an image model. [id] is the portable
/// display value the UI persists (`"1:1"`, `"16:9"`, `"9:16"`); each
/// provider subclass translates it into its own native JSON at submit time
/// (Grok and Flux take the ratio string directly as `aspect_ratio`; OpenAI
/// DALL-E 3 / gpt-image-1 map to a `size` like `"1792x1024"`).
@JsonSerializable()
class ImageAspectRatio {
  const ImageAspectRatio({required this.id, required this.label});

  factory ImageAspectRatio.fromJson(Map<String, dynamic> json) =>
      _$ImageAspectRatioFromJson(json);
  final String id;
  final String label;
  Map<String, dynamic> toJson() => _$ImageAspectRatioToJson(this);
}

/// Per-model image-generation roster. Attached to `LlmModel.optionsImage`
/// by `LlmPureHelpers.populateImageOptions` when an image-capable model is
/// adopted. Empty or null when the provider either has no aspect control
/// (legacy Grok image endpoint, some OpenRouter models) or the model is
/// not in our supported subset — the drawer tile hides itself in that
/// case so users don't see a non-functional picker.
@JsonSerializable()
class OptionsImage {
  const OptionsImage({required this.aspectRatios});

  factory OptionsImage.fromJson(Map<String, dynamic> json) =>
      _$OptionsImageFromJson(json);
  final List<ImageAspectRatio> aspectRatios;
  Map<String, dynamic> toJson() => _$OptionsImageToJson(this);
}

/// Concrete image-generation config consumed by provider dispatch. Built
/// from the resolved layer chain at request time; never persisted directly.
@JsonSerializable()
class ConfigImage {
  ConfigImage({required this.aspectRatioId});

  factory ConfigImage.fromJson(Map<String, dynamic> json) =>
      _$ConfigImageFromJson(json);
  String aspectRatioId;
  Map<String, dynamic> toJson() => _$ConfigImageToJson(this);
}
