import 'package:cardwave/common/src/models/prompt_segment_kind_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'prompt_breakdown.g.dart';

/// One assembled part of a chat prompt and its token cost. The cost is the
/// character-based estimate; exact per-part counts aren't available across
/// providers, so these get scaled to the real prompt total at render time
/// when the provider reported one.
@JsonSerializable(explicitToJson: true)
class PromptSegmentEntry {
  PromptSegmentEntry({required this.kind, required this.tokens});

  factory PromptSegmentEntry.fromJson(Map<String, dynamic> json) =>
      _$PromptSegmentEntryFromJson(json);
  final PromptSegmentKindEnum kind;
  final int tokens;
  Map<String, dynamic> toJson() => _$PromptSegmentEntryToJson(this);
}

/// A snapshot of how one generated reply's prompt filled the model's context
/// window: each part and its estimated size, the space held back for the
/// reply, the context window, and the provider's real input-token count when
/// it reported one. Stored per swipe so the breakdown bar can show, after the
/// fact, what the context looked like for that exact generation.
@JsonSerializable(explicitToJson: true)
class PromptContextBreakdown {
  PromptContextBreakdown({
    required this.contextSize,
    required this.reservedReply,
    required this.segments,
    this.realInputTokens,
  });

  factory PromptContextBreakdown.fromJson(Map<String, dynamic> json) =>
      _$PromptContextBreakdownFromJson(json);

  /// The model's context window in tokens — the full width of the bar.
  final int contextSize;

  /// Tokens the builder reserves for the model's answer; never sent as input.
  final int reservedReply;

  /// The provider's actual prompt-token count for this generation, or null
  /// when the provider reported none. When set it is the exact filled width
  /// and the per-segment estimates are scaled to sum to it.
  @JsonKey(includeIfNull: false)
  final int? realInputTokens;

  final List<PromptSegmentEntry> segments;

  /// Sum of the per-part character estimates.
  @JsonKey(includeFromJson: false, includeToJson: false)
  int get estimatedTotal => segments.fold(0, (sum, s) => sum + s.tokens);

  /// Best available figure for tokens actually sent: the provider's real
  /// count when present, else the summed estimate.
  @JsonKey(includeFromJson: false, includeToJson: false)
  int get promptTokens => realInputTokens ?? estimatedTotal;

  /// Prompt plus the reply reservation — the filled part of the window.
  @JsonKey(includeFromJson: false, includeToJson: false)
  int get usedTokens => promptTokens + reservedReply;

  /// Unfilled context to the right of the bar.
  @JsonKey(includeFromJson: false, includeToJson: false)
  int get freeTokens {
    final free = contextSize - usedTokens;
    return free < 0 ? 0 : free;
  }

  /// A segment's size scaled so the parts sum to the real prompt total. With
  /// no real total (provider reported none) the raw estimate is returned.
  int scaledTokensFor(PromptSegmentEntry segment) {
    final est = estimatedTotal;
    final real = realInputTokens;
    if (real == null || est == 0) return segment.tokens;
    return ((segment.tokens / est) * real).round();
  }

  /// Returns a copy with the provider's real input-token count attached. The
  /// builder produces the breakdown before generation; the caller stamps the
  /// real total once the provider reports it.
  PromptContextBreakdown withRealInputTokens(int? tokens) =>
      PromptContextBreakdown(
        contextSize: contextSize,
        reservedReply: reservedReply,
        segments: segments,
        realInputTokens: tokens,
      );

  /// The ordered slices for the bar and detail dialog: each prompt part scaled
  /// to the real total, then the reply reservation, then free space. [kind] is
  /// null only for the free slice. One source of truth so the bar, its legend,
  /// and the dialog never drift.
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<PromptBreakdownRow> get displayRows => [
    for (final segment in segments)
      PromptBreakdownRow(
        label: segment.kind.label,
        tokens: scaledTokensFor(segment),
        kind: segment.kind,
      ),
    PromptBreakdownRow(
      label: PromptSegmentKindEnum.reservedReply.label,
      tokens: reservedReply,
      kind: PromptSegmentKindEnum.reservedReply,
    ),
    PromptBreakdownRow(label: 'Free', tokens: freeTokens),
  ];

  Map<String, dynamic> toJson() => _$PromptContextBreakdownToJson(this);
}

/// A single labelled, sized slice for the breakdown bar and detail dialog.
/// [kind] is null for the free (unfilled) slice; otherwise it selects the
/// slice's colour.
class PromptBreakdownRow {
  const PromptBreakdownRow({
    required this.label,
    required this.tokens,
    this.kind,
  });
  final String label;
  final int tokens;
  final PromptSegmentKindEnum? kind;
}
