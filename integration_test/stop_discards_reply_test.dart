import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:schemantic/schemantic.dart';

import 'app_test_helpers.dart';

/// Verifies the Stop button actually discards an in-flight 1:1 reply.
///
/// Turn 1 (control) lets a scripted reply complete and asserts it commits, so
/// the test can't pass simply because replies never land. Turn 2 simulates the
/// user tapping Stop mid-stream: the fake streams a partial token then flips
/// the same cancel flag `stopGeneration` sets, and hands back a `cancelled`
/// result. The reply must not be committed: no new assistant message, and the
/// partial streamed text must not survive.
bool _simulateStop = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'pressing Stop discards the in-flight 1:1 reply',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugRunnerFactory = null;
        _simulateStop = false;
      });

      await wipeAppData();

      const presetId = 'fake-preset';
      const modelId = 'fake-model';
      const providerId = 'fake-provider';
      final dir = await appDataDir();
      final settings = AppSettings(
        characterPath: dir.path,
        onboardingComplete: true,
        memoryEnabled: false,
        connectionProfiles: [
          LlmProviderConfig(
            id: providerId,
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
          LlmProviderDomainEnum.assistant: presetId,
          LlmProviderDomainEnum.system: presetId,
        },
        refreshPolicy: ModelRefreshPolicyEnum.never,
      );
      await File(
        '${dir.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
      ).writeAsString(jsonEncode(settings.toJson()));

      await seedTestCharacter();

      debugRunnerFactory =
          ({
            required provider,
            required model,
            required preset,
            paramOverrides,
          }) => _FakeRunner();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = (await characterService.loadByName(
        kSeedCharacterName,
      ))!;

      await tester.tap(findCharacterTile(testCharFile.card.displayName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      Future<void> sendAndWaitIdle(String prompt) async {
        controller.inputController.text = prompt;
        unawaited(controller.sendMessage());
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (!controller.isGenerating) return;
        }
        fail(
          'turn "$prompt" did not finish; generating=${controller.isGenerating}',
        );
      }

      int assistantCount() => controller.messages
          .where((m) => m.role == ChatRoleEnum.assistant)
          .length;

      // The chat opens on the character's greeting, which is itself an
      // assistant message, so count from that baseline rather than zero.
      final baseline = assistantCount();

      // Turn 1 (control): a normal reply commits.
      _simulateStop = false;
      await sendAndWaitIdle('first message');
      expect(
        assistantCount(),
        baseline + 1,
        reason: 'a normal reply should commit',
      );
      expect(
        controller.messages.any(
          (m) => m.content.contains(_FakeRunner.normalReply),
        ),
        isTrue,
        reason: 'the committed reply should carry the scripted text',
      );
      final afterTurn1 = assistantCount();

      // Turn 2: Stop mid-stream → the reply must be discarded.
      _simulateStop = true;
      await sendAndWaitIdle('second message');
      expect(
        assistantCount(),
        afterTurn1,
        reason: 'pressing Stop must not commit a reply',
      );
      expect(
        controller.messages.any(
          (m) => m.content.contains(_FakeRunner.partialText),
        ),
        isFalse,
        reason: 'the partial streamed text must not survive Stop',
      );
    },
  );
}

/// Scripted stand-in for [LlmRunner]. Returns a fixed reply normally; when the
/// top-level [_simulateStop] flag is set, it streams a partial token, flips the
/// cancel flag (as tapping Stop would), and reports `cancelled`.
class _FakeRunner extends LlmRunner {
  _FakeRunner()
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  static const String normalReply = 'A normal committed reply.';
  static const String partialText = 'This partial should vanish on stop';

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    if (_simulateStop) {
      onToken?.call(partialText);
      cancelToken?.value = true;
      return const LlmRunnerResult(
        text: partialText,
        visibleLen: partialText.length,
        reasoning: '',
        finishReason: 'cancelled',
        modelName: 'fake-model',
        configType: 'null',
        configRepr: 'null',
        toolCalls: [],
      );
    }
    onToken?.call(normalReply);
    return const LlmRunnerResult(
      text: normalReply,
      visibleLen: normalReply.length,
      reasoning: '',
      finishReason: 'stream',
      modelName: 'fake-model',
      configType: 'null',
      configRepr: 'null',
      toolCalls: [],
    );
  }

  // The nodes "director" runs each turn and asks for structured output; return
  // an empty object (no state changes) so it never reaches a real model.
  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async => const {};
}
