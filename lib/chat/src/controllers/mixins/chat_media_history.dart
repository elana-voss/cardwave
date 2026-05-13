import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Picks the character's display name for placeholder substitution
/// (`{{char}}`) — nickname when set, otherwise card name.
String effectiveCharName(CharacterFile character) {
  final nickname = character.card.nickname;
  return (nickname != null && nickname.isNotEmpty)
      ? nickname
      : character.card.name;
}

/// Slices the recent message tail for the image / video prompt builders.
/// Drops in-flight placeholders (the just-added "Generating image…" /
/// "Generating video…" bubble) and finalised media messages
/// (`*(sent an image/video: …)*` markers) so a repeated `lastMessage`
/// generation keeps targeting the original conversational reply instead
/// of drifting onto its own prior output.
///
/// Returns an empty list when [usesChatHistory] is false (the caller
/// reads `mode.usesChatHistory` from the relevant generation enum).
List<LlmHistorySnippet> extractRecentMediaHistory({
  required ChatSession session,
  required String charName,
  required String userName,
  required bool usesChatHistory,
  required int maxMessages,
}) {
  if (!usesChatHistory) return const [];
  final recent = session.messages
      .where(
        (m) =>
            m.waitingFor == BubbleWaitingForEnum.complete &&
            !m.hasMediaAttachments &&
            m.content.trim().isNotEmpty,
      )
      .toList();
  final slice = recent.length > maxMessages
      ? recent.sublist(recent.length - maxMessages)
      : recent;
  return [
    for (final m in slice)
      (
        label: m.role == ChatRoleEnum.user ? userName : charName,
        content: m.content,
      ),
  ];
}
