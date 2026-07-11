import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/node_editor_form.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/editor/src/pages/widgets/node_list_tile.dart';
import 'package:cardwave/editor/src/pages/widgets/nodes_canvas_page.dart';
import 'package:cardwave/editor/src/pages/widgets/nodes_raw_editor_page.dart';
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

  /// Shape of generated node ids; the number feeds the enumeration in
  /// [_createNode].
  static final RegExp _generatedIdPattern = RegExp(r'^node_(\d+)$');

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
    _loadSeedControllers();

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

  /// Copies the engine-seed fields from [_extension] into their text
  /// controllers. Runs on first build and after a raw-editor save so the
  /// structured form mirrors the loaded extension.
  void _loadSeedControllers() {
    _goalController.text = _extension.initialGoal;
    final scene = _extension.initialScene ?? Scene();
    _locationController.text = scene.location;
    _timeOfDayController.text = scene.timeOfDay;
    _presentEntitiesController.text = scene.presentEntities.join(', ');
    _sensoryHooksController.text = scene.sensoryHooks.join(', ');
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
    _createNode();
    setState(() {});
  }

  /// Appends a fresh authored node with the default field values and
  /// returns its id. Used both by the Add Node button and by the
  /// per-node form's "Add new spawn", which needs the id to link it.
  ///
  /// Ids enumerate: one past the largest `node_<number>` already on the
  /// card. Hand-written ids without that shape are ignored by the scan.
  String _createNode() {
    var maxNumber = 0;
    for (final node in _extension.authoredNodes) {
      final match = _generatedIdPattern.firstMatch(node.id);
      if (match == null) continue;
      final number = int.parse(match.group(1)!);
      if (number > maxNumber) maxNumber = number;
    }
    final id = 'node_${maxNumber + 1}';
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
    return id;
  }

  Future<void> _deleteNodeById(String nodeId) async {
    final controller = context.read<EditorPageController>();
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await controller.confirmDelete(
      title: t.editor.editorNodes.deleteNodeTitle,
      message: t.editor.editorNodes.deleteNodeMessage,
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    final index = _indexOfNode(nodeId);
    if (index < 0) return;
    final removed = _extension.authoredNodes[index];
    setState(() {
      _extension.authoredNodes.removeAt(index);
      // Links toward the deleted node die with it — a stale id would
      // otherwise dangle and silently revive if its number is reused.
      for (var i = 0; i < _extension.authoredNodes.length; i++) {
        final other = _extension.authoredNodes[i];
        if (!other.spawnIds.contains(removed.id)) continue;
        _extension.authoredNodes[i] = _copyNode(
          other,
          spawnIds:
              other.spawnIds.where((id) => id != removed.id).toList(),
        );
      }
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

  Future<void> _openNodeEditor(Node node) {
    return showNodeEditorDialog(
      context,
      node: node,
      characterId: widget.characterFile.appCardId,
      allNodes: _extension.authoredNodes,
      onCreateSpawn: _createNode,
      onOpenNode: _openNodeById,
      // Lookup by `id` is the stable key: ids are generated once and
      // never change (the author edits the free-text `name` instead), so
      // a string match always finds the same entry even after reorder.
      onUpdated: (updated) => _onNodeUpdated(node.id, updated),
    );
  }

  Future<void> _openNodeById(String nodeId) {
    for (final node in _extension.authoredNodes) {
      if (node.id == nodeId) return _openNodeEditor(node);
    }
    return Future.value();
  }

  Future<void> _openCanvasPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => NodesCanvasPage(
          nodes: _extension.authoredNodes,
          onPositionChanged: _onNodeMoved,
          onLink: _onLinkSpawn,
          onUnlink: _onUnlinkSpawn,
          onEditNode: _openNodeById,
          onDeleteNode: _deleteNodeById,
          onAddNode: () => _createNode(),
        ),
      ),
    );
    // Nodes added or relinked on the canvas must show in the list when
    // the author comes back.
    if (mounted) setState(() {});
  }

  // --- Canvas edits ---

  void _onNodeMoved(String nodeId, double x, double y) {
    final idx = _indexOfNode(nodeId);
    if (idx < 0) return;
    _extension.authoredNodes[idx] = _copyNode(
      _extension.authoredNodes[idx],
      visualEditor: VisualEditorSection(x: x, y: y),
    );
    _persist();
  }

  void _onLinkSpawn(String sourceId, String targetId) {
    final idx = _indexOfNode(sourceId);
    if (idx < 0) return;
    final source = _extension.authoredNodes[idx];
    if (source.spawnIds.contains(targetId)) return;
    _extension.authoredNodes[idx] =
        _copyNode(source, spawnIds: [...source.spawnIds, targetId]);
    _persist();
    setState(() {});
  }

  void _onUnlinkSpawn(String sourceId, String targetId) {
    final idx = _indexOfNode(sourceId);
    if (idx < 0) return;
    final source = _extension.authoredNodes[idx];
    _extension.authoredNodes[idx] = _copyNode(
      source,
      spawnIds: source.spawnIds.where((id) => id != targetId).toList(),
    );
    _persist();
    setState(() {});
  }

  int _indexOfNode(String nodeId) =>
      _extension.authoredNodes.indexWhere((n) => n.id == nodeId);

  void _onNodeUpdated(String nodeId, Node updated) {
    final idx =
        _extension.authoredNodes.indexWhere((n) => n.id == nodeId);
    if (idx < 0) return;
    _extension.authoredNodes[idx] = updated;
    _persist();
    setState(() {});
  }

  void _openRawEditor() {
    final initialJson = const JsonEncoder.withIndent('  ')
        .convert(_strippedExtension(withEmptyScene: true).toJson());
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => NodesRawEditorPage(
          initialJson: initialJson,
          onSaved: _onRawSaved,
        ),
      ),
    ));
  }

  /// Applies a raw-editor save. The raw page hands back a parsed
  /// extension; this writes it through the panel's own persist path and
  /// re-seeds the form's text controllers so the structured view matches
  /// what was just saved.
  void _onRawSaved(CardNodesExtension cleaned) {
    _extension = cleaned;
    _persist();
    _loadExtension();
    _loadSeedControllers();
    setState(() {});
  }

  /// The extension as written to the card: a copy with each node's runtime
  /// countdown fields reset. [withEmptyScene] forces a non-null initial
  /// scene (an empty [Scene] when the card has none) so the raw editor
  /// shows the complete structure; the persist path passes the scene
  /// through unchanged.
  CardNodesExtension _strippedExtension({bool withEmptyScene = false}) =>
      CardNodesExtension(
        authoredNodes: _extension.authoredNodes.map(_stripRuntime).toList(),
        emotionBaseline: _extension.emotionBaseline,
        initialGoal: _extension.initialGoal,
        initialScene: withEmptyScene
            ? (_extension.initialScene ?? Scene())
            : _extension.initialScene,
      );

  void _persist() {
    final stripped = _strippedExtension();
    if (_hasContent(stripped)) {
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
          title: Row(
            children: [
              Text(t.editor.editorNodes.engineSeedTitle),
              const Spacer(),
              IconButton(
                key: const Key('editor-nodes-canvas-button'),
                tooltip: t.editor.editorNodes.visualEditorTooltip,
                icon: const Icon(Icons.account_tree),
                onPressed: () => unawaited(_openCanvasPage()),
              ),
              IconButton(
                key: const Key('editor-nodes-raw-button'),
                tooltip: t.editor.editorNodes.editJsonTooltip,
                icon: const Icon(Icons.data_object),
                onPressed: _openRawEditor,
              ),
            ],
          ),
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
                  label: t.editor.editorNodes.initialGoalLabel,
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
                _SectionLabel(t.editor.editorNodes.initialSceneLabel),
                TextFieldCard.singleLine(
                  controller: _locationController,
                  label: t.editor.editorNodes.locationLabel,
                ),
                TextFieldCard.singleLine(
                  controller: _timeOfDayController,
                  label: t.editor.editorNodes.timeOfDayLabel,
                ),
                TextFieldCard.singleLine(
                  controller: _presentEntitiesController,
                  label: t.editor.editorNodes.presentEntitiesLabel,
                ),
                TextFieldCard.singleLine(
                  controller: _sensoryHooksController,
                  label: t.editor.editorNodes.sensoryHooksLabel,
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
              label: Text(t.editor.editorNodes.addNodeButton),
            ),
          ),
        ),
        if (nodes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(t.editor.editorNodes.noAuthoredNodesYet),
            ),
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
                  onTap: () => unawaited(_openNodeEditor(nodes[i])),
                  onDelete: () => unawaited(_deleteNodeById(nodes[i].id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Returns a copy of [node] with canvas position and/or spawn links
/// replaced. Used by the canvas view's drag and link edits. All other
/// fields, including runtime counters, pass through unchanged (`_persist`
/// strips runtime on save).
Node _copyNode(
  Node node, {
  VisualEditorSection? visualEditor,
  List<String>? spawnIds,
}) =>
    Node(
      id: node.id,
      name: node.name,
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
      spawnIds: spawnIds ?? node.spawnIds,
      visualEditor: visualEditor ?? node.visualEditor,
    );

/// Returns a copy of [node] with runtime countdown fields reset to
/// constructor defaults so the saved JSON looks like a freshly
/// authored node (runtime state must not leak into the authored card).
/// Spawn links and canvas position are authoring data and pass through.
Node _stripRuntime(Node node) {
  return Node(
    id: node.id,
    name: node.name,
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
    spawnIds: node.spawnIds,
    visualEditor: node.visualEditor,
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
              t.editor.editorNodes.loadErrorMessage(n: errors.length),
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
                  t.editor.editorNodes.moreErrorsSuffix(
                    n: errors.length - 5,
                  ),
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
            t.editor.editorNodes.emotionBaselineLabel,
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
                child: Chip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(t.editor.editorNodes.emotionChipLabel),
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
