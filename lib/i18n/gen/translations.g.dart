/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 9
/// Strings: 79 (8 per locale)

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.en;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, Translations> {
	en(languageCode: 'en', build: Translations.build),
	es419(languageCode: 'es', countryCode: '419', build: _TranslationsEs419.build),
	hi(languageCode: 'hi', build: _TranslationsHi.build),
	ja(languageCode: 'ja', build: _TranslationsJa.build),
	ko(languageCode: 'ko', build: _TranslationsKo.build),
	ptBr(languageCode: 'pt', countryCode: 'BR', build: _TranslationsPtBr.build),
	ru(languageCode: 'ru', build: _TranslationsRu.build),
	zhHans(languageCode: 'zh', scriptCode: 'Hans', build: _TranslationsZhHans.build),
	zhHant(languageCode: 'zh', scriptCode: 'Hant', build: _TranslationsZhHant.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, Translations> build;

	/// Gets current instance managed by [LocaleSettings].
	Translations get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
Translations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, Translations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, Translations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	Translations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, Translations> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, Translations> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class Translations implements BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	// Translations
	late final _TranslationsAppEn app = _TranslationsAppEn._(_root);
	late final _TranslationsCharacterEn character = _TranslationsCharacterEn._(_root);
	late final _TranslationsChatEn chat = _TranslationsChatEn._(_root);
	late final _TranslationsCommonEn common = _TranslationsCommonEn._(_root);
	late final _TranslationsEditorEn editor = _TranslationsEditorEn._(_root);
	late final _TranslationsGridEn grid = _TranslationsGridEn._(_root);
	late final _TranslationsGroupEn group = _TranslationsGroupEn._(_root);
	late final _TranslationsLlmAppEn llmApp = _TranslationsLlmAppEn._(_root);
	late final _TranslationsMemoryEn memory = _TranslationsMemoryEn._(_root);
	late final _TranslationsNodesEn nodes = _TranslationsNodesEn._(_root);
	late final _TranslationsOnboardingEn onboarding = _TranslationsOnboardingEn._(_root);
	late final _TranslationsRoutingEn routing = _TranslationsRoutingEn._(_root);
	late final _TranslationsSearchEn search = _TranslationsSearchEn._(_root);
	late final _TranslationsSettingsEn settings = _TranslationsSettingsEn._(_root);
	late final _TranslationsWorkspaceEn workspace = _TranslationsWorkspaceEn._(_root);
}

// Path: app
class _TranslationsAppEn {
	_TranslationsAppEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterEn {
	_TranslationsCharacterEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatEn {
	_TranslationsChatEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonEn {
	_TranslationsCommonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsCommonActionsEn actions = _TranslationsCommonActionsEn._(_root);
}

// Path: editor
class _TranslationsEditorEn {
	_TranslationsEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridEn {
	_TranslationsGridEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsGridEmptyStateEn emptyState = _TranslationsGridEmptyStateEn._(_root);
	late final _TranslationsGridAppBarEn appBar = _TranslationsGridAppBarEn._(_root);
	late final _TranslationsGridFabEn fab = _TranslationsGridFabEn._(_root);
	late final _TranslationsGridDrawerEn drawer = _TranslationsGridDrawerEn._(_root);
	late final _TranslationsGridVariantBadgeEn variantBadge = _TranslationsGridVariantBadgeEn._(_root);
	late final _TranslationsGridDialogActionsEn dialogActions = _TranslationsGridDialogActionsEn._(_root);
	late final _TranslationsGridTagFilterDialogEn tagFilterDialog = _TranslationsGridTagFilterDialogEn._(_root);
	late final _TranslationsGridFiltersEn filters = _TranslationsGridFiltersEn._(_root);
	late final _TranslationsGridSortOptionEn sortOption = _TranslationsGridSortOptionEn._(_root);
	late final _TranslationsGridFilterControllerEn filterController = _TranslationsGridFilterControllerEn._(_root);
	late final _TranslationsGridMultiSelectDialogEn multiSelectDialog = _TranslationsGridMultiSelectDialogEn._(_root);
	late final _TranslationsGridCreateCharacterDialogEn createCharacterDialog = _TranslationsGridCreateCharacterDialogEn._(_root);
	late final _TranslationsGridVariantsSheetEn variantsSheet = _TranslationsGridVariantsSheetEn._(_root);
	late final _TranslationsGridGroupAppBarEn groupAppBar = _TranslationsGridGroupAppBarEn._(_root);
	late final _TranslationsGridThumbnailBadgesEn thumbnailBadges = _TranslationsGridThumbnailBadgesEn._(_root);
	late final _TranslationsGridActionMenuEn actionMenu = _TranslationsGridActionMenuEn._(_root);
	late final _TranslationsGridControllerMessagesEn controllerMessages = _TranslationsGridControllerMessagesEn._(_root);
}

// Path: group
class _TranslationsGroupEn {
	_TranslationsGroupEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppEn {
	_TranslationsLlmAppEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryEn {
	_TranslationsMemoryEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesEn {
	_TranslationsNodesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingEn {
	_TranslationsOnboardingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingEn {
	_TranslationsRoutingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchEn {
	_TranslationsSearchEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsEn {
	_TranslationsSettingsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get gearLanguage => 'Language';
	String get languageSystemDefault => 'System default';
}

// Path: workspace
class _TranslationsWorkspaceEn {
	_TranslationsWorkspaceEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: common.actions
class _TranslationsCommonActionsEn {
	_TranslationsCommonActionsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get delete => 'Delete';
}

// Path: grid.emptyState
class _TranslationsGridEmptyStateEn {
	_TranslationsGridEmptyStateEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noMatches => 'No characters match your filters';
	String get noCharacters => 'No characters imported yet';
	String get clearAllFilters => 'Clear all filters';
	String get importCharacters => 'Import Characters';
	String get createNewCharacter => 'Create New Character';
}

// Path: grid.appBar
class _TranslationsGridAppBarEn {
	_TranslationsGridAppBarEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get groups => 'Groups';
	String get createNew => 'Create New';
	String get import => 'Import';
	String get menuTooltip => 'Menu';
}

// Path: grid.fab
class _TranslationsGridFabEn {
	_TranslationsGridFabEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get addOrImportTooltip => 'Add or Import';
	String get import => 'Import';
	String get create => 'Create';
}

// Path: grid.drawer
class _TranslationsGridDrawerEn {
	_TranslationsGridDrawerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get mediaDefaultsApp => 'App';
	String get batchAiHeader => 'Batch AI';
	String get batchGeneratePreviewsTitle => 'Batch Generate Previews';
	String get batchGeneratePreviewsEmpty => 'All characters already have previews.';
	String get batchAutoTagTitle => 'Batch Auto-Tag';
	String get batchAutoTagEmpty => 'All characters already have tags.';
	String get libraryHeader => 'Library';
	String get reloadCharacters => 'Reload characters';
}

// Path: grid.variantBadge
class _TranslationsGridVariantBadgeEn {
	_TranslationsGridVariantBadgeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String tooltip({required Object count}) => '${count} Variants';
}

// Path: grid.dialogActions
class _TranslationsGridDialogActionsEn {
	_TranslationsGridDialogActionsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get clearAll => 'Clear All';
	String get apply => 'Apply';
}

// Path: grid.tagFilterDialog
class _TranslationsGridTagFilterDialogEn {
	_TranslationsGridTagFilterDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Filter Tags';
	String get searchHint => 'Search tags...';
}

// Path: grid.filters
class _TranslationsGridFiltersEn {
	_TranslationsGridFiltersEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get hideFiltersTooltip => 'Hide filters';
	String get moreFiltersTooltip => 'More filters';
	String get folderChip => 'Folder';
	String get creatorChip => 'Creator';
	String get tagChip => 'Tag';
	String get recentTooltip => 'Recent';
	String get favoritesTooltip => 'Favorites';
	String get variantsTooltip => 'Variants';
	String indexingProgress({required Object done, required Object total}) => 'Building search ${done} / ${total}…';
}

// Path: grid.sortOption
class _TranslationsGridSortOptionEn {
	_TranslationsGridSortOptionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get relevance => 'Relevance ↓';
	String get nameAsc => 'Name ↓';
	String get nameDesc => 'Name ↑';
	String get importNewest => 'Imported ↓';
	String get importOldest => 'Imported ↑';
	String get modifiedNewest => 'Modified ↓';
	String get modifiedOldest => 'Modified ↑';
	String get interactedNewest => 'Interacted ↓';
	String get interactedOldest => 'Interacted ↑';
	String get tokensHigh => 'Tokens ↓';
	String get tokensLow => 'Tokens ↑';
}

// Path: grid.filterController
class _TranslationsGridFilterControllerEn {
	_TranslationsGridFilterControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get filterCreators => 'Filter Creators';
	String get filterTags => 'Filter Tags';
	String get filterByFolder => 'Filter by Folder';
}

// Path: grid.multiSelectDialog
class _TranslationsGridMultiSelectDialogEn {
	_TranslationsGridMultiSelectDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get nothingToShow => 'Nothing to show yet.';
	String get noMatches => 'No matches.';
	String get showMore => 'Show More';
}

// Path: grid.createCharacterDialog
class _TranslationsGridCreateCharacterDialogEn {
	_TranslationsGridCreateCharacterDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get nameEmptyError => 'Character name cannot be empty.';
	String get nameInvalidCharsError => 'Name contains invalid characters (<>:"/\|?*).';
	String get nameExistsError => 'A character with this name already exists.';
	String get nameCheckFailedError => 'Could not verify the name. Check folder permissions and try again.';
	String get title => 'Create New Character';
	String get nameLabel => 'Character Name';
	String get createButton => 'Create';
}

// Path: grid.variantsSheet
class _TranslationsGridVariantsSheetEn {
	_TranslationsGridVariantsSheetEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Variants';
}

// Path: grid.groupAppBar
class _TranslationsGridGroupAppBarEn {
	_TranslationsGridGroupAppBarEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get characters => 'Characters';
	String get newGroup => 'New group';
}

// Path: grid.thumbnailBadges
class _TranslationsGridThumbnailBadgesEn {
	_TranslationsGridThumbnailBadgesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get recent => 'RECENT';
	String get original => 'ORIGINAL';
	String get variant => 'VARIANT';
}

// Path: grid.actionMenu
class _TranslationsGridActionMenuEn {
	_TranslationsGridActionMenuEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get editNotes => 'Edit Notes';
	String get dismissRecent => 'Dismiss Recent';
	String get exportPngV2V3 => 'Export as PNG (V2/V3)';
	String get exportJsonV3 => 'Export as JSON (V3)';
	String get exportJsonV2 => 'Export as JSON (V2)';
	String get duplicate => 'Duplicate';
}

// Path: grid.controllerMessages
class _TranslationsGridControllerMessagesEn {
	_TranslationsGridControllerMessagesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get duplicateFailed => 'Could not duplicate the character.';
	String get editVariantNotesTitle => 'Edit Variant Notes';
	String get editVariantNotesHint => 'Add notes about this variant...';
	String get deleteCardTitle => 'Delete Card';
	String get deleteCardMessage => 'Are you sure you want to delete this card?';
	String get deletePartialFailure => 'Some files could not be deleted. Check logs for details.';
}

// Path: <root>
class _TranslationsEs419 extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsEs419.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.es419,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es-419>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsEs419 _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppEs419 app = _TranslationsAppEs419._(_root);
	@override late final _TranslationsCharacterEs419 character = _TranslationsCharacterEs419._(_root);
	@override late final _TranslationsChatEs419 chat = _TranslationsChatEs419._(_root);
	@override late final _TranslationsCommonEs419 common = _TranslationsCommonEs419._(_root);
	@override late final _TranslationsEditorEs419 editor = _TranslationsEditorEs419._(_root);
	@override late final _TranslationsGridEs419 grid = _TranslationsGridEs419._(_root);
	@override late final _TranslationsGroupEs419 group = _TranslationsGroupEs419._(_root);
	@override late final _TranslationsLlmAppEs419 llmApp = _TranslationsLlmAppEs419._(_root);
	@override late final _TranslationsMemoryEs419 memory = _TranslationsMemoryEs419._(_root);
	@override late final _TranslationsNodesEs419 nodes = _TranslationsNodesEs419._(_root);
	@override late final _TranslationsOnboardingEs419 onboarding = _TranslationsOnboardingEs419._(_root);
	@override late final _TranslationsRoutingEs419 routing = _TranslationsRoutingEs419._(_root);
	@override late final _TranslationsSearchEs419 search = _TranslationsSearchEs419._(_root);
	@override late final _TranslationsSettingsEs419 settings = _TranslationsSettingsEs419._(_root);
	@override late final _TranslationsWorkspaceEs419 workspace = _TranslationsWorkspaceEs419._(_root);
}

// Path: app
class _TranslationsAppEs419 extends _TranslationsAppEn {
	_TranslationsAppEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterEs419 extends _TranslationsCharacterEn {
	_TranslationsCharacterEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatEs419 extends _TranslationsChatEn {
	_TranslationsChatEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonEs419 extends _TranslationsCommonEn {
	_TranslationsCommonEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorEs419 extends _TranslationsEditorEn {
	_TranslationsEditorEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridEs419 extends _TranslationsGridEn {
	_TranslationsGridEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupEs419 extends _TranslationsGroupEn {
	_TranslationsGroupEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppEs419 extends _TranslationsLlmAppEn {
	_TranslationsLlmAppEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryEs419 extends _TranslationsMemoryEn {
	_TranslationsMemoryEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesEs419 extends _TranslationsNodesEn {
	_TranslationsNodesEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingEs419 extends _TranslationsOnboardingEn {
	_TranslationsOnboardingEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingEs419 extends _TranslationsRoutingEn {
	_TranslationsRoutingEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchEs419 extends _TranslationsSearchEn {
	_TranslationsSearchEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsEs419 extends _TranslationsSettingsEn {
	_TranslationsSettingsEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceEs419 extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

	@override final _TranslationsEs419 _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsHi extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsHi.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.hi,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <hi>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsHi _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppHi app = _TranslationsAppHi._(_root);
	@override late final _TranslationsCharacterHi character = _TranslationsCharacterHi._(_root);
	@override late final _TranslationsChatHi chat = _TranslationsChatHi._(_root);
	@override late final _TranslationsCommonHi common = _TranslationsCommonHi._(_root);
	@override late final _TranslationsEditorHi editor = _TranslationsEditorHi._(_root);
	@override late final _TranslationsGridHi grid = _TranslationsGridHi._(_root);
	@override late final _TranslationsGroupHi group = _TranslationsGroupHi._(_root);
	@override late final _TranslationsLlmAppHi llmApp = _TranslationsLlmAppHi._(_root);
	@override late final _TranslationsMemoryHi memory = _TranslationsMemoryHi._(_root);
	@override late final _TranslationsNodesHi nodes = _TranslationsNodesHi._(_root);
	@override late final _TranslationsOnboardingHi onboarding = _TranslationsOnboardingHi._(_root);
	@override late final _TranslationsRoutingHi routing = _TranslationsRoutingHi._(_root);
	@override late final _TranslationsSearchHi search = _TranslationsSearchHi._(_root);
	@override late final _TranslationsSettingsHi settings = _TranslationsSettingsHi._(_root);
	@override late final _TranslationsWorkspaceHi workspace = _TranslationsWorkspaceHi._(_root);
}

// Path: app
class _TranslationsAppHi extends _TranslationsAppEn {
	_TranslationsAppHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterHi extends _TranslationsCharacterEn {
	_TranslationsCharacterHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatHi extends _TranslationsChatEn {
	_TranslationsChatHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonHi extends _TranslationsCommonEn {
	_TranslationsCommonHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorHi extends _TranslationsEditorEn {
	_TranslationsEditorHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridHi extends _TranslationsGridEn {
	_TranslationsGridHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupHi extends _TranslationsGroupEn {
	_TranslationsGroupHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppHi extends _TranslationsLlmAppEn {
	_TranslationsLlmAppHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryHi extends _TranslationsMemoryEn {
	_TranslationsMemoryHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesHi extends _TranslationsNodesEn {
	_TranslationsNodesHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingHi extends _TranslationsOnboardingEn {
	_TranslationsOnboardingHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingHi extends _TranslationsRoutingEn {
	_TranslationsRoutingHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchHi extends _TranslationsSearchEn {
	_TranslationsSearchHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsHi extends _TranslationsSettingsEn {
	_TranslationsSettingsHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceHi extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceHi._(_TranslationsHi root) : this._root = root, super._(root);

	@override final _TranslationsHi _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsJa extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsJa.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsJa _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppJa app = _TranslationsAppJa._(_root);
	@override late final _TranslationsCharacterJa character = _TranslationsCharacterJa._(_root);
	@override late final _TranslationsChatJa chat = _TranslationsChatJa._(_root);
	@override late final _TranslationsCommonJa common = _TranslationsCommonJa._(_root);
	@override late final _TranslationsEditorJa editor = _TranslationsEditorJa._(_root);
	@override late final _TranslationsGridJa grid = _TranslationsGridJa._(_root);
	@override late final _TranslationsGroupJa group = _TranslationsGroupJa._(_root);
	@override late final _TranslationsLlmAppJa llmApp = _TranslationsLlmAppJa._(_root);
	@override late final _TranslationsMemoryJa memory = _TranslationsMemoryJa._(_root);
	@override late final _TranslationsNodesJa nodes = _TranslationsNodesJa._(_root);
	@override late final _TranslationsOnboardingJa onboarding = _TranslationsOnboardingJa._(_root);
	@override late final _TranslationsRoutingJa routing = _TranslationsRoutingJa._(_root);
	@override late final _TranslationsSearchJa search = _TranslationsSearchJa._(_root);
	@override late final _TranslationsSettingsJa settings = _TranslationsSettingsJa._(_root);
	@override late final _TranslationsWorkspaceJa workspace = _TranslationsWorkspaceJa._(_root);
}

// Path: app
class _TranslationsAppJa extends _TranslationsAppEn {
	_TranslationsAppJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterJa extends _TranslationsCharacterEn {
	_TranslationsCharacterJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatJa extends _TranslationsChatEn {
	_TranslationsChatJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonJa extends _TranslationsCommonEn {
	_TranslationsCommonJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorJa extends _TranslationsEditorEn {
	_TranslationsEditorJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridJa extends _TranslationsGridEn {
	_TranslationsGridJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupJa extends _TranslationsGroupEn {
	_TranslationsGroupJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppJa extends _TranslationsLlmAppEn {
	_TranslationsLlmAppJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryJa extends _TranslationsMemoryEn {
	_TranslationsMemoryJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesJa extends _TranslationsNodesEn {
	_TranslationsNodesJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingJa extends _TranslationsOnboardingEn {
	_TranslationsOnboardingJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingJa extends _TranslationsRoutingEn {
	_TranslationsRoutingJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchJa extends _TranslationsSearchEn {
	_TranslationsSearchJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsJa extends _TranslationsSettingsEn {
	_TranslationsSettingsJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceJa extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceJa._(_TranslationsJa root) : this._root = root, super._(root);

	@override final _TranslationsJa _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsKo extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsKo.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.ko,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ko>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsKo _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppKo app = _TranslationsAppKo._(_root);
	@override late final _TranslationsCharacterKo character = _TranslationsCharacterKo._(_root);
	@override late final _TranslationsChatKo chat = _TranslationsChatKo._(_root);
	@override late final _TranslationsCommonKo common = _TranslationsCommonKo._(_root);
	@override late final _TranslationsEditorKo editor = _TranslationsEditorKo._(_root);
	@override late final _TranslationsGridKo grid = _TranslationsGridKo._(_root);
	@override late final _TranslationsGroupKo group = _TranslationsGroupKo._(_root);
	@override late final _TranslationsLlmAppKo llmApp = _TranslationsLlmAppKo._(_root);
	@override late final _TranslationsMemoryKo memory = _TranslationsMemoryKo._(_root);
	@override late final _TranslationsNodesKo nodes = _TranslationsNodesKo._(_root);
	@override late final _TranslationsOnboardingKo onboarding = _TranslationsOnboardingKo._(_root);
	@override late final _TranslationsRoutingKo routing = _TranslationsRoutingKo._(_root);
	@override late final _TranslationsSearchKo search = _TranslationsSearchKo._(_root);
	@override late final _TranslationsSettingsKo settings = _TranslationsSettingsKo._(_root);
	@override late final _TranslationsWorkspaceKo workspace = _TranslationsWorkspaceKo._(_root);
}

// Path: app
class _TranslationsAppKo extends _TranslationsAppEn {
	_TranslationsAppKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterKo extends _TranslationsCharacterEn {
	_TranslationsCharacterKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatKo extends _TranslationsChatEn {
	_TranslationsChatKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonKo extends _TranslationsCommonEn {
	_TranslationsCommonKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorKo extends _TranslationsEditorEn {
	_TranslationsEditorKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridKo extends _TranslationsGridEn {
	_TranslationsGridKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupKo extends _TranslationsGroupEn {
	_TranslationsGroupKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppKo extends _TranslationsLlmAppEn {
	_TranslationsLlmAppKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryKo extends _TranslationsMemoryEn {
	_TranslationsMemoryKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesKo extends _TranslationsNodesEn {
	_TranslationsNodesKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingKo extends _TranslationsOnboardingEn {
	_TranslationsOnboardingKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingKo extends _TranslationsRoutingEn {
	_TranslationsRoutingKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchKo extends _TranslationsSearchEn {
	_TranslationsSearchKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsKo extends _TranslationsSettingsEn {
	_TranslationsSettingsKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceKo extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceKo._(_TranslationsKo root) : this._root = root, super._(root);

	@override final _TranslationsKo _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsPtBr extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsPtBr.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.ptBr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt-BR>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsPtBr _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppPtBr app = _TranslationsAppPtBr._(_root);
	@override late final _TranslationsCharacterPtBr character = _TranslationsCharacterPtBr._(_root);
	@override late final _TranslationsChatPtBr chat = _TranslationsChatPtBr._(_root);
	@override late final _TranslationsCommonPtBr common = _TranslationsCommonPtBr._(_root);
	@override late final _TranslationsEditorPtBr editor = _TranslationsEditorPtBr._(_root);
	@override late final _TranslationsGridPtBr grid = _TranslationsGridPtBr._(_root);
	@override late final _TranslationsGroupPtBr group = _TranslationsGroupPtBr._(_root);
	@override late final _TranslationsLlmAppPtBr llmApp = _TranslationsLlmAppPtBr._(_root);
	@override late final _TranslationsMemoryPtBr memory = _TranslationsMemoryPtBr._(_root);
	@override late final _TranslationsNodesPtBr nodes = _TranslationsNodesPtBr._(_root);
	@override late final _TranslationsOnboardingPtBr onboarding = _TranslationsOnboardingPtBr._(_root);
	@override late final _TranslationsRoutingPtBr routing = _TranslationsRoutingPtBr._(_root);
	@override late final _TranslationsSearchPtBr search = _TranslationsSearchPtBr._(_root);
	@override late final _TranslationsSettingsPtBr settings = _TranslationsSettingsPtBr._(_root);
	@override late final _TranslationsWorkspacePtBr workspace = _TranslationsWorkspacePtBr._(_root);
}

// Path: app
class _TranslationsAppPtBr extends _TranslationsAppEn {
	_TranslationsAppPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterPtBr extends _TranslationsCharacterEn {
	_TranslationsCharacterPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatPtBr extends _TranslationsChatEn {
	_TranslationsChatPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonPtBr extends _TranslationsCommonEn {
	_TranslationsCommonPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorPtBr extends _TranslationsEditorEn {
	_TranslationsEditorPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridPtBr extends _TranslationsGridEn {
	_TranslationsGridPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupPtBr extends _TranslationsGroupEn {
	_TranslationsGroupPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppPtBr extends _TranslationsLlmAppEn {
	_TranslationsLlmAppPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryPtBr extends _TranslationsMemoryEn {
	_TranslationsMemoryPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesPtBr extends _TranslationsNodesEn {
	_TranslationsNodesPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingPtBr extends _TranslationsOnboardingEn {
	_TranslationsOnboardingPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingPtBr extends _TranslationsRoutingEn {
	_TranslationsRoutingPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchPtBr extends _TranslationsSearchEn {
	_TranslationsSearchPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsPtBr extends _TranslationsSettingsEn {
	_TranslationsSettingsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspacePtBr extends _TranslationsWorkspaceEn {
	_TranslationsWorkspacePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsRu extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsRu.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.ru,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ru>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsRu _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppRu app = _TranslationsAppRu._(_root);
	@override late final _TranslationsCharacterRu character = _TranslationsCharacterRu._(_root);
	@override late final _TranslationsChatRu chat = _TranslationsChatRu._(_root);
	@override late final _TranslationsCommonRu common = _TranslationsCommonRu._(_root);
	@override late final _TranslationsEditorRu editor = _TranslationsEditorRu._(_root);
	@override late final _TranslationsGridRu grid = _TranslationsGridRu._(_root);
	@override late final _TranslationsGroupRu group = _TranslationsGroupRu._(_root);
	@override late final _TranslationsLlmAppRu llmApp = _TranslationsLlmAppRu._(_root);
	@override late final _TranslationsMemoryRu memory = _TranslationsMemoryRu._(_root);
	@override late final _TranslationsNodesRu nodes = _TranslationsNodesRu._(_root);
	@override late final _TranslationsOnboardingRu onboarding = _TranslationsOnboardingRu._(_root);
	@override late final _TranslationsRoutingRu routing = _TranslationsRoutingRu._(_root);
	@override late final _TranslationsSearchRu search = _TranslationsSearchRu._(_root);
	@override late final _TranslationsSettingsRu settings = _TranslationsSettingsRu._(_root);
	@override late final _TranslationsWorkspaceRu workspace = _TranslationsWorkspaceRu._(_root);
}

// Path: app
class _TranslationsAppRu extends _TranslationsAppEn {
	_TranslationsAppRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterRu extends _TranslationsCharacterEn {
	_TranslationsCharacterRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatRu extends _TranslationsChatEn {
	_TranslationsChatRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonRu extends _TranslationsCommonEn {
	_TranslationsCommonRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorRu extends _TranslationsEditorEn {
	_TranslationsEditorRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridRu extends _TranslationsGridEn {
	_TranslationsGridRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupRu extends _TranslationsGroupEn {
	_TranslationsGroupRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppRu extends _TranslationsLlmAppEn {
	_TranslationsLlmAppRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryRu extends _TranslationsMemoryEn {
	_TranslationsMemoryRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesRu extends _TranslationsNodesEn {
	_TranslationsNodesRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingRu extends _TranslationsOnboardingEn {
	_TranslationsOnboardingRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingRu extends _TranslationsRoutingEn {
	_TranslationsRoutingRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchRu extends _TranslationsSearchEn {
	_TranslationsSearchRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsRu extends _TranslationsSettingsEn {
	_TranslationsSettingsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceRu extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsZhHans extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsZhHans.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhHans,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hans>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsZhHans _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppZhHans app = _TranslationsAppZhHans._(_root);
	@override late final _TranslationsCharacterZhHans character = _TranslationsCharacterZhHans._(_root);
	@override late final _TranslationsChatZhHans chat = _TranslationsChatZhHans._(_root);
	@override late final _TranslationsCommonZhHans common = _TranslationsCommonZhHans._(_root);
	@override late final _TranslationsEditorZhHans editor = _TranslationsEditorZhHans._(_root);
	@override late final _TranslationsGridZhHans grid = _TranslationsGridZhHans._(_root);
	@override late final _TranslationsGroupZhHans group = _TranslationsGroupZhHans._(_root);
	@override late final _TranslationsLlmAppZhHans llmApp = _TranslationsLlmAppZhHans._(_root);
	@override late final _TranslationsMemoryZhHans memory = _TranslationsMemoryZhHans._(_root);
	@override late final _TranslationsNodesZhHans nodes = _TranslationsNodesZhHans._(_root);
	@override late final _TranslationsOnboardingZhHans onboarding = _TranslationsOnboardingZhHans._(_root);
	@override late final _TranslationsRoutingZhHans routing = _TranslationsRoutingZhHans._(_root);
	@override late final _TranslationsSearchZhHans search = _TranslationsSearchZhHans._(_root);
	@override late final _TranslationsSettingsZhHans settings = _TranslationsSettingsZhHans._(_root);
	@override late final _TranslationsWorkspaceZhHans workspace = _TranslationsWorkspaceZhHans._(_root);
}

// Path: app
class _TranslationsAppZhHans extends _TranslationsAppEn {
	_TranslationsAppZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterZhHans extends _TranslationsCharacterEn {
	_TranslationsCharacterZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatZhHans extends _TranslationsChatEn {
	_TranslationsChatZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonZhHans extends _TranslationsCommonEn {
	_TranslationsCommonZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorZhHans extends _TranslationsEditorEn {
	_TranslationsEditorZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridZhHans extends _TranslationsGridEn {
	_TranslationsGridZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupZhHans extends _TranslationsGroupEn {
	_TranslationsGroupZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppZhHans extends _TranslationsLlmAppEn {
	_TranslationsLlmAppZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryZhHans extends _TranslationsMemoryEn {
	_TranslationsMemoryZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesZhHans extends _TranslationsNodesEn {
	_TranslationsNodesZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingZhHans extends _TranslationsOnboardingEn {
	_TranslationsOnboardingZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingZhHans extends _TranslationsRoutingEn {
	_TranslationsRoutingZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchZhHans extends _TranslationsSearchEn {
	_TranslationsSearchZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsZhHans extends _TranslationsSettingsEn {
	_TranslationsSettingsZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceZhHans extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

	@override final _TranslationsZhHans _root; // ignore: unused_field

	// Translations
}

// Path: <root>
class _TranslationsZhHant extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsZhHant.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhHant,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hant>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsZhHant _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppZhHant app = _TranslationsAppZhHant._(_root);
	@override late final _TranslationsCharacterZhHant character = _TranslationsCharacterZhHant._(_root);
	@override late final _TranslationsChatZhHant chat = _TranslationsChatZhHant._(_root);
	@override late final _TranslationsCommonZhHant common = _TranslationsCommonZhHant._(_root);
	@override late final _TranslationsEditorZhHant editor = _TranslationsEditorZhHant._(_root);
	@override late final _TranslationsGridZhHant grid = _TranslationsGridZhHant._(_root);
	@override late final _TranslationsGroupZhHant group = _TranslationsGroupZhHant._(_root);
	@override late final _TranslationsLlmAppZhHant llmApp = _TranslationsLlmAppZhHant._(_root);
	@override late final _TranslationsMemoryZhHant memory = _TranslationsMemoryZhHant._(_root);
	@override late final _TranslationsNodesZhHant nodes = _TranslationsNodesZhHant._(_root);
	@override late final _TranslationsOnboardingZhHant onboarding = _TranslationsOnboardingZhHant._(_root);
	@override late final _TranslationsRoutingZhHant routing = _TranslationsRoutingZhHant._(_root);
	@override late final _TranslationsSearchZhHant search = _TranslationsSearchZhHant._(_root);
	@override late final _TranslationsSettingsZhHant settings = _TranslationsSettingsZhHant._(_root);
	@override late final _TranslationsWorkspaceZhHant workspace = _TranslationsWorkspaceZhHant._(_root);
}

// Path: app
class _TranslationsAppZhHant extends _TranslationsAppEn {
	_TranslationsAppZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: character
class _TranslationsCharacterZhHant extends _TranslationsCharacterEn {
	_TranslationsCharacterZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: chat
class _TranslationsChatZhHant extends _TranslationsChatEn {
	_TranslationsChatZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: common
class _TranslationsCommonZhHant extends _TranslationsCommonEn {
	_TranslationsCommonZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: editor
class _TranslationsEditorZhHant extends _TranslationsEditorEn {
	_TranslationsEditorZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: grid
class _TranslationsGridZhHant extends _TranslationsGridEn {
	_TranslationsGridZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: group
class _TranslationsGroupZhHant extends _TranslationsGroupEn {
	_TranslationsGroupZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: llmApp
class _TranslationsLlmAppZhHant extends _TranslationsLlmAppEn {
	_TranslationsLlmAppZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: memory
class _TranslationsMemoryZhHant extends _TranslationsMemoryEn {
	_TranslationsMemoryZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: nodes
class _TranslationsNodesZhHant extends _TranslationsNodesEn {
	_TranslationsNodesZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: onboarding
class _TranslationsOnboardingZhHant extends _TranslationsOnboardingEn {
	_TranslationsOnboardingZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: routing
class _TranslationsRoutingZhHant extends _TranslationsRoutingEn {
	_TranslationsRoutingZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: search
class _TranslationsSearchZhHant extends _TranslationsSearchEn {
	_TranslationsSearchZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: settings
class _TranslationsSettingsZhHant extends _TranslationsSettingsEn {
	_TranslationsSettingsZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

// Path: workspace
class _TranslationsWorkspaceZhHant extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on Translations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'common.actions.delete': return 'Delete';
			case 'grid.emptyState.noMatches': return 'No characters match your filters';
			case 'grid.emptyState.noCharacters': return 'No characters imported yet';
			case 'grid.emptyState.clearAllFilters': return 'Clear all filters';
			case 'grid.emptyState.importCharacters': return 'Import Characters';
			case 'grid.emptyState.createNewCharacter': return 'Create New Character';
			case 'grid.appBar.groups': return 'Groups';
			case 'grid.appBar.createNew': return 'Create New';
			case 'grid.appBar.import': return 'Import';
			case 'grid.appBar.menuTooltip': return 'Menu';
			case 'grid.fab.addOrImportTooltip': return 'Add or Import';
			case 'grid.fab.import': return 'Import';
			case 'grid.fab.create': return 'Create';
			case 'grid.drawer.mediaDefaultsApp': return 'App';
			case 'grid.drawer.batchAiHeader': return 'Batch AI';
			case 'grid.drawer.batchGeneratePreviewsTitle': return 'Batch Generate Previews';
			case 'grid.drawer.batchGeneratePreviewsEmpty': return 'All characters already have previews.';
			case 'grid.drawer.batchAutoTagTitle': return 'Batch Auto-Tag';
			case 'grid.drawer.batchAutoTagEmpty': return 'All characters already have tags.';
			case 'grid.drawer.libraryHeader': return 'Library';
			case 'grid.drawer.reloadCharacters': return 'Reload characters';
			case 'grid.variantBadge.tooltip': return ({required Object count}) => '${count} Variants';
			case 'grid.dialogActions.clearAll': return 'Clear All';
			case 'grid.dialogActions.apply': return 'Apply';
			case 'grid.tagFilterDialog.title': return 'Filter Tags';
			case 'grid.tagFilterDialog.searchHint': return 'Search tags...';
			case 'grid.filters.hideFiltersTooltip': return 'Hide filters';
			case 'grid.filters.moreFiltersTooltip': return 'More filters';
			case 'grid.filters.folderChip': return 'Folder';
			case 'grid.filters.creatorChip': return 'Creator';
			case 'grid.filters.tagChip': return 'Tag';
			case 'grid.filters.recentTooltip': return 'Recent';
			case 'grid.filters.favoritesTooltip': return 'Favorites';
			case 'grid.filters.variantsTooltip': return 'Variants';
			case 'grid.filters.indexingProgress': return ({required Object done, required Object total}) => 'Building search ${done} / ${total}…';
			case 'grid.sortOption.relevance': return 'Relevance ↓';
			case 'grid.sortOption.nameAsc': return 'Name ↓';
			case 'grid.sortOption.nameDesc': return 'Name ↑';
			case 'grid.sortOption.importNewest': return 'Imported ↓';
			case 'grid.sortOption.importOldest': return 'Imported ↑';
			case 'grid.sortOption.modifiedNewest': return 'Modified ↓';
			case 'grid.sortOption.modifiedOldest': return 'Modified ↑';
			case 'grid.sortOption.interactedNewest': return 'Interacted ↓';
			case 'grid.sortOption.interactedOldest': return 'Interacted ↑';
			case 'grid.sortOption.tokensHigh': return 'Tokens ↓';
			case 'grid.sortOption.tokensLow': return 'Tokens ↑';
			case 'grid.filterController.filterCreators': return 'Filter Creators';
			case 'grid.filterController.filterTags': return 'Filter Tags';
			case 'grid.filterController.filterByFolder': return 'Filter by Folder';
			case 'grid.multiSelectDialog.nothingToShow': return 'Nothing to show yet.';
			case 'grid.multiSelectDialog.noMatches': return 'No matches.';
			case 'grid.multiSelectDialog.showMore': return 'Show More';
			case 'grid.createCharacterDialog.nameEmptyError': return 'Character name cannot be empty.';
			case 'grid.createCharacterDialog.nameInvalidCharsError': return 'Name contains invalid characters (<>:"/\|?*).';
			case 'grid.createCharacterDialog.nameExistsError': return 'A character with this name already exists.';
			case 'grid.createCharacterDialog.nameCheckFailedError': return 'Could not verify the name. Check folder permissions and try again.';
			case 'grid.createCharacterDialog.title': return 'Create New Character';
			case 'grid.createCharacterDialog.nameLabel': return 'Character Name';
			case 'grid.createCharacterDialog.createButton': return 'Create';
			case 'grid.variantsSheet.title': return 'Variants';
			case 'grid.groupAppBar.characters': return 'Characters';
			case 'grid.groupAppBar.newGroup': return 'New group';
			case 'grid.thumbnailBadges.recent': return 'RECENT';
			case 'grid.thumbnailBadges.original': return 'ORIGINAL';
			case 'grid.thumbnailBadges.variant': return 'VARIANT';
			case 'grid.actionMenu.editNotes': return 'Edit Notes';
			case 'grid.actionMenu.dismissRecent': return 'Dismiss Recent';
			case 'grid.actionMenu.exportPngV2V3': return 'Export as PNG (V2/V3)';
			case 'grid.actionMenu.exportJsonV3': return 'Export as JSON (V3)';
			case 'grid.actionMenu.exportJsonV2': return 'Export as JSON (V2)';
			case 'grid.actionMenu.duplicate': return 'Duplicate';
			case 'grid.controllerMessages.duplicateFailed': return 'Could not duplicate the character.';
			case 'grid.controllerMessages.editVariantNotesTitle': return 'Edit Variant Notes';
			case 'grid.controllerMessages.editVariantNotesHint': return 'Add notes about this variant...';
			case 'grid.controllerMessages.deleteCardTitle': return 'Delete Card';
			case 'grid.controllerMessages.deleteCardMessage': return 'Are you sure you want to delete this card?';
			case 'grid.controllerMessages.deletePartialFailure': return 'Some files could not be deleted. Check logs for details.';
			case 'settings.gearLanguage': return 'Language';
			case 'settings.languageSystemDefault': return 'System default';
			default: return null;
		}
	}
}

extension on _TranslationsEs419 {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsHi {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsJa {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsKo {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsPtBr {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsRu {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsZhHans {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}

extension on _TranslationsZhHant {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			default: return null;
		}
	}
}
