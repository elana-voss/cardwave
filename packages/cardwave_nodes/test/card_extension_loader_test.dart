import 'dart:convert';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validNodeJson({
  String id = 'n1',
  String predicate = 'true',
  String type = 'environmental',
}) =>
    <String, dynamic>{
      'id': id,
      'origin': 'authored',
      'type': type,
      'trigger_prob': 0.5,
      'delay': 0,
      'cooldown': 0,
      'sticky': 0,
      'alive': -1,
      'scope': 'session',
      'predicate': predicate,
      'narrative_payload': 'something happens',
      'effects': <String, dynamic>{},
      'spawns': <dynamic>[],
      'current_delay': 0,
      'current_cooldown': 0,
      'current_sticky': 0,
      'current_alive': -1,
    };

void main() {
  group('loadCardNodesExtension', () {
    test('empty JSON produces a default extension and no errors', () {
      final result = loadCardNodesExtension(<String, dynamic>{});
      expect(result.errors, isEmpty);
      expect(result.extension.authoredNodes, isEmpty);
      expect(result.extension.emotionBaseline, isEmpty);
      expect(result.extension.initialGoal, '');
      expect(result.extension.initialScene, isNull);
    });

    test('valid extension round-trips through JSON', () {
      final original = CardNodesExtension(
        authoredNodes: [
          Node.fromJson(_validNodeJson(id: 'rain', predicate: 'true')),
        ],
        emotionBaseline: {EmotionEnum.trust: 0.3, EmotionEnum.joy: 0.5},
        initialGoal: 'find the letter',
        initialScene: Scene(
          location: 'tavern',
          timeOfDay: 'evening',
        ),
      );
      final json = jsonDecode(jsonEncode(original.toJson()))
          as Map<String, dynamic>;
      final result = loadCardNodesExtension(json);
      expect(result.errors, isEmpty);
      expect(result.extension.authoredNodes, hasLength(1));
      expect(result.extension.authoredNodes.first.id, 'rain');
      expect(result.extension.emotionBaseline[EmotionEnum.trust], 0.3);
      expect(result.extension.initialGoal, 'find the letter');
      expect(result.extension.initialScene?.location, 'tavern');
    });

    test('authored node with unparseable predicate is reported', () {
      final json = <String, dynamic>{
        'authored_nodes': [_validNodeJson(predicate: 'a @ b')],
      };
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.path, 'authoredNodes[0].predicate');
      expect(result.errors.first.message, contains('parse error'));
    });

    test('authored node with unknown field in predicate is reported', () {
      final json = <String, dynamic>{
        'authored_nodes': [
          _validNodeJson(predicate: 'character.alice.foo.bar > 0'),
        ],
      };
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.path, 'authoredNodes[0].predicate');
      expect(result.errors.first.message, contains('unknown field path'));
    });

    test('emotion baseline above 1.0 is reported', () {
      final json = <String, dynamic>{
        'emotion_baseline': {'anger': 1.5},
      };
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.path, 'emotionBaseline.anger');
      expect(result.errors.first.message, contains('out of bounds'));
    });

    test('emotion baseline below 0.0 is reported', () {
      final json = <String, dynamic>{
        'emotion_baseline': {'fear': -0.1},
      };
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.path, 'emotionBaseline.fear');
    });

    test('multiple problems all reported, well-formed parts still loaded',
        () {
      final json = <String, dynamic>{
        'authored_nodes': [
          _validNodeJson(id: 'good', predicate: 'true'),
          _validNodeJson(id: 'bad-parse', predicate: 'a @ b'),
          _validNodeJson(
            id: 'bad-field',
            predicate: 'character.alice.foo == 1',
          ),
        ],
        'emotion_baseline': {'anger': 2.0},
        'initial_goal': 'do the thing',
      };
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(3));
      expect(result.extension.authoredNodes, hasLength(3));
      expect(result.extension.initialGoal, 'do the thing');
    });

    test('mis-shaped JSON returns default extension + single root error',
        () {
      // `authored_nodes` is supposed to be a list; here it is a number.
      final json = <String, dynamic>{'authored_nodes': 42};
      final result = loadCardNodesExtension(json);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.path, 'root');
      expect(result.errors.first.message, contains('parse failed'));
      expect(result.extension.authoredNodes, isEmpty);
    });
  });
}
