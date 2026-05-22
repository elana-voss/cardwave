import 'package:json_annotation/json_annotation.dart';

part 'memory_thread.g.dart';

/// An unresolved story thread — "what's pending": a promise made, a debt owed,
/// an unanswered question. Like [MemoryFact] it is looked up by the entities it
/// is about ([subjects]) and carries no vector. Unlike a fact it has a close
/// lifecycle: a later window's messages can resolve it, after which it stops
/// surfacing; if those resolving messages are edited away, reconcile reopens it.
@JsonSerializable(explicitToJson: true)
class MemoryThread {
  MemoryThread({
    required this.id,
    this.subjects = const [],
    required this.text,
    this.messageIds = const [],
    this.resolvedAt,
    this.resolvedByMessageIds = const [],
  });

  factory MemoryThread.fromJson(Map<String, dynamic> json) =>
      _$MemoryThreadFromJson(json);

  final String id;

  /// Normalized, lower-cased entity names this thread is about — the lookup key.
  final List<String> subjects;

  @JsonKey(defaultValue: '')
  final String text;

  /// The messages the thread was opened from; lets reconcile drop the thread
  /// when any of them changes, the same one-way link facts and events carry.
  final List<String> messageIds;

  /// Record time the thread was resolved (epoch ms); null while still open.
  /// Mutable — stamped by extraction's resolution pass.
  int? resolvedAt;

  /// The messages whose content resolved the thread, so reconcile can reopen it
  /// when any of them is edited away; cleared together with [resolvedAt].
  List<String> resolvedByMessageIds;

  Map<String, dynamic> toJson() => _$MemoryThreadToJson(this);
}
