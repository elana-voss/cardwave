import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_tool_call_record.dart';
import 'package:cardwave/common/common.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_swipe.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatSwipe {
  ChatSwipe({
    required this.content,
    this.tokenCount,
    List<String>? attachedImages,
    this.imageCaption,
    this.videoPath,
    List<ChatToolCallRecord>? toolCalls,
    List<String>? recalledMemory,
    this.promptBreakdown,
    this.waitingFor = BubbleWaitingForEnum.complete,
    this.waitingForLabel,
  }) : attachedImages = attachedImages ?? <String>[],
       toolCalls = toolCalls ?? <ChatToolCallRecord>[],
       recalledMemory = recalledMemory ?? <String>[];

  factory ChatSwipe.fromJson(Map<String, dynamic> json) =>
      _$ChatSwipeFromJson(json);
  String content;
  int? tokenCount;

  /// Cards-domain-relative paths to images that belong to this swipe.
  /// Kept separate from `content` so image data never leaks into
  /// markdown syntax the LLM sees — see `ChatPromptBuilder._buildHistory`.
  @JsonKey(defaultValue: <String>[])
  List<String> attachedImages;

  /// Caption to render in the chat bubble underneath the attached image.
  /// Set by the `send_selfie` tool when the chat model authors a caption
  /// alongside the selfie. The same text is also passed to the image-gen
  /// model with a "render this on the image" instruction; the bubble caption
  /// is the always-visible fallback in case the image-gen model dropped it.
  @JsonKey(includeIfNull: false)
  String? imageCaption;

  /// Cards-domain-relative path to the generated MP4 for this swipe, or
  /// null if no video has been generated. Written by
  /// `VideoGenerationService` after a job completes — the service persists
  /// bytes under `<chatDir>/<chatId>/video/` and stamps the resulting
  /// relative path here. The chat bubble reads this to decide whether to
  /// mount `VideoPlayerInline`. Regenerating a swipe with different config
  /// (resolution / aspect / duration) produces a new filename and replaces
  /// the path; old MP4s stay on disk as orphans (cache-size trimming is
  /// deferred, see MEMORY.md).
  @JsonKey(includeIfNull: false)
  String? videoPath;

  /// Tool calls the chat model emitted while producing this swipe, with
  /// the bodies returned to the model (if any). Persisted so future
  /// turns can avoid duplicate work (e.g. "you already fetched this
  /// URL"); the chat bubble does not render these in v1.
  @JsonKey(defaultValue: <ChatToolCallRecord>[])
  List<ChatToolCallRecord> toolCalls;

  /// Story-memory lines recalled for this swipe and fed into its prompt, each
  /// already formatted as a "- …" line. Persisted so the reply can show what
  /// memory informed it; empty when memory was off or nothing matched. Whether
  /// it renders is gated by the app-wide `showRecalledMemory` setting.
  @JsonKey(defaultValue: <String>[])
  List<String> recalledMemory;

  /// How this swipe's prompt filled the model's context window. Transient —
  /// held only for the live turn so the breakdown bar can show under the last
  /// reply, never written to or read from disk. Null after a reload.
  @JsonKey(includeFromJson: false, includeToJson: false)
  PromptContextBreakdown? promptBreakdown;

  /// Drives the bubble's progress indicator. Single source of truth for
  /// "is this swipe in flight, and on what". Runtime-only — never persisted.
  @JsonKey(includeFromJson: false, includeToJson: false)
  BubbleWaitingForEnum waitingFor;

  /// Override label for the indicator. Used by `runningTool` (filled
  /// from the tool's `progressLabel`) and by the video flow (filled
  /// per job phase: "Polling… 47%", "Downloading…", etc.). Null falls
  /// back to `waitingFor.defaultLabel`. Runtime-only.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? waitingForLabel;

  Map<String, dynamic> toJson() => _$ChatSwipeToJson(this);
}
