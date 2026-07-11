part of 'dialog_preset_picker.dart';

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.model,
    required this.activeDomains,
    required this.selected,
    required this.onTap,
  });
  final LlmPresetConfig preset;
  final LlmModel model;
  final List<LlmProviderDomainEnum> activeDomains;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);

    final params = <String>[];
    final temp =
        preset.parameterValues[LlmParameterDefinitionIdEnum.temperature];
    if (temp != null) {
      params.add(t.settings.aiTab.tempParamAbbrev(value: temp.toStringAsFixed(2)));
    }
    if (preset.reasoningEffort.isOn) {
      params.add(
        t.settings.aiTab.reasoningParamLabel(
          level: preset.reasoningEffort.label.toLowerCase(),
        ),
      );
    }
    final paramsLine = params.join(' · ');

    final metaLine = <String>[
      model.contextLabel,
      ?model.priceLabel,
    ].join(' · ');

    final subtitleLine = [
      metaLine,
      if (paramsLine.isNotEmpty) paramsLine,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      selectedColor: theme.colorScheme.onSecondaryContainer,
      title: Row(
        spacing: 8,
        children: [
          if (activeDomains.isNotEmpty)
            Column(
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
          if (model.isUnavailable) const BadgeModelUnavailable(),
          Expanded(
            child: Text(
              model.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitleLine,
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
