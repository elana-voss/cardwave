import 'dart:async';
import 'dart:io' show File;

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/src/utils/app_constants.dart';
import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/models/prompt_breakdown.dart';
import 'package:cardwave/common/src/widgets/dialog_json_prompt.dart';
import 'package:cardwave/common/src/widgets/dialog_message_edit.dart';
import 'package:cardwave/common/src/widgets/dialog_prompt_breakdown.dart';
import 'package:cardwave/common/src/widgets/dialog_progress.dart';
import 'package:cardwave/common/src/widgets/dialog_text_input.dart';
import 'package:cardwave/editor/editor.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:cardwave/common/src/widgets/dialog_progress.dart'
    show ProgressDialogHandle;

class NavigationService {
  factory NavigationService() => _instance;
  NavigationService._internal();
  static final NavigationService _instance = NavigationService._internal();

  // Wired to MaterialApp at lib/main.dart:611 (cross-file); the lint
  // only sees usage as a `key:` arg inside this class.
  // ignore: qcheck/always_pass_global_key
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Internal helper to show a dialog using the global navigator key.
  Future<T?> _showAppDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Displays a simple alert dialog with a [title], a [message], and an OK button.
  Future<void> showAlertConfirmDialog({
    required String title,
    required String message,
  }) async {
    await _showAppDialog(
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Confirm/cancel alert dialog. Returns true if confirmed, false if cancelled or dismissed.
  Future<bool> showConfirmCancelDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await _showAppDialog<bool>(
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: const Key('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Displays a dialog with a text input field, returning the entered string or null if cancelled.
  Future<String?> showTextInputDialog({
    required String title,
    required String initialText,
    required String hintText,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    int maxLines = 3,
  }) {
    return _showAppDialog<String>(
      builder: (context) => DialogTextInput(
        title: title,
        initialText: initialText,
        hintText: hintText,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLines: maxLines,
      ),
    );
  }

  /// Displays the dialog for creating a new character.
  Future<String?> showCreateCharacterDialog() {
    return _showAppDialog<String>(
      builder: (context) => const DialogCreateCharacter(),
    );
  }

  /// Shows the assistant-chat card-edit approval dialog. Returns one
  /// [ApprovalDecision] per input proposal in the same order. Dismissed
  /// (without explicit Confirm) → null; the gate controller treats that
  /// as deny-all.
  Future<List<ApprovalDecision>?> showCardEditApprovalDialog(
    List<CardEditProposal> proposals,
  ) {
    return _showAppDialog<List<ApprovalDecision>>(
      builder: (context) => DialogCardEditApproval(proposals: proposals),
      barrierDismissible: false,
    );
  }

  /// Opens the message edit dialog. Returns the new content if the user saved
  /// a non-empty change, null on cancel or if the text was unchanged.
  Future<String?> showMessageEditDialog({
    required String initialContent,
  }) async {
    final newContent = await _showAppDialog<String>(
      builder: (context) => DialogMessageEdit(initialContent: initialContent),
    );
    return (newContent != null && newContent != initialContent)
        ? newContent
        : null;
  }

  /// Opens a read-only viewer showing the JSON-formatted [rawPrompt]. Falls
  /// back to displaying the raw text when the input isn't valid JSON.
  Future<void> showJsonPromptDialog({String? rawPrompt}) async {
    await _showAppDialog<void>(
      builder: (context) => DialogJsonPrompt(rawContent: rawPrompt ?? ''),
    );
  }

  /// Opens the read-only prompt-breakdown detail for a reply: each prompt part
  /// with its token count, the reply reservation, free space, and totals.
  Future<void> showPromptBreakdownDialog({
    required PromptContextBreakdown breakdown,
  }) async {
    await _showAppDialog<void>(
      builder: (_) => DialogPromptBreakdown(breakdown: breakdown),
    );
  }

  /// Opens the group-overrides editor (shared scenario / system prompt /
  /// example dialogue for the supplied [controller]'s active group).
  Future<void> showGroupOverridesDialog({
    required GroupChatController controller,
  }) async {
    await _showAppDialog<void>(
      builder: (_) => ChangeNotifierProvider<GroupChatController>.value(
        value: controller,
        child: const DialogGroupOverrides(),
      ),
    );
  }

  /// Opens the taxonomy editor dialog (debug-only utility).
  Future<void> showTaxonomyEditorDialog() async {
    await _showAppDialog(builder: (context) => const DialogTaxonomyEditor());
  }

  /// Opens the persona editor. Pass [persona] to edit; omit for a new
  /// persona. Returns the saved [ChatPersona] on confirm, null on cancel.
  Future<ChatPersona?> showPersonaEditDialog({ChatPersona? persona}) {
    return _showAppDialog<ChatPersona>(
      builder: (_) => DialogPersona(persona: persona),
    );
  }

  /// Opens the personas management surface inside an [AppDialog].
  /// `forceMobile: true` because the persona row Cards want full width even
  /// on desktop. `isScrollable: false` is required because
  /// [SettingsTabPersonas] uses `Expanded(ListView)` internally; wrapping it
  /// in `SingleChildScrollView` would unbound the height and crash the
  /// layout.
  Future<void> showPersonasDialog() async {
    await _showAppDialog<void>(
      builder: (_) => AppDialog(
        builder: (ctx, isMobile) => const SettingsTabPersonas(),
        forceMobile: true,
        isScrollable: false,
      ),
    );
  }

  /// Opens the language picker inside an [AppDialog] — a flat list of every
  /// UI language plus a "System default" row. Modeled on [showPersonasDialog].
  Future<void> showLanguageDialog() async {
    await _showAppDialog<void>(
      builder: (_) => AppDialog(
        builder: (ctx, isMobile) => const DialogLanguagePicker(),
      ),
    );
  }

  /// Opens the image-style presets toggle dialog for a character. The dialog
  /// reads/writes `characterFile.configMedia.imagePromptPrefix` and persists
  /// changes via [characterService] as toggles flip. Returns when the user
  /// closes it.
  Future<void> showStylePresetsDialog({
    required CharacterFile characterFile,
    required CharacterService characterService,
  }) async {
    await _showAppDialog<void>(
      builder: (_) => StylePresetsDialog(
        characterFile: characterFile,
        characterService: characterService,
      ),
    );
  }

  /// Plays a freshly-downloaded test MP4 (the `Test video generation` button
  /// flow inside `TileProviderProfile`) inside an [AppDialog] using
  /// media_kit's player. Returns when the user closes the dialog. The temp
  /// [file] is the caller's to delete after the future resolves.
  Future<void> showVideoTestPreviewDialog({required File file}) async {
    await _showAppDialog<void>(
      builder: (_) => TestVideoPreviewDialog(file: file),
    );
  }

  /// Opens the NODES debug snapshot dialog for the currently open chat.
  /// Read-only, snapshot at the moment of opening — close and reopen
  /// to refresh. Dev/tuning tool per spec §10.
  Future<void> showNodesDebugDialog({required NodesService nodesService}) =>
      _showAppDialog<void>(
        builder: (_) => NodesDebugDialog(nodesService: nodesService),
      );

/// Opens the App Settings surface inside an [AppDialog]. Returns when the
  /// user closes the dialog.
  Future<void> showSettingsGeneralDialog() async {
    await _showAppDialog<void>(
      builder: (dialogCtx) => AppDialog(
        builder: (ctx, isMobile) => const SettingsTabGeneral(),
      ),
    );
  }

  /// Opens the provider config dialog in EDIT mode for an existing profile.
  /// Picks the local-vs-cloud dialog variant from `profile.providerEnum` so
  /// callers don't repeat the conditional. Returns the updated profile on
  /// save, null on cancel.
  Future<LlmProviderConfig?> showProviderEditDialog({
    required LlmProviderConfig profile,
  }) {
    final isLocal = profile.providerEnum == LLMProviderEnum.localOpenAi;
    return _showAppDialog<LlmProviderConfig>(
      builder: (_) => isLocal
          ? DialogLocalProviderConfig(profile: profile)
          : DialogProviderConfig(profile: profile),
    );
  }

  /// Opens the provider config dialog in ADD mode. Returns the new profile
  /// plus its fetched model list on save, null on cancel. The caller picks
  /// `isLocal` based on which "add" entry point fired (separate buttons
  /// drive cloud vs local).
  Future<DialogProviderAddResult?> showProviderAddDialog({
    required bool isLocal,
  }) {
    return _showAppDialog<DialogProviderAddResult>(
      builder: (_) => isLocal
          ? const DialogLocalProviderConfig()
          : const DialogProviderConfig(),
    );
  }

  /// Opens the in-process GGUF add dialog. Returns the constructed
  /// [LlmProviderConfig] on Save, `null` on dismiss.
  Future<LlmProviderConfig?> showLocalGgufProviderAddDialog() {
    return _showAppDialog<LlmProviderConfig>(
      builder: (_) => const DialogLocalGgufProviderConfig(),
    );
  }

  /// Opens a multi-select picker (used by the grid's tag and creator
  /// filters). [items] is a `key → count` map; the selected keys come back as
  /// a `Set<String>?`, null on cancel. [dynamicItemsCallback] lets the dialog
  /// recompute counts as the selection narrows (used by tag filtering).
  Future<Set<String>?> showMultiSelectDialog({
    required String title,
    required Map<String, int> items,
    required Set<String> selectedItems,
    Future<Map<String, int>> Function(Set<String>)? dynamicItemsCallback,
  }) {
    return _showAppDialog<Set<String>>(
      builder: (_) => DialogMultiSelect(
        title: title,
        items: items,
        selectedItems: selectedItems,
        dynamicItemsCallback: dynamicItemsCallback,
      ),
    );
  }

  /// Opens the folder-tree picker (used by the grid's directory filter).
  /// Returns the picked folder path or null on cancel.
  Future<String?> showPickFolderDialog({
    required String title,
    required Map<String, int> items,
    required String selectedItem,
    required String allFoldersKey,
  }) {
    return _showAppDialog<String>(
      builder: (_) => DialogPickFolder(
        title: title,
        items: items,
        selectedItem: selectedItem,
        allFoldersKey: allFoldersKey,
      ),
    );
  }

  /// Opens the preset config dialog (add or edit). Returns the saved
  /// `(model, preset)` record on save, null on cancel.
  Future<DialogPresetResult?> showPresetConfigDialog({
    required LlmProviderConfig connectionProfile,
    LlmPresetConfig? configuration,
    LlmModel? initialModel,
    Set<LlmProviderDomainEnum> activeDomains = const {},
  }) {
    return _showAppDialog<DialogPresetResult>(
      builder: (context) => DialogPresetConfig(
        connectionProfile: connectionProfile,
        configuration: configuration,
        initialModel: initialModel,
        activeDomains: activeDomains,
      ),
    );
  }

  /// Opens the content cleaner dialog. The user picks one or more cleaning
  /// rules; each invokes [onApply] with a `String -> String` processor that
  /// the caller applies to every card field.
  Future<void> showContentCleanerDialog({
    required void Function(String Function(String)) onApply,
  }) async {
    await _showAppDialog(
      builder: (context) => DialogContentCleaner(onApply: onApply),
    );
  }

  /// Opens the find/replace dialog. On confirm the dialog calls [onApply]
  /// with a `String -> String` processor that performs the replacement.
  Future<void> showFindReplaceDialog({
    required void Function(String Function(String)) onApply,
  }) async {
    await _showAppDialog(
      builder: (context) => DialogFindReplace(onApply: onApply),
    );
  }

  /// Displays a confirmation dialog showing the difference between [originalText] and [suggestedText].
  Future<bool?> showAiDiffConfirmationDialog({
    required String originalText,
    required String suggestedText,
  }) {
    return _showAppDialog<bool>(
      barrierDismissible: false,
      builder: (context) => DialogAiDiffConfirmation(
        originalText: originalText,
        suggestedText: suggestedText,
      ),
    );
  }

  /// Displays a progress dialog with a given [title]. Returns a [ProgressDialogHandle] to update or close it.
  ProgressDialogHandle showProgressDialog({
    required String title,
    VoidCallback? onCancel,
  }) {
    final context = navigatorKey.currentContext;

    Route<dynamic>? dialogRoute;

    final handle = ProgressDialogHandle(() {
      if (dialogRoute != null && dialogRoute.isActive) {
        final navigator = dialogRoute.navigator;
        if (navigator != null) {
          if (dialogRoute.isCurrent) {
            navigator.pop();
          } else {
            navigator.removeRoute(dialogRoute);
          }
        }
      }
    });

    if (context != null) {
      dialogRoute = DialogRoute(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            DialogProgress(title: title, handle: handle, onCancel: onCancel),
      );
      unawaited(Navigator.of(context, rootNavigator: true).push(dialogRoute));
    }

    return handle;
  }

  /// Wraps a [task] with a progress dialog showing the given [title].
  /// Handles showing, updating on success, and closing the dialog automatically.
  Future<T?> runWithProgressDialog<T>({
    required String title,
    required Future<T> Function(ProgressDialogHandle handle) task,
    String successMessage = 'Finished!',
    VoidCallback? onCancel,
  }) async {
    final handle = showProgressDialog(title: title, onCancel: onCancel);

    try {
      final result = await task(handle);
      if (!handle.isCancelled) {
        handle.update(progressValue: 1, messageValue: successMessage);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return result;
    } finally {
      handle.close();
    }
  }

  /// Displays a dialog asking the user to try an action again, showing a [title] and [content].
  Future<bool> showTryAgainDialog({
    required String title,
    required String content,
  }) async {
    final result = await _showAppDialog<bool>(
      builder: (context) => AppDialog(
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(content),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Displays a snackbar with the given [message] at the bottom of the screen.
  void showSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Displays a dialog listing the given import [errors].
  Future<void> showImportErrorsDialog(List<String> errors) async {
    await _showAppDialog(
      builder: (context) => AlertDialog(
        title: const Text('Import Errors'),
        content: SingleChildScrollView(
          // Spread children carry their own `Padding(bottom: 4)`; a single
          // `spacing:` would compound with that and change effective gaps.
          // ignore: qcheck/prefer_spacing
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following files could not be imported:'),
              const SizedBox(height: 8),
              ...errors.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $e',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Update-available dialog with optional release notes. Returns true if the user clicked "View Releases".
  Future<bool> showUpdateAvailableDialog({
    required String currentVersion,
    required String latestVersion,
    String? releaseNotes,
  }) async {
    final result = await _showAppDialog<bool>(
      builder: (context) => AlertDialog(
        title: const Text('Version Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A newer version of ${AppConstants.appPackageName} is available.\n\nCurrent version: $currentVersion\nLatest version: $latestVersion',
            ),
            if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Release Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(releaseNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('View Releases'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Displays a dialog warning the user about filename conflicts for the given [conflictingNames].
  Future<bool> showImportConflictsDialog(List<String> conflictingNames) async {
    final result = await _showAppDialog<bool>(
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Import Conflicts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conflictingNames.isNotEmpty) ...[
                Text(
                  'The following ${conflictingNames.length} characters have filename conflicts and will be renamed automatically:',
                ),
                const SizedBox(height: 8),
                Text(
                  '${conflictingNames.take(5).join(', ')}${conflictingNames.length > 5 ? ', ...' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
