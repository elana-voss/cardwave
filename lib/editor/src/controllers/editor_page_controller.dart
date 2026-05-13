import 'dart:convert';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/pages/widgets/panel_enum.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorPageController extends ChangeNotifier {
  EditorPageController({
    required this.characterFile,
    required this.characterService,
    required this.characterAiService,
    required LlmPureHelpers pureHelpers,
    required SettingsService settingsService,
  }) {
    validateConfigMediaCharacter(
      character: characterFile,
      providers: settingsService.settings.providerConfigs,
      pureHelpers: pureHelpers,
    );
  }
  final CharacterFile characterFile;
  final CharacterService characterService;
  final CharacterAiService characterAiService;

  PanelEnum _selectedPanel = PanelEnum.basic;
  bool _isDisposed = false;

  PanelEnum get selectedPanel => _selectedPanel;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void setSelectedPanel(PanelEnum panel) {
    if (_isDisposed) return;
    _selectedPanel = panel;
    notifyListeners();
  }

  Future<void> flushChanges() async {
    if (_isDisposed) return;
    await characterService.flushJsonInCacheAndPngIfDirtyOrPending(
      characterFile,
    );
  }

  /// Thin wrapper so widgets confirm via the controller, not NavigationService directly.
  Future<bool> confirmDelete({
    required String title,
    required String message,
    required Color confirmColor,
    String confirmText = 'Delete',
  }) {
    return NavigationService().showConfirmCancelDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      confirmColor: confirmColor,
    );
  }

  /// Runs a global AI action, opens the diff dialog, and returns the proposed
  /// card if the user confirmed. Returns null on cancel, no-change, or no proposal.
  Future<CharacterCardV3?> proposeAndConfirmGlobalAiAction(
    AiActionEnum action,
  ) async {
    if (_isDisposed) return null;

    final nav = NavigationService();
    CharacterCardV3? proposedCard;

    try {
      proposedCard = await nav.runWithProgressDialog<CharacterCardV3?>(
        title: action.isGlobalOnly ? action.label : 'Global ${action.label}',
        onCancel: characterAiService.cancelAllActiveAiTasks,
        task: (handle) => characterAiService.applyGlobalAiActionToCard(
          action: action,
          file: characterFile,
          handle: handle,
        ),
      );
    } on AiCancelledException {
      LoggingService().info('[GLOBAL AI ACTION] Cancelled');
      return null;
    } on Exception catch (e, st) {
      LoggingService().error('[GLOBAL AI ACTION] Failed', e, st);
      nav.showSnackBar('Global AI action failed. Check logs.');
      return null;
    }

    if (proposedCard == null || _isDisposed) return null;

    final originalText = _buildCompositeString(characterFile.card);
    final suggestedText = _buildCompositeString(proposedCard);
    if (originalText == suggestedText) return null;

    final confirmed = await nav.showAiDiffConfirmationDialog(
      originalText: originalText,
      suggestedText: suggestedText,
    );
    return confirmed == true ? proposedCard : null;
  }

  String _buildCompositeString(CharacterCardV3 card) {
    final buffer = StringBuffer();
    if (card.name.isNotEmpty) buffer.writeln('Name:\n${card.name}\n');
    if (card.description.isNotEmpty) {
      buffer.writeln('Description:\n${card.description}\n');
    }
    if (card.personality.isNotEmpty) {
      buffer.writeln('Personality:\n${card.personality}\n');
    }
    if (card.scenario.isNotEmpty) {
      buffer.writeln('Scenario:\n${card.scenario}\n');
    }
    if (card.firstMes.isNotEmpty) {
      buffer.writeln('First Message:\n${card.firstMes}\n');
    }
    if (card.mesExample.isNotEmpty) {
      buffer.writeln('Message Example:\n${card.mesExample}\n');
    }
    if (card.creatorNotes.isNotEmpty) {
      buffer.writeln('Creator Notes:\n${card.creatorNotes}\n');
    }
    if (card.systemPrompt.isNotEmpty) {
      buffer.writeln('System Prompt:\n${card.systemPrompt}\n');
    }
    if (card.postHistoryInstructions.isNotEmpty) {
      buffer.writeln(
        'Post-History Instructions:\n${card.postHistoryInstructions}\n',
      );
    }

    for (var i = 0; i < card.alternateGreetings.length; i++) {
      if (card.alternateGreetings[i].isNotEmpty) {
        buffer.writeln(
          'Alternate Greeting #${i + 1}:\n${card.alternateGreetings[i]}\n',
        );
      }
    }
    for (var i = 0; i < card.groupOnlyGreetings.length; i++) {
      if (card.groupOnlyGreetings[i].isNotEmpty) {
        buffer.writeln(
          'Group Greeting #${i + 1}:\n${card.groupOnlyGreetings[i]}\n',
        );
      }
    }
    final entries = card.lorebook?.entries ?? [];
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].content?.isNotEmpty == true) {
        buffer.writeln('Lorebook Entry #${i + 1}:\n${entries[i].content ?? ''}\n');
      }
    }

    return buffer.toString().trim();
  }

  String getCharacterDataJson() {
    final json = characterFile.card.toJson();
    json.removeWhere(
      (key, value) =>
          value == null ||
          value == '' ||
          (value is List && value.isEmpty) ||
          (value is Map && value.isEmpty),
    );
    return jsonEncode(json);
  }

  Future<bool> pickAndReplaceImage(
    BuildContext context,
    CharacterFile targetFile,
  ) async {
    final service = context.read<CharacterService>();

    const typeGroup = XTypeGroup(label: 'PNG Images', extensions: ['png']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return false;

    final fileLength = await file.length();
    if (fileLength > AppConstants.maxImageFileSizeBytes) {
      NavigationService().showSnackBar(
        'Selected image is too large. Maximum size is ${AppConstants.maxImageFileSizeLabel}.',
      );
      return false;
    }

    targetFile.appCardTimestampLastSaved =
        DateTime.now().millisecondsSinceEpoch;

    try {
      await service.replaceCharacterImage(targetFile, file);
      return true;
    } on Exception catch (e, stackTrace) {
      LoggingService().error(
        '[Image] Failed to replace character image: ${targetFile.card.name}',
        e,
        stackTrace,
      );
      NavigationService().showSnackBar(
        'Selected image is not a valid PNG or could not be read.',
      );
      return false;
    }
  }
}
