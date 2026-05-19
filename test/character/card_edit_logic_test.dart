import 'package:cardwave/character/character.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';

CharacterCardV3 _buildCard({
  String description = '',
  String personality = '',
  List<String> alternateGreetings = const [],
  List<String> tags = const [],
  List<String> groupOnlyGreetings = const [],
}) {
  return CharacterCardV3.fromJson({
    'name': 'Test',
    'description': description,
    'personality': personality,
    'scenario': '',
    'first_mes': '',
    'mes_example': '',
    'creator_notes': '',
    'system_prompt': '',
    'post_history_instructions': '',
    'alternate_greetings': alternateGreetings,
    'tags': tags,
    'creator': '',
    'character_version': '',
    'group_only_greetings': groupOnlyGreetings,
  });
}

class _FakeBuiltinToolAppData implements BuiltinToolAppData {
  _FakeBuiltinToolAppData(this.card);

  CharacterCardV3 card;
  final List<CardEditProposal> _batch = <CardEditProposal>[];

  @override
  bool get imageToolSelfieCaptionsAllowed => false;

  @override
  Future<void> generateImage({
    required ImageGenerationModeEnum mode,
    String? freePrompt,
    String? caption,
  }) => throw UnimplementedError();

  @override
  Future<void> generateVideo({
    required VideoGenerationModeEnum mode,
    String? freePrompt,
  }) => throw UnimplementedError();

  @override
  Future<bool> confirmFetch(String url, {String? purpose}) =>
      throw UnimplementedError();

  @override
  Set<String> get usedFirstNames => throw UnimplementedError();

  @override
  Set<String> get usedLastNames => throw UnimplementedError();

  @override
  String readScalar(CardFieldScalar field) => readScalarField(card, field);

  @override
  int listSize(CardFieldList field) => listFieldOf(card, field).length;

  @override
  String readListEntry(CardFieldList field, int index) =>
      listFieldOf(card, field)[index];

  @override
  ToolResult proposeScalarSet(CardFieldScalar field, String content) {
    _batch.add(
      CardScalarSetProposal(
        field: field,
        oldValue: readScalarField(card, field),
        newValue: content,
      ),
    );
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListSet(
    CardFieldList field,
    int index,
    String content,
  ) {
    final list = listFieldOf(card, field);
    if (index < 0 || index >= list.length) {
      return ToolResult.failure(
        'index $index out of bounds (size ${list.length}).',
      );
    }
    _batch.add(
      CardListSetProposal(
        field: field,
        index: index,
        oldValue: list[index],
        newValue: normalizeFieldValue(field, content),
      ),
    );
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListAppend(CardFieldList field, String content) {
    _batch.add(
      CardListAppendProposal(
        field: field,
        newValue: normalizeFieldValue(field, content),
      ),
    );
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListDelete(CardFieldList field, int index) {
    final list = listFieldOf(card, field);
    if (index < 0 || index >= list.length) {
      return ToolResult.failure(
        'index $index out of bounds (size ${list.length}).',
      );
    }
    _batch.add(
      CardListDeleteProposal(
        field: field,
        index: index,
        oldValue: list[index],
      ),
    );
    return const ToolResult.ok();
  }

  @override
  void beginCardEditBatch() => _batch.clear();

  @override
  List<CardEditProposal> takeBatch() {
    final out = List<CardEditProposal>.from(_batch);
    _batch.clear();
    return out;
  }
}

void main() {
  group('normalizeTagEntry', () {
    test('trims outer whitespace and lowercases', () {
      expect(normalizeTagEntry('  Fantasy  '), 'fantasy');
      expect(normalizeTagEntry('ROMANCE'), 'romance');
    });

    test('leaves inner whitespace intact', () {
      expect(normalizeTagEntry('  Slow Burn  '), 'slow burn');
    });
  });

  group('CardFieldScalar.fromJsonKey', () {
    test('round-trips every value', () {
      for (final v in CardFieldScalar.values) {
        expect(CardFieldScalar.fromJsonKey(v.jsonKey), v);
      }
    });

    test('returns null for an unknown key', () {
      expect(CardFieldScalar.fromJsonKey('not_a_field'), isNull);
    });
  });

  group('CardFieldList.fromJsonKey', () {
    test('round-trips every value', () {
      for (final v in CardFieldList.values) {
        expect(CardFieldList.fromJsonKey(v.jsonKey), v);
      }
    });

    test('returns null for an unknown key', () {
      expect(CardFieldList.fromJsonKey('not_a_field'), isNull);
    });
  });

  group('proposal modality', () {
    test('scalar set: empty content → deletion, non-empty → edit', () {
      const empty = CardScalarSetProposal(
        field: CardFieldScalar.description,
        oldValue: 'old',
        newValue: '',
      );
      const filled = CardScalarSetProposal(
        field: CardFieldScalar.description,
        oldValue: '',
        newValue: 'new',
      );
      expect(empty.modality, CardEditModality.deletion);
      expect(filled.modality, CardEditModality.edit);
    });

    test('list set: empty content → deletion, non-empty → edit', () {
      const empty = CardListSetProposal(
        field: CardFieldList.tag,
        index: 0,
        oldValue: 'old',
        newValue: '',
      );
      const filled = CardListSetProposal(
        field: CardFieldList.tag,
        index: 0,
        oldValue: '',
        newValue: 'new',
      );
      expect(empty.modality, CardEditModality.deletion);
      expect(filled.modality, CardEditModality.edit);
    });
  });

  group('applyCardEditProposals', () {
    test('scalar set lands on the right field', () {
      final card = _buildCard(description: 'old');
      applyCardEditProposals(card, const [
        CardScalarSetProposal(
          field: CardFieldScalar.description,
          oldValue: 'old',
          newValue: 'new',
        ),
      ]);
      expect(card.description, 'new');
    });

    test('list set at index lands', () {
      final card = _buildCard(alternateGreetings: ['a', 'b', 'c']);
      applyCardEditProposals(card, const [
        CardListSetProposal(
          field: CardFieldList.alternateGreeting,
          index: 1,
          oldValue: 'b',
          newValue: 'B!',
        ),
      ]);
      expect(card.alternateGreetings, ['a', 'B!', 'c']);
    });

    test('list append appends', () {
      final card = _buildCard(alternateGreetings: ['a']);
      applyCardEditProposals(card, const [
        CardListAppendProposal(
          field: CardFieldList.alternateGreeting,
          newValue: 'b',
        ),
      ]);
      expect(card.alternateGreetings, ['a', 'b']);
    });

    test('tag append dedup: appending an existing value is a no-op', () {
      final card = _buildCard(tags: ['fantasy']);
      applyCardEditProposals(card, const [
        CardListAppendProposal(
          field: CardFieldList.tag,
          newValue: 'fantasy',
        ),
      ]);
      expect(card.tags, ['fantasy']);
    });

    test('list delete removes the entry', () {
      final card = _buildCard(alternateGreetings: ['a', 'b', 'c']);
      applyCardEditProposals(card, const [
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 1,
          oldValue: 'b',
        ),
      ]);
      expect(card.alternateGreetings, ['a', 'c']);
    });

    test('three identical delete(0) proposals collapse to one delete', () {
      final card = _buildCard(alternateGreetings: ['a', 'b', 'c']);
      applyCardEditProposals(card, const [
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 0,
          oldValue: 'a',
        ),
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 0,
          oldValue: 'a',
        ),
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 0,
          oldValue: 'a',
        ),
      ]);
      expect(card.alternateGreetings, ['b', 'c']);
    });

    test('multi-delete on different indices applies in descending order', () {
      final card = _buildCard(alternateGreetings: ['A', 'B', 'C', 'D']);
      applyCardEditProposals(card, const [
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 1,
          oldValue: 'B',
        ),
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 3,
          oldValue: 'D',
        ),
      ]);
      expect(card.alternateGreetings, ['A', 'C']);
    });

    test('set(0,X) + delete(0): delete wins, X is gone', () {
      final card = _buildCard(alternateGreetings: ['a', 'b']);
      applyCardEditProposals(card, const [
        CardListSetProposal(
          field: CardFieldList.alternateGreeting,
          index: 0,
          oldValue: 'a',
          newValue: 'X',
        ),
        CardListDeleteProposal(
          field: CardFieldList.alternateGreeting,
          index: 0,
          oldValue: 'a',
        ),
      ]);
      expect(card.alternateGreetings, ['b']);
    });
  });

  group('CardFieldGetTool.execute', () {
    test('happy path: returns scalar value', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(description: 'hello'),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {'field': 'description'});
      expect(result.success, isTrue);
      expect(result.data, 'hello');
    });

    test('missing field arg → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, const {});
      expect(result.success, isFalse);
    });

    test('unknown field → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {'field': 'nope'});
      expect(result.success, isFalse);
    });
  });

  group('CardFieldSetTool.execute', () {
    test('happy path: records scalar proposal', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(description: 'before'),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldSetTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'description',
        'content': 'after',
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      final proposal = batch.first as CardScalarSetProposal;
      expect(proposal.field, CardFieldScalar.description);
      expect(proposal.oldValue, 'before');
      expect(proposal.newValue, 'after');
    });

    test('missing content → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldSetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {'field': 'description'});
      expect(result.success, isFalse);
    });
  });

  group('CardFieldListGetTool.execute', () {
    test('happy path no index: returns count as string', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListGetTool(maxCallsPerTurn: 1);
      final result =
          await tool.execute(ctx, {'field': 'alternate_greeting'});
      expect(result.success, isTrue);
      expect(result.data, '2');
    });

    test('happy path with index: returns entry', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 1,
      });
      expect(result.success, isTrue);
      expect(result.data, 'b');
    });

    test('integer-valued double 2.0 is accepted and truncated', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b', 'c']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 2.0,
      });
      expect(result.success, isTrue);
      expect(result.data, 'c');
    });

    test('out-of-bounds index → failure', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 5,
      });
      expect(result.success, isFalse);
    });

    test('missing field → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListGetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, const {});
      expect(result.success, isFalse);
    });
  });

  group('CardFieldListSetTool.execute', () {
    test('happy path: records list-set proposal', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListSetTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 1,
        'content': 'B!',
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      final proposal = batch.first as CardListSetProposal;
      expect(proposal.field, CardFieldList.alternateGreeting);
      expect(proposal.index, 1);
      expect(proposal.oldValue, 'b');
      expect(proposal.newValue, 'B!');
    });

    test('out-of-bounds index → failure', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListSetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 9,
        'content': 'X',
      });
      expect(result.success, isFalse);
    });

    test('missing content → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListSetTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 0,
      });
      expect(result.success, isFalse);
    });

    test('integer-valued double 1.0 is accepted', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListSetTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 1.0,
        'content': 'B2',
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      expect((batch.first as CardListSetProposal).index, 1);
    });
  });

  group('CardFieldListAppendTool.execute', () {
    test('happy path: records append proposal', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard(tags: ['fantasy']));
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListAppendTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'tag',
        'content': '  Romance  ',
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      final proposal = batch.first as CardListAppendProposal;
      expect(proposal.field, CardFieldList.tag);
      expect(proposal.newValue, 'romance');
    });

    test('missing content → failure', () async {
      final fake = _FakeBuiltinToolAppData(_buildCard());
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListAppendTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {'field': 'tag'});
      expect(result.success, isFalse);
    });
  });

  group('CardFieldListDeleteTool.execute', () {
    test('happy path: records delete proposal', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b', 'c']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListDeleteTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 1,
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      final proposal = batch.first as CardListDeleteProposal;
      expect(proposal.index, 1);
      expect(proposal.oldValue, 'b');
    });

    test('out-of-bounds index → failure', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListDeleteTool(maxCallsPerTurn: 1);
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 7,
      });
      expect(result.success, isFalse);
    });

    test('integer-valued double 0.0 is accepted', () async {
      final fake = _FakeBuiltinToolAppData(
        _buildCard(alternateGreetings: ['a', 'b']),
      );
      final ctx = ToolCallContext(appData: fake);
      const tool = CardFieldListDeleteTool(maxCallsPerTurn: 1);
      fake.beginCardEditBatch();
      final result = await tool.execute(ctx, {
        'field': 'alternate_greeting',
        'index': 0.0,
      });
      expect(result.success, isTrue);
      final batch = fake.takeBatch();
      expect(batch, hasLength(1));
      expect((batch.first as CardListDeleteProposal).index, 0);
    });
  });
}
