import 'package:cardwave_llm/src/tools/tool_call.dart';
import 'package:cardwave_llm/src/utils/utils_llm.dart';
import 'package:genkit/genkit.dart';

/// Neutral chat message role used across the app. Isolated from any
/// provider-specific message type so we can swap LLM backends without
/// touching prompt builders or chat services.
enum LlmRunnerMessageRoleEnum { system, user, assistant, tool }

/// Tool result rolled into a runner message. One [LlmRunnerMessage] of
/// role [LlmRunnerMessageRoleEnum.tool] carries one of these so the model
/// sees what came back from a specific call. `callRef` ties it to the
/// `ToolCall.ref` from the prior assistant turn — providers that
/// require correlation (OpenAI's `tool_call_id`) round-trip via this.
class ToolResultPayload {
  const ToolResultPayload({
    required this.toolName,
    required this.callRef,
    required this.data,
  });
  final String toolName;
  final String? callRef;
  final String data;
}

class LlmRunnerMessage {
  const LlmRunnerMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolResult,
  });

  factory LlmRunnerMessage.system(String content) =>
      LlmRunnerMessage(role: LlmRunnerMessageRoleEnum.system, content: content);

  factory LlmRunnerMessage.user(String content) =>
      LlmRunnerMessage(role: LlmRunnerMessageRoleEnum.user, content: content);

  factory LlmRunnerMessage.assistant(String content) => LlmRunnerMessage(
    role: LlmRunnerMessageRoleEnum.assistant,
    content: content,
  );

  /// Assistant turn that emitted tool calls. Carries the model's prose
  /// (may be empty when the model only emitted tool requests) plus the
  /// [calls] it asked for; the manual tool loop appends one of these
  /// before the matching [LlmRunnerMessage.toolResult] entries.
  factory LlmRunnerMessage.assistantWithToolCalls({
    required String text,
    required List<ToolCall> calls,
  }) => LlmRunnerMessage(
    role: LlmRunnerMessageRoleEnum.assistant,
    content: text,
    toolCalls: calls,
  );

  /// One tool result rolled into the message history. The manual loop
  /// emits one entry per dispatched call so the model can correlate by
  /// [callRef] when the provider requires it.
  factory LlmRunnerMessage.toolResult({
    required String toolName,
    required String? callRef,
    required String data,
  }) => LlmRunnerMessage(
    role: LlmRunnerMessageRoleEnum.tool,
    content: '',
    toolResult: ToolResultPayload(
      toolName: toolName,
      callRef: callRef,
      data: data,
    ),
  );

  final LlmRunnerMessageRoleEnum role;
  final String content;

  /// Populated only on the assistant-with-tool-calls variant.
  final List<ToolCall>? toolCalls;

  /// Populated only on the tool variant.
  final ToolResultPayload? toolResult;

  // Assistant turns are stripped so prior reasoning traces never re-enter
  // the next prompt; user and system content goes verbatim. Tool-call
  // and tool-result variants emit structured genkit Parts so the
  // adapter writes the provider's native wire format (OpenAI's role:tool
  // turn, Anthropic's tool_use / tool_result blocks, Gemini's
  // function_response).
  Message toGenkit() {
    switch (role) {
      case LlmRunnerMessageRoleEnum.tool:
        final r = toolResult!;
        return Message(
          role: Role.tool,
          content: [
            ToolResponsePart(
              toolResponse: ToolResponse(
                name: r.toolName,
                ref: r.callRef,
                output: r.data,
              ),
            ),
          ],
        );
      case LlmRunnerMessageRoleEnum.assistant:
        final visible = UtilsLlm.stripThinkTags(content);
        final parts = <Part>[
          if (visible.isNotEmpty) TextPart(text: visible),
          if (toolCalls != null)
            for (final c in toolCalls!)
              ToolRequestPart(
                toolRequest: ToolRequest(
                  name: c.name,
                  ref: c.ref,
                  input: c.arguments,
                ),
              ),
        ];
        // genkit requires at least one part; an empty assistant turn
        // (model emitted only tool calls and no prose) still needs a
        // text part to keep the message valid.
        if (parts.isEmpty) parts.add(TextPart(text: ''));
        return Message(role: Role.model, content: parts);
      case LlmRunnerMessageRoleEnum.user:
        return Message(
          role: Role.user,
          content: [TextPart(text: content)],
        );
      case LlmRunnerMessageRoleEnum.system:
        return Message(
          role: Role.system,
          content: [TextPart(text: content)],
        );
    }
  }
}
