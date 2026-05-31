/// One tool invocation extracted from an LLM response. The chat runner builds
/// a list of these from `ToolRequestPart`s in the streamed reply or the final
/// message; the dispatcher consumes them and runs each registered tool.
///
/// [ref] mirrors `ToolRequest.ref` from genkit (the provider's call id). The
/// chat loop sends each tool result back to the model as a tool-role message
/// keyed by this ref, so the provider can match the result to its call.
class ToolCall {
  const ToolCall({required this.name, required this.arguments, this.ref});
  final String name;
  final Map<String, dynamic> arguments;
  final String? ref;
}
