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
  String eventType = 'conversation',
  String cause = '',
  String effect = '',
  int importance = 1,
}) => <String, dynamic>{
  'text': text,
  'contextual_prefix': 'prefix',
  'event_type': eventType,
  'cause': cause,
  'effect': effect,
  'message_numbers': numbers,
  'characters': <String>[],
  'locations': <String>[],
  'items': <String>[],
  'concepts': <String>[],
  'keywords': <String>[],
  'importance': importance,
};

Map<String, dynamic> _factJson({
  required List<String> subjects,
  required String text,
  required List<int> numbers,
  String? supersedes,
}) => <String, dynamic>{
  'subjects': subjects,
  'text': text,
  'message_numbers': numbers,
  'supersedes': supersedes,
};

Map<String, dynamic> _threadJson({
  required List<String> subjects,
  required String text,
  required List<int> numbers,
}) => <String, dynamic>{
  'subjects': subjects,
  'text': text,
  'message_numbers': numbers,
};

Map<String, dynamic> _output({
  List<Map<String, dynamic>> events = const [],
  List<Map<String, dynamic>> facts = const [],
  List<Map<String, dynamic>> threads = const [],
  List<String> resolvedThreads = const [],
}) => <String, dynamic>{
  'events': events,
  'facts': facts,
  'threads': threads,
  'resolved_threads': resolvedThreads,
};

MemoryMessage _msg(String id, MemoryRole role, String text, int timestamp) =>
    MemoryMessage(id: id, role: role, text: text, timestamp: timestamp);

void main() {
  const happyText = 'I am so happy to see you again!';
  const angerText = 'You betrayed me and now I am furious.';
  const maylaText = 'Mayla draws her blade in the tavern.';

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
      _msg('m1', MemoryRole.user, happyText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
    ];
    final extractor = buildExtractor([
      _output(
        events: [
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
          },
        ],
      ),
    ]);

    final result = await extractor.extract(window);

    expect(result.events, hasLength(1));
    expect(result.facts, isEmpty);
    final event = result.events.single;
    expect(event.contextualPrefix, 'At the harbor at dusk,');
    expect(event.messageIds, ['m1', 'm2']);
    expect(event.userEmotion, EmotionLabelEnum.joy);
    expect(event.characterEmotion, EmotionLabelEnum.anger);
    expect(event.importance, 3);
    expect(event.vector, isNotNull);
    expect(event.vector!.length, embeddingsDim);
  });

  test('extraction yields a fact with normalized subjects and message ids', () async {
    final window = [_msg('m1', MemoryRole.character, maylaText, 1)];
    final result = await buildExtractor([
      _output(
        facts: [
          _factJson(
            subjects: ['Mayla', 'Captain'],
            text: 'Mayla and the captain are enemies',
            numbers: [1],
          ),
        ],
      ),
    ]).extract(window);

    expect(result.events, isEmpty);
    expect(result.facts, hasLength(1));
    final fact = result.facts.single;
    expect(
      fact.subjects,
      ['mayla', 'captain'],
      reason: 'subjects are lower-cased for lookup',
    );
    expect(fact.text, 'Mayla and the captain are enemies');
    expect(fact.messageIds, ['m1']);
    expect(fact.supersededAt, isNull);
  });

  test('an event citing only non-existent messages is dropped, not orphaned', () async {
    final window = [_msg('m1', MemoryRole.user, happyText, 1)];
    final result = await buildExtractor([
      _output(events: [_eventJson(text: 'unanchored', numbers: [99])]),
    ]).extract(window);

    expect(
      result.events,
      isEmpty,
      reason: 'no real message backs the event, so it cannot be stored',
    );
  });

  test('a fact citing only non-existent messages is dropped', () async {
    final window = [_msg('m1', MemoryRole.user, happyText, 1)];
    final result = await buildExtractor([
      _output(
        facts: [_factJson(subjects: ['x'], text: 'unanchored', numbers: [99])],
      ),
    ]).extract(window);

    expect(
      result.facts,
      isEmpty,
      reason: 'no real message backs the fact, so it cannot be reconciled',
    );
  });

  test('malformed or failed output yields nothing, no throw', () async {
    final window = [_msg('m1', MemoryRole.user, happyText, 1)];

    // A present-but-malformed map: no usable events or facts.
    final malformed = await buildExtractor([
      <String, dynamic>{'unexpected': true},
    ]).extract(window);
    expect(malformed.events, isEmpty);
    expect(malformed.facts, isEmpty);

    // completeStructured throwing (its real behavior on unparseable output).
    final failed = await buildExtractor([
      Exception('no parseable structured output'),
    ]).extract(window);
    expect(failed.events, isEmpty);
    expect(failed.facts, isEmpty);
  });

  test('events and facts commit straight into the graph, no staging', () async {
    final engine = buildEngine([
      _output(
        events: [_eventJson(text: 'a tense reunion', numbers: [1, 2])],
        facts: [
          _factJson(subjects: ['mayla'], text: 'Mayla is furious', numbers: [2]),
        ],
      ),
    ]);

    await engine.ingestWindow([
      _msg('m1', MemoryRole.user, happyText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
    ]);

    expect(engine.graph.events, hasLength(1));
    expect(engine.graph.facts, hasLength(1));
    expect(engine.graph.events.single.messageIds, ['m1', 'm2']);
    expect(engine.graph.facts.single.text, 'Mayla is furious');
  });

  test('a new fact supersedes a known candidate fact in one call', () async {
    final engine = buildEngine([
      _output(
        facts: [
          _factJson(subjects: ['mayla'], text: 'Mayla is a sailor', numbers: [1]),
        ],
      ),
      _output(
        facts: [
          _factJson(
            subjects: ['mayla'],
            text: 'Mayla is a captain',
            numbers: [1],
            supersedes: 'F1',
          ),
        ],
      ),
    ]);

    // Both windows name Mayla, so the first fact is a candidate in the second.
    await engine.ingestWindow([_msg('m1', MemoryRole.character, maylaText, 1)]);
    await engine.ingestWindow([_msg('m2', MemoryRole.character, maylaText, 2)]);

    final byText = {for (final fact in engine.graph.facts) fact.text: fact};
    expect(byText.keys, containsAll(['Mayla is a sailor', 'Mayla is a captain']));
    expect(
      byText['Mayla is a sailor']!.supersededAt,
      isNotNull,
      reason: 'the old fact is retired',
    );
    expect(
      byText['Mayla is a sailor']!.supersededBy,
      byText['Mayla is a captain']!.id,
    );
    expect(
      byText['Mayla is a captain']!.supersededAt,
      isNull,
      reason: 'the new fact is current',
    );
  });

  test('earlier messages are background only; each message is extracted once', () async {
    final engine = MemoryEngine(
      extractor: buildExtractor([
        // Window 1: m1, m2 are new (numbered 1, 2).
        _output(events: [_eventJson(text: 'opening beat', numbers: [1, 2])]),
        // Window 2: m2 is background, m3 is the only new message (number 1).
        _output(events: [_eventJson(text: 'next beat', numbers: [1])]),
      ]),
      batchSize: 2,
      contextSize: 1,
    );

    await engine.processMessages([
      _msg('m1', MemoryRole.user, happyText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
      _msg('m3', MemoryRole.user, happyText, 3),
    ]);

    expect(
      engine.graph.events,
      hasLength(2),
      reason: 'one event per window — m2 is background in window 2, not re-extracted',
    );
    final covered = {
      for (final event in engine.graph.events) ...event.messageIds,
    };
    expect(covered, {'m1', 'm2', 'm3'});
  });

  test('reconcile drops events and facts whose messages changed, recomputes from there', () async {
    final engine = buildEngine([
      _output(
        events: [_eventJson(text: 'e1', numbers: [1, 2])],
        facts: [_factJson(subjects: ['mayla'], text: 'f1', numbers: [1])],
      ),
      _output(
        events: [_eventJson(text: 'e2', numbers: [1, 2])],
        facts: [_factJson(subjects: ['mayla'], text: 'f2', numbers: [1])],
      ),
    ]);
    await engine.ingestWindow([
      _msg('m1', MemoryRole.user, maylaText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
    ]);
    await engine.ingestWindow([
      _msg('m3', MemoryRole.user, maylaText, 3),
      _msg('m4', MemoryRole.character, angerText, 4),
    ]);

    // m2's text changes; m4 is deleted.
    final result = engine.reconcile([
      _msg('m1', MemoryRole.user, maylaText, 1),
      _msg('m2', MemoryRole.character, 'an entirely different line', 2),
      _msg('m3', MemoryRole.user, maylaText, 3),
    ]);

    expect(
      result.recomputeFromIndex,
      1,
      reason: 'm2 sits at position 1 and is the earliest change',
    );
    expect(
      engine.graph.events,
      isEmpty,
      reason: 'e1 covers m2; e2 covers m3/m4 — both at or after the change',
    );
    expect(
      engine.graph.facts.map((fact) => fact.text),
      ['f1'],
      reason: 'f1 anchors to m1 (before the change) and survives; f2 (m3) drops',
    );
  });

  test('reconcile revives a fact whose superseding fact was dropped', () async {
    final engine = buildEngine([
      _output(
        facts: [_factJson(subjects: ['mayla'], text: 'f-old', numbers: [1])],
      ),
      _output(
        facts: [
          _factJson(
            subjects: ['mayla'],
            text: 'f-new',
            numbers: [1],
            supersedes: 'F1',
          ),
        ],
      ),
    ]);
    await engine.ingestWindow([
      _msg('m1', MemoryRole.character, maylaText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
    ]);
    await engine.ingestWindow([
      _msg('m3', MemoryRole.character, maylaText, 3),
      _msg('m4', MemoryRole.character, angerText, 4),
    ]);

    final old = engine.graph.facts.firstWhere((fact) => fact.text == 'f-old');
    expect(old.supersededAt, isNotNull, reason: 'f-new retired f-old');

    // m3 is deleted: reconcile drops f-new (anchored to m3), so the fact it had
    // superseded is no longer contradicted and must come back as current.
    engine.reconcile([
      _msg('m1', MemoryRole.character, maylaText, 1),
      _msg('m2', MemoryRole.character, angerText, 2),
      _msg('m4', MemoryRole.character, angerText, 4),
    ]);

    expect(engine.graph.facts.map((fact) => fact.text), ['f-old']);
    expect(
      engine.graph.facts.single.supersededAt,
      isNull,
      reason: 'the revived fact is current again',
    );
    expect(engine.graph.facts.single.supersededBy, isNull);
  });

  test('extraction parses event_type, cause and effect', () async {
    final window = [_msg('m1', MemoryRole.character, maylaText, 1)];
    final result = await buildExtractor([
      _output(
        events: [
          _eventJson(
            text: 'Mayla strikes the captain',
            numbers: [1],
            eventType: 'conflict',
            cause: 'he refused her the ship',
            effect: 'the crew turns on her',
            importance: 4,
          ),
        ],
      ),
    ]).extract(window);

    final event = result.events.single;
    expect(event.eventType, EventTypeEnum.conflict);
    expect(event.cause, 'he refused her the ship');
    expect(event.effect, 'the crew turns on her');
    expect(event.importance, 4);
  });

  test('an unknown event_type falls back to other; importance clamps to 1-5', () async {
    final window = [_msg('m1', MemoryRole.character, maylaText, 1)];
    final result = await buildExtractor([
      _output(
        events: [
          _eventJson(
            text: 'something',
            numbers: [1],
            eventType: 'quest_update',
            importance: 9,
          ),
        ],
      ),
    ]).extract(window);

    final event = result.events.single;
    expect(event.eventType, EventTypeEnum.other);
    expect(event.importance, 5, reason: 'out-of-range importance clamps to 5');
  });

  test('a thread opens, then a later window resolves it', () async {
    final engine = buildEngine([
      _output(
        threads: [
          _threadJson(
            subjects: ['mayla'],
            text: 'Mayla owes the captain a debt',
            numbers: [1],
          ),
        ],
      ),
      _output(resolvedThreads: ['T1']),
    ]);

    await engine.ingestWindow([_msg('m1', MemoryRole.character, maylaText, 1)]);
    expect(engine.graph.threads, hasLength(1));
    expect(engine.graph.threads.single.resolvedAt, isNull);

    // Second window names Mayla, so the open thread is a candidate; the model
    // marks it resolved.
    await engine.ingestWindow([_msg('m2', MemoryRole.character, maylaText, 2)]);
    final thread = engine.graph.threads.single;
    expect(thread.resolvedAt, isNotNull, reason: 'the thread is closed');
    expect(thread.resolvedByMessageIds, ['m2']);
  });

  test('reconcile reopens a thread whose resolving message is edited away', () async {
    final engine = buildEngine([
      _output(
        threads: [
          _threadJson(subjects: ['mayla'], text: 'a debt owed', numbers: [1]),
        ],
      ),
      _output(resolvedThreads: ['T1']),
    ]);
    await engine.ingestWindow([_msg('m1', MemoryRole.character, maylaText, 1)]);
    await engine.ingestWindow([_msg('m2', MemoryRole.character, maylaText, 2)]);
    expect(engine.graph.threads.single.resolvedAt, isNotNull);

    // m2 resolved it; change m2's text so reconcile drops the resolution.
    engine.reconcile([
      _msg('m1', MemoryRole.character, maylaText, 1),
      _msg('m2', MemoryRole.character, 'a different line', 2),
    ]);

    final thread = engine.graph.threads.single;
    expect(thread.resolvedAt, isNull, reason: 'the thread reopens');
    expect(thread.resolvedByMessageIds, isEmpty);
  });

  test('reconcile drops a thread whose opening message changed', () async {
    final engine = buildEngine([
      _output(
        threads: [
          _threadJson(subjects: ['mayla'], text: 'a debt owed', numbers: [1]),
        ],
      ),
    ]);
    await engine.ingestWindow([_msg('m1', MemoryRole.character, maylaText, 1)]);
    expect(engine.graph.threads, hasLength(1));

    engine.reconcile([_msg('m1', MemoryRole.character, 'rewritten', 1)]);
    expect(
      engine.graph.threads,
      isEmpty,
      reason: 'the thread was opened from m1, which changed',
    );
  });
}
