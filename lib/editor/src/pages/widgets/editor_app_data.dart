import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class EditorAppData extends StatefulWidget {
  const EditorAppData({
    required this.characterFile,
    required this.onChanged,
    super.key,
  });
  final CharacterFile characterFile;
  final VoidCallback onChanged;

  @override
  State<EditorAppData> createState() => EditorAppDataState();
}

class EditorAppDataState extends State<EditorAppData> {
  TextEditingController? _notesController;
  TextEditingController? _previewDescriptionController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.characterFile.appCardVariantNotes,
    );
    _notesController!.onTextChanged(() {
      widget.characterFile.appCardVariantNotes = _notesController!.text;
      widget.onChanged();
    });

    _previewDescriptionController = TextEditingController(
      text: widget.characterFile.card.cardwaveData.previewDescription,
    );
    _previewDescriptionController!.onTextChanged(() {
      final cwData = widget.characterFile.card.cardwaveData;
      cwData.previewDescription = _previewDescriptionController!.text;
      widget.characterFile.card.cardwaveData = cwData;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _notesController?.dispose();
    _previewDescriptionController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        TextFieldCard.multiLine(
          controller: _notesController!,
          label: t.editor.editorAppData.variantNotesLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _notesController!.text,
            onApply: aiPopupApply(this, _notesController!, 'Variant Notes'),
            fieldName: 'Variant Notes',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _previewDescriptionController!,
          label: t.editor.editorAppData.descriptionPreviewLabel,
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _previewDescriptionController!.text,
            onApply: aiPopupApply(
              this,
              _previewDescriptionController!,
              'Description Preview',
            ),
            fieldName: 'Description Preview',
            contextCard: widget.characterFile.card,
          ),
        ),
      ],
    );
  }
}
