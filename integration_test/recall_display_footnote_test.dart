import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:schemantic/schemantic.dart';

import 'app_test_helpers.dart';

/// Drives the recalled-memory footnote end-to-end against a scripted runner
/// (no network). Builds one event and one fact in a chat's memory, sends a turn
/// that recalls them, then checks two things: the recalled lines are stored on
/// the reply's swipe, and the app-wide `showRecalledMemory` setting gates
/// whether they render as a dimmed footnote under the reply.
///
/// The drawer toggle widget itself (a thin `DrawerSwitchTile`) is not driven
/// here — the test flips the same setting the tile writes and asserts the
/// render, which is the part unique to this feature.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'recalled memory renders as a footnote only when the setting is on',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugRunnerFactory = null;
      });

      await wipeAppData();

      const presetId = 'fake-preset';
      const modelId = 'fake-model';
      const providerId = 'fake-provider';
      final dir = await getApplicationDocumentsDirectory();
      // memoryEnabled must be turned on explicitly now that the app defaults
      // it off; showRecalledMemory stays at its default-off so the footnote
      // starts hidden, and the test toggles it on later.
      final settings = AppSettings(
        characterPath: dir.path,
        onboardingComplete: true,
        memoryEnabled: true,
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

      // "kingdom" (the fact) and "hero faced" (the event) appear in neither the
      // user messages nor the scripted reply, so a match in the widget tree can
      // only be the footnote.
      const factText = 'The dragon rules the gate kingdom.';
      final extraction = <String, dynamic>{
        'events': [
          <String, dynamic>{
            'text': 'The hero faced the dragon at the gate.',
            'contextual_prefix': 'At the castle gate,',
            'message_numbers': [1],
            'characters': ['the hero'],
            'locations': ['the gate'],
            'items': <String>[],
            'concepts': ['confrontation'],
            'keywords': ['dragon'],
            'importance': 4,
          },
        ],
        'facts': [
          <String, dynamic>{
            'subjects': ['dragon'],
            'text': factText,
            'message_numbers': [1],
            'supersedes': null,
          },
        ],
      };

      debugRunnerFactory =
          ({
            required provider,
            required model,
            required preset,
            paramOverrides,
          }) => _FakeRunner(extraction: extraction);

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
      final sessionId = controller.chatSession!.id;
      final graphPath = p.posix.join(
        testCharFile.appCardChatsFolder,
        sessionId,
        'memory',
        'graph.json',
      );

      Future<bool> graphHasEvents() async {
        if (!await AppStorage.instance.fileExists(
          StorageDomainEnum.cards,
          graphPath,
        )) {
          return false;
        }
        final content = await AppStorage.instance.readString(
          StorageDomainEnum.cards,
          graphPath,
        );
        final graph = jsonDecode(content) as Map<String, dynamic>;
        return (graph['events'] as List).isNotEmpty;
      }

      // Drive a full turn through the controller (typing + send), then wait for
      // both the user message and the AI reply to land. Going through
      // sendMessage avoids the flaky consecutive-tap path a button send hits.
      Future<void> doTurn(String prompt) async {
        final before = controller.messages.length;
        controller.inputController.text = prompt;
        unawaited(controller.sendMessage());
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          // ignore: qcheck/avoid_unsafe_collection_methods
          final last = controller.messages.isEmpty
              ? null
              : controller.messages.last;
          if (!controller.isGenerating &&
              controller.messages.length >= before + 2 &&
              last?.role == ChatRoleEnum.assistant) {
            return;
          }
        }
        fail(
          'chat turn for "$prompt" did not complete: '
          'messages=${controller.messages.length} '
          'generating=${controller.isGenerating}',
        );
      }

      // Two turns clear the extraction cadence; the post-turn pass commits the
      // event and the fact.
      await doTurn('Tell me what happened at the gate.');
      await doTurn('And then what did the dragon do?');

      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline) && !await graphHasEvents()) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        await graphHasEvents(),
        isTrue,
        reason: 'extraction should commit an event before the recall turn',
      );

      // This turn retrieves the committed memory; its reply's swipe should
      // carry the recalled lines.
      await doTurn('Remind me about the dragon.');

      final recalled = controller.messages.last.activeSwipe.recalledMemory;
      expect(
        recalled.any((line) => line.contains('kingdom')),
        isTrue,
        reason: 'the recalled fact should be stored on the reply swipe',
      );
      expect(
        recalled.any((line) => line.contains('hero faced')),
        isTrue,
        reason: 'the recalled event should be stored on the reply swipe',
      );

      final settingsService = SettingsService();

      // Setting off (default) → no footnote rendered.
      expect(
        find.textContaining('kingdom'),
        findsNothing,
        reason: 'footnote must be hidden while showRecalledMemory is off',
      );

      // Setting on → the recalled lines render as a footnote. Exactly one match
      // each confirms only the recall turn's reply shows it.
      settingsService.settings.showRecalledMemory = true;
      await settingsService.saveSettings();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('kingdom'),
        findsOneWidget,
        reason: 'the recalled fact should show as a footnote when on',
      );
      expect(
        find.textContaining('hero faced'),
        findsOneWidget,
        reason: 'the recalled event should show as a footnote when on',
      );

      // Setting back off → the footnote disappears again.
      settingsService.settings.showRecalledMemory = false;
      await settingsService.saveSettings();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('kingdom'),
        findsNothing,
        reason: 'toggling off should hide the footnote again',
      );
    },
  );
}

/// Scripted stand-in for [LlmRunner]: a constant reply for [generate] and a
/// caller-supplied extraction map for [completeStructured].
class _FakeRunner extends LlmRunner {
  _FakeRunner({required this.extraction})
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  final Map<String, dynamic> extraction;

  static const String _reply = 'The dragon guards the gate, then withdraws.';

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    return const LlmRunnerResult(
      text: _reply,
      visibleLen: _reply.length,
      reasoning: '',
      finishReason: 'stream',
      modelName: 'fake-model',
      configType: 'null',
      configRepr: 'null',
      toolCalls: [],
    );
  }

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async => extraction;
}
