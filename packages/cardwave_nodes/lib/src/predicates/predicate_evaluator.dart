import 'package:cardwave_nodes/src/models/character_state.dart';
import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:cardwave_nodes/src/models/scene.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/predicates/namespace_segments.dart';
import 'package:cardwave_nodes/src/predicates/predicate_ast.dart';

/// Evaluates [predicate] against [state]. The top-level expression must
/// be coercible to a boolean (a literal, a field reference, a
/// comparison, or a boolean combination thereof).
bool evaluatePredicate(PredicateNode predicate, SessionState state) {
  return _coerceBool(_evaluate(predicate, state));
}

Object? _evaluate(PredicateNode node, SessionState state) {
  return switch (node) {
    AndNode(:final left, :final right) =>
        _coerceBool(_evaluate(left, state)) &&
            _coerceBool(_evaluate(right, state)),
    OrNode(:final left, :final right) =>
        _coerceBool(_evaluate(left, state)) ||
            _coerceBool(_evaluate(right, state)),
    NotNode(:final operand) => !_coerceBool(_evaluate(operand, state)),
    ComparisonNode(:final left, :final op, :final right) =>
        _compare(_evaluate(left, state), op, _evaluate(right, state)),
    LiteralNode(:final value) => value,
    FieldRefNode(:final segments) => _resolveSegments(state, segments),
  };
}

/// Truthy rule: bool as-is; null and 0 are false; non-empty strings,
/// collections, and maps are true; any other object is true.
bool _coerceBool(Object? value) {
  if (value is bool) return value;
  if (value == null) return false;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

bool _compare(Object? left, ComparisonOp op, Object? right) {
  return switch (op) {
    ComparisonOp.eq => left == right,
    ComparisonOp.ne => left != right,
    ComparisonOp.lt => _lessThan(left, right),
    ComparisonOp.le => _lessThan(left, right) || left == right,
    ComparisonOp.gt => _lessThan(right, left),
    ComparisonOp.ge => _lessThan(right, left) || left == right,
  };
}

bool _lessThan(Object? a, Object? b) {
  if (a is num && b is num) return a < b;
  // String has no `<` operator — `compareTo` is the only way to order
  // strings lexicographically.
  // ignore: qcheck/avoid_unnecessary_compare_to
  if (a is String && b is String) return a.compareTo(b) < 0;
  return false;
}

// Name → enum lookups built once. Replaces per-evaluation linear scans
// through `EnumName.values`.
final Map<String, EmotionEnum> _emotionByName = {
  for (final v in EmotionEnum.values) v.name: v,
};
final Map<String, PhysicalEnum> _physicalByName = {
  for (final v in PhysicalEnum.values) v.name: v,
};
final Map<String, RelationshipEnum> _relationshipByName = {
  for (final v in RelationshipEnum.values) v.name: v,
};

Object? _resolveSegments(SessionState state, List<String> segments) {
  return switch (segments) {
    [NamespaceSegments.character, final id, ...final rest] =>
        _resolveCharacterArea(state, id, rest),
    [NamespaceSegments.global, ...final rest] =>
        _resolveGlobalArea(state, rest),
    _ => null,
  };
}

Object? _resolveCharacterArea(
  SessionState state,
  String id,
  List<String> rest,
) {
  final character = state.characters[id];
  if (character == null) return null;
  return switch (rest) {
    [NamespaceSegments.emotion, final name] =>
        _emotionValue(character, name),
    [NamespaceSegments.physical, final name] =>
        _physicalValue(character, name),
    [NamespaceSegments.relationship, final name] =>
        _relationshipValue(character, name),
    [NamespaceSegments.knowledge, final topic, final field] =>
        _resolveKnowledge(character.knowledge[topic], field),
    [NamespaceSegments.flags, final name] => character.flags[name],
    _ => null,
  };
}

double? _emotionValue(CharacterState c, String name) {
  final key = _emotionByName[name];
  return key == null ? null : c.emotion[key]?.value;
}

double? _physicalValue(CharacterState c, String name) {
  final key = _physicalByName[name];
  return key == null ? null : c.physical[key]?.value;
}

double? _relationshipValue(CharacterState c, String name) {
  final key = _relationshipByName[name];
  return key == null ? null : c.relationship[key]?.value;
}

Object? _resolveKnowledge(KnowledgeRecord? record, String field) {
  return switch (field) {
    NamespaceSegments.value => record?.value,
    NamespaceSegments.confidence => record?.confidence,
    _ => null,
  };
}

Object? _resolveGlobalArea(SessionState state, List<String> rest) {
  return switch (rest) {
    [NamespaceSegments.scene, final field] =>
        _resolveSceneField(state.currentScene, field),
    [NamespaceSegments.phase] => state.currentPhase.name,
    [NamespaceSegments.goal] => state.currentGoal,
    [NamespaceSegments.turn] => state.turn,
    [NamespaceSegments.eventLog] => state.eventLog,
    [NamespaceSegments.flags, final name] => state.flags[name],
    _ => null,
  };
}

Object? _resolveSceneField(Scene scene, String field) {
  return switch (field) {
    NamespaceSegments.location => scene.location,
    NamespaceSegments.timeOfDay => scene.timeOfDay,
    NamespaceSegments.presentEntities => scene.presentEntities,
    NamespaceSegments.sensoryHooks => scene.sensoryHooks,
    _ => null,
  };
}
