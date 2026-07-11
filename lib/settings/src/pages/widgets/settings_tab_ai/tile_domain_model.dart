import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

const double _kLabelColumnWidth = 80;

/// Dashboard row: model name + meta line with a fixed-width label
/// column on the left. When the active model is null the title flips
/// to a warning icon + error-color placeholder so unassigned domain
/// slots stand out.
class TileDomainModel extends StatelessWidget {
  const TileDomainModel({
    required this.model,
    super.key,
    this.leading,
    this.placeholderTitle = '',
    this.onTap,
    this.trailing,
    this.subtitleOverride,
    this.preset,
  });
  final Widget? leading;
  final LlmModel? model;
  final String placeholderTitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Replaces the default `contextLabel · priceLabel` subtitle. Used by
  /// local-GGUF rows to show "<loaded> ctx (max <native>)" since the
  /// loaded context size lives on the profile, not on `LlmModel`.
  final String? subtitleOverride;

  /// Active preset for this row. When non-null and its
  /// `parameterValues` carries a temperature, the subtitle gets a
  /// primary-color `Temp <value>` tail so users can tell presets of
  /// the same model apart at a glance.
  final LlmPresetConfig? preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeModel = model;

    if (activeModel == null) {
      // No preset assigned (or no compatible model exists). Surface the
      // gap with a warning icon + error-color text so the user notices
      // domains that still need a model picked — same tone the rest of
      // M3 uses for "this slot needs your attention".
      return ListTile(
        onTap: onTap,
        title: Row(
          spacing: 6,
          children: [
            _LabelColumn(leading: leading),
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 18,
            ),
            Expanded(
              child: Text(
                placeholderTitle,
                style: TextStyle(color: theme.colorScheme.error),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);
    final metaLine = subtitleOverride ??
        <String>[
          activeModel.contextLabel,
          ?activeModel.priceLabel,
        ].join(' · ');
    final temperature =
        preset?.parameterValues[LlmParameterDefinitionIdEnum.temperature];

    return ListTile(
      onTap: onTap,
      trailing: trailing,
      title: Row(
        children: [
          _LabelColumn(leading: leading),
          if (activeModel.isUnavailable) ...[
            const BadgeModelUnavailable(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(activeModel.name, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          const SizedBox(width: _kLabelColumnWidth),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                children: [
                  TextSpan(text: metaLine),
                  if (temperature != null) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: t.settings.aiTab.temperatureLabel(
                        value: temperature.toStringAsFixed(1),
                      ),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelColumn extends StatelessWidget {
  const _LabelColumn({required this.leading});
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kLabelColumnWidth,
      child: leading ?? const SizedBox.shrink(),
    );
  }
}
