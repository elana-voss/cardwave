import 'package:cardwave/character/src/pages/widgets/prompt_prefix_domain.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Modal text-field for editing a character's per-domain prompt-prefix
/// (image style, video style). Shared by the chat-drawer "Style" tile
/// and the editor-drawer media-settings grid.
///
/// Returns:
/// - `null` when the user cancels — caller leaves the field untouched.
/// - `''` when the user saves an empty string — caller should null the
///   field so the compactor doesn't emit an empty prefix.
/// - non-empty string when the user saves a value — caller writes it.
///
/// Persistence is the caller's responsibility: in the editor, that's
/// the debounced save callback; in the drawer, that's a direct flush
/// against the character file.
Future<String?> showCharacterPromptPrefixDialog(
  BuildContext context, {
  required PromptPrefixDomain domain,
  required String? currentValue,
}) async {
  final copy = _copyFor(domain);
  final controller = TextEditingController(text: currentValue ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AppDialog(
      builder: (ctx, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(copy.description, style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextFieldAutotrim(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: t.character.promptPrefixDialog.styleKeywordsLabel,
              hintText: copy.hint,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(t.common.actions.save),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

({String title, String description, String hint}) _copyFor(
  PromptPrefixDomain domain,
) {
  switch (domain) {
    case PromptPrefixDomain.image:
      return (
        title: t.character.promptPrefixDialog.imageTitle,
        description: t.character.promptPrefixDialog.imageDescription,
        hint: t.character.promptPrefixDialog.imageHint,
      );
    case PromptPrefixDomain.video:
      return (
        title: t.character.promptPrefixDialog.videoTitle,
        description: t.character.promptPrefixDialog.videoDescription,
        hint: t.character.promptPrefixDialog.videoHint,
      );
  }
}
