import 'dart:math';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/group/src/models/group_activation_strategy_enum.dart';

/// Picks the next speaker for a group chat per the active activation
/// strategy. Returns null when no candidate is available (e.g. all
/// muted, or an empty group).
///
/// NATURAL: scans the last 2 messages for a mention of a member's name
/// (whole-word, case-insensitive); falls back to talkativeness-weighted
/// random when no mention is found.
/// LIST: round-robin in the order characters were added.
/// RANDOM: talkativeness-weighted, excluding the last speaker.
CharacterFile? selectNextSpeaker({
  required List<CharacterFile> characters,
  required List<String> mutedIds,
  required GroupActivationStrategyEnum strategy,
  required String? lastSpeakerId,
  required List<ChatMessage> sessionMessages,
}) {
  final unmuted = characters
      .where((c) => !mutedIds.contains(c.appCardId))
      .toList();
  if (unmuted.isEmpty) return null;
  switch (strategy) {
    case GroupActivationStrategyEnum.natural:
      final mentioned = _findMentionedCharacter(
        unmuted,
        lastSpeakerId,
        sessionMessages,
      );
      if (mentioned != null) return mentioned;
      return _selectWeightedRandom(unmuted, lastSpeakerId);
    case GroupActivationStrategyEnum.list:
      return _selectRoundRobin(unmuted, lastSpeakerId);
    case GroupActivationStrategyEnum.random:
      return _selectWeightedRandom(unmuted, lastSpeakerId);
  }
}

/// NATURAL strategy: scans the last 2 messages (from any speaker) for a
/// candidate's name as a whole word. The last speaker is excluded so
/// characters take turns.
CharacterFile? _findMentionedCharacter(
  List<CharacterFile> candidates,
  String? lastSpeakerId,
  List<ChatMessage> sessionMessages,
) {
  if (sessionMessages.isEmpty) return null;
  final tail = sessionMessages.reversed.take(2).toList();
  for (final msg in tail) {
    for (final c in candidates) {
      if (c.appCardId == lastSpeakerId) continue;
      if (_mentionsName(msg.content, c.card.name)) return c;
    }
  }
  return null;
}

/// Whole-word, case-insensitive name match. Avoids false positives where
/// a short character name ("Al") would match inside an unrelated word
/// ("Alice", "although").
bool _mentionsName(String text, String name) {
  if (name.trim().isEmpty) return false;
  final escaped = RegExp.escape(name);
  final pattern = RegExp(
    '(?<![A-Za-z0-9_])$escaped(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  return pattern.hasMatch(text);
}

/// LIST strategy: round-robin in the order characters were added.
CharacterFile _selectRoundRobin(
  List<CharacterFile> candidates,
  String? lastSpeakerId,
) {
  // `candidates` is the non-empty unmuted-character list.
  // ignore: qcheck/avoid_unsafe_collection_methods
  if (lastSpeakerId == null) return candidates.first;
  final lastIdx = candidates.indexWhere((c) => c.appCardId == lastSpeakerId);
  // ignore: qcheck/avoid_unsafe_collection_methods
  if (lastIdx == -1) return candidates.first;
  return candidates[(lastIdx + 1) % candidates.length];
}

/// RANDOM strategy: talkativeness-weighted, excluding the last speaker.
CharacterFile _selectWeightedRandom(
  List<CharacterFile> unmuted,
  String? lastSpeakerId,
) {
  final candidates = unmuted.length > 1
      ? unmuted.where((c) => c.appCardId != lastSpeakerId).toList()
      : unmuted;
  final random = Random();
  final totalWeight = candidates.fold<double>(
    0,
    (sum, c) => sum + c.card.cardwaveData.talkativeness,
  );
  if (totalWeight <= 0) {
    return candidates[random.nextInt(candidates.length)];
  }
  var pick = random.nextDouble() * totalWeight;
  for (final char in candidates) {
    pick -= char.card.cardwaveData.talkativeness;
    if (pick <= 0) return char;
  }
  // `candidates` is non-empty (it derives from the non-empty unmuted list).
  // ignore: qcheck/avoid_unsafe_collection_methods
  return candidates.last;
}
