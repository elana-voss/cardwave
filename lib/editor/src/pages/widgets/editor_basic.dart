import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class EditorBasic extends StatefulWidget {
  const EditorBasic({
    required this.characterFile,
    required this.onChanged,
    super.key,
  });
  final CharacterFile characterFile;
  final VoidCallback onChanged;

  @override
  State<EditorBasic> createState() => EditorBasicState();
}

class EditorBasicState extends State<EditorBasic> {
  TextEditingController? _nameController;
  TextEditingController? _nicknameController;
  TextEditingController? _descriptionController;
  TextEditingController? _personalityController;
  TextEditingController? _scenarioController;
  TextEditingController? _mesExampleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.characterFile.card.name,
    );
    _nameController!.onTextChanged(() {
      widget.characterFile.card.name = _nameController!.text;
      widget.onChanged();
    });

    _nicknameController = TextEditingController(
      text: widget.characterFile.card.nickname ?? '',
    );
    _nicknameController!.onTextChanged(() {
      widget.characterFile.card.nickname = _nicknameController!.text.isEmpty
          ? null
          : _nicknameController!.text;
      widget.onChanged();
    });

    _descriptionController = TextEditingController(
      text: widget.characterFile.card.description,
    );
    _descriptionController!.onTextChanged(() {
      widget.characterFile.card.description = _descriptionController!.text;
      widget.onChanged();
    });

    _personalityController = TextEditingController(
      text: widget.characterFile.card.personality,
    );
    _personalityController!.onTextChanged(() {
      widget.characterFile.card.personality = _personalityController!.text;
      widget.onChanged();
    });

    _scenarioController = TextEditingController(
      text: widget.characterFile.card.scenario,
    );
    _scenarioController!.onTextChanged(() {
      widget.characterFile.card.scenario = _scenarioController!.text;
      widget.onChanged();
    });

    _mesExampleController = TextEditingController(
      text: widget.characterFile.card.mesExample,
    );
    _mesExampleController!.onTextChanged(() {
      widget.characterFile.card.mesExample = _mesExampleController!.text;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _nicknameController?.dispose();
    _descriptionController?.dispose();
    _personalityController?.dispose();
    _scenarioController?.dispose();
    _mesExampleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      spacing: 8,
      children: [
        TextFieldCard.singleLine(
          controller: _nameController!,
          label: t.editor.editorBasic.nameLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _nameController!.text,
            onApply: aiPopupApply(this, _nameController!, 'Name'),
            fieldName: 'Name',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.singleLine(
          controller: _nicknameController!,
          label: t.editor.editorBasic.nicknameLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _nicknameController!.text,
            onApply: aiPopupApply(this, _nicknameController!, 'Nickname (CCv3)'),
            fieldName: 'Nickname (CCv3)',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _descriptionController!,
          label: t.editor.editorBasic.descriptionLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _descriptionController!.text,
            onApply: aiPopupApply(this, _descriptionController!, 'Description'),
            fieldName: 'Description',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _personalityController!,
          label: t.editor.editorBasic.personalityLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _personalityController!.text,
            onApply: aiPopupApply(this, _personalityController!, 'Personality'),
            fieldName: 'Personality',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _scenarioController!,
          label: t.editor.editorBasic.scenarioLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _scenarioController!.text,
            onApply: aiPopupApply(this, _scenarioController!, 'Scenario'),
            fieldName: 'Scenario',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _mesExampleController!,
          label: t.editor.editorBasic.messageExampleLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _mesExampleController!.text,
            onApply: aiPopupApply(
              this,
              _mesExampleController!,
              'Message Example',
            ),
            fieldName: 'Message Example',
            contextCard: widget.characterFile.card,
          ),
        ),
      ],
    );
  }
}
