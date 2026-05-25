import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lookupPath', () {
    test('accepts all 8 emotion paths for any character id', () {
      for (final e in EmotionEnum.values) {
        expect(lookupPath('character.alice.emotion.${e.name}')?.type,
            FieldType.number);
        expect(lookupPath('character.bob.emotion.${e.name}')?.type,
            FieldType.number);
      }
    });

    test('accepts all physical state paths', () {
      for (final p in PhysicalEnum.values) {
        expect(lookupPath('character.alice.physical.${p.name}')?.type,
            FieldType.number);
      }
    });

    test('accepts all relationship paths', () {
      for (final r in RelationshipEnum.values) {
        expect(lookupPath('character.alice.relationship.${r.name}')?.type,
            FieldType.number);
      }
    });

    test('accepts knowledge.value (openValue) and confidence (number)', () {
      expect(lookupPath('character.alice.knowledge.user_name.value')?.type,
          FieldType.openValue);
      expect(lookupPath('character.alice.knowledge.user_name.confidence')?.type,
          FieldType.number);
    });

    test('accepts character.<id>.flags.<name>', () {
      expect(lookupPath('character.alice.flags.hasApologized')?.type,
          FieldType.openValue);
    });

    test('accepts all fixed global scene fields', () {
      expect(lookupPath('global.scene.location')?.type, FieldType.string);
      expect(lookupPath('global.scene.timeOfDay')?.type, FieldType.string);
      expect(lookupPath('global.scene.presentEntities')?.type, FieldType.list);
      expect(lookupPath('global.scene.sensoryHooks')?.type, FieldType.list);
    });

    test('accepts global.phase, global.goal, global.turn, global.eventLog', () {
      expect(lookupPath('global.phase')?.type, FieldType.string);
      expect(lookupPath('global.goal')?.type, FieldType.string);
      expect(lookupPath('global.turn')?.type, FieldType.number);
      expect(lookupPath('global.eventLog')?.type, FieldType.list);
    });

    test('accepts global.flags.<name>', () {
      expect(lookupPath('global.flags.coffee_consumed')?.type,
          FieldType.openValue);
    });

    test('rejects unknown roots', () {
      expect(lookupPath('foo.bar'), isNull);
      expect(lookupPath('character.alice.unknown.field'), isNull);
      expect(lookupPath('global.unknown.field'), isNull);
    });

    test('rejects wrong-length paths', () {
      expect(lookupPath('character.alice.emotion'), isNull);
      expect(lookupPath('character.alice.emotion.anger.extra'), isNull);
      expect(lookupPath('global'), isNull);
    });

    test('rejects empty placeholder segment', () {
      expect(lookupPath('character..emotion.anger'), isNull);
      expect(lookupPath('global.flags.'), isNull);
    });

    test('rejects unknown emotion names', () {
      expect(lookupPath('character.alice.emotion.envy'), isNull);
    });
  });
}
