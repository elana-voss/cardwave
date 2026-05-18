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

