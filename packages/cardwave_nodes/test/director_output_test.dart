import 'dart:convert';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

Node _validNode({
  String id = 'g1',
  double triggerProb = 0.5,
  String predicate = 'true',
}) =>
    Node(
      id: id,
      origin: NodeOriginEnum.generated,
      type: NodeTypeEnum.event,
      triggerProb: triggerProb,
      delay: 0,
      cooldown: 0,
      sticky: 0,
      alive: 10,
      scope: NodeScopeEnum.session,
      predicate: predicate,
      narrativePayload: 'something happens',
    );

void main() {
  group('JSON round-trip', () {
    test('empty DirectorOutput round-trips', () {
      final original = DirectorOutput();
      final restored = DirectorOutput.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.emotionDeltas, isEmpty);
      expect(restored.directiveLines, isEmpty);
      expect(restored.generatedNodes, isEmpty);
      expect(restored.eventLogAppend, isEmpty);
    });

    test('full DirectorOutput round-trips with nested enum-keyed deltas', () {
      final original = DirectorOutput(
        emotionDeltas: {
          'alice': {EmotionEnum.anger: 0.2, EmotionEnum.joy: -0.1},
        },
        physicalDeltas: {
          'alice': {PhysicalEnum.tiredness: 0.05},
        },
        relationshipDeltas: {
          'alice': {RelationshipEnum.trust: 0.03},
        },
        flagSet: {'hasApologized': true, 'drinkCount': 3},
        knowledgeWrites: {
          'alice': [
            const KnowledgeRecord(
              topic: 'user_name',
              value: 'Alice',
              confidence: 0.9,
            ),
          ],
        },
        directiveLines: ['She is still visibly cool toward him.'],
        generatedNodes: [_validNode()],
        eventLogAppend: [
          const EventLogAppend(text: 'They argued.', significance: 0.6),
        ],
      );
      final restored = DirectorOutput.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.emotionDeltas['alice']?[EmotionEnum.anger], 0.2);
      expect(restored.physicalDeltas['alice']?[PhysicalEnum.tiredness], 0.05);
      expect(restored.relationshipDeltas['alice']?[RelationshipEnum.trust],
          0.03);
      expect(restored.flagSet['hasApologized'], true);
      expect(restored.knowledgeWrites['alice']!.first.value, 'Alice');
      expect(restored.directiveLines, hasLength(1));
      expect(restored.generatedNodes, hasLength(1));
      expect(restored.eventLogAppend.first.text, 'They argued.');
    });

    test('EventLogAppend round-trips', () {
      const original = EventLogAppend(text: 'A thing.', significance: 0.4);
      final restored = EventLogAppend.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.text, 'A thing.');
      expect(restored.significance, 0.4);
    });
  });

  group('validator', () {
    test('empty output is valid', () {
      expect(validateDirectorOutput(DirectorOutput()), isEmpty);
    });

    test('emotion delta in bounds passes', () {
      final out = DirectorOutput(emotionDeltas: {
        'alice': {EmotionEnum.anger: 0.5},
      });
      expect(validateDirectorOutput(out), isEmpty);
    });

    test('emotion delta above 1.0 reported', () {
      final out = DirectorOutput(emotionDeltas: {
        'alice': {EmotionEnum.anger: 1.5},
      });
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'emotionDeltas.alice.anger');
      expect(errors.first.message, contains('out of bounds'));
    });

    test('emotion delta below -1.0 reported', () {
      final out = DirectorOutput(emotionDeltas: {
        'alice': {EmotionEnum.joy: -2.0},
      });
      expect(validateDirectorOutput(out), hasLength(1));
    });

    test('physical and relationship deltas validated the same way', () {
      final out = DirectorOutput(
        physicalDeltas: {'alice': {PhysicalEnum.pain: 5.0}},
        relationshipDeltas: {'alice': {RelationshipEnum.trust: -1.5}},
      );
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(2));
      expect(errors.map((e) => e.path),
          containsAll([
            'physicalDeltas.alice.pain',
            'relationshipDeltas.alice.trust',
          ]));
    });

    test('knowledge record with empty topic reported', () {
      final out = DirectorOutput(knowledgeWrites: {
        'alice': [
          const KnowledgeRecord(topic: '', value: 'x', confidence: 0.5),
        ],
      });
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'knowledgeWrites.alice[0].topic');
    });

    test('knowledge record with bad confidence reported', () {
      final out = DirectorOutput(knowledgeWrites: {
        'alice': [
          const KnowledgeRecord(topic: 't', value: 'x', confidence: 1.5),
        ],
      });
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'knowledgeWrites.alice[0].confidence');
    });

    test('event log entry with empty text reported', () {
      final out = DirectorOutput(eventLogAppend: [
        const EventLogAppend(text: '', significance: 0.5),
      ]);
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'eventLogAppend[0].text');
    });

    test('event log entry with bad significance reported', () {
      final out = DirectorOutput(eventLogAppend: [
        const EventLogAppend(text: 't', significance: -0.1),
      ]);
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'eventLogAppend[0].significance');
    });

    test('generated node with triggerProb > 1.0 reported', () {
      final out = DirectorOutput(generatedNodes: [
        _validNode(id: 'a', triggerProb: 1.5),
      ]);
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'generatedNodes[0].triggerProb');
    });

    test('generated node with unparseable predicate reported', () {
      final out = DirectorOutput(generatedNodes: [
        _validNode(predicate: 'a @ b'),
      ]);
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'generatedNodes[0].predicate');
      expect(errors.first.message, contains('parse error'));
    });

    test('generated node with unknown field in predicate reported', () {
      final out = DirectorOutput(generatedNodes: [
        _validNode(predicate: 'character.alice.foo.bar == 1'),
      ]);
      final errors = validateDirectorOutput(out);
      expect(errors, hasLength(1));
      expect(errors.first.path, 'generatedNodes[0].predicate');
      expect(errors.first.message, contains('unknown field path'));
    });

    test('multiple violations all reported', () {
      final out = DirectorOutput(
        emotionDeltas: {
          'alice': {EmotionEnum.anger: 2.0, EmotionEnum.fear: -3.0},
        },
        eventLogAppend: [
          const EventLogAppend(text: '', significance: 5.0),
        ],
      );
      expect(validateDirectorOutput(out), hasLength(4));
    });
  });
}
