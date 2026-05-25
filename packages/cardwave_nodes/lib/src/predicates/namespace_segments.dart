/// String segments used in the predicate namespace. Single source of
/// truth shared by `field_schema` (which builds the valid patterns) and
/// the evaluator (which matches them against runtime state). Renaming a
/// segment here updates both consumers.
abstract class NamespaceSegments {
  NamespaceSegments._();

  // Roots
  static const character = 'character';
  static const global = 'global';

  // Per-character areas
  static const emotion = 'emotion';
  static const physical = 'physical';
  static const relationship = 'relationship';
  static const knowledge = 'knowledge';
  static const flags = 'flags';

  // Knowledge record sub-fields
  static const value = 'value';
  static const confidence = 'confidence';

  // Global areas / leaves
  static const scene = 'scene';
  static const phase = 'phase';
  static const goal = 'goal';
  static const turn = 'turn';
  static const eventLog = 'eventLog';

  // Scene sub-fields
  static const location = 'location';
  static const timeOfDay = 'timeOfDay';
  static const presentEntities = 'presentEntities';
  static const sensoryHooks = 'sensoryHooks';
}
