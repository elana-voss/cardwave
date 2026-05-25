import 'dart:convert';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TrackedValue round-trip', () {
    final original = TrackedValue(value: 0.42, lockoutTurnsRemaining: 2);
    final json = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    final restored = TrackedValue.fromJson(json);
    expect(restored.value, 0.42);
    expect(restored.lockoutTurnsRemaining, 2);
  });

  test('Scene round-trip', () {
    final original = Scene(
      location: 'tavern',
      timeOfDay: 'evening',
      presentEntities: ['alice', 'bob'],
      sensoryHooks: ['smoke', 'firelight'],
    );
    final restored = Scene.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.location, 'tavern');
    expect(restored.timeOfDay, 'evening');
    expect(restored.presentEntities, ['alice', 'bob']);
    expect(restored.sensoryHooks, ['smoke', 'firelight']);
  });

  test('EventLogEntry round-trip', () {
    const original = EventLogEntry(
      turn: 12,
      text: 'Alice drew her blade.',
      significance: 0.8,
    );
    final restored = EventLogEntry.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.turn, 12);
    expect(restored.text, 'Alice drew her blade.');
    expect(restored.significance, 0.8);
  });

  test('KnowledgeRecord round-trip', () {
    const original = KnowledgeRecord(
      topic: 'user_name',
      value: 'Alice',
      confidence: 0.9,
    );
    final restored = KnowledgeRecord.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.topic, 'user_name');
    expect(restored.value, 'Alice');
    expect(restored.confidence, 0.9);
  });

  test('CharacterState default-constructed has all enums initialized to 0', () {
    final cs = CharacterState();
    for (final e in EmotionEnum.values) {
      expect(cs.emotion[e]?.value, 0.0, reason: 'emotion.$e not initialized');
    }
    for (final p in PhysicalEnum.values) {
      expect(cs.physical[p]?.value, 0.0, reason: 'physical.$p not initialized');
    }
    for (final r in RelationshipEnum.values) {
      expect(cs.relationship[r]?.value, 0.0, reason: 'relationship.$r not initialized');
    }
    expect(cs.knowledge, isEmpty);
    expect(cs.flags, isEmpty);
  });

  test('CharacterState round-trip with non-default values', () {
    final original = CharacterState();
    original.emotion[EmotionEnum.anger]!.value = 0.7;
    original.emotion[EmotionEnum.fear]!.lockoutTurnsRemaining = 2;
    original.physical[PhysicalEnum.tiredness]!.value = 0.4;
    original.relationship[RelationshipEnum.trust]!.value = 0.6;
    original.knowledge['user_name'] = const KnowledgeRecord(
      topic: 'user_name',
      value: 'Alice',
      confidence: 0.9,
    );
    original.flags['hasApologized'] = true;

    final restored = CharacterState.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.emotion[EmotionEnum.anger]!.value, 0.7);
    expect(restored.emotion[EmotionEnum.fear]!.lockoutTurnsRemaining, 2);
    expect(restored.physical[PhysicalEnum.tiredness]!.value, 0.4);
    expect(restored.relationship[RelationshipEnum.trust]!.value, 0.6);
    expect(restored.knowledge['user_name']!.value, 'Alice');
    expect(restored.flags['hasApologized'], true);
  });

  test('SessionState round-trip with two characters', () {
    final original = SessionState(
      currentGoal: 'find the missing letter',
      currentPhase: PhaseEnum.sequel,
      turn: 7,
    );
    original.characters['alice'] = CharacterState();
    original.characters['alice']!.emotion[EmotionEnum.anger]!.value = 0.5;
    original.characters['bob'] = CharacterState();
    original.characters['bob']!.emotion[EmotionEnum.fear]!.value = 0.3;
    original.eventLog.add(const EventLogEntry(
      turn: 5,
      text: 'They argued at the gate.',
      significance: 0.6,
    ));
    original.currentScene.location = 'gate';
    original.currentScene.timeOfDay = 'dawn';
    original.flags['gateLocked'] = true;

    final restored = SessionState.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.currentGoal, 'find the missing letter');
    expect(restored.currentPhase, PhaseEnum.sequel);
    expect(restored.turn, 7);
    expect(restored.characters.keys, containsAll(['alice', 'bob']));
    expect(restored.characters['alice']!.emotion[EmotionEnum.anger]!.value, 0.5);
    expect(restored.characters['bob']!.emotion[EmotionEnum.fear]!.value, 0.3);
    expect(restored.eventLog, hasLength(1));
    expect(restored.eventLog.first.text, 'They argued at the gate.');
    expect(restored.currentScene.location, 'gate');
    expect(restored.flags['gateLocked'], true);
  });
}
