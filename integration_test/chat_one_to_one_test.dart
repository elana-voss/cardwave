import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// 1:1 chat smoke test. Seeds a Grok provider via recovery file, boots the
/// app, taps the seed card, types a short message, taps send,
/// waits for a reply. Asserts: reply arrived, persisted in the controller's
/// message list.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat smoke — send message, receive reply',
    timeout: const Timeout(Duration(minutes: 2)),
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

      final cardFinder = findCharacterTile(kSeedCharacterName);
      expect(
        cardFinder,
        findsOneWidget,
        reason: 'grid should show at least the seed card',
      );
      await tester.tap(cardFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // TextFieldAutotrim passes its key to the inner TextFormField so
      // find.byKey returns 2 widgets; .first picks the wrapper.
      final inputFinder = find.byKey(const Key('chat-input')).first;
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Say hi in 3 words.');
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      await awaitChatIdle(tester, timeout: const Duration(seconds: 45));

      final chatContext = tester.element(find.byType(ChatView));
      final controller = chatContext.read<BaseChatViewController>();
      expect(
        controller.messages.length,
        greaterThanOrEqualTo(2),
        reason: 'expected at least user + assistant messages',
      );
      final last = controller.messages.last;
      expect(
        last.role == ChatRoleEnum.assistant ||
            last.role == ChatRoleEnum.character,
        isTrue,
        reason: 'last message should be an AI reply, got role=${last.role}',
      );
      expect(
        last.content.isNotEmpty,
        isTrue,
        reason: 'reply content should be non-empty',
      );
    },
  );
}
