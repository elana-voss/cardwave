import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Edit a message via the bubble's more_vert popup → Edit. Opens an
/// AppDialog with a TextFieldAutotrim pre-populated with the existing
/// content (message_dialog_helper.dart:9). Saving routes through the
/// bubble's `onEdit` callback to controller.editMessage and the
/// message's content updates in place.
///
/// Targets the AI reply (last message); same dialog and wiring as
/// editing a user message but unambiguous to select.
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — edit AI reply via bubble actions menu',
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

      await tester.tap(findCharacterTile(kSeedCharacterName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      final originalContent = controller.messages.last.content;
      expect(
        originalContent,
        isNotEmpty,
        reason: 'AI reply should have content before edit',
      );

      // Open more_vert on the AI reply. The chat ListView uses
      // `reverse: true` (chat_view.dart:182 inverts msgIndex), so the
      // BUILD order of bubbles is bottom-up — `.first` is the most recent
      // message (the reply), `.last` is the greeting.
      await tester.tap(find.byKey(const Key('msg-menu-trigger')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('msg-menu-edit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Edit Message'),
        findsOneWidget,
        reason: 'edit dialog title should be present',
      );

      // Edit dialog autofocuses the TextField. enterText replaces the
      // entire content, so no manual clear needed.
      const editedText = 'edited reply text';
      await tester.enterText(find.byType(TextField).last, editedText);
      await tester.pump();
      await dismissKeyboard(tester);

      // Save commits the edit; Cancel discards it. The dialog uses
      // FilledButton 'Save' / TextButton 'Cancel'.
      await tester.tap(find.byKey(const Key('dialog-save')));
      await tester.pumpAndSettle();

      expect(
        controller.messages.last.content,
        editedText,
        reason: 'edited content should land on the message',
      );
      expect(
        controller.messages.last.content,
        isNot(originalContent),
        reason: 'sanity — content actually changed',
      );
    },
  );
}
