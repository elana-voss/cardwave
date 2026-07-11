import 'dart:async';

import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Snapping 5-bucket slider for the active model preset's
/// `LlmParameterId.maxResponseLength`. Asymmetric snap: a stored value (e.g.
/// from the freeform presets dialog) displays as the closest bucket without
/// being overwritten — only an actual drag writes a canonical bucket value.
class TileMaxResponseLength extends StatelessWidget {
  const TileMaxResponseLength({required this.chatSession, super.key});
  final ChatSession? chatSession;

  @override
  Widget build(BuildContext context) {
    if (chatSession == null) return const SizedBox.shrink();

    final settingsService = context.watch<SettingsService>();
    final profiles = settingsService.settings.providerConfigs;
    final allPresets = profiles.expand((p) => p.allPresets).toList();
    final preset = allPresets
        .where((p) => p.id == chatSession!.modelPresetId)
        .firstOrNull;
    if (preset == null) return const SizedBox.shrink();

    final def = commonParameters.firstWhere(
      (p) => p.id == LlmParameterDefinitionIdEnum.maxResponseLength,
      orElse: () => throw StateError('maxResponseLength missing from commonParameters'),
    );
    final raw =
        preset.parameterValues[LlmParameterDefinitionIdEnum
            .maxResponseLength] ??
        def.defaultValue;

    // Read-side snap: display the closest bucket WITHOUT mutating `raw`.
    // The presets dialog can write fine-grained values; we visualize them
    // at the nearest bucket but only overwrite when the user actively drags.
    const buckets = _ResponseLengthBucketEnum.values;
    final current = _ResponseLengthBucketEnum.fromValue(raw);
    final currentIndex = buckets.indexOf(current);

    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: Text(
        t.chat.tileMaxResponseLength.titleWithBucket(bucket: current.label),
      ),
      subtitle: Slider(
        value: currentIndex.toDouble(),
        max: (buckets.length - 1).toDouble(),
        divisions: buckets.length - 1,
        label: t.chat.tileMaxResponseLength.sliderLabel(
          bucket: current.label,
          tokens: current.value,
        ),
        onChanged: (v) {
          // `v` is in `[0, buckets.length - 1]` by the slider's max/divisions.
          // ignore: qcheck/avoid_unsafe_collection_methods
          final picked = buckets[v.round()];
          preset.parameterValues = {
            ...preset.parameterValues,
            LlmParameterDefinitionIdEnum.maxResponseLength: picked.value
                .toDouble(),
          };
          unawaited(settingsService.saveSettings());
        },
      ),
    );
  }
}

enum _ResponseLengthBucketEnum {
  veryShort(80),
  short(180),
  medium(350),
  long(750),
  veryLong(1500)
  ;

  final int value;
  const _ResponseLengthBucketEnum(this.value);

  String get label => switch (this) {
    _ResponseLengthBucketEnum.veryShort =>
      t.chat.tileMaxResponseLength.bucketVeryShort,
    _ResponseLengthBucketEnum.short =>
      t.chat.tileMaxResponseLength.bucketShort,
    _ResponseLengthBucketEnum.medium =>
      t.chat.tileMaxResponseLength.bucketMedium,
    _ResponseLengthBucketEnum.long =>
      t.chat.tileMaxResponseLength.bucketLong,
    _ResponseLengthBucketEnum.veryLong =>
      t.chat.tileMaxResponseLength.bucketVeryLong,
  };

  static _ResponseLengthBucketEnum fromValue(num stored) {
    var best = _ResponseLengthBucketEnum.medium;
    var bestDelta = (stored - best.value).abs();
    for (final b in _ResponseLengthBucketEnum.values) {
      final delta = (stored - b.value).abs();
      if (delta < bestDelta) {
        best = b;
        bestDelta = delta;
      }
    }
    return best;
  }
}
