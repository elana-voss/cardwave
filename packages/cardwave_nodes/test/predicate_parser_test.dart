import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('literals', () {
    test('number', () {
      final ast = parsePredicate('0.5');
      expect(ast, isA<LiteralNode>());
      expect((ast as LiteralNode).value, 0.5);
    });

    test('string', () {
      final ast = parsePredicate('"hello"');
      expect((ast as LiteralNode).value, 'hello');
    });

    test('bool true', () {
      final ast = parsePredicate('true');
      expect((ast as LiteralNode).value, true);
    });

    test('bool false', () {
      final ast = parsePredicate('false');
      expect((ast as LiteralNode).value, false);
    });
  });

  group('field reference', () {
    test('dotted path', () {
      final ast = parsePredicate('character.alice.emotion.anger');
      expect((ast as FieldRefNode).path, 'character.alice.emotion.anger');
    });
  });

  group('comparison', () {
    test('greater than', () {
      final ast = parsePredicate('character.alice.emotion.anger > 0.5');
      expect(ast, isA<ComparisonNode>());
      final cmp = ast as ComparisonNode;
      expect(cmp.op, ComparisonOp.gt);
    });

    test('all six operators parse', () {
      for (final pair in [
        ('==', ComparisonOp.eq),
        ('!=', ComparisonOp.ne),
        ('<', ComparisonOp.lt),
        ('<=', ComparisonOp.le),
        ('>', ComparisonOp.gt),
        ('>=', ComparisonOp.ge),
      ]) {
        final ast =
            parsePredicate('character.alice.emotion.anger ${pair.$1} 0.5');
        expect((ast as ComparisonNode).op, pair.$2);
      }
    });
  });

  group('boolean composition', () {
    test('AND', () {
      final ast = parsePredicate('true AND false');
      expect(ast, isA<AndNode>());
    });

    test('OR', () {
      final ast = parsePredicate('true OR false');
      expect(ast, isA<OrNode>());
    });

    test('NOT', () {
      final ast = parsePredicate('NOT true');
      expect(ast, isA<NotNode>());
    });

    test('AND binds tighter than OR', () {
      // true OR false AND false  →  true OR (false AND false)
      final ast = parsePredicate('true OR false AND false');
      expect(ast, isA<OrNode>());
      expect((ast as OrNode).right, isA<AndNode>());
    });

    test('parentheses override precedence', () {
      // (true OR false) AND false
      final ast = parsePredicate('(true OR false) AND false');
      expect(ast, isA<AndNode>());
      expect((ast as AndNode).left, isA<OrNode>());
    });

    test('NOT binds to atom, not full expression', () {
      // NOT true AND false  →  (NOT true) AND false
      final ast = parsePredicate('NOT true AND false');
      expect(ast, isA<AndNode>());
      expect((ast as AndNode).left, isA<NotNode>());
    });
  });

  group('spec examples', () {
    test('emotion comparison', () {
      parsePredicate('character.alice.emotion.anger > 0.5');
    });

    test('AND with mixed operators', () {
      parsePredicate(
        'character.alice.emotion.trust < 0.3 '
        'AND global.scene.location == "private"',
      );
    });

    test('parenthesized OR with NOT', () {
      parsePredicate(
        '(character.alice.physical.tiredness > 0.7) OR '
        '(global.scene.timeOfDay == "late_night" AND '
        'NOT global.flags.coffee_consumed)',
      );
    });
  });

  group('parse errors', () {
    test('unexpected character', () {
      expect(() => parsePredicate('a @ b'),
          throwsA(isA<PredicateParseException>()));
    });

    test('unterminated string', () {
      expect(() => parsePredicate('"hello'),
          throwsA(isA<PredicateParseException>()));
    });

    test('missing closing paren', () {
      expect(() => parsePredicate('(true AND false'),
          throwsA(isA<PredicateParseException>()));
    });

    test('trailing tokens', () {
      expect(() => parsePredicate('true false'),
          throwsA(isA<PredicateParseException>()));
    });
  });
}
