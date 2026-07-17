import 'dart:async';
import 'dart:convert';

import 'package:cardwave_llm/src/models/llm_runner_message.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/tools/tool_call.dart';
import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

// Streaming cancellation closes the genkit subscription the instant
// cancelToken flips — no waiting for the next chunk boundary. Non-streaming
// requests cannot be cancelled mid-flight because genkit owns the HTTP client.
class LlmRunner {
  const LlmRunner({
    required ModelRef<Object?> model,
    required Genkit genkit,
    Object? config,
  }) : _model = model,
       _genkit = genkit,
       _config = config;
  // `ModelRef` instead of `Model` because some plugins (genkit_llamadart)
  // don't implement `GenkitPlugin.resolve`; their actions are materialised
  // lazily by the registry on first `generate`. `Model` extends `Action`
  // and implements `ModelRef`, so cloud callers that pass a resolved
  // `Model` still type-check.
  final ModelRef<Object?> _model;
  final Genkit _genkit;
  final Object? _config;

  // Exposed so callers can log outgoing metadata BEFORE firing the request —
  // otherwise a hung or errored call would leave the log silent.
  String get modelName => _model.name;
  String get configType => _config?.runtimeType.toString() ?? 'null';
  String get configRepr => _stringifyConfig(_config);

  Future<LlmRunnerResult> generate({
    required List<LlmRunnerMessage> messages,
    bool stream = false,
    ValueNotifier<bool>? cancelToken,
    void Function(String token)? onToken,
    List<Tool<Object?, Object?>>? tools,
  }) async {
    final gkMessages = messages.map((m) => m.toGenkit()).toList();
    // returnToolRequests: true keeps genkit from invoking each tool's `fn`
    // and returns the unexecuted ToolRequestPart(s) instead. Our
    // ToolDispatcher runs them. maxTurns: 1 makes the no-round-trip
    // contract explicit — even if the framework tried to continue, it
    // can't.
    final hasTools = tools != null && tools.isNotEmpty;

    if (stream && onToken != null) {
      final visible = StringBuffer();
      final reasoning = StringBuffer();
      final toolCalls = <ToolCall>[];
      final actionStream = _genkit.generateStream(
        model: _model,
        messages: gkMessages,
        config: _config,
        tools: hasTools ? tools : null,
        toolChoice: hasTools ? 'auto' : null,
        returnToolRequests: hasTools ? true : null,
        maxTurns: hasTools ? 1 : null,
      );
      final completer = Completer<void>();
      void onCancelRequested() {
        if (cancelToken?.value == true && !completer.isCompleted) {
          completer.complete();
        }
      }

      cancelToken?.addListener(onCancelRequested);
      final sub = actionStream.listen(
        (chunk) {
          if (cancelToken?.value == true) return;
          for (final part in chunk.content) {
            if (part.isReasoning) {
              final r = part.reasoning ?? '';
              if (r.isNotEmpty) reasoning.write(r);
              continue;
            }
            if (part.isText) {
              final t = part.text ?? '';
              if (t.isEmpty) continue;
              visible.write(t);
              onToken(t);
              continue;
            }
            // Tool calls in a streaming response can arrive either as
            // streamed chunks (some providers emit incremental tool args)
            // or only on the final message — we accumulate from chunks
            // here and dedupe against the final message below.
            _appendToolCallIfRequest(part, toolCalls);
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace s) {
          if (!completer.isCompleted) completer.completeError(e, s);
        },
        cancelOnError: true,
      );
      try {
        await completer.future;
      } finally {
        cancelToken?.removeListener(onCancelRequested);
        await sub.cancel();
      }
      // Some providers (and some genkit adapter versions) only deliver
      // ToolRequestParts on the final assembled response, not in the
      // streamed chunks. Pull tool calls from the final response too, then
      // dedupe by `ref` so we end up with one entry per call regardless of
      // which path delivered it.
      int? streamInputTokens;
      if (cancelToken?.value != true) {
        try {
          final finalResponse = await actionStream.onResult;
          streamInputTokens = finalResponse.usage?.inputTokens?.round();
          final finalMessage = finalResponse.message;
          if (finalMessage != null) {
            for (final part in finalMessage.content) {
              _appendToolCallIfRequest(part, toolCalls);
            }
          }
        } catch (e, st) {
          // Plain catch: this is a best-effort fallback — an Error from the
          // adapter must not sink a reply whose tokens already streamed.
          runnerLogger.warning(
            LlmDiagnosticEvent(
              level: LlmDiagnosticLevel.warning,
              message:
                  'LlmRunner: failed to read final stream response for tool '
                  'capture; using chunk-captured tools only',
              error: e,
              stackTrace: st,
            ),
          );
        }
      }
      return _buildResult(
        visible: visible.toString(),
        reasoning: reasoning.toString(),
        finishReason: cancelToken?.value == true ? 'cancelled' : 'stream',
        toolCalls: _dedupeToolCalls(toolCalls),
        inputTokens: streamInputTokens,
      );
    }

    final response = await _genkit.generate(
      model: _model,
      messages: gkMessages,
      config: _config,
      tools: hasTools ? tools : null,
      toolChoice: hasTools ? 'auto' : null,
      returnToolRequests: hasTools ? true : null,
      maxTurns: hasTools ? 1 : null,
    );
    final finishReason = response.finishReason?.value ?? 'unknown';
    final inputTokens = response.usage?.inputTokens?.round();
    final message = response.message;
    if (message == null) {
      return _buildResult(
        visible: response.text,
        reasoning: '',
        finishReason: finishReason,
        toolCalls: const [],
        inputTokens: inputTokens,
      );
    }
    final visible = StringBuffer();
    final reasoning = StringBuffer();
    final toolCalls = <ToolCall>[];
    for (final part in message.content) {
      if (part.isReasoning) {
        reasoning.write(part.reasoning ?? '');
      } else if (part.isText) {
        visible.write(part.text ?? '');
      } else {
        _appendToolCallIfRequest(part, toolCalls);
      }
    }
    return _buildResult(
      visible: visible.toString(),
      reasoning: reasoning.toString(),
      finishReason: finishReason,
      toolCalls: toolCalls,
      inputTokens: inputTokens,
    );
  }

  /// Collapses duplicate captures of the same tool call. The same call may
  /// appear once in the streamed chunks and again in the final assembled
  /// response, depending on the provider. Dedupes by `ref` (provider call
  /// id) when present; falls back to `name + JSON arguments` when no ref
  /// is available so we never run a tool twice for the same model decision.
  static List<ToolCall> _dedupeToolCalls(List<ToolCall> calls) {
    if (calls.length <= 1) return calls;
    final seen = <String>{};
    final out = <ToolCall>[];
    for (final c in calls) {
      final key = c.ref != null && c.ref!.isNotEmpty
          ? 'ref:${c.ref}'
          : 'na:${c.name}|${jsonEncode(c.arguments)}';
      if (seen.add(key)) out.add(c);
    }
    return out;
  }

  static void _appendToolCallIfRequest(Part part, List<ToolCall> sink) {
    if (!part.isToolRequest) return;
    final req = part.toolRequest;
    if (req == null) return;
    // Some providers emit incremental tool-arg deltas during streaming
    // (each chunk marked partial) before a final non-partial part. Skip
    // the partials so the dispatcher only sees one entry per tool call.
    if (req.partial == true) return;
    sink.add(
      ToolCall(
        name: req.name,
        arguments: req.input ?? <String, dynamic>{},
        ref: req.ref,
      ),
    );
  }

  Future<String> complete(String prompt) async {
    runnerLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.runner,
        title: 'OUTGOING REQUEST',
        body:
            '\nModel: ${_model.name}\nPromptLen: ${prompt.length}\nPrompt: $prompt',
        modelId: _model.name,
      ),
    );

    final response = await _genkit.generate(
      model: _model,
      prompt: prompt,
      config: _config,
    );
    return response.text;
  }

  /// Variant of [complete] that constrains the model's reply to
  /// [outputSchema]. Caller wraps a hand-built JSON-schema Map via
  /// `SchemanticType.from<Map<String, dynamic>>(...)`. The system-domain
  /// picker filters models by `LlmCapabilities.structuredOutput`, so the
  /// configured model is guaranteed to support the schema.
  Future<Map<String, dynamic>> completeStructured(
    String prompt,
    SchemanticType<Map<String, dynamic>> outputSchema,
  ) async {
    runnerLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.runner,
        title: 'OUTGOING REQUEST (structured)',
        body:
            '\nModel: ${_model.name}\nPromptLen: ${prompt.length}'
            '\nOutputSchema: yes\nPrompt: $prompt',
        modelId: _model.name,
      ),
    );

    final response = await _genkit.generate(
      model: _model,
      prompt: prompt,
      config: _config,
      outputSchema: outputSchema,
    );
    // jsonOutput first tries the binding-parsed `output`, then falls back
    // to extracting JSON from the raw text (genkit's lenient path). Null
    // here means the model returned nothing the schema can map onto — a
    // real upstream failure, not a can't-happen case.
    final raw = response.jsonOutput;
    if (raw == null) {
      throw Exception(
        'LLM "${_model.name}" returned no parseable structured output.',
      );
    }
    return raw.cast<String, dynamic>();
  }

  LlmRunnerResult _buildResult({
    required String visible,
    required String reasoning,
    required String finishReason,
    required List<ToolCall> toolCalls,
    int? inputTokens,
  }) {
    return LlmRunnerResult(
      text: _wrapReasoning(visible: visible, reasoning: reasoning),
      visibleLen: visible.length,
      reasoning: reasoning,
      finishReason: finishReason,
      modelName: _model.name,
      configType: _config?.runtimeType.toString() ?? 'null',
      configRepr: _stringifyConfig(_config),
      toolCalls: toolCalls,
      inputTokens: inputTokens,
    );
  }

  // Unifies Anthropic/Gemini structured ReasoningPart output with the
  // OpenAI-compat inline-tag format, so the bubble renderer and replay
  // stripper can treat both sources identically.
  static String _wrapReasoning({
    required String visible,
    required String reasoning,
  }) {
    if (reasoning.isEmpty) return visible;
    return '<think>$reasoning</think>\n\n$visible';
  }

  static String _stringifyConfig(Object? cfg) {
    if (cfg == null) return 'null';
    try {
      // Duck-typed toJson() for telemetry — provider configs each define their
      // own serialization but share no interface. Falls back to toString() if
      // the object can't be encoded.
      // ignore: qcheck/avoid_dynamic
      final json = (cfg as dynamic).toJson();
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      // Plain catch: a config without toJson() throws NoSuchMethodError
      // (an Error) — telemetry must fall back, never crash the request.
      return cfg.toString();
    }
  }
}

class LlmRunnerResult {
  const LlmRunnerResult({
    required this.text,
    required this.visibleLen,
    required this.reasoning,
    required this.finishReason,
    required this.modelName,
    required this.configType,
    required this.configRepr,
    required this.toolCalls,
    this.inputTokens,
  });
  final String text;
  final int visibleLen;
  final String reasoning;
  final String finishReason;
  final String modelName;
  final String configType;
  final String configRepr;

  /// Tool calls extracted from the LLM reply (`ToolRequestPart`s in genkit
  /// terms). Empty when no tool was emitted or tools weren't passed to
  /// [LlmRunner.generate]. The chat controller hands these to the
  /// `ToolDispatcher` after the stream finalizes.
  final List<ToolCall> toolCalls;

  /// The provider's reported prompt (input) token count for this generation,
  /// or null when the provider returned no usage. Used to anchor the prompt
  /// breakdown's filled width to the real number rather than the estimate.
  final int? inputTokens;

  int get reasoningLen => reasoning.length;
}
