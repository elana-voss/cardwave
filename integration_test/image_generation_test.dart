import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Image generation smoke test. Uses the magic-wand → "Generate image" →
/// Free prompt path so the test doesn't depend on a pre-existing chat
/// message. One image API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Image generation smoke — free prompt',
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

      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the magic wand. Top-level popup menu appears.
      await tester.tap(find.byKey(const Key('chat-media-menu')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('media-menu-image')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('media-image-mode-free')));
      await tester.pumpAndSettle();

      // Dialog pops up asking for subject. Type and confirm.
      await tester.enterText(find.byType(TextField).last, 'a red apple');
      await tester.pump();
      await dismissKeyboard(tester);
      final confirmFinder =
          find.byKey(const Key('media-generate-confirm')).evaluate().isNotEmpty
          ? find.byKey(const Key('media-generate-confirm'))
          : find.text('OK');
      expect(
        confirmFinder,
        findsOneWidget,
        reason: 'free-prompt dialog should have a confirm button',
      );
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      // Wait for generated image to attach to a message.
      await _awaitImageAttached(tester, timeout: const Duration(seconds: 60));
    },
  );
}

Future<void> _awaitImageAttached(
  WidgetTester tester, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    final controller = tester
        .element(find.byType(ChatView))
        .read<BaseChatViewController>();
    final hasImage = controller.messages.any(
      (m) => m.swipes.any((s) => s.attachedImages.isNotEmpty),
    );
    if (hasImage) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('No image attached to any message within ${timeout.inSeconds}s');
}
