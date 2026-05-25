import 'package:json_annotation/json_annotation.dart';

part 'event_log_append.g.dart';

/// A single entry the director wants appended to the rolling event log.
/// The engine stamps `turn` when it ingests this; the director writes
/// only [text] and [significance].
@JsonSerializable()
class EventLogAppend {
  const EventLogAppend({required this.text, required this.significance});

  factory EventLogAppend.fromJson(Map<String, dynamic> json) =>
      _$EventLogAppendFromJson(json);

  final String text;

  /// 0..1
  final double significance;

  Map<String, dynamic> toJson() => _$EventLogAppendToJson(this);
}
