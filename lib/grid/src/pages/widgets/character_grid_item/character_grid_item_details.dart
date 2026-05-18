import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_action_menu.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_item_tag_list.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:cardwave/routing/route_edit_character.dart';
import 'package:flutter/material.dart';

class CharacterGridItemDetails extends StatelessWidget {
  const CharacterGridItemDetails({
    required this.file,
    required this.variantStatus,
    required this.showVariantNotes,
    super.key,
  });
  final CharacterFile file;
  final VariantStatusEnum variantStatus;
  final bool showVariantNotes;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        // padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CharacterGridItemHeader(
              file: file,
              variantStatus: variantStatus,
              showVariantNotes: showVariantNotes,
            ),
            const SizedBox(height: 2),
            if (showVariantNotes) _CharacterGridItemVariantNotes(file: file),
            const SizedBox(height: 6),
            _CharacterGridItemDescription(file: file),
            const SizedBox(height: 8),
            CharacterGridItemTagList(file: file),
            const SizedBox(height: 6),
            _CharacterGridItemFooter(file: file),
          ],
        ),
      ),
    );
  }
}

class _CharacterGridItemHeader extends StatelessWidget {
  const _CharacterGridItemHeader({
    required this.file,
    required this.variantStatus,
    required this.showVariantNotes,
  });
  final CharacterFile file;
  final VariantStatusEnum variantStatus;
  final bool showVariantNotes;

  @override
  Widget build(BuildContext context) {
    // Adjacent `Expanded`/`IconButton` pair is flush (0 gap);
    // `spacing:` would add an unwanted gap.
    // ignore: qcheck/prefer_spacing
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: file.card.name,
              preferBelow: false,
              child: Text(
                file.card.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () =>
              unawaited(RouteEditCharacter().execute(context, file)),
        ),
        const SizedBox(width: 4),
        CharacterGridActionMenu(
          file: file,
          variantStatus: variantStatus,
          showVariantNotes: showVariantNotes,
        ),
      ],
    );
  }
}

class _CharacterGridItemVariantNotes extends StatelessWidget {
  const _CharacterGridItemVariantNotes({required this.file});
  final CharacterFile file;

  @override
  Widget build(BuildContext context) {
    return Text(
      file.appCardVariantNotes.isNotEmpty
          ? file.appCardVariantNotes
          : UtilsApp.timeAgo(file.pngTimestampLastSaved),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CharacterGridItemDescription extends StatelessWidget {
  const _CharacterGridItemDescription({required this.file});
  final CharacterFile file;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        file.card.cardwaveData.previewDescription ?? '',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
          height: 1.2,
        ),
      ),
    );
  }
}

class _CharacterGridItemFooter extends StatelessWidget {
  const _CharacterGridItemFooter({required this.file});
  final CharacterFile file;

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    if (file.card.creator.isNotEmpty) {
      spans.add(TextSpan(text: '@${file.card.creator}'));
    }
    if (spans.isNotEmpty) spans.add(const TextSpan(text: ' • '));
    spans.add(
      const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.file_download, size: 14, color: Colors.grey),
      ),
    );
    spans.add(
      TextSpan(text: ' ${UtilsApp.timeAgo(file.pngTimestampImported)}'),
    );
    if (spans.isNotEmpty) spans.add(const TextSpan(text: ' • '));
    spans.add(
      const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.edit, size: 14, color: Colors.grey),
      ),
    );
    spans.add(
      TextSpan(text: ' ${UtilsApp.timeAgo(file.pngTimestampLastSaved)}'),
    );
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _buildSpans(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 10,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
