import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Lorebook keyword injection: add a lorebook entry to Cass's card with
/// a unique keyword and a content directive instructing the model to
/// echo a unique sentinel phrase when that keyword appears. Then send
/// a chat message containing the keyword and assert the assistant's
/// reply includes the sentinel.
///
/// This is end-to-end proof of the entire lorebook pipeline:
///   editor entry creation → autosave → LorebookService.evaluate →
///   ChatPromptBuilder._buildLorebook → world_info injection into
///   the outgoing prompt → LLM consumption.
///
/// Underlying use case: a user can author a lorebook so that when
/// specific keywords appear in chat, the model gets extra context. If
/// the sentinel reaches the reply, the entry was injected; if it
/// doesn't, something in the pipeline broke.
///
/// Risk: the model may not comply with the directive even when injected
/// (false negative). Mitigated by an explicit "MUST include the exact
/// phrase" wording and by using a sentinel so unusual the model has no
/// reason to use it spontaneously.
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Lorebook — keyword in user message injects entry into prompt',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Sentinels: the keyword the entry triggers on, and the phrase the
      // entry tells the model to emit. Both unusual enough that the
      // model won't produce them spontaneously without the lorebook
      // injection.
      const triggerKeyword = 'ZARQUON';
      const echoSentinel = 'GLORG_BLERFTH_42';

      await tapEditOnCharacterTile(tester, kCassName);

      // Switch to the Lorebook tab.
      // GOTCHA: on a tablet-sized viewport the editor renders BOTH a Tab
      // and a NavigationRail item with text 'Lorebook', so this finder
      // would become ambiguous. Phone-sized emulator shows tabs only —
      // works as-is. If this fails with findsTwoWidgets on a wider device,
      // scope to find.byType(Tab).
      await tester.tap(find.text('Lorebook'));
      await tester.pumpAndSettle();

      // Add a new entry, then tap its tile (default comment 'New Entry')
      // to open the entry editor page.
      await tester.tap(find.byKey(const Key('lorebook-add-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Entry'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Fill Primary Keywords + Content. Both fields are TextFieldCard
      // wrappers; the rendered label can include a token-count suffix, so
      // match on the widget's `label` property instead of the text.
      final keysCard = find.byWidgetPredicate(
        (w) => w is TextFieldCard && w.label == 'Primary Keywords',
      );
      await tester.enterText(
        find.descendant(of: keysCard, matching: find.byType(TextFormField)),
        triggerKeyword,
      );
      await tester.pump();

      final contentCard = find.byWidgetPredicate(
        (w) => w is TextFieldCard && w.label == 'Content',
      );
      const injectedDirective =
          'IMPORTANT system instruction: When the user mentions $triggerKeyword, '
          'you MUST include the exact phrase $echoSentinel in your reply, '
          'verbatim. This phrase is the only acceptable signal that you '
          'received this instruction.';
      await tester.enterText(
        find.descendant(of: contentCard, matching: find.byType(TextFormField)),
        injectedDirective,
      );
      await tester.pump();
      await dismissKeyboard(tester);

      // Pop the entry editor → workspace → grid. PopScope on the workspace
      // flushes the pending autosave to PNG; no need to pre-wait the
      // 1s debounce.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byType(CharacterGridItem),
        findsAtLeastNWidgets(1),
        reason: 'should be back on the grid after popping the editor',
      );

      // Open Cass's chat (default tap, NOT the edit button).
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ─── Send a message containing the trigger keyword ───────────────
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(
        input,
        'Tell me one short fact about $triggerKeyword.',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Wait for the assistant reply to land.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 90));

      // ─── Underlying use case: sentinel echoed in the reply ───────────
      // If the lorebook entry was injected into the prompt, the model
      // received the directive and (per its instruction) included the
      // sentinel. If injection failed, the model has no reason to use a
      // nonsense word like GLORG_BLERFTH_42.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final lastReply = controller.messages.lastWhere(
        (m) =>
            m.role == ChatRoleEnum.character ||
            m.role == ChatRoleEnum.assistant,
      );
      expect(
        lastReply.content,
        contains(echoSentinel),
        reason:
            'assistant reply should contain $echoSentinel — proves the '
            'lorebook entry was injected into the prompt and the model '
            'received the directive. Reply was: "${lastReply.content}"',
      );
    },
  );
}
