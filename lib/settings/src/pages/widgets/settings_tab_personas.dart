import 'dart:async';

import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/controllers/personas_controller.dart';
import 'package:cardwave/settings/src/models/chat_persona.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsTabPersonas extends StatefulWidget {
  const SettingsTabPersonas({super.key});

  @override
  State<SettingsTabPersonas> createState() => _SettingsTabPersonasState();
}

class _SettingsTabPersonasState extends State<SettingsTabPersonas> {
  late final SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = context.read<SettingsService>();
  }

  void _addPersona() {
    unawaited(
      PersonasController.addPersona(settingsService: _settingsService),
    );
  }

  void _editPersona(ChatPersona persona) {
    unawaited(
      PersonasController.editPersona(
        settingsService: _settingsService,
        persona: persona,
      ),
    );
  }

  Future<void> _deletePersona(ChatPersona persona) async {
    await PersonasController.confirmAndDelete(
      settingsService: _settingsService,
      persona: persona,
      confirmColor: Theme.of(context).colorScheme.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('persona-new-button'),
              onPressed: _addPersona,
              icon: const Icon(Icons.add),
              label: Text(t.settings.personaDialog.newTitle),
            ),
          ),
        ),
        Expanded(
          child: RadioGroup<String>(
            groupValue: settings.defaultPersonaId,
            onChanged: (value) {
              if (value != null) {
                settings.defaultPersonaId = value;
                unawaited(_settingsService.saveSettings());
              }
            },
            child: ListView.builder(
              itemCount: settings.personas.length,
              itemBuilder: (context, index) {
                final persona = settings.personas[index];
                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      persona.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: persona.description.isNotEmpty
                        ? Text(
                            persona.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    value: persona.id,
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editPersona(persona),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: settings.defaultPersonaId == persona.id
                              ? t.settings.personasTab.cannotDeleteDefaultTooltip
                              : t.settings.personasTab.deleteTooltip,
                          onPressed: settings.defaultPersonaId == persona.id
                              ? null
                              : () => _deletePersona(persona),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
