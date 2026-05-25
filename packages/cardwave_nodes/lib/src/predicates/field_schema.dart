import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:cardwave_nodes/src/predicates/namespace_segments.dart';

/// What kind of value a field holds. Used by the predicate validator to
/// check that comparisons in expressions are well-typed.
enum FieldType {
  number,
  string,
  boolean,
  list,
  /// Open value — flags and knowledge.value can hold anything. The
  /// predicate evaluator handles these per the runtime value's type.
  openValue,
}

/// Specification for one leaf path pattern. A pattern may contain
/// placeholders (`<id>`, `<topic>`, `<name>`) that match any single
/// non-empty segment.
class FieldSpec {
  FieldSpec(this.pattern, this.type) : segments = pattern.split('.');

  final String pattern;
  final FieldType type;

  /// Pre-split pattern segments. Hoisted once at construction so
  /// per-lookup matching does not re-allocate.
  final List<String> segments;
}

/// All valid leaf paths under `character.<id>.xxx` and `global.xxx`.
/// Source of truth for predicate validation at node load time.
final List<FieldSpec> fieldSchema = [
  for (final e in EmotionEnum.values)
    FieldSpec(
      '${NamespaceSegments.character}.<id>.${NamespaceSegments.emotion}.${e.name}',
      FieldType.number,
    ),
  for (final p in PhysicalEnum.values)
    FieldSpec(
      '${NamespaceSegments.character}.<id>.${NamespaceSegments.physical}.${p.name}',
      FieldType.number,
    ),
  for (final r in RelationshipEnum.values)
    FieldSpec(
      '${NamespaceSegments.character}.<id>.${NamespaceSegments.relationship}.${r.name}',
      FieldType.number,
    ),
  FieldSpec(
    '${NamespaceSegments.character}.<id>.${NamespaceSegments.knowledge}.<topic>.${NamespaceSegments.value}',
    FieldType.openValue,
  ),
  FieldSpec(
    '${NamespaceSegments.character}.<id>.${NamespaceSegments.knowledge}.<topic>.${NamespaceSegments.confidence}',
    FieldType.number,
  ),
  FieldSpec(
    '${NamespaceSegments.character}.<id>.${NamespaceSegments.flags}.<name>',
    FieldType.openValue,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.scene}.${NamespaceSegments.location}',
    FieldType.string,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.scene}.${NamespaceSegments.timeOfDay}',
    FieldType.string,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.scene}.${NamespaceSegments.presentEntities}',
    FieldType.list,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.scene}.${NamespaceSegments.sensoryHooks}',
    FieldType.list,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.phase}',
    FieldType.string,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.goal}',
    FieldType.string,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.turn}',
    FieldType.number,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.flags}.<name>',
    FieldType.openValue,
  ),
  FieldSpec(
    '${NamespaceSegments.global}.${NamespaceSegments.eventLog}',
    FieldType.list,
  ),
];

/// Validates [path] against [fieldSchema]. Returns the matching spec or
/// null if the path matches no known pattern.
FieldSpec? lookupPath(String path) {
  final concrete = path.split('.');
  for (final spec in fieldSchema) {
    if (_matchesSegments(concrete, spec.segments)) return spec;
  }
  return null;
}

bool _matchesSegments(List<String> concrete, List<String> pattern) {
  if (concrete.length != pattern.length) return false;
  // Lengths are equal, so `i < concrete.length` keeps both indexed reads
  // below in range.
  for (var i = 0; i < concrete.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    final p = pattern[i];
    // ignore: qcheck/avoid_unsafe_collection_methods
    final c = concrete[i];
    if (_isPlaceholder(p)) {
      if (c.isEmpty) return false;
    } else if (p != c) {
      return false;
    }
  }
  return true;
}

bool _isPlaceholder(String segment) =>
    segment.length > 2 && segment.startsWith('<') && segment.endsWith('>');
