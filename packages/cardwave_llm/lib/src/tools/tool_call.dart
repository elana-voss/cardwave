/// One tool invocation extracted from an LLM response. The chat runner builds
/// a list of these from `ToolRequestPart`s in the streamed reply or the final
/// message; the dispatcher consumes them and runs each registered tool.
///
/// [ref] mirrors `ToolRequest.ref` from genkit (the provider's call id) and
/// is preserved end-to-end even though we don't currently send tool results
/// back to the model — kept so a future round-tripping tool can correlate.
class ToolCall {
  const ToolCall({required this.name, required this.arguments, this.ref});
  final String name;
  final Map<String, dynamic> arguments;
  final String? ref;
}
