import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the bundled llm_defaults.json asset: parseable, complete, and
/// shaped the way the resolver expects (ordered non-empty preference lists).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remoteProviders = [
    LLMProviderEnum.anthropic,
    LLMProviderEnum.openai,
    LLMProviderEnum.google,
    LLMProviderEnum.grok,
    LLMProviderEnum.nanogpt,
    LLMProviderEnum.openrouter,
  ];

  late LlmDefaultsRepository repository;

  setUpAll(() async {
    repository = LlmDefaultsRepository();
    await repository.init();
  });

  test('every remote provider has chat and system preferences', () {
    for (final provider in remoteProviders) {
      final domains = repository.forProvider(provider);
      expect(
        domains[LlmProviderDomainEnum.chat],
        isNotNull,
        reason: '${provider.name} has no chat entry',
      );
      expect(
        domains[LlmProviderDomainEnum.system],
        isNotNull,
        reason: '${provider.name} has no system entry',
      );
    }
  });

  test('every preference list is non-empty with non-empty entries', () {
    for (final provider in remoteProviders) {
      for (final entry in repository.forProvider(provider).entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: '${provider.name}/${entry.key.name} list is empty',
        );
        for (final id in entry.value) {
          expect(
            id.trim(),
            isNotEmpty,
            reason: '${provider.name}/${entry.key.name} has a blank entry',
          );
        }
      }
    }
  });

  test('nanogpt and openrouter default to the same chat and system models', () {
    final nano = repository.forProvider(LLMProviderEnum.nanogpt);
    final openrouter = repository.forProvider(LLMProviderEnum.openrouter);
    expect(
      nano[LlmProviderDomainEnum.chat]!.first,
      openrouter[LlmProviderDomainEnum.chat]!.first,
    );
    // Same model, per-provider id spelling (deepseek-ai/... vs deepseek/...).
    for (final id in [
      nano[LlmProviderDomainEnum.system]!.first,
      openrouter[LlmProviderDomainEnum.system]!.first,
    ]) {
      expect(id.toLowerCase(), contains('deepseek-v3.1-terminus'));
    }
  });

  test('local providers have no defaults', () {
    expect(repository.forProvider(LLMProviderEnum.localOpenAi), isEmpty);
    expect(repository.forProvider(LLMProviderEnum.localGguf), isEmpty);
  });
}
