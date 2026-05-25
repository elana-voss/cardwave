import 'package:cardwave/common/common.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

const double _kLabelColumnWidth = 80;

/// Renders the model name + meta line (context, pricing) with a fixed-width
/// label column on the left. Caller decides what goes in the column —
/// the dashboard passes plain small-caps domain text, the inventory rows
/// pass a stack of [DomainPill] status chips. Width is reserved either way
/// so rows align across both surfaces.
class TileDomainModel extends StatelessWidget {
  const TileDomainModel({
    required this.model,
    super.key,
    this.leading,
    this.placeholderTitle = '',
    this.onTap,
    this.trailing,
    this.subtitleOverride,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeModel = model;

    if (activeModel == null) {
      return ListTile(
        onTap: onTap,
        title: Row(
          children: [
            _LabelColumn(leading: leading),
            Expanded(
              child: Text(
                placeholderTitle,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
            child: Text(
              metaLine,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
