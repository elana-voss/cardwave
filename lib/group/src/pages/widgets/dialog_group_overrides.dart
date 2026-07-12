import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
  TextEditingController? _scenarioController;
  TextEditingController? _systemPromptController;
  TextEditingController? _mesExampleController;

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
    _scenarioController?.dispose();
    _systemPromptController?.dispose();
    _mesExampleController?.dispose();
    super.dispose();
  }

  void _save() {
    context.read<GroupChatController>().updateGroupData(
      overrideScenario: _scenarioController!.text,
      overrideSystemPrompt: _systemPromptController!.text,
      overrideMesExample: _mesExampleController!.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AppDialog(
      builder: (context, isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.group.groupChatPageEndDrawer.groupOverridesTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t.group.dialogGroupOverrides.explanationMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: t.common.promptSegmentKind.scenario,
            hint: t.group.dialogGroupOverrides.scenarioHint,
            controller: _scenarioController!,
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: t.group.dialogGroupOverrides.mainPromptLabel,
            hint: t.group.dialogGroupOverrides.mainPromptHint,
            controller: _systemPromptController!,
          ),
          const SizedBox(height: 16),
          _OverrideField(
            label: t.group.dialogGroupOverrides.exampleDialogueLabel,
            hint: t.group.dialogGroupOverrides.exampleDialogueHint,
            controller: _mesExampleController!,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _save,
          child: Text(t.common.actions.save),
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
    final t = Translations.of(context);
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
          tooltip: t.llmApp.mediaCellMenu.clear,
          onPressed: controller.clear,
        ),
      ),
    );
  }
}
