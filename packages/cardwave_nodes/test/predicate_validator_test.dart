import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid predicate has no errors', () {
    final ast = parsePredicate('character.alice.emotion.anger > 0.5');
    final errors = validatePredicate(ast);
    expect(errors, isEmpty);
  });

  test('unknown field is reported', () {
    final ast = parsePredicate('character.alice.foo.bar == 1');
    final errors = validatePredicate(ast);
    expect(errors, hasLength(1));
    expect(errors.first.path, 'character.alice.foo.bar');
  });

  test('multiple unknown fields all reported', () {
    final ast = parsePredicate(
      'character.alice.foo.bar > 1 AND global.unknown_field == "x"',
    );
    final errors = validatePredicate(ast);
    expect(errors, hasLength(2));
    expect(errors.map((e) => e.path),
        containsAll(['character.alice.foo.bar', 'global.unknown_field']));
  });

  test('NOT and parenthesized sub-expressions are walked', () {
    final ast = parsePredicate(
      '(NOT global.broken_flag) OR character.alice.bad.path > 0',
    );
    final errors = validatePredicate(ast);
    expect(errors, hasLength(2));
  });

  test('literals are not validated', () {
    final ast = parsePredicate('1 == 1 AND "x" == "y"');
    final errors = validatePredicate(ast);
    expect(errors, isEmpty);
  });

  test('all schema-valid emotion paths pass', () {
    for (final e in EmotionEnum.values) {
      final ast = parsePredicate('character.alice.emotion.${e.name} > 0');
      expect(validatePredicate(ast), isEmpty);
    }
  });

  test('all global paths pass', () {
    for (final source in [
      'global.scene.location == "x"',
      'global.scene.timeOfDay == "x"',
      'global.phase == "scene"',
      'global.goal == "x"',
      'global.turn > 0',
      'global.flags.anything == 1',
    ]) {
      expect(validatePredicate(parsePredicate(source)), isEmpty,
          reason: 'failed for: $source');
    }
  });
}
