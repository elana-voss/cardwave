import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Empty-send guard: tapping Icons.send with an empty input must not
/// produce a new user/assistant turn or fire an API call. Catches the
/// regression class where a stray onPressed fires sendMessage without
/// trim-checking the input.
///
/// 1:1 controller's sendMessage at chat_controller.dart:240 trims first
/// and early-returns when empty (with a special branch for "regen the
/// last user turn" that doesn't apply here — the only pre-existing
/// message is the assistant greeting). So the message count must remain
/// at exactly 1 (Cass's "Hello!" greeting).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — empty send is a no-op',
    timeout: const Timeout(Duration(minutes: 1)),
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

      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final initialCount = controller.messages.length;
      expect(
        initialCount,
        greaterThanOrEqualTo(1),
        reason:
            'Cass card has a first_mes greeting — chat should boot '
            'with at least one message',
      );

      // Tap send without typing. Input is empty by default.
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        controller.messages.length,
        initialCount,
        reason: 'empty send must not append a user turn or trigger gen',
      );
      expect(
        controller.isGenerating,
        isFalse,
        reason: 'empty send must not flip the controller into generating',
      );
    },
  );
}
