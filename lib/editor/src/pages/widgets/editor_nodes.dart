import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/node_editor_page.dart';
import 'package:cardwave/editor/src/pages/widgets/node_list_tile.dart';
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Editor panel for a card's `cardwave_nodes` extension block: the
/// engine seed (initial goal, scene, emotion baseline), the list of
/// authored nodes, and the per-node editor opened via tap on a list
/// row.
///
/// This step adds the node list + per-node editor (basic fields,
/// predicate, narrative payload). Effects sub-forms and spawns
/// arrive in subsequent steps.
class EditorNodes extends StatefulWidget {
  const EditorNodes({
    required this.characterFile,
    required this.onChanged,
    super.key,
  });

  final CharacterFile characterFile;
  final VoidCallback onChanged;

  @override
  State<EditorNodes> createState() => _EditorNodesState();
}

class _EditorNodesState extends State<EditorNodes> {
  /// Default starting `triggerProb` for a freshly-added node. 1.0 so
  /// the node fires every turn it is eligible, matching the most
  /// common authoring intent (the author can lower it afterward).
  static const double _newNodeTriggerProb = 1.0;

  /// Default `alive` for a freshly-added node. -1 means the node stays
  /// in the pool forever unless explicitly removed; safest default
  /// for handcrafted content.
  static const int _newNodeAlive = -1;

  late CardNodesExtension _extension;
  late List<CardExtensionLoadError> _loadErrors;

  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _timeOfDayController = TextEditingController();
  final TextEditingController _presentEntitiesController =
      TextEditingController();
  final TextEditingController _sensoryHooksController = TextEditingController();

  /// Which emotion currently has its inline-slider expanded. Tap the
  /// chip again to collapse.
  EmotionEnum? _expandedBaseline;

  @override
  void initState() {
    super.initState();
    _loadExtension();
    _goalController.text = _extension.initialGoal;
    final scene = _extension.initialScene ?? Scene();
    _locationController.text = scene.location;
    _timeOfDayController.text = scene.timeOfDay;
    _presentEntitiesController.text = scene.presentEntities.join(', ');
    _sensoryHooksController.text = scene.sensoryHooks.join(', ');

    _goalController.onTextChanged(_onGoalChanged);
    _locationController.onTextChanged(_onSceneChanged);
    _timeOfDayController.onTextChanged(_onSceneChanged);
    _presentEntitiesController.onTextChanged(_onSceneChanged);
    _sensoryHooksController.onTextChanged(_onSceneChanged);
  }

  @override
  void dispose() {
    _goalController.dispose();
    _locationController.dispose();
    _timeOfDayController.dispose();
    _presentEntitiesController.dispose();
    _sensoryHooksController.dispose();
    super.dispose();
  }

  void _loadExtension() {
    final raw = widget.characterFile.card.extensions[nodesCardExtensionKey];
    if (raw is Map<String, dynamic>) {
      final result = loadCardNodesExtension(raw);
      _extension = result.extension;
      _loadErrors = result.errors;
    } else {
      _extension = CardNodesExtension();
      _loadErrors = const [];
    }
  }

  void _onGoalChanged() {
    _extension = CardNodesExtension(
      authoredNodes: _extension.authoredNodes,
      emotionBaseline: _extension.emotionBaseline,
      initialGoal: _goalController.text,
      initialScene: _extension.initialScene,
    );
    _persist();
  }

  void _onSceneChanged() {
    final presentEntities = _parseCsv(_presentEntitiesController.text);
    final sensoryHooks = _parseCsv(_sensoryHooksController.text);
    final hasContent = _locationController.text.isNotEmpty ||
        _timeOfDayController.text.isNotEmpty ||
        presentEntities.isNotEmpty ||
        sensoryHooks.isNotEmpty;
    Scene? scene;
    if (hasContent) {
      scene = _extension.initialScene ?? Scene();
      scene.location = _locationController.text;
      scene.timeOfDay = _timeOfDayController.text;
      scene.presentEntities = presentEntities;
      scene.sensoryHooks = sensoryHooks;
    }
    _extension = CardNodesExtension(
      authoredNodes: _extension.authoredNodes,
      emotionBaseline: _extension.emotionBaseline,
      initialGoal: _extension.initialGoal,
      initialScene: scene,
    );
    _persist();
  }

  void _setBaseline(EmotionEnum emotion, double value) {
    _extension.emotionBaseline[emotion] = value;
    _persist();
    setState(() {});
  }

  void _addBaseline(EmotionEnum emotion) {
    _extension.emotionBaseline[emotion] = 0.0;
    _persist();
    setState(() {
      _expandedBaseline = emotion;
    });
  }

  void _removeBaseline(EmotionEnum emotion) {
    _extension.emotionBaseline.remove(emotion);
    _persist();
    setState(() {
      if (_expandedBaseline == emotion) _expandedBaseline = null;
    });
  }

  void _addNode() {
    final id = 'node_${DateTime.now().millisecondsSinceEpoch}';
    final node = Node(
      id: id,
      origin: NodeOriginEnum.authored,
      type: NodeTypeEnum.characterBehavior,
      triggerProb: _newNodeTriggerProb,
      delay: 0,
      cooldown: 0,
      sticky: 0,
      alive: _newNodeAlive,
      scope: NodeScopeEnum.session,
      predicate: 'true',
      narrativePayload: '',
    );
    _extension.authoredNodes.add(node);
    _persist();
    setState(() {});
  }

  Future<void> _deleteNode(int index) async {
    final controller = context.read<EditorPageController>();
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await controller.confirmDelete(
      title: 'Delete node',
      message: 'Remove this authored node from the card?',
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _extension.authoredNodes.removeAt(index);
    });
    _persist();
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final node = _extension.authoredNodes.removeAt(oldIndex);
      _extension.authoredNodes.insert(newIndex, node);
    });
    _persist();
  }

  void _openNodeEditor(Node node) {
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => NodeEditorPage(
          node: node,
          characterId: widget.characterFile.appCardId,
          // Lookup by `id` is the stable key: the editor cannot
          // change a node's id (it is shown read-only), so a string
          // match always finds the same entry even after reorder.
          onUpdated: (updated) => _onNodeUpdated(node.id, updated),
        ),
      ),
    ));
  }

  void _onNodeUpdated(String nodeId, Node updated) {
    final idx =
        _extension.authoredNodes.indexWhere((n) => n.id == nodeId);
    if (idx < 0) return;
    _extension.authoredNodes[idx] = updated;
    _persist();
    setState(() {});
  }

  void _persist() {
    if (_hasContent(_extension)) {
      final stripped = CardNodesExtension(
        authoredNodes:
            _extension.authoredNodes.map(_stripRuntime).toList(),
        emotionBaseline: _extension.emotionBaseline,
        initialGoal: _extension.initialGoal,
        initialScene: _extension.initialScene,
      );
      widget.characterFile.card.extensions[nodesCardExtensionKey] =
          stripped.toJson();
    } else {
      widget.characterFile.card.extensions.remove(nodesCardExtensionKey);
    }
    widget.onChanged();
  }

  /// Whether the extension carries anything worth writing back. Avoids
  /// stamping an empty `cardwave_nodes` key onto cards that never had
  /// one (a cleared-out engine seed reverts to the missing-key shape).
  bool _hasContent(CardNodesExtension ext) {
    if (ext.authoredNodes.isNotEmpty) return true;
    if (ext.emotionBaseline.isNotEmpty) return true;
    if (ext.initialGoal.isNotEmpty) return true;
    final scene = ext.initialScene;
    if (scene == null) return false;
    return scene.location.isNotEmpty ||
        scene.timeOfDay.isNotEmpty ||
        scene.presentEntities.isNotEmpty ||
        scene.sensoryHooks.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final remainingEmotions = EmotionEnum.values
        .where((e) => !_extension.emotionBaseline.containsKey(e))
        .toList();
    final nodes = _extension.authoredNodes;
    // Horizontal padding inside this panel is intentionally zero —
    // `EditorScrollablePanel` (the parent in `editor_view.dart`) adds
    // the outer horizontal padding and centers within a max width. Any
    // padding added here would double up against that.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadErrors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LoadErrorBanner(errors: _loadErrors),
          ),
        ExpansionTile(
          title: const Text('Engine seed'),
          initiallyExpanded: nodes.isEmpty,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                TextFieldCard.singleLine(
                  controller: _goalController,
                  label: 'Initial goal',
                ),
                _BaselineSection(
                  baseline: _extension.emotionBaseline,
                  remaining: remainingEmotions,
                  expanded: _expandedBaseline,
                  onChipTapped: (e) => setState(
                    () =>
                        _expandedBaseline = _expandedBaseline == e ? null : e,
                  ),
                  onValueChanged: _setBaseline,
                  onRemove: _removeBaseline,
                  onAdd: _addBaseline,
                ),
                const _SectionLabel('Initial scene'),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextFieldCard.singleLine(
                        controller: _locationController,
                        label: 'Location',
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextFieldCard.singleLine(
                        controller: _timeOfDayController,
                        label: 'Time of day',
                      ),
                    ),
                  ],
                ),
                TextFieldCard.singleLine(
                  controller: _presentEntitiesController,
                  label: 'Present (comma-separated)',
                ),
                TextFieldCard.singleLine(
                  controller: _sensoryHooksController,
                  label: 'Sensory hooks (comma-separated)',
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const Key('editor-nodes-add-button'),
              onPressed: _addNode,
              icon: const Icon(Icons.add),
              label: const Text('Add Node'),
            ),
          ),
        ),
        if (nodes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No authored nodes yet.')),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _onReorderItem,
            children: [
              for (int i = 0; i < nodes.length; i++)
                NodeListTile(
                  key: ValueKey(identityHashCode(nodes[i])),
                  node: nodes[i],
                  index: i,
                  onTap: () => _openNodeEditor(nodes[i]),
                  onDelete: () => unawaited(_deleteNode(i)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Returns a copy of [node] with runtime countdown fields reset to
/// constructor defaults so the saved JSON looks like a freshly
/// authored node (per plan: runtime state must not leak into the
/// authored card). Recurses into `spawns`.
Node _stripRuntime(Node node) {
  return Node(
    id: node.id,
    origin: node.origin,
    type: node.type,
    triggerProb: node.triggerProb,
    delay: node.delay,
    cooldown: node.cooldown,
    sticky: node.sticky,
    alive: node.alive,
    scope: node.scope,
    predicate: node.predicate,
    narrativePayload: node.narrativePayload,
    effects: node.effects,
    spawns: node.spawns.map(_stripRuntime).toList(),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.errors});

  final List<CardExtensionLoadError> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This card\'s nodes block has ${errors.length} problem'
              '${errors.length == 1 ? '' : 's'}; editing here will '
              'overwrite the broken parts on save.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            for (final error in errors.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• $error',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            if (errors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '… ${errors.length - 5} more',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BaselineSection extends StatelessWidget {
  const _BaselineSection({
    required this.baseline,
    required this.remaining,
    required this.expanded,
    required this.onChipTapped,
    required this.onValueChanged,
    required this.onRemove,
    required this.onAdd,
  });

  final Map<EmotionEnum, double> baseline;
  final List<EmotionEnum> remaining;
  final EmotionEnum? expanded;
  final ValueChanged<EmotionEnum> onChipTapped;
  final void Function(EmotionEnum, double) onValueChanged;
  final ValueChanged<EmotionEnum> onRemove;
  final ValueChanged<EmotionEnum> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Emotion baseline',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in baseline.entries)
              InputChip(
                label: Text(
                  '${entry.key.name} ${entry.value.toStringAsFixed(2)}',
                ),
                selected: expanded == entry.key,
                onPressed: () => onChipTapped(entry.key),
                onDeleted: () => onRemove(entry.key),
              ),
            if (remaining.isNotEmpty)
              PopupMenuButton<EmotionEnum>(
                onSelected: onAdd,
                itemBuilder: (context) => [
                  for (final e in remaining)
                    PopupMenuItem(value: e, child: Text(e.name)),
                ],
                child: const Chip(
                  avatar: Icon(Icons.add, size: 18),
                  label: Text('Emotion'),
                ),
              ),
          ],
        ),
        if (expanded != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _BaselineSlider(
              emotion: expanded!,
              value: baseline[expanded!] ?? 0.0,
              onChanged: (v) => onValueChanged(expanded!, v),
            ),
          ),
      ],
    );
  }
}

class _BaselineSlider extends StatelessWidget {
  const _BaselineSlider({
    required this.emotion,
    required this.value,
    required this.onChanged,
  });

  final EmotionEnum emotion;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(emotion.name),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

List<String> _parseCsv(String input) => input
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();
