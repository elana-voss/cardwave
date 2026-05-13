part of 'lorebook_entry_editor_page.dart';

class _EntryScanRow extends StatelessWidget {
  const _EntryScanRow({
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
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 160,
              child: TextFieldCard.singleLine(
                controller: controller.scanDepth,
                label: 'Scan Depth',
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 240,
              child: TextFieldCard.singleLine(
                controller: controller.automationId,
                label: 'Automation ID',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Use Regex'),
              selected: entry.useRegex ?? false,
              onSelected: (v) {
                entry.useRegex = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: const Text('Case Sensitive'),
              selected: entry.caseSensitive ?? false,
              onSelected: (v) {
                entry.caseSensitive = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: const Text('Whole Words'),
              selected: entry.extensions.matchWholeWords ?? false,
              onSelected: (v) {
                entry.extensions.matchWholeWords = v;
                onUpdate();
              },
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: const Text('Group Scoring'),
              selected: entry.extensions.useGroupScoring ?? false,
              onSelected: (v) {
                entry.extensions.useGroupScoring = v;
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
