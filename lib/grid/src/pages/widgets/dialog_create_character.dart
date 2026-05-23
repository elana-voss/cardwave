import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DialogCreateCharacter extends StatefulWidget {
  const DialogCreateCharacter({super.key});

  @override
  State<DialogCreateCharacter> createState() => _DialogCreateCharacterState();
}

class _DialogCreateCharacterState extends State<DialogCreateCharacter> {
  final TextEditingController _nameController = TextEditingController();
  bool _isChecking = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSubmit() async {
    setState(() {
      _isChecking = true;
      _nameError = null;
    });

    final name = _nameController.text.trim();

    var hasError = false;

    if (name.isEmpty) {
      _nameError = 'Character name cannot be empty.';
      hasError = true;
    } else if (RegExp(r'[<>:"/\\|?*]').hasMatch(name)) {
      _nameError = r'Name contains invalid characters (<>:"/\|?*).';
      hasError = true;
    }

    if (hasError) {
      setState(() {
        _isChecking = false;
      });
      return;
    }

    final imageFilename = '$name.png';

    try {
      final exists = await context.read<CharacterService>().characterPngExists(
        imageFilename,
      );
      if (exists) {
        _nameError = 'A character with this name already exists.';
        hasError = true;
      }
    } on Exception catch (e, st) {
      LoggingService().error(
        'Character-name file-existence check failed',
        e,
        st,
      );
      _nameError =
          'Could not verify the name. Check folder permissions and try again.';
      hasError = true;
    }

    if (hasError) {
      setState(() {
        _isChecking = false;
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      builder: (context, isMobile) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              'Create New Character',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextField(
              key: const Key('character-name-field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Character Name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _validateAndSubmit(),
            ),
          ],
        );
      },
      actions: [
        FilledButton(
          key: const Key('character-create-confirm'),
          onPressed: _isChecking ? null : _validateAndSubmit,
          child: _isChecking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
