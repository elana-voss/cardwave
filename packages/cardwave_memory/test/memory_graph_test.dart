import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:flutter_test/flutter_test.dart';

StoryEvent _buildEvent({Float32List? vector}) => StoryEvent(
  id: newEventId(),
  recordedAt: 2000,
  text: 'Mayla drew her blade on the crew in the harbor tavern.',
  contextualPrefix: 'In the harbor tavern at dusk,',
  messageIds: const ['msg-1', 'msg-2'],
  characterEmotion: EmotionLabelEnum.anger,
  userEmotion: EmotionLabelEnum.fear,
  importance: 3,
  characters: const ['Mayla'],
  locations: const ['Harbor Tavern'],
  items: const ['blade'],
  concepts: const ['betrayal'],
  keywords: const ['tavern', 'blade'],
  vector: vector,
);

MemoryFact _buildFact() => MemoryFact(
  id: newFactId(),
  subjects: const ['mayla', 'the crew'],
  text: 'Mayla and the crew are enemies.',
  messageIds: const ['msg-1', 'msg-2'],
);

MemoryGraph _buildGraph({Float32List? vector}) => MemoryGraph(
  events: [_buildEvent(vector: vector)],
  facts: [_buildFact()],
);

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

  test('a superseded fact round-trips its supersession marks', () {
    final fact = MemoryFact(
      id: 'f1',
      subjects: const ['mayla'],
      text: 'Mayla is a sailor',
      messageIds: const ['msg-1'],
      supersededAt: 42,
      supersededBy: 'f2',
    );
    final clone = MemoryFact.fromJson(fact.toJson());
    expect(clone.supersededAt, 42);
    expect(clone.supersededBy, 'f2');
  });

  test('event vectors round-trip through the sidecar; facts carry none', () {
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
