import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';

/// A registered tool the chat model can call. Concrete subclasses live under
/// `builtin/`. The system-prompt advertisement, the tool-call schema sent to
/// the provider, and the executor are all derived from this one object so
/// adding a new tool is one file: register + system-prompt teaching all flow
/// from here.
abstract class ToolDefinition {
  const ToolDefinition();

  /// Stable id used by the LLM to reference this tool. Must be unique across
  /// the registry. Snake_case per provider convention.
  String get name;

  /// Short, model-facing description of what the tool does. Sent to the
  /// provider as part of the tool definition; the LLM reads this when
  /// deciding whether to call. Keep one sentence.
  String get description;

  /// JSON Schema for the tool's input arguments. App-data-aware so a tool
  /// can drop / include fields based on caller-supplied state — e.g.
  /// `send_selfie` omits `caption` from the schema when the session's
  /// "allow selfie captions" flag is off. Concrete tools cast [appData]
  /// to the typed record their host registered with; tools that don't
  /// need any state ignore [appData] and return a fixed schema.
  Map<String, Object?> parametersSchemaFor(Object appData);

  /// Long-form teaching block injected into the chat system prompt under
  /// the "available_tools" section. This is where you explain the *why* of
  /// the tool (e.g. "a selfie is how you show {{user}} something about
  /// yourself in this moment"). Optional — return empty string if the
  /// short [description] is enough on its own.
  String get systemPromptText;

  /// Maximum times this tool may run within one assistant turn (one
  /// outer call to `generateChatReply`, across all rounds of the manual
  /// tool loop). Excess calls return a `cap reached` failure to the
  /// model so the model can adjust. Concrete tools take this via
  /// constructor so the host app owns the cap values.
  int get maxCallsPerTurn;

  /// Short user-facing label rendered in the chat bubble while this
  /// tool is dispatching (between iterations of the manual tool loop).
  /// Plain text — the controller adds markdown italics. Examples:
  /// `'Sending selfie…'`, `'Browsing…'`. The service deduplicates and
  /// joins labels across the tools firing in one round.
  String get progressLabel;

  /// Execute the tool with [args] (the `input` map from the LLM's
  /// `ToolRequest`). The implementation typically delegates to a side-effect
  /// closure on [ctx] (e.g. `ctx.generateImage(...)`).
  Future<ToolResult> execute(ToolCallContext ctx, Map<String, dynamic> args);

  /// Releases long-lived resources held by the tool (e.g. HTTP clients).
  /// Default no-op; tools that hold per-instance state override.
  void dispose() {}
}
