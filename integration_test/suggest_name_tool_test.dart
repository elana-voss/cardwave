import 'dart:convert';

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave_names/cardwave_names.dart';
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

      await bootCassChat(tester);
      await enableToolViaDrawer(tester, toggleLabel: 'Suggest NPC Names');

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
      await sendChatPrompt(tester, userPrompt);

      // Manual tool loop: iter 1 emits the call, picker runs locally,
      // iter 2 narrates. 90s covers both LLM round-trips with headroom
      // for slow Grok variants.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 90));

      final pick = assertToolFiredOnLastMessage(
        controller,
        toolName: SuggestNameTool.toolName,
      );
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
      final lastMessage = controller.messages.last;
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
