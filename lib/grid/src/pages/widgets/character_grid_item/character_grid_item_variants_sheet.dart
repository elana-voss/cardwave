import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Bottom sheet listing every variant in one group, oldest first. Loads the
/// group's cards from the library index on demand and reloads when the library
/// changes, auto-dismissing once the last variant is deleted.
class CharacterGridItemVariantsSheet extends StatefulWidget {
  const CharacterGridItemVariantsSheet({required this.rootId, super.key});
  final String rootId;

  @override
  State<CharacterGridItemVariantsSheet> createState() =>
      _CharacterGridItemVariantsSheetState();
}

class _CharacterGridItemVariantsSheetState
    extends State<CharacterGridItemVariantsSheet> {
  late final CharacterService _characterService;
  List<CharacterFile>? _variants;

  @override
  void initState() {
    super.initState();
    _characterService = context.read<CharacterService>();
    _characterService.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _characterService.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await _characterService.cardsByRootId(widget.rootId);
    final files = <CharacterFile>[];
    for (final item in items) {
      try {
        files.add(await _characterService.loadFull(item.appCardImagePath));
      } on Exception {
        // Skip a variant that can't be read.
      }
    }
    if (!mounted) return;
    setState(() => _variants = files);

    // Auto-dismiss once the last variant is gone.
    if (files.isEmpty && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final variants = _variants;
    if (variants == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (variants.isEmpty) return const SizedBox.shrink();

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
                  t.grid.variantsSheet.title,
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
              itemCount: variants.length,
              itemBuilder: (context, index) => CharacterGridItem(
                key: ValueKey(variants[index].appCardImagePath),
                file: variants[index],
                variantCount: 1,
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
