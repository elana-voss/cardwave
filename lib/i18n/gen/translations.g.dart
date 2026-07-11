/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 9
/// Strings: 726 (80 per locale)

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
	late final _TranslationsCharacterPromptPrefixDialogEn promptPrefixDialog = _TranslationsCharacterPromptPrefixDialogEn._(_root);
	late final _TranslationsCharacterCardEditApprovalEn cardEditApproval = _TranslationsCharacterCardEditApprovalEn._(_root);
	late final _TranslationsCharacterRequireApprovalTileEn requireApprovalTile = _TranslationsCharacterRequireApprovalTileEn._(_root);
	late final _TranslationsCharacterLoadingStatusEn loadingStatus = _TranslationsCharacterLoadingStatusEn._(_root);
	late final _TranslationsCharacterSavePathValidationEn savePathValidation = _TranslationsCharacterSavePathValidationEn._(_root);
	String get characterFilesTypeGroupLabel => 'Character Files';
	late final _TranslationsCharacterCreateControllerEn createController = _TranslationsCharacterCreateControllerEn._(_root);
	late final _TranslationsCharacterImportControllerEn importController = _TranslationsCharacterImportControllerEn._(_root);
	late final _TranslationsCharacterAiActionControllerEn aiActionController = _TranslationsCharacterAiActionControllerEn._(_root);
}

// Path: chat
class _TranslationsChatEn {
	_TranslationsChatEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsChatTileAiProviderEn tileAiProvider = _TranslationsChatTileAiProviderEn._(_root);
	late final _TranslationsChatPresetTileEn presetTile = _TranslationsChatPresetTileEn._(_root);
	late final _TranslationsChatTileImagePresetEn tileImagePreset = _TranslationsChatTileImagePresetEn._(_root);
	late final _TranslationsChatTileVideoPresetEn tileVideoPreset = _TranslationsChatTileVideoPresetEn._(_root);
	late final _TranslationsChatTileTtsPresetEn tileTtsPreset = _TranslationsChatTileTtsPresetEn._(_root);
	late final _TranslationsChatTileImageAspectRatioEn tileImageAspectRatio = _TranslationsChatTileImageAspectRatioEn._(_root);
	late final _TranslationsChatTileVideoAspectRatioEn tileVideoAspectRatio = _TranslationsChatTileVideoAspectRatioEn._(_root);
	late final _TranslationsChatTileVideoResolutionEn tileVideoResolution = _TranslationsChatTileVideoResolutionEn._(_root);
	late final _TranslationsChatTileVideoDurationEn tileVideoDuration = _TranslationsChatTileVideoDurationEn._(_root);
	late final _TranslationsChatTileTtsVoiceEn tileTtsVoice = _TranslationsChatTileTtsVoiceEn._(_root);
	late final _TranslationsChatTileTtsLanguageEn tileTtsLanguage = _TranslationsChatTileTtsLanguageEn._(_root);
	late final _TranslationsChatTileNsfwEn tileNsfw = _TranslationsChatTileNsfwEn._(_root);
	late final _TranslationsChatTileScenarioEn tileScenario = _TranslationsChatTileScenarioEn._(_root);
	late final _TranslationsChatTileMaxResponseLengthEn tileMaxResponseLength = _TranslationsChatTileMaxResponseLengthEn._(_root);
	late final _TranslationsChatTileTrailingParagraphEn tileTrailingParagraph = _TranslationsChatTileTrailingParagraphEn._(_root);
	late final _TranslationsChatTileReasoningEffortEn tileReasoningEffort = _TranslationsChatTileReasoningEffortEn._(_root);
	late final _TranslationsChatTileChatThemeEn tileChatTheme = _TranslationsChatTileChatThemeEn._(_root);
	late final _TranslationsChatTileRecalledMemoryEn tileRecalledMemory = _TranslationsChatTileRecalledMemoryEn._(_root);
	late final _TranslationsChatCharacterSwitcherEn characterSwitcher = _TranslationsChatCharacterSwitcherEn._(_root);
	late final _TranslationsChatFreeImagePromptDialogEn freeImagePromptDialog = _TranslationsChatFreeImagePromptDialogEn._(_root);
	late final _TranslationsChatFreeVideoPromptDialogEn freeVideoPromptDialog = _TranslationsChatFreeVideoPromptDialogEn._(_root);
	late final _TranslationsChatImagePromptReviewDialogEn imagePromptReviewDialog = _TranslationsChatImagePromptReviewDialogEn._(_root);
	late final _TranslationsChatVideoPromptReviewDialogEn videoPromptReviewDialog = _TranslationsChatVideoPromptReviewDialogEn._(_root);
	late final _TranslationsChatUrlFetchReviewDialogEn urlFetchReviewDialog = _TranslationsChatUrlFetchReviewDialogEn._(_root);
	late final _TranslationsChatMessageActionsRowEn messageActionsRow = _TranslationsChatMessageActionsRowEn._(_root);
	late final _TranslationsChatTtsPlayButtonEn ttsPlayButton = _TranslationsChatTtsPlayButtonEn._(_root);
	late final _TranslationsChatMessageSwipeFlipperEn messageSwipeFlipper = _TranslationsChatMessageSwipeFlipperEn._(_root);
	late final _TranslationsChatVideoPlayerInlineEn videoPlayerInline = _TranslationsChatVideoPlayerInlineEn._(_root);
	String get newChatLabel => 'New Chat';
	late final _TranslationsChatChatListItemEn chatListItem = _TranslationsChatChatListItemEn._(_root);
	late final _TranslationsChatChatHistoryControllerEn chatHistoryController = _TranslationsChatChatHistoryControllerEn._(_root);
	late final _TranslationsChatChatPageControllerEn chatPageController = _TranslationsChatChatPageControllerEn._(_root);
	late final _TranslationsChatImageGenerationMixinEn imageGenerationMixin = _TranslationsChatImageGenerationMixinEn._(_root);
	late final _TranslationsChatVideoGenerationMixinEn videoGenerationMixin = _TranslationsChatVideoGenerationMixinEn._(_root);
	late final _TranslationsChatBubbleWaitingForEn bubbleWaitingFor = _TranslationsChatBubbleWaitingForEn._(_root);
	late final _TranslationsChatAppBarChatEn appBarChat = _TranslationsChatAppBarChatEn._(_root);
	late final _TranslationsChatAllChatsDrawerListEn allChatsDrawerList = _TranslationsChatAllChatsDrawerListEn._(_root);
	late final _TranslationsChatChatInputMediaMenuEn chatInputMediaMenu = _TranslationsChatChatInputMediaMenuEn._(_root);
	late final _TranslationsChatChatViewEn chatView = _TranslationsChatChatViewEn._(_root);
	late final _TranslationsChatChatMessageBubbleEn chatMessageBubble = _TranslationsChatChatMessageBubbleEn._(_root);
}

// Path: common
class _TranslationsCommonEn {
	_TranslationsCommonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsCommonActionsEn actions = _TranslationsCommonActionsEn._(_root);
	late final _TranslationsCommonAiActionEn aiAction = _TranslationsCommonAiActionEn._(_root);
	String get aiActionsTooltip => 'AI Actions';
	late final _TranslationsCommonPromptSegmentKindEn promptSegmentKind = _TranslationsCommonPromptSegmentKindEn._(_root);
	late final _TranslationsCommonPromptBreakdownEn promptBreakdown = _TranslationsCommonPromptBreakdownEn._(_root);
	late final _TranslationsCommonLogsEn logs = _TranslationsCommonLogsEn._(_root);
	late final _TranslationsCommonImportErrorsDialogEn importErrorsDialog = _TranslationsCommonImportErrorsDialogEn._(_root);
	late final _TranslationsCommonUpdateDialogEn updateDialog = _TranslationsCommonUpdateDialogEn._(_root);
	late final _TranslationsCommonImportConflictsDialogEn importConflictsDialog = _TranslationsCommonImportConflictsDialogEn._(_root);
	late final _TranslationsCommonMissingProviderBannerEn missingProviderBanner = _TranslationsCommonMissingProviderBannerEn._(_root);
	late final _TranslationsCommonModelSelectionDialogEn modelSelectionDialog = _TranslationsCommonModelSelectionDialogEn._(_root);
	late final _TranslationsCommonShowAdvancedEn showAdvanced = _TranslationsCommonShowAdvancedEn._(_root);
	late final _TranslationsCommonMessageEditDialogEn messageEditDialog = _TranslationsCommonMessageEditDialogEn._(_root);
	late final _TranslationsCommonPromptBreakdownDialogEn promptBreakdownDialog = _TranslationsCommonPromptBreakdownDialogEn._(_root);
	late final _TranslationsCommonJsonPromptDialogEn jsonPromptDialog = _TranslationsCommonJsonPromptDialogEn._(_root);
	late final _TranslationsCommonProgressDialogEn progressDialog = _TranslationsCommonProgressDialogEn._(_root);
	late final _TranslationsCommonDiffPanelEn diffPanel = _TranslationsCommonDiffPanelEn._(_root);
	late final _TranslationsCommonSelectionDialogEn selectionDialog = _TranslationsCommonSelectionDialogEn._(_root);
	late final _TranslationsCommonZdrSwitchEn zdrSwitch = _TranslationsCommonZdrSwitchEn._(_root);
	late final _TranslationsCommonTextFieldCardEn textFieldCard = _TranslationsCommonTextFieldCardEn._(_root);
	late final _TranslationsCommonModelCapabilityEn modelCapability = _TranslationsCommonModelCapabilityEn._(_root);
	String get modelUnavailableTooltip => 'This model is no longer available from the provider — pick another.';
	String get characterImageSemanticLabel => 'Character image';
	late final _TranslationsCommonAppConstantsEn appConstants = _TranslationsCommonAppConstantsEn._(_root);
}

// Path: editor
class _TranslationsEditorEn {
	_TranslationsEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsEditorPanelLabelsEn panelLabels = _TranslationsEditorPanelLabelsEn._(_root);
	late final _TranslationsEditorAppBarEditorEn appBarEditor = _TranslationsEditorAppBarEditorEn._(_root);
	late final _TranslationsEditorCodeFindPanelEn codeFindPanel = _TranslationsEditorCodeFindPanelEn._(_root);
	late final _TranslationsEditorFindReplaceDialogEn findReplaceDialog = _TranslationsEditorFindReplaceDialogEn._(_root);
	late final _TranslationsEditorObjectValueEditorEn objectValueEditor = _TranslationsEditorObjectValueEditorEn._(_root);
	late final _TranslationsEditorEditorBasicEn editorBasic = _TranslationsEditorEditorBasicEn._(_root);
	late final _TranslationsEditorEditorCreatorMetadataEn editorCreatorMetadata = _TranslationsEditorEditorCreatorMetadataEn._(_root);
	late final _TranslationsEditorEditorPromptsEn editorPrompts = _TranslationsEditorEditorPromptsEn._(_root);
	late final _TranslationsEditorEditorAppDataEn editorAppData = _TranslationsEditorEditorAppDataEn._(_root);
	late final _TranslationsEditorEditorAlternateGreetingsEn editorAlternateGreetings = _TranslationsEditorEditorAlternateGreetingsEn._(_root);
	late final _TranslationsEditorEditorGroupGreetingsEn editorGroupGreetings = _TranslationsEditorEditorGroupGreetingsEn._(_root);
	late final _TranslationsEditorEditorLorebookEn editorLorebook = _TranslationsEditorEditorLorebookEn._(_root);
	late final _TranslationsEditorLorebookEntryListTileEn lorebookEntryListTile = _TranslationsEditorLorebookEntryListTileEn._(_root);
	late final _TranslationsEditorLorebookEntryEditorPageEn lorebookEntryEditorPage = _TranslationsEditorLorebookEntryEditorPageEn._(_root);
	late final _TranslationsEditorLorebookEntryEditorTopSectionEn lorebookEntryEditorTopSection = _TranslationsEditorLorebookEntryEditorTopSectionEn._(_root);
	late final _TranslationsEditorLorebookEntryEditorScanRowEn lorebookEntryEditorScanRow = _TranslationsEditorLorebookEntryEditorScanRowEn._(_root);
	late final _TranslationsEditorDialogContentCleanerEn dialogContentCleaner = _TranslationsEditorDialogContentCleanerEn._(_root);
	late final _TranslationsEditorDialogAiDiffConfirmationEn dialogAiDiffConfirmation = _TranslationsEditorDialogAiDiffConfirmationEn._(_root);
	late final _TranslationsEditorEditorPageControllerEn editorPageController = _TranslationsEditorEditorPageControllerEn._(_root);
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
	late final _TranslationsLlmAppMediaFieldEn mediaField = _TranslationsLlmAppMediaFieldEn._(_root);
	late final _TranslationsLlmAppMediaSectionEn mediaSection = _TranslationsLlmAppMediaSectionEn._(_root);
	late final _TranslationsLlmAppTristateEn tristate = _TranslationsLlmAppTristateEn._(_root);
	late final _TranslationsLlmAppMediaCellMenuEn mediaCellMenu = _TranslationsLlmAppMediaCellMenuEn._(_root);
	late final _TranslationsLlmAppMediaHeaderEn mediaHeader = _TranslationsLlmAppMediaHeaderEn._(_root);
	late final _TranslationsLlmAppPresetRowEn presetRow = _TranslationsLlmAppPresetRowEn._(_root);
	late final _TranslationsLlmAppMediaCellEn mediaCell = _TranslationsLlmAppMediaCellEn._(_root);
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
	String get finishFailedSnackbar => 'Setup failed. See logs for details.';
	String get appBarTitle => 'Quick Setup';
	String get webWarning => 'Experimental web build — browser storage may reset between updates. Use desktop or Android for persistent data.';
	String get finishButton => 'Finish Setup';
	String get nextButton => 'Next';
	String get backButton => 'Back';
	late final _TranslationsOnboardingStorageStepEn storageStep = _TranslationsOnboardingStorageStepEn._(_root);
	late final _TranslationsOnboardingSetupStepEn setupStep = _TranslationsOnboardingSetupStepEn._(_root);
	late final _TranslationsOnboardingAiSectionEn aiSection = _TranslationsOnboardingAiSectionEn._(_root);
	late final _TranslationsOnboardingAiStatusEn aiStatus = _TranslationsOnboardingAiStatusEn._(_root);
	late final _TranslationsOnboardingPersonaSectionEn personaSection = _TranslationsOnboardingPersonaSectionEn._(_root);
	late final _TranslationsOnboardingDisclaimerEn disclaimer = _TranslationsOnboardingDisclaimerEn._(_root);
	late final _TranslationsOnboardingFetchErrorEn fetchError = _TranslationsOnboardingFetchErrorEn._(_root);
}

// Path: routing
class _TranslationsRoutingEn {
	_TranslationsRoutingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsRoutingChatCharacterEn chatCharacter = _TranslationsRoutingChatCharacterEn._(_root);
	late final _TranslationsRoutingEditCharacterEn editCharacter = _TranslationsRoutingEditCharacterEn._(_root);
	late final _TranslationsRoutingEditPresetEn editPreset = _TranslationsRoutingEditPresetEn._(_root);
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
	late final _TranslationsSettingsGearMenuEn gearMenu = _TranslationsSettingsGearMenuEn._(_root);
	late final _TranslationsSettingsMediaDefaultsDrawerEntryEn mediaDefaultsDrawerEntry = _TranslationsSettingsMediaDefaultsDrawerEntryEn._(_root);
	late final _TranslationsSettingsEndDrawerEn endDrawer = _TranslationsSettingsEndDrawerEn._(_root);
	late final _TranslationsSettingsGeneralEn general = _TranslationsSettingsGeneralEn._(_root);
	late final _TranslationsSettingsAiSettingsTabEn aiSettingsTab = _TranslationsSettingsAiSettingsTabEn._(_root);
	late final _TranslationsSettingsAiTabEn aiTab = _TranslationsSettingsAiTabEn._(_root);
	late final _TranslationsSettingsPresetConfigEn presetConfig = _TranslationsSettingsPresetConfigEn._(_root);
	late final _TranslationsSettingsProviderConfigEn providerConfig = _TranslationsSettingsProviderConfigEn._(_root);
	late final _TranslationsSettingsLocalProviderConfigEn localProviderConfig = _TranslationsSettingsLocalProviderConfigEn._(_root);
	late final _TranslationsSettingsLocalGgufEn localGguf = _TranslationsSettingsLocalGgufEn._(_root);
	late final _TranslationsSettingsPersonaDialogEn personaDialog = _TranslationsSettingsPersonaDialogEn._(_root);
	late final _TranslationsSettingsPersonasTabEn personasTab = _TranslationsSettingsPersonasTabEn._(_root);
	late final _TranslationsSettingsUpdateCheckEn updateCheck = _TranslationsSettingsUpdateCheckEn._(_root);
}

// Path: workspace
class _TranslationsWorkspaceEn {
	_TranslationsWorkspaceEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
}

// Path: character.promptPrefixDialog
class _TranslationsCharacterPromptPrefixDialogEn {
	_TranslationsCharacterPromptPrefixDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get styleKeywordsLabel => 'Style keywords';
	String get imageTitle => 'Image Style';
	String get imageDescription => 'Prepended to every image generation prompt for this character (e.g. "anime style, vibrant colors").';
	String get imageHint => 'anime style, vibrant colors';
	String get videoTitle => 'Video Style';
	String get videoDescription => 'Prepended to every video generation prompt for this character (e.g. "cinematic, shallow depth of field, 24fps film grain"). Video models respond to motion and camera vocabulary; keep it short.';
	String get videoHint => 'cinematic, shallow depth of field';
}

// Path: character.cardEditApproval
class _TranslationsCharacterCardEditApprovalEn {
	_TranslationsCharacterCardEditApprovalEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get denyAll => 'Deny all';
	String get approveAll => 'Approve all';
	String get confirm => 'Confirm';
	String get dialogTitle => 'Assistant proposed changes';
	String dontAskAgainFor({required Object modality}) => 'Don\'t ask again for ${modality}';
	late final _TranslationsCharacterCardEditApprovalModalityLabelEn modalityLabel = _TranslationsCharacterCardEditApprovalModalityLabelEn._(_root);
	late final _TranslationsCharacterCardEditApprovalModalityVerbEn modalityVerb = _TranslationsCharacterCardEditApprovalModalityVerbEn._(_root);
	String get tapToDeny => 'Tap to deny';
	String get tapToApprove => 'Tap to approve';
	String get reasonLabel => 'Reason (optional, sent back to the assistant)';
	String get newEntryTitle => 'New entry';
	String get removingTitle => 'Removing';
	String get beforeTitle => 'Before';
	String get afterTitle => 'After';
}

// Path: character.requireApprovalTile
class _TranslationsCharacterRequireApprovalTileEn {
	_TranslationsCharacterRequireApprovalTileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get edits => 'Require approval: edits';
	String get additions => 'Require approval: additions';
	String get deletions => 'Require approval: deletions';
}

// Path: character.loadingStatus
class _TranslationsCharacterLoadingStatusEn {
	_TranslationsCharacterLoadingStatusEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get initial => 'Loading...';
	String get copyingAssistant => 'Copying assistant...';
	String get scanningForCharacters => 'Scanning for characters...';
	String scanningForCharactersProgress({required Object current, required Object total}) => 'Scanning for characters...\n${current} / ${total}';
	String loadingCharactersProgress({required Object current, required Object total}) => 'Loading characters...\n${current} / ${total}';
}

// Path: character.savePathValidation
class _TranslationsCharacterSavePathValidationEn {
	_TranslationsCharacterSavePathValidationEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noLibraryFolder => 'No library folder configured.';
	String get mustBeInsideLibrary => 'Characters must be saved inside your library folder.';
}

// Path: character.createController
class _TranslationsCharacterCreateControllerEn {
	_TranslationsCharacterCreateControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get pngImagesTypeGroupLabel => 'PNG Images';
	String get invalidLocationTitle => 'Invalid Location';
	String get creationFailedTitle => 'Creation Failed';
	String get creationFailedMessage => 'Could not create the character. Check logs for details.';
}

// Path: character.importController
class _TranslationsCharacterImportControllerEn {
	_TranslationsCharacterImportControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String failedToImport({required Object fileName}) => 'Failed to import ${fileName}.';
	String importedCount({required Object count}) => 'Imported ${count} characters';
}

// Path: character.aiActionController
class _TranslationsCharacterAiActionControllerEn {
	_TranslationsCharacterAiActionControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get aiActionFailed => 'AI Action failed. Check logs for details.';
	String processingProgress({required Object name, required Object current, required Object total, required Object eta}) => 'Processing ${name} (${current}/${total})...${eta}';
	String etaHoursMinutes({required Object hours, required Object minutes}) => ' ETA: ${hours}h ${minutes}m';
	String etaMinutesSeconds({required Object minutes, required Object seconds}) => ' ETA: ${minutes}m ${seconds}s';
	String etaSeconds({required Object seconds}) => ' ETA: ${seconds}s';
	String processingField({required Object fieldName}) => 'Processing ${fieldName}...';
}

// Path: chat.tileAiProvider
class _TranslationsChatTileAiProviderEn {
	_TranslationsChatTileAiProviderEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get modelLabel => 'Model';
	String get invalidLabel => 'Invalid';
	String get chooseModelTitle => 'Choose a model';
}

// Path: chat.presetTile
class _TranslationsChatPresetTileEn {
	_TranslationsChatPresetTileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get tapToChoose => 'Tap to choose';
}

// Path: chat.tileImagePreset
class _TranslationsChatTileImagePresetEn {
	_TranslationsChatTileImagePresetEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get titleLabel => 'Image Model';
	String get chooseModelTitle => 'Choose an image model';
}

// Path: chat.tileVideoPreset
class _TranslationsChatTileVideoPresetEn {
	_TranslationsChatTileVideoPresetEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get titleLabel => 'Video Model';
	String get chooseModelTitle => 'Choose a video model';
}

// Path: chat.tileTtsPreset
class _TranslationsChatTileTtsPresetEn {
	_TranslationsChatTileTtsPresetEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get titleLabel => 'Speech Model';
	String get chooseModelTitle => 'Choose a speech model';
}

// Path: chat.tileImageAspectRatio
class _TranslationsChatTileImageAspectRatioEn {
	_TranslationsChatTileImageAspectRatioEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Image aspect ratio';
}

// Path: chat.tileVideoAspectRatio
class _TranslationsChatTileVideoAspectRatioEn {
	_TranslationsChatTileVideoAspectRatioEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Aspect ratio';
}

// Path: chat.tileVideoResolution
class _TranslationsChatTileVideoResolutionEn {
	_TranslationsChatTileVideoResolutionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Resolution';
}

// Path: chat.tileVideoDuration
class _TranslationsChatTileVideoDurationEn {
	_TranslationsChatTileVideoDurationEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Duration';
}

// Path: chat.tileTtsVoice
class _TranslationsChatTileTtsVoiceEn {
	_TranslationsChatTileTtsVoiceEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Voice';
}

// Path: chat.tileTtsLanguage
class _TranslationsChatTileTtsLanguageEn {
	_TranslationsChatTileTtsLanguageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Language';
}

// Path: chat.tileNsfw
class _TranslationsChatTileNsfwEn {
	_TranslationsChatTileNsfwEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'NSFW / Unlimited';
}

// Path: chat.tileScenario
class _TranslationsChatTileScenarioEn {
	_TranslationsChatTileScenarioEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Scenario';
}

// Path: chat.tileMaxResponseLength
class _TranslationsChatTileMaxResponseLengthEn {
	_TranslationsChatTileMaxResponseLengthEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String titleWithBucket({required Object bucket}) => 'Response length — ${bucket}';
	String sliderLabel({required Object bucket, required Object tokens}) => '${bucket} (${tokens} tokens)';
	String get bucketVeryShort => 'Very short';
	String get bucketShort => 'Short';
	String get bucketMedium => 'Medium';
	String get bucketLong => 'Long';
	String get bucketVeryLong => 'Very long';
}

// Path: chat.tileTrailingParagraph
class _TranslationsChatTileTrailingParagraphEn {
	_TranslationsChatTileTrailingParagraphEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Cut Trailing Text';
}

// Path: chat.tileReasoningEffort
class _TranslationsChatTileReasoningEffortEn {
	_TranslationsChatTileReasoningEffortEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String titleWithEffort({required Object effort}) => 'Reasoning — ${effort}';
	String get titleOff => 'Reasoning off';
	String get extraTokensCaption => 'Uses extra tokens beyond your max response length.';
}

// Path: chat.tileChatTheme
class _TranslationsChatTileChatThemeEn {
	_TranslationsChatTileChatThemeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Theme';
}

// Path: chat.tileRecalledMemory
class _TranslationsChatTileRecalledMemoryEn {
	_TranslationsChatTileRecalledMemoryEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get label => 'Show Recalled Memory';
}

// Path: chat.characterSwitcher
class _TranslationsChatCharacterSwitcherEn {
	_TranslationsChatCharacterSwitcherEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get favoritesTooltip => 'Favorites';
	String get recentChatsTooltip => 'Recent Chats';
	String get originalBadge => 'ORIGINAL';
	String get variantBadge => 'VARIANT';
	String lastActive({required Object timeAgo}) => 'Last active: ${timeAgo}';
	String get never => 'Never';
}

// Path: chat.freeImagePromptDialog
class _TranslationsChatFreeImagePromptDialogEn {
	_TranslationsChatFreeImagePromptDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Generate image';
	String get description => 'Describe what you want to see. A short phrase is fine — the model will expand it into a full tag list.';
	String get subjectLabel => 'Subject';
	String get subjectHint => 'cyberpunk alley, neon rain';
	String get generateButton => 'Generate';
}

// Path: chat.freeVideoPromptDialog
class _TranslationsChatFreeVideoPromptDialogEn {
	_TranslationsChatFreeVideoPromptDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Generate video';
	String get description => 'Describe a short moment of motion — what is moving, how, where. The system model will expand it into a cinematic T2V prompt.';
	String get subjectLabel => 'Subject';
	String get subjectHint => 'she walks through neon rain, slow motion';
	String get generateButton => 'Generate';
}

// Path: chat.imagePromptReviewDialog
class _TranslationsChatImagePromptReviewDialogEn {
	_TranslationsChatImagePromptReviewDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Review image prompt';
	String get description => 'Edit the prompt below before generating, or tap Generate to use it as-is.';
	String get fieldLabel => 'Image prompt';
	String get generateButton => 'Generate';
}

// Path: chat.videoPromptReviewDialog
class _TranslationsChatVideoPromptReviewDialogEn {
	_TranslationsChatVideoPromptReviewDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Review video prompt';
	String get description => 'Edit the prompt below before submitting, or tap Generate to use it as-is.';
	String get fieldLabel => 'Video prompt';
	String get generateButton => 'Generate';
}

// Path: chat.urlFetchReviewDialog
class _TranslationsChatUrlFetchReviewDialogEn {
	_TranslationsChatUrlFetchReviewDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Allow web fetch?';
	String get description => 'The character wants to read the contents of this URL.';
	String get purposeLabel => 'Purpose:';
	String get denyButton => 'Deny';
	String get allowButton => 'Allow';
}

// Path: chat.messageActionsRow
class _TranslationsChatMessageActionsRowEn {
	_TranslationsChatMessageActionsRowEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String tokenCountAbbrev({required Object count}) => '${count}t';
	String generationTimeAbbrev({required Object seconds}) => '${seconds}s';
	String get viewGenerationPromptTooltip => 'View generation prompt';
	String get messageActionsTooltip => 'Message actions';
	String get editAction => 'Edit';
	String get copyAction => 'Copy';
	String get shareImageAction => 'Share Image';
	String get setAsBackgroundAction => 'Set as Background';
	String get setAsCharacterImageAction => 'Set as Character Image';
	String get deleteAction => 'Delete';
	String get copiedToClipboard => 'Message copied to clipboard';
}

// Path: chat.ttsPlayButton
class _TranslationsChatTtsPlayButtonEn {
	_TranslationsChatTtsPlayButtonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get stopTooltip => 'Stop';
	String get readAloudTooltip => 'Read aloud';
	String get ttsFailed => 'TTS failed.';
}

// Path: chat.messageSwipeFlipper
class _TranslationsChatMessageSwipeFlipperEn {
	_TranslationsChatMessageSwipeFlipperEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get previousVersionTooltip => 'Previous version';
	String swipeCounter({required Object current, required Object total}) => '${current} / ${total}';
	String get regenerateTooltip => 'Regenerate';
	String get nextVersionTooltip => 'Next version';
}

// Path: chat.videoPlayerInline
class _TranslationsChatVideoPlayerInlineEn {
	_TranslationsChatVideoPlayerInlineEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get webUnsupported => 'Video playback not supported on web.';
	String get couldNotLoad => 'Could not load video.';
}

// Path: chat.chatListItem
class _TranslationsChatChatListItemEn {
	_TranslationsChatChatListItemEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String messageCount({required Object count}) => '${count} messages';
	String get renameAction => 'Rename';
	String get deleteChatAction => 'Delete Chat';
}

// Path: chat.chatHistoryController
class _TranslationsChatChatHistoryControllerEn {
	_TranslationsChatChatHistoryControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get renameChatTitle => 'Rename Chat';
	String get chatNameHint => 'Chat Name';
	String get renameButton => 'Rename';
	String get deleteChatTitle => 'Delete Chat';
	String get deleteChatMessage => 'Are you sure you want to delete this chat history? This action cannot be undone.';
}

// Path: chat.chatPageController
class _TranslationsChatChatPageControllerEn {
	_TranslationsChatChatPageControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get clearAssistantHistoryMessage => 'Clear the assistant chat history?';
	String get clearButton => 'Clear';
	String get deleteOrKeepMessage => 'Would you like to delete the current chat or keep it in your history?';
	String get deleteCurrentButton => 'Delete Current';
	String get keepCurrentButton => 'Keep Current';
}

// Path: chat.imageGenerationMixin
class _TranslationsChatImageGenerationMixinEn {
	_TranslationsChatImageGenerationMixinEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get enterPromptMessage => 'Enter a prompt to generate an image.';
	String get noCharacterMessage => 'No character available for image generation.';
	String get notConfiguredMessage => 'Image generation is not configured.';
	String get noSystemModelMessage => 'No system model is configured. Set one in Settings → AI.';
}

// Path: chat.videoGenerationMixin
class _TranslationsChatVideoGenerationMixinEn {
	_TranslationsChatVideoGenerationMixinEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get enterPromptMessage => 'Enter a prompt to generate a video.';
	String get noCharacterMessage => 'No character available for video generation.';
	String get notConfiguredMessage => 'Video generation is not configured.';
}

// Path: chat.bubbleWaitingFor
class _TranslationsChatBubbleWaitingForEn {
	_TranslationsChatBubbleWaitingForEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get thinking => 'Thinking…';
	String get preparingImagePrompt => 'Preparing image prompt…';
	String get preparingVideoPrompt => 'Preparing video prompt…';
	String get generatingImage => 'Generating image…';
	String get generatingVideo => 'Generating video…';
}

// Path: chat.appBarChat
class _TranslationsChatAppBarChatEn {
	_TranslationsChatAppBarChatEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get hideEditorPanelTooltip => 'Hide editor panel';
	String get showEditorSideBySideTooltip => 'Show editor side-by-side';
}

// Path: chat.allChatsDrawerList
class _TranslationsChatAllChatsDrawerListEn {
	_TranslationsChatAllChatsDrawerListEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get rebuildingIndex => 'Rebuilding index...';
	String get noChatsFound => 'No chats found.';
}

// Path: chat.chatInputMediaMenu
class _TranslationsChatChatInputMediaMenuEn {
	_TranslationsChatChatInputMediaMenuEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get generateMediaTooltip => 'Generate media';
	String get generateImageLabel => 'Generate image';
	String get generateVideoLabel => 'Generate video';
}

// Path: chat.chatView
class _TranslationsChatChatViewEn {
	_TranslationsChatChatViewEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get deleteMessageTitle => 'Delete Message';
	String get deleteMessageConfirmation => 'Are you sure you want to delete this message?';
	String get typeMessageHint => 'Type a message...';
	String get moreActionsTooltip => 'More actions';
	String get continueAction => 'Continue';
	String get impersonateAction => 'Impersonate';
	String get generateReplyAction => 'Generate Reply';
	String get improveMessageAction => 'Improve Message';
}

// Path: chat.chatMessageBubble
class _TranslationsChatChatMessageBubbleEn {
	_TranslationsChatChatMessageBubbleEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get imagesTypeGroupLabel => 'Images';
	String get assistantFallbackName => 'Assistant';
	String get reasoningLabel => 'Reasoning';
	String get sendingToProvider => 'Sending to provider…';
	String pollingWithPercent({required Object pct}) => 'Polling… ${pct}%';
	String get polling => 'Polling…';
	String get downloading => 'Downloading…';
}

// Path: common.actions
class _TranslationsCommonActionsEn {
	_TranslationsCommonActionsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get delete => 'Delete';
	String get ok => 'OK';
	String get cancel => 'Cancel';
	String get save => 'Save';
	String get tryAgain => 'Try Again';
	String get close => 'Close';
}

// Path: common.aiAction
class _TranslationsCommonAiActionEn {
	_TranslationsCommonAiActionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get proofread => 'Proofread';
	String get compact => 'Compact Prose';
	String get translate => 'Translate to English';
	String get generatePreview => 'Generate Preview';
	String get autoTag => 'Auto-Tag';
}

// Path: common.promptSegmentKind
class _TranslationsCommonPromptSegmentKindEn {
	_TranslationsCommonPromptSegmentKindEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get identity => 'Identity';
	String get systemPrompt => 'System prompt';
	String get nsfwMode => 'NSFW mode';
	String get scenarioMode => 'Scenario mode';
	String get description => 'Description';
	String get personality => 'Personality';
	String get scenario => 'Scenario';
	String get userPersona => 'Your persona';
	String get memory => 'Memory';
	String get situation => 'Situation';
	String get cardData => 'Card data';
	String get tools => 'Tools';
	String get postHistory => 'Post-history';
	String get depthPrompt => 'Depth prompt';
	String get worldInfo => 'World info';
	String get injected => 'Injected';
	String get exampleDialogue => 'Example dialogue';
	String get history => 'Message history';
	String get currentMessage => 'Current message';
	String get reservedReply => 'Reserved reply';
}

// Path: common.promptBreakdown
class _TranslationsCommonPromptBreakdownEn {
	_TranslationsCommonPromptBreakdownEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get free => 'Free';
}

// Path: common.logs
class _TranslationsCommonLogsEn {
	_TranslationsCommonLogsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Logs';
	String get filterTooltip => 'Filter Logs';
	String get clearTooltip => 'Clear Logs';
	String get exportTooltip => 'Export Logs';
	String get searchHint => 'Search logs...';
	String get noLogsFound => 'No logs found.';
	String get noLogsToExport => 'No logs to export';
	String get exportedSuccessfully => 'Logs exported successfully';
	String get exportFailed => 'Failed to export logs. See logs for details.';
	String get copiedToClipboard => 'Copied to clipboard';
	String get copyLogButton => 'Copy Log';
	String get copiedEntryToClipboard => 'Copied log entry to clipboard';
}

// Path: common.importErrorsDialog
class _TranslationsCommonImportErrorsDialogEn {
	_TranslationsCommonImportErrorsDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Import Errors';
	String get message => 'The following files could not be imported:';
}

// Path: common.updateDialog
class _TranslationsCommonUpdateDialogEn {
	_TranslationsCommonUpdateDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Version Available';
	String body({required Object appName, required Object currentVersion, required Object latestVersion}) => 'A newer version of ${appName} is available.\n\nCurrent version: ${currentVersion}\nLatest version: ${latestVersion}';
	String get releaseNotesLabel => 'Release Notes:';
	String get viewReleasesButton => 'View Releases';
}

// Path: common.importConflictsDialog
class _TranslationsCommonImportConflictsDialogEn {
	_TranslationsCommonImportConflictsDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Import Conflicts';
	String message({required Object count}) => 'The following ${count} characters have filename conflicts and will be renamed automatically:';
}

// Path: common.missingProviderBanner
class _TranslationsCommonMissingProviderBannerEn {
	_TranslationsCommonMissingProviderBannerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get message => 'Connect an AI provider.';
	String get setUpNowButton => 'Set Up Now';
}

// Path: common.modelSelectionDialog
class _TranslationsCommonModelSelectionDialogEn {
	_TranslationsCommonModelSelectionDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get searchHint => 'Search Models';
	String subscriptionOnlyToggle({required Object included, required Object total}) => 'Show only subscription models (${included}/${total})';
}

// Path: common.showAdvanced
class _TranslationsCommonShowAdvancedEn {
	_TranslationsCommonShowAdvancedEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get less => 'Less';
	String get more => 'More';
}

// Path: common.messageEditDialog
class _TranslationsCommonMessageEditDialogEn {
	_TranslationsCommonMessageEditDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Edit Message';
}

// Path: common.promptBreakdownDialog
class _TranslationsCommonPromptBreakdownDialogEn {
	_TranslationsCommonPromptBreakdownDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Prompt Breakdown';
	String get breakdownTab => 'Breakdown';
	String get contentTab => 'Content';
	String get promptTotalEstimated => 'Prompt total (estimated)';
	String get promptTotalProvider => 'Prompt total (provider)';
	String get contextWindowLabel => 'Context window';
	String get categoryHeader => 'CATEGORY';
	String get tokensHeader => 'TOKENS';
	String get usageHeader => 'USAGE';
	String get noContentToInspect => 'No content to inspect for this reply.';
	String get estimatedSuffix => ' (estimated)';
	String usedSummary({required Object used, required Object total}) => '${used} / ${total} used';
}

// Path: common.jsonPromptDialog
class _TranslationsCommonJsonPromptDialogEn {
	_TranslationsCommonJsonPromptDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Generation Prompt';
}

// Path: common.progressDialog
class _TranslationsCommonProgressDialogEn {
	_TranslationsCommonProgressDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get defaultMessage => 'Sending...';
	String get finished => 'Finished!';
}

// Path: common.diffPanel
class _TranslationsCommonDiffPanelEn {
	_TranslationsCommonDiffPanelEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String tokenSuffix({required Object count}) => ' (${count} Tokens)';
}

// Path: common.selectionDialog
class _TranslationsCommonSelectionDialogEn {
	_TranslationsCommonSelectionDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get searchHint => 'Search…';
}

// Path: common.zdrSwitch
class _TranslationsCommonZdrSwitchEn {
	_TranslationsCommonZdrSwitchEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Require Zero Data Retention (ZDR)';
	String get subtitle => 'Only show OR models with ZDR-compliant endpoints. Enable this if your openrouter.ai account restricts to ZDR providers.';
}

// Path: common.textFieldCard
class _TranslationsCommonTextFieldCardEn {
	_TranslationsCommonTextFieldCardEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String labelWithTokenCount({required Object label, required Object count}) => '${label} - ${count} tokens';
	String tokenCountAbbrev({required Object count}) => '${count} t';
}

// Path: common.modelCapability
class _TranslationsCommonModelCapabilityEn {
	_TranslationsCommonModelCapabilityEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get reasoning => 'Reasoning';
	String get vision => 'Vision';
	String get tools => 'Tools';
	String get json => 'JSON';
	String get files => 'Files';
	String get image => 'Image';
	String get video => 'Video';
	String get speech => 'Speech';
	String get music => 'Music';
}

// Path: common.appConstants
class _TranslationsCommonAppConstantsEn {
	_TranslationsCommonAppConstantsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get maxImageFileSizeLabel => '10 MB';
	String get exportFailedMessage => 'Export failed. See logs for details.';
}

// Path: editor.panelLabels
class _TranslationsEditorPanelLabelsEn {
	_TranslationsEditorPanelLabelsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get basic => 'Basic';
	String get greetings => 'Greetings';
	String get prompts => 'Prompts';
	String get lorebook => 'Lorebook';
	String get group => 'Group';
	String get creator => 'Creator';
	String get appData => 'App Data';
	String get nodes => 'Nodes';
}

// Path: editor.appBarEditor
class _TranslationsEditorAppBarEditorEn {
	_TranslationsEditorAppBarEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get hideAssistantPanelTooltip => 'Hide assistant panel';
	String get showChatAssistantTooltip => 'Show chat assistant side-by-side';
}

// Path: editor.codeFindPanel
class _TranslationsEditorCodeFindPanelEn {
	_TranslationsEditorCodeFindPanelEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noneResult => 'none';
	String get previousTooltip => 'Previous';
	String get nextTooltip => 'Next';
	String get closeTooltip => 'Close';
	String get replaceTooltip => 'Replace';
	String get replaceAllTooltip => 'Replace All';
}

// Path: editor.findReplaceDialog
class _TranslationsEditorFindReplaceDialogEn {
	_TranslationsEditorFindReplaceDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get confirmReplaceAllTitle => 'Confirm Replace All';
	String get confirmReplaceAllMessage => 'Are you sure you want to proceed?\nThis action is irreversible and affects all fields.';
	String get proceedButton => 'Proceed';
	String get title => 'Find & Replace';
	String get findLabel => 'Find';
	String get replaceWithLabel => 'Replace with';
	String get replaceAllButton => 'Replace All';
}

// Path: editor.objectValueEditor
class _TranslationsEditorObjectValueEditorEn {
	_TranslationsEditorObjectValueEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get stringType => 'string';
	String get numberType => 'number';
	String get boolType => 'bool';
}

// Path: editor.editorBasic
class _TranslationsEditorEditorBasicEn {
	_TranslationsEditorEditorBasicEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get nameLabel => 'Name';
	String get nicknameLabel => 'Nickname (CCv3)';
	String get descriptionLabel => 'Description';
	String get personalityLabel => 'Personality';
	String get scenarioLabel => 'Scenario';
	String get messageExampleLabel => 'Message Example';
}

// Path: editor.editorCreatorMetadata
class _TranslationsEditorEditorCreatorMetadataEn {
	_TranslationsEditorEditorCreatorMetadataEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get systemNameLabel => 'System Name (CCv3)';
	String get creatorLabel => 'Creator';
	String get versionLabel => 'Version';
	String get creatorNotesLabel => 'Creator Notes';
	String get tagsLabel => 'Tags (Coma separated)';
}

// Path: editor.editorPrompts
class _TranslationsEditorEditorPromptsEn {
	_TranslationsEditorEditorPromptsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get systemPromptLabel => 'System Prompt';
	String get postHistoryInstructionsLabel => 'Post History Instructions';
	String get depthPromptLabel => 'Depth Prompt (Character Notes)';
	String get insertionDepthLabel => 'Insertion Depth';
	String get roleLabel => 'Role';
}

// Path: editor.editorAppData
class _TranslationsEditorEditorAppDataEn {
	_TranslationsEditorEditorAppDataEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get variantNotesLabel => 'Variant Notes';
	String get descriptionPreviewLabel => 'Description Preview';
}

// Path: editor.editorAlternateGreetings
class _TranslationsEditorEditorAlternateGreetingsEn {
	_TranslationsEditorEditorAlternateGreetingsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get deleteGreetingTitle => 'Delete Greeting';
	String get deleteGreetingMessage => 'Are you sure you want to delete this greeting?';
	String get addGreetingButton => 'Add Greeting';
	String get primaryGreetingLabel => 'Primary Greeting (first_mes)';
	String alternateGreetingLabel({required Object index}) => 'Alternate Greeting #${index}';
	String get removeTooltip => 'Remove';
}

// Path: editor.editorGroupGreetings
class _TranslationsEditorEditorGroupGreetingsEn {
	_TranslationsEditorEditorGroupGreetingsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String greetingLabel({required Object index}) => 'Greeting ${index}';
}

// Path: editor.editorLorebook
class _TranslationsEditorEditorLorebookEn {
	_TranslationsEditorEditorLorebookEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get newEntryDefaultComment => 'New Entry';
	String get deleteEntryTitle => 'Delete Entry';
	String get deleteEntryMessage => 'Are you sure you want to delete this entry?';
	String get addNewEntryButton => 'Add New Entry';
	String get noEntriesFound => 'No lorebook entries found.';
}

// Path: editor.lorebookEntryListTile
class _TranslationsEditorLorebookEntryListTileEn {
	_TranslationsEditorLorebookEntryListTileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get untitledEntry => 'Untitled Entry';
	String get noKeywords => 'No keywords';
}

// Path: editor.lorebookEntryEditorPage
class _TranslationsEditorLorebookEntryEditorPageEn {
	_TranslationsEditorLorebookEntryEditorPageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get editEntryTitle => 'Edit Lorebook Entry';
	String get advancedFilter => 'Advanced';
	String get primaryKeywordsLabel => 'Primary Keywords';
	String get logicLabel => 'Logic';
	String get logicAndAny => 'AND ANY';
	String get logicAndAll => 'AND ALL';
	String get logicNotAny => 'NOT ANY';
	String get logicNotAll => 'NOT ALL';
	String get optionalFilterLabel => 'Optional Filter';
	String get contentLabel => 'Content';
	String get nonRecursableFilter => 'Non-recursable';
	String get preventFurtherRecursionFilter => 'Prevent Further Recursion';
	String get delayUntilRecursionFilter => 'Delay Until Recursion';
	String get ignoreBudgetFilter => 'Ignore Budget';
	String get prioritizeFilter => 'Prioritize';
	String get inclusionGroupLabel => 'Inclusion Group';
	String get groupWeightLabel => 'Group Weight';
	String get stickyLabel => 'Sticky';
	String get cooldownLabel => 'Cooldown';
	String get delayLabel => 'Delay';
	String get filterToCharactersLabel => 'Filter to Characters or Tags';
	String get filterToTriggersLabel => 'Filter to Generation Triggers';
	String get additionalMatchingSourcesLabel => 'Additional Matching Sources:';
	String get personaFilter => 'Persona';
	String get descriptionFilter => 'Description';
	String get personalityFilter => 'Personality';
	String get depthPromptFilter => 'Depth Prompt';
	String get scenarioFilter => 'Scenario';
	String get creatorNotesFilter => 'Creator Notes';
}

// Path: editor.lorebookEntryEditorTopSection
class _TranslationsEditorLorebookEntryEditorTopSectionEn {
	_TranslationsEditorLorebookEntryEditorTopSectionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get titleMemoLabel => 'Title/Memo';
	String get strategyLabel => 'Strategy';
	String get strategyConstant => 'Constant';
	String get strategyEnabled => 'Enabled';
	String get strategyDisabled => 'Disabled';
	String get strategyVectorized => 'Vectorized';
	String get positionLabel => 'Position';
	String get positionUpChar => '↑ Char';
	String get positionDownChar => '↓ Char';
	String get positionUpAn => '↑ AN';
	String get positionDownAn => '↓ AN';
	String get positionDepthSystem => '@D System';
	String get positionDepthUser => '@D User';
	String get positionDepthAssistant => '@D Assistant';
	String get positionUpEm => '↑ EM';
	String get positionDownEm => '↓ EM';
	String get positionOutlet => 'Outlet';
	String get depthLabel => 'Depth';
	String get orderLabel => 'Order';
	String get triggerLabel => 'Trigger %';
}

// Path: editor.lorebookEntryEditorScanRow
class _TranslationsEditorLorebookEntryEditorScanRowEn {
	_TranslationsEditorLorebookEntryEditorScanRowEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get scanDepthLabel => 'Scan Depth';
	String get automationIdLabel => 'Automation ID';
	String get useRegexFilter => 'Use Regex';
	String get caseSensitiveFilter => 'Case Sensitive';
	String get wholeWordsFilter => 'Whole Words';
	String get groupScoringFilter => 'Group Scoring';
}

// Path: editor.dialogContentCleaner
class _TranslationsEditorDialogContentCleanerEn {
	_TranslationsEditorDialogContentCleanerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String confirmActionTitle({required Object actionName}) => 'Confirm ${actionName}';
	String get title => 'Content Cleaner';
	String get normalizeFancyCharsAction => 'Normalize Fancy Chars';
	String get normalizeFancyCharsButton => 'Normalize Fancy Chars (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
	String get purgeHtmlAction => 'Purge HTML';
	String get purgeHtmlButton => 'Purge HTML Tags';
	String get purgeMarkdownAction => 'Purge Markdown Links/Images';
	String get purgeEmojisAction => 'Purge Emojis';
	String get purgeExtraSpacesAction => 'Purge Extra Spaces';
	String get yoloPurgeAction => 'Yolo Purge';
	String get applyAllAboveButton => 'Apply All Above';
}

// Path: editor.dialogAiDiffConfirmation
class _TranslationsEditorDialogAiDiffConfirmationEn {
	_TranslationsEditorDialogAiDiffConfirmationEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get applyChangesButton => 'Apply Changes';
	String get originalTextTitle => 'Original Text';
	String get suggestedTextTitle => 'Suggested Text';
}

// Path: editor.editorPageController
class _TranslationsEditorEditorPageControllerEn {
	_TranslationsEditorEditorPageControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String globalActionTitle({required Object action}) => 'Global ${action}';
	String get globalAiActionFailed => 'Global AI action failed. Check logs.';
	String compositeName({required Object value}) => 'Name:\n${value}\n';
	String compositeDescription({required Object value}) => 'Description:\n${value}\n';
	String compositePersonality({required Object value}) => 'Personality:\n${value}\n';
	String compositeScenario({required Object value}) => 'Scenario:\n${value}\n';
	String compositeFirstMessage({required Object value}) => 'First Message:\n${value}\n';
	String compositeMessageExample({required Object value}) => 'Message Example:\n${value}\n';
	String compositeCreatorNotes({required Object value}) => 'Creator Notes:\n${value}\n';
	String compositeSystemPrompt({required Object value}) => 'System Prompt:\n${value}\n';
	String compositePostHistoryInstructions({required Object value}) => 'Post-History Instructions:\n${value}\n';
	String compositeAlternateGreeting({required Object index, required Object value}) => 'Alternate Greeting #${index}:\n${value}\n';
	String compositeGroupGreeting({required Object index, required Object value}) => 'Group Greeting #${index}:\n${value}\n';
	String compositeLorebookEntry({required Object index, required Object value}) => 'Lorebook Entry #${index}:\n${value}\n';
	String imageTooLargeMessage({required Object maxSize}) => 'Selected image is too large. Maximum size is ${maxSize}.';
	String get invalidPngMessage => 'Selected image is not a valid PNG or could not be read.';
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

// Path: llmApp.mediaField
class _TranslationsLlmAppMediaFieldEn {
	_TranslationsLlmAppMediaFieldEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get imageModel => 'Image model';
	String get imageAspectRatio => 'Image aspect ratio';
	String get imageNsfwAllowed => 'Image NSFW allowed';
	String get imageToolSelfieAllowed => 'Can send selfies';
	String get imageToolSelfieCaptionsAllowed => 'Allow selfie captions';
	String get imagePromptPrefix => 'Image style';
	String get videoModel => 'Video model';
	String get videoResolution => 'Video resolution';
	String get videoAspectRatio => 'Video aspect ratio';
	String get videoDuration => 'Video duration';
	String get videoNsfwAllowed => 'Video NSFW allowed';
	String get videoToolSendAllowed => 'Can send videos';
	String get videoPromptPrefix => 'Video style';
	String get ttsModel => 'TTS model';
	String get ttsVoice => 'TTS voice';
	String get ttsLanguage => 'TTS language';
	String get webToolFetchAllowed => 'Allow web fetch';
	String get nameToolSuggestAllowed => 'Can suggest NPC names';
}

// Path: llmApp.mediaSection
class _TranslationsLlmAppMediaSectionEn {
	_TranslationsLlmAppMediaSectionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get image => 'Image';
	String get video => 'Video';
	String get tts => 'TTS';
	String get web => 'Web';
	String get names => 'Names';
}

// Path: llmApp.tristate
class _TranslationsLlmAppTristateEn {
	_TranslationsLlmAppTristateEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get on => 'On';
	String get off => 'Off';
	String get inherit => 'Inherit';
}

// Path: llmApp.mediaCellMenu
class _TranslationsLlmAppMediaCellMenuEn {
	_TranslationsLlmAppMediaCellMenuEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get change => 'Change…';
	String get clear => 'Clear';
}

// Path: llmApp.mediaHeader
class _TranslationsLlmAppMediaHeaderEn {
	_TranslationsLlmAppMediaHeaderEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get appDefault => 'App default';
	String get character => 'Character';
	String get currentChat => 'Current chat';
	String get previousLayerTooltip => 'Previous layer';
	String get nextLayerTooltip => 'Next layer';
}

// Path: llmApp.presetRow
class _TranslationsLlmAppPresetRowEn {
	_TranslationsLlmAppPresetRowEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get changeAppDefaultTitle => 'Change app default?';
	String get changeAppDefaultMessage => 'This affects every chat. Continue?';
	String get continueButton => 'Continue';
	String chooseModelTitle({required Object domain}) => 'Choose a ${domain} model';
}

// Path: llmApp.mediaCell
class _TranslationsLlmAppMediaCellEn {
	_TranslationsLlmAppMediaCellEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get notApplicable => 'Not applicable';
}

// Path: onboarding.storageStep
class _TranslationsOnboardingStorageStepEn {
	_TranslationsOnboardingStorageStepEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Character Storage';
	String get subtitle => 'Where should we save your character cards?';
	String get description => 'Saved in the app folder by default. Point to an existing PNG folder to import.';
	String get startFresh => 'Start fresh';
	String get haveCards => 'I already have cards';
	String get importLaterHint => 'Import PNGs later via File → Import.';
	String selectedPath({required Object path}) => 'Selected: ${path}';
	String get selectedDefaultFolder => 'Selected: Default app folder';
	String get noFolderSelected => 'No folder selected yet.';
}

// Path: onboarding.setupStep
class _TranslationsOnboardingSetupStepEn {
	_TranslationsOnboardingSetupStepEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'AI & Persona';
}

// Path: onboarding.aiSection
class _TranslationsOnboardingAiSectionEn {
	_TranslationsOnboardingAiSectionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get heading => 'AI Connection';
	String get optionalHint => 'Optional — skip and add a key later in Settings (local providers can be added there too).';
	String get apiKeyLabel => 'API Key';
	String get apiKeyHint => 'Paste your key (or skip for now)';
	String get supportedProviders => 'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. More in Settings.';
	String get unknownModel => '(unknown model)';
	String get ctxUnknown => 'ctx —';
	String ctxValue({required Object ctx}) => 'ctx ${ctx}';
	String kvSuffix({required Object kv}) => ' · KV ${kv}';
	String get changeButton => 'Change';
}

// Path: onboarding.aiStatus
class _TranslationsOnboardingAiStatusEn {
	_TranslationsOnboardingAiStatusEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get connecting => 'Connecting…';
	String connected({required Object provider}) => 'Connected to ${provider}. Default chat model selected.';
	String detected({required Object provider}) => 'Detected: ${provider}';
	String get unrecognizedKey => 'Unrecognized key format.';
}

// Path: onboarding.personaSection
class _TranslationsOnboardingPersonaSectionEn {
	_TranslationsOnboardingPersonaSectionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get heading => 'Your Persona';
	String get hint => 'Your name in chats. More persona details in Settings.';
	String get nameLabel => 'Your name';
}

// Path: onboarding.disclaimer
class _TranslationsOnboardingDisclaimerEn {
	_TranslationsOnboardingDisclaimerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get prefix => 'I have read and agree to the ';
	String get linkText => 'Disclaimer';
}

// Path: onboarding.fetchError
class _TranslationsOnboardingFetchErrorEn {
	_TranslationsOnboardingFetchErrorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noModels => 'No models returned. Check your API key.';
	String get connectionFailed => 'Could not connect. Check your internet connection and API key.';
}

// Path: routing.chatCharacter
class _TranslationsRoutingChatCharacterEn {
	_TranslationsRoutingChatCharacterEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String navigationError({required Object name}) => 'Navigation error to chat. Character: ${name}';
}

// Path: routing.editCharacter
class _TranslationsRoutingEditCharacterEn {
	_TranslationsRoutingEditCharacterEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String navigationError({required Object name}) => 'Navigation error to edit. Character: ${name}';
}

// Path: routing.editPreset
class _TranslationsRoutingEditPresetEn {
	_TranslationsRoutingEditPresetEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String navigationError({required Object presetId}) => 'Navigation error to edit preset: ${presetId}';
}

// Path: settings.gearMenu
class _TranslationsSettingsGearMenuEn {
	_TranslationsSettingsGearMenuEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get settingsTooltip => 'Settings';
	String get mediaDefaultsApp => 'App';
	String get mediaDefaultsCharacter => 'Character';
	String get mediaDefaultsChat => 'Chat';
	String get appSettings => 'App Settings';
	String get logs => 'Logs';
}

// Path: settings.mediaDefaultsDrawerEntry
class _TranslationsSettingsMediaDefaultsDrawerEntryEn {
	_TranslationsSettingsMediaDefaultsDrawerEntryEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get configurationHeader => 'Configuration';
}

// Path: settings.endDrawer
class _TranslationsSettingsEndDrawerEn {
	_TranslationsSettingsEndDrawerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get switchPersonaTooltip => 'Switch persona';
}

// Path: settings.general
class _TranslationsSettingsGeneralEn {
	_TranslationsSettingsGeneralEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get characterFolderTitle => 'Character Folder';
	String get characterFolderNotSet => 'Not set. Required for the app to function.';
	String get browseButton => 'Browse...';
	String get taxonomyTagsTitle => 'Taxonomy Tags';
	String get appThemeTitle => 'App Theme';
	String get themeSystem => 'System';
	String get themeLight => 'Light';
	String get themeDark => 'Dark';
	String get themeStyleTitle => 'Theme Style';
	String get themeStyleDefault => 'Default';
	String get themeStyleNeon => 'Neon';
	String get storyMemoryTitle => 'Story Memory';
	String get storyMemorySubtitle => 'Remember earlier moments and bring the relevant ones back into long chats.';
	String get narrativeEngineTitle => 'Narrative Engine';
	String get narrativeEngineSubtitle => 'Track the scene and characters and move the story along as you chat.';
	String get promptBreakdownTitle => 'Show Prompt Breakdown';
	String get promptBreakdownSubtitle => 'Show a bar under each reply breaking down how the prompt filled the model context window.';
	String get checkUpdatesTitle => 'Check for Updates';
	String get checkUpdatesSubtitle => 'Check if a newer version of the app is available.';
	String get websiteTitle => 'Website';
	String get websiteSubtitle => 'Visit the official website for updates and information.';
	String get disclaimerTitle => 'Disclaimer & Terms';
	String get disclaimerSubtitle => 'Read the application disclaimer and terms of use.';
	String versionLabel({required Object version, required Object buildNumber}) => 'Version ${version}+${buildNumber}';
}

// Path: settings.aiSettingsTab
class _TranslationsSettingsAiSettingsTabEn {
	_TranslationsSettingsAiSettingsTabEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get aiProviders => 'AI Providers';
	String get mediaDefaults => 'Media Defaults';
}

// Path: settings.aiTab
class _TranslationsSettingsAiTabEn {
	_TranslationsSettingsAiTabEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String refreshSummary({required Object updated, required Object unavailable, required Object errors}) => 'Refreshed ${updated} models, ${unavailable} unavailable, ${errors} errors.';
	String get newProviderButton => 'New Provider';
	String get cloudProviderMenuItem => 'Cloud Provider';
	String get localProviderMenuItem => 'Local Provider';
	String get localGgufMenuItem => 'Local GGUF';
	String get noProvidersConfigured => 'No API providers configured.';
	String get addingProviderOverlay => 'Adding provider…';
	String get neverRefreshed => 'Never refreshed';
	String lastRefreshedLabel({required Object time}) => 'Last refreshed: ${time}';
	String get refreshModelsButton => 'Refresh models';
	String get refreshNowMenuItem => 'Refresh now';
	String get autoNeverMenuItem => 'Auto: Never';
	String get autoDailyMenuItem => 'Auto: Daily on startup';
	String get defaultModelsHeader => 'Default Models for New Chats';
	String get editModelTooltip => 'Edit Model';
	String get noModelsPlaceholder => 'No Models';
	String get noCompatibleModelsPlaceholder => 'No compatible models';
	String get tapToChoosePlaceholder => 'Tap to choose';
	String get modelUsedForPrefix => 'Model used for ';
	String get modelUsedForSuffix => ' generation';
	String get chooseModelTitle => 'Choose a Model';
	String temperatureLabel({required Object value}) => 'Temp ${value}';
	String get setDefaultButton => 'Set default';
	String get addModelButton => 'Add Model';
	String get editProviderMenuItem => 'Edit provider';
	String get moreTooltip => 'More';
	String get noModelsForProvider => 'No Models configured for this provider.';
	String setDefaultConfirmTitle({required Object provider}) => 'Set ${provider} as the default for every AI feature?';
	String get setDefaultConfirmMessage => 'You may pick models for unsupported features\n(like image or video) from other providers yourself.';
	String localGgufSubtitle({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (max ${native}) · KV ${kv}';
	String get testTtsTooltip => 'Test TTS';
	String get ttsTestPhrase => 'Hello, this is a test.';
	String get ttsFailedError => 'TTS failed.';
	String get testVideoTooltip => 'Test video generation';
	String get videoGeneratedWebFallback => 'Video generated successfully (preview unavailable on web).';
	String get videoFailedError => 'Video failed.';
	String get videoLoadFailedMessage => 'Could not load generated video.';
	String get presetPickerSearchHint => 'Search by provider, model, or preset…';
	String tempParamAbbrev({required Object value}) => 'temp ${value}';
	String reasoningParamLabel({required Object level}) => 'reasoning ${level}';
}

// Path: settings.presetConfig
class _TranslationsSettingsPresetConfigEn {
	_TranslationsSettingsPresetConfigEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get testMessageButton => 'Test Message';
	String get testSuccessLabel => 'Success';
	String get testFailedLabel => 'Failed';
	String get deleteModelTitle => 'Delete Model?';
	String deleteModelMessage({required Object name}) => 'Permanently delete "${name}"? This cannot be undone.';
	String get editModelHeader => 'Edit Model';
	String get addModelHeader => 'Add Model';
	String get resetToDefaultsTooltip => 'Reset to Defaults';
	String get modelNameLabel => 'Model name';
	String get clearTooltip => 'Clear';
	String get nameRequiredError => 'Name is required';
	String get modelLabel => 'Model';
	String get selectModelHint => 'Select a model';
	String get modelRequiredError => 'Model is required';
	String filteredDomainsNote({required Object domains}) => 'Models are filtered to support the active domains: ${domains}';
	String get requiredValidator => 'Required';
	String get invalidValidator => 'Invalid';
	String get testResponseTitle => 'Response';
}

// Path: settings.providerConfig
class _TranslationsSettingsProviderConfigEn {
	_TranslationsSettingsProviderConfigEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noModelsError => 'No models returned. Check your API key.';
	String get connectionFailedError => 'Could not connect. Check your internet connection and API key.';
	String get deleteProviderTitle => 'Delete provider?';
	String deleteProviderMessage({required Object provider}) => 'Permanently delete the ${provider} provider and all its presets? This cannot be undone.';
	String lockHint({required Object roles}) => 'Cannot delete: in use by ${roles}.';
	String get editProviderHeader => 'Edit Provider';
	String get addProviderHeader => 'Add Provider';
	String get apiKeyLabel => 'API Key';
	String get apiKeyHintRotate => 'Paste a new key to rotate';
	String get apiKeyHintNew => 'Paste your key — provider is auto-detected';
	String get supportedProvidersNote => 'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
	String keyMismatchError({required Object owner, required Object profile}) => 'This key belongs to ${owner}, but this profile is ${profile}. Delete this profile and add a new one instead.';
	String get anotherProviderFallback => 'another provider';
	String get connectingStatus => 'Connecting…';
	String connectedStatus({required Object provider}) => 'Connected to ${provider}. Default presets will be created.';
	String detectedStatus({required Object provider}) => 'Detected: ${provider}';
	String get unrecognizedKeyStatus => 'Unrecognized key format.';
}

// Path: settings.localProviderConfig
class _TranslationsSettingsLocalProviderConfigEn {
	_TranslationsSettingsLocalProviderConfigEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String serverUnreachableMessage({required Object url}) => 'Could not reach ${url}. Make sure your local server (KoboldCpp / Ollama / LM Studio / llama.cpp) is running.';
	String get noModelsError => 'Server reachable but returned no models. Load a model in your local server first.';
	String get deleteProviderMessage => 'Permanently delete this Local provider and all its presets? This cannot be undone.';
	String get editHeader => 'Edit Local Provider';
	String get addHeader => 'Add Local Provider';
	String get serverUrlLabel => 'Server URL';
	String get serverUrlLockedHelper => 'Locked. Delete this provider and add a new one to point at a different server.';
	String get apiKeyOptionalLabel => 'API Key (optional)';
	String get apiKeyOptionalHint => 'Leave blank — most local servers don\'t need one';
	String get connectFetchButton => 'Connect & Fetch Models';
	String connectedFoundModels({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Connected. Found ${n} model.',
		other: 'Connected. Found ${n} models.',
	);
}

// Path: settings.localGguf
class _TranslationsSettingsLocalGgufEn {
	_TranslationsSettingsLocalGgufEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get haveLocalGgufExpanderTitle => 'I have a local GGUF file';
	String get pickFileLabel => 'Pick GGUF file...';
	String get loadModelLabel => 'Load model';
	String get nativeContextLabel => 'Native context';
	String get freeVramLabel => 'Free VRAM';
	String get contextSizeLabel => 'Context size';
	String get kvCacheLabel => 'KV cache';
	String get kvCacheAutoLabel => 'Auto';
	String modelTooLargeForVramMessage({required Object neededMb, required Object freeMb}) => 'This model needs about ${neededMb}MB of GPU memory but only ${freeMb}MB is free. Close other GPU apps or pick a smaller / more-quantized model.';
	String modelBarelyFitsMessage({required Object minimumContext}) => 'This model barely fits even with q4_0 KV cache at ${minimumContext} tokens. Consider a more-aggressively-quantized model file.';
	String get readingMetadata => 'Reading model metadata…';
	String get architectureLabel => 'Architecture';
	String autoKvHint({required Object picked, required Object max}) => 'auto: ${picked} (max ${max})';
	String maxKvHint({required Object max, required Object picked}) => 'max ${max} at ${picked} KV';
	String ctxExceedsMaxError({required Object max, required Object picked}) => 'over ${max} at ${picked} KV — load may OOM';
	String get vramNotDetected => 'not detected';
	String readMetadataFailedError({required Object error}) => 'Failed to read GGUF metadata: ${error}';
	String loadModelFailedError({required Object error}) => 'Failed to load the model: ${error}';
}

// Path: settings.personaDialog
class _TranslationsSettingsPersonaDialogEn {
	_TranslationsSettingsPersonaDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get newTitle => 'New Persona';
	String get editTitle => 'Edit Persona';
	String get nameLabel => 'Name';
	String get nameRequiredError => 'Name is required';
	String get descriptionLabel => 'Description';
	String get descriptionHint => 'Appearance, personality, background, etc.';
}

// Path: settings.personasTab
class _TranslationsSettingsPersonasTabEn {
	_TranslationsSettingsPersonasTabEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get cannotDeleteDefaultTooltip => 'Cannot delete default persona';
	String get deleteTooltip => 'Delete Persona';
	String get cannotDeleteDefaultSnackbar => 'Cannot delete the default persona.';
	String get deleteConfirmTitle => 'Delete Persona';
	String deleteConfirmMessage({required Object name}) => 'Are you sure you want to delete "${name}"?';
}

// Path: settings.updateCheck
class _TranslationsSettingsUpdateCheckEn {
	_TranslationsSettingsUpdateCheckEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get upToDateTitle => 'Up to Date';
	String upToDateMessage({required Object version}) => 'You are on the current version (${version}).';
	String get notApplicableTitle => 'Update Check';
	String get notApplicableMessage => 'Version check is not applicable on the Web.';
	String get errorTitle => 'Error';
	String get serverErrorMessage => 'Could not check for updates. Server error.';
	String get connectionErrorMessage => 'Could not check for updates. Check your connection.';
}

// Path: character.cardEditApproval.modalityLabel
class _TranslationsCharacterCardEditApprovalModalityLabelEn {
	_TranslationsCharacterCardEditApprovalModalityLabelEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get edits => 'edits';
	String get additions => 'additions';
	String get deletions => 'deletions';
}

// Path: character.cardEditApproval.modalityVerb
class _TranslationsCharacterCardEditApprovalModalityVerbEn {
	_TranslationsCharacterCardEditApprovalModalityVerbEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get edit => 'Edit';
	String get addition => 'Add to';
	String get deletion => 'Remove from';
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
			case 'character.promptPrefixDialog.styleKeywordsLabel': return 'Style keywords';
			case 'character.promptPrefixDialog.imageTitle': return 'Image Style';
			case 'character.promptPrefixDialog.imageDescription': return 'Prepended to every image generation prompt for this character (e.g. "anime style, vibrant colors").';
			case 'character.promptPrefixDialog.imageHint': return 'anime style, vibrant colors';
			case 'character.promptPrefixDialog.videoTitle': return 'Video Style';
			case 'character.promptPrefixDialog.videoDescription': return 'Prepended to every video generation prompt for this character (e.g. "cinematic, shallow depth of field, 24fps film grain"). Video models respond to motion and camera vocabulary; keep it short.';
			case 'character.promptPrefixDialog.videoHint': return 'cinematic, shallow depth of field';
			case 'character.cardEditApproval.denyAll': return 'Deny all';
			case 'character.cardEditApproval.approveAll': return 'Approve all';
			case 'character.cardEditApproval.confirm': return 'Confirm';
			case 'character.cardEditApproval.dialogTitle': return 'Assistant proposed changes';
			case 'character.cardEditApproval.dontAskAgainFor': return ({required Object modality}) => 'Don\'t ask again for ${modality}';
			case 'character.cardEditApproval.modalityLabel.edits': return 'edits';
			case 'character.cardEditApproval.modalityLabel.additions': return 'additions';
			case 'character.cardEditApproval.modalityLabel.deletions': return 'deletions';
			case 'character.cardEditApproval.modalityVerb.edit': return 'Edit';
			case 'character.cardEditApproval.modalityVerb.addition': return 'Add to';
			case 'character.cardEditApproval.modalityVerb.deletion': return 'Remove from';
			case 'character.cardEditApproval.tapToDeny': return 'Tap to deny';
			case 'character.cardEditApproval.tapToApprove': return 'Tap to approve';
			case 'character.cardEditApproval.reasonLabel': return 'Reason (optional, sent back to the assistant)';
			case 'character.cardEditApproval.newEntryTitle': return 'New entry';
			case 'character.cardEditApproval.removingTitle': return 'Removing';
			case 'character.cardEditApproval.beforeTitle': return 'Before';
			case 'character.cardEditApproval.afterTitle': return 'After';
			case 'character.requireApprovalTile.edits': return 'Require approval: edits';
			case 'character.requireApprovalTile.additions': return 'Require approval: additions';
			case 'character.requireApprovalTile.deletions': return 'Require approval: deletions';
			case 'character.loadingStatus.initial': return 'Loading...';
			case 'character.loadingStatus.copyingAssistant': return 'Copying assistant...';
			case 'character.loadingStatus.scanningForCharacters': return 'Scanning for characters...';
			case 'character.loadingStatus.scanningForCharactersProgress': return ({required Object current, required Object total}) => 'Scanning for characters...\n${current} / ${total}';
			case 'character.loadingStatus.loadingCharactersProgress': return ({required Object current, required Object total}) => 'Loading characters...\n${current} / ${total}';
			case 'character.savePathValidation.noLibraryFolder': return 'No library folder configured.';
			case 'character.savePathValidation.mustBeInsideLibrary': return 'Characters must be saved inside your library folder.';
			case 'character.characterFilesTypeGroupLabel': return 'Character Files';
			case 'character.createController.pngImagesTypeGroupLabel': return 'PNG Images';
			case 'character.createController.invalidLocationTitle': return 'Invalid Location';
			case 'character.createController.creationFailedTitle': return 'Creation Failed';
			case 'character.createController.creationFailedMessage': return 'Could not create the character. Check logs for details.';
			case 'character.importController.failedToImport': return ({required Object fileName}) => 'Failed to import ${fileName}.';
			case 'character.importController.importedCount': return ({required Object count}) => 'Imported ${count} characters';
			case 'character.aiActionController.aiActionFailed': return 'AI Action failed. Check logs for details.';
			case 'character.aiActionController.processingProgress': return ({required Object name, required Object current, required Object total, required Object eta}) => 'Processing ${name} (${current}/${total})...${eta}';
			case 'character.aiActionController.etaHoursMinutes': return ({required Object hours, required Object minutes}) => ' ETA: ${hours}h ${minutes}m';
			case 'character.aiActionController.etaMinutesSeconds': return ({required Object minutes, required Object seconds}) => ' ETA: ${minutes}m ${seconds}s';
			case 'character.aiActionController.etaSeconds': return ({required Object seconds}) => ' ETA: ${seconds}s';
			case 'character.aiActionController.processingField': return ({required Object fieldName}) => 'Processing ${fieldName}...';
			case 'chat.tileAiProvider.modelLabel': return 'Model';
			case 'chat.tileAiProvider.invalidLabel': return 'Invalid';
			case 'chat.tileAiProvider.chooseModelTitle': return 'Choose a model';
			case 'chat.presetTile.tapToChoose': return 'Tap to choose';
			case 'chat.tileImagePreset.titleLabel': return 'Image Model';
			case 'chat.tileImagePreset.chooseModelTitle': return 'Choose an image model';
			case 'chat.tileVideoPreset.titleLabel': return 'Video Model';
			case 'chat.tileVideoPreset.chooseModelTitle': return 'Choose a video model';
			case 'chat.tileTtsPreset.titleLabel': return 'Speech Model';
			case 'chat.tileTtsPreset.chooseModelTitle': return 'Choose a speech model';
			case 'chat.tileImageAspectRatio.label': return 'Image aspect ratio';
			case 'chat.tileVideoAspectRatio.label': return 'Aspect ratio';
			case 'chat.tileVideoResolution.label': return 'Resolution';
			case 'chat.tileVideoDuration.label': return 'Duration';
			case 'chat.tileTtsVoice.label': return 'Voice';
			case 'chat.tileTtsLanguage.label': return 'Language';
			case 'chat.tileNsfw.label': return 'NSFW / Unlimited';
			case 'chat.tileScenario.label': return 'Scenario';
			case 'chat.tileMaxResponseLength.titleWithBucket': return ({required Object bucket}) => 'Response length — ${bucket}';
			case 'chat.tileMaxResponseLength.sliderLabel': return ({required Object bucket, required Object tokens}) => '${bucket} (${tokens} tokens)';
			case 'chat.tileMaxResponseLength.bucketVeryShort': return 'Very short';
			case 'chat.tileMaxResponseLength.bucketShort': return 'Short';
			case 'chat.tileMaxResponseLength.bucketMedium': return 'Medium';
			case 'chat.tileMaxResponseLength.bucketLong': return 'Long';
			case 'chat.tileMaxResponseLength.bucketVeryLong': return 'Very long';
			case 'chat.tileTrailingParagraph.label': return 'Cut Trailing Text';
			case 'chat.tileReasoningEffort.titleWithEffort': return ({required Object effort}) => 'Reasoning — ${effort}';
			case 'chat.tileReasoningEffort.titleOff': return 'Reasoning off';
			case 'chat.tileReasoningEffort.extraTokensCaption': return 'Uses extra tokens beyond your max response length.';
			case 'chat.tileChatTheme.label': return 'Theme';
			case 'chat.tileRecalledMemory.label': return 'Show Recalled Memory';
			case 'chat.characterSwitcher.favoritesTooltip': return 'Favorites';
			case 'chat.characterSwitcher.recentChatsTooltip': return 'Recent Chats';
			case 'chat.characterSwitcher.originalBadge': return 'ORIGINAL';
			case 'chat.characterSwitcher.variantBadge': return 'VARIANT';
			case 'chat.characterSwitcher.lastActive': return ({required Object timeAgo}) => 'Last active: ${timeAgo}';
			case 'chat.characterSwitcher.never': return 'Never';
			case 'chat.freeImagePromptDialog.title': return 'Generate image';
			case 'chat.freeImagePromptDialog.description': return 'Describe what you want to see. A short phrase is fine — the model will expand it into a full tag list.';
			case 'chat.freeImagePromptDialog.subjectLabel': return 'Subject';
			case 'chat.freeImagePromptDialog.subjectHint': return 'cyberpunk alley, neon rain';
			case 'chat.freeImagePromptDialog.generateButton': return 'Generate';
			case 'chat.freeVideoPromptDialog.title': return 'Generate video';
			case 'chat.freeVideoPromptDialog.description': return 'Describe a short moment of motion — what is moving, how, where. The system model will expand it into a cinematic T2V prompt.';
			case 'chat.freeVideoPromptDialog.subjectLabel': return 'Subject';
			case 'chat.freeVideoPromptDialog.subjectHint': return 'she walks through neon rain, slow motion';
			case 'chat.freeVideoPromptDialog.generateButton': return 'Generate';
			case 'chat.imagePromptReviewDialog.title': return 'Review image prompt';
			case 'chat.imagePromptReviewDialog.description': return 'Edit the prompt below before generating, or tap Generate to use it as-is.';
			case 'chat.imagePromptReviewDialog.fieldLabel': return 'Image prompt';
			case 'chat.imagePromptReviewDialog.generateButton': return 'Generate';
			case 'chat.videoPromptReviewDialog.title': return 'Review video prompt';
			case 'chat.videoPromptReviewDialog.description': return 'Edit the prompt below before submitting, or tap Generate to use it as-is.';
			case 'chat.videoPromptReviewDialog.fieldLabel': return 'Video prompt';
			case 'chat.videoPromptReviewDialog.generateButton': return 'Generate';
			case 'chat.urlFetchReviewDialog.title': return 'Allow web fetch?';
			case 'chat.urlFetchReviewDialog.description': return 'The character wants to read the contents of this URL.';
			case 'chat.urlFetchReviewDialog.purposeLabel': return 'Purpose:';
			case 'chat.urlFetchReviewDialog.denyButton': return 'Deny';
			case 'chat.urlFetchReviewDialog.allowButton': return 'Allow';
			case 'chat.messageActionsRow.tokenCountAbbrev': return ({required Object count}) => '${count}t';
			case 'chat.messageActionsRow.generationTimeAbbrev': return ({required Object seconds}) => '${seconds}s';
			case 'chat.messageActionsRow.viewGenerationPromptTooltip': return 'View generation prompt';
			case 'chat.messageActionsRow.messageActionsTooltip': return 'Message actions';
			case 'chat.messageActionsRow.editAction': return 'Edit';
			case 'chat.messageActionsRow.copyAction': return 'Copy';
			case 'chat.messageActionsRow.shareImageAction': return 'Share Image';
			case 'chat.messageActionsRow.setAsBackgroundAction': return 'Set as Background';
			case 'chat.messageActionsRow.setAsCharacterImageAction': return 'Set as Character Image';
			case 'chat.messageActionsRow.deleteAction': return 'Delete';
			case 'chat.messageActionsRow.copiedToClipboard': return 'Message copied to clipboard';
			case 'chat.ttsPlayButton.stopTooltip': return 'Stop';
			case 'chat.ttsPlayButton.readAloudTooltip': return 'Read aloud';
			case 'chat.ttsPlayButton.ttsFailed': return 'TTS failed.';
			case 'chat.messageSwipeFlipper.previousVersionTooltip': return 'Previous version';
			case 'chat.messageSwipeFlipper.swipeCounter': return ({required Object current, required Object total}) => '${current} / ${total}';
			case 'chat.messageSwipeFlipper.regenerateTooltip': return 'Regenerate';
			case 'chat.messageSwipeFlipper.nextVersionTooltip': return 'Next version';
			case 'chat.videoPlayerInline.webUnsupported': return 'Video playback not supported on web.';
			case 'chat.videoPlayerInline.couldNotLoad': return 'Could not load video.';
			case 'chat.newChatLabel': return 'New Chat';
			case 'chat.chatListItem.messageCount': return ({required Object count}) => '${count} messages';
			case 'chat.chatListItem.renameAction': return 'Rename';
			case 'chat.chatListItem.deleteChatAction': return 'Delete Chat';
			case 'chat.chatHistoryController.renameChatTitle': return 'Rename Chat';
			case 'chat.chatHistoryController.chatNameHint': return 'Chat Name';
			case 'chat.chatHistoryController.renameButton': return 'Rename';
			case 'chat.chatHistoryController.deleteChatTitle': return 'Delete Chat';
			case 'chat.chatHistoryController.deleteChatMessage': return 'Are you sure you want to delete this chat history? This action cannot be undone.';
			case 'chat.chatPageController.clearAssistantHistoryMessage': return 'Clear the assistant chat history?';
			case 'chat.chatPageController.clearButton': return 'Clear';
			case 'chat.chatPageController.deleteOrKeepMessage': return 'Would you like to delete the current chat or keep it in your history?';
			case 'chat.chatPageController.deleteCurrentButton': return 'Delete Current';
			case 'chat.chatPageController.keepCurrentButton': return 'Keep Current';
			case 'chat.imageGenerationMixin.enterPromptMessage': return 'Enter a prompt to generate an image.';
			case 'chat.imageGenerationMixin.noCharacterMessage': return 'No character available for image generation.';
			case 'chat.imageGenerationMixin.notConfiguredMessage': return 'Image generation is not configured.';
			case 'chat.imageGenerationMixin.noSystemModelMessage': return 'No system model is configured. Set one in Settings → AI.';
			case 'chat.videoGenerationMixin.enterPromptMessage': return 'Enter a prompt to generate a video.';
			case 'chat.videoGenerationMixin.noCharacterMessage': return 'No character available for video generation.';
			case 'chat.videoGenerationMixin.notConfiguredMessage': return 'Video generation is not configured.';
			case 'chat.bubbleWaitingFor.thinking': return 'Thinking…';
			case 'chat.bubbleWaitingFor.preparingImagePrompt': return 'Preparing image prompt…';
			case 'chat.bubbleWaitingFor.preparingVideoPrompt': return 'Preparing video prompt…';
			case 'chat.bubbleWaitingFor.generatingImage': return 'Generating image…';
			case 'chat.bubbleWaitingFor.generatingVideo': return 'Generating video…';
			case 'chat.appBarChat.hideEditorPanelTooltip': return 'Hide editor panel';
			case 'chat.appBarChat.showEditorSideBySideTooltip': return 'Show editor side-by-side';
			case 'chat.allChatsDrawerList.rebuildingIndex': return 'Rebuilding index...';
			case 'chat.allChatsDrawerList.noChatsFound': return 'No chats found.';
			case 'chat.chatInputMediaMenu.generateMediaTooltip': return 'Generate media';
			case 'chat.chatInputMediaMenu.generateImageLabel': return 'Generate image';
			case 'chat.chatInputMediaMenu.generateVideoLabel': return 'Generate video';
			case 'chat.chatView.deleteMessageTitle': return 'Delete Message';
			case 'chat.chatView.deleteMessageConfirmation': return 'Are you sure you want to delete this message?';
			case 'chat.chatView.typeMessageHint': return 'Type a message...';
			case 'chat.chatView.moreActionsTooltip': return 'More actions';
			case 'chat.chatView.continueAction': return 'Continue';
			case 'chat.chatView.impersonateAction': return 'Impersonate';
			case 'chat.chatView.generateReplyAction': return 'Generate Reply';
			case 'chat.chatView.improveMessageAction': return 'Improve Message';
			case 'chat.chatMessageBubble.imagesTypeGroupLabel': return 'Images';
			case 'chat.chatMessageBubble.assistantFallbackName': return 'Assistant';
			case 'chat.chatMessageBubble.reasoningLabel': return 'Reasoning';
			case 'chat.chatMessageBubble.sendingToProvider': return 'Sending to provider…';
			case 'chat.chatMessageBubble.pollingWithPercent': return ({required Object pct}) => 'Polling… ${pct}%';
			case 'chat.chatMessageBubble.polling': return 'Polling…';
			case 'chat.chatMessageBubble.downloading': return 'Downloading…';
			case 'common.actions.delete': return 'Delete';
			case 'common.actions.ok': return 'OK';
			case 'common.actions.cancel': return 'Cancel';
			case 'common.actions.save': return 'Save';
			case 'common.actions.tryAgain': return 'Try Again';
			case 'common.actions.close': return 'Close';
			case 'common.aiAction.proofread': return 'Proofread';
			case 'common.aiAction.compact': return 'Compact Prose';
			case 'common.aiAction.translate': return 'Translate to English';
			case 'common.aiAction.generatePreview': return 'Generate Preview';
			case 'common.aiAction.autoTag': return 'Auto-Tag';
			case 'common.aiActionsTooltip': return 'AI Actions';
			case 'common.promptSegmentKind.identity': return 'Identity';
			case 'common.promptSegmentKind.systemPrompt': return 'System prompt';
			case 'common.promptSegmentKind.nsfwMode': return 'NSFW mode';
			case 'common.promptSegmentKind.scenarioMode': return 'Scenario mode';
			case 'common.promptSegmentKind.description': return 'Description';
			case 'common.promptSegmentKind.personality': return 'Personality';
			case 'common.promptSegmentKind.scenario': return 'Scenario';
			case 'common.promptSegmentKind.userPersona': return 'Your persona';
			case 'common.promptSegmentKind.memory': return 'Memory';
			case 'common.promptSegmentKind.situation': return 'Situation';
			case 'common.promptSegmentKind.cardData': return 'Card data';
			case 'common.promptSegmentKind.tools': return 'Tools';
			case 'common.promptSegmentKind.postHistory': return 'Post-history';
			case 'common.promptSegmentKind.depthPrompt': return 'Depth prompt';
			case 'common.promptSegmentKind.worldInfo': return 'World info';
			case 'common.promptSegmentKind.injected': return 'Injected';
			case 'common.promptSegmentKind.exampleDialogue': return 'Example dialogue';
			case 'common.promptSegmentKind.history': return 'Message history';
			case 'common.promptSegmentKind.currentMessage': return 'Current message';
			case 'common.promptSegmentKind.reservedReply': return 'Reserved reply';
			case 'common.promptBreakdown.free': return 'Free';
			case 'common.logs.title': return 'Logs';
			case 'common.logs.filterTooltip': return 'Filter Logs';
			case 'common.logs.clearTooltip': return 'Clear Logs';
			case 'common.logs.exportTooltip': return 'Export Logs';
			case 'common.logs.searchHint': return 'Search logs...';
			case 'common.logs.noLogsFound': return 'No logs found.';
			case 'common.logs.noLogsToExport': return 'No logs to export';
			case 'common.logs.exportedSuccessfully': return 'Logs exported successfully';
			case 'common.logs.exportFailed': return 'Failed to export logs. See logs for details.';
			case 'common.logs.copiedToClipboard': return 'Copied to clipboard';
			case 'common.logs.copyLogButton': return 'Copy Log';
			case 'common.logs.copiedEntryToClipboard': return 'Copied log entry to clipboard';
			case 'common.importErrorsDialog.title': return 'Import Errors';
			case 'common.importErrorsDialog.message': return 'The following files could not be imported:';
			case 'common.updateDialog.title': return 'Version Available';
			case 'common.updateDialog.body': return ({required Object appName, required Object currentVersion, required Object latestVersion}) => 'A newer version of ${appName} is available.\n\nCurrent version: ${currentVersion}\nLatest version: ${latestVersion}';
			case 'common.updateDialog.releaseNotesLabel': return 'Release Notes:';
			case 'common.updateDialog.viewReleasesButton': return 'View Releases';
			case 'common.importConflictsDialog.title': return 'Import Conflicts';
			case 'common.importConflictsDialog.message': return ({required Object count}) => 'The following ${count} characters have filename conflicts and will be renamed automatically:';
			case 'common.missingProviderBanner.message': return 'Connect an AI provider.';
			case 'common.missingProviderBanner.setUpNowButton': return 'Set Up Now';
			case 'common.modelSelectionDialog.searchHint': return 'Search Models';
			case 'common.modelSelectionDialog.subscriptionOnlyToggle': return ({required Object included, required Object total}) => 'Show only subscription models (${included}/${total})';
			case 'common.showAdvanced.less': return 'Less';
			case 'common.showAdvanced.more': return 'More';
			case 'common.messageEditDialog.title': return 'Edit Message';
			case 'common.promptBreakdownDialog.title': return 'Prompt Breakdown';
			case 'common.promptBreakdownDialog.breakdownTab': return 'Breakdown';
			case 'common.promptBreakdownDialog.contentTab': return 'Content';
			case 'common.promptBreakdownDialog.promptTotalEstimated': return 'Prompt total (estimated)';
			case 'common.promptBreakdownDialog.promptTotalProvider': return 'Prompt total (provider)';
			case 'common.promptBreakdownDialog.contextWindowLabel': return 'Context window';
			case 'common.promptBreakdownDialog.categoryHeader': return 'CATEGORY';
			case 'common.promptBreakdownDialog.tokensHeader': return 'TOKENS';
			case 'common.promptBreakdownDialog.usageHeader': return 'USAGE';
			case 'common.promptBreakdownDialog.noContentToInspect': return 'No content to inspect for this reply.';
			case 'common.promptBreakdownDialog.estimatedSuffix': return ' (estimated)';
			case 'common.promptBreakdownDialog.usedSummary': return ({required Object used, required Object total}) => '${used} / ${total} used';
			case 'common.jsonPromptDialog.title': return 'Generation Prompt';
			case 'common.progressDialog.defaultMessage': return 'Sending...';
			case 'common.progressDialog.finished': return 'Finished!';
			case 'common.diffPanel.tokenSuffix': return ({required Object count}) => ' (${count} Tokens)';
			case 'common.selectionDialog.searchHint': return 'Search…';
			case 'common.zdrSwitch.title': return 'Require Zero Data Retention (ZDR)';
			case 'common.zdrSwitch.subtitle': return 'Only show OR models with ZDR-compliant endpoints. Enable this if your openrouter.ai account restricts to ZDR providers.';
			case 'common.textFieldCard.labelWithTokenCount': return ({required Object label, required Object count}) => '${label} - ${count} tokens';
			case 'common.textFieldCard.tokenCountAbbrev': return ({required Object count}) => '${count} t';
			case 'common.modelCapability.reasoning': return 'Reasoning';
			case 'common.modelCapability.vision': return 'Vision';
			case 'common.modelCapability.tools': return 'Tools';
			case 'common.modelCapability.json': return 'JSON';
			case 'common.modelCapability.files': return 'Files';
			case 'common.modelCapability.image': return 'Image';
			case 'common.modelCapability.video': return 'Video';
			case 'common.modelCapability.speech': return 'Speech';
			case 'common.modelCapability.music': return 'Music';
			case 'common.modelUnavailableTooltip': return 'This model is no longer available from the provider — pick another.';
			case 'common.characterImageSemanticLabel': return 'Character image';
			case 'common.appConstants.maxImageFileSizeLabel': return '10 MB';
			case 'common.appConstants.exportFailedMessage': return 'Export failed. See logs for details.';
			case 'editor.panelLabels.basic': return 'Basic';
			case 'editor.panelLabels.greetings': return 'Greetings';
			case 'editor.panelLabels.prompts': return 'Prompts';
			case 'editor.panelLabels.lorebook': return 'Lorebook';
			case 'editor.panelLabels.group': return 'Group';
			case 'editor.panelLabels.creator': return 'Creator';
			case 'editor.panelLabels.appData': return 'App Data';
			case 'editor.panelLabels.nodes': return 'Nodes';
			case 'editor.appBarEditor.hideAssistantPanelTooltip': return 'Hide assistant panel';
			case 'editor.appBarEditor.showChatAssistantTooltip': return 'Show chat assistant side-by-side';
			case 'editor.codeFindPanel.noneResult': return 'none';
			case 'editor.codeFindPanel.previousTooltip': return 'Previous';
			case 'editor.codeFindPanel.nextTooltip': return 'Next';
			case 'editor.codeFindPanel.closeTooltip': return 'Close';
			case 'editor.codeFindPanel.replaceTooltip': return 'Replace';
			case 'editor.codeFindPanel.replaceAllTooltip': return 'Replace All';
			case 'editor.findReplaceDialog.confirmReplaceAllTitle': return 'Confirm Replace All';
			case 'editor.findReplaceDialog.confirmReplaceAllMessage': return 'Are you sure you want to proceed?\nThis action is irreversible and affects all fields.';
			case 'editor.findReplaceDialog.proceedButton': return 'Proceed';
			case 'editor.findReplaceDialog.title': return 'Find & Replace';
			case 'editor.findReplaceDialog.findLabel': return 'Find';
			case 'editor.findReplaceDialog.replaceWithLabel': return 'Replace with';
			case 'editor.findReplaceDialog.replaceAllButton': return 'Replace All';
			case 'editor.objectValueEditor.stringType': return 'string';
			case 'editor.objectValueEditor.numberType': return 'number';
			case 'editor.objectValueEditor.boolType': return 'bool';
			case 'editor.editorBasic.nameLabel': return 'Name';
			case 'editor.editorBasic.nicknameLabel': return 'Nickname (CCv3)';
			case 'editor.editorBasic.descriptionLabel': return 'Description';
			case 'editor.editorBasic.personalityLabel': return 'Personality';
			case 'editor.editorBasic.scenarioLabel': return 'Scenario';
			case 'editor.editorBasic.messageExampleLabel': return 'Message Example';
			case 'editor.editorCreatorMetadata.systemNameLabel': return 'System Name (CCv3)';
			case 'editor.editorCreatorMetadata.creatorLabel': return 'Creator';
			case 'editor.editorCreatorMetadata.versionLabel': return 'Version';
			case 'editor.editorCreatorMetadata.creatorNotesLabel': return 'Creator Notes';
			case 'editor.editorCreatorMetadata.tagsLabel': return 'Tags (Coma separated)';
			case 'editor.editorPrompts.systemPromptLabel': return 'System Prompt';
			case 'editor.editorPrompts.postHistoryInstructionsLabel': return 'Post History Instructions';
			case 'editor.editorPrompts.depthPromptLabel': return 'Depth Prompt (Character Notes)';
			case 'editor.editorPrompts.insertionDepthLabel': return 'Insertion Depth';
			case 'editor.editorPrompts.roleLabel': return 'Role';
			case 'editor.editorAppData.variantNotesLabel': return 'Variant Notes';
			case 'editor.editorAppData.descriptionPreviewLabel': return 'Description Preview';
			case 'editor.editorAlternateGreetings.deleteGreetingTitle': return 'Delete Greeting';
			case 'editor.editorAlternateGreetings.deleteGreetingMessage': return 'Are you sure you want to delete this greeting?';
			case 'editor.editorAlternateGreetings.addGreetingButton': return 'Add Greeting';
			case 'editor.editorAlternateGreetings.primaryGreetingLabel': return 'Primary Greeting (first_mes)';
			case 'editor.editorAlternateGreetings.alternateGreetingLabel': return ({required Object index}) => 'Alternate Greeting #${index}';
			case 'editor.editorAlternateGreetings.removeTooltip': return 'Remove';
			case 'editor.editorGroupGreetings.greetingLabel': return ({required Object index}) => 'Greeting ${index}';
			case 'editor.editorLorebook.newEntryDefaultComment': return 'New Entry';
			case 'editor.editorLorebook.deleteEntryTitle': return 'Delete Entry';
			case 'editor.editorLorebook.deleteEntryMessage': return 'Are you sure you want to delete this entry?';
			case 'editor.editorLorebook.addNewEntryButton': return 'Add New Entry';
			case 'editor.editorLorebook.noEntriesFound': return 'No lorebook entries found.';
			case 'editor.lorebookEntryListTile.untitledEntry': return 'Untitled Entry';
			case 'editor.lorebookEntryListTile.noKeywords': return 'No keywords';
			case 'editor.lorebookEntryEditorPage.editEntryTitle': return 'Edit Lorebook Entry';
			case 'editor.lorebookEntryEditorPage.advancedFilter': return 'Advanced';
			case 'editor.lorebookEntryEditorPage.primaryKeywordsLabel': return 'Primary Keywords';
			case 'editor.lorebookEntryEditorPage.logicLabel': return 'Logic';
			case 'editor.lorebookEntryEditorPage.logicAndAny': return 'AND ANY';
			case 'editor.lorebookEntryEditorPage.logicAndAll': return 'AND ALL';
			case 'editor.lorebookEntryEditorPage.logicNotAny': return 'NOT ANY';
			case 'editor.lorebookEntryEditorPage.logicNotAll': return 'NOT ALL';
			case 'editor.lorebookEntryEditorPage.optionalFilterLabel': return 'Optional Filter';
			case 'editor.lorebookEntryEditorPage.contentLabel': return 'Content';
			case 'editor.lorebookEntryEditorPage.nonRecursableFilter': return 'Non-recursable';
			case 'editor.lorebookEntryEditorPage.preventFurtherRecursionFilter': return 'Prevent Further Recursion';
			case 'editor.lorebookEntryEditorPage.delayUntilRecursionFilter': return 'Delay Until Recursion';
			case 'editor.lorebookEntryEditorPage.ignoreBudgetFilter': return 'Ignore Budget';
			case 'editor.lorebookEntryEditorPage.prioritizeFilter': return 'Prioritize';
			case 'editor.lorebookEntryEditorPage.inclusionGroupLabel': return 'Inclusion Group';
			case 'editor.lorebookEntryEditorPage.groupWeightLabel': return 'Group Weight';
			case 'editor.lorebookEntryEditorPage.stickyLabel': return 'Sticky';
			case 'editor.lorebookEntryEditorPage.cooldownLabel': return 'Cooldown';
			case 'editor.lorebookEntryEditorPage.delayLabel': return 'Delay';
			case 'editor.lorebookEntryEditorPage.filterToCharactersLabel': return 'Filter to Characters or Tags';
			case 'editor.lorebookEntryEditorPage.filterToTriggersLabel': return 'Filter to Generation Triggers';
			case 'editor.lorebookEntryEditorPage.additionalMatchingSourcesLabel': return 'Additional Matching Sources:';
			case 'editor.lorebookEntryEditorPage.personaFilter': return 'Persona';
			case 'editor.lorebookEntryEditorPage.descriptionFilter': return 'Description';
			case 'editor.lorebookEntryEditorPage.personalityFilter': return 'Personality';
			case 'editor.lorebookEntryEditorPage.depthPromptFilter': return 'Depth Prompt';
			case 'editor.lorebookEntryEditorPage.scenarioFilter': return 'Scenario';
			case 'editor.lorebookEntryEditorPage.creatorNotesFilter': return 'Creator Notes';
			case 'editor.lorebookEntryEditorTopSection.titleMemoLabel': return 'Title/Memo';
			case 'editor.lorebookEntryEditorTopSection.strategyLabel': return 'Strategy';
			case 'editor.lorebookEntryEditorTopSection.strategyConstant': return 'Constant';
			case 'editor.lorebookEntryEditorTopSection.strategyEnabled': return 'Enabled';
			case 'editor.lorebookEntryEditorTopSection.strategyDisabled': return 'Disabled';
			case 'editor.lorebookEntryEditorTopSection.strategyVectorized': return 'Vectorized';
			case 'editor.lorebookEntryEditorTopSection.positionLabel': return 'Position';
			case 'editor.lorebookEntryEditorTopSection.positionUpChar': return '↑ Char';
			case 'editor.lorebookEntryEditorTopSection.positionDownChar': return '↓ Char';
			case 'editor.lorebookEntryEditorTopSection.positionUpAn': return '↑ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDownAn': return '↓ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDepthSystem': return '@D System';
			case 'editor.lorebookEntryEditorTopSection.positionDepthUser': return '@D User';
			case 'editor.lorebookEntryEditorTopSection.positionDepthAssistant': return '@D Assistant';
			case 'editor.lorebookEntryEditorTopSection.positionUpEm': return '↑ EM';
			case 'editor.lorebookEntryEditorTopSection.positionDownEm': return '↓ EM';
			case 'editor.lorebookEntryEditorTopSection.positionOutlet': return 'Outlet';
			case 'editor.lorebookEntryEditorTopSection.depthLabel': return 'Depth';
			case 'editor.lorebookEntryEditorTopSection.orderLabel': return 'Order';
			case 'editor.lorebookEntryEditorTopSection.triggerLabel': return 'Trigger %';
			case 'editor.lorebookEntryEditorScanRow.scanDepthLabel': return 'Scan Depth';
			case 'editor.lorebookEntryEditorScanRow.automationIdLabel': return 'Automation ID';
			case 'editor.lorebookEntryEditorScanRow.useRegexFilter': return 'Use Regex';
			case 'editor.lorebookEntryEditorScanRow.caseSensitiveFilter': return 'Case Sensitive';
			case 'editor.lorebookEntryEditorScanRow.wholeWordsFilter': return 'Whole Words';
			case 'editor.lorebookEntryEditorScanRow.groupScoringFilter': return 'Group Scoring';
			case 'editor.dialogContentCleaner.confirmActionTitle': return ({required Object actionName}) => 'Confirm ${actionName}';
			case 'editor.dialogContentCleaner.title': return 'Content Cleaner';
			case 'editor.dialogContentCleaner.normalizeFancyCharsAction': return 'Normalize Fancy Chars';
			case 'editor.dialogContentCleaner.normalizeFancyCharsButton': return 'Normalize Fancy Chars (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
			case 'editor.dialogContentCleaner.purgeHtmlAction': return 'Purge HTML';
			case 'editor.dialogContentCleaner.purgeHtmlButton': return 'Purge HTML Tags';
			case 'editor.dialogContentCleaner.purgeMarkdownAction': return 'Purge Markdown Links/Images';
			case 'editor.dialogContentCleaner.purgeEmojisAction': return 'Purge Emojis';
			case 'editor.dialogContentCleaner.purgeExtraSpacesAction': return 'Purge Extra Spaces';
			case 'editor.dialogContentCleaner.yoloPurgeAction': return 'Yolo Purge';
			case 'editor.dialogContentCleaner.applyAllAboveButton': return 'Apply All Above';
			case 'editor.dialogAiDiffConfirmation.applyChangesButton': return 'Apply Changes';
			case 'editor.dialogAiDiffConfirmation.originalTextTitle': return 'Original Text';
			case 'editor.dialogAiDiffConfirmation.suggestedTextTitle': return 'Suggested Text';
			case 'editor.editorPageController.globalActionTitle': return ({required Object action}) => 'Global ${action}';
			case 'editor.editorPageController.globalAiActionFailed': return 'Global AI action failed. Check logs.';
			case 'editor.editorPageController.compositeName': return ({required Object value}) => 'Name:\n${value}\n';
			case 'editor.editorPageController.compositeDescription': return ({required Object value}) => 'Description:\n${value}\n';
			case 'editor.editorPageController.compositePersonality': return ({required Object value}) => 'Personality:\n${value}\n';
			case 'editor.editorPageController.compositeScenario': return ({required Object value}) => 'Scenario:\n${value}\n';
			case 'editor.editorPageController.compositeFirstMessage': return ({required Object value}) => 'First Message:\n${value}\n';
			case 'editor.editorPageController.compositeMessageExample': return ({required Object value}) => 'Message Example:\n${value}\n';
			case 'editor.editorPageController.compositeCreatorNotes': return ({required Object value}) => 'Creator Notes:\n${value}\n';
			case 'editor.editorPageController.compositeSystemPrompt': return ({required Object value}) => 'System Prompt:\n${value}\n';
			case 'editor.editorPageController.compositePostHistoryInstructions': return ({required Object value}) => 'Post-History Instructions:\n${value}\n';
			case 'editor.editorPageController.compositeAlternateGreeting': return ({required Object index, required Object value}) => 'Alternate Greeting #${index}:\n${value}\n';
			case 'editor.editorPageController.compositeGroupGreeting': return ({required Object index, required Object value}) => 'Group Greeting #${index}:\n${value}\n';
			case 'editor.editorPageController.compositeLorebookEntry': return ({required Object index, required Object value}) => 'Lorebook Entry #${index}:\n${value}\n';
			case 'editor.editorPageController.imageTooLargeMessage': return ({required Object maxSize}) => 'Selected image is too large. Maximum size is ${maxSize}.';
			case 'editor.editorPageController.invalidPngMessage': return 'Selected image is not a valid PNG or could not be read.';
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
			case 'llmApp.mediaField.imageModel': return 'Image model';
			case 'llmApp.mediaField.imageAspectRatio': return 'Image aspect ratio';
			case 'llmApp.mediaField.imageNsfwAllowed': return 'Image NSFW allowed';
			case 'llmApp.mediaField.imageToolSelfieAllowed': return 'Can send selfies';
			case 'llmApp.mediaField.imageToolSelfieCaptionsAllowed': return 'Allow selfie captions';
			case 'llmApp.mediaField.imagePromptPrefix': return 'Image style';
			case 'llmApp.mediaField.videoModel': return 'Video model';
			case 'llmApp.mediaField.videoResolution': return 'Video resolution';
			case 'llmApp.mediaField.videoAspectRatio': return 'Video aspect ratio';
			case 'llmApp.mediaField.videoDuration': return 'Video duration';
			case 'llmApp.mediaField.videoNsfwAllowed': return 'Video NSFW allowed';
			case 'llmApp.mediaField.videoToolSendAllowed': return 'Can send videos';
			case 'llmApp.mediaField.videoPromptPrefix': return 'Video style';
			case 'llmApp.mediaField.ttsModel': return 'TTS model';
			case 'llmApp.mediaField.ttsVoice': return 'TTS voice';
			case 'llmApp.mediaField.ttsLanguage': return 'TTS language';
			case 'llmApp.mediaField.webToolFetchAllowed': return 'Allow web fetch';
			case 'llmApp.mediaField.nameToolSuggestAllowed': return 'Can suggest NPC names';
			case 'llmApp.mediaSection.image': return 'Image';
			case 'llmApp.mediaSection.video': return 'Video';
			case 'llmApp.mediaSection.tts': return 'TTS';
			case 'llmApp.mediaSection.web': return 'Web';
			case 'llmApp.mediaSection.names': return 'Names';
			case 'llmApp.tristate.on': return 'On';
			case 'llmApp.tristate.off': return 'Off';
			case 'llmApp.tristate.inherit': return 'Inherit';
			case 'llmApp.mediaCellMenu.change': return 'Change…';
			case 'llmApp.mediaCellMenu.clear': return 'Clear';
			case 'llmApp.mediaHeader.appDefault': return 'App default';
			case 'llmApp.mediaHeader.character': return 'Character';
			case 'llmApp.mediaHeader.currentChat': return 'Current chat';
			case 'llmApp.mediaHeader.previousLayerTooltip': return 'Previous layer';
			case 'llmApp.mediaHeader.nextLayerTooltip': return 'Next layer';
			case 'llmApp.presetRow.changeAppDefaultTitle': return 'Change app default?';
			case 'llmApp.presetRow.changeAppDefaultMessage': return 'This affects every chat. Continue?';
			case 'llmApp.presetRow.continueButton': return 'Continue';
			case 'llmApp.presetRow.chooseModelTitle': return ({required Object domain}) => 'Choose a ${domain} model';
			case 'llmApp.mediaCell.notApplicable': return 'Not applicable';
			case 'onboarding.finishFailedSnackbar': return 'Setup failed. See logs for details.';
			case 'onboarding.appBarTitle': return 'Quick Setup';
			case 'onboarding.webWarning': return 'Experimental web build — browser storage may reset between updates. Use desktop or Android for persistent data.';
			case 'onboarding.finishButton': return 'Finish Setup';
			case 'onboarding.nextButton': return 'Next';
			case 'onboarding.backButton': return 'Back';
			case 'onboarding.storageStep.title': return 'Character Storage';
			case 'onboarding.storageStep.subtitle': return 'Where should we save your character cards?';
			case 'onboarding.storageStep.description': return 'Saved in the app folder by default. Point to an existing PNG folder to import.';
			case 'onboarding.storageStep.startFresh': return 'Start fresh';
			case 'onboarding.storageStep.haveCards': return 'I already have cards';
			case 'onboarding.storageStep.importLaterHint': return 'Import PNGs later via File → Import.';
			case 'onboarding.storageStep.selectedPath': return ({required Object path}) => 'Selected: ${path}';
			case 'onboarding.storageStep.selectedDefaultFolder': return 'Selected: Default app folder';
			case 'onboarding.storageStep.noFolderSelected': return 'No folder selected yet.';
			case 'onboarding.setupStep.title': return 'AI & Persona';
			case 'onboarding.aiSection.heading': return 'AI Connection';
			case 'onboarding.aiSection.optionalHint': return 'Optional — skip and add a key later in Settings (local providers can be added there too).';
			case 'onboarding.aiSection.apiKeyLabel': return 'API Key';
			case 'onboarding.aiSection.apiKeyHint': return 'Paste your key (or skip for now)';
			case 'onboarding.aiSection.supportedProviders': return 'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. More in Settings.';
			case 'onboarding.aiSection.unknownModel': return '(unknown model)';
			case 'onboarding.aiSection.ctxUnknown': return 'ctx —';
			case 'onboarding.aiSection.ctxValue': return ({required Object ctx}) => 'ctx ${ctx}';
			case 'onboarding.aiSection.kvSuffix': return ({required Object kv}) => ' · KV ${kv}';
			case 'onboarding.aiSection.changeButton': return 'Change';
			case 'onboarding.aiStatus.connecting': return 'Connecting…';
			case 'onboarding.aiStatus.connected': return ({required Object provider}) => 'Connected to ${provider}. Default chat model selected.';
			case 'onboarding.aiStatus.detected': return ({required Object provider}) => 'Detected: ${provider}';
			case 'onboarding.aiStatus.unrecognizedKey': return 'Unrecognized key format.';
			case 'onboarding.personaSection.heading': return 'Your Persona';
			case 'onboarding.personaSection.hint': return 'Your name in chats. More persona details in Settings.';
			case 'onboarding.personaSection.nameLabel': return 'Your name';
			case 'onboarding.disclaimer.prefix': return 'I have read and agree to the ';
			case 'onboarding.disclaimer.linkText': return 'Disclaimer';
			case 'onboarding.fetchError.noModels': return 'No models returned. Check your API key.';
			case 'onboarding.fetchError.connectionFailed': return 'Could not connect. Check your internet connection and API key.';
			case 'routing.chatCharacter.navigationError': return ({required Object name}) => 'Navigation error to chat. Character: ${name}';
			case 'routing.editCharacter.navigationError': return ({required Object name}) => 'Navigation error to edit. Character: ${name}';
			case 'routing.editPreset.navigationError': return ({required Object presetId}) => 'Navigation error to edit preset: ${presetId}';
			case 'settings.gearLanguage': return 'Language';
			case 'settings.languageSystemDefault': return 'System default';
			case 'settings.gearMenu.settingsTooltip': return 'Settings';
			case 'settings.gearMenu.mediaDefaultsApp': return 'App';
			case 'settings.gearMenu.mediaDefaultsCharacter': return 'Character';
			case 'settings.gearMenu.mediaDefaultsChat': return 'Chat';
			case 'settings.gearMenu.appSettings': return 'App Settings';
			case 'settings.gearMenu.logs': return 'Logs';
			case 'settings.mediaDefaultsDrawerEntry.configurationHeader': return 'Configuration';
			case 'settings.endDrawer.switchPersonaTooltip': return 'Switch persona';
			case 'settings.general.characterFolderTitle': return 'Character Folder';
			case 'settings.general.characterFolderNotSet': return 'Not set. Required for the app to function.';
			case 'settings.general.browseButton': return 'Browse...';
			case 'settings.general.taxonomyTagsTitle': return 'Taxonomy Tags';
			case 'settings.general.appThemeTitle': return 'App Theme';
			case 'settings.general.themeSystem': return 'System';
			case 'settings.general.themeLight': return 'Light';
			case 'settings.general.themeDark': return 'Dark';
			case 'settings.general.themeStyleTitle': return 'Theme Style';
			case 'settings.general.themeStyleDefault': return 'Default';
			case 'settings.general.themeStyleNeon': return 'Neon';
			case 'settings.general.storyMemoryTitle': return 'Story Memory';
			case 'settings.general.storyMemorySubtitle': return 'Remember earlier moments and bring the relevant ones back into long chats.';
			case 'settings.general.narrativeEngineTitle': return 'Narrative Engine';
			case 'settings.general.narrativeEngineSubtitle': return 'Track the scene and characters and move the story along as you chat.';
			case 'settings.general.promptBreakdownTitle': return 'Show Prompt Breakdown';
			case 'settings.general.promptBreakdownSubtitle': return 'Show a bar under each reply breaking down how the prompt filled the model context window.';
			case 'settings.general.checkUpdatesTitle': return 'Check for Updates';
			case 'settings.general.checkUpdatesSubtitle': return 'Check if a newer version of the app is available.';
			case 'settings.general.websiteTitle': return 'Website';
			case 'settings.general.websiteSubtitle': return 'Visit the official website for updates and information.';
			case 'settings.general.disclaimerTitle': return 'Disclaimer & Terms';
			case 'settings.general.disclaimerSubtitle': return 'Read the application disclaimer and terms of use.';
			case 'settings.general.versionLabel': return ({required Object version, required Object buildNumber}) => 'Version ${version}+${buildNumber}';
			case 'settings.aiSettingsTab.aiProviders': return 'AI Providers';
			case 'settings.aiSettingsTab.mediaDefaults': return 'Media Defaults';
			case 'settings.aiTab.refreshSummary': return ({required Object updated, required Object unavailable, required Object errors}) => 'Refreshed ${updated} models, ${unavailable} unavailable, ${errors} errors.';
			case 'settings.aiTab.newProviderButton': return 'New Provider';
			case 'settings.aiTab.cloudProviderMenuItem': return 'Cloud Provider';
			case 'settings.aiTab.localProviderMenuItem': return 'Local Provider';
			case 'settings.aiTab.localGgufMenuItem': return 'Local GGUF';
			case 'settings.aiTab.noProvidersConfigured': return 'No API providers configured.';
			case 'settings.aiTab.addingProviderOverlay': return 'Adding provider…';
			case 'settings.aiTab.neverRefreshed': return 'Never refreshed';
			case 'settings.aiTab.lastRefreshedLabel': return ({required Object time}) => 'Last refreshed: ${time}';
			case 'settings.aiTab.refreshModelsButton': return 'Refresh models';
			case 'settings.aiTab.refreshNowMenuItem': return 'Refresh now';
			case 'settings.aiTab.autoNeverMenuItem': return 'Auto: Never';
			case 'settings.aiTab.autoDailyMenuItem': return 'Auto: Daily on startup';
			case 'settings.aiTab.defaultModelsHeader': return 'Default Models for New Chats';
			case 'settings.aiTab.editModelTooltip': return 'Edit Model';
			case 'settings.aiTab.noModelsPlaceholder': return 'No Models';
			case 'settings.aiTab.noCompatibleModelsPlaceholder': return 'No compatible models';
			case 'settings.aiTab.tapToChoosePlaceholder': return 'Tap to choose';
			case 'settings.aiTab.modelUsedForPrefix': return 'Model used for ';
			case 'settings.aiTab.modelUsedForSuffix': return ' generation';
			case 'settings.aiTab.chooseModelTitle': return 'Choose a Model';
			case 'settings.aiTab.temperatureLabel': return ({required Object value}) => 'Temp ${value}';
			case 'settings.aiTab.setDefaultButton': return 'Set default';
			case 'settings.aiTab.addModelButton': return 'Add Model';
			case 'settings.aiTab.editProviderMenuItem': return 'Edit provider';
			case 'settings.aiTab.moreTooltip': return 'More';
			case 'settings.aiTab.noModelsForProvider': return 'No Models configured for this provider.';
			case 'settings.aiTab.setDefaultConfirmTitle': return ({required Object provider}) => 'Set ${provider} as the default for every AI feature?';
			case 'settings.aiTab.setDefaultConfirmMessage': return 'You may pick models for unsupported features\n(like image or video) from other providers yourself.';
			case 'settings.aiTab.localGgufSubtitle': return ({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (max ${native}) · KV ${kv}';
			case 'settings.aiTab.testTtsTooltip': return 'Test TTS';
			case 'settings.aiTab.ttsTestPhrase': return 'Hello, this is a test.';
			case 'settings.aiTab.ttsFailedError': return 'TTS failed.';
			case 'settings.aiTab.testVideoTooltip': return 'Test video generation';
			case 'settings.aiTab.videoGeneratedWebFallback': return 'Video generated successfully (preview unavailable on web).';
			case 'settings.aiTab.videoFailedError': return 'Video failed.';
			case 'settings.aiTab.videoLoadFailedMessage': return 'Could not load generated video.';
			case 'settings.aiTab.presetPickerSearchHint': return 'Search by provider, model, or preset…';
			case 'settings.aiTab.tempParamAbbrev': return ({required Object value}) => 'temp ${value}';
			case 'settings.aiTab.reasoningParamLabel': return ({required Object level}) => 'reasoning ${level}';
			case 'settings.presetConfig.testMessageButton': return 'Test Message';
			case 'settings.presetConfig.testSuccessLabel': return 'Success';
			case 'settings.presetConfig.testFailedLabel': return 'Failed';
			case 'settings.presetConfig.deleteModelTitle': return 'Delete Model?';
			case 'settings.presetConfig.deleteModelMessage': return ({required Object name}) => 'Permanently delete "${name}"? This cannot be undone.';
			case 'settings.presetConfig.editModelHeader': return 'Edit Model';
			case 'settings.presetConfig.addModelHeader': return 'Add Model';
			case 'settings.presetConfig.resetToDefaultsTooltip': return 'Reset to Defaults';
			case 'settings.presetConfig.modelNameLabel': return 'Model name';
			case 'settings.presetConfig.clearTooltip': return 'Clear';
			case 'settings.presetConfig.nameRequiredError': return 'Name is required';
			case 'settings.presetConfig.modelLabel': return 'Model';
			case 'settings.presetConfig.selectModelHint': return 'Select a model';
			case 'settings.presetConfig.modelRequiredError': return 'Model is required';
			case 'settings.presetConfig.filteredDomainsNote': return ({required Object domains}) => 'Models are filtered to support the active domains: ${domains}';
			case 'settings.presetConfig.requiredValidator': return 'Required';
			case 'settings.presetConfig.invalidValidator': return 'Invalid';
			case 'settings.presetConfig.testResponseTitle': return 'Response';
			case 'settings.providerConfig.noModelsError': return 'No models returned. Check your API key.';
			case 'settings.providerConfig.connectionFailedError': return 'Could not connect. Check your internet connection and API key.';
			case 'settings.providerConfig.deleteProviderTitle': return 'Delete provider?';
			case 'settings.providerConfig.deleteProviderMessage': return ({required Object provider}) => 'Permanently delete the ${provider} provider and all its presets? This cannot be undone.';
			case 'settings.providerConfig.lockHint': return ({required Object roles}) => 'Cannot delete: in use by ${roles}.';
			case 'settings.providerConfig.editProviderHeader': return 'Edit Provider';
			case 'settings.providerConfig.addProviderHeader': return 'Add Provider';
			case 'settings.providerConfig.apiKeyLabel': return 'API Key';
			case 'settings.providerConfig.apiKeyHintRotate': return 'Paste a new key to rotate';
			case 'settings.providerConfig.apiKeyHintNew': return 'Paste your key — provider is auto-detected';
			case 'settings.providerConfig.supportedProvidersNote': return 'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
			case 'settings.providerConfig.keyMismatchError': return ({required Object owner, required Object profile}) => 'This key belongs to ${owner}, but this profile is ${profile}. Delete this profile and add a new one instead.';
			case 'settings.providerConfig.anotherProviderFallback': return 'another provider';
			case 'settings.providerConfig.connectingStatus': return 'Connecting…';
			case 'settings.providerConfig.connectedStatus': return ({required Object provider}) => 'Connected to ${provider}. Default presets will be created.';
			case 'settings.providerConfig.detectedStatus': return ({required Object provider}) => 'Detected: ${provider}';
			case 'settings.providerConfig.unrecognizedKeyStatus': return 'Unrecognized key format.';
			case 'settings.localProviderConfig.serverUnreachableMessage': return ({required Object url}) => 'Could not reach ${url}. Make sure your local server (KoboldCpp / Ollama / LM Studio / llama.cpp) is running.';
			case 'settings.localProviderConfig.noModelsError': return 'Server reachable but returned no models. Load a model in your local server first.';
			case 'settings.localProviderConfig.deleteProviderMessage': return 'Permanently delete this Local provider and all its presets? This cannot be undone.';
			case 'settings.localProviderConfig.editHeader': return 'Edit Local Provider';
			case 'settings.localProviderConfig.addHeader': return 'Add Local Provider';
			case 'settings.localProviderConfig.serverUrlLabel': return 'Server URL';
			case 'settings.localProviderConfig.serverUrlLockedHelper': return 'Locked. Delete this provider and add a new one to point at a different server.';
			case 'settings.localProviderConfig.apiKeyOptionalLabel': return 'API Key (optional)';
			case 'settings.localProviderConfig.apiKeyOptionalHint': return 'Leave blank — most local servers don\'t need one';
			case 'settings.localProviderConfig.connectFetchButton': return 'Connect & Fetch Models';
			case 'settings.localProviderConfig.connectedFoundModels': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: 'Connected. Found ${n} model.',
				other: 'Connected. Found ${n} models.',
			);
			case 'settings.localGguf.haveLocalGgufExpanderTitle': return 'I have a local GGUF file';
			case 'settings.localGguf.pickFileLabel': return 'Pick GGUF file...';
			case 'settings.localGguf.loadModelLabel': return 'Load model';
			case 'settings.localGguf.nativeContextLabel': return 'Native context';
			case 'settings.localGguf.freeVramLabel': return 'Free VRAM';
			case 'settings.localGguf.contextSizeLabel': return 'Context size';
			case 'settings.localGguf.kvCacheLabel': return 'KV cache';
			case 'settings.localGguf.kvCacheAutoLabel': return 'Auto';
			case 'settings.localGguf.modelTooLargeForVramMessage': return ({required Object neededMb, required Object freeMb}) => 'This model needs about ${neededMb}MB of GPU memory but only ${freeMb}MB is free. Close other GPU apps or pick a smaller / more-quantized model.';
			case 'settings.localGguf.modelBarelyFitsMessage': return ({required Object minimumContext}) => 'This model barely fits even with q4_0 KV cache at ${minimumContext} tokens. Consider a more-aggressively-quantized model file.';
			case 'settings.localGguf.readingMetadata': return 'Reading model metadata…';
			case 'settings.localGguf.architectureLabel': return 'Architecture';
			case 'settings.localGguf.autoKvHint': return ({required Object picked, required Object max}) => 'auto: ${picked} (max ${max})';
			case 'settings.localGguf.maxKvHint': return ({required Object max, required Object picked}) => 'max ${max} at ${picked} KV';
			case 'settings.localGguf.ctxExceedsMaxError': return ({required Object max, required Object picked}) => 'over ${max} at ${picked} KV — load may OOM';
			case 'settings.localGguf.vramNotDetected': return 'not detected';
			case 'settings.localGguf.readMetadataFailedError': return ({required Object error}) => 'Failed to read GGUF metadata: ${error}';
			case 'settings.localGguf.loadModelFailedError': return ({required Object error}) => 'Failed to load the model: ${error}';
			case 'settings.personaDialog.newTitle': return 'New Persona';
			case 'settings.personaDialog.editTitle': return 'Edit Persona';
			case 'settings.personaDialog.nameLabel': return 'Name';
			case 'settings.personaDialog.nameRequiredError': return 'Name is required';
			case 'settings.personaDialog.descriptionLabel': return 'Description';
			case 'settings.personaDialog.descriptionHint': return 'Appearance, personality, background, etc.';
			case 'settings.personasTab.cannotDeleteDefaultTooltip': return 'Cannot delete default persona';
			case 'settings.personasTab.deleteTooltip': return 'Delete Persona';
			case 'settings.personasTab.cannotDeleteDefaultSnackbar': return 'Cannot delete the default persona.';
			case 'settings.personasTab.deleteConfirmTitle': return 'Delete Persona';
			case 'settings.personasTab.deleteConfirmMessage': return ({required Object name}) => 'Are you sure you want to delete "${name}"?';
			case 'settings.updateCheck.upToDateTitle': return 'Up to Date';
			case 'settings.updateCheck.upToDateMessage': return ({required Object version}) => 'You are on the current version (${version}).';
			case 'settings.updateCheck.notApplicableTitle': return 'Update Check';
			case 'settings.updateCheck.notApplicableMessage': return 'Version check is not applicable on the Web.';
			case 'settings.updateCheck.errorTitle': return 'Error';
			case 'settings.updateCheck.serverErrorMessage': return 'Could not check for updates. Server error.';
			case 'settings.updateCheck.connectionErrorMessage': return 'Could not check for updates. Check your connection.';
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
