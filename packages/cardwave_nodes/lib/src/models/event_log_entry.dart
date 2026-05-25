import 'package:json_annotation/json_annotation.dart';

part 'event_log_entry.g.dart';

/// One entry in the rolling event log. [turn] is stamped by the engine
/// when the director's `eventLogAppend` is ingested; the director writes
/// only [text] and [significance]. [significance] is 0..1.
@JsonSerializable()
class EventLogEntry {
  const EventLogEntry({
    required this.turn,
    required this.text,
    required this.significance,
  });

  factory EventLogEntry.fromJson(Map<String, dynamic> json) =>
      _$EventLogEntryFromJson(json);

  final int turn;
  final String text;
  final double significance;

  Map<String, dynamic> toJson() => _$EventLogEntryToJson(this);
}
