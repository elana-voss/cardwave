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
  int importance = 3,
  Float32List? vector,
}) {
  final event = StoryEvent(
    id: id,
    recordedAt: 0,
    text: text,
    contextualPrefix: '',
    importance: importance,
    characters: characters,
    locations: locations,
    keywords: keywords,
  );
  event.vector = vector;
  return event;
}

MemoryThread _thread(
  String id, {
  required List<String> subjects,
  String text = '',
  int? resolvedAt,
}) => MemoryThread(
  id: id,
  subjects: subjects,
  text: text,
  resolvedAt: resolvedAt,
);

MemoryFact _fact(
  String id, {
  required List<String> subjects,
  String text = '',
  int? supersededAt,
}) => MemoryFact(
  id: id,
  subjects: subjects,
  text: text,
  supersededAt: supersededAt,
);

List<String> _ids(List<StoryEvent> events) => [for (final e in events) e.id];

void main() {
  test('hybrid fusion ranks a dual-channel match above a keyword-only one',
      () async {
    final graph = MemoryGraph(
      events: [
        _event('attack', text: 'a dragon attacks the village',
            keywords: ['dragon', 'attack'], vector: _basis(0)),
        _event('dinner', text: 'they eat dinner', vector: _basis(1)),
        _event('mention', text: 'a dragon is mentioned',
            keywords: ['dragon'], vector: _basis(2)),
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
    // Both events match "raven" in exactly one field and share the query
    // vector, so they tie on both channels; only the named-entity boost
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

  test('rebuilding the index picks up events committed after load', () async {
    final graph = MemoryGraph(
      events: [
        _event('loaded', text: 'prologue', keywords: ['prologue'],
            vector: _basis(0)),
      ],
    );
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

  test('facts are retrieved by an entity the query names, newest first', () {
    final graph = MemoryGraph(
      facts: [
        _fact('f1', subjects: ['mayla'], text: 'Mayla is a sailor'),
        _fact('f2', subjects: ['captain'], text: 'the captain is cruel'),
        _fact('f3', subjects: ['mayla'], text: 'Mayla now captains the ship'),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    final facts = retriever.retrieveFacts('what is mayla doing now');

    expect(
      facts.map((fact) => fact.text),
      ['Mayla now captains the ship', 'Mayla is a sailor'],
      reason: 'both Mayla facts, newest first; the captain fact is not named',
    );
  });

  test('a superseded fact is never retrieved', () {
    final graph = MemoryGraph(
      facts: [
        _fact('f1', subjects: ['mayla'], text: 'old', supersededAt: 123),
        _fact('f2', subjects: ['mayla'], text: 'current'),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    expect(
      retriever.retrieveFacts('mayla').map((fact) => fact.text),
      ['current'],
      reason: 'the retired fact stays hidden',
    );
  });

  test('the active character brings its facts even when the query omits the name',
      () {
    final graph = MemoryGraph(
      facts: [_fact('f1', subjects: ['mayla'], text: 'Mayla is a captain')],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    expect(
      retriever
          .retrieveFacts('what now', activeSubjects: ['Mayla'])
          .map((fact) => fact.text),
      ['Mayla is a captain'],
      reason: 'the current character is always an entity in the lookup',
    );
  });

  test('a fact about an unnamed entity does not surface', () {
    final graph = MemoryGraph(
      facts: [_fact('f1', subjects: ['captain'], text: 'the captain is cruel')],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    expect(
      retriever.retrieveFacts('tell me about mayla'),
      isEmpty,
      reason: 'no query token or active subject names the captain',
    );
  });

  test('between equally-relevant events the more important ranks first', () async {
    // Both events match the keyword and share the query vector, so they tie on
    // both channels; only the importance boost separates them.
    final graph = MemoryGraph(
      events: [
        _event('trivial', text: 'a dragon passes by',
            keywords: ['dragon'], importance: 1, vector: _basis(0)),
        _event('pivotal', text: 'a dragon razes the village',
            keywords: ['dragon'], importance: 5, vector: _basis(0)),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder({'dragon': _basis(0)}),
      graph: graph,
    );
    await retriever.rebuildIndex();

    final result = await retriever.retrieve('dragon');

    expect(result.first.id, 'pivotal', reason: 'higher importance is lifted');
    expect(
      _ids(result).toSet(),
      {'pivotal', 'trivial'},
      reason: 'the boost reorders, it does not drop the other event',
    );
  });

  test('open threads are retrieved by name; resolved ones stay hidden', () {
    final graph = MemoryGraph(
      threads: [
        _thread('t1', subjects: ['mayla'], text: 'Mayla owes a debt'),
        _thread('t2', subjects: ['mayla'], text: 'an old promise',
            resolvedAt: 123),
        _thread('t3', subjects: ['captain'], text: 'the captain seeks revenge'),
      ],
    );
    final retriever = MemoryRetriever(
      embedder: _QueryEmbedder(const {}),
      graph: graph,
    );

    expect(
      retriever.retrieveThreads('what about mayla').map((t) => t.text),
      ['Mayla owes a debt'],
      reason: 'only the open thread Mayla is named in surfaces',
    );
  });
}
