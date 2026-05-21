import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:schemantic/schemantic.dart';

/// Returns a fixed structured response and counts how many times it was asked,
/// so a test can assert the detector skipped the model call entirely.
class _FakeLlmRunner extends LlmRunner {
  _FakeLlmRunner(this.response)
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  final Map<String, dynamic> response;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async {
    calls++;
    return response;
  }
}

/// Stands in for the model returning nothing parseable — `completeStructured`'s
/// real failure mode.
class _ThrowingRunner extends LlmRunner {
  _ThrowingRunner()
    : super(
        model: gk.Model<Object?>(
          name: 'fake-model',
          fn: (_, _) => throw UnimplementedError('fake runner: fn unused'),
        ),
        genkit: gk.Genkit(isDevEnv: false),
      );

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async => throw Exception('no parseable structured output');
}

StoryEvent _event(String id, int recordedAt, String text) =>
    StoryEvent(id: id, recordedAt: recordedAt, text: text, contextualPrefix: '');

void main() {
  test('a later event supersedes an earlier one and a link is recorded', () async {
    final e1 = _event('e1', 1, 'the king rules');
    final e2 = _event('e2', 2, 'a feast is held');
    final e3 = _event('e3', 3, 'the king is slain');
    final graph = MemoryGraph(events: [e1, e2, e3]);
    final runner = _FakeLlmRunner(<String, dynamic>{
      'supersedes': [
        <String, dynamic>{'earlier': 1, 'later': 3},
      ],
      'links': [
        <String, dynamic>{'from': 3, 'to': 1},
      ],
    });

    final changed = await EventRelationDetector(runner: runner).detect(graph);

    expect(changed, isTrue);
    expect(
      e1.supersededAt,
      e3.recordedAt,
      reason: 'the slain-king fact supersedes the ruling-king fact',
    );
    expect(
      e1.supersededBy,
      e3.id,
      reason: 'the overriding event is recorded so reconcile can reverse it',
    );
    expect(e2.supersededAt, isNull, reason: 'the unrelated fact is untouched');
    expect(e3.linkedEventIds, ['e1'], reason: 'the later event links back');
  });

  test('detection is skipped when too few live events exist', () async {
    final graph = MemoryGraph(events: [_event('e1', 1, 'a lonely fact')]);
    final runner = _FakeLlmRunner(const <String, dynamic>{
      'supersedes': <Object?>[],
      'links': <Object?>[],
    });

    final changed = await EventRelationDetector(runner: runner).detect(graph);

    expect(changed, isFalse);
    expect(runner.calls, 0, reason: 'one event has nothing to relate, so no call');
  });

  test('backward, out-of-range, and self pairs are ignored', () async {
    final e1 = _event('e1', 1, 'a');
    final e2 = _event('e2', 2, 'b');
    final graph = MemoryGraph(events: [e1, e2]);
    final runner = _FakeLlmRunner(<String, dynamic>{
      'supersedes': [
        <String, dynamic>{'earlier': 2, 'later': 1}, // a later fact can't be earlier
        <String, dynamic>{'earlier': 1, 'later': 9}, // 9 is not a fact number
      ],
      'links': [
        <String, dynamic>{'from': 1, 'to': 1}, // a fact can't link to itself
        <String, dynamic>{'from': 1, 'to': 7}, // 7 is not a fact number
      ],
    });

    final changed = await EventRelationDetector(runner: runner).detect(graph);

    expect(changed, isFalse);
    expect(e1.supersededAt, isNull);
    expect(e2.supersededAt, isNull);
    expect(e1.linkedEventIds, isEmpty);
  });

  test('a failed model call leaves relations unchanged, no throw', () async {
    final e1 = _event('e1', 1, 'a');
    final e2 = _event('e2', 2, 'b');
    final graph = MemoryGraph(events: [e1, e2]);

    final changed = await EventRelationDetector(runner: _ThrowingRunner()).detect(graph);

    expect(changed, isFalse);
    expect(e1.supersededAt, isNull);
    expect(e1.linkedEventIds, isEmpty);
  });

  test('re-running records no duplicate link', () async {
    final e1 = _event('e1', 1, 'a sword is forged');
    final e2 = _event('e2', 2, 'the sword returns');
    final graph = MemoryGraph(events: [e1, e2]);
    final runner = _FakeLlmRunner(<String, dynamic>{
      'supersedes': <Object?>[],
      'links': [
        <String, dynamic>{'from': 2, 'to': 1},
      ],
    });
    final detector = EventRelationDetector(runner: runner);

    expect(await detector.detect(graph), isTrue);
    expect(e2.linkedEventIds, ['e1']);
    // Both events stay live, so the second pass runs again and returns the same
    // link — already present, so nothing changes.
    expect(await detector.detect(graph), isFalse);
    expect(e2.linkedEventIds, ['e1'], reason: 'the link is not duplicated');
  });
}
