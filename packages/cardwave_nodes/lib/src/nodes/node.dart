import 'package:cardwave_nodes/src/nodes/node_effects.dart';
import 'package:cardwave_nodes/src/nodes/node_origin_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_scope_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_type_enum.dart';
import 'package:cardwave_nodes/src/nodes/visual_editor_section.dart';
import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

/// One beat in the pool. Holds the authoring fields (initial countdown
/// values, scope, predicate, payload, effects, the ids of nodes this one
/// spawns, and its canvas position) plus the per-turn runtime state
/// (currentDelay, currentCooldown, currentSticky, currentAlive) so the
/// pool's tick can decrement in place and the whole shape round-trips
/// through JSON.
///
/// Nodes are stored flat in [CardNodesExtension.authoredNodes]; a node
/// names the nodes it spawns by id in [spawnIds] rather than nesting
/// them, so a node can be spawned by more than one parent and can exist
/// before it is wired to anything.
///
/// `-1` semantics by field:
///   - delay: literal; -1 treated as 0
///   - cooldown: -1 means "no cooldown" (equivalent to 0)
///   - sticky: -1 means "permanent sticky" (never decremented)
///   - alive: -1 means "no time-to-live" (never expires by alive)
@JsonSerializable(explicitToJson: true)
class Node {
  Node({
    required this.id,
    this.name = '',
    required this.origin,
    required this.type,
    required this.triggerProb,
    required this.delay,
    required this.cooldown,
    required this.sticky,
    required this.alive,
    required this.scope,
    required this.predicate,
    required this.narrativePayload,
    NodeEffects? effects,
    List<String>? spawnIds,
    VisualEditorSection? visualEditor,
    int? currentDelay,
    int? currentCooldown,
    int? currentSticky,
    int? currentAlive,
  })  : effects = effects ?? NodeEffects(),
        spawnIds = spawnIds ?? [],
        visualEditor = visualEditor ?? const VisualEditorSection(),
        currentDelay = currentDelay ?? (delay < 0 ? 0 : delay),
        currentCooldown = currentCooldown ?? 0,
        currentSticky = currentSticky ?? 0,
        currentAlive = currentAlive ?? alive;

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  final String id;

  /// Human label the author edits freely. Nothing references it — spawn
  /// links use [id], which is generated once and never changes.
  @JsonKey(defaultValue: '')
  final String name;

  final NodeOriginEnum origin;
  final NodeTypeEnum type;
  final double triggerProb;

  // Initial values (authoring intent).
  final int delay;
  final int cooldown;
  final int sticky;
  final int alive;

  final NodeScopeEnum scope;

  /// Source text of the boolean expression that gates eligibility. The
  /// firing logic parses and caches the AST per pool entry.
  final String predicate;

  final String narrativePayload;
  final NodeEffects effects;

  /// Ids of the nodes this one drops into the pool when it fires. Each
  /// must match the `id` of an entry in
  /// [CardNodesExtension.authoredNodes]; the loader rejects dangling
  /// references.
  @JsonKey(name: 'spawn_ids')
  final List<String> spawnIds;

  /// The node's `visual_editor` JSON section: its box position on the
  /// visual editor canvas. Authoring data (kept on save, not a runtime
  /// counter). Origin until the author places the box.
  final VisualEditorSection visualEditor;

  // Runtime values (mutated by the pool's tick and by firing).
  int currentDelay;
  int currentCooldown;
  int currentSticky;
  int currentAlive;

  /// What the UI shows for this node: the author's name, or the id
  /// while no name is set.
  String get displayLabel => name.isEmpty ? id : name;

  Map<String, dynamic> toJson() => _$NodeToJson(this);
}
