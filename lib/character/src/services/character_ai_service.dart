import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/repositories/taxonomy_repository.dart';
import 'package:cardwave/character/src/services/character_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';

/// Raised by an in-flight AI task when the user has cancelled it (either by
/// pressing the progress-dialog Cancel button, or via
/// [CharacterAiService.cancelAllActiveAiTasks]). Catch this in callers to
/// distinguish a user cancel from a real failure and skip the error
/// snackbar.
class AiCancelledException implements Exception {
  const AiCancelledException();
  @override
  String toString() => 'AiCancelledException: cancelled by user';
}

class _AiTaskState {
  bool isCancelled = false;
}

/// Mutable progress state threaded through a batch AI action across many
/// card fields. The `current` counter is incremented by every field call so
/// the progress dialog can show 7-of-23 etc.
class _AiFieldBatchState {
  _AiFieldBatchState({
    required this.handle,
    required this.total,
    required this.action,
  });
  final ProgressDialogHandle handle;
  final int total;
  final AiActionEnum action;
  int current = 0;
}

class CharacterAiService extends ChangeNotifier {
  CharacterAiService({
    required this.settingsService,
    required this.promptRepository,
    required this.characterService,
    required this.taxonomyRepository,
    required this.loggingService,
    required this.pureHelpers,
  });
  final SettingsService settingsService;
  final PromptRepository promptRepository;
  final CharacterService characterService;
  final TaxonomyRepository taxonomyRepository;
  final LoggingService loggingService;
  final LlmPureHelpers pureHelpers;

  final Map<String, _AiTaskState> _processingAiTaskStatuses = {};
  int _simpleTaskCounter = 0;

  bool isProcessingAiTask(String path) =>
      _processingAiTaskStatuses.containsKey(_normalize(path));

  void cancelAllActiveAiTasks() {
    if (_processingAiTaskStatuses.isEmpty) return;

    for (final taskState in _processingAiTaskStatuses.values) {
      taskState.isCancelled = true;
    }
    _processingAiTaskStatuses.clear();
    // The in-process local model keeps generating after its Dart wait is
    // abandoned; stop the worker so cancel frees the GPU instead of letting
    // the run finish. No-op for cloud models (nothing is registered).
    LlmProvider.cancelActiveLocalGeneration();
    loggingService.info('[CANCEL] User cancelled all active AI tasks');
  }

  String _normalize(String path) {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return isWindows ? path.toLowerCase() : path;
  }

  LlmRunner _getRunner(int? maxResponseTokens) {
    final configId =
        settingsService.settings.domainPresetIds[LlmProviderDomainEnum.system];

    if (configId == null) {
      throw Exception('System model not configured');
    }

    final resolved = pureHelpers.resolvePreset(
      configId: configId,
      providers: settingsService.settings.providerConfigs,
    );

    return pureHelpers.createRunner(
      provider: resolved.provider,
      model: resolved.model,
      preset: resolved.preset,
      paramOverrides: maxResponseTokens != null
          ? {
              LlmParameterDefinitionIdEnum.maxResponseLength: maxResponseTokens
                  .toDouble(),
            }
          : null,
    );
  }

  /// True when the system-domain model is the in-process local GGUF. It
  /// generates minutes-slow, so callers give it one long attempt with no
  /// retries (a retried timeout would only start a second slow run) instead
  /// of the cloud retry budget.
  bool _isSystemModelLocalInProcess() {
    final configId =
        settingsService.settings.domainPresetIds[LlmProviderDomainEnum.system];
    if (configId == null) return false;
    final resolved = pureHelpers.resolvePresetOrNull(
      configId: configId,
      providers: settingsService.settings.providerConfigs,
    );
    return resolved?.provider.providerEnum == LLMProviderEnum.localGguf;
  }

  Future<String> _runSimpleAiTask(String prompt) async {
    final isLocal = _isSystemModelLocalInProcess();
    final maxRetries = isLocal ? 0 : AppConstants.fallbackMaxRetries;
    final timeout = Duration(
      seconds: isLocal
          ? AppConstants.localLlmTimeoutSeconds
          : AppConstants.fallbackLlmTimeoutSeconds,
    );
    _simpleTaskCounter++;
    final taskId =
        'simple_task_${DateTime.now().millisecondsSinceEpoch}_$_simpleTaskCounter';
    final taskState = _AiTaskState();
    _processingAiTaskStatuses[taskId] = taskState;

    try {
      var attempt = 0;
      while (attempt <= maxRetries) {
        final runner = _getRunner(AppConstants.fallbackMaxResponseTokens);

        try {
          if (taskState.isCancelled) throw const AiCancelledException();

          final result = await runner.complete(prompt).timeout(timeout);
          return result.trim();
        } on Exception catch (e, st) {
          if (isLocal) LlmProvider.cancelActiveLocalGeneration();
          if (e is AiCancelledException) rethrow;
          if (taskState.isCancelled) {
            Error.throwWithStackTrace(const AiCancelledException(), st);
          }
          if (attempt >= maxRetries) rethrow;
          attempt++;
          loggingService.warning(
            '[SIMPLE AI TASK] Retry ($attempt/$maxRetries): $e',
          );
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
      throw Exception('Failed after $maxRetries retries');
    } finally {
      _processingAiTaskStatuses.remove(taskId);
    }
  }

  Future<String> proofreadText(String text) {
    final prompt = promptRepository.proseProofread.replaceAll('%INPUT%', text);
    return _runSimpleAiTask(prompt);
  }

  Future<String> compactText(String text) {
    final prompt = promptRepository.proseCompacting.replaceAll('%INPUT%', text);
    return _runSimpleAiTask(prompt);
  }

  Future<String> translateText({
    required String text,
    required String fieldName,
    required CharacterCardV3 contextCard,
  }) {
    final sb = StringBuffer();
    if (contextCard.name.isNotEmpty) {
      sb.writeln(
        '<Name>${UtilsApp.cleanseAndInlineForPrompt(contextCard.name)}</Name>',
      );
    }
    if (contextCard.description.isNotEmpty) {
      sb.writeln(
        '<Description>${UtilsApp.cleanseAndInlineForPrompt(contextCard.description)}</Description>',
      );
    }
    if (contextCard.personality.isNotEmpty) {
      sb.writeln(
        '<Personality>${UtilsApp.cleanseAndInlineForPrompt(contextCard.personality)}</Personality>',
      );
    }
    if (contextCard.scenario.isNotEmpty) {
      sb.writeln(
        '<Scenario>${UtilsApp.cleanseAndInlineForPrompt(contextCard.scenario)}</Scenario>',
      );
    }
    final contextString = sb.toString().trim();

    final prompt = promptRepository.translation
        .replaceAll(
          '%CONTEXT%',
          contextString.isEmpty ? 'None.' : contextString,
        )
        .replaceAll('%FIELD_NAME%', fieldName)
        .replaceAll('%INPUT%', text);

    return _runSimpleAiTask(prompt);
  }

  Future<void> _executeCharacterAiTask(
    CharacterFile file, {
    required String taskName,
    required Future<void> Function(LlmRunner runner) task,
    int? maxResponseTokens,
  }) async {
    final isLocal = _isSystemModelLocalInProcess();
    final maxRetries = isLocal ? 0 : AppConstants.fallbackMaxRetries;
    final timeout = Duration(
      seconds: isLocal
          ? AppConstants.localLlmTimeoutSeconds
          : AppConstants.fallbackLlmTimeoutSeconds,
    );
    final path = _normalize(file.appCardImagePath);
    if (_processingAiTaskStatuses.containsKey(path)) {
      throw Exception('A task is already processing for ${file.card.name}.');
    }

    final taskState = _AiTaskState();
    _processingAiTaskStatuses[path] = taskState;

    notifyListeners();

    loggingService.info('[$taskName] Started: ${file.card.name}');

    try {
      var attempt = 0;
      while (attempt <= maxRetries) {
        final runner = _getRunner(maxResponseTokens);

        try {
          if (taskState.isCancelled) {
            loggingService.info('[$taskName] Cancelled: ${file.card.name}');
            break;
          }

          await task(runner).timeout(timeout);
          loggingService.info('[$taskName] Success: ${file.card.name}');
          break;
        } on Exception catch (e, stackTrace) {
          // A timed-out local attempt leaves the worker generating; stop it so
          // the GPU frees now instead of finishing the abandoned run.
          if (isLocal) LlmProvider.cancelActiveLocalGeneration();
          if (taskState.isCancelled) {
            loggingService.info('[$taskName] Cancelled: ${file.card.name}');
            break;
          }
          if (attempt >= maxRetries) {
            loggingService.error(
              '[$taskName] Failed after $maxRetries retries for ${file.card.name}',
              e,
              stackTrace,
            );
            rethrow;
          }
          attempt++;
          loggingService.warning(
            '[$taskName] Retry ($attempt/$maxRetries) for ${file.card.name}: $e',
          );
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    } finally {
      _processingAiTaskStatuses.remove(path);
      notifyListeners();
      loggingService.info('[$taskName] Finished: ${file.card.name}');
    }
  }

  /// Characters whose preview description is missing — work-list for batch
  /// generation. Queried from the library index, then loaded full.
  Future<List<CharacterFile>> get charactersMissingPreview =>
      characterService.cardsMissingPreview();

  /// Returns the AI-suggested replacement text for a single field action,
  /// or null for actions that mutate the card in place rather than returning
  /// a proposal.
  Future<String?> getLocalAiTextProposal({
    required AiActionEnum action,
    required String currentText,
    required String fieldName,
    required CharacterCardV3 contextCard,
  }) async {
    switch (action) {
      case AiActionEnum.proofread:
        return proofreadText(currentText);
      case AiActionEnum.compact:
        return compactText(currentText);
      case AiActionEnum.translate:
        return translateText(
          text: currentText,
          fieldName: fieldName,
          contextCard: contextCard,
        );
      case AiActionEnum.generatePreview:
      case AiActionEnum.autoTag:
        return null;
    }
  }

  /// Applies a global AI action to the card and returns the proposed result.
  /// Emits progress through [handle]; throws [AiCancelledException] if the
  /// user cancelled mid-batch. Side-effect actions
  /// (`generatePreview`, `autoTag`) return null after mutating [file] in
  /// place.
  Future<CharacterCardV3?> applyGlobalAiActionToCard({
    required AiActionEnum action,
    required CharacterFile file,
    required ProgressDialogHandle handle,
  }) async {
    if (action.isGlobalOnly) {
      // Only the two global-only AI actions reach here; a switch over the full
      // AiActionEnum needs a dead default: arm and gains nothing.
      // ignore: qcheck/prefer_switch_with_enums
      if (action == AiActionEnum.generatePreview) {
        await generateDescriptionPreview(file);
      } else if (action == AiActionEnum.autoTag) {
        await autoTagCharacter(file);
      }
      return null;
    }

    final proposedCard = CharacterCardV3.fromJson(file.card.toJson());
    final total =
        9 +
        proposedCard.alternateGreetings.length +
        proposedCard.groupOnlyGreetings.length +
        (proposedCard.lorebook?.entries.length ?? 0);
    final state = _AiFieldBatchState(
      handle: handle,
      total: total,
      action: action,
    );

    Future<void> run(
      String fieldName,
      String value,
      void Function(String) setter,
    ) => _runAiActionOnField(
      fieldName: fieldName,
      value: value,
      setter: setter,
      contextCard: proposedCard,
      state: state,
    );

    await run('Name', proposedCard.name, (v) => proposedCard.name = v);
    await run(
      'Description',
      proposedCard.description,
      (v) => proposedCard.description = v,
    );
    await run(
      'Personality',
      proposedCard.personality,
      (v) => proposedCard.personality = v,
    );
    await run(
      'Scenario',
      proposedCard.scenario,
      (v) => proposedCard.scenario = v,
    );
    await run(
      'First Message',
      proposedCard.firstMes,
      (v) => proposedCard.firstMes = v,
    );
    await run(
      'Message Example',
      proposedCard.mesExample,
      (v) => proposedCard.mesExample = v,
    );
    await run(
      'Creator Notes',
      proposedCard.creatorNotes,
      (v) => proposedCard.creatorNotes = v,
    );
    await run(
      'System Prompt',
      proposedCard.systemPrompt,
      (v) => proposedCard.systemPrompt = v,
    );
    await run(
      'Post-History Instructions',
      proposedCard.postHistoryInstructions,
      (v) => proposedCard.postHistoryInstructions = v,
    );

    for (var i = 0; i < proposedCard.alternateGreetings.length; i++) {
      await run(
        'Alternate Greeting #${i + 1}',
        proposedCard.alternateGreetings[i],
        (v) => proposedCard.alternateGreetings[i] = v,
      );
    }
    for (var i = 0; i < proposedCard.groupOnlyGreetings.length; i++) {
      await run(
        'Group Greeting #${i + 1}',
        proposedCard.groupOnlyGreetings[i],
        (v) => proposedCard.groupOnlyGreetings[i] = v,
      );
    }
    final entries = proposedCard.lorebook?.entries ?? [];
    for (var i = 0; i < entries.length; i++) {
      await run(
        'Lorebook Entry #${i + 1}',
        entries[i].content ?? '',
        (v) => entries[i].content = v,
      );
    }

    return proposedCard;
  }

  /// Runs the batch action (proofread / compact / translate) for one card
  /// field, mutating `state.current` and updating the progress dialog. Throws
  /// [AiCancelledException] if the user cancelled before this call.
  Future<void> _runAiActionOnField({
    required String fieldName,
    required String value,
    required void Function(String) setter,
    required CharacterCardV3 contextCard,
    required _AiFieldBatchState state,
  }) async {
    if (state.handle.isCancelled) throw const AiCancelledException();

    state.current++;
    if (value.trim().isEmpty) return;

    state.handle.update(
      progressValue: state.current / state.total,
      messageValue: t.character.aiActionController.processingField(
        fieldName: fieldName,
      ),
    );

    var result = value;
    if (state.action == AiActionEnum.proofread) {
      result = await proofreadText(value);
    } else if (state.action == AiActionEnum.compact) {
      result = await compactText(value);
    } else if (state.action == AiActionEnum.translate) {
      result = await translateText(
        text: value,
        fieldName: fieldName,
        contextCard: contextCard,
      );
    }

    if (result != value && !state.handle.isCancelled) {
      setter(result);
    }
  }

  /// Characters with no app-tags — work-list for batch auto-tagging. Queried
  /// from the library index, then loaded full.
  Future<List<CharacterFile>> get charactersMissingTags =>
      characterService.cardsMissingAppTags();

  Future<void> generateDescriptionPreview(CharacterFile file) {
    return _executeCharacterAiTask(
      file,
      taskName: 'PREVIEW',
      maxResponseTokens: 300,
      task: (runner) async {
        final sb = StringBuffer();
        if (file.card.name.isNotEmpty) {
          sb.writeln(
            '<Name>${UtilsApp.cleanseAndInlineForPrompt(file.card.name)}</Name>',
          );
        }
        if (file.card.nickname?.isNotEmpty == true) {
          sb.writeln(
            '<Nickname>${UtilsApp.cleanseAndInlineForPrompt(file.card.nickname!)}</Nickname>',
          );
        }
        if (file.card.description.isNotEmpty) {
          sb.writeln(
            '<Description>${UtilsApp.cleanseAndInlineForPrompt(file.card.description)}</Description>',
          );
        }
        if (file.card.personality.isNotEmpty) {
          sb.writeln(
            '<Personality>${UtilsApp.cleanseAndInlineForPrompt(file.card.personality)}</Personality>',
          );
        }
        if (file.card.scenario.isNotEmpty) {
          sb.writeln(
            '<Scenario>${UtilsApp.cleanseAndInlineForPrompt(file.card.scenario)}</Scenario>',
          );
        }
        if (file.card.tags.isNotEmpty) {
          sb.writeln('<Tags>${file.card.tags.join(',')}</Tags>');
        }

        final prompt = promptRepository.descriptionPreview.replaceAll(
          '%INPUT%',
          sb.toString(),
        );
        final result = await runner.complete(prompt);

        final cwData = file.card.cardwaveData;
        cwData.previewDescription = result.trim();
        file.card.cardwaveData = cwData;

        await characterService.saveJsonInCacheNow(file);
      },
    );
  }

  Future<void> autoTagCharacter(CharacterFile file) {
    return _executeCharacterAiTask(
      file,
      taskName: 'AUTO-TAG',
      maxResponseTokens: AppConstants.autoTagMaxResponseTokens,
      task: (runner) async {
        final sb = StringBuffer();
        if (file.card.name.isNotEmpty) {
          sb.writeln(
            '<Name>${UtilsApp.cleanseAndInlineForPrompt(file.card.name)}</Name>',
          );
        }
        if (file.card.description.isNotEmpty) {
          sb.writeln(
            '<Description>${UtilsApp.cleanseAndInlineForPrompt(file.card.description)}</Description>',
          );
        }
        if (file.card.personality.isNotEmpty) {
          sb.writeln(
            '<Personality>${UtilsApp.cleanseAndInlineForPrompt(file.card.personality)}</Personality>',
          );
        }
        if (file.card.scenario.isNotEmpty) {
          sb.writeln(
            '<Scenario>${UtilsApp.cleanseAndInlineForPrompt(file.card.scenario)}</Scenario>',
          );
        }

        final taxonomyString = taxonomyRepository.getLlmPromptString();
        final prompt = promptRepository.taxonomyTagging
            .replaceAll('%TAGS%', taxonomyString)
            .replaceAll('%INPUT%', sb.toString());

        loggingService.logLlm(
          '[AUTO-TAG] OUTGOING',
          '\nCharacter: ${file.card.name}\nLen: ${prompt.length}\n\n$prompt',
        );

        final schema = taxonomyRepository.buildAutoTagSchema();
        final response = await runner.completeStructured(prompt, schema);

        loggingService.logLlm(
          '[AUTO-TAG] INCOMING',
          '\nCharacter: ${file.card.name}\n\n'
              '${const JsonEncoder.withIndent('  ').convert(response)}',
        );

        final tagIds = _flattenAutoTagResponse(response);
        await updateCharacterTaxonomyTags(file, tagIds);
      },
    );
  }

  /// Flattens the per-group response from [TaxonomyRepository.buildAutoTagSchema]
  /// into a flat tag-id set. The schema's enum constraints already bound
  /// values to known tag ids, so no validity filter runs here.
  Set<String> _flattenAutoTagResponse(Map<String, dynamic> response) {
    final out = <String>{};
    for (final value in response.values) {
      if (value is String) {
        out.add(value);
      } else if (value is List) {
        for (final v in value) {
          if (v is String) out.add(v);
        }
      }
    }
    return out;
  }

  Future<void> updateCharacterTaxonomyTags(
    CharacterFile file,
    Set<String> newTags,
  ) async {
    file.appCardTags = newTags;
    final existingTagsLower = file.card.tags
        .map((t) => t.toLowerCase())
        .toSet();

    for (final tagId in newTags) {
      final tagDef = taxonomyRepository.getTag(tagId);
      if (tagDef != null) {
        final tagName = tagDef.tagName;
        if (!existingTagsLower.contains(tagName.toLowerCase())) {
          file.card.tags.add(tagName);
          existingTagsLower.add(tagName.toLowerCase());
        }
      }
    }
    await characterService.saveJsonInCacheAndPngNow(file);
  }
}
