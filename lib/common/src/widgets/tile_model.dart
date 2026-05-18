import 'package:cardwave/common/src/widgets/badge_model_unavailable.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

class TileModel extends StatelessWidget {
  const TileModel({
    required this.model,
    super.key,
    this.onTap,
    this.selected = false,
    this.trailing,
    this.leading,
    this.showDetails = true,
  });
  final LlmModel model;
  final VoidCallback? onTap;
  final bool selected;
  final IconButton? trailing;
  final Widget? leading;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);

    final caps = model.capabilities;

    final inputCapabilityChips = <_ChipSpec>[
      if (caps.reasoning)
        const _ChipSpec(Icons.psychology_outlined, 'Reasoning'),
      if (caps.inputModalities.contains(LlmModelCapabilitiesEnum.image))
        const _ChipSpec(Icons.visibility_outlined, 'Vision'),
      if (caps.toolCalling) const _ChipSpec(Icons.build_outlined, 'Tools'),
      if (caps.structuredOutput)
        const _ChipSpec(Icons.data_object_outlined, 'JSON'),
      if (caps.inputModalities.contains(LlmModelCapabilitiesEnum.file))
        const _ChipSpec(Icons.description_outlined, 'Files'),
    ];
    final outputCapabilityChips = <_ChipSpec>[
      if (caps.outputModalities.contains(LlmModelCapabilitiesEnum.image))
        const _ChipSpec(Icons.image_outlined, 'Image'),
      if (caps.outputModalities.contains(LlmModelCapabilitiesEnum.video))
        const _ChipSpec(Icons.movie_outlined, 'Video'),
      if (caps.outputModalities.contains(LlmModelCapabilitiesEnum.audioTts))
        const _ChipSpec(Icons.record_voice_over_outlined, 'Speech'),
      if (caps.outputModalities.contains(LlmModelCapabilitiesEnum.audioMusic))
        const _ChipSpec(Icons.music_note_outlined, 'Music'),
    ];
    final chipChildren = <Widget>[
      for (final spec in inputCapabilityChips) _ChipWidget(spec: spec),
      for (final spec in outputCapabilityChips)
        _ChipWidget(spec: spec, accent: true),
    ];

    final idLower = model.id.toLowerCase();
    final nameLower = model.name.toLowerCase();
    final isIdRedundant =
        idLower == nameLower ||
        nameLower.startsWith(idLower) ||
        idLower.startsWith(nameLower);

    final metaLine = <String>[
      if (!isIdRedundant) model.id,
      model.contextLabel,
      ?model.priceLabel,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: leading,
      trailing: trailing,
      title: Row(
        children: [
          if (model.isUnavailable) ...[
            const BadgeModelUnavailable(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              model.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chipChildren,
            ),
          ],
        ],
      ),
      subtitle: showDetails
          ? Text(
              metaLine,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
  }

}

class _ChipSpec {
  const _ChipSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _ChipWidget extends StatelessWidget {
  const _ChipWidget({required this.spec, this.accent = false});
  final _ChipSpec spec;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = accent
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = accent
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(spec.icon, size: 13, color: fg),
          Text(
            spec.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
