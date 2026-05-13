import 'package:json_annotation/json_annotation.dart';

part 'chat_tool_call_record.g.dart';

/// Sidecar entry persisted on a [ChatSwipe] every time the chat model
/// emitted a tool call as part of producing that swipe. Carries the
/// tool name, the args the model sent, the body returned to the model
/// (if any), and whether the call succeeded.
///
/// v1 is write-only — the chat bubble does not render it. Future work
/// (prompt builder reuse: "you already fetched X, do not refetch") will
/// read these.
@JsonSerializable()
class ChatToolCallRecord {
  const ChatToolCallRecord({
    required this.toolName,
    required this.args,
    required this.success,
    this.resultData,
    this.errorMessage,
  });

  factory ChatToolCallRecord.fromJson(Map<String, dynamic> json) =>
      _$ChatToolCallRecordFromJson(json);

  final String toolName;
  final Map<String, dynamic> args;

  /// Body the tool returned to the model. Null for side-effect-only
  /// tools (`send_selfie`) and for failed calls.
  @JsonKey(includeIfNull: false)
  final String? resultData;

  final bool success;

  /// Failure detail when [success] is false.
  @JsonKey(includeIfNull: false)
  final String? errorMessage;

  Map<String, dynamic> toJson() => _$ChatToolCallRecordToJson(this);
}
