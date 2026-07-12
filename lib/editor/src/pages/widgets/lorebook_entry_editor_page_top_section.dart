part of 'lorebook_entry_editor_page.dart';

class _EntryTopSection extends StatelessWidget {
  const _EntryTopSection({
    required this.entry,
    required this.controller,
    required this.onUpdate,
  });
  final LorebookEntry entry;
  final EntryControllers controller;
  final VoidCallback onUpdate;

  static const int _defaultPosition = 0;
  static const String _defaultPositionStr = '0';

  String _getStrategy() {
    if (entry.enabled == false) return 'Disabled';
    if (entry.constant == true) return 'Constant';
    if (entry.extensions.vectorized == true) return 'Vectorized';
    return 'Enabled';
  }

  void _setStrategy(String strategy) {
    switch (strategy) {
      case 'Enabled':
        entry.enabled = true;
        entry.constant = false;
        entry.extensions.vectorized = false;
      case 'Constant':
        entry.enabled = true;
        entry.constant = true;
        entry.extensions.vectorized = false;
      case 'Vectorized':
        entry.enabled = true;
        entry.constant = false;
        entry.extensions.vectorized = true;
      case 'Disabled':
        entry.enabled = false;
    }
    onUpdate();
  }

  String _getPositionValue() {
    final pos = entry.extensions.position ?? _defaultPosition;

    if (pos == 4) {
      final role = entry.extensions.role ?? 0;
      if (role >= 0 && role <= 2) return '4_$role';
      return '4_0';
    }

    final posStr = pos.toString();
    const validPositions = ['0', '1', '2', '3', '5', '6', '7'];
    if (validPositions.contains(posStr)) {
      return posStr;
    }
    return _defaultPositionStr;
  }

  void _setPosition(String value) {
    int posNum;
    if (value.startsWith('4_')) {
      posNum = 4;
      entry.extensions.role = int.parse(value.split('_')[1]);
    } else {
      posNum = int.parse(value);
      entry.extensions.role = null;
    }
    entry.extensions.position = posNum;
    entry.position = posNum == 0 ? 'before_char' : 'after_char';
    onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFieldCard.singleLine(
          controller: controller.comment,
          label: t.editor.lorebookEntryEditorTopSection.titleMemoLabel,
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: DropdownLabeled<String>(
                label: t.editor.lorebookEntryEditorTopSection.strategyLabel,
                value: _getStrategy(),
                items: [
                  DropdownMenuItem(
                    value: 'Constant',
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(Icons.circle, color: Colors.blue),
                        Expanded(
                          child: Text(
                            t.editor.lorebookEntryEditorTopSection
                                .strategyConstant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Enabled',
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            t.editor.lorebookEntryEditorTopSection
                                .strategyEnabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Disabled',
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.circle,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        Expanded(
                          child: Text(
                            t.editor.lorebookEntryEditorTopSection
                                .strategyDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Vectorized',
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(Icons.link),
                        Expanded(
                          child: Text(
                            t.editor.lorebookEntryEditorTopSection
                                .strategyVectorized,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) => _setStrategy(value!),
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownLabeled<String>(
                label: t.editor.lorebookEntryEditorTopSection.positionLabel,
                value: _getPositionValue(),
                items: [
                  DropdownMenuItem(
                    value: '0',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionUpChar,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '1',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionDownChar,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '2',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionUpAn,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '3',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionDownAn,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '4_0',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection
                          .positionDepthSystem,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '4_1',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionDepthUser,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '4_2',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection
                          .positionDepthAssistant,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '5',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionUpEm,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '6',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionDownEm,
                    ),
                  ),
                  DropdownMenuItem(
                    value: '7',
                    child: Text(
                      t.editor.lorebookEntryEditorTopSection.positionOutlet,
                    ),
                  ),
                ],
                onChanged: (value) => _setPosition(value!),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.depth,
                label: t.editor.lorebookEntryEditorTopSection.depthLabel,
                keyboardType: TextInputType.number,
                enabled: entry.extensions.position == 4,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.order,
                label: t.editor.lorebookEntryEditorTopSection.orderLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.probability,
                label: t.editor.lorebookEntryEditorTopSection.triggerLabel,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
