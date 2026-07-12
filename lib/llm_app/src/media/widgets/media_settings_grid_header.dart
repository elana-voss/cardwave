import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:flutter/material.dart';

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
      MediaSettingsGridLayer.app => t.llmApp.mediaHeader.appDefault,
      MediaSettingsGridLayer.character => characterName.isEmpty
          ? t.llmApp.mediaHeader.character
          : characterName,
      MediaSettingsGridLayer.session => t.llmApp.mediaHeader.currentChat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
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
                    tooltip: t.llmApp.mediaHeader.previousLayerTooltip,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  // Guarded by `layers.length == 1` above.
                  // ignore: qcheck/avoid_unsafe_collection_methods
                  Expanded(child: plainLabel(_labelFor(layers.single))),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    iconSize: 20,
                    onPressed: onCycleNext,
                    tooltip: t.llmApp.mediaHeader.nextLayerTooltip,
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
