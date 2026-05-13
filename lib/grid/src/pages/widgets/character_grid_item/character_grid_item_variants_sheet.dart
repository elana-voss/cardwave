import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CharacterGridItemVariantsSheet extends StatelessWidget {
  const CharacterGridItemVariantsSheet({required this.rootId, super.key});
  final String rootId;

  @override
  Widget build(BuildContext context) {
    final characterService = context.watch<CharacterService>();

    final currentStack =
        characterService.characterFiles
            .where((f) => f.appCardRootId == rootId)
            .toList()
          ..sort(
            (a, b) => a.pngTimestampImported.compareTo(b.pngTimestampImported),
          );

    if (currentStack.isEmpty) {
      // Auto-dismiss the sheet once its last variant has been deleted; the
      // in-callback `mounted` / `canPop` guards make a repeated call (if
      // build re-runs before the pop lands) harmless.
      // ignore: qcheck/avoid_side_effects_in_build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Variants',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const CloseButton(),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppConstants.gridMaxCrossAxisExtent,
                mainAxisExtent: AppConstants.gridMainAxisExtent,
                crossAxisSpacing: AppConstants.gridCrossAxisSpacing,
                mainAxisSpacing: AppConstants.gridMainAxisSpacing,
              ),
              itemCount: currentStack.length,
              itemBuilder: (context, index) => CharacterGridItem(
                key: ValueKey(currentStack[index].appCardImagePath),
                characters: [currentStack[index]],
                variantStatus: index == 0
                    ? VariantStatusEnum.original
                    : VariantStatusEnum.variant,
                showVariantNotes: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
