import 'package:cardwave_llm/src/image/image_generation_mode_enum.dart';
import 'package:cardwave_llm/src/video/video_generation_mode_enum.dart';

/// State the builtin tools' `parametersSchemaFor` methods need. Read-only;
/// no closures here so the schema-gen path can hand in a lightweight
/// instance that doesn't yet know which target message a tool will fire
/// against. App constructs it from the active session's media config.
abstract class BuiltinToolSchemaContext {
  /// Drives whether `send_selfie`'s schema requires a `caption` field.
  /// Reflects `session.configMedia.imageToolSelfieCaptionsAllowed` ?? false.
  bool get imageToolSelfieCaptionsAllowed;
}

/// Full app-data hook the builtin tools cast to inside `execute`. Adds
/// the closures the side-effect tools invoke to attach media / confirm
/// fetches against the in-flight bubble. The package treats the cast
/// type as opaque inside `ToolCallContext.appData`.
abstract class BuiltinToolAppData implements BuiltinToolSchemaContext {
  Future<void> generateImage({
    required ImageGenerationModeEnum mode,
    String? freePrompt,
    String? caption,
  });

  Future<void> generateVideo({
    required VideoGenerationModeEnum mode,
    String? freePrompt,
  });

  Future<bool> confirmFetch(String url, {String? purpose});

  /// Names already returned by `suggest_name` in the active chat. The
  /// package treats these as opaque accessors so it doesn't need to know
  /// about ChatSession; the app side reads them off the active session.
  /// The `suggest_name` tool reads and mutates these sets directly.
  Set<String> get usedFirstNames;
  Set<String> get usedLastNames;
}

/// State-only impl for the `toGenkitTools` schema-gen path. Built before
/// the per-iteration target message exists; holds nothing the tools'
/// `execute` would need (those run later via the full
/// [BuiltinToolAppData]).
///
/// NEVER pass an instance of this to `ToolDispatcher.dispatch` /
/// `ToolDefinition.execute` — the tool's execute path casts to
/// [BuiltinToolAppData], which this class does not implement, so the cast
/// would fail at runtime with no compile-time signal. The dispatch path
/// must always receive the full app-side concrete impl.
class BuiltinToolSchemaOnly implements BuiltinToolSchemaContext {
  const BuiltinToolSchemaOnly({required this.imageToolSelfieCaptionsAllowed});

  @override
  final bool imageToolSelfieCaptionsAllowed;
}
