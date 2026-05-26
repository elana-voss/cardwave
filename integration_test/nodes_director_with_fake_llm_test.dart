// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:schemantic/schemantic.dart';

import 'app_test_helpers.dart';

/// Drives the NODES engine end-to-end through a chat reply, with NO
/// real LLM contact. Verifies:
///
///   1. The card's `cardwave_nodes` extension is read on first send —
///      authored scene, goal, and emotion baseline land in
///      `SessionState`.
///   2. The actor LLM call's system message includes the `<situation>`
///      block assembled by `PromptAssembler.assembleDynamicSections`
///      (and that block contains the seeded scene/goal/state).
///   3. After the reply, the director call runs (the fake runner's
///      `completeStructured` is invoked).
///   4. The director's scripted output (one emotion delta + one event
///      log entry) is applied to state and persisted to disk at
///      `<chatDir>/<sessionId>/nodes/state.json`.
///
/// No `GROK_API_KEY` is required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'NODES end-to-end: extension seeds, actor sees <situation>, director writes back',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugRunnerFactory = null;
      });

      await wipeAppData();

      // Settings: one provider with one fake model wired into both
      // the chat domain (actor) AND the system domain (director).
      // structuredOutput=true is load-bearing — `completeStructured`
      // gates on it.
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
                capabilities: const LlmCapabilities(
                  toolCalling: true,
                  structuredOutput: true,
                ),
                presets: [
                  LlmPresetConfig(id: presetId, name: 'fake'),
                ],
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
      final settingsFile = File(
        '${dir.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
      );
      await settingsFile.writeAsString(jsonEncode(settings.toJson()));

      await seedTestCharacter();

      // The director's scripted reply: small joy delta on the test
      // character + one event-log line. Keyed by the character's
      // appCardId (filled in after the card loads, below).
      late String testCharId;
      final fake = _FakeNodesRunner(
        actorReply: 'Hello there.',
        directorOutputFactory: () => {
          'emotion_deltas': {
            testCharId: {'joy': 0.05},
          },
          'event_log_append': [
            {'text': 'first hello', 'significance': 0.3},
          ],
        },
      );
      debugRunnerFactory = ({
        required provider,
        required model,
        required preset,
        paramOverrides,
      }) => fake;

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Find the seeded test character (the one that isn't Cass) and
      // inject a `cardwave_nodes` extension onto its in-memory card.
      // CharacterService loaded the PNG without it; we add it before
      // the first send so `NodesService._ensureOpen` picks it up.
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = characterService.characterFiles.firstWhere(
        (f) => f.card.displayName != kCassName,
        orElse: () => throw StateError(
          'seedTestCharacter should have placed a 2nd card',
        ),
      );
      testCharId = testCharFile.appCardId;
      testCharFile.card.extensions['cardwave_nodes'] = <String, dynamic>{
        'authored_nodes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'greeting',
            'origin': 'authored',
            'type': 'characterBehavior',
            'trigger_prob': 1.0,
            'delay': 0,
            'cooldown': 0,
            'sticky': 0,
            'alive': -1,
            'scope': 'session',
            'predicate': 'true',
            'narrative_payload': 'She nods in greeting.',
          },
        ],
        'emotion_baseline': <String, dynamic>{'trust': 0.4},
        'initial_goal': 'meet the stranger',
        'initial_scene': <String, dynamic>{
          'location': 'tavern',
          'time_of_day': 'evening',
        },
      };

      // Open the test character's chat.
      await tester.tap(findCharacterTile(testCharFile.card.displayName));
      await tester.pumpAndSettle();

      await sendChatPrompt(tester, 'Hello.');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 30));

      // 1. Actor LLM saw a <situation> block with the seeded scene/goal.
      final systemMessages = fake.lastGenerateMessages.where(
        (m) => m.role == LlmRunnerMessageRoleEnum.system,
      );
      expect(systemMessages, isNotEmpty,
          reason: 'actor call should include at least one system message');
      final systemText = systemMessages.map((m) => m.content).join('\n');
      expect(systemText, contains('<situation>'));
      expect(systemText, contains('## Scene'));
      expect(systemText, contains('tavern'));
      expect(systemText, contains('evening'));
      expect(systemText, contains('meet the stranger'));

      // 2. Wait for the post-reply director call to land. recordTurn is
      // fire-and-forget, so pump the test clock until the fake reports
      // the structured call ran.
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        if (fake.completeStructuredCalls >= 1) break;
      }
      expect(fake.completeStructuredCalls, greaterThanOrEqualTo(1),
          reason: 'director should have been called via completeStructured');

      // 3. The director's writeback lands on the in-memory state — the
      // same state `NodesService._persistCurrent` then writes to disk
      // via `AppStorage` (which roots cards-domain paths under the docs
      // dir, so a raw `File(path)` check would point at the wrong
      // place). Reading through the Provider-shared service avoids the
      // path resolution and exercises the same code path.
      final nodesService = tester
          .element(find.byType(MaterialApp))
          .read<CardwaveNodesModule>()
          .nodesService;
      final state = nodesService.state;
      expect(state, isNotNull,
          reason: 'state should be open after a turn ran');
      expect(state!.characters.containsKey(testCharId), isTrue,
          reason: 'fresh-chat seed should have created the character entry');
      final joy = state.characters[testCharId]!.emotion[EmotionEnum.joy]!;
      expect(joy.value, greaterThan(0),
          reason: 'joy delta from director should have landed');
      expect(state.eventLog, isNotEmpty,
          reason: 'director event-log append should be on the state');
      expect(state.eventLog.first.text, 'first hello');

      // 4. The router in main.dart forwards FiringLogEvent records into
      // LoggingService. The seeded `greeting` node has predicate `true`
      // and triggerProb 1.0, so it fires every turn — the in-app log
      // viewer should now show a `[NODES] turn N: fired "greeting"`
      // entry. Catches a future regression where the router branch
      // gets deleted or the message format drifts.
      final logs = LoggingService().logsNotifier.value;
      expect(
        logs.any((e) =>
            e.message.contains('[NODES]') &&
            e.message.contains('fired "greeting"')),
        isTrue,
        reason:
            'router should have forwarded the NodeFiredEvent into the in-app '
            'log; seen messages: '
            '${logs.where((e) => e.message.contains("[NODES]")).map((e) => e.message).toList()}',
      );
    },
  );
}

/// Scripted stand-in for [LlmRunner] covering BOTH the actor path
/// (`generate`) and the director path (`completeStructured`). The
/// dummy `Model` + `Genkit` satisfy the parent constructor; both
/// methods short-circuit before any real genkit machinery runs.
class _FakeNodesRunner extends LlmRunner {
  _FakeNodesRunner({
    required this.actorReply,
    required this.directorOutputFactory,
  }) : super(
          model: gk.Model<Object?>(
            name: 'fake-model',
            fn: (_, __) => throw UnimplementedError(
              'fake runner: model.fn must not be called',
            ),
          ),
          genkit: gk.Genkit(isDevEnv: false),
        );

  final String actorReply;
  // Lazy so the director output can close over data computed AFTER
  // the runner is constructed (the test character's appCardId is only
  // known once CharacterService finishes loading).
  final Map<String, dynamic> Function() directorOutputFactory;

  List<LlmRunnerMessage> lastGenerateMessages = const [];
  int completeStructuredCalls = 0;

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    lastGenerateMessages = messages;
    return LlmRunnerResult(
      text: actorReply,
      visibleLen: actorReply.length,
      reasoning: '',
      finishReason: 'stop',
      modelName: 'fake-model',
      configType: 'null',
      configRepr: 'null',
      toolCalls: const [],
    );
  }

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async {
    completeStructuredCalls += 1;
    return directorOutputFactory();
  }
}
