import 'dart:math';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';

class GroupPromptService {
  final Random _random = Random();

  /// Returns a copy of [history] where every character/assistant message
  /// has its content prefixed with "{SpeakerName}: " so the LLM can tell
  /// who said what when multiple characters share the assistant role.
  /// User and system messages are passed through unchanged.
  List<ChatMessage> buildPrefixedHistory({
    required List<ChatMessage> history,
    required String Function(String? characterId) resolveSpeakerName,
  }) {
    return history.map((message) {
      if (message.role != ChatRoleEnum.character &&
          message.role != ChatRoleEnum.assistant) {
        return message;
      }
      final speakerName = resolveSpeakerName(message.characterId);
      return ChatMessage(
        role: message.role,
        swipes: [ChatSwipe(content: '$speakerName: ${message.content}')],
        timestamp: message.timestamp,
        characterId: message.characterId,
      );
    }).toList();
  }

  /// Picks and returns a macro-expanded greeting for [character].
  /// Prefers group-only greetings; falls back to standard greetings.
  String getInitialGroupGreeting(
    CharacterCardV3 character, {
    required String userName,
  }) {
    final String raw;
    if (character.groupOnlyGreetings.isNotEmpty) {
      final index = _random.nextInt(character.groupOnlyGreetings.length);
      raw = character.groupOnlyGreetings[index];
    } else {
      final standardGreetings = [
        character.firstMes,
        ...character.alternateGreetings,
      ];
      raw = standardGreetings[_random.nextInt(standardGreetings.length)];
    }

    return UtilsPrompt.replacePlaceholders(
      raw,
      charName: character.name,
      userName: userName,
    );
  }
}
