import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as gk;
import 'package:schemantic/schemantic.dart';

/// Scripted [LlmRunner]: returns (or throws) queued results in order,
/// overriding [completeStructured] so genkit is never reached. The dummy
/// model/genkit satisfy the parent constructor but are never used.
class _FakeLlmRunner extends LlmRunner {
  _FakeLlmRunner(this._queue)
      : super(
          model: gk.Model<Object?>(
            name: 'fake-director',
            fn: (_, _) =>
                throw UnimplementedError('fake runner: fn unused'),
          ),
          genkit: gk.Genkit(isDevEnv: false),
        );

  final List<Object> _queue;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async {
    calls++;
    final next = _queue.removeAt(0);
    if (next is Exception) throw next;
    return next as Map<String, dynamic>;
  }
}

SessionState _seedState() {
  final state = SessionState();
  state.characters['alice'] = CharacterState();
  return state;
}

void main() {
  group('DirectorRunner.run', () {
    test('returns parsed output on first valid response', () async {
      final fake = _FakeLlmRunner([
        <String, dynamic>{
          'directive_lines': ['She is still visibly cool toward him.'],
        },
      ]);
      final director = DirectorRunner(runner: fake);
      final output = await director.run(
        state: _seedState(),
        actorLastOutput: '',
        userInput: 'hi',
      );
      expect(fake.calls, 1);
      expect(output.directiveLines, ['She is still visibly cool toward him.']);
    });

    test('retries on validation failure and succeeds on next attempt',
        () async {
      // First response has an out-of-bounds delta; second is valid.
      final fake = _FakeLlmRunner([
        <String, dynamic>{
          'emotion_deltas': {
            'alice': {'anger': 5.0},
          },
        },
        <String, dynamic>{
          'emotion_deltas': {
            'alice': {'anger': 0.3},
          },
        },
      ]);
      final director = DirectorRunner(runner: fake);
      final output = await director.run(
        state: _seedState(),
        actorLastOutput: '',
        userInput: 'hi',
      );
      expect(fake.calls, 2);
      expect(output.emotionDeltas['alice']?[EmotionEnum.anger], 0.3);
    });

    test('retries on LLM exception and succeeds on next attempt', () async {
      final fake = _FakeLlmRunner([
        Exception('network blip'),
        <String, dynamic>{
          'directive_lines': ['ok'],
        },
      ]);
      final director = DirectorRunner(runner: fake);
      final output = await director.run(
        state: _seedState(),
        actorLastOutput: '',
        userInput: 'hi',
      );
      expect(fake.calls, 2);
      expect(output.directiveLines, ['ok']);
    });

    test('falls back to empty DirectorOutput after retries exhausted',
        () async {
      // All attempts fail validation (out-of-bounds significance).
      final fake = _FakeLlmRunner([
        <String, dynamic>{
          'event_log_append': [
            {'text': 'x', 'significance': 5.0},
          ],
        },
        <String, dynamic>{
          'event_log_append': [
            {'text': 'y', 'significance': 5.0},
          ],
        },
        <String, dynamic>{
          'event_log_append': [
            {'text': 'z', 'significance': 5.0},
          ],
        },
      ]);
      final director = DirectorRunner(runner: fake, maxRetries: 2);
      final output = await director.run(
        state: _seedState(),
        actorLastOutput: '',
        userInput: 'hi',
      );
      expect(fake.calls, 3);
      expect(output.directiveLines, isEmpty);
      expect(output.eventLogAppend, isEmpty);
      expect(output.emotionDeltas, isEmpty);
    });

    test('maxRetries 0 makes one call only', () async {
      final fake = _FakeLlmRunner([Exception('boom')]);
      final director = DirectorRunner(runner: fake, maxRetries: 0);
      await director.run(
        state: _seedState(),
        actorLastOutput: '',
        userInput: 'hi',
      );
      expect(fake.calls, 1);
    });
  });

  group('buildDirectorPrompt', () {
    test('includes preamble, state JSON, actor output, user input', () {
      final state = _seedState();
      state.currentGoal = 'find the missing letter';
      final prompt = buildDirectorPrompt(
        state: state,
        actorLastOutput: '"I don\'t know where it is."',
        userInput: 'Are you sure?',
      );
      expect(prompt, contains('DIRECTOR'));
      expect(prompt, contains('find the missing letter'));
      expect(prompt, contains('"I don\'t know where it is."'));
      expect(prompt, contains('Are you sure?'));
    });
  });
}
