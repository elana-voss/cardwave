import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// New-chat reset: the more_vert menu's "New Chat" option shows a
/// Keep-Current / Delete-Current dialog, then calls createNewChat. We
/// tap "Keep Current" so we don't exercise the delete path.
///
/// Asserts the dialog opens, the flow completes without crashing, and
/// the chat ends in a usable state (messages non-empty, not generating).
/// A stronger "chat id changed" assertion was tried but the controller
/// reference swaps out when setActiveChat fires, making a stale-ref
/// comparison unreliable — the observable UI-level guarantees above are
/// enough to catch real regressions.
///
/// No API calls — the greeting is authored in the card asset.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — New Chat creates a fresh session',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedTestCharacter();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      await tester.tap(findCharacterTile(kSeedCharacterName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final initialController = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      expect(
        initialController.messages,
        isNotEmpty,
        reason: 'the seed card should boot with a greeting',
      );
      // Capture the OLD chat id as a string so a later comparison can
      // prove a fresh session was created (not just "keep current with
      // greeting" passing trivially).
      final oldChatId = initialController.chatSession!.id;

      // Open the input-row overflow menu and pick "New Chat". Three more_vert
      // icons exist in a chat with a greeting: chat-list-item, message-bubble
      // actions row, and the input row. The input-row popup has the unique
      // tooltip 'More actions'.
      await tester.tap(find.byKey(const Key('chat-menu-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-menu-new-chat')));
      await tester.pumpAndSettle();

      // Dialog asks Keep / Delete / Cancel. Keep the old chat in history,
      // let a new one be created.
      expect(
        find.byKey(const Key('dialog-confirm')),
        findsOneWidget,
        reason: 'New Chat dialog must surface a "Keep Current" action',
      );
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Re-read the controller — setActiveChat may have swapped the
      // provided instance. Chat must be in a stable, usable state.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      expect(
        controller.messages,
        isNotEmpty,
        reason: 'new chat should carry the greeting, not be empty',
      );
      expect(
        controller.isGenerating,
        isFalse,
        reason: 'new chat must not be in generating state',
      );

      // Underlying use case: a NEW chat session was created. Without this,
      // the test could pass even if "Keep Current" silently no-op'd and
      // the same old chat stayed active. ChatSession.id is generated per
      // chat, so a different id proves the swap.
      expect(
        controller.chatSession!.id,
        isNot(oldChatId),
        reason: 'New Chat → Keep Current should swap to a fresh session id',
      );
    },
  );
}
