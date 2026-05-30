import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';

/// Editor panel for a card's `cardwave_nodes` extension block: the
/// engine seed (initial goal, scene, emotion baseline), the list of
/// authored nodes, and the per-node editor opened via tap on a list row.
///
/// This step ships the engine-seed section end-to-end. The node list
/// and per-node editor arrive in subsequent steps.
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
  late CardNodesExtension _extension;
  late List<CardExtensionLoadError> _loadErrors;

  late final TextEditingController _goalController;
  late final TextEditingController _locationController;
  late final TextEditingController _timeOfDayController;
  late final TextEditingController _presentEntitiesController;
  late final TextEditingController _sensoryHooksController;

  /// Which emotion currently has its inline-slider expanded. Tap the
  /// chip again to collapse.
  EmotionEnum? _expandedBaseline;

  @override
  void initState() {
    super.initState();
    _loadExtension();
    _goalController = TextEditingController(text: _extension.initialGoal);
    final scene = _extension.initialScene ?? Scene();
    _locationController = TextEditingController(text: scene.location);
    _timeOfDayController = TextEditingController(text: scene.timeOfDay);
    _presentEntitiesController =
        TextEditingController(text: scene.presentEntities.join(', '));
    _sensoryHooksController =
        TextEditingController(text: scene.sensoryHooks.join(', '));

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

  void _persist() {
    if (_hasContent(_extension)) {
      widget.characterFile.card.extensions[nodesCardExtensionKey] = _extension.toJson();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (_loadErrors.isNotEmpty) _LoadErrorBanner(errors: _loadErrors),
          const _SectionHeader('Engine seed'),
          TextFieldCard.singleLine(
            controller: _goalController,
            label: 'Initial goal',
          ),
          _BaselineSection(
            baseline: _extension.emotionBaseline,
            remaining: remainingEmotions,
            expanded: _expandedBaseline,
            onChipTapped: (e) => setState(
              () => _expandedBaseline = _expandedBaseline == e ? null : e,
            ),
            onValueChanged: _setBaseline,
            onRemove: _removeBaseline,
            onAdd: _addBaseline,
          ),
          const _SectionHeader('Initial scene'),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

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
