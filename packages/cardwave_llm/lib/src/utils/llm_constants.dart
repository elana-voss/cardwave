/// Numeric fallbacks the LLM module uses when a model entry doesn't
/// declare its own context length / max output tokens. Mirrors the values
/// formerly read from `AppConstants` in lib/common/. Kept in sync with
/// `lib/common/src/utils/app_constants.dart` if those values ever change.
class LlmConstants {
  /// Used when a model's max-tokens field is absent in the parameter UI's
  /// default value (the slider's *current* default, not the absolute cap).
  static const double defaultMaxResponseTokens = 350;

  /// Cap for the max-output-tokens slider when the provider doesn't
  /// declare a model-specific limit; also seeded into `LlmModel` /
  /// provider-defaults when the API doesn't surface one.
  static const int fallbackMaxResponseTokens = 4096;

  /// Cap for the context-window slider when the provider doesn't declare
  /// one; also seeded into `LlmModel` / provider-defaults when missing.
  static const int fallbackContextLength = 128000;
}
