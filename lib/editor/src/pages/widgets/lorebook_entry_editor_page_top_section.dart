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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldCard.singleLine(
          controller: controller.comment,
          label: 'Title/Memo',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: DropdownLabeled<String>(
                label: 'Strategy',
                value: _getStrategy(),
                items: [
                  const DropdownMenuItem(
                    value: 'Constant',
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(child: Text('Constant')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Enabled',
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Enabled')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Disabled',
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Disabled')),
                      ],
                    ),
                  ),
                  const DropdownMenuItem(
                    value: 'Vectorized',
                    child: Row(
                      children: [
                        Icon(Icons.link),
                        SizedBox(width: 8),
                        Expanded(child: Text('Vectorized')),
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
                label: 'Position',
                value: _getPositionValue(),
                items: const [
                  DropdownMenuItem(value: '0', child: Text('↑ Char')),
                  DropdownMenuItem(value: '1', child: Text('↓ Char')),
                  DropdownMenuItem(value: '2', child: Text('↑ AN')),
                  DropdownMenuItem(value: '3', child: Text('↓ AN')),
                  DropdownMenuItem(value: '4_0', child: Text('@D System')),
                  DropdownMenuItem(value: '4_1', child: Text('@D User')),
                  DropdownMenuItem(value: '4_2', child: Text('@D Assistant')),
                  DropdownMenuItem(value: '5', child: Text('↑ EM')),
                  DropdownMenuItem(value: '6', child: Text('↓ EM')),
                  DropdownMenuItem(value: '7', child: Text('Outlet')),
                ],
                onChanged: (value) => _setPosition(value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.depth,
                label: 'Depth',
                keyboardType: TextInputType.number,
                enabled: entry.extensions.position == 4,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.order,
                label: 'Order',
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFieldCard.singleLine(
                controller: controller.probability,
                label: 'Trigger %',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
