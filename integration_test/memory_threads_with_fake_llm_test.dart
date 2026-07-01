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

/// Drives the event-type / cause / effect fields and the open-thread channel
/// end-to-end against a scripted runner (no network). Verifies, in one run:
///
/// - An extracted event reaches the next prompt under `<memory>` in the
///   three-line shape: a `[event_type]` tag on the text line, then a `Cause:`
///   and an `Effect:` line.
/// - An open thread commits to the graph and reaches `<memory>` as an
///   `(open thread)` line.
/// - A later turn that resolves the thread closes it: it stops reaching
///   `<memory>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'story memory — event type/cause/effect inject; open thread opens then resolves',
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
      final settings = AppSettings(
        characterPath: dir.path,
        onboardingComplete: true,
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

      // Distinctive texts that appear in no message or reply, so a <memory>
      // match only passes if retrieval put them there. "dragon" is in every
      // reply, so it is the thread subject that makes the open thread a
      // resolution candidate on the second extraction pass.
      const eventText = 'The hero faced the dragon at the gate.';
      const causeText = 'the dragon blocked the only road';
      const effectText = 'the village was left undefended';
      const threadText = 'The hero still owes the dragon an answer.';

      // Shared, mutable extraction output. Phase 1 opens an event + thread;
      // phase 2 opens nothing new and resolves the candidate thread T1.
      final extraction = <String, dynamic>{};
      void openPhase() {
        extraction
          ..clear()
          ..addAll(<String, dynamic>{
            'events': [
              <String, dynamic>{
                'text': eventText,
                'contextual_prefix': 'At the castle gate,',
                'event_type': 'conflict',
                'cause': causeText,
                'effect': effectText,
                'message_numbers': [1],
                'characters': ['the hero'],
                'locations': ['the gate'],
                'items': <String>[],
                'concepts': ['confrontation'],
                'keywords': ['dragon'],
                'importance': 4,
              },
            ],
            'facts': <Map<String, dynamic>>[],
            'threads': [
              <String, dynamic>{
                'subjects': ['dragon'],
                'text': threadText,
                'message_numbers': [1],
              },
            ],
            'resolved_threads': <String>[],
          });
      }

      void resolvePhase() {
        extraction
          ..clear()
          ..addAll(<String, dynamic>{
            'events': <Map<String, dynamic>>[],
            'facts': <Map<String, dynamic>>[],
            'threads': <Map<String, dynamic>>[],
            'resolved_threads': ['T1'],
          });
      }

      openPhase();

      final prompts = <String>[];
      debugRunnerFactory = ({
        required provider,
        required model,
        required preset,
        paramOverrides,
      }) => _FakeRunner(extraction: extraction, prompts: prompts);

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = (await characterService.loadAll()).firstWhere(
        (f) => f.card.displayName != kCassName,
        orElse: () => throw StateError('seedTestCharacter should add a card'),
      );

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

      Future<Map<String, dynamic>?> readGraph() async {
        if (!await AppStorage.instance.fileExists(
          StorageDomainEnum.cards,
          graphPath,
        )) {
          return null;
        }
        final content = await AppStorage.instance.readString(
          StorageDomainEnum.cards,
          graphPath,
        );
        return jsonDecode(content) as Map<String, dynamic>;
      }

      Future<Map<String, dynamic>> awaitGraphWhere(
        bool Function(Map<String, dynamic> graph) predicate,
      ) async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 300));
          final graph = await readGraph();
          if (graph != null && predicate(graph)) return graph;
        }
        fail('memory graph never reached the expected state within 60s');
      }

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
              (last?.role == ChatRoleEnum.assistant ||
                  last?.role == ChatRoleEnum.character)) {
            return;
          }
        }
        fail('chat turn for "$prompt" did not complete');
      }

      // Phase 1 — two turns clears the extraction cadence; the post-turn pass
      // commits one event and one open thread.
      await doTurn('Tell me what happened at the gate.');
      await doTurn('And then what did the dragon do?');

      final committed = await awaitGraphWhere(
        (graph) => (graph['events'] as List).isNotEmpty,
      );
      expect(
        (committed['threads'] as List),
        isNotEmpty,
        reason: 'open thread should commit alongside the event; graph=$committed',
      );

      // Retrieval turn — the event's three-line shape and the open thread
      // should reach <memory>. This turn does not clear the cadence.
      prompts.clear();
      await sendChatPrompt(tester, 'Remind me about the dragon.');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      final memoryPrompt = prompts.firstWhere(
        (prompt) => prompt.contains('<memory>') && prompt.contains(eventText),
        orElse: () => fail('the event text never reached <memory>'),
      );
      expect(
        memoryPrompt,
        contains('[conflict]'),
        reason: 'the event line carries its type tag',
      );
      expect(
        memoryPrompt,
        contains('Cause: $causeText'),
        reason: 'cause is its own line under the event',
      );
      expect(
        memoryPrompt,
        contains('Effect: $effectText'),
        reason: 'effect is its own line under the event',
      );
      expect(
        memoryPrompt,
        contains('(open thread) $threadText'),
        reason: 'the open thread reaches <memory>',
      );

      // Phase 2 — resolve the open thread (subject "dragon" makes it candidate
      // T1). Two turns clears the cadence again.
      resolvePhase();
      await doTurn('I gave the dragon my answer at last.');
      await doTurn('It accepted and flew off.');

      await awaitGraphWhere((graph) {
        final threads = graph['threads'] as List;
        return threads.isNotEmpty &&
            (threads.first as Map)['resolved_at'] != null;
      });

      // Retrieval turn — the resolved thread should no longer reach <memory>.
      prompts.clear();
      await sendChatPrompt(tester, 'Anything still hanging with the dragon?');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      expect(
        prompts.every((prompt) => !prompt.contains(threadText)),
        isTrue,
        reason: 'a resolved thread is no longer recalled',
      );
    },
  );
}

/// Scripted stand-in for [LlmRunner]: a constant reply for [generate] and a
/// caller-supplied extraction map for [completeStructured]. The reply mentions
/// "dragon" so the open thread stays a resolution candidate.
class _FakeRunner extends LlmRunner {
  _FakeRunner({required this.extraction, required this.prompts})
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  final Map<String, dynamic> extraction;
  final List<String> prompts;

  static const String _reply = 'The dragon guards the gate, then withdraws.';

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    prompts.add(messages.map((m) => m.content).join('\n'));
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
