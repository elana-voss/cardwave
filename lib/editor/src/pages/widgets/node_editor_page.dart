import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/dropdown_labeled.dart';
import 'package:cardwave/editor/src/pages/widgets/object_value_editor.dart';
import 'package:cardwave/editor/src/pages/widgets/tag_chip.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Full-page editor for a single authored node. Receives the node by
/// value, holds a working copy, calls [onUpdated] with a rebuilt
/// `Node` on every field change. The parent panel replaces the node
/// in the list and persists.
///
/// [characterId] is the card's own `appCardId`. Per the plan, effects
/// always target this single id (the schema's per-character map shape
/// is preserved but the key is hidden from the UI).
///
/// This step covers basic fields, the predicate field with live
/// validation, the narrative payload field, and the effects section
/// (emotion / physical / relationship deltas, scene & flow).
/// Knowledge writes, flag set, and spawns arrive in later steps.
class NodeEditorPage extends StatefulWidget {
  const NodeEditorPage({
    required this.node,
    required this.characterId,
    required this.onUpdated,
    this.breadcrumb = const [],
    super.key,
  });

  final Node node;
  final String characterId;
  final ValueChanged<Node> onUpdated;

  /// IDs of ancestor nodes leading to this one, oldest first. Empty
  /// for the top-level edit; on each recursive push it grows with the
  /// parent node's id so the app bar can render a path.
  final List<String> breadcrumb;

  @override
  State<NodeEditorPage> createState() => _NodeEditorPageState();
}

class _NodeEditorPageState extends State<NodeEditorPage> {
  late Node _node;
  final _NodeControllers _controllers = _NodeControllers();

  /// Live predicate problems published on every keystroke. Held in a
  /// `ValueNotifier` so `_PredicateField` can rebuild only its problems
  /// list via `ValueListenableBuilder` — without `setState` on this
  /// page.
  ///
  /// ⚠️ DO NOT call `setState` from inside any text-controller listener
  /// on this page (notably `_onAnyTextChanged`). A page-wide rebuild on
  /// every keystroke triggers a Flutter framework race on the Android
  /// emulator: the real platform IME asynchronously pushes its cached
  /// field value back through the platform channel during the rebuild,
  /// overwriting whatever was just typed. Burned multiple hours debugging
  /// this on 2026-05-30 — the `editor_nodes_round_trip_test` flake
  /// disappeared the moment the per-keystroke setState was removed.
  /// Reach for this `ValueNotifier` pattern for any future per-keystroke
  /// derived display state on this page (problem lists, token counts,
  /// computed previews).
  final ValueNotifier<List<String>> _predicateProblems =
      ValueNotifier(const []);

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _controllers.loadFrom(_node);
    _predicateProblems.value = findPredicateProblems(_node.predicate);

    // One shared listener on every controller — same shape as
    // lorebook_entry_editor_page.dart's `_onTextChanged`. Each
    // keystroke rebuilds the Node from ALL controller texts, so a
    // single field change can't leave the others stale.
    for (final controller in _controllers.all) {
      controller.onTextChanged(_onAnyTextChanged);
    }
  }

  void _onAnyTextChanged() {
    _replace(_buildFromCurrentState());
    _predicateProblems.value =
        findPredicateProblems(_controllers.predicate.text);
  }

  @override
  void dispose() {
    _controllers.dispose();
    _predicateProblems.dispose();
    super.dispose();
  }

  void _replace(Node updated) {
    _node = updated;
    widget.onUpdated(updated);
  }

  /// Builds a Node from the CURRENT controller text on every text
  /// field plus the in-state non-controller fields (type, scope,
  /// origin, effects, spawns) on `_node`. Used by every text-field
  /// listener so a stale `_node` can never revert a field that was
  /// typed by the user: the controllers are the source of truth.
  Node _buildFromCurrentState() {
    final triggerProb = double.tryParse(_controllers.triggerProb.text);
    final delay = int.tryParse(_controllers.delay.text);
    final cooldown = int.tryParse(_controllers.cooldown.text);
    final sticky = int.tryParse(_controllers.sticky.text);
    final alive = int.tryParse(_controllers.alive.text);
    return Node(
      id: _node.id,
      origin: _node.origin,
      type: _node.type,
      triggerProb:
          (triggerProb ?? _node.triggerProb).clamp(0.0, 1.0).toDouble(),
      delay: delay ?? _node.delay,
      cooldown: cooldown ?? _node.cooldown,
      sticky: sticky ?? _node.sticky,
      alive: alive ?? _node.alive,
      scope: _node.scope,
      predicate: _controllers.predicate.text,
      narrativePayload: _controllers.narrativePayload.text,
      effects: _node.effects,
      spawns: _node.spawns,
    );
  }

  void _onSliderTriggerProbChanged(double value) {
    // Setting the controller text fires `_onAnyTextChanged`, which
    // rebuilds the Node. The `setState` here is just so the parent
    // re-passes the new `node.triggerProb` down to the slider widget.
    _controllers.triggerProb.text = value.toStringAsFixed(2);
    setState(() {});
  }

  void _setNeverFor(_CountdownField field) {
    final controller = switch (field) {
      _CountdownField.delay => _controllers.delay,
      _CountdownField.cooldown => _controllers.cooldown,
      _CountdownField.sticky => _controllers.sticky,
      _CountdownField.alive => _controllers.alive,
    };
    // Setting the text fires `_onAnyTextChanged` via the controller's
    // listener — that runs `_replace`. No explicit call needed here.
    controller.text = '-1';
  }

  void _onTypeChanged(NodeTypeEnum? value) {
    if (value == null) return;
    _replace(_rebuild(_node, type: value));
    setState(() {});
  }

  void _onScopeChanged(NodeScopeEnum? value) {
    if (value == null) return;
    _replace(_rebuild(_node, scope: value));
    setState(() {});
  }

  void _onOriginChanged(NodeOriginEnum? value) {
    if (value == null) return;
    _replace(_rebuild(_node, origin: value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final crumbs = [...widget.breadcrumb, _node.id];
    return Scaffold(
      appBar: AppBar(title: Text(crumbs.join(' › '))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            _BasicFieldsSection(
              node: _node,
              controllers: _controllers,
              onTypeChanged: _onTypeChanged,
              onScopeChanged: _onScopeChanged,
              onOriginChanged: _onOriginChanged,
              onSliderTriggerProbChanged: _onSliderTriggerProbChanged,
              onSetNever: _setNeverFor,
            ),
            _PredicateField(
              controller: _controllers.predicate,
              problems: _predicateProblems,
            ),
            TextFieldCard.multiLine(
              controller: _controllers.narrativePayload,
              label: 'Narrative payload',
            ),
            _EffectsSection(
              effects: _node.effects,
              characterId: widget.characterId,
              currentPhase: _node.effects.phaseChange,
              currentGoal: _node.effects.goalChange,
              sceneTransition: _node.effects.sceneTransition,
              onMutated: _onEffectsMutated,
              onGoalChanged: _onGoalChangeChanged,
              onPhaseChanged: _onPhaseChangeChanged,
              onSceneTransitionChanged: _onSceneTransitionChanged,
            ),
            _SpawnsSection(
              spawns: _node.spawns,
              onAdd: _addSpawn,
              onOpen: (spawn) => _openSpawnEditor(spawn, crumbs),
              onDelete: _deleteSpawn,
            ),
          ],
        ),
      ),
    );
  }

  void _addSpawn() {
    final spawn = Node(
      id: 'node_${DateTime.now().millisecondsSinceEpoch}',
      origin: NodeOriginEnum.authored,
      type: NodeTypeEnum.characterBehavior,
      triggerProb: 1.0,
      delay: 0,
      cooldown: 0,
      sticky: 0,
      alive: -1,
      scope: NodeScopeEnum.session,
      predicate: 'true',
      narrativePayload: '',
    );
    _node.spawns.add(spawn);
    widget.onUpdated(_node);
    setState(() {});
  }

  Future<void> _deleteSpawn(Node spawn) async {
    final controller = context.read<EditorPageController>();
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await controller.confirmDelete(
      title: 'Delete spawn',
      message: 'Remove this spawn from the parent node?',
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    _node.spawns.removeWhere((n) => n.id == spawn.id);
    widget.onUpdated(_node);
    setState(() {});
  }

  void _openSpawnEditor(Node spawn, List<String> parentCrumbs) {
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => NodeEditorPage(
          node: spawn,
          characterId: widget.characterId,
          breadcrumb: parentCrumbs,
          onUpdated: (updated) {
            final idx = _node.spawns.indexWhere((n) => n.id == spawn.id);
            if (idx < 0) return;
            _node.spawns[idx] = updated;
            widget.onUpdated(_node);
            setState(() {});
          },
        ),
      ),
    ));
  }

  void _onEffectsMutated() {
    // Deltas / flag / knowledge mutations are in-place on the maps
    // owned by `_node.effects`; the Node reference is unchanged, but
    // the parent still needs a persist tick.
    widget.onUpdated(_node);
    setState(() {});
  }

  void _onGoalChangeChanged(String? value) {
    _replaceEffects(goalChange: value);
  }

  void _onPhaseChangeChanged(PhaseEnum? value) {
    _replaceEffects(phaseChange: value);
  }

  void _onSceneTransitionChanged(bool value) {
    _replaceEffects(sceneTransition: value);
  }

  void _replaceEffects({
    Object? goalChange = _kKeep,
    Object? phaseChange = _kKeep,
    bool? sceneTransition,
  }) {
    final current = _node.effects;
    final next = NodeEffects(
      emotionDeltas: current.emotionDeltas,
      physicalDeltas: current.physicalDeltas,
      relationshipDeltas: current.relationshipDeltas,
      flagSet: current.flagSet,
      goalChange: identical(goalChange, _kKeep)
          ? current.goalChange
          : goalChange as String?,
      phaseChange: identical(phaseChange, _kKeep)
          ? current.phaseChange
          : phaseChange as PhaseEnum?,
      sceneTransition: sceneTransition ?? current.sceneTransition,
      knowledgeWrites: current.knowledgeWrites,
    );
    _replace(_rebuild(_node, effects: next));
    setState(() {});
  }
}

/// Sentinel for `_replaceEffects` so callers can distinguish "not
/// touching this field" from "set it to null." A normal nullable
/// parameter can't tell them apart.
const Object _kKeep = Object();

/// Padding shared by the four effects-category ExpansionTiles so they
/// align consistently and the indent matches the parent column.
const EdgeInsets _kExpansionTilePadding = EdgeInsets.zero;
const EdgeInsets _kExpansionChildrenPadding =
    EdgeInsets.only(left: 16, bottom: 8);

/// Copy of [from] with one or more fields replaced. Used by the
/// knowledge-writes editor's three per-field callbacks so each one
/// doesn't have to reconstruct the two unchanged fields.
KnowledgeRecord _copyKnowledgeRecord(
  KnowledgeRecord from, {
  String? topic,
  Object? value,
  double? confidence,
}) =>
    KnowledgeRecord(
      topic: topic ?? from.topic,
      value: value ?? from.value,
      confidence: confidence ?? from.confidence,
    );

/// The set of named "countdown" fields on `Node` (per spec §4.2).
enum _CountdownField { delay, cooldown, sticky, alive }

/// Bag of text controllers for one node edit session. Disposed
/// alongside the page state.
class _NodeControllers {
  _NodeControllers();

  final TextEditingController predicate = TextEditingController();
  final TextEditingController narrativePayload = TextEditingController();
  final TextEditingController triggerProb = TextEditingController();
  final TextEditingController delay = TextEditingController();
  final TextEditingController cooldown = TextEditingController();
  final TextEditingController sticky = TextEditingController();
  final TextEditingController alive = TextEditingController();

  late final List<TextEditingController> all = [
    predicate,
    narrativePayload,
    triggerProb,
    delay,
    cooldown,
    sticky,
    alive,
  ];

  /// Populate from [n]'s authoring fields. Called from `initState`
  /// once the page's `_node` is assigned.
  void loadFrom(Node n) {
    predicate.text = n.predicate;
    narrativePayload.text = n.narrativePayload;
    triggerProb.text = n.triggerProb.toStringAsFixed(2);
    delay.text = n.delay.toString();
    cooldown.text = n.cooldown.toString();
    sticky.text = n.sticky.toString();
    alive.text = n.alive.toString();
  }

  void dispose() {
    for (final controller in all) {
      controller.dispose();
    }
  }
}

/// Rebuilds a `Node` with one or more authoring fields replaced.
/// Spawns flow through unchanged. Runtime countdown fields stay at
/// whatever the source node carried (`_persist` in the panel strips
/// them on save).
Node _rebuild(
  Node current, {
  NodeTypeEnum? type,
  NodeScopeEnum? scope,
  NodeOriginEnum? origin,
  double? triggerProb,
  ({_CountdownField field, int value})? countdown,
  String? predicate,
  String? narrativePayload,
  NodeEffects? effects,
}) {
  return Node(
    id: current.id,
    origin: origin ?? current.origin,
    type: type ?? current.type,
    triggerProb: triggerProb ?? current.triggerProb,
    delay: countdown?.field == _CountdownField.delay
        ? countdown!.value
        : current.delay,
    cooldown: countdown?.field == _CountdownField.cooldown
        ? countdown!.value
        : current.cooldown,
    sticky: countdown?.field == _CountdownField.sticky
        ? countdown!.value
        : current.sticky,
    alive: countdown?.field == _CountdownField.alive
        ? countdown!.value
        : current.alive,
    scope: scope ?? current.scope,
    predicate: predicate ?? current.predicate,
    narrativePayload: narrativePayload ?? current.narrativePayload,
    effects: effects ?? current.effects,
    spawns: current.spawns,
    currentDelay: current.currentDelay,
    currentCooldown: current.currentCooldown,
    currentSticky: current.currentSticky,
    currentAlive: current.currentAlive,
  );
}

class _BasicFieldsSection extends StatelessWidget {
  const _BasicFieldsSection({
    required this.node,
    required this.controllers,
    required this.onTypeChanged,
    required this.onScopeChanged,
    required this.onOriginChanged,
    required this.onSliderTriggerProbChanged,
    required this.onSetNever,
  });

  final Node node;
  final _NodeControllers controllers;
  final ValueChanged<NodeTypeEnum?> onTypeChanged;
  final ValueChanged<NodeScopeEnum?> onScopeChanged;
  final ValueChanged<NodeOriginEnum?> onOriginChanged;
  final ValueChanged<double> onSliderTriggerProbChanged;
  final ValueChanged<_CountdownField> onSetNever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          'ID: ${node.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownLabeled<NodeTypeEnum>(
                label: 'Type',
                value: node.type,
                items: [
                  for (final t in NodeTypeEnum.values)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: onTypeChanged,
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownLabeled<NodeScopeEnum>(
                label: 'Scope',
                value: node.scope,
                items: [
                  for (final s in NodeScopeEnum.values)
                    DropdownMenuItem(value: s, child: Text(s.name)),
                ],
                onChanged: onScopeChanged,
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownLabeled<NodeOriginEnum>(
                label: 'Origin',
                value: node.origin,
                items: [
                  for (final o in NodeOriginEnum.values)
                    DropdownMenuItem(value: o, child: Text(o.name)),
                ],
                onChanged: onOriginChanged,
              ),
            ),
          ],
        ),
        _TriggerProbRow(
          value: node.triggerProb,
          controller: controllers.triggerProb,
          onSliderChanged: onSliderTriggerProbChanged,
        ),
        _CountdownRow(
          field: _CountdownField.delay,
          controller: controllers.delay,
          helper: 'Turns to wait before becoming eligible. -1 acts as 0.',
          onSetNever: null,
        ),
        _CountdownRow(
          field: _CountdownField.cooldown,
          controller: controllers.cooldown,
          helper: 'Turns locked out after firing. -1 means no cooldown.',
          onSetNever: () => onSetNever(_CountdownField.cooldown),
        ),
        _CountdownRow(
          field: _CountdownField.sticky,
          controller: controllers.sticky,
          helper:
              'Turns the narrative payload keeps appearing as "Lingering" '
              'after firing. -1 means permanent.',
          onSetNever: () => onSetNever(_CountdownField.sticky),
        ),
        _CountdownRow(
          field: _CountdownField.alive,
          controller: controllers.alive,
          helper:
              'Turns the node stays in the pool before removal. '
              '-1 means forever.',
          onSetNever: () => onSetNever(_CountdownField.alive),
        ),
      ],
    );
  }
}

class _TriggerProbRow extends StatelessWidget {
  const _TriggerProbRow({
    required this.value,
    required this.controller,
    required this.onSliderChanged,
  });

  final double value;
  final TextEditingController controller;
  final ValueChanged<double> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 110,
          child: Text('Trigger prob'),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onSliderChanged,
          ),
        ),
        SizedBox(
          width: 80,
          child: TextFieldCard.singleLine(
            controller: controller,
            label: '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.field,
    required this.controller,
    required this.helper,
    required this.onSetNever,
  });

  final _CountdownField field;
  final TextEditingController controller;
  final String helper;

  /// When non-null, renders a "Set to never" trailing button next to
  /// the field that fills `-1`. `delay` does not get one (its `-1`
  /// is treated as `0`, so "never" is meaningless there).
  final VoidCallback? onSetNever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SizedBox(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(field.name),
          ),
        ),
        SizedBox(
          width: 100,
          child: TextFieldCard.singleLine(
            controller: controller,
            label: '',
            keyboardType: const TextInputType.numberWithOptions(signed: true),
          ),
        ),
        if (onSetNever != null)
          TextButton(
            onPressed: onSetNever,
            child: const Text('Set to never'),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 14),
            child: Text(
              helper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EffectsSection extends StatelessWidget {
  const _EffectsSection({
    required this.effects,
    required this.characterId,
    required this.currentPhase,
    required this.currentGoal,
    required this.sceneTransition,
    required this.onMutated,
    required this.onGoalChanged,
    required this.onPhaseChanged,
    required this.onSceneTransitionChanged,
  });

  final NodeEffects effects;
  final String characterId;
  final PhaseEnum? currentPhase;
  final String? currentGoal;
  final bool sceneTransition;

  /// Called after in-place mutations to the per-character delta maps
  /// (the maps live inside `effects` and are mutable; only the
  /// containing `NodeEffects` and `Node` carry final fields).
  final VoidCallback onMutated;

  /// Setters for the three flow fields (each backed by `final` on
  /// `NodeEffects`, so the parent rebuilds the full effects object).
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<PhaseEnum?> onPhaseChanged;
  final ValueChanged<bool> onSceneTransitionChanged;

  _DeltaMapEditor<E> _deltaEditor<E extends Enum>({
    required String title,
    required List<E> allValues,
    required Map<String, Map<E, double>> byCharacter,
  }) =>
      _DeltaMapEditor<E>(
        title: title,
        allValues: allValues,
        binding: _DeltaMapBinding(
          characterId: characterId,
          byCharacter: byCharacter,
          onChanged: onMutated,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Effects'),
        _deltaEditor<EmotionEnum>(
          title: 'Emotion deltas',
          allValues: EmotionEnum.values,
          byCharacter: effects.emotionDeltas,
        ),
        _deltaEditor<PhysicalEnum>(
          title: 'Physical deltas',
          allValues: PhysicalEnum.values,
          byCharacter: effects.physicalDeltas,
        ),
        _deltaEditor<RelationshipEnum>(
          title: 'Relationship deltas',
          allValues: RelationshipEnum.values,
          byCharacter: effects.relationshipDeltas,
        ),
        _KnowledgeWritesSection(
          binding: _KnowledgeWriteBinding(
            characterId: characterId,
            byCharacter: effects.knowledgeWrites,
            onChanged: onMutated,
          ),
        ),
        _FlagSetSection(
          binding: _FlagSetBinding(
            flags: effects.flagSet,
            onChanged: onMutated,
          ),
        ),
        _SceneAndFlowSection(
          goal: currentGoal,
          phase: currentPhase,
          sceneTransition: sceneTransition,
          onGoalChanged: onGoalChanged,
          onPhaseChanged: onPhaseChanged,
          onSceneTransitionChanged: onSceneTransitionChanged,
        ),
      ],
    );
  }
}

/// Wraps a per-character delta map (`Map<String, Map<E, double>>`) and
/// exposes add / set / swap / remove operations for a single
/// character key. Strips the inner map when it becomes empty so the
/// serialized form matches a freshly authored card.
class _DeltaMapBinding<E extends Enum> {
  const _DeltaMapBinding({
    required this.characterId,
    required this.byCharacter,
    required this.onChanged,
  });

  final String characterId;
  final Map<String, Map<E, double>> byCharacter;
  final VoidCallback onChanged;

  Map<E, double> get current => byCharacter[characterId] ?? const {};

  void add(E key) {
    final map = byCharacter.putIfAbsent(characterId, () => {});
    map[key] = 0.0;
    onChanged();
  }

  void setValue(E key, double value) {
    final map = byCharacter.putIfAbsent(characterId, () => {});
    map[key] = value;
    onChanged();
  }

  void swap(E oldKey, E newKey) {
    final map = byCharacter[characterId];
    if (map == null) return;
    final value = map[oldKey] ?? 0.0;
    map.remove(oldKey);
    map[newKey] = value;
    onChanged();
  }

  void remove(E key) {
    final map = byCharacter[characterId];
    if (map == null) return;
    map.remove(key);
    if (map.isEmpty) byCharacter.remove(characterId);
    onChanged();
  }
}

class _DeltaMapEditor<E extends Enum> extends StatelessWidget {
  const _DeltaMapEditor({
    required this.title,
    required this.allValues,
    required this.binding,
  });

  final String title;
  final List<E> allValues;
  final _DeltaMapBinding<E> binding;

  @override
  Widget build(BuildContext context) {
    final current = binding.current;
    final remaining =
        allValues.where((v) => !current.containsKey(v)).toList();
    return ExpansionTile(
      title: Row(
        children: [
          Text(title),
          if (current.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CountBadge(current.length),
          ],
        ],
      ),
      tilePadding: _kExpansionTilePadding,
      childrenPadding: _kExpansionChildrenPadding,
      children: [
        for (final entry in current.entries)
          _DeltaRow<E>(
            field: entry.key,
            value: entry.value,
            available: [
              entry.key,
              ...allValues.where((v) => !current.containsKey(v)),
            ],
            onFieldChanged: (newField) {
              if (newField == entry.key) return;
              binding.swap(entry.key, newField);
            },
            onValueChanged: (v) => binding.setValue(entry.key, v),
            onRemove: () => binding.remove(entry.key),
          ),
        if (remaining.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<E>(
              onSelected: binding.add,
              itemBuilder: (context) => [
                for (final v in remaining)
                  PopupMenuItem(value: v, child: Text(v.name)),
              ],
              child: const Chip(
                avatar: Icon(Icons.add, size: 18),
                label: Text('Add delta'),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeltaRow<E extends Enum> extends StatefulWidget {
  const _DeltaRow({
    required this.field,
    required this.value,
    required this.available,
    required this.onFieldChanged,
    required this.onValueChanged,
    required this.onRemove,
  });

  final E field;
  final double value;
  final List<E> available;
  final ValueChanged<E> onFieldChanged;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onRemove;

  @override
  State<_DeltaRow<E>> createState() => _DeltaRowState<E>();
}

class _DeltaRowState<E extends Enum> extends State<_DeltaRow<E>> {
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _valueController.text = widget.value.toStringAsFixed(2);
    _valueController.onTextChanged(() {
      final parsed = double.tryParse(_valueController.text);
      if (parsed == null) return;
      final clamped = parsed.clamp(directorDeltaMin, directorDeltaMax);
      if (clamped == widget.value) return;
      widget.onValueChanged(clamped);
    });
  }

  @override
  void didUpdateWidget(_DeltaRow<E> old) {
    super.didUpdateWidget(old);
    final asText = widget.value.toStringAsFixed(2);
    if (_valueController.text != asText) {
      _valueController.text = asText;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: DropdownButton<E>(
              isExpanded: true,
              value: widget.field,
              items: [
                for (final v in widget.available)
                  DropdownMenuItem(value: v, child: Text(v.name)),
              ],
              onChanged: (v) {
                if (v != null) widget.onFieldChanged(v);
              },
            ),
          ),
          Expanded(
            child: Slider(
              min: directorDeltaMin,
              max: directorDeltaMax,
              value: widget.value.clamp(directorDeltaMin, directorDeltaMax),
              onChanged: widget.onValueChanged,
            ),
          ),
          SizedBox(
            width: 72,
            child: TextFieldCard.singleLine(
              controller: _valueController,
              label: '',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _KnowledgeWriteBinding {
  const _KnowledgeWriteBinding({
    required this.characterId,
    required this.byCharacter,
    required this.onChanged,
  });

  final String characterId;
  final Map<String, List<KnowledgeRecord>> byCharacter;
  final VoidCallback onChanged;

  List<KnowledgeRecord> get current => byCharacter[characterId] ?? const [];

  void add() {
    final list = byCharacter.putIfAbsent(characterId, () => []);
    list.add(const KnowledgeRecord(topic: '', value: '', confidence: 0.5));
    onChanged();
  }

  void replace(int index, KnowledgeRecord record) {
    final list = byCharacter[characterId];
    if (list == null || index < 0 || index >= list.length) return;
    list[index] = record;
    onChanged();
  }

  void remove(int index) {
    final list = byCharacter[characterId];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) byCharacter.remove(characterId);
    onChanged();
  }
}

class _KnowledgeWritesSection extends StatelessWidget {
  const _KnowledgeWritesSection({required this.binding});

  final _KnowledgeWriteBinding binding;

  @override
  Widget build(BuildContext context) {
    final records = binding.current;
    return ExpansionTile(
      title: Row(
        children: [
          const Text('Knowledge writes'),
          if (records.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CountBadge(records.length),
          ],
        ],
      ),
      tilePadding: _kExpansionTilePadding,
      childrenPadding: _kExpansionChildrenPadding,
      children: [
        for (var i = 0; i < records.length; i++)
          _KnowledgeRow(
            // Index-based key: records are replaced (not mutated) on
            // every keystroke. An identity-based key would change with
            // each replacement and steal focus mid-typing.
            key: ValueKey(i),
            record: records[i],
            onTopicChanged: (topic) =>
                binding.replace(i, _copyKnowledgeRecord(records[i], topic: topic)),
            onValueChanged: (value) =>
                binding.replace(i, _copyKnowledgeRecord(records[i], value: value)),
            onConfidenceChanged: (conf) => binding.replace(
              i,
              _copyKnowledgeRecord(records[i], confidence: conf),
            ),
            onRemove: () => binding.remove(i),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add fact'),
            onPressed: binding.add,
          ),
        ),
      ],
    );
  }
}

class _KnowledgeRow extends StatefulWidget {
  const _KnowledgeRow({
    required this.record,
    required this.onTopicChanged,
    required this.onValueChanged,
    required this.onConfidenceChanged,
    required this.onRemove,
    super.key,
  });

  final KnowledgeRecord record;
  final ValueChanged<String> onTopicChanged;
  final ValueChanged<Object?> onValueChanged;
  final ValueChanged<double> onConfidenceChanged;
  final VoidCallback onRemove;

  @override
  State<_KnowledgeRow> createState() => _KnowledgeRowState();
}

class _KnowledgeRowState extends State<_KnowledgeRow> {
  final TextEditingController _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _topicController.text = widget.record.topic;
    _topicController.onTextChanged(
      () => widget.onTopicChanged(_topicController.text),
    );
  }

  @override
  void didUpdateWidget(_KnowledgeRow old) {
    super.didUpdateWidget(old);
    if (_topicController.text != widget.record.topic) {
      _topicController.text = widget.record.topic;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFieldCard.singleLine(
                  controller: _topicController,
                  label: 'topic',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
                tooltip: 'Remove',
              ),
            ],
          ),
          ObjectValueEditor(
            value: widget.record.value,
            onChanged: widget.onValueChanged,
          ),
          Row(
            children: [
              const SizedBox(width: 100, child: Text('confidence')),
              Expanded(
                child: Slider(
                  value: widget.record.confidence.clamp(0.0, 1.0),
                  onChanged: widget.onConfidenceChanged,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  widget.record.confidence.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlagSetBinding {
  const _FlagSetBinding({required this.flags, required this.onChanged});

  final Map<String, Object?> flags;
  final VoidCallback onChanged;

  void add() {
    var key = 'new_flag';
    var i = 1;
    while (flags.containsKey(key)) {
      i++;
      key = 'new_flag_$i';
    }
    flags[key] = '';
    onChanged();
  }

  void renameKey(String oldKey, String newKey) {
    if (oldKey == newKey) return;
    if (!flags.containsKey(oldKey)) return;
    if (flags.containsKey(newKey)) return;
    final value = flags.remove(oldKey);
    flags[newKey] = value;
    onChanged();
  }

  void setValue(String key, Object? value) {
    if (!flags.containsKey(key)) return;
    flags[key] = value;
    onChanged();
  }

  void remove(String key) {
    if (!flags.containsKey(key)) return;
    flags.remove(key);
    onChanged();
  }
}

class _FlagSetSection extends StatelessWidget {
  const _FlagSetSection({required this.binding});

  final _FlagSetBinding binding;

  @override
  Widget build(BuildContext context) {
    final keys = binding.flags.keys.toList();
    return ExpansionTile(
      title: Row(
        children: [
          const Text('Flag set'),
          if (keys.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CountBadge(keys.length),
          ],
        ],
      ),
      tilePadding: _kExpansionTilePadding,
      childrenPadding: _kExpansionChildrenPadding,
      children: [
        for (final key in keys)
          _FlagRow(
            key: ValueKey(key),
            flagKey: key,
            value: binding.flags[key],
            onKeyChanged: (newKey) => binding.renameKey(key, newKey),
            onValueChanged: (v) => binding.setValue(key, v),
            onRemove: () => binding.remove(key),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add flag'),
            onPressed: binding.add,
          ),
        ),
      ],
    );
  }
}

class _FlagRow extends StatefulWidget {
  const _FlagRow({
    required this.flagKey,
    required this.value,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onRemove,
    super.key,
  });

  final String flagKey;
  final Object? value;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<Object?> onValueChanged;
  final VoidCallback onRemove;

  @override
  State<_FlagRow> createState() => _FlagRowState();
}

class _FlagRowState extends State<_FlagRow> {
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _keyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _keyController.text = widget.flagKey;
    // Commit on focus loss rather than on every keystroke: a partial
    // key like "user_" mid-typing would otherwise overwrite the map
    // key, breaking widget identity and stealing the user's focus.
    _keyFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _keyFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_keyFocusNode.hasFocus) return;
    final next = _keyController.text;
    if (next.isEmpty || next == widget.flagKey) return;
    widget.onKeyChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          SizedBox(
            width: 160,
            child: TextFieldCard.singleLine(
              controller: _keyController,
              focusNode: _keyFocusNode,
              label: 'key',
            ),
          ),
          Expanded(
            child: ObjectValueEditor(
              value: widget.value,
              onChanged: widget.onValueChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _SceneAndFlowSection extends StatefulWidget {
  const _SceneAndFlowSection({
    required this.goal,
    required this.phase,
    required this.sceneTransition,
    required this.onGoalChanged,
    required this.onPhaseChanged,
    required this.onSceneTransitionChanged,
  });

  final String? goal;
  final PhaseEnum? phase;
  final bool sceneTransition;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<PhaseEnum?> onPhaseChanged;
  final ValueChanged<bool> onSceneTransitionChanged;

  @override
  State<_SceneAndFlowSection> createState() => _SceneAndFlowSectionState();
}

class _SceneAndFlowSectionState extends State<_SceneAndFlowSection> {
  final TextEditingController _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _goalController.text = widget.goal ?? '';
    _goalController.onTextChanged(() {
      final text = _goalController.text;
      widget.onGoalChanged(text.isEmpty ? null : text);
    });
  }

  @override
  void didUpdateWidget(_SceneAndFlowSection old) {
    super.didUpdateWidget(old);
    final asText = widget.goal ?? '';
    if (_goalController.text != asText) _goalController.text = asText;
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        children: [
          const Text('Scene & flow'),
          if (_isSet) ...[
            const SizedBox(width: 8),
            _CountBadge(_setCount),
          ],
        ],
      ),
      tilePadding: _kExpansionTilePadding,
      childrenPadding: _kExpansionChildrenPadding,
      children: [
        TextFieldCard.singleLine(
          controller: _goalController,
          label: 'goalChange (clears the current goal when empty)',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              const SizedBox(width: 110, child: Text('phaseChange')),
              SizedBox(
                width: 200,
                child: DropdownButton<PhaseEnum?>(
                  isExpanded: true,
                  value: widget.phase,
                  hint: const Text('(none)'),
                  items: [
                    const DropdownMenuItem<PhaseEnum?>(
                      child: Text('(none)'),
                    ),
                    for (final p in PhaseEnum.values)
                      DropdownMenuItem<PhaseEnum?>(
                        value: p,
                        child: Text(p.name),
                      ),
                  ],
                  onChanged: widget.onPhaseChanged,
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('sceneTransition'),
          subtitle: const Text(
            'When true, the engine marks the firing as a scene shift.',
          ),
          value: widget.sceneTransition,
          onChanged: widget.onSceneTransitionChanged,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  bool get _isSet =>
      (widget.goal != null && widget.goal!.isNotEmpty) ||
      widget.phase != null ||
      widget.sceneTransition;

  int get _setCount =>
      ((widget.goal != null && widget.goal!.isNotEmpty) ? 1 : 0) +
      (widget.phase != null ? 1 : 0) +
      (widget.sceneTransition ? 1 : 0);
}

class _SpawnsSection extends StatelessWidget {
  const _SpawnsSection({
    required this.spawns,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  final List<Node> spawns;
  final VoidCallback onAdd;
  final ValueChanged<Node> onOpen;
  final ValueChanged<Node> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Spawns'),
        for (final spawn in spawns)
          _SpawnRow(
            key: ValueKey(identityHashCode(spawn)),
            spawn: spawn,
            onOpen: () => onOpen(spawn),
            onDelete: () => onDelete(spawn),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add spawn'),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

class _SpawnRow extends StatelessWidget {
  const _SpawnRow({
    required this.spawn,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final Node spawn;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        spawn.id,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TagChip(label: spawn.type.name),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDelete,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PredicateField extends StatelessWidget {
  const _PredicateField({required this.controller, required this.problems});

  final TextEditingController controller;
  final ValueListenable<List<String>> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldCard.multiLine(
          controller: controller,
          label: 'Predicate',
        ),
        ValueListenableBuilder<List<String>>(
          valueListenable: problems,
          builder: (context, list, _) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final problem in list)
                    Text(
                      '• $problem',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
