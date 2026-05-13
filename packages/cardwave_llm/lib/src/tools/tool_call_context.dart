/// Opaque carrier the dispatcher passes to every tool's `execute` and
/// to `ToolDefinition.parametersSchemaFor`. The llm domain has no
/// knowledge of the app data shape — concrete tools cast [appData] to
/// the typed record their host built. Builtin tools cast to
/// `BuiltinToolAppData` (defined in app code) at the top of each method.
class ToolCallContext {
  const ToolCallContext({required this.appData});
  final Object appData;
}
