import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/src/controllers/filter_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/routing/route_create_character.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewEmptyState extends StatelessWidget {
  const ViewEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final filterController = context.watch<FilterController>();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Icon(
            filterController.hasActiveFilters ? Icons.search_off : Icons.inbox,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          Text(
            filterController.hasActiveFilters
                ? t.grid.emptyState.noMatches
                : t.grid.emptyState.noCharacters,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (filterController.hasActiveFilters)
            FilledButton.icon(
              onPressed: filterController.clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(t.grid.emptyState.clearAllFilters),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => CharacterImportController.runBulkImport(
                    context.read<CharacterService>(),
                  ),
                  icon: const Icon(Icons.upload),
                  label: Text(t.grid.emptyState.importCharacters),
                ),
                OutlinedButton.icon(
                  onPressed: () => RouteCreateCharacter().execute(context),
                  icon: const Icon(Icons.add),
                  label: Text(t.grid.emptyState.createNewCharacter),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
