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

/// Drives story memory end-to-end against a scripted runner (no network). The
/// same fake stands in for both the chat reply (`generate`) and the memory
/// extraction (`completeStructured`), so the extractor deterministically
/// commits a scene. Verifies, in one run:
///
/// - After enough turns, an event commits to the on-disk graph file.
/// - The retrieved event reaches the next prompt under `<memory>` (and not in
///   the assistant-only `supplemental_data_context`).
/// - Deleting a covered message then taking a turn recomputes the tree — the
///   node covering the deleted message is dropped.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'story memory — commit, retrieve into <memory>, recompute on delete',
    timeout: const Timeout(Duration(minutes: 4)),
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
        // The system domain drives memory extraction; chat drives replies.
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

      // The fake extraction always commits a one-event scene ending at the
      // first numbered message of each window, with "dragon" as a keyword the
      // later query matches.
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
            'beat': 'conflict',
          },
        ],
        'scene_end_message': 1,
        'scene_summary': 'The hero confronts the dragon.',
      };
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
      final testCharFile = characterService.characterFiles.firstWhere(
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

      // Two turns clears the extraction cadence; the post-turn pass commits.
      await doTurn('Tell me what happened at the gate.');
      await doTurn('And then what did the dragon do?');

      final committed = await awaitGraphWithEvents();
      expect(
        (committed['events'] as List),
        isNotEmpty,
        reason: 'extraction should have committed at least one event',
      );
      final committedNodeIds = {
        for (final node in committed['nodes'] as List)
          (node as Map<String, dynamic>)['id'] as String,
      };
      expect(committedNodeIds, isNotEmpty, reason: 'a scene node should commit');

      // Next turn: retrieval should pull the dragon event into <memory>.
      prompts.clear();
      await sendChatPrompt(tester, 'Remind me about the dragon.');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      // 'hero faced' is the extracted event's text — it appears in no user
      // message or reply, so this fails if <memory> is empty or carries the
      // wrong event, not just when the tag is missing.
      expect(
        prompts.any(
          (prompt) =>
              prompt.contains('<memory>') && prompt.contains('hero faced'),
        ),
        isTrue,
        reason: 'the retrieved event text should reach the prompt under <memory>',
      );
      expect(
        prompts.every(
          (prompt) => !prompt.contains('<supplemental_data_context>'),
        ),
        isTrue,
        reason: 'memory must not leak into the assistant data-context section',
      );

      // Delete the oldest message (covered by the first committed scene), then
      // take a turn — reconcile must drop the node covering it.
      // ignore: qcheck/avoid_unsafe_collection_methods
      final oldest = controller.messages.first;
      final oldestId = oldest.id;
      await controller.deleteMessage(oldest);
      await tester.pumpAndSettle();

      await doTurn('Carry on.');

      final recomputed = await _awaitGraphWhere(
        tester,
        readGraph,
        (graph) => (graph['nodes'] as List).every(
          (node) => !((node as Map<String, dynamic>)['message_ids'] as List)
              .contains(oldestId),
        ),
      );
      expect(
        (recomputed['nodes'] as List).every(
          (node) => !((node as Map<String, dynamic>)['message_ids'] as List)
              .contains(oldestId),
        ),
        isTrue,
        reason: 'no committed node should still reference the deleted message',
      );
    },
  );
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
/// fixed extraction map for [completeStructured]. Records the prompts handed to
/// [generate] so the test can assert what reached the model.
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
