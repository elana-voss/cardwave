import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a fixed vector for known query strings, a zero vector otherwise.
/// Event vectors are set directly on each [StoryEvent]; this only embeds the
/// query, so the tests control every cosine exactly.
class _QueryEmbedder extends Embedder {
  _QueryEmbedder(this._byText);

  final Map<String, Float32List> _byText;

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

  Float32List _vectorFor(String text) =>
      _byText[text] ?? Float32List(embeddingsDim);
}

// Unit basis vector e_i. Dot product with e_0 is 1 when i == 0, else 0.
Float32List _basis(int index) => Float32List(embeddingsDim)..[index] = 1.0;

// A vector whose dot product with e_0 (the query vector in these tests) is
// exactly [dotWithBasis0] — the embedder L2-normalizes, so cosine == dot.
Float32List _withCosine(double dotWithBasis0) =>
    Float32List(embeddingsDim)..[0] = dotWithBasis0;

StoryEvent _event(
  String id, {
  String text = '',
  List<String> characters = const [],
  List<String> locations = const [],
  List<String> keywords = const [],
  List<String> linkedEventIds = const [],
  int? supersededAt,
  int? validUntil,
  Float32List? vector,
}) {
  final event = StoryEvent(
    id: id,
    recordedAt: 0,
    text: text,
    contextualPrefix: '',
    characters: characters,
    locations: locations,
    keywords: keywords,
    linkedEventIds: linkedEventIds,
    supersededAt: supersededAt,
    validUntil: validUntil,
  );
  event.vector = vector;
  return event;
}

List<String> _ids(List<StoryEvent> events) => [for (final e in events) e.id];

void main() {
  test('hybrid fusion ranks a dual-channel match above a keyword-only one',
      () async {
    final graph = MemoryGraph(
      events: [
        _event(
          'attack',
          text: 'a dragon attacks the village',
          keywords: ['dragon', 'attack'],
          vector: _basis(0),
        ),
        _event('dinner', text: 'they eat dinner', vector: _basis(1)),
        _event(
          'mention',
          text: 'a dragon is mentioned',
          keywords: ['dragon'],
          vector: _basis(2),
        ),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'dragon attack': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final result = await retriever.retrieve('dragon attack');

    expect(
      _ids(result),
      ['attack', 'mention'],
      reason: 'attack matches both channels; mention only keyword; dinner '
          'matches neither and is dropped',
    );
  });

  test('an exact name match outranks an otherwise-equal event without it',
      () async {
    // Both events match the query "raven" in exactly one field and share the
    // query vector, so they tie on both channels; only the named-entity boost
    // separates them.
    final graph = MemoryGraph(
      events: [
        _event('person', text: 'a quiet evening',
            characters: ['Raven'], vector: _basis(0)),
        _event('bird', text: 'a quiet evening',
            keywords: ['raven'], vector: _basis(0)),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'raven': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final result = await retriever.retrieve('raven');

    expect(result.first.id, 'person', reason: 'the character match is boosted');
    expect(
      _ids(result).toSet(),
      {'person', 'bird'},
      reason: 'the boost reorders, it does not drop the other event',
    );
  });

  test('the relevance cutoff keeps cosine at the threshold and drops below it',
      () async {
    // Query token matches no field, so only the meaning channel admits events
    // and the cutoff alone decides.
    final graph = MemoryGraph(
      events: [
        _event('high', text: 'alpha', vector: _withCosine(1.0)),
        _event('exactly', text: 'bravo', vector: _withCosine(0.6)),
        _event('below', text: 'charlie', vector: _withCosine(0.59)),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'unmatched': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final result = await retriever.retrieve('unmatched');

    expect(
      _ids(result).toSet(),
      {'high', 'exactly'},
      reason: 'cosine 0.6 is at the cutoff and kept; 0.59 is below and dropped',
    );
  });

  test('superseded events are filtered by default, kept when retrospective',
      () async {
    final graph = MemoryGraph(
      events: [
        _event('live', text: 'the king rules', keywords: ['king'],
            vector: _basis(0)),
        _event('old', text: 'the king rules', keywords: ['king'],
            vector: _basis(0), supersededAt: 123),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'king': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final current = await retriever.retrieve('king');
    expect(_ids(current), ['live'], reason: 'the superseded fact is filtered');

    final past = await retriever.retrieve('king', retrospective: true);
    expect(
      _ids(past).toSet(),
      {'live', 'old'},
      reason: 'a retrospective query keeps the superseded fact',
    );
  });

  test('cross-link expansion walks exactly one hop', () async {
    // Only `start` is retrievable directly; `linked` and `far` match nothing.
    // `linked` should appear (one hop from start); `far` should not (two hops).
    final graph = MemoryGraph(
      events: [
        _event('start', text: 'opening', keywords: ['opening'],
            vector: _basis(0), linkedEventIds: ['linked']),
        _event('linked', text: 'aside', vector: _basis(5),
            linkedEventIds: ['far']),
        _event('far', text: 'unrelated', vector: _basis(6)),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'opening': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final result = await retriever.retrieve('opening');

    expect(_ids(result), contains('start'));
    expect(_ids(result), contains('linked'));
    expect(
      _ids(result),
      isNot(contains('far')),
      reason: 'far is two hops away and must not be pulled in',
    );
  });

  test('arc retrieval returns the chapter summary, not scenes or event text',
      () async {
    final graph = MemoryGraph(
      events: [_event('e1', text: 'sword clashes in the war')],
      nodes: [
        const TreeNode(
          id: 'scene1',
          level: TreeLevelEnum.scene,
          summary: 'the war drums sound',
        ),
        const TreeNode(
          id: 'chapter1',
          level: TreeLevelEnum.chapter,
          summary: 'the war begins',
        ),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    final result = retriever.retrieveArcSummaries(
      'war',
      level: TreeLevelEnum.chapter,
    );

    expect(result, hasLength(1));
    expect(result.first.level, TreeLevelEnum.chapter);
    expect(result.first.summary, 'the war begins');
  });

  test('rebuilding the index picks up events committed after load', () async {
    final eventLoaded = _event('loaded', text: 'prologue',
        keywords: ['prologue'], vector: _basis(0));
    final graph = MemoryGraph(events: [eventLoaded]);
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    expect(
      await retriever.retrieve('newcomer'),
      isEmpty,
      reason: 'no event mentions newcomer yet',
    );

    graph.events.add(
      _event('committed', text: 'newcomer arrives', keywords: ['newcomer'],
          vector: _basis(1)),
    );
    await retriever.rebuildIndex();

    expect(
      _ids(await retriever.retrieve('newcomer')),
      ['committed'],
      reason: 'the rebuilt index now finds the newly committed event',
    );
  });
}
