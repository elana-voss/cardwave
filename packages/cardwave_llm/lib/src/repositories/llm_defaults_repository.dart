import 'dart:convert';

import 'package:cardwave_llm/src/models/llm_provider_domain_enum.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The "best model" defaults per provider and per domain (chat / system /
/// assistant / image / speech / video), loaded once from a bundled JSON asset
/// so they can be hand-edited (and later script-updated) without touching Dart.
///
/// The JSON is keyed by [LLMProviderEnum.name] then [LlmProviderDomainEnum.name].
/// Providers with no sensible default (the two local ones) are simply absent.
class LlmDefaultsRepository {
  // Flutter exposes package assets at "packages/<pkg>/<asset>" via rootBundle.
  static const _assetPath = 'packages/cardwave_llm/assets/llm_defaults.json';

  final Map<LLMProviderEnum, Map<LlmProviderDomainEnum, String>> _byProvider =
      {};
  bool _initialized = false;

  Future<void> init() async {
    final raw =
        jsonDecode(await rootBundle.loadString(_assetPath))
            as Map<String, dynamic>;
    for (final providerEntry in raw.entries) {
      final providerEnum = LLMProviderEnum.values.byName(providerEntry.key);
      final domains = <LlmProviderDomainEnum, String>{};
      for (final domainEntry
          in (providerEntry.value as Map<String, dynamic>).entries) {
        final domain = LlmProviderDomainEnum.values.byName(domainEntry.key);
        domains[domain] = domainEntry.value as String;
      }
      _byProvider[providerEnum] = domains;
    }
    _initialized = true;
  }

  /// Default model ids for [providerEnum], empty for providers with no entry
  /// (the two local providers). Throws if [init] has not run, so a too-early
  /// caller fails loudly instead of silently getting the wrong defaults.
  Map<LlmProviderDomainEnum, String> forProvider(LLMProviderEnum providerEnum) {
    if (!_initialized) {
      throw StateError(
        'LlmDefaultsRepository.init() must run before reading defaults.',
      );
    }
    return _byProvider[providerEnum] ?? const {};
  }
}
