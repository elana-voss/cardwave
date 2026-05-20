import 'dart:typed_data';

import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:flutter_test/flutter_test.dart';

StoryEvent _buildEvent({Float32List? vector}) => StoryEvent(
  id: newEventId(),
  recordedAt: 2000,
  text: 'Mayla drew her blade on the crew in the harbor tavern.',
  contextualPrefix: 'In the harbor tavern at dusk,',
  messageIds: const ['msg-1', 'msg-2'],
  validFrom: 1000,
  beat: SceneBeatEnum.conflict,
  characterEmotion: EmotionLabelEnum.anger,
  userEmotion: EmotionLabelEnum.fear,
  importance: 3,
  linkedEventIds: const ['event-earlier'],
  characters: const ['Mayla'],
  locations: const ['Harbor Tavern'],
  items: const ['blade'],
  concepts: const ['betrayal'],
  keywords: const ['tavern', 'blade'],
  vector: vector,
);

MemoryGraph _buildGraph({Float32List? vector}) {
  final event = _buildEvent(vector: vector);
  final sceneId = newSceneId();
  final chapterId = newChapterId();
  return MemoryGraph(
    events: [event],
    nodes: [
      TreeNode(
        id: sceneId,
        level: TreeLevelEnum.scene,
        parentId: chapterId,
        childIds: [event.id],
        messageIds: const ['msg-1', 'msg-2'],
        summary: 'Mayla confronts the crew.',
        eventIds: [event.id],
      ),
      TreeNode(
        id: chapterId,
        level: TreeLevelEnum.chapter,
        childIds: [sceneId],
        summary: '',
      ),
    ],
    roots: [chapterId],
  );
}

void main() {
  test('MemoryGraph survives a JSON round-trip with field equality', () {
    final graph = _buildGraph();
    final clone = MemoryGraph.fromJson(graph.toJson());
    expect(clone.toJson(), graph.toJson());
  });

  test('MemoryMessage carries the mapped chat-turn fields', () {
    const message = MemoryMessage(
      id: 'msg-7',
      role: MemoryRole.character,
      text: 'You shouldn\'t have come here.',
      timestamp: 5,
      characterId: 'char-3',
    );
    expect(message.role, MemoryRole.character);
    expect(message.characterId, 'char-3');
  });

  test('event vectors round-trip through the sidecar codec', () {
    final source = Float32List.fromList(
      List<double>.generate(embeddingsDim, (i) => (i % 7) * 0.01),
    );
    final graph = _buildGraph(vector: source);
    final bytes = graph.encodeVectors();

    // JSON drops vectors; the sidecar restores them.
    final restored = MemoryGraph.fromJson(graph.toJson());
    for (final event in restored.events) {
      expect(event.vector, isNull, reason: 'vectors are excluded from JSON');
    }

    restored.restoreVectors(bytes);

    expect(restored.events.length, graph.events.length);
    final original = [for (final e in graph.events) e.vector].iterator;
    final got = [for (final e in restored.events) e.vector].iterator;
    while (original.moveNext() && got.moveNext()) {
      final originalVector = original.current;
      final gotVector = got.current;
      expect(originalVector, isNotNull);
      expect(gotVector, isNotNull);
      expect(List<double>.from(gotVector!), List<double>.from(originalVector!));
    }
  });
}
