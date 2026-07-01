// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Drives the assistant-chat card-edit flow end-to-end without contacting
/// any real LLM provider. The trick is `LlmPureHelpers.debugRunnerFactory`,
/// which lets the test inject a scripted [LlmRunner] in place of the real
/// provider-backed one. The test verifies:
///
/// - The fake runner is invoked through the assistant chat path.
/// - With edit approval turned off for this test, the proposed scalar set
///   auto-applies with no dialog.
/// - The mutation lands on the character file held by `CharacterService`.
///
/// No `GROK_API_KEY` is required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'assistant chat card edit — fake runner, approval dialog, apply',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      // Wide-screen viewport so `WorkspaceController.effectiveMode`
      // returns `splitEditorAssistant` when both the editor base and the
      // editor side panel are on. Mobile widths collapse to single-pane
      // editor.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugRunnerFactory = null;
      });

      await wipeAppData();

      // Pre-write a fully-formed settings.json so the chat path can
      // resolve a preset without hitting any network. The provider /
      // model / preset details don't matter — `debugRunnerFactory`
      // short-circuits `createRunner` before any provider code runs.
      // The model must still advertise `toolCalling: true` so the
      // execution service advertises the card-edit tools to the runner.
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
        },
        // Suppress the daily startup model refresh; otherwise the
        // provider's real model list overwrites our fake model and the
        // preset id no longer resolves.
        refreshPolicy: ModelRefreshPolicyEnum.never,
        // Keep edits auto-applying for this end-to-end check so it verifies
        // the write reaches CharacterService without driving the approval
        // dialog (the dialog flow is covered by the widget test).
        assistantCardEditRequireApprovalForEdits: false,
      );
      final settingsFile = File(
        '${dir.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
      );
      await settingsFile.writeAsString(jsonEncode(settings.toJson()));

      await seedTestCharacter();

      const newDescription = 'A retired space pirate.';
      final scripted = <LlmRunnerResult>[
        const LlmRunnerResult(
          text: '',
          visibleLen: 0,
          reasoning: '',
          finishReason: 'stream',
          modelName: modelId,
          configType: 'null',
          configRepr: 'null',
          toolCalls: [
            ToolCall(
              name: 'card_field_set',
              arguments: {
                'field': 'description',
                'content': newDescription,
              },
            ),
          ],
        ),
        const LlmRunnerResult(
          text: 'Done.',
          visibleLen: 5,
          reasoning: '',
          finishReason: 'stream',
          modelName: modelId,
          configType: 'null',
          configRepr: 'null',
          toolCalls: [],
        ),
      ];
      debugRunnerFactory = ({
        required provider,
        required model,
        required preset,
        paramOverrides,
      }) => _FakeLlmRunner(scripted);

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Edits auto-apply by default; the dialog flow is covered by
      // test/character/dialog_card_edit_approval_test.dart.

      // The bundled test card's displayName comes from the embedded PNG.
      // Filter Cass out — only the seed card remains.
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = (await characterService.loadAll()).firstWhere(
        (f) => f.card.displayName != kCassName,
        orElse: () =>
            throw StateError('seedTestCharacter should have placed a 2nd card'),
      );
      final testCharName = testCharFile.card.displayName;
      final testTile = findCharacterTile(testCharName);
      expect(testTile, findsOneWidget);
      await tester.tap(testTile);
      await tester.pumpAndSettle();

      // WorkspaceController is provided inside WorkspacePage's MultiProvider,
      // so the lookup must start from a descendant. AppScaffold is the
      // first widget below that MultiProvider.
      final workspaceCtl = tester
          .element(find.byType(AppScaffold))
          .read<WorkspaceController>();
      workspaceCtl.setBase(WorkspaceBaseEnum.editor);
      workspaceCtl.toggleEditorSidePanel();
      await tester.pumpAndSettle();

      await sendChatPrompt(tester, 'Update the description.');
      await awaitChatIdle(tester, timeout: const Duration(seconds: 30));

      // The assistant chat binds to Cass (bundled assistant) regardless of
      // which card we entered the workspace on, so verify the new
      // description landed on any character file rather than a specific one.
      final files = await characterService.loadAll();
      expect(
        files.any((c) => c.card.description == newDescription),
        isTrue,
        reason:
            'no character file carries the scripted description; '
            'descriptions seen: '
            '${files.map((c) => '${c.card.name}=${c.card.description.length}c').toList()}',
      );
    },
  );
}

/// Scripted stand-in for [LlmRunner]. Overrides [generate] so the real
/// genkit machinery is never reached. The dummy `Model` + `Genkit`
/// satisfy the parent constructor; both are inert because `generate`
/// short-circuits before the parent body runs.
class _FakeLlmRunner extends LlmRunner {
  _FakeLlmRunner(List<LlmRunnerResult> scripted)
      : _queue = List<LlmRunnerResult>.from(scripted),
        super(
          model: gk.Model<Object?>(
            name: 'fake-model',
            fn: (_, __) => throw UnimplementedError(
              'fake runner: model.fn must not be called',
            ),
          ),
          genkit: gk.Genkit(isDevEnv: false),
        );

  final List<LlmRunnerResult> _queue;

  @override
  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<gk.Tool<Object?, Object?>>? tools,
  }) async {
    if (_queue.isEmpty) {
      throw StateError(
        'fake runner exhausted: generate() called more times than scripted',
      );
    }
    return _queue.removeAt(0);
  }
}
