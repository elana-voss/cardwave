import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// fetch_website round-trip. Seeds Grok, opens the Cass chat, enables
/// "Allow Web Fetch" in the chat drawer, sends a prompt that names the
/// tool and a stable URL (example.com — IANA reserves it for examples
/// and the body is tiny). Asserts:
///
/// 1. The session's `webToolFetchAllowed` flips on after the drawer toggle.
/// 2. The assistant's last swipe carries a `fetch_website` ChatToolCallRecord
///    with `success: true`, `resultData` containing both the
///    `BEGIN_FETCHED_CONTENT` delimiter and the page's "Example Domain"
///    title — proves the manual loop ran one tool round, the HTTP GET
///    succeeded, and HTML→Markdown conversion fired.
/// 3. The final reply text references the fetched page (via "example",
///    "domain", or "illustrative") — proves the tool result reached the
///    model on iteration 2 and was incorporated into the user-visible
///    reply, not just attached as silent metadata.
///
/// Cost: 2 chat turns on Grok (iter 1 emits the tool call, iter 2
/// summarises the fetched page). No image / video generation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fetch_website tool — model fetches URL, page content reaches reply',
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

      // 'Web' is the bottom-most ExpansionTile in the drawer (order:
      // Chat → Chat Theme → Speech → Video → Image → Web), below the
      // fold on a phone viewport.
      final webHeader = find.text('Web');
      await tester.dragUntilVisible(
        webHeader,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(webHeader);
      await tester.pumpAndSettle();

      // Tap "Allow Web Fetch" — SwitchListTile's onChanged fires when
      // you tap the title row, no need to find the inner Switch widget.
      final allowFetchTile = find.text('Allow Web Fetch');
      await tester.dragUntilVisible(
        allowFetchTile,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(allowFetchTile);
      await tester.pumpAndSettle();

      // Close the drawer (Android system-back) so the chat input is
      // hit-testable again — the drawer overlay would intercept the
      // send button tap otherwise.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Sanity: the session reflects the toggle.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final session = controller.chatSession;
      expect(session, isNotNull);
      expect(
        session!.configMedia?.webToolFetchAllowed,
        isTrue,
        reason: 'drawer toggle should set webToolFetchAllowed on session',
      );

      // Naming the tool explicitly + a trivial URL drives Grok to
      // emit one fetch_website call on iter 1. The "two sentences"
      // bound keeps iter 2 short.
      const userPrompt =
          'Please use the fetch_website tool to fetch https://example.com '
          'and then tell me in two sentences what that page is for.';
      await tester.enterText(
        find.byKey(const Key('chat-input')).first,
        userPrompt,
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Manual tool loop: iter 1 LLM call + HTTP fetch + iter 2 LLM
      // call. 90s covers both round-trips plus the fetch with
      // headroom for slow Grok variants.
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
      final fetchRecords = activeSwipe.toolCalls
          .where((r) => r.toolName == FetchWebsiteTool.toolName)
          .toList();
      expect(
        fetchRecords,
        isNotEmpty,
        reason:
            'model should have called fetch_website at least once; '
            'all recorded tool calls: '
            '${activeSwipe.toolCalls.map((r) => r.toolName).toList()}',
      );

      final fetch = fetchRecords.first;
      expect(
        fetch.success,
        isTrue,
        reason:
            'fetch_website call should have succeeded; '
            'errorMessage=${fetch.errorMessage}',
      );
      expect(
        fetch.resultData,
        isNotNull,
        reason: 'successful fetch should carry resultData',
      );
      expect(
        fetch.resultData,
        contains(FetchWebsiteTool.resultDelimiterBegin),
        reason: 'fetched payload should be wrapped in delimiters',
      );
      expect(
        fetch.resultData,
        contains('Example Domain'),
        reason:
            'example.com body should include the page title — '
            'proves HTML→Markdown conversion preserved page text',
      );

      // Reply text references the fetched page. Model may phrase it
      // many ways — we accept any of "example" / "domain" /
      // "illustrative" since they all appear in example.com's prose
      // ("for use in illustrative examples in documents").
      expect(
        lastMessage.content.isNotEmpty,
        isTrue,
        reason: 'reply text must be non-empty',
      );
      expect(
        lastMessage.content.toLowerCase(),
        anyOf(
          contains('example'),
          contains('domain'),
          contains('illustrative'),
        ),
        reason:
            'reply should reference fetched content '
            '(got: "${lastMessage.content}")',
      );

      // Hold the final UI state for a few seconds of real wall time
      // so a watching operator can visually confirm the rendered
      // bubble before the test framework tears down the app.
      // `pumpAndSettle` only advances Flutter's frame clock; an actual
      // delay needs `Future.delayed` plus a final `pump` to flush.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
    },
  );
}
