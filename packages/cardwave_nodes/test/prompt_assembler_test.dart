import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a fixed vector for known texts, a constant fallback for the
/// rest. Lets tests anchor cosine ranking on specific inputs without
/// running the real model.
class _MapEmbedder extends Embedder {
  _MapEmbedder(this._vectors);

  final Map<String, Float32List> _vectors;

  @override
  Future<List<Float32List>> embed(
    List<String> texts, {
    required EmbedTaskEnum task,
  }) async =>
      [for (final t in texts) _vectorFor(t)];

  @override
  Future<Float32List> embedOne(
    String text, {
    required EmbedTaskEnum task,
  }) async =>
      _vectorFor(text);

  Float32List _vectorFor(String text) => _vectors[text] ?? _fallback;

  static final Float32List _fallback =
      Float32List.fromList(List<double>.filled(embeddingsDim, 0.0));
}

Node _stickyNode({
  String id = 'n',
  String payload = 'sticky beat',
  int currentSticky = 3,
}) {
  final node = Node(
    id: id,
    origin: NodeOriginEnum.authored,
    type: NodeTypeEnum.characterBehavior,
    triggerProb: 0.5,
    delay: 0,
    cooldown: 0,
    sticky: 5,
    alive: -1,
    scope: NodeScopeEnum.session,
    predicate: 'true',
    narrativePayload: payload,
  );
  node.currentSticky = currentSticky;
  return node;
}

Node _firedNode({String id = 'fired', String payload = 'a new beat'}) => Node(
      id: id,
      origin: NodeOriginEnum.authored,
      type: NodeTypeEnum.environmental,
      triggerProb: 1.0,
      delay: 0,
      cooldown: 0,
      sticky: 0,
      alive: -1,
      scope: NodeScopeEnum.session,
      predicate: 'true',
      narrativePayload: payload,
    );

SessionState _seedState() {
  final state = SessionState(currentGoal: 'find the letter');
  state.characters['alice'] = CharacterState();
  state.characters['alice']!.emotion[EmotionEnum.anger]!.value = 0.7;
  state.currentScene.location = 'tavern';
  state.currentScene.timeOfDay = 'evening';
  return state;
}

void main() {
  group('section ordering', () {
    test('all six sections appear in spec order', () async {
      final state = _seedState();
      final pool = NodePool()..add(_stickyNode(payload: 'still cool'));
      final assembler = PromptAssembler();
      final prompt = await assembler.assemble(
        cardDefinition: '## Alice\nA stoic gunslinger.',
        state: state,
        pool: pool,
        firedThisTurn: [_firedNode(payload: 'she sighs')],
        userInput: 'Hello',
        maxContextTokens: 8000,
      );
      final sceneIdx = prompt.indexOf('## Scene');
      final cardIdx = prompt.indexOf('## Alice');
      final stateIdx = prompt.indexOf('## State');
      final lingeringIdx = prompt.indexOf('## Lingering');
      final nowIdx = prompt.indexOf('## Now');
      final userIdx = prompt.indexOf('User: Hello');
      expect(sceneIdx, isNonNegative);
      expect(cardIdx, greaterThan(sceneIdx));
      expect(stateIdx, greaterThan(cardIdx));
      expect(lingeringIdx, greaterThan(stateIdx));
      expect(nowIdx, greaterThan(lingeringIdx));
      expect(userIdx, greaterThan(nowIdx));
    });

    test('empty scene section is dropped, not emitted as blank', () async {
      final state = SessionState();
      state.characters['alice'] = CharacterState();
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      expect(prompt, isNot(contains('## Scene')));
    });

    test('no sticky and no fired = sections omitted', () async {
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: _seedState(),
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      expect(prompt, isNot(contains('## Lingering')));
      expect(prompt, isNot(contains('## Now')));
    });
  });

  group('assembleDynamicSections', () {
    test('returns scene + variable blocks; omits cardDefinition and user',
        () async {
      final state = _seedState();
      final pool = NodePool()..add(_stickyNode(payload: 'still cool'));
      final assembler = PromptAssembler();
      final dynamic_ = await assembler.assembleDynamicSections(
        state: state,
        pool: pool,
        firedThisTurn: [_firedNode(payload: 'she sighs')],
        userInput: 'Hello',
        maxContextTokens: 8000,
      );
      expect(dynamic_, contains('## Scene'));
      expect(dynamic_, contains('## State'));
      expect(dynamic_, contains('## Lingering'));
      expect(dynamic_, contains('still cool'));
      expect(dynamic_, contains('## Now'));
      expect(dynamic_, contains('she sighs'));
      expect(dynamic_, isNot(contains('## Alice')),
          reason: 'cardDefinition is the host\'s responsibility');
      expect(dynamic_, isNot(contains('User: Hello')),
          reason: 'user input is the host\'s responsibility');
    });

    test('empty world: only the always-on state slice (phase) survives',
        () async {
      final dynamic_ = await PromptAssembler().assembleDynamicSections(
        state: SessionState()..characters['alice'] = CharacterState(),
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      // No scene, no goal, no prominent emotions, no nodes — but the
      // phase line is part of the state slice and always emits.
      expect(dynamic_, isNot(contains('## Scene')));
      expect(dynamic_, isNot(contains('## Lingering')));
      expect(dynamic_, isNot(contains('## Now')));
      expect(dynamic_, isNot(contains('## Earlier')));
      expect(dynamic_, contains('## State'));
      expect(dynamic_, contains('Phase:'));
    });
  });

  group('sticky directives', () {
    test('only currentSticky > 0 nodes contribute', () async {
      final pool = NodePool()
        ..add(_stickyNode(id: 'a', payload: 'still cool', currentSticky: 2))
        ..add(_stickyNode(id: 'b', payload: 'no longer', currentSticky: 0));
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: _seedState(),
        pool: pool,
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      expect(prompt, contains('still cool'));
      expect(prompt, isNot(contains('no longer')));
    });

    test('permanent sticky (-1) included', () async {
      final pool = NodePool()
        ..add(_stickyNode(id: 'p', payload: 'forever', currentSticky: -1));
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: _seedState(),
        pool: pool,
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      expect(prompt, contains('forever'));
    });
  });

  group('state slice', () {
    test('emotions below 0.5 are not listed; goal and phase always shown',
        () async {
      final state = _seedState();
      state.characters['alice']!.emotion[EmotionEnum.anger]!.value = 0.3;
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000,
      );
      expect(prompt, contains('Goal: find the letter'));
      expect(prompt, contains('Phase: scene'));
      expect(prompt, isNot(contains('anger')));
    });
  });

  group('memory surfacing — recency fallback (no embedder)', () {
    test('most recent fits the budget; older trimmed', () async {
      final state = _seedState();
      for (var i = 0; i < 10; i++) {
        state.eventLog.add(EventLogEntry(
          turn: i,
          text: 'event $i — ${"x" * 60}',
          significance: 0.5,
        ));
      }
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 8000, // 10% budget = 800 * 4 = 3200 chars
      );
      // All 10 entries are ~65 chars each ≈ 650 chars total; fits easily.
      for (var i = 0; i < 10; i++) {
        expect(prompt, contains('event $i'));
      }
    });

    test('with tight budget, only most recent few fit', () async {
      final state = _seedState();
      // 30 entries × ~80 chars = ~2400 chars. State slice ~60 chars eats
      // first; remaining ~420 chars fits ~5 most-recent entries.
      for (var i = 0; i < 30; i++) {
        state.eventLog.add(EventLogEntry(
          turn: i,
          text: 'turn-$i ${"x" * 70}',
          significance: 0.5,
        ));
      }
      final prompt = await PromptAssembler().assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'hi',
        maxContextTokens: 1200,
      );
      expect(prompt, contains('turn-29'));
      expect(prompt, isNot(contains('turn-0')));
    });
  });

  group('memory surfacing — embedder ranking', () {
    test('relevant entry surfaced over irrelevant one', () async {
      // Query "tavern" and entry "tavern brawl" share a vector;
      // unrelated entries map to the fallback zero vector.
      final v = Float32List.fromList(
          List<double>.filled(embeddingsDim, 0.1));
      final embedder = _MapEmbedder({
        'Hello tavern': v,
        'a tavern brawl broke out': v,
      });
      final assembler = PromptAssembler(embedder: embedder);
      final state = _seedState();
      // Only the entry whose vector matches the query should rank > 0.
      state.eventLog.add(const EventLogEntry(
        turn: 0,
        text: 'unrelated event one',
        significance: 0.5,
      ));
      state.eventLog.add(const EventLogEntry(
        turn: 1,
        text: 'a tavern brawl broke out',
        significance: 0.7,
      ));
      // State slice ~60 chars + only one entry fits after that.
      final prompt = await assembler.assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'Hello tavern',
        maxContextTokens: 220,
      );
      expect(prompt, contains('tavern brawl broke out'));
      expect(prompt, isNot(contains('unrelated event one')));
    });

    test('vector cache reuses across calls — no double embed', () async {
      var embedCalls = 0;
      final v = Float32List.fromList(
          List<double>.filled(embeddingsDim, 0.1));
      final embedder = _CountingEmbedder({
        'context': v,
        'event one': v,
      }, () => embedCalls++);
      final assembler = PromptAssembler(embedder: embedder);
      final state = _seedState()
        ..eventLog.add(const EventLogEntry(
          turn: 0,
          text: 'event one',
          significance: 0.5,
        ));
      await assembler.assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'context',
        maxContextTokens: 8000,
      );
      final firstRunCalls = embedCalls;
      await assembler.assemble(
        cardDefinition: 'CARD',
        state: state,
        pool: NodePool(),
        firedThisTurn: const [],
        userInput: 'context',
        maxContextTokens: 8000,
      );
      // Second run: 'context' re-embedded (query is fresh each turn),
      // 'event one' served from cache.
      expect(embedCalls - firstRunCalls, 1);
    });
  });
}

class _CountingEmbedder extends Embedder {
  _CountingEmbedder(this._vectors, this._tick);
  final Map<String, Float32List> _vectors;
  final void Function() _tick;

  @override
  Future<List<Float32List>> embed(
    List<String> texts, {
    required EmbedTaskEnum task,
  }) async =>
      [for (final t in texts) _vectorFor(t)];

  @override
  Future<Float32List> embedOne(
    String text, {
    required EmbedTaskEnum task,
  }) async {
    _tick();
    return _vectorFor(text);
  }

  Float32List _vectorFor(String text) =>
      _vectors[text] ??
      Float32List.fromList(List<double>.filled(embeddingsDim, 0.0));
}
