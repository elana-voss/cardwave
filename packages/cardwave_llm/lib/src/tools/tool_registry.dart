import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/tools/tool_definition.dart';
// genkit also exports a `ToolDefinition` (the genkit-internal metadata type
// used by adapters); hide it here so our local `ToolDefinition` resolves
// unambiguously.
import 'package:genkit/genkit.dart' hide ToolDefinition;
import 'package:schemantic/schemantic.dart';

/// In-memory store of tool definitions. App startup registers each tool
/// instance once; `chat_execution_service` queries by name when building
/// the per-call tool list, and `chat_prompt_builder` queries the same set
/// to compose the system-prompt advertisement.
class ToolRegistry {
  ToolRegistry({required this.promptRepository});

  final PromptRepository promptRepository;
  final Map<String, ToolDefinition> _tools = {};

  void register(ToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  void dispose() {
    for (final tool in _tools.values) {
      tool.dispose();
    }
  }

  ToolDefinition? get(String name) => _tools[name];

  /// Filters the registered tools down to those whose names appear in
  /// [allowedNames]. The caller derives that list from per-domain tool flags
  /// on the session's media config. Names not in the registry are ignored
  /// (forward-compat with sessions that referenced a tool we've since
  /// removed). The caller is expected to also gate on
  /// `model.capabilities.toolCalling` before passing this list to the
  /// runner.
  List<ToolDefinition> enabledFor(List<String> allowedNames) {
    return [
      for (final name in allowedNames)
        if (_tools[name] != null) _tools[name]!,
    ];
  }

  /// Composes the chat system prompt's "available_tools" section. Returns
  /// an empty string when [enabled] is empty so the prompt builder can skip
  /// the section entirely.
  String buildSystemPromptAdvertisement(List<ToolDefinition> enabled) {
    if (enabled.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln(promptRepository.toolAdvertisementPreamble.trim());
    for (final tool in enabled) {
      buf.writeln();
      buf.writeln('Tool `${tool.name}`: ${tool.description}');
      final extra = tool.systemPromptText.trim();
      if (extra.isNotEmpty) {
        buf.writeln(extra);
      }
    }
    return buf.toString().trim();
  }

  /// Translates our [ToolDefinition]s to genkit [Tool]s for the runner.
  /// Schemas are resolved per-call so a tool can vary which fields it
  /// advertises (e.g. `send_selfie` drops `caption` when the session
  /// disables captions). [appData] is the same opaque payload the
  /// dispatcher will pass to `execute`; tools cast to their expected
  /// record type and read whatever fields they need.
  ///
  /// The [Tool.fn] is intentionally a thrower — we always pass
  /// `returnToolRequests: true` to the runner so genkit returns the
  /// unexecuted request parts instead of invoking `fn`. If `fn` ever
  /// runs, that's a wiring bug and we want it to fail loudly.
  List<Tool<Object?, Object?>> toGenkitTools(
    List<ToolDefinition> enabled,
    Object appData,
  ) {
    return [
      for (final tool in enabled)
        Tool<Map<String, dynamic>, Map<String, dynamic>>(
          name: tool.name,
          description: tool.description,
          inputSchema: SchemanticType.from<Map<String, dynamic>>(
            jsonSchema: tool.parametersSchemaFor(appData),
            parse: (json) => json is Map<String, dynamic>
                ? json
                : Map<String, dynamic>.of((json as Map).cast<String, dynamic>()),
          ),
          fn: (input, ctx) async {
            throw StateError(
              'ToolRegistry: genkit fn for "${tool.name}" was invoked, but '
              'returnToolRequests:true is supposed to keep the runner from '
              'calling it. Either the runner is misconfigured or genkit '
              'changed behaviour — investigate before silencing.',
            );
          },
        ),
    ];
  }
}
