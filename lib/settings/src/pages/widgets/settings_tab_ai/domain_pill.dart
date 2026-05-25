import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/dialog_preset_picker.dart'
    show DialogPresetPicker;
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_provider_profile.dart'
    show TileProviderProfile;
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

/// Filled primary-container chip displaying a domain label. Used as a
/// status badge in [TileProviderProfile] inventory rows ("this preset is
/// currently used for X") and in [DialogPresetPicker] rows. The dashboard
/// rows up top use a plain small-caps label instead, so the chip's
/// meaning stays unambiguous: chip = "currently assigned here".
class DomainPill extends StatelessWidget {
  const DomainPill({required this.domain, super.key});
  final LlmProviderDomainEnum domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: theme.colorScheme.outline),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        domain.label,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
