import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/services/settings_service.dart'
    show SettingsService;
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:json_annotation/json_annotation.dart';

part 'llm_providers_recovery.g.dart';

/// Disaster-recovery mirror of the few fields per `LlmProviderConfig` that
/// carry user-entered credentials. Written alongside every
/// `cardwave_settings.json` save by `SettingsService.saveSettings`, read
/// only when `SettingsService.init` finds settings.json missing or
/// invalidated. Carries its own [schemaVersion], independent of
/// [AppConstants.cacheVersion], so bumping the settings schema never
/// wipes it. That's the whole point: API keys are plain strings and
/// shouldn't be collateral damage from a settings-schema evolution.
@JsonSerializable()
class LlmProvidersRecovery {
  const LlmProvidersRecovery({
    required this.characterPath,
    this.schemaVersion = 1,
    List<LlmProviderRecoveryEntry>? providers,
  }) : providers = providers ?? const [];

  factory LlmProvidersRecovery.fromJson(Map<String, dynamic> json) =>
      _$LlmProvidersRecoveryFromJson(json);
  @JsonKey(defaultValue: 1)
  final int schemaVersion;

  /// Absolute filesystem path the user picked for character PNG/JSON
  /// storage on desktop, or the platform-deterministic
  /// `getApplicationDocumentsDirectory()` path on Android/iOS, or `''` on
  /// Web. Mirrored uniformly on all three — desktop gains real
  /// preservation across schema bumps, mobile/web round-trip their
  /// platform-deterministic values as a no-op. Required because the app
  /// never produces a recovery file without a valid path at write time
  /// ([SettingsService.init]'s `??=` guarantees non-null before the
  /// first save).
  final String characterPath;

  @JsonKey(defaultValue: <LlmProviderRecoveryEntry>[])
  final List<LlmProviderRecoveryEntry> providers;
  Map<String, dynamic> toJson() => _$LlmProvidersRecoveryToJson(this);
}

/// One row in [LlmProvidersRecovery.providers]. The minimum needed to
/// reconstruct a usable `LlmProviderConfig` after a settings wipe — id,
/// provider type, API key, and optional base URL. Models, presets, and
/// domain-preset assignments are not stored; they regenerate from scratch
/// during the rebuild because defaults may legitimately have changed
/// across versions.
@JsonSerializable()
class LlmProviderRecoveryEntry {
  const LlmProviderRecoveryEntry({
    required this.id,
    required this.providerType,
    required this.apiKey,
    this.baseUrl,
  });

  factory LlmProviderRecoveryEntry.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderRecoveryEntryFromJson(json);
  final String id;

  @JsonKey(unknownEnumValue: LLMProviderEnum.nanogpt)
  final LLMProviderEnum providerType;

  final String apiKey;

  @JsonKey(includeIfNull: false)
  final String? baseUrl;
  Map<String, dynamic> toJson() => _$LlmProviderRecoveryEntryToJson(this);
}
