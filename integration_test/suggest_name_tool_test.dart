import 'dart:convert';

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_names/cardwave_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// suggest_name round-trip. Seeds Grok, opens the Cass chat, enables
/// "Suggest NPC Names" in the chat drawer, sends a prompt naming the
/// tool and asking the AI to introduce one NPC. Asserts:
///
/// 1. The session's `nameToolSuggestAllowed` flips on after the drawer toggle.
/// 2. The assistant's last swipe carries a `suggest_name` ChatToolCallRecord
///    with `success: true` and `resultData` parseable as a flat NamePick JSON
///    payload with `first_name` as a non-empty string.
/// 3. The reply text contains that exact first name (case-insensitive) —
///    proves the tool result reached the model on iteration 2 and was
///    incorporated into the user-visible reply.
///
/// Cost: 2 chat turns on Grok — turn 1 emits the tool call, the picker
/// runs locally and returns synchronously, turn 2 narrates with the
/// chosen name. No image / video generation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'suggest_name tool — model picks an NPC name and uses it in the reply',
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

      // Enter Cass chat.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Open the end-drawer.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      // 'Names' is the bottom-most section. DrawerSectionHeader is a static
      // label (no tap-to-expand), so we drag the toggle into view and tap
      // it directly — no separate header tap is needed.
      final allowTile = find.text('Suggest NPC Names');
      await tester.dragUntilVisible(
        allowTile,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(allowTile);
      await tester.pumpAndSettle();

      // Close the drawer (Android system-back) so the chat input is
      // hit-testable again — the drawer overlay would intercept the send
      // button tap otherwise.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Sanity: the session reflects the toggle.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final session = controller.chatSession;
      expect(session, isNotNull);
      expect(
        session!.configMedia?.nameToolSuggestAllowed,
        isTrue,
        reason: 'drawer toggle should set nameToolSuggestAllowed on session',
      );

      // Naming the tool explicitly plus a 2-sentence cap keeps the test
      // deterministic and short.
      const userPrompt =
          'Use the suggest_name tool, then introduce one new NPC walking '
          'into the scene right now. Keep the introduction to two sentences '
          'and use the exact name the tool returns.';
      await tester.enterText(
        find.byKey(const Key('chat-input')).first,
        userPrompt,
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Manual tool loop: iter 1 emits the call, picker runs locally,
      // iter 2 narrates. 90s covers both LLM round-trips with headroom
      // for slow Grok variants.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 90));

      // Last message: assistant reply with the persisted tool-call
      // record on its active swipe.
      final lastMessage = controller.messages.last;
      expect(
        lastMessage.role == ChatRoleEnum.assistant ||
            lastMessage.role == ChatRoleEnum.character,
        isTrue,
        reason:
            'last message should be the AI reply, '
            'got role=${lastMessage.role}',
      );
      final activeSwipe = lastMessage.swipes[lastMessage.swipeIndex];
      final pickRecords = activeSwipe.toolCalls
          .where((r) => r.toolName == SuggestNameTool.toolName)
          .toList();
      expect(
        pickRecords,
        isNotEmpty,
        reason:
            'model should have called suggest_name at least once; '
            'all recorded tool calls: '
            '${activeSwipe.toolCalls.map((r) => r.toolName).toList()}',
      );

      final pick = pickRecords.first;
      expect(
        pick.success,
        isTrue,
        reason:
            'suggest_name call should have succeeded; '
            'errorMessage=${pick.errorMessage}',
      );
      expect(
        pick.resultData,
        isNotNull,
        reason: 'successful pick should carry resultData',
      );

      // Parse the NamePick payload and pull out the chosen first name.
      // The tool returns a flat shape: `{first_name, last_name, gender, ...}`
      // — not nested under `first_name_entry` as I'd initially guessed.
      final json = jsonDecode(pick.resultData!) as Map<String, dynamic>;
      final firstName = json['first_name'] as String;
      expect(firstName, isNotEmpty);

      // The picker is deterministic per filter slice; if the LLM used the
      // tool result, the chosen name must appear in the reply.
      expect(
        lastMessage.content.toLowerCase(),
        contains(firstName.toLowerCase()),
        reason:
            'reply should reference the tool-returned first name '
            '($firstName); got: "${lastMessage.content}"',
      );

      // Hold the final UI state for a few seconds of real wall time so a
      // watching operator can visually confirm the rendered bubble before
      // the test framework tears down the app.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
    },
  );
}
