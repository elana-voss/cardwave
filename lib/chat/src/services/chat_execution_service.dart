import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/chat_tool_call_record.dart';
import 'package:cardwave/chat/src/models/generation_event.dart';
import 'package:cardwave/chat/src/services/chat_prompt_builder.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/memory/memory.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_names/cardwave_names.dart';
import 'package:flutter/foundation.dart';

/// Closure shape the chat controller hands to [ChatExecutionService]
/// so the manual tool loop can dispatch tool calls without the service
/// importing controller types. The controller wires this to a
/// [ToolDispatcher.dispatch] call against a [ToolCallContext] it built
/// from its own state (target message, generateImage closure, URL
/// confirmation closure).
///
/// [callCounts] is owned by the service and persists across all loop
/// iterations of one outer `generateChatReply` invocation, so per-tool
/// caps are enforced per-turn (not per-iteration).
typedef ToolDispatchCallback =
    Future<List<ToolResult>> Function(
      List<ToolCall> calls,
      Map<String, int> callCounts,
    );

class ChatExecutionService {
  ChatExecutionService({
    required this.pureHelpers,
    required this.settingsService,
    required this.chatService,
    required this.promptRepository,
    required this.toolRegistry,
    required this.memoryService,
  });
  final LlmPureHelpers pureHelpers;
  final SettingsService settingsService;
  final ChatService chatService;
  final PromptRepository promptRepository;
  final ToolRegistry toolRegistry;
  final MemoryService memoryService;

  /// Generates a chat reply, running the manual tool loop when the
  /// model emits tool calls. Pass [dispatchToolCalls] when the chat
  /// session has tools enabled — the closure runs the tool dispatcher
  /// against a controller-built [ToolCallContext]. Calls without tools
  /// (or where the model doesn't emit any) terminate after one round
  /// and behave identically to the pre-loop flow.
  Stream<GenerationEvent> generateChatReply(
    ChatSession session,
    CharacterFile characterFile, {
    required ValueNotifier<bool> cancelToken,
    ChatMessage? injectedMessage,
    bool isImpersonating = false,
    String? dataContext,
    ToolDispatchCallback? dispatchToolCalls,
  }) {
    final streamController = StreamController<GenerationEvent>();

    unawaited(
      Future(() async {
        try {
          final resolvedPreset = pureHelpers.resolvePreset(
            configId: session.modelPresetId,
            providers: settingsService.settings.providerConfigs,
          );
          final provider = resolvedPreset.provider;
          final model = resolvedPreset.model;
          final preset = resolvedPreset.preset;

          final runner = pureHelpers.createRunner(
            provider: provider,
            model: model,
            preset: preset,
          );

          final resolver = LlmParameterResolver(
            model: model,
            userValues: preset.parameterValues,
          );
          final contextSize =
              resolver.resolveInt(LlmParameterDefinitionIdEnum.contextSize) ??
              model.contextLength;
          final maxResponseLength = resolver.resolveInt(
            LlmParameterDefinitionIdEnum.maxResponseLength,
          );

          // Resolve the per-domain media flags so tool gating respects
          // the same character → session → app fallthrough as image and
          // video. Reading the session field directly would bypass
          // character-level toggles users set in the editor.
          final resolvedMedia = resolveMedia(
            settings: settingsService.settings,
            pureHelpers: pureHelpers,
            session: session,
            character: characterFile,
          );

          final allowedNames = <String>[
            if (resolvedMedia.imageToolSelfieAllowed) SendSelfieTool.toolName,
            if (resolvedMedia.videoToolSendAllowed) SendVideoTool.toolName,
            if (resolvedMedia.webToolFetchAllowed) FetchWebsiteTool.toolName,
            if (resolvedMedia.nameToolSuggestAllowed)
              SuggestNameTool.toolName,
            // Card-edit tools advertised only in assistant chats — regular
            // chats with a character should not let the character rewrite
            // its own card mid-conversation.
            if (session.isAssistant) ...[
              CardFieldGetTool.toolName,
              CardFieldSetTool.toolName,
              CardFieldListGetTool.toolName,
              CardFieldListSetTool.toolName,
              CardFieldListAppendTool.toolName,
              CardFieldListDeleteTool.toolName,
            ],
          ];
          final enabledTools = model.capabilities.toolCalling
              ? toolRegistry.enabledFor(allowedNames)
              : const <ToolDefinition>[];
          // Schema-gen happens before the per-iteration target message
          // exists; pass a state-only impl carrying just the flags the
          // tools' parametersSchemaFor methods read. The full
          // BuiltinToolAppData is built later inside the dispatch closure.
          final schemaCtx = BuiltinToolSchemaOnly(
            imageToolSelfieCaptionsAllowed:
                session.configMedia?.imageToolSelfieCaptionsAllowed ?? false,
          );
          final genkitTools = enabledTools.isEmpty
              ? null
              : toolRegistry.toGenkitTools(enabledTools, schemaCtx);

          // Surface the three tool-gate inputs so missing-advertisement
          // bugs can be diagnosed from logs alone — the model capability
          // flag, the derived allowed-names list, and the resolved set
          // passed to the runner.
          LoggingService().info(
            'tool gates: '
            'model.toolCalling=${model.capabilities.toolCalling} '
            'allowedNames=$allowedNames '
            'enabledTools=${enabledTools.map((t) => t.name).toList()}',
          );

          // Story memory — retrieved before the prompt is built and injected
          // as its own <memory> section. Skipped for the assistant chat and
          // when memory is off. retrieveContext degrades to empty on any
          // failure, so it never blocks the reply.
          final memoryContext =
              settingsService.settings.memoryEnabled && !session.isAssistant
              ? await memoryService.retrieveContext(session, characterFile)
              : null;

          final builder = ChatPromptBuilder(
            contextSize: contextSize,
            maxResponseLength: maxResponseLength,
            session: session,
            characterFile: characterFile,
            settingsService: settingsService,
            promptRepository: promptRepository,
            injectedMessage: injectedMessage,
            isImpersonating: isImpersonating,
            dataContext: dataContext,
            memoryContext: memoryContext,
            enabledTools: enabledTools,
            toolRegistry: toolRegistry,
          );

          final messages = await builder.build();

          LoggingService().info(
            'generateChatReply: characterFile="${characterFile.card.name}" '
            'chatId=${session.id} dataContextLen=${dataContext?.length ?? 0} '
            'messagesCount=${messages.length}',
          );

          _logOutgoing(
            characterName: characterFile.card.name,
            presetModel: model.id,
            runner: runner,
            messages: messages,
          );

          final startTime = DateTime.now();
          final accumulatedRecords = <ChatToolCallRecord>[];
          final callCounts = <String, int>{};
          var lastText = '';

          // Trims the trailing-paragraph (if the session has it on and
          // we're not impersonating), counts tokens, emits the Complete
          // event with the loop's accumulated tool-call records. Three
          // call sites — final-no-tools, side-effect-only termination,
          // and loop-bound abort — all funnel through here.
          Future<void> emitComplete({
            required String text,
            required bool applyTrim,
            required int generationMs,
          }) async {
            final trimmed =
                applyTrim && session.removeTrailingSentences && !isImpersonating
                ? chatService.trimTrailingParagraph(text)
                : text;
            final tokenCount = await UtilsLlm.countTokens(trimmed);
            streamController.add(
              GenerationCompleteEvent(
                finalContent: trimmed,
                rawPrompt: trimmed,
                generationTime: generationMs,
                tokenCount: tokenCount,
                modelUsed: model.id,
                toolCallRecords: accumulatedRecords,
              ),
            );
          }

          for (
            var iter = 0;
            iter < AppConstants.toolLoopMaxIterations;
            iter++
          ) {
            if (cancelToken.value) break;

            final result = await runner.generate(
              messages: messages,
              stream: session.isStreaming,
              cancelToken: cancelToken,
              onToken: (content) =>
                  streamController.add(GenerationTokenEvent(content)),
              tools: genkitTools,
            );
            lastText = result.text;

            final iterMs = DateTime.now().difference(startTime).inMilliseconds;
            _logIncoming(
              characterName: characterFile.card.name,
              result: result,
              generationMs: iterMs,
              iteration: iter + 1,
            );

            if (result.toolCalls.isEmpty) {
              // Final round — what's been streamed (if anything) is the
              // user-visible reply.
              await emitComplete(
                text: result.text,
                applyTrim: true,
                generationMs: iterMs,
              );
              return;
            }

            // Tool round — wipe whatever was streamed for this iteration
            // (the model's intermediate prose isn't shown to the user)
            // and switch the bubble to a per-tool progress label
            // (e.g. "Sending selfie…", "Browsing…"). Same tool firing
            // multiple times collapses to one label; mixed-tool rounds
            // get a comma-joined list in call order.
            streamController.add(GenerationTokenWipeEvent());
            final progressLabel = _composeProgressLabel(result.toolCalls);
            streamController.add(
              GenerationToolLoopProgressEvent(progressLabel),
            );

            if (dispatchToolCalls == null) {
              // Misconfiguration — tools came back but the controller
              // didn't supply a dispatch closure. Bail with whatever
              // text the model produced; log loudly.
              LoggingService().error(
                'generateChatReply: model emitted tool calls but no '
                'dispatchToolCalls closure was provided; aborting loop.',
              );
              break;
            }

            final toolResults = await dispatchToolCalls(
              result.toolCalls,
              callCounts,
            );
            assert(
              toolResults.length == result.toolCalls.length,
              'dispatchToolCalls must return one result per call',
            );
            for (var i = 0; i < result.toolCalls.length; i++) {
              final call = result.toolCalls[i];
              // One result per call (asserted above).
              // ignore: qcheck/avoid_unsafe_collection_methods
              final r = toolResults[i];
              accumulatedRecords.add(
                ChatToolCallRecord(
                  toolName: call.name,
                  args: call.arguments,
                  success: r.success,
                  resultData: r.data,
                  errorMessage: r.errorMessage,
                ),
              );
            }

            // Only successful tools with empty data are "side-effect-only"
            // (e.g. selfie attached an image; nothing for the model to
            // read back). Failures with no data — denied URL review,
            // network error, non-HTML reject, cap reached — must continue
            // the loop so the model sees the error message and can
            // apologise, adjust, or stop. Treating them as side-effects
            // would leave the user with the model's pre-tool prose and
            // no acknowledgement of what went wrong.
            final allSideEffectOnly = toolResults.every(
              (r) => r.success && (r.data == null || r.data!.isEmpty),
            );
            if (allSideEffectOnly) {
              _logToolLoopIteration(
                iteration: iter + 1,
                calls: result.toolCalls,
                results: toolResults,
                callCounts: callCounts,
                decision: 'terminate (side-effect-only; loop ends)',
              );
              // Side-effect-only round (e.g. selfie) — don't burn
              // another model call; the model's prose plus the
              // attached side-effect are the final reply.
              await emitComplete(
                text: result.text,
                applyTrim: true,
                generationMs: iterMs,
              );
              return;
            }

            // Append the assistant's tool-call turn + the tool results
            // and continue the loop so the model can read the data.
            messages.add(
              LlmRunnerMessage.assistantWithToolCalls(
                text: result.text,
                calls: result.toolCalls,
              ),
            );
            for (var i = 0; i < result.toolCalls.length; i++) {
              final call = result.toolCalls[i];
              // One result per call (asserted where `toolResults` is bound).
              // ignore: qcheck/avoid_unsafe_collection_methods
              final r = toolResults[i];
              messages.add(
                LlmRunnerMessage.toolResult(
                  toolName: call.name,
                  callRef: call.ref,
                  data: r.data ?? r.errorMessage ?? '',
                ),
              );
            }
            _logToolLoopIteration(
              iteration: iter + 1,
              calls: result.toolCalls,
              results: toolResults,
              callCounts: callCounts,
              decision: 'continue (results fed back to model)',
            );
          }

          // Loop bound exceeded (or cancelled) — emit the last text we
          // saw as the final reply with a warning.
          if (!cancelToken.value) {
            LoggingService().warning(
              'generateChatReply: tool loop hit '
              '${AppConstants.toolLoopMaxIterations} iterations; '
              'emitting last partial as final.',
            );
            LoggingService().logLlm(
              '[TOOL-LOOP]',
              '\nLoop bound exceeded after '
                  '${AppConstants.toolLoopMaxIterations} iterations. '
                  'Cumulative call counts: $callCounts. Emitting last '
                  "iteration's text as final.",
            );
          }
          final totalMs = DateTime.now().difference(startTime).inMilliseconds;
          await emitComplete(
            text: lastText,
            applyTrim: false,
            generationMs: totalMs,
          );
        } on Exception catch (e) {
          streamController.addError(e);
        } finally {
          await streamController.close();
        }
      }),
    );

    return streamController.stream;
  }

  Stream<GenerationEvent> generateUtilityResponseWithHistory(
    ChatSession session, {
    required ValueNotifier<bool> cancelToken,
    required String systemPrompt,
    required String postHistoryPrompt,
    int historyTurns = 5,
  }) {
    final streamController = StreamController<GenerationEvent>();

    unawaited(
      Future(() async {
        try {
          final resolved = pureHelpers.resolvePreset(
            configId: session.modelPresetId,
            providers: settingsService.settings.providerConfigs,
          );
          final provider = resolved.provider;
          final model = resolved.model;
          final preset = resolved.preset;

          final runner = pureHelpers.createRunner(
            provider: provider,
            model: model,
            preset: preset,
          );

          final messages = <LlmRunnerMessage>[];

          if (systemPrompt.trim().isNotEmpty) {
            messages.add(LlmRunnerMessage.system(systemPrompt));
          }

          final validHistory = session.messages
              .where((m) => m.content.trim().isNotEmpty)
              .toList();
          final historySubset = validHistory.length > historyTurns
              ? validHistory.sublist(validHistory.length - historyTurns)
              : validHistory;

          messages.addAll(
            historySubset.map((m) {
              switch (m.role) {
                case ChatRoleEnum.user:
                  return LlmRunnerMessage.user(m.content);
                case ChatRoleEnum.assistant:
                case ChatRoleEnum.character:
                  return LlmRunnerMessage.assistant(m.content);
                case ChatRoleEnum.system:
                  return LlmRunnerMessage.system(m.content);
              }
            }),
          );

          messages.add(LlmRunnerMessage.user(postHistoryPrompt));

          _logOutgoing(
            characterName: 'utility',
            presetModel: model.id,
            runner: runner,
            messages: messages,
          );

          final startTime = DateTime.now();

          final result = await runner.generate(
            messages: messages,
            stream: session.isStreaming,
            cancelToken: cancelToken,
            onToken: (content) =>
                streamController.add(GenerationTokenEvent(content)),
          );
          final accumulatedText = result.text;

          final generationTime = DateTime.now()
              .difference(startTime)
              .inMilliseconds;

          _logIncoming(
            characterName: 'utility',
            result: result,
            generationMs: generationTime,
          );

          final tokenCount = await UtilsLlm.countTokens(accumulatedText);

          streamController.add(
            GenerationCompleteEvent(
              finalContent: accumulatedText,
              rawPrompt: accumulatedText,
              generationTime: generationTime,
              tokenCount: tokenCount,
              modelUsed: model.id,
            ),
          );
        } on Exception catch (e) {
          streamController.addError(e);
        } finally {
          await streamController.close();
        }
      }),
    );

    return streamController.stream;
  }

  void _logOutgoing({
    required String characterName,
    required String presetModel,
    required LlmRunner runner,
    required List<LlmRunnerMessage> messages,
  }) {
    final totalChars = messages.fold<int>(0, (s, m) => s + m.content.length);
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('Character:  $characterName');
    buffer.writeln('Preset:     $presetModel');
    buffer.writeln('Model:      ${runner.modelName}');
    buffer.writeln('Config:     ${runner.configType}');
    for (final line in const LineSplitter().convert(runner.configRepr)) {
      buffer.writeln('            $line');
    }
    buffer.writeln('Messages:   ${messages.length} ($totalChars chars total)');
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final label = _labelForMessage(i, messages);
      buffer.writeln();
      buffer.writeln(
        '=== $label [${i + 1}/${messages.length}] · ${m.role.name} · ${m.content.length} chars ===',
      );
      buffer.writeln(m.content);
    }
    LoggingService().logLlm('[CHAT] OUTGOING', buffer.toString());
  }

  void _logIncoming({
    required String characterName,
    required LlmRunnerResult result,
    required int generationMs,
    int? iteration,
  }) {
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('Character:     $characterName');
    if (iteration != null) {
      buffer.writeln('Iteration:     $iteration');
    }
    buffer.writeln('Finish reason: ${result.finishReason}');
    buffer.writeln(
      'Generation:    ${(generationMs / 1000).toStringAsFixed(1)}s',
    );
    buffer.writeln('Visible:       ${result.visibleLen} chars');
    buffer.writeln('Reasoning:     ${result.reasoningLen} chars');
    buffer.writeln('Tool calls:    ${result.toolCalls.length}');
    buffer.writeln();
    buffer.writeln('=== Response · ${result.visibleLen} chars ===');
    buffer.writeln(result.text);
    if (result.reasoning.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== Reasoning · ${result.reasoningLen} chars ===');
      buffer.writeln(result.reasoning);
    }
    LoggingService().logLlm('[CHAT] INCOMING', buffer.toString());
  }

  /// Builds the user-facing progress label for one dispatch round.
  /// Pulls each call's [ToolDefinition.progressLabel] from the registry,
  /// dedupes so a tool firing multiple times shows only once, and
  /// joins them in first-occurrence order with `', '`. Falls back to
  /// `'Working…'` for a tool that's somehow not in the registry — keeps
  /// the bubble informative if a future tool registration regresses.
  String _composeProgressLabel(List<ToolCall> calls) {
    final labels = <String>[];
    for (final c in calls) {
      final tool = toolRegistry.get(c.name);
      final label = tool?.progressLabel ?? 'Working…';
      if (!labels.contains(label)) labels.add(label);
    }
    return labels.isEmpty ? 'Working…' : labels.join(', ');
  }

  /// Logs one tool-loop iteration's frame: which tool calls fired,
  /// each result's outcome, the cap counters, and the loop's decision
  /// (continue / terminate). Separate channel from `[CHAT]` so a grep
  /// shows only round-trip activity.
  static void _logToolLoopIteration({
    required int iteration,
    required List<ToolCall> calls,
    required List<ToolResult> results,
    required Map<String, int> callCounts,
    required String decision,
  }) {
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('Iteration: $iteration');
    buffer.writeln('Calls:     ${calls.length}');
    for (var i = 0; i < calls.length; i++) {
      final c = calls[i];
      final r = i < results.length ? results[i] : null;
      buffer.writeln();
      buffer.writeln('  [$i] ${c.name}  ref=${c.ref ?? '(none)'}');
      if (r == null) {
        buffer.writeln('      result: <missing>');
      } else if (r.success) {
        final dataLen = r.data?.length ?? 0;
        buffer.writeln(
          '      result: ok  data=$dataLen chars'
          '${dataLen == 0 ? ' (side-effect)' : ''}',
        );
      } else {
        buffer.writeln(
          '      result: failure  error=${r.errorMessage ?? '(no message)'}',
        );
      }
    }
    if (callCounts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Call counts (turn-cumulative):');
      for (final entry in callCounts.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    buffer.writeln();
    buffer.writeln('Decision:  $decision');
    LoggingService().logLlm('[TOOL-LOOP]', buffer.toString());
  }

  static String _labelForMessage(int index, List<LlmRunnerMessage> messages) {
    // Only ever called with `index` in `[0, messages.length)`.
    // ignore: qcheck/avoid_unsafe_collection_methods
    final m = messages[index];
    if (m.role == LlmRunnerMessageRoleEnum.system) return 'System prompt';
    final isLastUser =
        m.role == LlmRunnerMessageRoleEnum.user &&
        messages
            .skip(index + 1)
            .every((x) => x.role != LlmRunnerMessageRoleEnum.user);
    if (isLastUser) return 'New user message';
    return 'History message';
  }
}
