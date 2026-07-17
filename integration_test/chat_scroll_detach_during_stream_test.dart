// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Regression test for the chat-scroll bug: while a reply streams, scrolling
/// up to read earlier messages used to snap you back to the bottom. Cause: the
/// streaming bubble was blanked on detach, the list collapsed, and the scroll
/// clamped to the bottom. Streams a long reply via a fake runner, then jumps
/// the scroll to several offsets mid-stream and asserts the position holds and
/// the list does not collapse.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const modelId = 'fake-model';

  testWidgets(
    'scrolling up mid-stream holds position instead of snapping to bottom',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      addTearDown(() => debugRunnerFactory = null);

      await wipeAppData();
      await seedTestCharacter();

      // Web has no real filesystem; seed settings through AppStorage
      // (IndexedDB) instead of a dart:io file, same as app_test_helpers.
      final docsPath =
          kIsWeb ? '' : (await appDataDir()).path;
      const presetId = 'fake-preset';
      final settings = AppSettings(
        characterPath: docsPath,
        onboardingComplete: true,
        connectionProfiles: [
          LlmProviderConfig(
            id: 'fake-provider',
            apiKey: 'unused-by-fake',
            providerEnum: LLMProviderEnum.nanogpt,
            models: [
              LlmModel(
                id: modelId,
                name: modelId,
                capabilities: const LlmCapabilities(toolCalling: true),
                presets: [LlmPresetConfig(id: presetId, name: 'fake')],
              ),
            ],
          ),
        ],
        domainPresetIds: const {
          LlmProviderDomainEnum.chat: presetId,
        },
        refreshPolicy: ModelRefreshPolicyEnum.never,
      );
      final settingsJson = jsonEncode(settings.toJson());
      if (kIsWeb) {
        await AppStorage.instance.init((_) => '');
        await AppStorage.instance.writeString(
          StorageDomainEnum.settings,
          AppConstants.settingsFileName,
          settingsJson,
        );
      } else {
        await File(
          '$docsPath${Platform.pathSeparator}${AppConstants.settingsFileName}',
        ).writeAsString(settingsJson);
      }

      // Every reply streams ~40 lines at ~150ms/line (~6s window) so the
      // bubble grows well past the viewport and there is time to scroll.
      final longChunks = List<String>.generate(
        120,
        (i) => 'Paragraph ${i + 1}: the quick brown fox jumps over the lazy '
            'dog and keeps on running into the night.\n\n',
      );
      debugRunnerFactory = ({
        required provider,
        required model,
        required preset,
        paramOverrides,
      }) => _StreamingFakeRunner(longChunks, const Duration(milliseconds: 150));

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      await tester.tap(findCharacterTile(kSeedCharacterName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final ScrollController sc = controller.scrollController;

      await sendChatPrompt(tester, 'tell me a long story');

      // Let the stream grow the bubble tall (do NOT await idle).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      print('SCROLLPROBE start: gen=${controller.isGenerating} '
          'pixels=${sc.position.pixels} detached=${controller.userDetached} '
          'maxExtent=${sc.position.maxScrollExtent}');

      var assertedTrials = 0;
      // Scroll up to [offset] mid-stream and confirm the position holds. The
      // bug blanked the bubble on detach, collapsing the list (maxScrollExtent
      // -> 0) and clamping pixels back to 0 with detached flipping to false.
      Future<void> trial(String label, double offset) async {
        if (sc.hasClients) sc.jumpTo(0); // re-attach so the bubble re-grows
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));
        final maxBefore = sc.position.maxScrollExtent;
        final target = offset.clamp(0.0, maxBefore);
        sc.jumpTo(target);
        await tester.pump(const Duration(milliseconds: 50));
        final maxAfterDetach = sc.position.maxScrollExtent;
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final pixels = sc.position.pixels;
        final detached = controller.userDetached;
        final gen = controller.isGenerating;
        print('SCROLLPROBE trial=$label target=$target maxBefore=$maxBefore '
            'maxAfterDetach=$maxAfterDetach => pixels=$pixels '
            'detached=$detached gen=$gen');
        // Only assert while the reply is still streaming and the target is
        // clearly past the stick threshold — that is the broken window.
        if (gen && target > AppConstants.chatScrollStickThreshold * 4) {
          assertedTrials++;
          expect(detached, isTrue,
              reason: '$label: reader should stay detached mid-stream');
          expect(maxAfterDetach, greaterThan(target),
              reason: '$label: list collapsed on detach '
                  '(maxScrollExtent=$maxAfterDetach)');
          expect(pixels, greaterThan(target / 2),
              reason: '$label: scroll should hold near $target, not snap to '
                  'the bottom (got $pixels)');
        }
      }

      await trial('small', 60);
      await trial('medium', 150);
      await trial('large', 500);

      expect(assertedTrials, greaterThan(0),
          reason: 'no trial ran while the reply was streaming — the test would '
              'pass without exercising the bug (did the fake reply stream?)');

      await awaitChatIdle(tester, timeout: const Duration(seconds: 20));
    },
  );
}

class _StreamingFakeRunner extends LlmRunner {
  _StreamingFakeRunner(this._chunks, this._delay)
      : super(
          model: gk.Model<Object?>(
            name: 'fake-model',
            fn: (_, __) =>
                throw UnimplementedError('fake runner: model.fn unused'),
          ),
          genkit: gk.Genkit(isDevEnv: false),
        );

  final List<String> _chunks;
  final Duration _delay;

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    final buffer = StringBuffer();
    for (final chunk in _chunks) {
      if (cancelToken?.value == true) break;
      onToken?.call(chunk);
      buffer.write(chunk);
      await Future<void>.delayed(_delay);
    }
    final text = buffer.toString();
    return LlmRunnerResult(
      text: text,
      visibleLen: text.length,
      reasoning: '',
      finishReason: 'stream',
      modelName: 'fake-model',
      configType: 'null',
      configRepr: 'null',
      toolCalls: const [],
    );
  }
}
