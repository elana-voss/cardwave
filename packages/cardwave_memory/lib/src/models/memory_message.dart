import 'package:cardwave_memory/src/models/memory_role.dart';

/// One chat turn handed to the memory engine. The app maps `ChatMessage`
/// (`id`, `role`, `activeSwipe.content`, `timestamp`, `characterId`) onto
/// this. Transient input — never persisted; the chat log stays the source of
/// truth. [characterId] is null in 1:1 chats (mirrors `ChatMessage`).
class MemoryMessage {
  const MemoryMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.characterId,
  });

  final String id;
  final MemoryRole role;
  final String text;
  final int timestamp;
  final String? characterId;
}
