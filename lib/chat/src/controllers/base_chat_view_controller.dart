import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
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
  bool get isGenerating;

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
  Future<void> improveInput() async {}

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
