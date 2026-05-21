import 'package:json_annotation/json_annotation.dart';

part 'memory_fact.g.dart';

/// A current-state or relationship fact about one or more entities — "what is
/// true now", as opposed to [StoryEvent]'s "what happened". Looked up by the
/// entities it is about ([subjects]), never embedded. A later fact can mark
/// this one superseded; reconcile revives it if that later fact is edited away.
@JsonSerializable(explicitToJson: true)
class MemoryFact {
  MemoryFact({
    required this.id,
    this.subjects = const [],
    required this.text,
    this.messageIds = const [],
    this.supersededAt,
    this.supersededBy,
  });

  factory MemoryFact.fromJson(Map<String, dynamic> json) =>
      _$MemoryFactFromJson(json);

  final String id;

  /// Normalized, lower-cased entity names this fact is about — the lookup key.
  final List<String> subjects;

  @JsonKey(defaultValue: '')
  final String text;

  /// The source messages the fact was drawn from; lets reconcile drop the fact
  /// when any of them changes, the same one-way link [StoryEvent] carries.
  final List<String> messageIds;

  /// Record time a later fact contradicted this one (epoch ms); null while the
  /// fact is current. Mutable — stamped by extraction's supersession pass.
  int? supersededAt;

  /// Id of the fact that superseded this one, so reconcile can revive this one
  /// when that later fact is edited away; cleared together with [supersededAt].
  String? supersededBy;

  Map<String, dynamic> toJson() => _$MemoryFactToJson(this);
}
