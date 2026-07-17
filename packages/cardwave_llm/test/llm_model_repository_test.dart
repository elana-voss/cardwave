import 'dart:convert';

import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('fetchModels per-entry isolation', () {
    test('one malformed catalog entry is skipped, not fatal', () async {
      // {"id": 42} throws TypeError inside parseModel (`json['id'] as
      // String`) — an Error, not an Exception. The valid entry must
      // survive it.
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 42},
              {'id': 'gpt-4o-mini'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = LlmModelRepository(httpClient: client);
      final models = await repository.fetchModels(
        providerEnum: LLMProviderEnum.openai,
        apiKey: 'test-key',
      );
      expect(models, hasLength(1));
      expect(models.single.id, 'gpt-4o-mini');
    });

    test('a non-map catalog entry is skipped, not fatal', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              'not-a-map',
              {'id': 'gpt-4o-mini'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = LlmModelRepository(httpClient: client);
      final models = await repository.fetchModels(
        providerEnum: LLMProviderEnum.openai,
        apiKey: 'test-key',
      );
      expect(models, hasLength(1));
      expect(models.single.id, 'gpt-4o-mini');
    });
  });
}
