/// Outcome of executing a single tool.
///
/// [data] carries content the model needs on the next round of the manual
/// tool loop. `null` data means side-effect-only (e.g. `send_selfie` —
/// the image is attached to the bubble; the model has nothing to read
/// back). Non-null data triggers another model invocation with the data
/// folded into the message history; that's how `fetch_website` reaches
/// the model on its next turn.
class ToolResult {
  const ToolResult.ok({this.data}) : success = true, errorMessage = null;
  const ToolResult.failure(this.errorMessage) : success = false, data = null;

  final bool success;
  final String? errorMessage;

  /// Markdown / text body the model should see on its next turn. Null for
  /// pure side-effect tools.
  final String? data;
}
