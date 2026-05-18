import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_item_details.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_item_thumbnail.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_item_variant_badge.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/character_grid_item_variants_sheet.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:cardwave/routing/route_chat_character.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CharacterGridItem extends StatelessWidget {
  const CharacterGridItem({
    required this.characters,
    super.key,
    this.variantStatus = VariantStatusEnum.none,
    this.showVariantNotes = false,
  });
  final List<CharacterFile> characters;
  final VariantStatusEnum variantStatus;
  final bool showVariantNotes;

  void _showVariants(BuildContext context) {
    // `characters` is always built non-empty (one entry per card stack).
    // ignore: qcheck/avoid_unsafe_collection_methods
    final rootId = characters.first.appCardRootId;
    unawaited(
      showModalBottomSheet(
        showDragHandle: false,
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) {
          return CharacterGridItemVariantsSheet(rootId: rootId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `characters` is always built non-empty (one entry per card stack).
    // ignore: qcheck/avoid_unsafe_collection_methods
    final file = characters.first;
    final isAiTask = context.select<CharacterAiService, bool>(
      (service) => service.isProcessingAiTask(file.appCardImagePath),
    );
    final isGroup = characters.length > 1;

    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: file.card.cardwaveData.isFavorite
                ? BorderSide(color: Theme.of(context).colorScheme.error)
                : file.isRecent
                ? BorderSide(color: Theme.of(context).colorScheme.primary)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              if (isGroup) {
                _showVariants(context);
              } else if (context.mounted) {
                unawaited(RouteChatCharacter().execute(context, file));
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CharacterGridItemThumbnail(
                  file: file,
                  isRecent: file.isRecent,
                  variantStatus: variantStatus,
                ),
                CharacterGridItemDetails(
                  file: file,
                  variantStatus: variantStatus,
                  showVariantNotes: showVariantNotes,
                ),
              ],
            ),
          ),
        ),
        if (isGroup)
          Positioned(
            bottom: 0,
            right: 0,
            child: CharacterGridItemVariantBadge(
              count: characters.length,
              onTap: () => _showVariants(context),
            ),
          ),
        if (isAiTask)
          const Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: _AiProcessingOverlay(),
            ),
          ),
      ],
    );
  }
}

class _AiProcessingOverlay extends StatefulWidget {
  const _AiProcessingOverlay();

  @override
  State<_AiProcessingOverlay> createState() => _AiProcessingOverlayState();
}

class _AiProcessingOverlayState extends State<_AiProcessingOverlay>
    with SingleTickerProviderStateMixin {
  final int _aiOverlayAnimationDurationMs = 2000;
  final double _aiOverlayOpacityBase = 0.1;
  final double _aiOverlayOpacityHighlight = 0.4;
  final double _aiOverlayBandSize = 0.2;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _aiOverlayAnimationDurationMs),
    );
    unawaited(_controller.repeat());

    _animation = Tween<double>(
      begin: -_aiOverlayBandSize,
      end: 1.0 + _aiOverlayBandSize,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  _animation.value - _aiOverlayBandSize,
                  _animation.value,
                  _animation.value + _aiOverlayBandSize,
                ],
                colors: [
                  color.withValues(alpha: _aiOverlayOpacityBase),
                  color.withValues(alpha: _aiOverlayOpacityHighlight),
                  color.withValues(alpha: _aiOverlayOpacityBase),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
