import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/pages/widgets/dropdown_labeled.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

part 'lorebook_entry_editor_page_top_section.dart';
part 'lorebook_entry_editor_page_scan_row.dart';

class EntryControllers {
  EntryControllers({
    required String? comment,
    required List<String> keys,
    required List<String> secondaryKeys,
    required String? content,
    required int? order,
    required int? probability,
    required int? scanDepth,
    required String? group,
    required int? groupWeight,
    required int? sticky,
    required int? cooldown,
    required int? delay,
    required String? automationId,
    required int? depth,
    required List<String> triggers,
    required List<String>? characterFilterNames,
  }) : comment = TextEditingController(text: comment),
       keys = TextEditingController(text: keys.join(', ')),
       secondaryKeys = TextEditingController(text: secondaryKeys.join(', ')),
       content = TextEditingController(text: content),
       order = TextEditingController(text: order?.toString()),
       probability = TextEditingController(text: probability?.toString()),
       scanDepth = TextEditingController(text: scanDepth?.toString()),
       group = TextEditingController(text: group),
       groupWeight = TextEditingController(text: groupWeight?.toString()),
       sticky = TextEditingController(text: sticky?.toString()),
       cooldown = TextEditingController(text: cooldown?.toString()),
       delay = TextEditingController(text: delay?.toString()),
       automationId = TextEditingController(text: automationId),
       depth = TextEditingController(text: depth?.toString()),
       triggers = TextEditingController(text: triggers.join(', ')),
       characterFilter = TextEditingController(
         text: characterFilterNames?.join(', '),
       );
  final TextEditingController comment;
  final TextEditingController keys;
  final TextEditingController secondaryKeys;
  final TextEditingController content;
  final TextEditingController order;
  final TextEditingController probability;
  final TextEditingController scanDepth;
  final TextEditingController group;
  final TextEditingController groupWeight;
  final TextEditingController sticky;
  final TextEditingController cooldown;
  final TextEditingController delay;
  final TextEditingController automationId;
  final TextEditingController depth;
  final TextEditingController triggers;
  final TextEditingController characterFilter;

  void dispose() {
    comment.dispose();
    keys.dispose();
    secondaryKeys.dispose();
    content.dispose();
    order.dispose();
    probability.dispose();
    scanDepth.dispose();
    group.dispose();
    groupWeight.dispose();
    sticky.dispose();
    cooldown.dispose();
    delay.dispose();
    automationId.dispose();
    depth.dispose();
    triggers.dispose();
    characterFilter.dispose();
  }
}

class LorebookEntryEditorPage extends StatefulWidget {
  const LorebookEntryEditorPage({
    required this.entry,
    required this.contextCard,
    required this.isAdvancedMode,
    required this.onAdvancedModeToggled,
    required this.onChanged,
    super.key,
  });
  final LorebookEntry entry;
  final CharacterCardV3 contextCard;
  final bool isAdvancedMode;
  final ValueChanged<bool> onAdvancedModeToggled;
  final VoidCallback onChanged;

  @override
  State<LorebookEntryEditorPage> createState() =>
      _LorebookEntryEditorPageState();
}

class _LorebookEntryEditorPageState extends State<LorebookEntryEditorPage> {
  EntryControllers? _controllers;
  late bool _isAdvancedMode;

  @override
  void initState() {
    super.initState();
    _isAdvancedMode = widget.isAdvancedMode;
    _controllers = _createEntryController(widget.entry);
  }

  @override
  void didUpdateWidget(covariant LorebookEntryEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry != oldWidget.entry) {
      _controllers?.dispose();
      _controllers = _createEntryController(widget.entry);
    }
    if (widget.isAdvancedMode != oldWidget.isAdvancedMode) {
      _isAdvancedMode = widget.isAdvancedMode;
    }
  }

  @override
  void dispose() {
    _controllers?.dispose();
    super.dispose();
  }

  List<String> _splitKeywordsAndRegexes(String input) {
    final result = <String>[];
    var insideRegex = false;
    final currentToken = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '/' && (i == 0 || input[i - 1] != r'\')) {
        insideRegex = !insideRegex;
        currentToken.write(char);
      } else if (char == ',' && !insideRegex) {
        final token = currentToken.toString().trim();
        if (token.isNotEmpty) result.add(token);
        currentToken.clear();
      } else {
        currentToken.write(char);
      }
    }
    final lastToken = currentToken.toString().trim();
    if (lastToken.isNotEmpty) result.add(lastToken);
    return result;
  }

  void _onTextChanged(LorebookEntry entry, EntryControllers controllers) {
    entry.comment = controllers.comment.text;
    entry.keys = _splitKeywordsAndRegexes(controllers.keys.text);
    entry.secondaryKeys = _splitKeywordsAndRegexes(
      controllers.secondaryKeys.text,
    );
    entry.content = controllers.content.text;
    entry.insertionOrder = int.tryParse(controllers.order.text);
    entry.extensions.probability = int.tryParse(controllers.probability.text);
    entry.extensions.scanDepth = int.tryParse(controllers.scanDepth.text);
    entry.extensions.group = controllers.group.text;
    entry.extensions.groupWeight = int.tryParse(controllers.groupWeight.text);
    entry.extensions.sticky = int.tryParse(controllers.sticky.text);
    entry.extensions.cooldown = int.tryParse(controllers.cooldown.text);
    entry.extensions.delay = int.tryParse(controllers.delay.text);
    entry.extensions.automationId = controllers.automationId.text;
    entry.extensions.depth = int.tryParse(controllers.depth.text);
    entry.extensions.triggers = controllers.triggers.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final names = controllers.characterFilter.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (entry.characterFilter != null) {
      entry.characterFilter!.names = names;
    } else {
      entry.characterFilter = CharacterFilter(names: names);
    }
    widget.onChanged();
  }

  EntryControllers _createEntryController(LorebookEntry entry) {
    final controllers = EntryControllers(
      comment: entry.comment,
      keys: entry.keys,
      secondaryKeys: entry.secondaryKeys,
      content: entry.content,
      order: entry.insertionOrder,
      probability: entry.extensions.probability,
      scanDepth: entry.extensions.scanDepth,
      group: entry.extensions.group,
      groupWeight: entry.extensions.groupWeight,
      sticky: entry.extensions.sticky,
      cooldown: entry.extensions.cooldown,
      delay: entry.extensions.delay,
      automationId: entry.extensions.automationId,
      depth: entry.extensions.depth,
      triggers: entry.extensions.triggers,
      characterFilterNames: entry.characterFilter?.names,
    );

    controllers.comment.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.keys.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.secondaryKeys.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.content.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.order.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.probability.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.scanDepth.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.group.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.groupWeight.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.sticky.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.cooldown.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.delay.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.automationId.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.depth.onTextChanged(() => _onTextChanged(entry, controllers));
    controllers.triggers.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );
    controllers.characterFilter.onTextChanged(
      () => _onTextChanged(entry, controllers),
    );

    return controllers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editor.lorebookEntryEditorPage.editEntryTitle),
        actionsPadding: const EdgeInsets.only(right: 16),
        actions: [
          FilterChip(
            label: Text(t.editor.lorebookEntryEditorPage.advancedFilter),
            selected: _isAdvancedMode,
            onSelected: (value) {
              setState(() {
                _isAdvancedMode = value;
              });
              widget.onAdvancedModeToggled(value);
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            _EntryTopSection(
              entry: widget.entry,
              controller: _controllers!,
              onUpdate: () {
                setState(() {});
                widget.onChanged();
              },
            ),
            _EntryKeywordsSection(
              entry: widget.entry,
              controller: _controllers!,
              onUpdate: () {
                setState(() {});
                widget.onChanged();
              },
            ),
            if (_isAdvancedMode)
              _EntryScanRow(
                entry: widget.entry,
                controller: _controllers!,
                onUpdate: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
            _EntryContentSection(
              content: _controllers!.content,
              currentText: () => _controllers!.content.text,
              onApplyAi: aiPopupApply(
                this,
                _controllers!.content,
                'Lorebook Entry Content',
              ),
              contextCard: widget.contextCard,
            ),
            if (_isAdvancedMode) ...[
              _EntryRecursionRow(
                entry: widget.entry,
                onUpdate: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
              _EntryInclusionGroupRow(
                entry: widget.entry,
                controller: _controllers!,
                onUpdate: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
            ],
            _EntryTimedEffectsRow(controller: _controllers!),
            if (_isAdvancedMode) ...[
              _EntryFilterRow(controller: _controllers!),
              _EntryMatchingOptionsRow(
                entry: widget.entry,
                onUpdate: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryKeywordsSection extends StatelessWidget {
  const _EntryKeywordsSection({
    required this.entry,
    required this.controller,
    required this.onUpdate,
  });
  final LorebookEntry entry;
  final EntryControllers controller;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFieldCard.singleLine(
          controller: controller.keys,
          label: t.editor.lorebookEntryEditorPage.primaryKeywordsLabel,
        ),
        DropdownLabeled<int>(
          label: t.editor.lorebookEntryEditorPage.logicLabel,
          value: entry.selectiveLogic ?? 0,
          items: [
            DropdownMenuItem(
              value: 0,
              child: Text(t.editor.lorebookEntryEditorPage.logicAndAny),
            ),
            DropdownMenuItem(
              value: 3,
              child: Text(t.editor.lorebookEntryEditorPage.logicAndAll),
            ),
            DropdownMenuItem(
              value: 2,
              child: Text(t.editor.lorebookEntryEditorPage.logicNotAny),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text(t.editor.lorebookEntryEditorPage.logicNotAll),
            ),
          ],
          onChanged: (value) {
            entry.selectiveLogic = value;
            onUpdate();
          },
        ),
        TextFieldCard.singleLine(
          controller: controller.secondaryKeys,
          label: t.editor.lorebookEntryEditorPage.optionalFilterLabel,
        ),
      ],
    );
  }
}

class _EntryContentSection extends StatelessWidget {
  const _EntryContentSection({
    required this.content,
    required this.currentText,
    required this.onApplyAi,
    required this.contextCard,
  });

  /// The TextEditingController for the field itself. Owned by the parent
  /// [_LorebookEntryEditorPageState] (disposed in its `didUpdateWidget`
  /// when `widget.entry` changes).
  final TextEditingController content;

  /// Read at click time by the AI popup.
  final ValueGetter<String> currentText;

  /// Built via [aiPopupApply] in the parent State so the `mounted` check
  /// reflects the page State's lifecycle (the same lifecycle that
  /// disposes [content]).
  final ValueChanged<String> onApplyAi;

  final CharacterCardV3 contextCard;

  @override
  Widget build(BuildContext context) {
    return TextFieldCard.multiLine(
      controller: content,
      label: t.editor.lorebookEntryEditorPage.contentLabel,
      showTokenCount: true,
      trailing: AiActionTextfieldPopup(
        currentText: currentText,
        onApply: onApplyAi,
        fieldName: 'Lorebook Entry Content',
        contextCard: contextCard,
      ),
    );
  }
}

class _EntryRecursionRow extends StatelessWidget {
  const _EntryRecursionRow({required this.entry, required this.onUpdate});
  final LorebookEntry entry;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          label: Text(t.editor.lorebookEntryEditorPage.nonRecursableFilter),
          selected: entry.extensions.excludeRecursion ?? false,
          onSelected: (v) {
            entry.extensions.excludeRecursion = v;
            onUpdate();
          },
          visualDensity: VisualDensity.compact,
        ),
        FilterChip(
          label: Text(
            t.editor.lorebookEntryEditorPage.preventFurtherRecursionFilter,
          ),
          selected: entry.extensions.preventRecursion ?? false,
          onSelected: (v) {
            entry.extensions.preventRecursion = v;
            onUpdate();
          },
          visualDensity: VisualDensity.compact,
        ),
        FilterChip(
          label: Text(
            t.editor.lorebookEntryEditorPage.delayUntilRecursionFilter,
          ),
          selected: (entry.extensions.delayUntilRecursion ?? 0) > 0,
          onSelected: (v) {
            entry.extensions.delayUntilRecursion = (v ? 1 : 0);
            onUpdate();
          },
          visualDensity: VisualDensity.compact,
        ),
        FilterChip(
          label: Text(t.editor.lorebookEntryEditorPage.ignoreBudgetFilter),
          selected: entry.extensions.ignoreBudget ?? false,
          onSelected: (v) {
            entry.extensions.ignoreBudget = v;
            onUpdate();
          },
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _EntryInclusionGroupRow extends StatelessWidget {
  const _EntryInclusionGroupRow({
    required this.entry,
    required this.controller,
    required this.onUpdate,
  });
  final LorebookEntry entry;
  final EntryControllers controller;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text(t.editor.lorebookEntryEditorPage.prioritizeFilter),
            selected: entry.extensions.groupOverride ?? false,
            onSelected: (v) {
              entry.extensions.groupOverride = v;
              onUpdate();
            },
            visualDensity: VisualDensity.compact,
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: TextFieldCard.singleLine(
                controller: controller.group,
                label: t.editor.lorebookEntryEditorPage.inclusionGroupLabel,
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFieldCard.singleLine(
                controller: controller.groupWeight,
                label: t.editor.lorebookEntryEditorPage.groupWeightLabel,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryTimedEffectsRow extends StatelessWidget {
  const _EntryTimedEffectsRow({required this.controller});
  final EntryControllers controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 120,
          child: TextFieldCard.singleLine(
            controller: controller.sticky,
            label: t.editor.lorebookEntryEditorPage.stickyLabel,
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(
          width: 120,
          child: TextFieldCard.singleLine(
            controller: controller.cooldown,
            label: t.editor.lorebookEntryEditorPage.cooldownLabel,
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(
          width: 120,
          child: TextFieldCard.singleLine(
            controller: controller.delay,
            label: t.editor.lorebookEntryEditorPage.delayLabel,
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}

class _EntryFilterRow extends StatelessWidget {
  const _EntryFilterRow({required this.controller});
  final EntryControllers controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFieldCard.singleLine(
          controller: controller.characterFilter,
          label: t.editor.lorebookEntryEditorPage.filterToCharactersLabel,
        ),
        TextFieldCard.singleLine(
          controller: controller.triggers,
          label: t.editor.lorebookEntryEditorPage.filterToTriggersLabel,
        ),
      ],
    );
  }
}

class _EntryMatchingOptionsRow extends StatelessWidget {
  const _EntryMatchingOptionsRow({required this.entry, required this.onUpdate});
  final LorebookEntry entry;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          t.editor.lorebookEntryEditorPage.additionalMatchingSourcesLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: Text(t.editor.lorebookEntryEditorPage.personaFilter),
              selected: entry.extensions.matchPersonaDescription ?? false,
              onSelected: (v) {
                entry.extensions.matchPersonaDescription = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: Text(t.editor.lorebookEntryEditorPage.descriptionFilter),
              selected: entry.extensions.matchCharacterDescription ?? false,
              onSelected: (v) {
                entry.extensions.matchCharacterDescription = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: Text(t.editor.lorebookEntryEditorPage.personalityFilter),
              selected: entry.extensions.matchCharacterPersonality ?? false,
              onSelected: (v) {
                entry.extensions.matchCharacterPersonality = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: Text(t.editor.lorebookEntryEditorPage.depthPromptFilter),
              selected: entry.extensions.matchCharacterDepthPrompt ?? false,
              onSelected: (v) {
                entry.extensions.matchCharacterDepthPrompt = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: Text(t.editor.lorebookEntryEditorPage.scenarioFilter),
              selected: entry.extensions.matchScenario ?? false,
              onSelected: (v) {
                entry.extensions.matchScenario = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: Text(
                t.editor.lorebookEntryEditorPage.creatorNotesFilter,
              ),
              selected: entry.extensions.matchCreatorNotes ?? false,
              onSelected: (v) {
                entry.extensions.matchCreatorNotes = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}
