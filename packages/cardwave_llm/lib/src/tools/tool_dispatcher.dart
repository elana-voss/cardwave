import 'dart:convert';

import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/tools/tool_call.dart';
import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_registry.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';

/// Runs the tool calls extracted from an LLM reply. The chat execution
/// service hands a list of [ToolCall]s plus a [ToolCallContext] to
/// [dispatch]; the dispatcher looks each up in the [ToolRegistry] and
/// executes it.
///
/// Per-turn caps are enforced via the external [callCounts] map. The
/// service owns that map across one outer `generateChatReply` so a cap
/// of 3 means 3 calls TOTAL in the turn, not 3 per loop iteration. The
/// per-tool cap value comes from the tool's `maxCallsPerTurn` getter.
class ToolDispatcher {
  const ToolDispatcher({required this.registry});
  final ToolRegistry registry;

  Future<List<ToolResult>> dispatch(
    List<ToolCall> calls,
    ToolCallContext ctx, {
    required Map<String, int> callCounts,
  }) async {
    final results = <ToolResult>[];
    for (final call in calls) {
      final tool = registry.get(call.name);
      if (tool == null) {
        toolsLogger.warning(
          LlmDiagnosticEvent(
            level: LlmDiagnosticLevel.warning,
            message:
                'ToolDispatcher: model called unknown tool "${call.name}"; skipping.',
          ),
        );
        results.add(ToolResult.failure('Unknown tool: ${call.name}'));
        continue;
      }
      final cap = tool.maxCallsPerTurn;
      final used = callCounts[call.name] ?? 0;
      if (used >= cap) {
        toolsLogger.warning(
          LlmDiagnosticEvent(
            level: LlmDiagnosticLevel.warning,
            message:
                'ToolDispatcher: cap reached for "${call.name}" '
                '(used=$used cap=$cap); skipping.',
          ),
        );
        results.add(
          ToolResult.failure(
            'Tool "${call.name}" cap reached for this turn ($cap).',
          ),
        );
        continue;
      }
      callCounts[call.name] = used + 1;
      _logToolCall(call);
      try {
        final result = await tool.execute(ctx, call.arguments);
        _logToolResult(call.name, result);
        results.add(result);
      } on Exception catch (e, st) {
        toolsLogger.severe(
          LlmDiagnosticEvent(
            level: LlmDiagnosticLevel.error,
            message: 'ToolDispatcher: tool "${call.name}" threw',
            error: e,
            stackTrace: st,
          ),
        );
        results.add(ToolResult.failure(e.toString()));
      }
    }
    return results;
  }

  static void _logToolCall(ToolCall call) {
    const encoder = JsonEncoder.withIndent('  ');
    String args;
    try {
      args = encoder.convert(call.arguments);
    } on Object {
      // Some tool args may contain non-JSON-encodable values; fall back to
      // a plain toString so the log line still shows what the model sent.
      args = call.arguments.toString();
    }
    toolsLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.toolCall,
        title: '${call.name} OUTGOING',
        body: '\nRef: ${call.ref ?? '(none)'}\nArgs: $args',
      ),
    );
  }

  /// Cap on inlining tool-result data into logs. Anything below this
  /// (name picks, fetched-website summaries) is fully readable; the
  /// large payloads (base64 selfies, video bytes) keep the size-only
  /// summary so logs stay scannable.
  static const _maxLoggedDataChars = 2048;

  static void _logToolResult(String toolName, ToolResult result) {
    final body = result.success
        ? '\nResult: ok\nData: ${_formatResultData(result.data)}'
        : '\nResult: failure\nError:  ${result.errorMessage ?? '(no message)'}';
    toolsLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.toolCall,
        title: '$toolName INCOMING',
        body: body,
      ),
    );
  }

  static String _formatResultData(String? data) {
    if (data == null) return '(none)';
    if (data.length <= _maxLoggedDataChars) return '\n$data';
    return '${data.length} chars (truncated above ${_maxLoggedDataChars}c)';
  }
}
