import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:schemantic/schemantic.dart';

/// Scripted [LlmRunner]: returns (or throws) the queued results in order,
/// overriding [completeStructured] so genkit is never reached. The dummy
/// model/genkit satisfy the parent constructor but are never used.
class _FakeLlmRunner extends LlmRunner {
  _FakeLlmRunner(this._queue)
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  final List<Object> _queue;

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async {
    final next = _queue.removeAt(0);
    if (next is Exception) throw next;
    return next as Map<String, dynamic>;
  }
}

/// Returns a mapped vector for known texts (the emotion descriptions and the
/// role lines), a constant non-zero vector otherwise — enough to drive the
/// classifier and to give every event a non-null embedding.
class _MapEmbedder extends Embedder {
  _MapEmbedder(this._vectors);

  final Map<String, Float32List> _vectors;

  @override
  Future<List<Float32List>> embed(
    List<String> texts, {
    required EmbedTaskEnum task,
  }) async => [for (final text in texts) _vectorFor(text)];

  @override
  Future<Float32List> embedOne(
    String text, {
    required EmbedTaskEnum task,
  }) async => _vectorFor(text);

  Float32List _vectorFor(String text) => _vectors[text] ?? _fallback;

  static final Float32List _fallback = Float32List.fromList(
    List<double>.filled(embeddingsDim, 0.1),
  );
}

Float32List _basis(int index) => Float32List(embeddingsDim)..[index] = 1.0;

int _indexOfLabel(EmotionLabelEnum label) {
  var index = 0;
  for (final entry in emotionDescriptions) {
    if (entry.label == label) return index;
    index++;
  }
  return -1;
}

Map<String, dynamic> _eventJson({
  required String text,
  required List<int> numbers,
}) => <String, dynamic>{
  'text': text,
  'contextual_prefix': 'prefix',
  'message_numbers': numbers,
  'characters': <String>[],
  'locations': <String>[],
  'items': <String>[],
  'concepts': <String>[],
  'keywords': <String>[],
  'importance': 1,
  'beat': null,
};

void main() {
  const happyText = 'I am so happy to see you again!';
  const angerText = 'You betrayed me and now I am furious.';

  late Map<String, Float32List> vectors;

  setUp(() {
    vectors = {};
    var index = 0;
    for (final entry in emotionDescriptions) {
      vectors[entry.description] = _basis(index);
      index++;
    }
    vectors[happyText] = _basis(_indexOfLabel(EmotionLabelEnum.joy));
    vectors[angerText] = _basis(_indexOfLabel(EmotionLabelEnum.anger));
  });

  MemoryExtractor buildExtractor(List<Object> queue) {
    final embedder = _MapEmbedder(vectors);
    return MemoryExtractor(
      runner: _FakeLlmRunner(queue),
      embedder: embedder,
      classifier: EmotionClassifier(embedder),
    );
  }

  MemoryEngine buildEngine(List<Object> queue) =>
      MemoryEngine(extractor: buildExtractor(queue));

  test('extraction yields an event with prefix, emotions, and a vector', () async {
    final window = [
      const MemoryMessage(
        id: 'm1',
        role: MemoryRole.user,
        text: happyText,
        timestamp: 1,
      ),
      const MemoryMessage(
        id: 'm2',
        role: MemoryRole.character,
        text: angerText,
        timestamp: 2,
      ),
    ];
    final extractor = buildExtractor([
      <String, dynamic>{
        'events': [
          <String, dynamic>{
            'text': 'They reunite, then the mood turns.',
            'contextual_prefix': 'At the harbor at dusk,',
            'message_numbers': [1, 2],
            'characters': ['Mayla'],
            'locations': ['harbor'],
            'items': <String>[],
            'concepts': ['reunion'],
            'keywords': ['dusk'],
            'importance': 3,
            'beat': 'conflict',
          },
        ],
        'scene_end_message': null,
        'scene_summary': '',
      },
    ]);

    final result = await extractor.extract(window);

    expect(result.verdict, isA<SceneContinues>());
    expect(result.events, hasLength(1));
    for (final event in result.events) {
      expect(event.contextualPrefix, 'At the harbor at dusk,');
      expect(event.messageIds, ['m1', 'm2']);
      expect(event.userEmotion, EmotionLabelEnum.joy);
      expect(event.characterEmotion, EmotionLabelEnum.anger);
      expect(event.beat, SceneBeatEnum.conflict);
      expect(event.importance, 3);
      expect(event.vector, isNotNull);
      expect(event.vector!.length, embeddingsDim);
    }
  });

  test('an event citing only non-existent messages is dropped, not orphaned', () async {
    final window = [
      const MemoryMessage(
        id: 'm1',
        role: MemoryRole.user,
        text: happyText,
        timestamp: 1,
      ),
    ];
    final result = await buildExtractor([
      <String, dynamic>{
        'events': [_eventJson(text: 'unanchored', numbers: [99])],
        'scene_end_message': null,
        'scene_summary': '',
      },
    ]).extract(window);

    expect(
      result.events,
      isEmpty,
      reason: 'no real message backs the event, so it cannot be stored',
    );
  });

  test('malformed or failed output leaves the window provisional, no throw', () async {
    final window = [
      const MemoryMessage(
        id: 'm1',
        role: MemoryRole.user,
        text: happyText,
        timestamp: 1,
      ),
    ];

    // A present-but-malformed map: no usable events.
    final malformed = await buildExtractor([
      <String, dynamic>{'unexpected': true},
    ]).extract(window);
    expect(malformed.events, isEmpty);
    expect(malformed.verdict, isA<SceneContinues>());

    // completeStructured throwing (its real behavior on unparseable output).
    final failed = await buildExtractor([
      Exception('no parseable structured output'),
    ]).extract(window);
    expect(failed.events, isEmpty);
    expect(failed.verdict, isA<SceneContinues>());
  });

  test('an end-cut verdict commits the staged scene as a tree node', () async {
    final window = [
      const MemoryMessage(
        id: 'm1',
        role: MemoryRole.user,
        text: happyText,
        timestamp: 1,
      ),
      const MemoryMessage(
        id: 'm2',
        role: MemoryRole.character,
        text: angerText,
        timestamp: 2,
      ),
    ];
    final engine = buildEngine([
      <String, dynamic>{
        'events': [_eventJson(text: 'A tense reunion.', numbers: [1, 2])],
        'scene_end_message': 2,
        'scene_summary': 'Mayla and the captain reunite, badly.',
      },
    ]);

    await engine.ingestWindow(window);

    expect(engine.staging.isEmpty, isTrue, reason: 'committed events leave staging');
    expect(engine.graph.events, hasLength(1));
    final scenes = [
      for (final node in engine.graph.nodes)
        if (node.level == TreeLevelEnum.scene) node,
    ];
    expect(scenes, hasLength(1));
    for (final scene in scenes) {
      expect(scene.summary, 'Mayla and the captain reunite, badly.');
      expect(scene.eventIds, hasLength(1));
      expect(scene.messageIds, ['m1', 'm2']);
    }
  });

  test('a "continues" verdict keeps events provisional across two windows', () async {
    const m1 = MemoryMessage(
      id: 'm1',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 1,
    );
    const m2 = MemoryMessage(
      id: 'm2',
      role: MemoryRole.character,
      text: angerText,
      timestamp: 2,
    );
    const m3 = MemoryMessage(
      id: 'm3',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 3,
    );
    final engine = buildEngine([
      <String, dynamic>{
        'events': [_eventJson(text: 'beat one', numbers: [1, 2])],
        'scene_end_message': null,
        'scene_summary': '',
      },
      <String, dynamic>{
        'events': [_eventJson(text: 'beat two', numbers: [1, 2])],
        'scene_end_message': null,
        'scene_summary': '',
      },
    ]);

    await engine.ingestWindow([m1, m2]);
    // Overlapping window (re-reads m2 as leading context).
    await engine.ingestWindow([m2, m3]);

    expect(engine.graph.nodes, isEmpty, reason: 'nothing commits while the scene continues');
    expect(
      engine.staging.length,
      2,
      reason: 'both events stay provisional, not lost across windows',
    );
  });

  test('reconcile drops nodes whose messages changed and recomputes from there', () async {
    const m1 = MemoryMessage(
      id: 'm1',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 1,
    );
    const m2 = MemoryMessage(
      id: 'm2',
      role: MemoryRole.character,
      text: angerText,
      timestamp: 2,
    );
    const m3 = MemoryMessage(
      id: 'm3',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 3,
    );
    const m4 = MemoryMessage(
      id: 'm4',
      role: MemoryRole.character,
      text: angerText,
      timestamp: 4,
    );
    final engine = buildEngine([
      <String, dynamic>{
        'events': [_eventJson(text: 'scene one', numbers: [1, 2])],
        'scene_end_message': 2,
        'scene_summary': 'first scene',
      },
      <String, dynamic>{
        'events': [_eventJson(text: 'scene two', numbers: [1, 2])],
        'scene_end_message': 2,
        'scene_summary': 'second scene',
      },
    ]);

    await engine.ingestWindow([m1, m2]); // commits scene 1 over m1, m2
    await engine.ingestWindow([m3, m4]); // commits scene 2 over m3, m4

    final committedIds = [for (final node in engine.graph.nodes) node.id];
    expect(committedIds, hasLength(2));

    // m2's text changes; m4 is deleted.
    final result = engine.reconcile(const [
      m1,
      MemoryMessage(
        id: 'm2',
        role: MemoryRole.character,
        text: 'an entirely different line',
        timestamp: 2,
      ),
      m3,
    ]);

    expect(
      result.recomputeFromIndex,
      1,
      reason: 'm2 sits at position 1 and is the earliest change',
    );
    expect(
      result.dirtyNodeIds.toSet(),
      committedIds.toSet(),
      reason: 'scene 1 depends on m2; scene 2 sits after the change — both recompute',
    );
    expect(engine.graph.nodes, isEmpty);
    expect(engine.graph.events, isEmpty);
  });

  test('earlier messages are background only; each message is extracted once', () async {
    const m1 = MemoryMessage(
      id: 'm1',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 1,
    );
    const m2 = MemoryMessage(
      id: 'm2',
      role: MemoryRole.character,
      text: angerText,
      timestamp: 2,
    );
    const m3 = MemoryMessage(
      id: 'm3',
      role: MemoryRole.user,
      text: happyText,
      timestamp: 3,
    );
    final engine = MemoryEngine(
      extractor: buildExtractor([
        // Window 1: m1, m2 are new (numbered 1, 2).
        <String, dynamic>{
          'events': [_eventJson(text: 'opening beat', numbers: [1, 2])],
          'scene_end_message': null,
          'scene_summary': '',
        },
        // Window 2: m2 is background, m3 is the only new message (number 1).
        <String, dynamic>{
          'events': [_eventJson(text: 'next beat', numbers: [1])],
          'scene_end_message': null,
          'scene_summary': '',
        },
      ]),
      batchSize: 2,
      contextSize: 1,
    );

    await engine.processMessages([m1, m2, m3]);

    expect(
      engine.staging.length,
      2,
      reason: 'one event per window — m2 is background in window 2, not re-extracted',
    );
    final covered = {
      for (final event in engine.staging.events) ...event.messageIds,
    };
    expect(covered, {'m1', 'm2', 'm3'});
  });
}
