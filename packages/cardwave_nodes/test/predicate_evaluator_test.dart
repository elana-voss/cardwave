import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

SessionState _seedState() {
  final state = SessionState(
    currentGoal: 'find the letter',
    turn: 7,
  );
  state.characters['alice'] = CharacterState();
  state.characters['alice']!.emotion[EmotionEnum.anger]!.value = 0.7;
  state.characters['alice']!.physical[PhysicalEnum.tiredness]!.value = 0.3;
  state.characters['alice']!.relationship[RelationshipEnum.trust]!.value = 0.6;
  state.characters['alice']!.knowledge['user_name'] = const KnowledgeRecord(
    topic: 'user_name',
    value: 'Alice',
    confidence: 0.9,
  );
  state.characters['alice']!.flags['hasApologized'] = true;
  state.currentScene.location = 'tavern';
  state.currentScene.timeOfDay = 'evening';
  state.flags['gateLocked'] = false;
  return state;
}

bool _eval(String source, SessionState state) =>
    evaluatePredicate(parsePredicate(source), state);

void main() {
  group('literal evaluation', () {
    final state = _seedState();
    test('true', () => expect(_eval('true', state), isTrue));
    test('false', () => expect(_eval('false', state), isFalse));
    test('number truthy', () => expect(_eval('1', state), isTrue));
    test('zero falsy', () => expect(_eval('0', state), isFalse));
    test('non-empty string truthy',
        () => expect(_eval('"x"', state), isTrue));
  });

  group('field resolution', () {
    final state = _seedState();
    test('emotion path',
        () => expect(_eval('character.alice.emotion.anger > 0.5', state), isTrue));
    test('physical path',
        () => expect(_eval('character.alice.physical.tiredness < 0.5', state), isTrue));
    test('relationship path',
        () => expect(_eval('character.alice.relationship.trust >= 0.6', state), isTrue));
    test('knowledge value',
        () => expect(_eval('character.alice.knowledge.user_name.value == "Alice"', state), isTrue));
    test('knowledge confidence',
        () => expect(_eval('character.alice.knowledge.user_name.confidence > 0.8', state), isTrue));
    test('character flag (truthy)',
        () => expect(_eval('character.alice.flags.hasApologized', state), isTrue));
    test('global scene location',
        () => expect(_eval('global.scene.location == "tavern"', state), isTrue));
    test('global goal',
        () => expect(_eval('global.goal == "find the letter"', state), isTrue));
    test('global turn',
        () => expect(_eval('global.turn == 7', state), isTrue));
    test('global flag (falsy false bool)',
        () => expect(_eval('global.flags.gateLocked', state), isFalse));
    test('missing character returns null → falsy',
        () => expect(_eval('character.bob.emotion.anger', state), isFalse));
    test('missing flag key returns null → falsy',
        () => expect(_eval('character.alice.flags.never_set', state), isFalse));
  });

  group('boolean composition', () {
    final state = _seedState();
    test('AND both true',
        () => expect(_eval(
            'character.alice.emotion.anger > 0.5 AND '
            'global.scene.location == "tavern"',
            state), isTrue));
    test('AND one false',
        () => expect(_eval(
            'character.alice.emotion.anger > 0.5 AND '
            'global.scene.location == "kitchen"',
            state), isFalse));
    test('OR one true',
        () => expect(_eval(
            'character.alice.emotion.anger < 0.1 OR '
            'global.scene.location == "tavern"',
            state), isTrue));
    test('OR both false',
        () => expect(_eval('false OR false', state), isFalse));
    test('NOT flips',
        () => expect(_eval('NOT character.alice.flags.hasApologized', state), isFalse));
    test('NOT NOT roundtrip',
        () => expect(_eval('NOT NOT true', state), isTrue));
  });

  group('comparisons', () {
    final state = _seedState();
    test('== num', () => expect(_eval('1 == 1', state), isTrue));
    test('== int double', () => expect(_eval('1 == 1.0', state), isTrue));
    test('!= num', () => expect(_eval('1 != 2', state), isTrue));
    test('== string', () => expect(_eval('"x" == "x"', state), isTrue));
    test('< string lex',
        () => expect(_eval('"apple" < "banana"', state), isTrue));
    test('>= num', () => expect(_eval('5 >= 5', state), isTrue));
    test('mixed types comparison falls through to false',
        () => expect(_eval('1 < "a"', state), isFalse));
  });

  group('truthy coercion', () {
    final state = _seedState();
    test('non-empty list (presentEntities seeded empty)',
        () => expect(_eval('global.scene.presentEntities', state), isFalse));
    test('non-empty string field',
        () => expect(_eval('global.scene.location', state), isTrue));
    test('zero turn case', () {
      final s = SessionState();
      expect(_eval('global.turn', s), isFalse);
    });
  });
}
