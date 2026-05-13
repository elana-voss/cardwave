import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Editor for group-level overrides of each member's scenario, main prompt,
/// and example dialogue. Opened from a ListTile in the end drawer.
class DialogGroupOverrides extends StatefulWidget {
  const DialogGroupOverrides({super.key});

  @override
  State<DialogGroupOverrides> createState() => _DialogGroupOverridesState();
}

class _DialogGroupOverridesState extends State<DialogGroupOverrides> {
  late final TextEditingController _scenarioController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _mesExampleController;

  @override
  void initState() {
    super.initState();
    final data = context.read<GroupChatController>().groupData;
    _scenarioController = TextEditingController(
      text: data.overrideScenario ?? '',
    );
    _systemPromptController = TextEditingController(
      text: data.overrideSystemPrompt ?? '',
    );
    _mesExampleController = TextEditingController(
      text: data.overrideMesExample ?? '',
    );
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    _systemPromptController.dispose();
    _mesExampleController.dispose();
    super.dispose();
  }

  void _save() {
    context.read<GroupChatController>().updateGroupData(
      overrideScenario: _scenarioController.text,
      overrideSystemPrompt: _systemPromptController.text,
      overrideMesExample: _mesExampleController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      builder: (context, isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Group overrides',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Unique to this chat. All group members use these values instead '
            'of what their character cards define. Leave empty to fall back '
            'to the card value.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: 'Scenario',
            hint: 'Shared setting for the group (e.g. "In a cafe in Paris")',
            controller: _scenarioController,
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: 'Main Prompt',
            hint: 'System prompt applied during every turn',
            controller: _systemPromptController,
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: 'Example Dialogue',
            hint: 'Shared example messages for tone / formatting',
            controller: _mesExampleController,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _OverrideField extends StatelessWidget {
  const _OverrideField({
    required this.label,
    required this.hint,
    required this.controller,
  });
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: controller.clear,
        ),
      ),
    );
  }
}
