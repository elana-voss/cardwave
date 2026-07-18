import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';

LlmModel model(
  String id, {
  String? name,
  int? created,
  Set<LlmModelCapabilitiesEnum> output = const {LlmModelCapabilitiesEnum.text},
  bool structuredOutput = false,
}) => LlmModel(
  id: id,
  name: name ?? id,
  created: created,
  capabilities: LlmCapabilities(
    outputModalities: output,
    structuredOutput: structuredOutput,
  ),
);

void main() {
  final helpers = LlmPureHelpers(
    repository: LlmModelRepository(),
    defaultsRepository: LlmDefaultsRepository(),
  );

  String resolveChat(List<String> preferences, List<LlmModel> models) =>
      helpers.resolveModelForDomain(
        LlmProviderDomainEnum.chat,
        preferences,
        models,
      );

  group('resolveModelForDomain — preference order', () {
    test('exact id match wins over a newer family match', () {
      final models = [
        model('claude-sonnet-6', created: 200),
        model('claude-sonnet-5', created: 100),
      ];
      expect(
        resolveChat(['claude-sonnet-5', 'sonnet'], models),
        'claude-sonnet-5',
      );
    });

    test('exact match also works on the display name', () {
      final models = [model('id-x', name: 'Sonnet 5')];
      expect(resolveChat(['Sonnet 5'], models), 'id-x');
    });

    test('dead concrete id falls through to the family word', () {
      final models = [
        model('claude-sonnet-6', created: 200),
        model('claude-haiku-5', created: 300),
      ];
      expect(
        resolveChat(['claude-sonnet-5', 'sonnet'], models),
        'claude-sonnet-6',
      );
    });

    test('earlier preference beats later preference', () {
      final models = [model('a-kimi-1'), model('b-deepseek-1')];
      expect(resolveChat(['kimi', 'deepseek'], models), 'a-kimi-1');
    });
  });

  group('resolveModelForDomain — family matching', () {
    test('picks the newest family member by release date', () {
      final models = [
        model('gemini-3.1-flash', created: 100),
        model('gemini-3.5-flash', created: 300),
        model('gemini-3.3-flash', created: 200),
      ];
      expect(resolveChat(['flash'], models), 'gemini-3.5-flash');
    });

    test('matching is case-insensitive', () {
      final models = [model('DeepSeek-V3.1-Terminus')];
      expect(resolveChat(['deepseek'], models), 'DeepSeek-V3.1-Terminus');
    });

    test('on missing release dates the first catalog entry wins', () {
      final models = [model('grok-4.5'), model('grok-4.3')];
      expect(resolveChat(['grok'], models), 'grok-4.5');
    });

    test('a newer model that cannot serve the domain is skipped', () {
      final models = [
        model(
          'grok-imagine-image',
          created: 300,
          output: {LlmModelCapabilitiesEnum.image},
        ),
        model('grok-4.5', created: 200),
      ];
      expect(resolveChat(['grok'], models), 'grok-4.5');
    });
  });

  group('resolveModelForDomain — domain requirements', () {
    test('system domain skips exact match without structured output', () {
      final models = [
        model('deepseek-v3.2', created: 300, structuredOutput: false),
        model('deepseek-v3.1', created: 200, structuredOutput: true),
      ];
      expect(
        helpers.resolveModelForDomain(
          LlmProviderDomainEnum.system,
          ['deepseek-v3.2', 'deepseek'],
          models,
        ),
        'deepseek-v3.1',
      );
    });

    test('image domain resolves an image-capable family match', () {
      final models = [
        model('gpt-5.6-terra', created: 300),
        model(
          'dall-e-3',
          created: 100,
          output: {LlmModelCapabilitiesEnum.image},
        ),
      ];
      expect(
        helpers.resolveModelForDomain(
          LlmProviderDomainEnum.image,
          ['dall-e-3', 'dall-e'],
          models,
        ),
        'dall-e-3',
      );
    });
  });

  group('resolveModelForDomain — fallbacks', () {
    test('no preference matches: first domain-capable model', () {
      final models = [
        model(
          'some-image-model',
          output: {LlmModelCapabilitiesEnum.image},
        ),
        model('some-text-model'),
      ];
      expect(resolveChat(['sonnet'], models), 'some-text-model');
    });

    test('empty preference list: first domain-capable model', () {
      final models = [model('anything')];
      expect(resolveChat(const [], models), 'anything');
    });

    test('nothing can serve the domain: empty string', () {
      final models = [
        model(
          'image-only',
          output: {LlmModelCapabilitiesEnum.image},
        ),
      ];
      expect(resolveChat(['image-only'], models), '');
    });

    test('empty catalog: empty string', () {
      expect(resolveChat(['sonnet'], const []), '');
    });
  });
}
