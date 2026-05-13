part of 'dialog_preset_picker.dart';

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.profile,
    required this.preset,
    required this.model,
    required this.activeDomains,
    required this.selected,
    required this.onTap,
  });
  final LlmProviderConfig profile;
  final LlmPresetConfig preset;
  final LlmModel model;
  final List<LlmProviderDomainEnum> activeDomains;
  final bool selected;
  final VoidCallback onTap;

  static const double _labelColumnWidth = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);

    final params = <String>[];
    final temp =
        preset.parameterValues[LlmParameterDefinitionIdEnum.temperature];
    if (temp != null) params.add('temp ${temp.toStringAsFixed(2)}');
    if (preset.reasoningEffort.isOn) {
      params.add('reasoning ${preset.reasoningEffort.label.toLowerCase()}');
    }
    final paramsLine = params.join(' · ');

    final metaLine = <String>[
      model.contextLabel,
      ?model.priceLabel,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      selected: selected,
      title: Row(
        children: [
          SizedBox(
            width: _labelColumnWidth,
            child: activeDomains.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in activeDomains)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: DomainPill(domain: d),
                        ),
                    ],
                  ),
          ),
          if (model.isUnavailable) ...[
            const BadgeModelUnavailable(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.providerEnum.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  model.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          const SizedBox(width: _labelColumnWidth),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metaLine,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (paramsLine.isNotEmpty)
                  Text(
                    paramsLine,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
