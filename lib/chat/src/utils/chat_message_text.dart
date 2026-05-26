import 'package:cardwave/chat/src/models/chat_message.dart';

/// The most recent non-empty USER message in [messages], or empty
/// when none exists. Walks the list rather than taking `messages.last`
/// so reroll / swipe / continue — where the trailing message is the
/// assistant's reply being regenerated — still resolves to the
/// user's most recent question.
String latestUserText(List<ChatMessage> messages) =>
    _latestTextWhere(messages, (m) => m.role == ChatRoleEnum.user);

/// The most recent non-empty ASSISTANT or CHARACTER message in
/// [messages], or empty when none exists. The character role is
/// included because group / multi-character chats use it for the
/// non-user turns (one-on-one chats use assistant) — both count as
/// "the actor's last reply".
String latestAssistantText(List<ChatMessage> messages) =>
    _latestTextWhere(messages, (m) =>
        m.role == ChatRoleEnum.assistant || m.role == ChatRoleEnum.character);

String _latestTextWhere(
  List<ChatMessage> messages,
  bool Function(ChatMessage) matches,
) {
  String? text;
  for (final message in messages) {
    if (matches(message) && message.content.isNotEmpty) {
      text = message.content;
    }
  }
  return text ?? '';
}
