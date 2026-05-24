import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class EditorCreatorMetadata extends StatefulWidget {
  const EditorCreatorMetadata({
    required this.characterFile,
    required this.onChanged,
    super.key,
  });
  final CharacterFile characterFile;
  final VoidCallback onChanged;

  @override
  State<EditorCreatorMetadata> createState() => EditorCreatorMetadataState();
}

class EditorCreatorMetadataState extends State<EditorCreatorMetadata> {
  TextEditingController? _systemNameController;
  TextEditingController? _creatorController;
  TextEditingController? _characterVersionController;
  TextEditingController? _creatorNotesController;
  TextEditingController? _tagsController;

  @override
  void initState() {
    super.initState();
    _systemNameController = TextEditingController(
      text: widget.characterFile.card.systemName ?? '',
    );
    _systemNameController!.onTextChanged(() {
      widget.characterFile.card.systemName = _systemNameController!.text.isEmpty
          ? null
          : _systemNameController!.text;
      widget.onChanged();
    });

    _creatorController = TextEditingController(
      text: widget.characterFile.card.creator,
    );
    _creatorController!.onTextChanged(() {
      widget.characterFile.card.creator = _creatorController!.text;
      widget.onChanged();
    });

    _characterVersionController = TextEditingController(
      text: widget.characterFile.card.characterVersion,
    );
    _characterVersionController!.onTextChanged(() {
      widget.characterFile.card.characterVersion =
          _characterVersionController!.text;
      widget.onChanged();
    });

    _creatorNotesController = TextEditingController(
      text: widget.characterFile.card.creatorNotes,
    );
    _creatorNotesController!.onTextChanged(() {
      widget.characterFile.card.creatorNotes = _creatorNotesController!.text;
      widget.onChanged();
    });

    _tagsController = TextEditingController(
      text: widget.characterFile.card.tags.join(', '),
    );
    _tagsController!.onTextChanged(() {
      widget.characterFile.card.tags = _tagsController!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _systemNameController?.dispose();
    _creatorController?.dispose();
    _characterVersionController?.dispose();
    _creatorNotesController?.dispose();
    _tagsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFieldCard.singleLine(
          controller: _systemNameController!,
          label: 'System Name (CCv3)',
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: TextFieldCard.singleLine(
                controller: _creatorController!,
                label: 'Creator',
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFieldCard.singleLine(
                controller: _characterVersionController!,
                label: 'Version',
              ),
            ),
          ],
        ),
        TextFieldCard.multiLine(
          controller: _creatorNotesController!,
          label: 'Creator Notes',
          showTokenCount: true,
          trailing: AiActionTextfieldPopup(
            currentText: () => _creatorNotesController!.text,
            onApply: aiPopupApply(
              this,
              _creatorNotesController!,
              'Creator Notes',
            ),
            fieldName: 'Creator Notes',
            contextCard: widget.characterFile.card,
          ),
        ),
        TextFieldCard.multiLine(
          controller: _tagsController!,
          label: 'Tags (Coma separated)',
        ),
      ],
    );
  }
}
