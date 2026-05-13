import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/mock_local_llm_server.dart';

/// Risk #1 gate from the local-provider integration-test plan:
/// `dart:io HttpServer.bind` has no precedent in this repo's test suite,
/// so we don't yet know whether an in-process mock can bind a loopback
/// port inside an `integration_test` running on an Android emulator.
///
/// This test does NOT load the Flutter app. It just starts the mock
/// server, bounces one GET through `dart:io`'s HttpClient to verify the
/// 200 + JSON shape, and shuts the server down. Green here means the
/// architecture works and we can build the UI tests on top of it. Red
/// here means the whole approach needs rethinking before going further.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mock OpenAI-compat server bounces GET /v1/models',
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      if (kIsWeb) {
        markTestSkipped(
          'Android-only: uses HttpServer.bind for mock LLM server',
        );
        return;
      }
      final server = MockLocalLlmServer();
      await server.start();
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse('${server.baseUrl}/models'));
        final resp = await req.close();
        expect(resp.statusCode, 200, reason: 'mock should return 200');

        final body = await resp.transform(utf8.decoder).join();
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        expect(
          parsed['data'],
          isList,
          reason: 'response should match OpenAI list shape',
        );
        expect((parsed['data'] as List).first, isA<Map<String, dynamic>>());
        expect(
          server.requestCount,
          1,
          reason: 'mock should have recorded exactly one request',
        );
      } finally {
        client.close();
        await server.stop();
      }
    },
  );
}
