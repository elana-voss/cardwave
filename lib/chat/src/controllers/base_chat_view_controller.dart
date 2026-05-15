import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/generation_event.dart';
import 'package:cardwave/chat/src/services/chat_execution_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

/// Shared contract for 1:1 and group chat controllers.
///
/// ChatView depends only on this type. The parent widget decides which
/// concrete controller to provide via [Provider<BaseChatViewController>].
abstract class BaseChatViewController extends ChangeNotifier {
  // --- UI controllers ---

  TextEditingController get inputController;
  ScrollController get scrollController;
  FocusNode get focusNode;

  /// Streams tokens during generation so the UI can update incrementally.
  ValueNotifier<String> get streamingContent;

  // --- State ---

  List<ChatMessage> get messages;
  bool isGenerating = false;
  bool isImproving = false;

  /// Subclass-mutable cancellation flag for the in-flight generation /
  /// improvement stream. Null between runs; subclasses set it before
  /// starting a stream and clear it in the finally block.
  @protected
  ValueNotifier<bool>? cancelToken;

  /// Set true by the concrete `dispose()` before `super.dispose()` so any
  /// async `await` gap can detect a disposed controller and skip writes
  /// that would race against the now-disposed UI controllers.
  @protected
  bool isDisposed = false;

  /// The session this controller owns, or null for controllers that
  /// aggregate across sessions (none today — reserved for future multi-
  /// session views). The chat bubble uses this to key the TTS audio cache
  /// under the session's folder.
  ChatSession? get chatSession => null;

  /// True while a background input-processing operation is running
  /// (e.g. impersonation or input improvement in 1:1 chats).
  /// Group chats return false.
  bool get isProcessingInput => false;

  // --- Display name / character resolution ---

  /// Returns the display name shown in the chat bubble for [message].
  ///
  /// The renderer passes the whole message (not just its [ChatMessage.characterId])
  /// because the two chat flavors need different signals to resolve identity:
  ///
  /// - **1:1 chat:** the session has exactly one character. `characterId` is
  ///   redundant there and historically was left `null` on every message —
  ///   including assistant messages — which meant a `String? characterId`
  ///   interface could not distinguish "user message" from "assistant message".
  ///   With the full message in hand, the 1:1 controller decides purely on
  ///   [ChatMessage.role]: user → persona name, assistant → the session's
  ///   single character.
  ///
  /// - **Group chat:** multiple characters share one session, so every
  ///   assistant message records which character produced it in
  ///   [ChatMessage.characterId]. The group controller still needs that id
  ///   to look up the right character; the role alone is not enough.
  ///
  /// Taking the whole message keeps both controllers honest — neither has to
  /// fake a sentinel or carry a separate `isUser` flag alongside the id.
  String resolveDisplayName(ChatMessage message);

  /// Returns the [CharacterFile] for [message], or null if it cannot be
  /// resolved (e.g. user messages, or an unknown character id in a group chat).
  CharacterFile? resolveCharacterFile(ChatMessage message);

  // --- Capability flags ---
  // ChatView gates UI options behind these. Defaults to false; 1:1 controller
  // overrides the ones it supports.

  bool get supportsSwipe => false;
  bool get supportsImpersonation => false;
  bool get supportsContinue => false;
  bool get supportsImproveInput => false;

  // --- Subclass hooks read by the shared improveInput body ---

  /// The user-side display name to substitute into improvement prompts
  /// (e.g. the active persona's name in 1:1 chat, the group's user name
  /// in group chat).
  @protected
  String get userName;

  /// The character-side display name to substitute into improvement
  /// prompts. 1:1 uses the chat character; group uses the last speaker
  /// (or a generic fallback when no one has spoken yet).
  @protected
  String get charName;

  @protected
  ChatExecutionService get executionService;

  @protected
  PromptRepository get promptRepository;

  /// Short prefix prepended to error logs from this controller's
  /// generation paths, so log lines stay greppable per chat flavour.
  @protected
  String get logTag;

  // --- Core actions (both controllers implement these) ---

  Future<void> sendMessage();
  void stopGeneration();
  Future<void> deleteMessage(ChatMessage message);
  Future<void> updateMessage(ChatMessage message, String newContent);
  Future<void> regenerateLastMessage();
  Future<void> generateReply();

  // --- 1:1-only actions (no-op by default) ---

  Future<void> changeSwipe(ChatMessage message) async {}
  Future<void> continueChat() async {}
  Future<void> impersonateUser() async {}

  /// Improves the user's input by streaming an LLM rewrite back into
  /// [inputController]. Cancellation restores the original text; success
  /// applies the cleaned response (quote-strip + "Improved message:"-
  /// prefix strip). Shared body for 1:1 and group chats; subclass hooks
  /// [userName], [charName], [chatSession], [executionService],
  /// [promptRepository], and [logTag] cover the per-flavour differences.
  Future<void> improveInput() async {
    final rawInput = inputController.text.trim();
    if (rawInput.isEmpty || isDisposed || isGenerating) return;

    var prompt = promptRepository.improveUserMessagePostHistory;
    prompt = prompt.replaceAll('%CURRENT_USER_MESSAGE%', rawInput);
    prompt = prompt.replaceAll('%USER_NAME%', userName);
    prompt = prompt.replaceAll('%CHAR_NAME%', charName);

    final originalInput = rawInput;
    cancelToken = ValueNotifier(false);
    isGenerating = true;
    isImproving = true;
    inputController.clear();
    if (!isDisposed) notifyListeners();

    var bufferedText = '';
    var lastUpdateMs = 0;

    try {
      final stream = executionService.generateUtilityResponseWithHistory(
        chatSession!,
        cancelToken: cancelToken!,
        systemPrompt: promptRepository.improveUserMessagePreHistory,
        postHistoryPrompt: prompt,
      );

      await for (final event in stream) {
        if (isDisposed || cancelToken?.value == true) break;
        if (event is GenerationTokenEvent) {
          bufferedText += event.token;
          if (bufferedText.trimLeft().isEmpty) {
            bufferedText = '';
            continue;
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateMs > 250) {
            inputController.value = TextEditingValue(
              text: bufferedText,
              selection: TextSelection.collapsed(offset: bufferedText.length),
            );
            lastUpdateMs = now;
          }
        } else if (event is GenerationCompleteEvent) {
          bufferedText = event.finalContent;
        }
      }
    } on Exception catch (e, stackTrace) {
      if (cancelToken?.value != true) {
        LoggingService().error('$logTag: improveInput failed', e, stackTrace);
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
      }
    } finally {
      if (cancelToken?.value == true) {
        if (!isDisposed) {
          inputController.value = TextEditingValue(
            text: originalInput,
            selection: TextSelection.collapsed(offset: originalInput.length),
          );
        }
      } else {
        var finalContent = bufferedText.trim();
        finalContent = finalContent.replaceAll(RegExp(r'^"|"$'), '').trim();
        finalContent = finalContent
            .replaceAll(
              RegExp(
                r'^(Here is the improved message|Improved message|Improved):?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        if (!isDisposed) {
          inputController.value = TextEditingValue(
            text: finalContent,
            selection: TextSelection.collapsed(offset: finalContent.length),
          );
        }
      }
      cancelToken?.dispose();
      cancelToken = null;
      isGenerating = false;
      isImproving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  /// Storage domain-relative folder that holds this chat's persistent
  /// sidecars (session JSON, TTS audio cache, generated video files, etc.).
  ///
  /// For 1:1 chats this resolves to the character's `appCardChatsFolder`;
  /// for group chats it resolves to the group's `chats/` subfolder. The TTS
  /// service derives the per-message audio cache path from this + the
  /// session id, so honoring the owner's folder is the whole point — 1:1
  /// audio lives with the character, group audio lives with the group.
  String get chatsFolder;

  // --- Scroll helpers ---

  void jumpToBottom();
  void scrollToBottom({bool animated = true, bool force = false});

  /// Sticky: true while the user is scrolled past the stick threshold; non-forced auto-scrolls no-op.
  bool get userDetached;
}
