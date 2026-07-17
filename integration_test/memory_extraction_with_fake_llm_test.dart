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
import 'package:provider/provider.dart';
import 'package:schemantic/schemantic.dart';

import 'app_test_helpers.dart';

/// Drives story memory end-to-end against a scripted runner (no network). The
/// same fake stands in for both the chat reply (`generate`) and the memory
/// extraction (`completeStructured`); the test switches what extraction returns
/// between phases by mutating the shared [extraction] map. Verifies, in one run:
///
/// - After enough turns, an event and a fact commit to the on-disk graph file.
/// - A later turn whose extraction overrides the known fact retires it: the new
///   fact is current, the old one is marked superseded.
/// - The current fact (not the superseded one) and the event reach the next
///   prompt under `<memory>` (and not in the assistant-only
///   `supplemental_data_context`).
/// - Deleting the message the superseding fact was drawn from revives the
///   original fact — it is current again and the superseding fact is gone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'story memory — commit, supersede, retrieve current fact, revive on delete',
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
      final dir = await appDataDir();
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
        // The system domain drives memory extraction; chat drives replies.
        domainPresetIds: const {
          LlmProviderDomainEnum.chat: presetId,
          LlmProviderDomainEnum.system: presetId,
        },
        refreshPolicy: ModelRefreshPolicyEnum.never,
      );
      await File(
        '${dir.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
      ).writeAsString(jsonEncode(settings.toJson()));

      await seedTestCharacter();

      // Distinctive fact texts: the kingdom fact is committed first, superseded
      // by the mountains fact, then revived. The event text ("hero faced") is
      // constant across phases and appears in no message or reply, so the
      // <memory> assertion only passes if retrieval put it there.
      const factKingdom = 'The dragon rules the gate kingdom.';
      const factMountains = 'The dragon has fled to the mountains.';

      // Shared, mutable extraction output. The fake reads it live; the test
      // rewrites its contents (clear + addAll) to advance phases. A null
      // [factText] commits an event but no fact.
      final extraction = <String, dynamic>{};
      void setExtraction({String? factText, String? supersedes}) {
        extraction
          ..clear()
          ..addAll(<String, dynamic>{
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
              if (factText != null)
                <String, dynamic>{
                  'subjects': ['dragon'],
                  'text': factText,
                  'message_numbers': [1],
                  'supersedes': supersedes,
                },
            ],
          });
      }

      setExtraction(factText: factKingdom);

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

      Future<Map<String, dynamic>> awaitGraphWithEvents() async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 300));
          final graph = await readGraph();
          if (graph != null && (graph['events'] as List).isNotEmpty) {
            return graph;
          }
        }
        fail('memory graph never committed an event within 60s');
      }

      // Drive a full turn through the controller (typing + send), then wait
      // for the user message and the AI reply to both land. Going through
      // sendMessage rather than tapping the send button avoids the flaky
      // consecutive-tap path and the stale-idle race a button send hits.
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
        fail(
          'chat turn for "$prompt" did not complete: '
          'messages=${controller.messages.length} '
          'generating=${controller.isGenerating}',
        );
      }

      // Phase 1 — two turns clears the extraction cadence; the post-turn pass
      // commits one event and the kingdom fact.
      await doTurn('Tell me what happened at the gate.');
      await doTurn('And then what did the dragon do?');

      final committed = await awaitGraphWithEvents();
      expect(
        (committed['events'] as List),
        isNotEmpty,
        reason: 'extraction should have committed at least one event',
      );
      expect(
        _factContaining(committed, 'kingdom'),
        isNotNull,
        reason: 'the kingdom fact should commit',
      );
      expect(
        _factContaining(committed, 'kingdom')!['superseded_at'],
        isNull,
        reason: 'the kingdom fact is current when first committed',
      );

      // Phase 2 — the next extraction overrides the kingdom fact with the
      // mountains fact. Both windows mention "dragon" (it is in every reply),
      // so the kingdom fact is offered as candidate F1 and the new fact retires
      // it. Two turns clears the cadence again.
      setExtraction(factText: factMountains, supersedes: 'F1');
      await doTurn('Where is the dragon now?');
      await doTurn('Are you sure it left the kingdom?');

      final superseded = await _awaitGraphWhere(tester, readGraph, (graph) {
        final old = _factContaining(graph, 'kingdom');
        final neu = _factContaining(graph, 'mountains');
        return old != null &&
            old['superseded_at'] != null &&
            neu != null &&
            neu['superseded_at'] == null;
      });
      expect(
        _factContaining(superseded, 'kingdom')!['superseded_at'],
        isNotNull,
        reason: 'the kingdom fact is retired once the mountains fact overrides it',
      );

      // Retrieval turn — the current (mountains) fact and the event should reach
      // <memory>; the retired kingdom fact should not be offered. This turn does
      // not clear the cadence, so it triggers no extraction.
      prompts.clear();
      await sendChatPrompt(tester, 'Remind me about the dragon.');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      expect(
        prompts.any(
          (prompt) =>
              prompt.contains('<memory>') && prompt.contains('hero faced'),
        ),
        isTrue,
        reason: 'the retrieved event text should reach the prompt under <memory>',
      );
      expect(
        prompts.any(
          (prompt) =>
              prompt.contains('<memory>') && prompt.contains('mountains'),
        ),
        isTrue,
        reason: 'the current fact should reach the prompt under <memory>',
      );
      expect(
        prompts.every(
          (prompt) => !prompt.contains('<supplemental_data_context>'),
        ),
        isTrue,
        reason: 'memory must not leak into the assistant data-context section',
      );

      // Phase 3 — delete the message the mountains fact was drawn from. From
      // here extraction commits no fact (so the re-extraction after reconcile
      // cannot re-supersede), and reconcile should drop the mountains fact and
      // revive the kingdom fact it had retired.
      setExtraction();
      final beforeDelete = (await readGraph())!;
      final mountainsFact = _factContaining(beforeDelete, 'mountains')!;
      final supersedingMessageId =
          (mountainsFact['message_ids'] as List).first as String;
      final target = controller.messages.firstWhere(
        (message) => message.id == supersedingMessageId,
      );
      await controller.deleteMessage(target);
      await tester.pumpAndSettle();

      await doTurn('Carry on.');

      final revived = await _awaitGraphWhere(tester, readGraph, (graph) {
        final old = _factContaining(graph, 'kingdom');
        return old != null &&
            old['superseded_at'] == null &&
            _factContaining(graph, 'mountains') == null;
      });
      expect(
        _factContaining(revived, 'kingdom')!['superseded_at'],
        isNull,
        reason: 'deleting the superseding message revives the original fact',
      );
      expect(
        _factContaining(revived, 'mountains'),
        isNull,
        reason: 'the fact drawn from the deleted message is gone',
      );
    },
  );
}

/// The first fact in [graph] whose text contains [needle], or null.
Map<String, dynamic>? _factContaining(Map<String, dynamic> graph, String needle) {
  for (final entry in graph['facts'] as List) {
    final fact = entry as Map<String, dynamic>;
    if ((fact['text'] as String).contains(needle)) return fact;
  }
  return null;
}

/// Polls [readGraph] until [predicate] holds, returning the matching graph.
Future<Map<String, dynamic>> _awaitGraphWhere(
  WidgetTester tester,
  Future<Map<String, dynamic>?> Function() readGraph,
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

/// Scripted stand-in for [LlmRunner]: a constant reply for [generate] and a
/// caller-supplied extraction map for [completeStructured]. Records the prompts
/// handed to [generate] so the test can assert what reached the model.
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
