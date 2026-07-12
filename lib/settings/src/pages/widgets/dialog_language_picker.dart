import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/services/locale_controller.dart';
import 'package:flutter/material.dart';

/// A single selectable language row in [DialogLanguagePicker].
///
/// [native] is the language's name written in its own language and [englishName]
/// is an English disambiguation subtitle shown only for non-Latin scripts. Both
/// are intentionally hardcoded — they are locale-invariant identity labels, NOT
/// translation keys (see the Step 3 extraction exclusions), so they read the
/// same regardless of the active UI language.
class _LanguageEntry {
  const _LanguageEntry({
    required this.tag,
    required this.native,
    this.englishName,
  });

  /// BCP-47 tag passed to [LocaleController.setLocale].
  final String tag;
  final String native;
  final String? englishName;
}

const List<_LanguageEntry> _languages = [
  _LanguageEntry(tag: 'en', native: 'English'),
  _LanguageEntry(tag: 'ru', native: 'Русский', englishName: 'Russian'),
  _LanguageEntry(tag: 'pt-BR', native: 'Português (Brasil)'),
  _LanguageEntry(tag: 'es-419', native: 'Español (Latinoamérica)'),
  _LanguageEntry(tag: 'ja', native: '日本語', englishName: 'Japanese'),
  _LanguageEntry(
    tag: 'zh-Hans',
    native: '简体中文',
    englishName: 'Simplified Chinese',
  ),
  _LanguageEntry(
    tag: 'zh-Hant',
    native: '繁體中文',
    englishName: 'Traditional Chinese',
  ),
  _LanguageEntry(tag: 'ko', native: '한국어', englishName: 'Korean'),
  _LanguageEntry(tag: 'hi', native: 'हिन्दी', englishName: 'Hindi'),
  _LanguageEntry(tag: 'vi', native: 'Tiếng Việt'),
];

/// Flat, scrollable list of every UI language. The first row follows the device
/// locale ("System default"); the rest set an explicit language. Tapping a row
/// applies the choice through [LocaleController] and closes the dialog; the app
/// re-renders in the new language immediately via the top-level
/// `TranslationProvider`. The check mark marks the persisted choice.
class DialogLanguagePicker extends StatelessWidget {
  const DialogLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final controller = LocaleController();
    final currentTag = controller.localeTag;

    void select(String? tag) {
      controller.setLocale(tag);
      Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('language-tile-system'),
          title: Text(t.settings.languageSystemDefault),
          trailing: currentTag == null ? const Icon(Icons.check) : null,
          onTap: () => select(null),
        ),
        for (final lang in _languages)
          ListTile(
            key: Key('language-tile-${lang.tag}'),
            title: Text(lang.native),
            subtitle: lang.englishName == null
                ? null
                : Text(lang.englishName!),
            trailing: currentTag == lang.tag ? const Icon(Icons.check) : null,
            onTap: () => select(lang.tag),
          ),
      ],
    );
  }
}
