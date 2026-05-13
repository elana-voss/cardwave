import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const double _overlayMargin = 4;
const double _badgePaddingHorizontal = 6;
const double _badgePaddingVertical = 2;
const double _badgeFontSize = 10;
const double _badgeBorderRadius = 4;
const double _tokenBarHeight = 22;
const double _tokenBarFontSize = 12;
const double _favoriteIconSize = 20;
const double _variantBadgeBottomMargin = 26;
const int _backgroundAlphaOverlay = 100;
const int _backgroundAlphaTokenBar = 200;

class CharacterGridItemThumbnail extends StatelessWidget {
  const CharacterGridItemThumbnail({
    required this.file,
    required this.isRecent,
    required this.variantStatus,
    super.key,
  });
  final CharacterFile file;
  final bool isRecent;
  final VariantStatusEnum variantStatus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppConstants.gridThumbnailWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageThumbnail(file: file, width: AppConstants.gridThumbnailWidth),
          _FavoriteOverlay(file: file),
          if (isRecent) const _RecentOverlay(),
          if (variantStatus != VariantStatusEnum.none)
            _VariantOverlay(variantStatus: variantStatus),
          _TokenCountOverlay(
            permanentCount: file.appCardTokenCountPermanent,
            allCount: file.appCardTokenCountAll,
          ),
        ],
      ),
    );
  }
}

class _FavoriteOverlay extends StatelessWidget {
  const _FavoriteOverlay({required this.file});
  final CharacterFile file;

  @override
  Widget build(BuildContext context) {
    final isFavorite = file.card.cardwaveData.isFavorite;
    return Positioned(
      top: _overlayMargin,
      left: _overlayMargin,
      child: GestureDetector(
        onTap: () {
          file.card.cardwaveData.isFavorite = !isFavorite;
          unawaited(context.read<CharacterService>().saveJsonInCacheNow(file));
        },
        child: Container(
          padding: const EdgeInsets.all(_overlayMargin),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(_backgroundAlphaOverlay),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite
                ? Theme.of(context).colorScheme.error
                : Colors.white,
            size: _favoriteIconSize,
          ),
        ),
      ),
    );
  }
}

class _RecentOverlay extends StatelessWidget {
  const _RecentOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _overlayMargin,
      right: _overlayMargin,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _badgePaddingHorizontal,
          vertical: _badgePaddingVertical,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(_badgeBorderRadius),
        ),
        child: Text(
          'RECENT',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            fontSize: _badgeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _VariantOverlay extends StatelessWidget {
  const _VariantOverlay({required this.variantStatus});
  final VariantStatusEnum variantStatus;

  @override
  Widget build(BuildContext context) {
    final isOriginal = variantStatus == VariantStatusEnum.original;
    return Positioned(
      bottom: _variantBadgeBottomMargin,
      left: _overlayMargin,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _badgePaddingHorizontal,
          vertical: _badgePaddingVertical,
        ),
        decoration: BoxDecoration(
          color: isOriginal
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(_badgeBorderRadius),
        ),
        child: Text(
          isOriginal ? 'ORIGINAL' : 'VARIANT',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isOriginal
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: _badgeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TokenCountOverlay extends StatelessWidget {
  const _TokenCountOverlay({
    required this.permanentCount,
    required this.allCount,
  });
  final int permanentCount;
  final int allCount;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: _tokenBarHeight,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withAlpha(_backgroundAlphaTokenBar),
        ),
        alignment: Alignment.center,
        child: Text(
          '$permanentCount / $allCount',
          style: const TextStyle(
            fontSize: _tokenBarFontSize,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
