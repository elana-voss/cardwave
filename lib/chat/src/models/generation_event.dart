import 'package:cardwave/chat/src/models/chat_tool_call_record.dart';
import 'package:cardwave/common/common.dart';

abstract class GenerationEvent {}

class GenerationTokenEvent extends GenerationEvent {
  GenerationTokenEvent(this.token);
  final String token;
}

/// Emitted at the end of a tool-using loop iteration so the controller
/// can clear whatever tokens it streamed for that iteration. The model's
/// intermediate prose (between tool calls) is intentionally not shown
/// to the user — the final iteration's text is the user-visible reply.
class GenerationTokenWipeEvent extends GenerationEvent {
  GenerationTokenWipeEvent();
}

/// Emitted right after [GenerationTokenWipeEvent] so the controller can
/// render a per-tool progress indicator while the tool dispatch runs.
/// [label] is composed by the chat-execution service from the tools
/// firing this round (deduped, comma-joined for multi-tool rounds).
/// Plain text — the controller wraps it in markdown italics for the
/// bubble.
class GenerationToolLoopProgressEvent extends GenerationEvent {
  GenerationToolLoopProgressEvent(this.label);
  final String label;
}

class GenerationCompleteEvent extends GenerationEvent {
  GenerationCompleteEvent({
    required this.finalContent,
    required this.generationTime,
    required this.tokenCount,
    required this.modelUsed,
    this.rawPrompt,
    this.toolCallRecords = const [],
    this.recalledMemory = const [],
    this.promptBreakdown,
  });
  final String finalContent;
  final String? rawPrompt;
  final int generationTime;
  final int tokenCount;
  final String modelUsed;

  /// Tool calls executed during the manual loop while producing this
  /// reply. Each entry pairs the model's call with the dispatched
  /// result. Empty when no tools fired. The chat controller writes
  /// these onto the swipe so future turns can see them.
  final List<ChatToolCallRecord> toolCallRecords;

  /// Story-memory lines recalled for this reply (each a preformatted "- …"
  /// line), carried so the controller can store them on the reply's swipe.
  /// Empty when memory was off or the path doesn't use memory.
  final List<String> recalledMemory;

  /// How the prompt for this reply filled the model's context window, carried
  /// so the controller can store it on the reply's swipe. Null on paths that
  /// emit no reply (dropped empty turn).
  final PromptContextBreakdown? promptBreakdown;
}
