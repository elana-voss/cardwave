import 'package:cardwave_llm/src/image/image_generation_mode_enum.dart';
import 'package:cardwave_llm/src/tools/builtin/card_field_types.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';
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

  /// Reads the current value of a scalar field on the open card. Returns
  /// the empty string when the field is unset. Called by `card_field_get`.
  String readScalar(CardFieldScalar field);

  /// Number of entries in a list field on the open card. Called by
  /// `card_field_list_get` when `index` is null.
  int listSize(CardFieldList field);

  /// Reads one entry from a list field. Caller must validate the index
  /// against `listSize` first; out-of-bounds is the tool's failure to
  /// report, not the app's.
  String readListEntry(CardFieldList field, int index);

  /// Records a proposed scalar write. Returns a failure result when the
  /// open card is unavailable; the dispatcher feeds that failure back to
  /// the model and skips the batch entry. On success the proposal is
  /// appended to the per-batch buffer (see [beginCardEditBatch] /
  /// [takeBatch]) and `ToolResult.ok()` is returned.
  ToolResult proposeScalarSet(CardFieldScalar field, String content);

  /// Records a proposed list-index write. Returns failure for OOB index
  /// or when no card is open.
  ToolResult proposeListSet(CardFieldList field, int index, String content);

  /// Records a proposed append to a list field.
  ToolResult proposeListAppend(CardFieldList field, String content);

  /// Records a proposed delete of one list entry. Returns failure for OOB.
  ToolResult proposeListDelete(CardFieldList field, int index);

  /// Clears the per-batch proposal buffer at the start of a write-tool
  /// dispatch pass.
  void beginCardEditBatch();

  /// Returns and clears the proposal buffer. Proposals are returned in
  /// the order they were recorded, which mirrors the order of successful
  /// write-tool executions in the same dispatch pass — letting the
  /// caller correlate each proposal back to its source `ToolCall` by
  /// walking the writes and `writeRawResults` lists in step.
  List<CardEditProposal> takeBatch();
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
