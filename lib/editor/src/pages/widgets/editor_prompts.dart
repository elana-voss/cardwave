import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/pages/widgets/dropdown_labeled.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class EditorPrompts extends StatefulWidget {
  const EditorPrompts({
    required this.characterFile,
    required this.onChanged,
    super.key,
  });
  final CharacterFile characterFile;
  final VoidCallback onChanged;

  @override
  State<EditorPrompts> createState() => EditorPromptsState();
}

class EditorPromptsState extends State<EditorPrompts> {
  TextEditingController? _systemPromptController;
  TextEditingController? _postHistoryInstructionsController;
  TextEditingController? _depthPromptController;
  TextEditingController? _depthController;
  late DepthPromptRoleEnum _depthRole;

  @override
  void initState() {
    super.initState();
    _systemPromptController = TextEditingController(
      text: widget.characterFile.card.systemPrompt,
    );
    _systemPromptController!.onTextChanged(() {
      widget.characterFile.card.systemPrompt = _systemPromptController!.text;
      widget.onChanged();
    });

    _postHistoryInstructionsController = TextEditingController(
      text: widget.characterFile.card.postHistoryInstructions,
    );
    _postHistoryInstructionsController!.onTextChanged(() {
      widget.characterFile.card.postHistoryInstructions =
          _postHistoryInstructionsController!.text;
      widget.onChanged();
    });

    final initialDepthPrompt = widget.characterFile.card.depthPrompt;
    _depthPromptController = TextEditingController(
      text: initialDepthPrompt?.prompt ?? '',
    );
    _depthPromptController!.onTextChanged(_updateDepthPrompt);

    _depthController = TextEditingController(
      text: (initialDepthPrompt?.depth ?? 4).toString(),
    );
    _depthController!.onTextChanged(_updateDepthPrompt);

    _depthRole = initialDepthPrompt?.role ?? DepthPromptRoleEnum.system;
  }

  void _updateDepthPrompt() {
    final prompt = _depthPromptController!.text;

    if (prompt.isEmpty) {
      widget.characterFile.card.depthPrompt = null;
    } else {
      final depth = int.tryParse(_depthController!.text) ?? 4;
      final role = _depthRole;
      widget.characterFile.card.depthPrompt = DepthPrompt(
        prompt: prompt,
        depth: depth,
        role: role,
      );
    }
    widget.onChanged();
  }

  @override
  void dispose() {
    _systemPromptController?.dispose();
    _postHistoryInstructionsController?.dispose();
    _depthPromptController?.dispose();
    _depthController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      children: [
        TextFieldCard.multiLine(
          controller: _systemPromptController!,
          label: t.editor.editorPrompts.systemPromptLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _systemPromptController!.text,
            onApply: aiPopupApply(
              this,
              _systemPromptController!,
              'System Prompt',
            ),
            fieldName: 'System Prompt',
            contextCard: widget.characterFile.card,
          ),
        ),
        const SizedBox(height: 8),
        TextFieldCard.multiLine(
          controller: _postHistoryInstructionsController!,
          label: t.editor.editorPrompts.postHistoryInstructionsLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _postHistoryInstructionsController!.text,
            onApply: aiPopupApply(
              this,
              _postHistoryInstructionsController!,
              'Post History Instructions',
            ),
            fieldName: 'Post History Instructions',
            contextCard: widget.characterFile.card,
          ),
        ),
        const SizedBox(height: 16),
        TextFieldCard.multiLine(
          controller: _depthPromptController!,
          label: t.editor.editorPrompts.depthPromptLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _depthPromptController!.text,
            onApply: aiPopupApply(this, _depthPromptController!, 'Depth Prompt'),
            fieldName: 'Depth Prompt',
            contextCard: widget.characterFile.card,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 16,
          children: [
            Expanded(
              child: TextFieldCard.singleLine(
                controller: _depthController!,
                label: t.editor.editorPrompts.insertionDepthLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            Expanded(
              flex: 2,
              child: DropdownLabeled<DepthPromptRoleEnum>(
                label: t.editor.editorPrompts.roleLabel,
                value: _depthRole,
                items: DepthPromptRoleEnum.values.map((role) {
                  final label =
                      role.name.substring(0, 1).toUpperCase() +
                      role.name.substring(1);
                  return DropdownMenuItem(value: role, child: Text(label));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _depthRole = value);
                    _updateDepthPrompt();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
