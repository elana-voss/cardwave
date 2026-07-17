import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

/// Rename a chat from the All Chats list. Uses the bubble row's
/// trailing more_vert popup → Rename → AlertDialog with TextField.
/// Asserts the new name persists by closing and re-opening the
/// drawer, then finding the new name in the list.
///
/// Underlying use case: a renamed chat keeps its new name across
/// drawer dismiss/reopen — write hits disk and the index reflects it.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — rename chat persists across drawer reopen',
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

      // ─── Drawer → All Chats ─────────────────────────────────────────
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-all-chats')));
      await tester.pumpAndSettle();

      // ─── Open ChatListItem popup → Rename ──────────────────────────
      // First entry's trailing PopupMenuButton (Icons.more_vert) — scope
      // to the AllChatsDrawerList so we don't hit a chat-bubble more_vert
      // sitting in the underlying chat view (still mounted under the
      // drawer overlay).
      final drawerMoreVerts = find.descendant(
        of: find.byType(AllChatsDrawerList),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(drawerMoreVerts.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-history-rename')));
      await tester.pumpAndSettle();

      expect(
        find.text('Rename Chat'),
        findsOneWidget,
        reason: 'rename dialog title should appear',
      );
      const newName = 'Test Renamed Chat';
      await tester.enterText(find.byType(TextField).last, newName);
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(find.byKey(const Key('dialog-save')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The list item's title should now be the new name.
      expect(
        find.text(newName),
        findsOneWidget,
        reason: 'list should reflect the rename immediately',
      );

      // ─── Close and re-open drawer → All Chats ───────────────────────
      // Close the drawer to drop the All Chats route, then reopen — this
      // forces a fresh AllChatsDrawerList read of the index from disk.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-all-chats')));
      await tester.pumpAndSettle();

      // Underlying use case: the renamed chat persisted to the index on
      // disk — the freshly-loaded list still shows the new name.
      expect(
        find.text(newName),
        findsOneWidget,
        reason: 'renamed chat should persist across drawer reopen',
      );
    },
  );
}
