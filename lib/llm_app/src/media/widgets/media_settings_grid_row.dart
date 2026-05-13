import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:flutter/material.dart';

const double _kLabelWidthWide = 200;
const double _kLabelWidthNarrow = 120;

/// Picks the leading label column width based on the available width
/// passed in (from a LayoutBuilder). Below the project's mobile
/// breakpoint the column tightens so the value cell isn't squeezed on
/// phones; above it stays at 200dp for legible labels.
double mediaSettingsGridLabelColumnWidth(double availableWidth) =>
    availableWidth < AppConstants.mobileBreakpoint
        ? _kLabelWidthNarrow
        : _kLabelWidthWide;

/// One row in the layer grid: label on the left + one cell per layer in
/// [layers] on the right. Cell builders always produce the full triple
/// (app/character/session); the row picks just the layers it's asked
/// to render — narrow layouts pass a single-element list, wide layouts
/// pass all available layers.
class MediaSettingsGridRow extends StatelessWidget {
  const MediaSettingsGridRow({
    required this.label,
    required this.layers,
    required this.appCell,
    required this.characterCell,
    required this.sessionCell,
    required this.labelColumnWidth,
    super.key,
  });

  final String label;
  final List<MediaSettingsGridLayer> layers;
  final MediaSettingsGridCell appCell;
  final MediaSettingsGridCell characterCell;
  final MediaSettingsGridCell sessionCell;
  final double labelColumnWidth;

  MediaSettingsGridCell _cellFor(MediaSettingsGridLayer l) {
    return switch (l) {
      MediaSettingsGridLayer.app => appCell,
      MediaSettingsGridLayer.character => characterCell,
      MediaSettingsGridLayer.session => sessionCell,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: labelColumnWidth,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final l in layers) Expanded(child: _cellFor(l)),
        ],
      ),
    );
  }
}

/// Header band above the value column(s). Two modes:
///
///   * **Switcher** ([showSwitcher] true, [layers] has one element):
///     `<` arrow + current layer label + `>` arrow. Used in narrow
///     layouts where only one column fits.
///   * **Multi** ([showSwitcher] false): one centred label per layer
///     side by side, no arrows. Used on wide screens.
class MediaSettingsGridHeader extends StatelessWidget {
  const MediaSettingsGridHeader({
    required this.layers,
    required this.characterName,
    required this.labelColumnWidth,
    this.showSwitcher = false,
    this.onCyclePrev,
    this.onCycleNext,
    super.key,
  });

  final List<MediaSettingsGridLayer> layers;
  final String characterName;
  final double labelColumnWidth;
  final bool showSwitcher;
  final VoidCallback? onCyclePrev;
  final VoidCallback? onCycleNext;

  String _labelFor(MediaSettingsGridLayer l) {
    return switch (l) {
      MediaSettingsGridLayer.app => 'App default',
      MediaSettingsGridLayer.character =>
        characterName.isEmpty ? 'Character' : characterName,
      MediaSettingsGridLayer.session => 'Current chat',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSecondaryContainer,
    );
    Widget plainLabel(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: style,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return ColoredBox(
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: [
          SizedBox(width: labelColumnWidth),
          if (showSwitcher && layers.length == 1)
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    iconSize: 20,
                    onPressed: onCyclePrev,
                    tooltip: 'Previous layer',
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  // Guarded by `layers.length == 1` above.
                  // ignore: qcheck/avoid_unsafe_collection_methods
                  Expanded(child: plainLabel(_labelFor(layers.single))),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    iconSize: 20,
                    onPressed: onCycleNext,
                    tooltip: 'Next layer',
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ],
              ),
            )
          else
            for (final l in layers) Expanded(child: plainLabel(_labelFor(l))),
        ],
      ),
    );
  }
}
