import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_alternate_greetings.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_app_data.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_basic.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_creator_metadata.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_group_greetings.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_lorebook.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_nodes.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_prompts.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_scrollable_panel.dart';
import 'package:cardwave/editor/src/pages/widgets/panel_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

part 'editor_view_panel_navigation_rail.dart';

class EditorView extends StatefulWidget {
  const EditorView({
    required this.characterFile,
    required this.selectedPanel,
    required this.onPanelChanged,
    super.key,
  });
  final CharacterFile characterFile;
  final PanelEnum selectedPanel;
  final ValueChanged<PanelEnum> onPanelChanged;

  @override
  State<EditorView> createState() => EditorViewState();
}

class EditorViewState extends State<EditorView> {
  int _editorVersion = 0;
  bool _isAdvancedMode = false;
  ValueNotifier<({String appCardId, int counter})?>? _mutationNotifier;

  @override
  void initState() {
    super.initState();
    // Subscribe to external card mutations (assistant-chat card-edit tool
    // calls that landed). Reference captured into a field so dispose can
    // detach without `context.read`, which is unsafe during teardown.
    _mutationNotifier = context.read<CharacterService>().externalCardMutation
      ..addListener(_onExternalCardMutation);
  }

  @override
  void dispose() {
    _mutationNotifier?.removeListener(_onExternalCardMutation);
    super.dispose();
  }

  void _onExternalCardMutation() {
    if (!mounted) return;
    final v = _mutationNotifier?.value;
    if (v?.appCardId != widget.characterFile.appCardId) return;
    setState(() {
      _editorVersion++;
    });
  }

  void _triggerJsonCacheAutoSave() {
    context.read<CharacterService>().queueJsonInCacheDebounced(
      widget.characterFile,
    );
  }

  // Reached via GlobalKey<EditorViewState> from the parent route.
  // ignore: qcheck/prefer_widget_private_members
  void applyCleaner(String Function(String) processor) {
    if (!mounted) return;
    // Snapshot the whole card before the bulk transform. The editor has no
    // general undo, and find/replace + content-cleaner actions touch every
    // field (name, description, tags, lorebook), so a mistaken run — e.g. an
    // empty-find replace — would otherwise be unrecoverable. Both callers
    // funnel through here, so this single snapshot covers all of them.
    final snapshot = jsonEncode(widget.characterFile.card.toJson());
    widget.characterFile.card.transformAllStrings(processor);
    _editorVersion++;
    _triggerJsonCacheAutoSave();
    setState(() {});
    _offerUndo(snapshot);
  }

  /// Shows a snackbar with an Undo action that restores the card from
  /// [snapshot] (a `jsonEncode`d card taken before a bulk transform),
  /// re-keying the panels and autosaving the restored state.
  void _offerUndo(String snapshot) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.editor.contentTransform.appliedSnackbar),
        action: SnackBarAction(
          label: t.editor.contentTransform.undoButton,
          onPressed: () {
            if (!mounted) return;
            widget.characterFile.card = CharacterCardV3.fromJson(
              jsonDecode(snapshot) as Map<String, dynamic>,
            );
            _editorVersion++;
            _triggerJsonCacheAutoSave();
            setState(() {});
          },
        ),
      ),
    );
  }

  // Reached via GlobalKey<EditorViewState> from the parent route.
  // ignore: qcheck/prefer_widget_private_members
  Future<void> runGlobalAiAction(AiActionEnum action) async {
    final newCard = await context
        .read<EditorPageController>()
        .proposeAndConfirmGlobalAiAction(action);
    if (newCard == null || !mounted) return;
    widget.characterFile.card = newCard;
    _editorVersion++;
    _triggerJsonCacheAutoSave();
    setState(() {});
  }

  // A switch returning per-panel trees; reads four mutable EditorViewState
  // fields + setState + a sibling — a widget class would re-thread all of
  // it for no rebuild-boundary gain.
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildEditorPanels() {
    final panel = widget.selectedPanel;

    switch (panel) {
      case PanelEnum.lorebook:
        return Expanded(
          key: ValueKey(_editorVersion),
          child: LorebookEditorWidget(
            characterFile: widget.characterFile,
            isAdvancedMode: _isAdvancedMode,
            onAdvancedModeToggled: (v) => setState(() => _isAdvancedMode = v),
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.nodes:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorNodes(
            characterFile: widget.characterFile,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.basic:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorBasic(
            characterFile: widget.characterFile,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.creatorMetadata:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorCreatorMetadata(
            characterFile: widget.characterFile,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.prompts:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorPrompts(
            characterFile: widget.characterFile,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.greetings:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorAlternateGreetings(
            characterCard: widget.characterFile.card,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.groupSettings:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorGroupGreetings(
            characterCard: widget.characterFile.card,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
      case PanelEnum.appData:
        return EditorScrollablePanel(
          panel: panel,
          editorVersion: _editorVersion,
          content: EditorAppData(
            characterFile: widget.characterFile,
            onChanged: _triggerJsonCacheAutoSave,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppConstants.tabletBreakpoint;

        if (isWide) {
          ///
          /// Desktop
          ///
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PanelNavigationRail(
                      selected: widget.selectedPanel,
                      onSelectionChanged: widget.onPanelChanged,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    _buildEditorPanels(),
                  ],
                ),
              ),
            ],
          );
        }

        ///
        /// Smaller than Desktop
        ///
        return Column(
          children: [
            _PanelNavigationTabs(
              selected: widget.selectedPanel,
              onSelectionChanged: widget.onPanelChanged,
            ),
            _buildEditorPanels(),
          ],
        );
      },
    );
  }
}

class _PanelNavigationTabs extends StatelessWidget {
  const _PanelNavigationTabs({
    required this.selected,
    required this.onSelectionChanged,
  });
  final PanelEnum selected;
  final ValueChanged<PanelEnum> onSelectionChanged;

  static const List<PanelEnum> _panels = [
    PanelEnum.basic,
    PanelEnum.greetings,
    PanelEnum.prompts,
    PanelEnum.lorebook,
    PanelEnum.groupSettings,
    PanelEnum.creatorMetadata,
    PanelEnum.appData,
    PanelEnum.nodes,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    var selectedIndex = _panels.indexOf(selected);
    if (selectedIndex == -1) selectedIndex = 0;

    return DefaultTabController(
      key: ValueKey(selected),
      length: _panels.length,
      initialIndex: selectedIndex,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        // TabBar only calls `onTap` with `index` in `[0, length)`.
        // ignore: qcheck/avoid_unsafe_collection_methods
        onTap: (index) => onSelectionChanged(_panels[index]),
        tabs: [
          Tab(text: t.editor.panelLabels.basic),
          Tab(text: t.editor.panelLabels.greetings),
          Tab(text: t.editor.panelLabels.prompts),
          Tab(text: t.editor.panelLabels.lorebook),
          Tab(text: t.editor.panelLabels.group),
          Tab(text: t.editor.panelLabels.creator),
          Tab(text: t.editor.panelLabels.appData),
          Tab(text: t.editor.panelLabels.nodes),
        ],
      ),
    );
  }
}
