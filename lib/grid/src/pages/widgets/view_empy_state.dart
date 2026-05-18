import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/src/controllers/filter_controller.dart';
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
        children: [
          Icon(
            filterController.hasActiveFilters ? Icons.search_off : Icons.inbox,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            filterController.hasActiveFilters
                ? 'No characters match your filters'
                : 'No characters imported yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (filterController.hasActiveFilters) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: filterController.clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear all filters'),
            ),
          ] else ...[
            const SizedBox(height: 16),
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
                  label: const Text('Import Characters'),
                ),
                OutlinedButton.icon(
                  onPressed: () => RouteCreateCharacter().execute(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Character'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
