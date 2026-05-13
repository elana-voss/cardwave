import 'dart:async';

import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Only Anthropic and Gemini accept a reasoning/thinking knob through genkit
// today. OpenAI-compat providers (OpenAI, Grok, OpenRouter, NanoGpt) either
// always-reason by model id or have no wire-level control, so the tile is
// hidden there — it would just be decorative.
const Set<LLMProviderEnum> _supportedReasoningProviders = {
  LLMProviderEnum.anthropic,
  LLMProviderEnum.google,
};

class TileReasoningEffort extends StatelessWidget {
  const TileReasoningEffort({required this.chatSession, super.key});
  final ChatSession? chatSession;

  @override
  Widget build(BuildContext context) {
    if (chatSession == null) return const SizedBox.shrink();

    final settingsService = context.watch<SettingsService>();
    // LlmPureHelpers is an immutable stateless helper provided once —
    // `read`, not `watch`, is correct here. avoid_read_inside_build can't
    // tell the object never changes, so this hit is a false positive.
    // ignore: qcheck/avoid_read_inside_build
    final pureHelpers = context.read<LlmPureHelpers>();

    final profiles = settingsService.settings.providerConfigs;
    final resolved = pureHelpers.resolvePresetOrNull(
      configId: chatSession!.modelPresetId,
      providers: profiles,
    );
    if (resolved == null) return const SizedBox.shrink();
    if (!_supportedReasoningProviders.contains(
      resolved.provider.providerEnum,
    )) {
      return const SizedBox.shrink();
    }
    final preset = resolved.preset;
    if (!resolved.model.capabilities.reasoning) return const SizedBox.shrink();

    final effort = preset.reasoningEffort;
    final enabled = effort.isOn;
    const sliderBuckets = [
      LlmPresetConfigReasoningEffortEnum.low,
      LlmPresetConfigReasoningEffortEnum.medium,
      LlmPresetConfigReasoningEffortEnum.high,
    ];
    final sliderCurrent = enabled
        ? effort
        : LlmPresetConfigReasoningEffortEnum.medium;
    final sliderIndex = sliderBuckets.indexOf(sliderCurrent);

    void writeEffort(LlmPresetConfigReasoningEffortEnum next) {
      preset.reasoningEffort = next;
      unawaited(settingsService.saveSettings());
    }

    return ListTile(
      leading: Icon(enabled ? Icons.psychology : Icons.psychology_outlined),
      onTap: () => writeEffort(
        enabled
            ? LlmPresetConfigReasoningEffortEnum.off
            : LlmPresetConfigReasoningEffortEnum.medium,
      ),
      title: Text(enabled ? 'Reasoning — ${effort.label}' : 'Reasoning off'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Slider(
            value: sliderIndex.toDouble(),
            max: (sliderBuckets.length - 1).toDouble(),
            divisions: sliderBuckets.length - 1,
            label: sliderCurrent.label,
            onChanged: enabled
                // `v` is in `[0, sliderBuckets.length - 1]` by the slider's
                // `max`/`divisions`, so `v.round()` is a valid index.
                // ignore: qcheck/avoid_unsafe_collection_methods
                ? (v) => writeEffort(sliderBuckets[v.round()])
                : null,
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Text(
                'Uses extra tokens beyond your max response length.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
