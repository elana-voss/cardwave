import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/models/chat_persona.dart';
import 'package:flutter/material.dart';

class DialogPersona extends StatefulWidget {
  const DialogPersona({super.key, this.persona});
  final ChatPersona? persona;

  @override
  State<DialogPersona> createState() => _DialogPersonaState();
}

class _DialogPersonaState extends State<DialogPersona> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.persona?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.persona?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final newPersona = ChatPersona(
        id: widget.persona?.id,
        name: _nameController.text,
        description: _descriptionController.text,
      );
      Navigator.pop(context, newPersona);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      actions: [
        FilledButton(
          key: const Key('persona-edit-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            widget.persona == null ? 'New Persona' : 'Edit Persona',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                TextFieldAutotrim(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                TextFieldAutotrim(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Appearance, personality, background, etc.',
                  ),
                  maxLines: 5,
                  minLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
