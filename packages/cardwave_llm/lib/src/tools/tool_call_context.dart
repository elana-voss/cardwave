import 'package:flutter/foundation.dart';

/// Opaque carrier the dispatcher passes to every tool's `execute` and
/// to `ToolDefinition.parametersSchemaFor`. The llm domain has no
/// knowledge of the app data shape — concrete tools cast [appData] to
/// the typed record their host built. Builtin tools cast to
/// `BuiltinToolAppData` (defined in app code) at the top of each method.
class ToolCallContext {
  const ToolCallContext({required this.appData, this.cancelToken});
  final Object appData;

  /// Flips to true when the user stops the in-flight reply. Long-running
  /// tools and the dispatcher re-check this after their awaits so work
  /// begun before Stop produces no result. Null for non-cancellable
  /// callers (tests, schema-gen).
  final ValueListenable<bool>? cancelToken;

  /// True once the user has stopped the reply.
  bool get isCancelled => cancelToken?.value ?? false;
}
