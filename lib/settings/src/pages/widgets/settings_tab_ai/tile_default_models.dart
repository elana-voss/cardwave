import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/ai_tab_section_header.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_domain_preset.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

/// Dashboard at the top of the AI Providers tab — lists every domain
/// (text, image, ...) and the assigned model. Renders as an
/// [AiTabSectionHeader] (bold title + provider list subtitle + hairline
/// divider) followed by per-domain rows.
class TileDefaultModels extends StatelessWidget {
  const TileDefaultModels({
    required this.profiles,
    required this.activeProviders,
    required this.onChanged,
    super.key,
  });
  final List<LlmProviderConfig> profiles;
  final List<LLMProviderEnum> activeProviders;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final providerLabels = activeProviders
        .map((e) => LlmProvider.of(e).label)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiTabSectionHeader(
          title: t.settings.aiTab.defaultModelsHeader,
          subtitle: providerLabels.isEmpty ? null : providerLabels,
        ),
        const Divider(height: 1, thickness: 0.5),
        for (final domain in LlmProviderDomainEnum.values)
          TileDomainPreset(
            domain: domain,
            profiles: profiles,
            onChanged: onChanged,
          ),
      ],
    );
  }
}
