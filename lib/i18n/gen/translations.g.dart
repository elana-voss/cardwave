/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 9
/// Strings: 1814 (201 per locale)

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
	late final _TranslationsAppAppBootstrapperEn appBootstrapper = _TranslationsAppAppBootstrapperEn._(_root);
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
	late final _TranslationsCommonTimeAgoEn timeAgo = _TranslationsCommonTimeAgoEn._(_root);
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
	late final _TranslationsEditorEditorNodesEn editorNodes = _TranslationsEditorEditorNodesEn._(_root);
	late final _TranslationsEditorNodeListTileEn nodeListTile = _TranslationsEditorNodeListTileEn._(_root);
	late final _TranslationsEditorNodesRawEditorPageEn nodesRawEditorPage = _TranslationsEditorNodesRawEditorPageEn._(_root);
	late final _TranslationsEditorNodesCanvasViewEn nodesCanvasView = _TranslationsEditorNodesCanvasViewEn._(_root);
	late final _TranslationsEditorNodeEditorFormEn nodeEditorForm = _TranslationsEditorNodeEditorFormEn._(_root);
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
	late final _TranslationsGridTagWrapEn tagWrap = _TranslationsGridTagWrapEn._(_root);
}

// Path: group
class _TranslationsGroupEn {
	_TranslationsGroupEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _TranslationsGroupGroupGridControllerEn groupGridController = _TranslationsGroupGroupGridControllerEn._(_root);
	late final _TranslationsGroupGroupChatPageEn groupChatPage = _TranslationsGroupGroupChatPageEn._(_root);
	late final _TranslationsGroupGroupGridPageEn groupGridPage = _TranslationsGroupGroupGridPageEn._(_root);
	late final _TranslationsGroupTileAutoChatDelayEn tileAutoChatDelay = _TranslationsGroupTileAutoChatDelayEn._(_root);
	late final _TranslationsGroupTileActivationStrategyEn tileActivationStrategy = _TranslationsGroupTileActivationStrategyEn._(_root);
	late final _TranslationsGroupGroupChatPageEndDrawerEn groupChatPageEndDrawer = _TranslationsGroupGroupChatPageEndDrawerEn._(_root);
	late final _TranslationsGroupGroupCharacterPickerEn groupCharacterPicker = _TranslationsGroupGroupCharacterPickerEn._(_root);
	late final _TranslationsGroupGroupCharacterTileEn groupCharacterTile = _TranslationsGroupGroupCharacterTileEn._(_root);
	late final _TranslationsGroupDialogCreateGroupEn dialogCreateGroup = _TranslationsGroupDialogCreateGroupEn._(_root);
	late final _TranslationsGroupDialogGroupOverridesEn dialogGroupOverrides = _TranslationsGroupDialogGroupOverridesEn._(_root);
	late final _TranslationsGroupGroupCharacterPanelEn groupCharacterPanel = _TranslationsGroupGroupCharacterPanelEn._(_root);
	late final _TranslationsGroupDialogSelectGroupEn dialogSelectGroup = _TranslationsGroupDialogSelectGroupEn._(_root);
	late final _TranslationsGroupGroupGridItemEn groupGridItem = _TranslationsGroupGroupGridItemEn._(_root);
	late final _TranslationsGroupGroupFileServiceEn groupFileService = _TranslationsGroupGroupFileServiceEn._(_root);
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
	late final _TranslationsSettingsLoadingStatusEn loadingStatus = _TranslationsSettingsLoadingStatusEn._(_root);
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
	late final _TranslationsWorkspaceWorkspaceEndDrawerImageEn workspaceEndDrawerImage = _TranslationsWorkspaceWorkspaceEndDrawerImageEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerVideoEn workspaceEndDrawerVideo = _TranslationsWorkspaceWorkspaceEndDrawerVideoEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerDisplayEn workspaceEndDrawerDisplay = _TranslationsWorkspaceWorkspaceEndDrawerDisplayEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerAiEn workspaceEndDrawerAi = _TranslationsWorkspaceWorkspaceEndDrawerAiEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerEditingEn workspaceEndDrawerEditing = _TranslationsWorkspaceWorkspaceEndDrawerEditingEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerExportEn workspaceEndDrawerExport = _TranslationsWorkspaceWorkspaceEndDrawerExportEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn workspaceEndDrawerChatTheme = _TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerChatEn workspaceEndDrawerChat = _TranslationsWorkspaceWorkspaceEndDrawerChatEn._(_root);
	late final _TranslationsWorkspaceWorkspaceEndDrawerEn workspaceEndDrawer = _TranslationsWorkspaceWorkspaceEndDrawerEn._(_root);
	late final _TranslationsWorkspaceStylePresetsDialogEn stylePresetsDialog = _TranslationsWorkspaceStylePresetsDialogEn._(_root);
	late final _TranslationsWorkspaceWorkspacePageEn workspacePage = _TranslationsWorkspaceWorkspacePageEn._(_root);
}

// Path: app.appBootstrapper
class _TranslationsAppAppBootstrapperEn {
	_TranslationsAppAppBootstrapperEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String failedToInitializeMessage({required Object error}) => 'Failed to initialize app:\n\n${error}';
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
	String errorPrefix({required Object error}) => 'Error: ${error}';
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

// Path: common.timeAgo
class _TranslationsCommonTimeAgoEn {
	_TranslationsCommonTimeAgoEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String years({required Object n}) => '${n}y ago';
	String months({required Object n}) => '${n}mo ago';
	String days({required Object n}) => '${n}d ago';
	String hours({required Object n}) => '${n}h ago';
	String minutes({required Object n}) => '${n}m ago';
	String get justNow => 'Just now';
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

// Path: editor.editorNodes
class _TranslationsEditorEditorNodesEn {
	_TranslationsEditorEditorNodesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get deleteNodeTitle => 'Delete node';
	String get deleteNodeMessage => 'Remove this authored node from the card?';
	String get engineSeedTitle => 'Engine seed';
	String get visualEditorTooltip => 'Visual editor';
	String get editJsonTooltip => 'Edit JSON';
	String get initialGoalLabel => 'Initial goal';
	String get initialSceneLabel => 'Initial scene';
	String get locationLabel => 'Location';
	String get timeOfDayLabel => 'Time of day';
	String get presentEntitiesLabel => 'Present (comma-separated)';
	String get sensoryHooksLabel => 'Sensory hooks (comma-separated)';
	String get addNodeButton => 'Add Node';
	String get noAuthoredNodesYet => 'No authored nodes yet.';
	String loadErrorMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'This card\'s nodes block has ${n} problem; editing here will overwrite the broken parts on save.',
		other: 'This card\'s nodes block has ${n} problems; editing here will overwrite the broken parts on save.',
	);
	String moreErrorsSuffix({required Object n}) => '… ${n} more';
	String get emotionBaselineLabel => 'Emotion baseline';
	String get emotionChipLabel => 'Emotion';
}

// Path: editor.nodeListTile
class _TranslationsEditorNodeListTileEn {
	_TranslationsEditorNodeListTileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String spawnsLabel({required Object count}) => 'spawns: ${count}';
}

// Path: editor.nodesRawEditorPage
class _TranslationsEditorNodesRawEditorPageEn {
	_TranslationsEditorNodesRawEditorPageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get topLevelMustBeObject => 'Top level must be a JSON object';
	String get editNodesJsonTitle => 'Edit nodes JSON';
	String fixProblemsMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Fix ${n} problem to save.',
		other: 'Fix ${n} problems to save.',
	);
}

// Path: editor.nodesCanvasView
class _TranslationsEditorNodesCanvasViewEn {
	_TranslationsEditorNodesCanvasViewEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get spawnedByPort => 'spawned by';
	String get spawnsPort => 'spawns';
	String get editNodeLabel => 'Edit node';
	String get addNodeTooltip => 'Add node';
}

// Path: editor.nodeEditorForm
class _TranslationsEditorNodeEditorFormEn {
	_TranslationsEditorNodeEditorFormEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get nameLabel => 'Name';
	String get narrativePayloadLabel => 'Narrative payload';
	String get removeSpawnLinkTitle => 'Remove spawn link';
	String removeSpawnLinkMessage({required Object nodeId}) => 'Stop this node from spawning "${nodeId}"? The node itself stays on the card.';
	String get removeButton => 'Remove';
	String get typeLabel => 'Type';
	String get scopeLabel => 'Scope';
	String get originLabel => 'Origin';
	String get triggerProbLabel => 'Trigger prob';
	String get delayHelper => 'Turns to wait before becoming eligible. -1 acts as 0.';
	String get cooldownHelper => 'Turns locked out after firing. -1 means no cooldown.';
	String get stickyHelper => 'Turns the narrative payload keeps appearing as "Lingering" after firing. -1 means permanent.';
	String get aliveHelper => 'Turns the node stays in the pool before removal. -1 means forever.';
	String get setToNeverButton => 'Set to never';
	String get effectsSectionLabel => 'Effects';
	String get emotionDeltasTitle => 'Emotion deltas';
	String get physicalDeltasTitle => 'Physical deltas';
	String get relationshipDeltasTitle => 'Relationship deltas';
	String get addDeltaChip => 'Add delta';
	String get knowledgeWritesTitle => 'Knowledge writes';
	String get addFactChip => 'Add fact';
	String get topicLabel => 'topic';
	String get confidenceLabel => 'confidence';
	String get flagSetTitle => 'Flag set';
	String get addFlagChip => 'Add flag';
	String get keyLabel => 'key';
	String get sceneAndFlowTitle => 'Scene & flow';
	String get goalChangeLabel => 'goalChange (clears the current goal when empty)';
	String get phaseChangeLabel => 'phaseChange';
	String get noneOption => '(none)';
	String get sceneTransitionLabel => 'sceneTransition';
	String get sceneTransitionSubtitle => 'When true, the engine marks the firing as a scene shift.';
	String get spawnsSectionLabel => 'Spawns';
	String get addNewChip => 'Add new';
	String get linkExistingChip => 'Link existing';
	String get unlinkTooltip => 'Unlink';
	String get predicateLabel => 'Predicate';
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

// Path: grid.tagWrap
class _TranslationsGridTagWrapEn {
	_TranslationsGridTagWrapEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String tagCountLabel({required Object tag, required Object count}) => '${tag} (${count})';
}

// Path: group.groupGridController
class _TranslationsGroupGroupGridControllerEn {
	_TranslationsGroupGroupGridControllerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get renameGroupTitle => 'Rename Group';
	String get groupNameHint => 'Group name';
	String get deleteGroupTitle => 'Delete Group';
	String deleteGroupMessage({required Object name}) => 'Are you sure you want to delete "${name}"? This cannot be undone.';
}

// Path: group.groupChatPage
class _TranslationsGroupGroupChatPageEn {
	_TranslationsGroupGroupChatPageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get defaultGroupName => 'Group Chat';
	String failedToLoadMessage({required Object error}) => 'Failed to load group chat:\n${error}';
	String get nextTurnTooltip => 'Next turn';
	String get stopAutoChatTooltip => 'Stop auto-chat';
	String get startAutoChatTooltip => 'Start auto-chat';
	String get stopGenerationTooltip => 'Stop generation';
	String get noCharactersYetMessage => 'This group has no characters yet.';
	String get addCharacterButton => 'Add a character';
	String get pickCharacterMessage => 'Pick a character from the list on the left.';
}

// Path: group.groupGridPage
class _TranslationsGroupGroupGridPageEn {
	_TranslationsGroupGroupGridPageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String failedToLoadMessage({required Object error}) => 'Failed to load groups:\n${error}';
	String get unknownErrorFallback => 'unknown error';
	String get noGroupsYetMessage => 'No groups yet — tap + to create one.';
}

// Path: group.tileAutoChatDelay
class _TranslationsGroupTileAutoChatDelayEn {
	_TranslationsGroupTileAutoChatDelayEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Auto-chat delay';
	String secondsAbbrev({required Object seconds}) => '${seconds}s';
}

// Path: group.tileActivationStrategy
class _TranslationsGroupTileActivationStrategyEn {
	_TranslationsGroupTileActivationStrategyEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Speaker selection';
	String get naturalOption => 'Natural';
	String get roundRobinOption => 'Round-robin';
	String get randomOption => 'Random';
	String get changeSelectionTooltip => 'Change speaker selection';
}

// Path: group.groupChatPageEndDrawer
class _TranslationsGroupGroupChatPageEndDrawerEn {
	_TranslationsGroupGroupChatPageEndDrawerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get allowWebFetchTitle => 'Allow Web Fetch';
	String get allowWebFetchSubtitle => 'Read public web pages when relevant';
	String get reviewUrlTitle => 'Review URL Before Fetching';
	String get reviewUrlSubtitle => 'Confirm each fetch';
	String get suggestNpcNamesTitle => 'Suggest NPC Names';
	String get suggestNpcNamesSubtitle => 'Pick names from the curated database';
	String get unrestrictedImagesTitle => 'Unrestricted Images';
	String get allowNsfwImagePromptsSubtitle => 'Allow NSFW image prompts';
	String get characterCanSendSelfiesTitle => 'Character Can Send Selfies';
	String get attachSelfieWhenNaturalSubtitle => 'Attach a selfie when natural';
	String get reviewImagePromptTitle => 'Review Image Prompt';
	String get editBeforeGeneratingSubtitle => 'Edit before generating';
	String get reviewToolImagePromptsTitle => 'Review Tool Image Prompts';
	String get editToolTriggeredPromptsSubtitle => 'Edit tool-triggered prompts';
	String get allowSelfieCaptionsTitle => 'Allow Selfie Captions';
	String get captionRenderedOnImageSubtitle => 'Caption rendered on the image';
	String get groupOverridesTitle => 'Group overrides';
	String get groupOverridesSubtitle => 'Shared scenario, main prompt, example dialogue';
	String get chatSessionSubtitle => 'Chat session';
	String get allChatsLabel => 'All Chats';
	String get showImageLabel => 'Show Image';
	String get groupSectionHeader => 'Group';
	String get chatSectionHeader => 'Chat';
	String get chatThemeSectionHeader => 'Chat Theme';
	String get unrestrictedVideosTitle => 'Unrestricted Videos';
	String get allowNsfwVideoPromptsSubtitle => 'Allow NSFW video prompts';
	String get characterCanSendVideosTitle => 'Character Can Send Videos';
	String get attachShortVideoWhenNaturalSubtitle => 'Attach a short video when natural';
	String get reviewVideoPromptTitle => 'Review Video Prompt';
}

// Path: group.groupCharacterPicker
class _TranslationsGroupGroupCharacterPickerEn {
	_TranslationsGroupGroupCharacterPickerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get addButton => 'Add';
	String addWithCountButton({required Object count}) => 'Add ${count}';
	String get favoritesTooltip => 'Favorites';
	String noMatchMessage({required Object query}) => 'No characters match "${query}"';
	String get noFavoritesMessage => 'No favorited characters available';
	String get allAddedMessage => 'All characters already added';
}

// Path: group.groupCharacterTile
class _TranslationsGroupGroupCharacterTileEn {
	_TranslationsGroupGroupCharacterTileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get speakTooltip => 'Make this character speak';
	String get removeFromChatTitle => 'Remove from chat';
}

// Path: group.dialogCreateGroup
class _TranslationsGroupDialogCreateGroupEn {
	_TranslationsGroupDialogCreateGroupEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'New Group';
	String get nameLabel => 'Name';
	String get nameHint => 'e.g. Bob & Alice';
}

// Path: group.dialogGroupOverrides
class _TranslationsGroupDialogGroupOverridesEn {
	_TranslationsGroupDialogGroupOverridesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get explanationMessage => 'Unique to this chat. All group members use these values instead of what their character cards define. Leave empty to fall back to the card value.';
	String get scenarioHint => 'Shared setting for the group (e.g. "In a cafe in Paris")';
	String get mainPromptLabel => 'Main Prompt';
	String get mainPromptHint => 'System prompt applied during every turn';
	String get exampleDialogueLabel => 'Example Dialogue';
	String get exampleDialogueHint => 'Shared example messages for tone / formatting';
}

// Path: group.groupCharacterPanel
class _TranslationsGroupGroupCharacterPanelEn {
	_TranslationsGroupGroupCharacterPanelEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get addCharacterButton => 'Add Character';
	String get noCharactersYetMessage => 'No characters yet.\nTap + to add one.';
}

// Path: group.dialogSelectGroup
class _TranslationsGroupDialogSelectGroupEn {
	_TranslationsGroupDialogSelectGroupEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get deleteGroupTitle => 'Delete group?';
	String deleteGroupMessage({required Object name}) => '"${name}" and all of its chat sessions will be permanently removed.';
	String get title => 'Groups';
	String get noGroupsYetMessage => 'No groups yet. Tap "New group" to create one.';
	String memberCountLabel({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} member',
		other: '${n} members',
	);
}

// Path: group.groupGridItem
class _TranslationsGroupGroupGridItemEn {
	_TranslationsGroupGroupGridItemEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String overflowCountBadge({required Object count}) => '+${count}';
	String get noMembersYetMessage => 'No members yet';
}

// Path: group.groupFileService
class _TranslationsGroupGroupFileServiceEn {
	_TranslationsGroupGroupFileServiceEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get defaultGroupName => 'Group';
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

// Path: settings.loadingStatus
class _TranslationsSettingsLoadingStatusEn {
	_TranslationsSettingsLoadingStatusEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get restoringProviders => 'Restoring providers…';
	String fetchingModelsProgress({required Object completed, required Object total}) => 'Fetching models (${completed}/${total})…';
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

// Path: workspace.workspaceEndDrawerImage
class _TranslationsWorkspaceWorkspaceEndDrawerImageEn {
	_TranslationsWorkspaceWorkspaceEndDrawerImageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get imageStyleTitle => 'Image Style';
	String get noneValue => 'None';
}

// Path: workspace.workspaceEndDrawerVideo
class _TranslationsWorkspaceWorkspaceEndDrawerVideoEn {
	_TranslationsWorkspaceWorkspaceEndDrawerVideoEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get videoStyleTitle => 'Video Style';
}

// Path: workspace.workspaceEndDrawerDisplay
class _TranslationsWorkspaceWorkspaceEndDrawerDisplayEn {
	_TranslationsWorkspaceWorkspaceEndDrawerDisplayEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get sectionHeader => 'Display';
	String get showCharacterImageTitle => 'Show Character Image';
	String get wideScreenOnlySubtitle => 'Wide-screen editor only';
}

// Path: workspace.workspaceEndDrawerAi
class _TranslationsWorkspaceWorkspaceEndDrawerAiEn {
	_TranslationsWorkspaceWorkspaceEndDrawerAiEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get sectionHeader => 'AI';
}

// Path: workspace.workspaceEndDrawerEditing
class _TranslationsWorkspaceWorkspaceEndDrawerEditingEn {
	_TranslationsWorkspaceWorkspaceEndDrawerEditingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get sectionHeader => 'Editing';
}

// Path: workspace.workspaceEndDrawerExport
class _TranslationsWorkspaceWorkspaceEndDrawerExportEn {
	_TranslationsWorkspaceWorkspaceEndDrawerExportEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get sectionHeader => 'Export';
	String get exportPngTitle => 'Export as PNG (V2/V3)';
	String get exportJsonV3Title => 'Export as JSON (V3)';
	String get exportJsonV2Title => 'Export as JSON (V2)';
}

// Path: workspace.workspaceEndDrawerChatTheme
class _TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get resetImagesTitle => 'Reset Images';
}

// Path: workspace.workspaceEndDrawerChat
class _TranslationsWorkspaceWorkspaceEndDrawerChatEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get assistantCardEditsSectionHeader => 'Assistant Card Edits';
}

// Path: workspace.workspaceEndDrawer
class _TranslationsWorkspaceWorkspaceEndDrawerEn {
	_TranslationsWorkspaceWorkspaceEndDrawerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get favoriteLabel => 'Favorite';
	String get nodesEngineTitle => 'NODES Engine';
	String get debugSnapshotSubtitle => 'Debug snapshot';
	String get characterSubtitle => 'Character';
}

// Path: workspace.stylePresetsDialog
class _TranslationsWorkspaceStylePresetsDialogEn {
	_TranslationsWorkspaceStylePresetsDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get noStyleSelectedMessage => 'No style selected';
}

// Path: workspace.workspacePage
class _TranslationsWorkspaceWorkspacePageEn {
	_TranslationsWorkspaceWorkspacePageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get rebuildingChatIndexMessage => 'Rebuilding chat index...';
	String get selectChatToStartMessagingMessage => 'Select a chat to start messaging';
	String get failedToLoadAssistantMessage => 'Failed to load assistant.';
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
	@override late final _TranslationsMemoryEs419 memory = _TranslationsMemoryEs419._(_root);
	@override late final _TranslationsNodesEs419 nodes = _TranslationsNodesEs419._(_root);
	@override late final _TranslationsSearchEs419 search = _TranslationsSearchEs419._(_root);
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

// Path: search
class _TranslationsSearchEs419 extends _TranslationsSearchEn {
	_TranslationsSearchEs419._(_TranslationsEs419 root) : this._root = root, super._(root);

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
	@override late final _TranslationsMemoryHi memory = _TranslationsMemoryHi._(_root);
	@override late final _TranslationsNodesHi nodes = _TranslationsNodesHi._(_root);
	@override late final _TranslationsSearchHi search = _TranslationsSearchHi._(_root);
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

// Path: search
class _TranslationsSearchHi extends _TranslationsSearchEn {
	_TranslationsSearchHi._(_TranslationsHi root) : this._root = root, super._(root);

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
	@override late final _TranslationsMemoryJa memory = _TranslationsMemoryJa._(_root);
	@override late final _TranslationsNodesJa nodes = _TranslationsNodesJa._(_root);
	@override late final _TranslationsSearchJa search = _TranslationsSearchJa._(_root);
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

// Path: search
class _TranslationsSearchJa extends _TranslationsSearchEn {
	_TranslationsSearchJa._(_TranslationsJa root) : this._root = root, super._(root);

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
	@override late final _TranslationsMemoryKo memory = _TranslationsMemoryKo._(_root);
	@override late final _TranslationsNodesKo nodes = _TranslationsNodesKo._(_root);
	@override late final _TranslationsSearchKo search = _TranslationsSearchKo._(_root);
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

// Path: search
class _TranslationsSearchKo extends _TranslationsSearchEn {
	_TranslationsSearchKo._(_TranslationsKo root) : this._root = root, super._(root);

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
	@override late final _TranslationsMemoryPtBr memory = _TranslationsMemoryPtBr._(_root);
	@override late final _TranslationsNodesPtBr nodes = _TranslationsNodesPtBr._(_root);
	@override late final _TranslationsSearchPtBr search = _TranslationsSearchPtBr._(_root);
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

// Path: search
class _TranslationsSearchPtBr extends _TranslationsSearchEn {
	_TranslationsSearchPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

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
	@override late final _TranslationsAppAppBootstrapperRu appBootstrapper = _TranslationsAppAppBootstrapperRu._(_root);
}

// Path: character
class _TranslationsCharacterRu extends _TranslationsCharacterEn {
	_TranslationsCharacterRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsCharacterPromptPrefixDialogRu promptPrefixDialog = _TranslationsCharacterPromptPrefixDialogRu._(_root);
	@override late final _TranslationsCharacterCardEditApprovalRu cardEditApproval = _TranslationsCharacterCardEditApprovalRu._(_root);
	@override late final _TranslationsCharacterRequireApprovalTileRu requireApprovalTile = _TranslationsCharacterRequireApprovalTileRu._(_root);
	@override late final _TranslationsCharacterLoadingStatusRu loadingStatus = _TranslationsCharacterLoadingStatusRu._(_root);
	@override late final _TranslationsCharacterSavePathValidationRu savePathValidation = _TranslationsCharacterSavePathValidationRu._(_root);
	@override String get characterFilesTypeGroupLabel => 'Файлы персонажей';
	@override late final _TranslationsCharacterCreateControllerRu createController = _TranslationsCharacterCreateControllerRu._(_root);
	@override late final _TranslationsCharacterImportControllerRu importController = _TranslationsCharacterImportControllerRu._(_root);
	@override late final _TranslationsCharacterAiActionControllerRu aiActionController = _TranslationsCharacterAiActionControllerRu._(_root);
}

// Path: chat
class _TranslationsChatRu extends _TranslationsChatEn {
	_TranslationsChatRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsChatTileAiProviderRu tileAiProvider = _TranslationsChatTileAiProviderRu._(_root);
	@override late final _TranslationsChatPresetTileRu presetTile = _TranslationsChatPresetTileRu._(_root);
	@override late final _TranslationsChatTileImagePresetRu tileImagePreset = _TranslationsChatTileImagePresetRu._(_root);
	@override late final _TranslationsChatTileVideoPresetRu tileVideoPreset = _TranslationsChatTileVideoPresetRu._(_root);
	@override late final _TranslationsChatTileTtsPresetRu tileTtsPreset = _TranslationsChatTileTtsPresetRu._(_root);
	@override late final _TranslationsChatTileImageAspectRatioRu tileImageAspectRatio = _TranslationsChatTileImageAspectRatioRu._(_root);
	@override late final _TranslationsChatTileVideoAspectRatioRu tileVideoAspectRatio = _TranslationsChatTileVideoAspectRatioRu._(_root);
	@override late final _TranslationsChatTileVideoResolutionRu tileVideoResolution = _TranslationsChatTileVideoResolutionRu._(_root);
	@override late final _TranslationsChatTileVideoDurationRu tileVideoDuration = _TranslationsChatTileVideoDurationRu._(_root);
	@override late final _TranslationsChatTileTtsVoiceRu tileTtsVoice = _TranslationsChatTileTtsVoiceRu._(_root);
	@override late final _TranslationsChatTileTtsLanguageRu tileTtsLanguage = _TranslationsChatTileTtsLanguageRu._(_root);
	@override late final _TranslationsChatTileNsfwRu tileNsfw = _TranslationsChatTileNsfwRu._(_root);
	@override late final _TranslationsChatTileScenarioRu tileScenario = _TranslationsChatTileScenarioRu._(_root);
	@override late final _TranslationsChatTileMaxResponseLengthRu tileMaxResponseLength = _TranslationsChatTileMaxResponseLengthRu._(_root);
	@override late final _TranslationsChatTileTrailingParagraphRu tileTrailingParagraph = _TranslationsChatTileTrailingParagraphRu._(_root);
	@override late final _TranslationsChatTileReasoningEffortRu tileReasoningEffort = _TranslationsChatTileReasoningEffortRu._(_root);
	@override late final _TranslationsChatTileChatThemeRu tileChatTheme = _TranslationsChatTileChatThemeRu._(_root);
	@override late final _TranslationsChatTileRecalledMemoryRu tileRecalledMemory = _TranslationsChatTileRecalledMemoryRu._(_root);
	@override late final _TranslationsChatCharacterSwitcherRu characterSwitcher = _TranslationsChatCharacterSwitcherRu._(_root);
	@override late final _TranslationsChatFreeImagePromptDialogRu freeImagePromptDialog = _TranslationsChatFreeImagePromptDialogRu._(_root);
	@override late final _TranslationsChatFreeVideoPromptDialogRu freeVideoPromptDialog = _TranslationsChatFreeVideoPromptDialogRu._(_root);
	@override late final _TranslationsChatImagePromptReviewDialogRu imagePromptReviewDialog = _TranslationsChatImagePromptReviewDialogRu._(_root);
	@override late final _TranslationsChatVideoPromptReviewDialogRu videoPromptReviewDialog = _TranslationsChatVideoPromptReviewDialogRu._(_root);
	@override late final _TranslationsChatUrlFetchReviewDialogRu urlFetchReviewDialog = _TranslationsChatUrlFetchReviewDialogRu._(_root);
	@override late final _TranslationsChatMessageActionsRowRu messageActionsRow = _TranslationsChatMessageActionsRowRu._(_root);
	@override late final _TranslationsChatTtsPlayButtonRu ttsPlayButton = _TranslationsChatTtsPlayButtonRu._(_root);
	@override late final _TranslationsChatMessageSwipeFlipperRu messageSwipeFlipper = _TranslationsChatMessageSwipeFlipperRu._(_root);
	@override late final _TranslationsChatVideoPlayerInlineRu videoPlayerInline = _TranslationsChatVideoPlayerInlineRu._(_root);
	@override String get newChatLabel => 'Новый чат';
	@override late final _TranslationsChatChatListItemRu chatListItem = _TranslationsChatChatListItemRu._(_root);
	@override late final _TranslationsChatChatHistoryControllerRu chatHistoryController = _TranslationsChatChatHistoryControllerRu._(_root);
	@override late final _TranslationsChatChatPageControllerRu chatPageController = _TranslationsChatChatPageControllerRu._(_root);
	@override late final _TranslationsChatImageGenerationMixinRu imageGenerationMixin = _TranslationsChatImageGenerationMixinRu._(_root);
	@override late final _TranslationsChatVideoGenerationMixinRu videoGenerationMixin = _TranslationsChatVideoGenerationMixinRu._(_root);
	@override late final _TranslationsChatBubbleWaitingForRu bubbleWaitingFor = _TranslationsChatBubbleWaitingForRu._(_root);
	@override late final _TranslationsChatAppBarChatRu appBarChat = _TranslationsChatAppBarChatRu._(_root);
	@override late final _TranslationsChatAllChatsDrawerListRu allChatsDrawerList = _TranslationsChatAllChatsDrawerListRu._(_root);
	@override late final _TranslationsChatChatInputMediaMenuRu chatInputMediaMenu = _TranslationsChatChatInputMediaMenuRu._(_root);
	@override late final _TranslationsChatChatViewRu chatView = _TranslationsChatChatViewRu._(_root);
	@override late final _TranslationsChatChatMessageBubbleRu chatMessageBubble = _TranslationsChatChatMessageBubbleRu._(_root);
}

// Path: common
class _TranslationsCommonRu extends _TranslationsCommonEn {
	_TranslationsCommonRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsCommonActionsRu actions = _TranslationsCommonActionsRu._(_root);
	@override late final _TranslationsCommonAiActionRu aiAction = _TranslationsCommonAiActionRu._(_root);
	@override String get aiActionsTooltip => 'Действия ИИ';
	@override late final _TranslationsCommonPromptSegmentKindRu promptSegmentKind = _TranslationsCommonPromptSegmentKindRu._(_root);
	@override late final _TranslationsCommonPromptBreakdownRu promptBreakdown = _TranslationsCommonPromptBreakdownRu._(_root);
	@override late final _TranslationsCommonLogsRu logs = _TranslationsCommonLogsRu._(_root);
	@override late final _TranslationsCommonImportErrorsDialogRu importErrorsDialog = _TranslationsCommonImportErrorsDialogRu._(_root);
	@override late final _TranslationsCommonUpdateDialogRu updateDialog = _TranslationsCommonUpdateDialogRu._(_root);
	@override late final _TranslationsCommonImportConflictsDialogRu importConflictsDialog = _TranslationsCommonImportConflictsDialogRu._(_root);
	@override late final _TranslationsCommonMissingProviderBannerRu missingProviderBanner = _TranslationsCommonMissingProviderBannerRu._(_root);
	@override late final _TranslationsCommonModelSelectionDialogRu modelSelectionDialog = _TranslationsCommonModelSelectionDialogRu._(_root);
	@override late final _TranslationsCommonShowAdvancedRu showAdvanced = _TranslationsCommonShowAdvancedRu._(_root);
	@override late final _TranslationsCommonMessageEditDialogRu messageEditDialog = _TranslationsCommonMessageEditDialogRu._(_root);
	@override late final _TranslationsCommonPromptBreakdownDialogRu promptBreakdownDialog = _TranslationsCommonPromptBreakdownDialogRu._(_root);
	@override late final _TranslationsCommonJsonPromptDialogRu jsonPromptDialog = _TranslationsCommonJsonPromptDialogRu._(_root);
	@override late final _TranslationsCommonProgressDialogRu progressDialog = _TranslationsCommonProgressDialogRu._(_root);
	@override late final _TranslationsCommonDiffPanelRu diffPanel = _TranslationsCommonDiffPanelRu._(_root);
	@override late final _TranslationsCommonSelectionDialogRu selectionDialog = _TranslationsCommonSelectionDialogRu._(_root);
	@override late final _TranslationsCommonZdrSwitchRu zdrSwitch = _TranslationsCommonZdrSwitchRu._(_root);
	@override late final _TranslationsCommonTextFieldCardRu textFieldCard = _TranslationsCommonTextFieldCardRu._(_root);
	@override late final _TranslationsCommonModelCapabilityRu modelCapability = _TranslationsCommonModelCapabilityRu._(_root);
	@override String get modelUnavailableTooltip => 'Эта модель больше недоступна у провайдера — выберите другую.';
	@override String get characterImageSemanticLabel => 'Изображение персонажа';
	@override late final _TranslationsCommonAppConstantsRu appConstants = _TranslationsCommonAppConstantsRu._(_root);
	@override late final _TranslationsCommonTimeAgoRu timeAgo = _TranslationsCommonTimeAgoRu._(_root);
}

// Path: editor
class _TranslationsEditorRu extends _TranslationsEditorEn {
	_TranslationsEditorRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsEditorPanelLabelsRu panelLabels = _TranslationsEditorPanelLabelsRu._(_root);
	@override late final _TranslationsEditorAppBarEditorRu appBarEditor = _TranslationsEditorAppBarEditorRu._(_root);
	@override late final _TranslationsEditorCodeFindPanelRu codeFindPanel = _TranslationsEditorCodeFindPanelRu._(_root);
	@override late final _TranslationsEditorFindReplaceDialogRu findReplaceDialog = _TranslationsEditorFindReplaceDialogRu._(_root);
	@override late final _TranslationsEditorObjectValueEditorRu objectValueEditor = _TranslationsEditorObjectValueEditorRu._(_root);
	@override late final _TranslationsEditorEditorBasicRu editorBasic = _TranslationsEditorEditorBasicRu._(_root);
	@override late final _TranslationsEditorEditorCreatorMetadataRu editorCreatorMetadata = _TranslationsEditorEditorCreatorMetadataRu._(_root);
	@override late final _TranslationsEditorEditorPromptsRu editorPrompts = _TranslationsEditorEditorPromptsRu._(_root);
	@override late final _TranslationsEditorEditorAppDataRu editorAppData = _TranslationsEditorEditorAppDataRu._(_root);
	@override late final _TranslationsEditorEditorAlternateGreetingsRu editorAlternateGreetings = _TranslationsEditorEditorAlternateGreetingsRu._(_root);
	@override late final _TranslationsEditorEditorGroupGreetingsRu editorGroupGreetings = _TranslationsEditorEditorGroupGreetingsRu._(_root);
	@override late final _TranslationsEditorEditorLorebookRu editorLorebook = _TranslationsEditorEditorLorebookRu._(_root);
	@override late final _TranslationsEditorLorebookEntryListTileRu lorebookEntryListTile = _TranslationsEditorLorebookEntryListTileRu._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorPageRu lorebookEntryEditorPage = _TranslationsEditorLorebookEntryEditorPageRu._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorTopSectionRu lorebookEntryEditorTopSection = _TranslationsEditorLorebookEntryEditorTopSectionRu._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorScanRowRu lorebookEntryEditorScanRow = _TranslationsEditorLorebookEntryEditorScanRowRu._(_root);
	@override late final _TranslationsEditorDialogContentCleanerRu dialogContentCleaner = _TranslationsEditorDialogContentCleanerRu._(_root);
	@override late final _TranslationsEditorDialogAiDiffConfirmationRu dialogAiDiffConfirmation = _TranslationsEditorDialogAiDiffConfirmationRu._(_root);
	@override late final _TranslationsEditorEditorPageControllerRu editorPageController = _TranslationsEditorEditorPageControllerRu._(_root);
	@override late final _TranslationsEditorEditorNodesRu editorNodes = _TranslationsEditorEditorNodesRu._(_root);
	@override late final _TranslationsEditorNodeListTileRu nodeListTile = _TranslationsEditorNodeListTileRu._(_root);
	@override late final _TranslationsEditorNodesRawEditorPageRu nodesRawEditorPage = _TranslationsEditorNodesRawEditorPageRu._(_root);
	@override late final _TranslationsEditorNodesCanvasViewRu nodesCanvasView = _TranslationsEditorNodesCanvasViewRu._(_root);
	@override late final _TranslationsEditorNodeEditorFormRu nodeEditorForm = _TranslationsEditorNodeEditorFormRu._(_root);
}

// Path: grid
class _TranslationsGridRu extends _TranslationsGridEn {
	_TranslationsGridRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsGridEmptyStateRu emptyState = _TranslationsGridEmptyStateRu._(_root);
	@override late final _TranslationsGridAppBarRu appBar = _TranslationsGridAppBarRu._(_root);
	@override late final _TranslationsGridFabRu fab = _TranslationsGridFabRu._(_root);
	@override late final _TranslationsGridDrawerRu drawer = _TranslationsGridDrawerRu._(_root);
	@override late final _TranslationsGridVariantBadgeRu variantBadge = _TranslationsGridVariantBadgeRu._(_root);
	@override late final _TranslationsGridDialogActionsRu dialogActions = _TranslationsGridDialogActionsRu._(_root);
	@override late final _TranslationsGridTagFilterDialogRu tagFilterDialog = _TranslationsGridTagFilterDialogRu._(_root);
	@override late final _TranslationsGridFiltersRu filters = _TranslationsGridFiltersRu._(_root);
	@override late final _TranslationsGridSortOptionRu sortOption = _TranslationsGridSortOptionRu._(_root);
	@override late final _TranslationsGridFilterControllerRu filterController = _TranslationsGridFilterControllerRu._(_root);
	@override late final _TranslationsGridMultiSelectDialogRu multiSelectDialog = _TranslationsGridMultiSelectDialogRu._(_root);
	@override late final _TranslationsGridCreateCharacterDialogRu createCharacterDialog = _TranslationsGridCreateCharacterDialogRu._(_root);
	@override late final _TranslationsGridVariantsSheetRu variantsSheet = _TranslationsGridVariantsSheetRu._(_root);
	@override late final _TranslationsGridGroupAppBarRu groupAppBar = _TranslationsGridGroupAppBarRu._(_root);
	@override late final _TranslationsGridThumbnailBadgesRu thumbnailBadges = _TranslationsGridThumbnailBadgesRu._(_root);
	@override late final _TranslationsGridActionMenuRu actionMenu = _TranslationsGridActionMenuRu._(_root);
	@override late final _TranslationsGridControllerMessagesRu controllerMessages = _TranslationsGridControllerMessagesRu._(_root);
	@override late final _TranslationsGridTagWrapRu tagWrap = _TranslationsGridTagWrapRu._(_root);
}

// Path: group
class _TranslationsGroupRu extends _TranslationsGroupEn {
	_TranslationsGroupRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsGroupGroupGridControllerRu groupGridController = _TranslationsGroupGroupGridControllerRu._(_root);
	@override late final _TranslationsGroupGroupChatPageRu groupChatPage = _TranslationsGroupGroupChatPageRu._(_root);
	@override late final _TranslationsGroupGroupGridPageRu groupGridPage = _TranslationsGroupGroupGridPageRu._(_root);
	@override late final _TranslationsGroupTileAutoChatDelayRu tileAutoChatDelay = _TranslationsGroupTileAutoChatDelayRu._(_root);
	@override late final _TranslationsGroupTileActivationStrategyRu tileActivationStrategy = _TranslationsGroupTileActivationStrategyRu._(_root);
	@override late final _TranslationsGroupGroupChatPageEndDrawerRu groupChatPageEndDrawer = _TranslationsGroupGroupChatPageEndDrawerRu._(_root);
	@override late final _TranslationsGroupGroupCharacterPickerRu groupCharacterPicker = _TranslationsGroupGroupCharacterPickerRu._(_root);
	@override late final _TranslationsGroupGroupCharacterTileRu groupCharacterTile = _TranslationsGroupGroupCharacterTileRu._(_root);
	@override late final _TranslationsGroupDialogCreateGroupRu dialogCreateGroup = _TranslationsGroupDialogCreateGroupRu._(_root);
	@override late final _TranslationsGroupDialogGroupOverridesRu dialogGroupOverrides = _TranslationsGroupDialogGroupOverridesRu._(_root);
	@override late final _TranslationsGroupGroupCharacterPanelRu groupCharacterPanel = _TranslationsGroupGroupCharacterPanelRu._(_root);
	@override late final _TranslationsGroupDialogSelectGroupRu dialogSelectGroup = _TranslationsGroupDialogSelectGroupRu._(_root);
	@override late final _TranslationsGroupGroupGridItemRu groupGridItem = _TranslationsGroupGroupGridItemRu._(_root);
	@override late final _TranslationsGroupGroupFileServiceRu groupFileService = _TranslationsGroupGroupFileServiceRu._(_root);
}

// Path: llmApp
class _TranslationsLlmAppRu extends _TranslationsLlmAppEn {
	_TranslationsLlmAppRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLlmAppMediaFieldRu mediaField = _TranslationsLlmAppMediaFieldRu._(_root);
	@override late final _TranslationsLlmAppMediaSectionRu mediaSection = _TranslationsLlmAppMediaSectionRu._(_root);
	@override late final _TranslationsLlmAppTristateRu tristate = _TranslationsLlmAppTristateRu._(_root);
	@override late final _TranslationsLlmAppMediaCellMenuRu mediaCellMenu = _TranslationsLlmAppMediaCellMenuRu._(_root);
	@override late final _TranslationsLlmAppMediaHeaderRu mediaHeader = _TranslationsLlmAppMediaHeaderRu._(_root);
	@override late final _TranslationsLlmAppPresetRowRu presetRow = _TranslationsLlmAppPresetRowRu._(_root);
	@override late final _TranslationsLlmAppMediaCellRu mediaCell = _TranslationsLlmAppMediaCellRu._(_root);
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
	@override String get finishFailedSnackbar => 'Не удалось завершить настройку. Подробности в логах.';
	@override String get appBarTitle => 'Быстрая настройка';
	@override String get webWarning => 'Экспериментальная веб-сборка — хранилище браузера может сбрасываться между обновлениями. Для постоянного хранения данных используйте десктоп или Android.';
	@override String get finishButton => 'Завершить настройку';
	@override String get nextButton => 'Далее';
	@override String get backButton => 'Назад';
	@override late final _TranslationsOnboardingStorageStepRu storageStep = _TranslationsOnboardingStorageStepRu._(_root);
	@override late final _TranslationsOnboardingSetupStepRu setupStep = _TranslationsOnboardingSetupStepRu._(_root);
	@override late final _TranslationsOnboardingAiSectionRu aiSection = _TranslationsOnboardingAiSectionRu._(_root);
	@override late final _TranslationsOnboardingAiStatusRu aiStatus = _TranslationsOnboardingAiStatusRu._(_root);
	@override late final _TranslationsOnboardingPersonaSectionRu personaSection = _TranslationsOnboardingPersonaSectionRu._(_root);
	@override late final _TranslationsOnboardingDisclaimerRu disclaimer = _TranslationsOnboardingDisclaimerRu._(_root);
	@override late final _TranslationsOnboardingFetchErrorRu fetchError = _TranslationsOnboardingFetchErrorRu._(_root);
}

// Path: routing
class _TranslationsRoutingRu extends _TranslationsRoutingEn {
	_TranslationsRoutingRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsRoutingChatCharacterRu chatCharacter = _TranslationsRoutingChatCharacterRu._(_root);
	@override late final _TranslationsRoutingEditCharacterRu editCharacter = _TranslationsRoutingEditCharacterRu._(_root);
	@override late final _TranslationsRoutingEditPresetRu editPreset = _TranslationsRoutingEditPresetRu._(_root);
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
	@override String get gearLanguage => 'Язык';
	@override String get languageSystemDefault => 'Системный по умолчанию';
	@override late final _TranslationsSettingsGearMenuRu gearMenu = _TranslationsSettingsGearMenuRu._(_root);
	@override late final _TranslationsSettingsMediaDefaultsDrawerEntryRu mediaDefaultsDrawerEntry = _TranslationsSettingsMediaDefaultsDrawerEntryRu._(_root);
	@override late final _TranslationsSettingsEndDrawerRu endDrawer = _TranslationsSettingsEndDrawerRu._(_root);
	@override late final _TranslationsSettingsLoadingStatusRu loadingStatus = _TranslationsSettingsLoadingStatusRu._(_root);
	@override late final _TranslationsSettingsGeneralRu general = _TranslationsSettingsGeneralRu._(_root);
	@override late final _TranslationsSettingsAiSettingsTabRu aiSettingsTab = _TranslationsSettingsAiSettingsTabRu._(_root);
	@override late final _TranslationsSettingsAiTabRu aiTab = _TranslationsSettingsAiTabRu._(_root);
	@override late final _TranslationsSettingsPresetConfigRu presetConfig = _TranslationsSettingsPresetConfigRu._(_root);
	@override late final _TranslationsSettingsProviderConfigRu providerConfig = _TranslationsSettingsProviderConfigRu._(_root);
	@override late final _TranslationsSettingsLocalProviderConfigRu localProviderConfig = _TranslationsSettingsLocalProviderConfigRu._(_root);
	@override late final _TranslationsSettingsLocalGgufRu localGguf = _TranslationsSettingsLocalGgufRu._(_root);
	@override late final _TranslationsSettingsPersonaDialogRu personaDialog = _TranslationsSettingsPersonaDialogRu._(_root);
	@override late final _TranslationsSettingsPersonasTabRu personasTab = _TranslationsSettingsPersonasTabRu._(_root);
	@override late final _TranslationsSettingsUpdateCheckRu updateCheck = _TranslationsSettingsUpdateCheckRu._(_root);
}

// Path: workspace
class _TranslationsWorkspaceRu extends _TranslationsWorkspaceEn {
	_TranslationsWorkspaceRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerImageRu workspaceEndDrawerImage = _TranslationsWorkspaceWorkspaceEndDrawerImageRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerVideoRu workspaceEndDrawerVideo = _TranslationsWorkspaceWorkspaceEndDrawerVideoRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerDisplayRu workspaceEndDrawerDisplay = _TranslationsWorkspaceWorkspaceEndDrawerDisplayRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerAiRu workspaceEndDrawerAi = _TranslationsWorkspaceWorkspaceEndDrawerAiRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerEditingRu workspaceEndDrawerEditing = _TranslationsWorkspaceWorkspaceEndDrawerEditingRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerExportRu workspaceEndDrawerExport = _TranslationsWorkspaceWorkspaceEndDrawerExportRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerChatThemeRu workspaceEndDrawerChatTheme = _TranslationsWorkspaceWorkspaceEndDrawerChatThemeRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerChatRu workspaceEndDrawerChat = _TranslationsWorkspaceWorkspaceEndDrawerChatRu._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerRu workspaceEndDrawer = _TranslationsWorkspaceWorkspaceEndDrawerRu._(_root);
	@override late final _TranslationsWorkspaceStylePresetsDialogRu stylePresetsDialog = _TranslationsWorkspaceStylePresetsDialogRu._(_root);
	@override late final _TranslationsWorkspaceWorkspacePageRu workspacePage = _TranslationsWorkspaceWorkspacePageRu._(_root);
}

// Path: app.appBootstrapper
class _TranslationsAppAppBootstrapperRu extends _TranslationsAppAppBootstrapperEn {
	_TranslationsAppAppBootstrapperRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String failedToInitializeMessage({required Object error}) => 'Не удалось запустить приложение:\n\n${error}';
}

// Path: character.promptPrefixDialog
class _TranslationsCharacterPromptPrefixDialogRu extends _TranslationsCharacterPromptPrefixDialogEn {
	_TranslationsCharacterPromptPrefixDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get styleKeywordsLabel => 'Ключевые слова стиля';
	@override String get imageTitle => 'Стиль изображения';
	@override String get imageDescription => 'Добавляется в начало каждого промпта генерации изображения для этого персонажа (например, «стиль аниме, яркие цвета»).';
	@override String get imageHint => 'стиль аниме, яркие цвета';
	@override String get videoTitle => 'Стиль видео';
	@override String get videoDescription => 'Добавляется в начало каждого промпта генерации видео для этого персонажа (например, «кинематографично, малая глубина резкости, зерно плёнки 24 к/с»). Видеомодели реагируют на лексику движения и камеры; пишите кратко.';
	@override String get videoHint => 'кинематографично, малая глубина резкости';
}

// Path: character.cardEditApproval
class _TranslationsCharacterCardEditApprovalRu extends _TranslationsCharacterCardEditApprovalEn {
	_TranslationsCharacterCardEditApprovalRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get denyAll => 'Отклонить все';
	@override String get approveAll => 'Одобрить все';
	@override String get confirm => 'Подтвердить';
	@override String get dialogTitle => 'Ассистент предложил изменения';
	@override String dontAskAgainFor({required Object modality}) => 'Не спрашивать снова для «${modality}»';
	@override late final _TranslationsCharacterCardEditApprovalModalityLabelRu modalityLabel = _TranslationsCharacterCardEditApprovalModalityLabelRu._(_root);
	@override late final _TranslationsCharacterCardEditApprovalModalityVerbRu modalityVerb = _TranslationsCharacterCardEditApprovalModalityVerbRu._(_root);
	@override String get tapToDeny => 'Нажмите, чтобы отклонить';
	@override String get tapToApprove => 'Нажмите, чтобы одобрить';
	@override String get reasonLabel => 'Причина (необязательно, отправляется обратно ассистенту)';
	@override String get newEntryTitle => 'Новая запись';
	@override String get removingTitle => 'Удаление';
	@override String get beforeTitle => 'До';
	@override String get afterTitle => 'После';
}

// Path: character.requireApprovalTile
class _TranslationsCharacterRequireApprovalTileRu extends _TranslationsCharacterRequireApprovalTileEn {
	_TranslationsCharacterRequireApprovalTileRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get edits => 'Требовать одобрения: правки';
	@override String get additions => 'Требовать одобрения: добавления';
	@override String get deletions => 'Требовать одобрения: удаления';
}

// Path: character.loadingStatus
class _TranslationsCharacterLoadingStatusRu extends _TranslationsCharacterLoadingStatusEn {
	_TranslationsCharacterLoadingStatusRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get initial => 'Загрузка...';
	@override String get copyingAssistant => 'Копирование ассистента...';
	@override String get scanningForCharacters => 'Поиск персонажей...';
	@override String scanningForCharactersProgress({required Object current, required Object total}) => 'Поиск персонажей...\n${current} / ${total}';
	@override String loadingCharactersProgress({required Object current, required Object total}) => 'Загрузка персонажей...\n${current} / ${total}';
}

// Path: character.savePathValidation
class _TranslationsCharacterSavePathValidationRu extends _TranslationsCharacterSavePathValidationEn {
	_TranslationsCharacterSavePathValidationRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noLibraryFolder => 'Папка библиотеки не настроена.';
	@override String get mustBeInsideLibrary => 'Персонажей нужно сохранять внутри папки библиотеки.';
}

// Path: character.createController
class _TranslationsCharacterCreateControllerRu extends _TranslationsCharacterCreateControllerEn {
	_TranslationsCharacterCreateControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get pngImagesTypeGroupLabel => 'Изображения PNG';
	@override String get invalidLocationTitle => 'Недопустимое расположение';
	@override String get creationFailedTitle => 'Не удалось создать';
	@override String get creationFailedMessage => 'Не удалось создать персонажа. Подробности в логах.';
}

// Path: character.importController
class _TranslationsCharacterImportControllerRu extends _TranslationsCharacterImportControllerEn {
	_TranslationsCharacterImportControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String failedToImport({required Object fileName}) => 'Не удалось импортировать ${fileName}.';
	@override String importedCount({required Object count}) => 'Импортировано персонажей: ${count}';
}

// Path: character.aiActionController
class _TranslationsCharacterAiActionControllerRu extends _TranslationsCharacterAiActionControllerEn {
	_TranslationsCharacterAiActionControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get aiActionFailed => 'Действие ИИ не выполнено. Подробности в логах.';
	@override String processingProgress({required Object name, required Object current, required Object total, required Object eta}) => 'Обработка ${name} (${current}/${total})...${eta}';
	@override String etaHoursMinutes({required Object hours, required Object minutes}) => ' Осталось: ${hours} ч ${minutes} мин';
	@override String etaMinutesSeconds({required Object minutes, required Object seconds}) => ' Осталось: ${minutes} мин ${seconds} с';
	@override String etaSeconds({required Object seconds}) => ' Осталось: ${seconds} с';
	@override String processingField({required Object fieldName}) => 'Обработка «${fieldName}»...';
}

// Path: chat.tileAiProvider
class _TranslationsChatTileAiProviderRu extends _TranslationsChatTileAiProviderEn {
	_TranslationsChatTileAiProviderRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get modelLabel => 'Модель';
	@override String get invalidLabel => 'Недопустимо';
	@override String get chooseModelTitle => 'Выберите модель';
}

// Path: chat.presetTile
class _TranslationsChatPresetTileRu extends _TranslationsChatPresetTileEn {
	_TranslationsChatPresetTileRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get tapToChoose => 'Нажмите, чтобы выбрать';
}

// Path: chat.tileImagePreset
class _TranslationsChatTileImagePresetRu extends _TranslationsChatTileImagePresetEn {
	_TranslationsChatTileImagePresetRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Модель изображений';
	@override String get chooseModelTitle => 'Выберите модель изображений';
}

// Path: chat.tileVideoPreset
class _TranslationsChatTileVideoPresetRu extends _TranslationsChatTileVideoPresetEn {
	_TranslationsChatTileVideoPresetRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Модель видео';
	@override String get chooseModelTitle => 'Выберите модель видео';
}

// Path: chat.tileTtsPreset
class _TranslationsChatTileTtsPresetRu extends _TranslationsChatTileTtsPresetEn {
	_TranslationsChatTileTtsPresetRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Модель речи';
	@override String get chooseModelTitle => 'Выберите модель речи';
}

// Path: chat.tileImageAspectRatio
class _TranslationsChatTileImageAspectRatioRu extends _TranslationsChatTileImageAspectRatioEn {
	_TranslationsChatTileImageAspectRatioRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Соотношение сторон изображения';
}

// Path: chat.tileVideoAspectRatio
class _TranslationsChatTileVideoAspectRatioRu extends _TranslationsChatTileVideoAspectRatioEn {
	_TranslationsChatTileVideoAspectRatioRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Соотношение сторон';
}

// Path: chat.tileVideoResolution
class _TranslationsChatTileVideoResolutionRu extends _TranslationsChatTileVideoResolutionEn {
	_TranslationsChatTileVideoResolutionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Разрешение';
}

// Path: chat.tileVideoDuration
class _TranslationsChatTileVideoDurationRu extends _TranslationsChatTileVideoDurationEn {
	_TranslationsChatTileVideoDurationRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Длительность';
}

// Path: chat.tileTtsVoice
class _TranslationsChatTileTtsVoiceRu extends _TranslationsChatTileTtsVoiceEn {
	_TranslationsChatTileTtsVoiceRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Голос';
}

// Path: chat.tileTtsLanguage
class _TranslationsChatTileTtsLanguageRu extends _TranslationsChatTileTtsLanguageEn {
	_TranslationsChatTileTtsLanguageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Язык';
}

// Path: chat.tileNsfw
class _TranslationsChatTileNsfwRu extends _TranslationsChatTileNsfwEn {
	_TranslationsChatTileNsfwRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'NSFW / Без ограничений';
}

// Path: chat.tileScenario
class _TranslationsChatTileScenarioRu extends _TranslationsChatTileScenarioEn {
	_TranslationsChatTileScenarioRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Сценарий';
}

// Path: chat.tileMaxResponseLength
class _TranslationsChatTileMaxResponseLengthRu extends _TranslationsChatTileMaxResponseLengthEn {
	_TranslationsChatTileMaxResponseLengthRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String titleWithBucket({required Object bucket}) => 'Длина ответа — ${bucket}';
	@override String sliderLabel({required Object bucket, required Object tokens}) => '${bucket} (${tokens} токенов)';
	@override String get bucketVeryShort => 'Очень короткий';
	@override String get bucketShort => 'Короткий';
	@override String get bucketMedium => 'Средний';
	@override String get bucketLong => 'Длинный';
	@override String get bucketVeryLong => 'Очень длинный';
}

// Path: chat.tileTrailingParagraph
class _TranslationsChatTileTrailingParagraphRu extends _TranslationsChatTileTrailingParagraphEn {
	_TranslationsChatTileTrailingParagraphRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Обрезать хвост текста';
}

// Path: chat.tileReasoningEffort
class _TranslationsChatTileReasoningEffortRu extends _TranslationsChatTileReasoningEffortEn {
	_TranslationsChatTileReasoningEffortRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String titleWithEffort({required Object effort}) => 'Рассуждения — ${effort}';
	@override String get titleOff => 'Рассуждения выключены';
	@override String get extraTokensCaption => 'Использует дополнительные токены сверх максимальной длины ответа.';
}

// Path: chat.tileChatTheme
class _TranslationsChatTileChatThemeRu extends _TranslationsChatTileChatThemeEn {
	_TranslationsChatTileChatThemeRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Тема';
}

// Path: chat.tileRecalledMemory
class _TranslationsChatTileRecalledMemoryRu extends _TranslationsChatTileRecalledMemoryEn {
	_TranslationsChatTileRecalledMemoryRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get label => 'Показывать вызванную память';
}

// Path: chat.characterSwitcher
class _TranslationsChatCharacterSwitcherRu extends _TranslationsChatCharacterSwitcherEn {
	_TranslationsChatCharacterSwitcherRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get favoritesTooltip => 'Избранное';
	@override String get recentChatsTooltip => 'Недавние чаты';
	@override String get originalBadge => 'ОРИГИНАЛ';
	@override String get variantBadge => 'ВАРИАНТ';
	@override String lastActive({required Object timeAgo}) => 'Последняя активность: ${timeAgo}';
	@override String get never => 'Никогда';
}

// Path: chat.freeImagePromptDialog
class _TranslationsChatFreeImagePromptDialogRu extends _TranslationsChatFreeImagePromptDialogEn {
	_TranslationsChatFreeImagePromptDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Сгенерировать изображение';
	@override String get description => 'Опишите, что вы хотите увидеть. Достаточно короткой фразы — модель развернёт её в полный список тегов.';
	@override String get subjectLabel => 'Тема';
	@override String get subjectHint => 'киберпанк-переулок, неоновый дождь';
	@override String get generateButton => 'Сгенерировать';
}

// Path: chat.freeVideoPromptDialog
class _TranslationsChatFreeVideoPromptDialogRu extends _TranslationsChatFreeVideoPromptDialogEn {
	_TranslationsChatFreeVideoPromptDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Сгенерировать видео';
	@override String get description => 'Опишите короткий момент движения — что движется, как, где. Системная модель развернёт это в кинематографичный промпт T2V.';
	@override String get subjectLabel => 'Тема';
	@override String get subjectHint => 'она идёт сквозь неоновый дождь, замедленная съёмка';
	@override String get generateButton => 'Сгенерировать';
}

// Path: chat.imagePromptReviewDialog
class _TranslationsChatImagePromptReviewDialogRu extends _TranslationsChatImagePromptReviewDialogEn {
	_TranslationsChatImagePromptReviewDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Проверить промпт изображения';
	@override String get description => 'Отредактируйте промпт ниже перед генерацией или нажмите «Сгенерировать», чтобы использовать как есть.';
	@override String get fieldLabel => 'Промпт изображения';
	@override String get generateButton => 'Сгенерировать';
}

// Path: chat.videoPromptReviewDialog
class _TranslationsChatVideoPromptReviewDialogRu extends _TranslationsChatVideoPromptReviewDialogEn {
	_TranslationsChatVideoPromptReviewDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Проверить промпт видео';
	@override String get description => 'Отредактируйте промпт ниже перед отправкой или нажмите «Сгенерировать», чтобы использовать как есть.';
	@override String get fieldLabel => 'Промпт видео';
	@override String get generateButton => 'Сгенерировать';
}

// Path: chat.urlFetchReviewDialog
class _TranslationsChatUrlFetchReviewDialogRu extends _TranslationsChatUrlFetchReviewDialogEn {
	_TranslationsChatUrlFetchReviewDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Разрешить веб-запрос?';
	@override String get description => 'Персонаж хочет прочитать содержимое этого URL.';
	@override String get purposeLabel => 'Цель:';
	@override String get denyButton => 'Отклонить';
	@override String get allowButton => 'Разрешить';
}

// Path: chat.messageActionsRow
class _TranslationsChatMessageActionsRowRu extends _TranslationsChatMessageActionsRowEn {
	_TranslationsChatMessageActionsRowRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String tokenCountAbbrev({required Object count}) => '${count} т';
	@override String generationTimeAbbrev({required Object seconds}) => '${seconds} с';
	@override String get viewGenerationPromptTooltip => 'Посмотреть промпт генерации';
	@override String get messageActionsTooltip => 'Действия с сообщением';
	@override String get editAction => 'Изменить';
	@override String get copyAction => 'Копировать';
	@override String get shareImageAction => 'Поделиться изображением';
	@override String get setAsBackgroundAction => 'Сделать фоном';
	@override String get setAsCharacterImageAction => 'Сделать изображением персонажа';
	@override String get deleteAction => 'Удалить';
	@override String get copiedToClipboard => 'Сообщение скопировано в буфер обмена';
}

// Path: chat.ttsPlayButton
class _TranslationsChatTtsPlayButtonRu extends _TranslationsChatTtsPlayButtonEn {
	_TranslationsChatTtsPlayButtonRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get stopTooltip => 'Стоп';
	@override String get readAloudTooltip => 'Прочитать вслух';
	@override String get ttsFailed => 'Ошибка TTS.';
}

// Path: chat.messageSwipeFlipper
class _TranslationsChatMessageSwipeFlipperRu extends _TranslationsChatMessageSwipeFlipperEn {
	_TranslationsChatMessageSwipeFlipperRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get previousVersionTooltip => 'Предыдущая версия';
	@override String swipeCounter({required Object current, required Object total}) => '${current} / ${total}';
	@override String get regenerateTooltip => 'Перегенерировать';
	@override String get nextVersionTooltip => 'Следующая версия';
}

// Path: chat.videoPlayerInline
class _TranslationsChatVideoPlayerInlineRu extends _TranslationsChatVideoPlayerInlineEn {
	_TranslationsChatVideoPlayerInlineRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get webUnsupported => 'Воспроизведение видео не поддерживается в вебе.';
	@override String get couldNotLoad => 'Не удалось загрузить видео.';
}

// Path: chat.chatListItem
class _TranslationsChatChatListItemRu extends _TranslationsChatChatListItemEn {
	_TranslationsChatChatListItemRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String messageCount({required Object count}) => 'Сообщений: ${count}';
	@override String get renameAction => 'Переименовать';
	@override String get deleteChatAction => 'Удалить чат';
}

// Path: chat.chatHistoryController
class _TranslationsChatChatHistoryControllerRu extends _TranslationsChatChatHistoryControllerEn {
	_TranslationsChatChatHistoryControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get renameChatTitle => 'Переименовать чат';
	@override String get chatNameHint => 'Название чата';
	@override String get renameButton => 'Переименовать';
	@override String get deleteChatTitle => 'Удалить чат';
	@override String get deleteChatMessage => 'Вы уверены, что хотите удалить историю этого чата? Это действие нельзя отменить.';
}

// Path: chat.chatPageController
class _TranslationsChatChatPageControllerRu extends _TranslationsChatChatPageControllerEn {
	_TranslationsChatChatPageControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get clearAssistantHistoryMessage => 'Очистить историю чата с ассистентом?';
	@override String get clearButton => 'Очистить';
	@override String get deleteOrKeepMessage => 'Удалить текущий чат или сохранить его в истории?';
	@override String get deleteCurrentButton => 'Удалить текущий';
	@override String get keepCurrentButton => 'Оставить текущий';
}

// Path: chat.imageGenerationMixin
class _TranslationsChatImageGenerationMixinRu extends _TranslationsChatImageGenerationMixinEn {
	_TranslationsChatImageGenerationMixinRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get enterPromptMessage => 'Введите промпт для генерации изображения.';
	@override String get noCharacterMessage => 'Нет персонажа для генерации изображения.';
	@override String get notConfiguredMessage => 'Генерация изображений не настроена.';
	@override String get noSystemModelMessage => 'Системная модель не настроена. Задайте её в Настройки → ИИ.';
}

// Path: chat.videoGenerationMixin
class _TranslationsChatVideoGenerationMixinRu extends _TranslationsChatVideoGenerationMixinEn {
	_TranslationsChatVideoGenerationMixinRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get enterPromptMessage => 'Введите промпт для генерации видео.';
	@override String get noCharacterMessage => 'Нет персонажа для генерации видео.';
	@override String get notConfiguredMessage => 'Генерация видео не настроена.';
}

// Path: chat.bubbleWaitingFor
class _TranslationsChatBubbleWaitingForRu extends _TranslationsChatBubbleWaitingForEn {
	_TranslationsChatBubbleWaitingForRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get thinking => 'Размышляет…';
	@override String get preparingImagePrompt => 'Подготовка промпта изображения…';
	@override String get preparingVideoPrompt => 'Подготовка промпта видео…';
	@override String get generatingImage => 'Генерация изображения…';
	@override String get generatingVideo => 'Генерация видео…';
}

// Path: chat.appBarChat
class _TranslationsChatAppBarChatRu extends _TranslationsChatAppBarChatEn {
	_TranslationsChatAppBarChatRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get hideEditorPanelTooltip => 'Скрыть панель редактора';
	@override String get showEditorSideBySideTooltip => 'Показать редактор рядом';
}

// Path: chat.allChatsDrawerList
class _TranslationsChatAllChatsDrawerListRu extends _TranslationsChatAllChatsDrawerListEn {
	_TranslationsChatAllChatsDrawerListRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get rebuildingIndex => 'Перестроение индекса...';
	@override String get noChatsFound => 'Чаты не найдены.';
}

// Path: chat.chatInputMediaMenu
class _TranslationsChatChatInputMediaMenuRu extends _TranslationsChatChatInputMediaMenuEn {
	_TranslationsChatChatInputMediaMenuRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get generateMediaTooltip => 'Сгенерировать медиа';
	@override String get generateImageLabel => 'Сгенерировать изображение';
	@override String get generateVideoLabel => 'Сгенерировать видео';
}

// Path: chat.chatView
class _TranslationsChatChatViewRu extends _TranslationsChatChatViewEn {
	_TranslationsChatChatViewRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get deleteMessageTitle => 'Удалить сообщение';
	@override String get deleteMessageConfirmation => 'Вы уверены, что хотите удалить это сообщение?';
	@override String get typeMessageHint => 'Введите сообщение...';
	@override String get moreActionsTooltip => 'Ещё действия';
	@override String get continueAction => 'Продолжить';
	@override String get impersonateAction => 'Отыграть за персонажа';
	@override String get generateReplyAction => 'Сгенерировать ответ';
	@override String get improveMessageAction => 'Улучшить сообщение';
}

// Path: chat.chatMessageBubble
class _TranslationsChatChatMessageBubbleRu extends _TranslationsChatChatMessageBubbleEn {
	_TranslationsChatChatMessageBubbleRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get imagesTypeGroupLabel => 'Изображения';
	@override String get assistantFallbackName => 'Ассистент';
	@override String get reasoningLabel => 'Рассуждения';
	@override String get sendingToProvider => 'Отправка провайдеру…';
	@override String pollingWithPercent({required Object pct}) => 'Опрос… ${pct}%';
	@override String get polling => 'Опрос…';
	@override String get downloading => 'Загрузка…';
}

// Path: common.actions
class _TranslationsCommonActionsRu extends _TranslationsCommonActionsEn {
	_TranslationsCommonActionsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Удалить';
	@override String get ok => 'ОК';
	@override String get cancel => 'Отмена';
	@override String get save => 'Сохранить';
	@override String get tryAgain => 'Повторить';
	@override String get close => 'Закрыть';
}

// Path: common.aiAction
class _TranslationsCommonAiActionRu extends _TranslationsCommonAiActionEn {
	_TranslationsCommonAiActionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get proofread => 'Вычитать';
	@override String get compact => 'Сжать текст';
	@override String get translate => 'Перевести на английский';
	@override String get generatePreview => 'Создать превью';
	@override String get autoTag => 'Авто-теги';
}

// Path: common.promptSegmentKind
class _TranslationsCommonPromptSegmentKindRu extends _TranslationsCommonPromptSegmentKindEn {
	_TranslationsCommonPromptSegmentKindRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get identity => 'Идентичность';
	@override String get systemPrompt => 'Системный промпт';
	@override String get nsfwMode => 'Режим NSFW';
	@override String get scenarioMode => 'Режим сценария';
	@override String get description => 'Описание';
	@override String get personality => 'Характер';
	@override String get scenario => 'Сценарий';
	@override String get userPersona => 'Ваша персона';
	@override String get memory => 'Память';
	@override String get situation => 'Ситуация';
	@override String get cardData => 'Данные карточки';
	@override String get tools => 'Инструменты';
	@override String get postHistory => 'После истории';
	@override String get depthPrompt => 'Глубинный промпт';
	@override String get worldInfo => 'Информация о мире';
	@override String get injected => 'Внедрено';
	@override String get exampleDialogue => 'Пример диалога';
	@override String get history => 'История сообщений';
	@override String get currentMessage => 'Текущее сообщение';
	@override String get reservedReply => 'Зарезервировано для ответа';
}

// Path: common.promptBreakdown
class _TranslationsCommonPromptBreakdownRu extends _TranslationsCommonPromptBreakdownEn {
	_TranslationsCommonPromptBreakdownRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get free => 'Свободно';
}

// Path: common.logs
class _TranslationsCommonLogsRu extends _TranslationsCommonLogsEn {
	_TranslationsCommonLogsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Логи';
	@override String get filterTooltip => 'Фильтр логов';
	@override String get clearTooltip => 'Очистить логи';
	@override String get exportTooltip => 'Экспорт логов';
	@override String get searchHint => 'Поиск в логах...';
	@override String get noLogsFound => 'Логи не найдены.';
	@override String get noLogsToExport => 'Нет логов для экспорта';
	@override String get exportedSuccessfully => 'Логи успешно экспортированы';
	@override String get exportFailed => 'Не удалось экспортировать логи. Подробности в логах.';
	@override String get copiedToClipboard => 'Скопировано в буфер обмена';
	@override String get copyLogButton => 'Копировать лог';
	@override String get copiedEntryToClipboard => 'Запись лога скопирована в буфер обмена';
	@override String errorPrefix({required Object error}) => 'Ошибка: ${error}';
}

// Path: common.importErrorsDialog
class _TranslationsCommonImportErrorsDialogRu extends _TranslationsCommonImportErrorsDialogEn {
	_TranslationsCommonImportErrorsDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ошибки импорта';
	@override String get message => 'Следующие файлы не удалось импортировать:';
}

// Path: common.updateDialog
class _TranslationsCommonUpdateDialogRu extends _TranslationsCommonUpdateDialogEn {
	_TranslationsCommonUpdateDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Доступна версия';
	@override String body({required Object appName, required Object currentVersion, required Object latestVersion}) => 'Доступна более новая версия ${appName}.\n\nТекущая версия: ${currentVersion}\nПоследняя версия: ${latestVersion}';
	@override String get releaseNotesLabel => 'Что нового:';
	@override String get viewReleasesButton => 'Смотреть релизы';
}

// Path: common.importConflictsDialog
class _TranslationsCommonImportConflictsDialogRu extends _TranslationsCommonImportConflictsDialogEn {
	_TranslationsCommonImportConflictsDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Конфликты импорта';
	@override String message({required Object count}) => 'Следующие ${count} персонажей имеют конфликты имён файлов и будут переименованы автоматически:';
}

// Path: common.missingProviderBanner
class _TranslationsCommonMissingProviderBannerRu extends _TranslationsCommonMissingProviderBannerEn {
	_TranslationsCommonMissingProviderBannerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get message => 'Подключите провайдер ИИ.';
	@override String get setUpNowButton => 'Настроить сейчас';
}

// Path: common.modelSelectionDialog
class _TranslationsCommonModelSelectionDialogRu extends _TranslationsCommonModelSelectionDialogEn {
	_TranslationsCommonModelSelectionDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Поиск моделей';
	@override String subscriptionOnlyToggle({required Object included, required Object total}) => 'Показывать только модели по подписке (${included}/${total})';
}

// Path: common.showAdvanced
class _TranslationsCommonShowAdvancedRu extends _TranslationsCommonShowAdvancedEn {
	_TranslationsCommonShowAdvancedRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get less => 'Меньше';
	@override String get more => 'Больше';
}

// Path: common.messageEditDialog
class _TranslationsCommonMessageEditDialogRu extends _TranslationsCommonMessageEditDialogEn {
	_TranslationsCommonMessageEditDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Редактировать сообщение';
}

// Path: common.promptBreakdownDialog
class _TranslationsCommonPromptBreakdownDialogRu extends _TranslationsCommonPromptBreakdownDialogEn {
	_TranslationsCommonPromptBreakdownDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Разбор промпта';
	@override String get breakdownTab => 'Разбор';
	@override String get contentTab => 'Содержимое';
	@override String get promptTotalEstimated => 'Итого по промпту (оценка)';
	@override String get promptTotalProvider => 'Итого по промпту (провайдер)';
	@override String get contextWindowLabel => 'Контекстное окно';
	@override String get categoryHeader => 'КАТЕГОРИЯ';
	@override String get tokensHeader => 'ТОКЕНЫ';
	@override String get usageHeader => 'ИСПОЛЬЗОВАНИЕ';
	@override String get noContentToInspect => 'Нет содержимого для этого ответа.';
	@override String get estimatedSuffix => ' (оценка)';
	@override String usedSummary({required Object used, required Object total}) => 'Использовано ${used} / ${total}';
}

// Path: common.jsonPromptDialog
class _TranslationsCommonJsonPromptDialogRu extends _TranslationsCommonJsonPromptDialogEn {
	_TranslationsCommonJsonPromptDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Промпт генерации';
}

// Path: common.progressDialog
class _TranslationsCommonProgressDialogRu extends _TranslationsCommonProgressDialogEn {
	_TranslationsCommonProgressDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get defaultMessage => 'Отправка...';
	@override String get finished => 'Готово!';
}

// Path: common.diffPanel
class _TranslationsCommonDiffPanelRu extends _TranslationsCommonDiffPanelEn {
	_TranslationsCommonDiffPanelRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String tokenSuffix({required Object count}) => ' (${count} токенов)';
}

// Path: common.selectionDialog
class _TranslationsCommonSelectionDialogRu extends _TranslationsCommonSelectionDialogEn {
	_TranslationsCommonSelectionDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Поиск…';
}

// Path: common.zdrSwitch
class _TranslationsCommonZdrSwitchRu extends _TranslationsCommonZdrSwitchEn {
	_TranslationsCommonZdrSwitchRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Требовать нулевое хранение данных (ZDR)';
	@override String get subtitle => 'Показывать только модели OR с ZDR-совместимыми эндпоинтами. Включите, если ваш аккаунт openrouter.ai ограничен провайдерами ZDR.';
}

// Path: common.textFieldCard
class _TranslationsCommonTextFieldCardRu extends _TranslationsCommonTextFieldCardEn {
	_TranslationsCommonTextFieldCardRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String labelWithTokenCount({required Object label, required Object count}) => '${label} — ${count} токенов';
	@override String tokenCountAbbrev({required Object count}) => '${count} т';
}

// Path: common.modelCapability
class _TranslationsCommonModelCapabilityRu extends _TranslationsCommonModelCapabilityEn {
	_TranslationsCommonModelCapabilityRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get reasoning => 'Рассуждения';
	@override String get vision => 'Зрение';
	@override String get tools => 'Инструменты';
	@override String get json => 'JSON';
	@override String get files => 'Файлы';
	@override String get image => 'Изображение';
	@override String get video => 'Видео';
	@override String get speech => 'Речь';
	@override String get music => 'Музыка';
}

// Path: common.appConstants
class _TranslationsCommonAppConstantsRu extends _TranslationsCommonAppConstantsEn {
	_TranslationsCommonAppConstantsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get maxImageFileSizeLabel => '10 МБ';
	@override String get exportFailedMessage => 'Не удалось экспортировать. Подробности в логах.';
}

// Path: common.timeAgo
class _TranslationsCommonTimeAgoRu extends _TranslationsCommonTimeAgoEn {
	_TranslationsCommonTimeAgoRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String years({required Object n}) => '${n} г. назад';
	@override String months({required Object n}) => '${n} мес. назад';
	@override String days({required Object n}) => '${n} д. назад';
	@override String hours({required Object n}) => '${n} ч. назад';
	@override String minutes({required Object n}) => '${n} мин. назад';
	@override String get justNow => 'Только что';
}

// Path: editor.panelLabels
class _TranslationsEditorPanelLabelsRu extends _TranslationsEditorPanelLabelsEn {
	_TranslationsEditorPanelLabelsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get basic => 'Основное';
	@override String get greetings => 'Приветствия';
	@override String get prompts => 'Промпты';
	@override String get lorebook => 'Лорбук';
	@override String get group => 'Группа';
	@override String get creator => 'Автор';
	@override String get appData => 'Данные приложения';
	@override String get nodes => 'Узлы';
}

// Path: editor.appBarEditor
class _TranslationsEditorAppBarEditorRu extends _TranslationsEditorAppBarEditorEn {
	_TranslationsEditorAppBarEditorRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get hideAssistantPanelTooltip => 'Скрыть панель ассистента';
	@override String get showChatAssistantTooltip => 'Показать чат-ассистент рядом';
}

// Path: editor.codeFindPanel
class _TranslationsEditorCodeFindPanelRu extends _TranslationsEditorCodeFindPanelEn {
	_TranslationsEditorCodeFindPanelRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noneResult => 'нет';
	@override String get previousTooltip => 'Предыдущее';
	@override String get nextTooltip => 'Следующее';
	@override String get closeTooltip => 'Закрыть';
	@override String get replaceTooltip => 'Заменить';
	@override String get replaceAllTooltip => 'Заменить всё';
}

// Path: editor.findReplaceDialog
class _TranslationsEditorFindReplaceDialogRu extends _TranslationsEditorFindReplaceDialogEn {
	_TranslationsEditorFindReplaceDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get confirmReplaceAllTitle => 'Подтвердите «Заменить всё»';
	@override String get confirmReplaceAllMessage => 'Вы уверены, что хотите продолжить?\nЭто действие необратимо и затрагивает все поля.';
	@override String get proceedButton => 'Продолжить';
	@override String get title => 'Найти и заменить';
	@override String get findLabel => 'Найти';
	@override String get replaceWithLabel => 'Заменить на';
	@override String get replaceAllButton => 'Заменить всё';
}

// Path: editor.objectValueEditor
class _TranslationsEditorObjectValueEditorRu extends _TranslationsEditorObjectValueEditorEn {
	_TranslationsEditorObjectValueEditorRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get stringType => 'строка';
	@override String get numberType => 'число';
	@override String get boolType => 'булево';
}

// Path: editor.editorBasic
class _TranslationsEditorEditorBasicRu extends _TranslationsEditorEditorBasicEn {
	_TranslationsEditorEditorBasicRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get nameLabel => 'Имя';
	@override String get nicknameLabel => 'Прозвище (CCv3)';
	@override String get descriptionLabel => 'Описание';
	@override String get personalityLabel => 'Характер';
	@override String get scenarioLabel => 'Сценарий';
	@override String get messageExampleLabel => 'Пример сообщения';
}

// Path: editor.editorCreatorMetadata
class _TranslationsEditorEditorCreatorMetadataRu extends _TranslationsEditorEditorCreatorMetadataEn {
	_TranslationsEditorEditorCreatorMetadataRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get systemNameLabel => 'Системное имя (CCv3)';
	@override String get creatorLabel => 'Автор';
	@override String get versionLabel => 'Версия';
	@override String get creatorNotesLabel => 'Заметки автора';
	@override String get tagsLabel => 'Теги (через запятую)';
}

// Path: editor.editorPrompts
class _TranslationsEditorEditorPromptsRu extends _TranslationsEditorEditorPromptsEn {
	_TranslationsEditorEditorPromptsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get systemPromptLabel => 'Системный промпт';
	@override String get postHistoryInstructionsLabel => 'Инструкции после истории';
	@override String get depthPromptLabel => 'Глубинный промпт (заметки о персонаже)';
	@override String get insertionDepthLabel => 'Глубина вставки';
	@override String get roleLabel => 'Роль';
}

// Path: editor.editorAppData
class _TranslationsEditorEditorAppDataRu extends _TranslationsEditorEditorAppDataEn {
	_TranslationsEditorEditorAppDataRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get variantNotesLabel => 'Заметки варианта';
	@override String get descriptionPreviewLabel => 'Превью описания';
}

// Path: editor.editorAlternateGreetings
class _TranslationsEditorEditorAlternateGreetingsRu extends _TranslationsEditorEditorAlternateGreetingsEn {
	_TranslationsEditorEditorAlternateGreetingsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get deleteGreetingTitle => 'Удалить приветствие';
	@override String get deleteGreetingMessage => 'Вы уверены, что хотите удалить это приветствие?';
	@override String get addGreetingButton => 'Добавить приветствие';
	@override String get primaryGreetingLabel => 'Основное приветствие (first_mes)';
	@override String alternateGreetingLabel({required Object index}) => 'Альтернативное приветствие №${index}';
	@override String get removeTooltip => 'Удалить';
}

// Path: editor.editorGroupGreetings
class _TranslationsEditorEditorGroupGreetingsRu extends _TranslationsEditorEditorGroupGreetingsEn {
	_TranslationsEditorEditorGroupGreetingsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String greetingLabel({required Object index}) => 'Приветствие ${index}';
}

// Path: editor.editorLorebook
class _TranslationsEditorEditorLorebookRu extends _TranslationsEditorEditorLorebookEn {
	_TranslationsEditorEditorLorebookRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newEntryDefaultComment => 'Новая запись';
	@override String get deleteEntryTitle => 'Удалить запись';
	@override String get deleteEntryMessage => 'Вы уверены, что хотите удалить эту запись?';
	@override String get addNewEntryButton => 'Добавить запись';
	@override String get noEntriesFound => 'Записи лорбука не найдены.';
}

// Path: editor.lorebookEntryListTile
class _TranslationsEditorLorebookEntryListTileRu extends _TranslationsEditorLorebookEntryListTileEn {
	_TranslationsEditorLorebookEntryListTileRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get untitledEntry => 'Запись без названия';
	@override String get noKeywords => 'Нет ключевых слов';
}

// Path: editor.lorebookEntryEditorPage
class _TranslationsEditorLorebookEntryEditorPageRu extends _TranslationsEditorLorebookEntryEditorPageEn {
	_TranslationsEditorLorebookEntryEditorPageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get editEntryTitle => 'Редактировать запись лорбука';
	@override String get advancedFilter => 'Расширенно';
	@override String get primaryKeywordsLabel => 'Основные ключевые слова';
	@override String get logicLabel => 'Логика';
	@override String get logicAndAny => 'И (любое)';
	@override String get logicAndAll => 'И (все)';
	@override String get logicNotAny => 'НЕ (любое)';
	@override String get logicNotAll => 'НЕ (все)';
	@override String get optionalFilterLabel => 'Дополнительный фильтр';
	@override String get contentLabel => 'Содержимое';
	@override String get nonRecursableFilter => 'Без рекурсии';
	@override String get preventFurtherRecursionFilter => 'Запретить дальнейшую рекурсию';
	@override String get delayUntilRecursionFilter => 'Отложить до рекурсии';
	@override String get ignoreBudgetFilter => 'Игнорировать бюджет';
	@override String get prioritizeFilter => 'Приоритизировать';
	@override String get inclusionGroupLabel => 'Группа включения';
	@override String get groupWeightLabel => 'Вес группы';
	@override String get stickyLabel => 'Закреплённый';
	@override String get cooldownLabel => 'Задержка перезарядки';
	@override String get delayLabel => 'Задержка';
	@override String get filterToCharactersLabel => 'Фильтр по персонажам или тегам';
	@override String get filterToTriggersLabel => 'Фильтр по триггерам генерации';
	@override String get additionalMatchingSourcesLabel => 'Дополнительные источники совпадений:';
	@override String get personaFilter => 'Персона';
	@override String get descriptionFilter => 'Описание';
	@override String get personalityFilter => 'Характер';
	@override String get depthPromptFilter => 'Глубинный промпт';
	@override String get scenarioFilter => 'Сценарий';
	@override String get creatorNotesFilter => 'Заметки автора';
}

// Path: editor.lorebookEntryEditorTopSection
class _TranslationsEditorLorebookEntryEditorTopSectionRu extends _TranslationsEditorLorebookEntryEditorTopSectionEn {
	_TranslationsEditorLorebookEntryEditorTopSectionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get titleMemoLabel => 'Заголовок/памятка';
	@override String get strategyLabel => 'Стратегия';
	@override String get strategyConstant => 'Постоянный';
	@override String get strategyEnabled => 'Включён';
	@override String get strategyDisabled => 'Отключён';
	@override String get strategyVectorized => 'Векторизован';
	@override String get positionLabel => 'Позиция';
	@override String get positionUpChar => '↑ Перс';
	@override String get positionDownChar => '↓ Перс';
	@override String get positionUpAn => '↑ AN';
	@override String get positionDownAn => '↓ AN';
	@override String get positionDepthSystem => '@D система';
	@override String get positionDepthUser => '@D польз.';
	@override String get positionDepthAssistant => '@D ассистент';
	@override String get positionUpEm => '↑ EM';
	@override String get positionDownEm => '↓ EM';
	@override String get positionOutlet => 'Выход';
	@override String get depthLabel => 'Глубина';
	@override String get orderLabel => 'Порядок';
	@override String get triggerLabel => 'Триггер %';
}

// Path: editor.lorebookEntryEditorScanRow
class _TranslationsEditorLorebookEntryEditorScanRowRu extends _TranslationsEditorLorebookEntryEditorScanRowEn {
	_TranslationsEditorLorebookEntryEditorScanRowRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get scanDepthLabel => 'Глубина сканирования';
	@override String get automationIdLabel => 'ID автоматизации';
	@override String get useRegexFilter => 'Использовать regex';
	@override String get caseSensitiveFilter => 'С учётом регистра';
	@override String get wholeWordsFilter => 'Слова целиком';
	@override String get groupScoringFilter => 'Оценка группы';
}

// Path: editor.dialogContentCleaner
class _TranslationsEditorDialogContentCleanerRu extends _TranslationsEditorDialogContentCleanerEn {
	_TranslationsEditorDialogContentCleanerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String confirmActionTitle({required Object actionName}) => 'Подтвердите «${actionName}»';
	@override String get title => 'Очистка содержимого';
	@override String get normalizeFancyCharsAction => 'Нормализовать спецсимволы';
	@override String get normalizeFancyCharsButton => 'Нормализовать спецсимволы (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
	@override String get purgeHtmlAction => 'Удалить HTML';
	@override String get purgeHtmlButton => 'Удалить теги HTML';
	@override String get purgeMarkdownAction => 'Удалить ссылки/изображения Markdown';
	@override String get purgeEmojisAction => 'Удалить эмодзи';
	@override String get purgeExtraSpacesAction => 'Удалить лишние пробелы';
	@override String get yoloPurgeAction => 'Полная очистка';
	@override String get applyAllAboveButton => 'Применить всё выше';
}

// Path: editor.dialogAiDiffConfirmation
class _TranslationsEditorDialogAiDiffConfirmationRu extends _TranslationsEditorDialogAiDiffConfirmationEn {
	_TranslationsEditorDialogAiDiffConfirmationRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get applyChangesButton => 'Применить изменения';
	@override String get originalTextTitle => 'Исходный текст';
	@override String get suggestedTextTitle => 'Предложенный текст';
}

// Path: editor.editorPageController
class _TranslationsEditorEditorPageControllerRu extends _TranslationsEditorEditorPageControllerEn {
	_TranslationsEditorEditorPageControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String globalActionTitle({required Object action}) => 'Глобально: ${action}';
	@override String get globalAiActionFailed => 'Глобальное действие ИИ не выполнено. Проверьте логи.';
	@override String compositeName({required Object value}) => 'Имя:\n${value}\n';
	@override String compositeDescription({required Object value}) => 'Описание:\n${value}\n';
	@override String compositePersonality({required Object value}) => 'Характер:\n${value}\n';
	@override String compositeScenario({required Object value}) => 'Сценарий:\n${value}\n';
	@override String compositeFirstMessage({required Object value}) => 'Первое сообщение:\n${value}\n';
	@override String compositeMessageExample({required Object value}) => 'Пример сообщения:\n${value}\n';
	@override String compositeCreatorNotes({required Object value}) => 'Заметки автора:\n${value}\n';
	@override String compositeSystemPrompt({required Object value}) => 'Системный промпт:\n${value}\n';
	@override String compositePostHistoryInstructions({required Object value}) => 'Инструкции после истории:\n${value}\n';
	@override String compositeAlternateGreeting({required Object index, required Object value}) => 'Альтернативное приветствие №${index}:\n${value}\n';
	@override String compositeGroupGreeting({required Object index, required Object value}) => 'Групповое приветствие №${index}:\n${value}\n';
	@override String compositeLorebookEntry({required Object index, required Object value}) => 'Запись лорбука №${index}:\n${value}\n';
	@override String imageTooLargeMessage({required Object maxSize}) => 'Выбранное изображение слишком большое. Максимальный размер — ${maxSize}.';
	@override String get invalidPngMessage => 'Выбранное изображение не является корректным PNG или не может быть прочитано.';
}

// Path: editor.editorNodes
class _TranslationsEditorEditorNodesRu extends _TranslationsEditorEditorNodesEn {
	_TranslationsEditorEditorNodesRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get deleteNodeTitle => 'Удалить узел';
	@override String get deleteNodeMessage => 'Удалить этот авторский узел из карточки?';
	@override String get engineSeedTitle => 'Начальное состояние движка';
	@override String get visualEditorTooltip => 'Визуальный редактор';
	@override String get editJsonTooltip => 'Редактировать JSON';
	@override String get initialGoalLabel => 'Начальная цель';
	@override String get initialSceneLabel => 'Начальная сцена';
	@override String get locationLabel => 'Место';
	@override String get timeOfDayLabel => 'Время суток';
	@override String get presentEntitiesLabel => 'Присутствуют (через запятую)';
	@override String get sensoryHooksLabel => 'Сенсорные зацепки (через запятую)';
	@override String get addNodeButton => 'Добавить узел';
	@override String get noAuthoredNodesYet => 'Авторских узлов пока нет.';
	@override String loadErrorMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'В блоке узлов этой карточки ${n} проблема; редактирование здесь перезапишет повреждённые части при сохранении.',
		few: 'В блоке узлов этой карточки ${n} проблемы; редактирование здесь перезапишет повреждённые части при сохранении.',
		many: 'В блоке узлов этой карточки ${n} проблем; редактирование здесь перезапишет повреждённые части при сохранении.',
		other: 'В блоке узлов этой карточки ${n} проблемы; редактирование здесь перезапишет повреждённые части при сохранении.',
	);
	@override String moreErrorsSuffix({required Object n}) => '… ещё ${n}';
	@override String get emotionBaselineLabel => 'Базовая эмоция';
	@override String get emotionChipLabel => 'Эмоция';
}

// Path: editor.nodeListTile
class _TranslationsEditorNodeListTileRu extends _TranslationsEditorNodeListTileEn {
	_TranslationsEditorNodeListTileRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String spawnsLabel({required Object count}) => 'порождает: ${count}';
}

// Path: editor.nodesRawEditorPage
class _TranslationsEditorNodesRawEditorPageRu extends _TranslationsEditorNodesRawEditorPageEn {
	_TranslationsEditorNodesRawEditorPageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get topLevelMustBeObject => 'Верхний уровень должен быть объектом JSON';
	@override String get editNodesJsonTitle => 'Редактировать JSON узлов';
	@override String fixProblemsMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Исправьте ${n} проблему, чтобы сохранить.',
		few: 'Исправьте ${n} проблемы, чтобы сохранить.',
		many: 'Исправьте ${n} проблем, чтобы сохранить.',
		other: 'Исправьте ${n} проблемы, чтобы сохранить.',
	);
}

// Path: editor.nodesCanvasView
class _TranslationsEditorNodesCanvasViewRu extends _TranslationsEditorNodesCanvasViewEn {
	_TranslationsEditorNodesCanvasViewRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get spawnedByPort => 'порождён';
	@override String get spawnsPort => 'порождает';
	@override String get editNodeLabel => 'Редактировать узел';
	@override String get addNodeTooltip => 'Добавить узел';
}

// Path: editor.nodeEditorForm
class _TranslationsEditorNodeEditorFormRu extends _TranslationsEditorNodeEditorFormEn {
	_TranslationsEditorNodeEditorFormRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get nameLabel => 'Имя';
	@override String get narrativePayloadLabel => 'Нарративная нагрузка';
	@override String get removeSpawnLinkTitle => 'Удалить связь порождения';
	@override String removeSpawnLinkMessage({required Object nodeId}) => 'Запретить этому узлу порождать «${nodeId}»? Сам узел останется на карточке.';
	@override String get removeButton => 'Удалить';
	@override String get typeLabel => 'Тип';
	@override String get scopeLabel => 'Область';
	@override String get originLabel => 'Источник';
	@override String get triggerProbLabel => 'Вероятность триггера';
	@override String get delayHelper => 'Ходов ожидания перед активацией. -1 равно 0.';
	@override String get cooldownHelper => 'Ходов блокировки после срабатывания. -1 означает без перезарядки.';
	@override String get stickyHelper => 'Ходов, в течение которых нарративная нагрузка остаётся как «Сохраняющаяся» после срабатывания. -1 означает навсегда.';
	@override String get aliveHelper => 'Ходов, в течение которых узел остаётся в пуле до удаления. -1 означает бесконечно.';
	@override String get setToNeverButton => 'Установить «никогда»';
	@override String get effectsSectionLabel => 'Эффекты';
	@override String get emotionDeltasTitle => 'Изменения эмоций';
	@override String get physicalDeltasTitle => 'Физические изменения';
	@override String get relationshipDeltasTitle => 'Изменения отношений';
	@override String get addDeltaChip => 'Добавить изменение';
	@override String get knowledgeWritesTitle => 'Записи знаний';
	@override String get addFactChip => 'Добавить факт';
	@override String get topicLabel => 'тема';
	@override String get confidenceLabel => 'уверенность';
	@override String get flagSetTitle => 'Набор флагов';
	@override String get addFlagChip => 'Добавить флаг';
	@override String get keyLabel => 'ключ';
	@override String get sceneAndFlowTitle => 'Сцена и ход';
	@override String get goalChangeLabel => 'goalChange (очищает текущую цель, если пусто)';
	@override String get phaseChangeLabel => 'phaseChange';
	@override String get noneOption => '(нет)';
	@override String get sceneTransitionLabel => 'sceneTransition';
	@override String get sceneTransitionSubtitle => 'Если true, движок помечает срабатывание как смену сцены.';
	@override String get spawnsSectionLabel => 'Порождения';
	@override String get addNewChip => 'Добавить новый';
	@override String get linkExistingChip => 'Связать существующий';
	@override String get unlinkTooltip => 'Отвязать';
	@override String get predicateLabel => 'Предикат';
}

// Path: grid.emptyState
class _TranslationsGridEmptyStateRu extends _TranslationsGridEmptyStateEn {
	_TranslationsGridEmptyStateRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noMatches => 'Нет персонажей по вашим фильтрам';
	@override String get noCharacters => 'Персонажи ещё не импортированы';
	@override String get clearAllFilters => 'Сбросить все фильтры';
	@override String get importCharacters => 'Импортировать персонажей';
	@override String get createNewCharacter => 'Создать персонажа';
}

// Path: grid.appBar
class _TranslationsGridAppBarRu extends _TranslationsGridAppBarEn {
	_TranslationsGridAppBarRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get groups => 'Группы';
	@override String get createNew => 'Создать';
	@override String get import => 'Импорт';
	@override String get menuTooltip => 'Меню';
}

// Path: grid.fab
class _TranslationsGridFabRu extends _TranslationsGridFabEn {
	_TranslationsGridFabRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get addOrImportTooltip => 'Добавить или импортировать';
	@override String get import => 'Импорт';
	@override String get create => 'Создать';
}

// Path: grid.drawer
class _TranslationsGridDrawerRu extends _TranslationsGridDrawerEn {
	_TranslationsGridDrawerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get mediaDefaultsApp => 'Приложение';
	@override String get batchAiHeader => 'Пакетный ИИ';
	@override String get batchGeneratePreviewsTitle => 'Пакетная генерация превью';
	@override String get batchGeneratePreviewsEmpty => 'У всех персонажей уже есть превью.';
	@override String get batchAutoTagTitle => 'Пакетное авто-тегирование';
	@override String get batchAutoTagEmpty => 'У всех персонажей уже есть теги.';
	@override String get libraryHeader => 'Библиотека';
	@override String get reloadCharacters => 'Перезагрузить персонажей';
}

// Path: grid.variantBadge
class _TranslationsGridVariantBadgeRu extends _TranslationsGridVariantBadgeEn {
	_TranslationsGridVariantBadgeRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String tooltip({required Object count}) => 'Вариантов: ${count}';
}

// Path: grid.dialogActions
class _TranslationsGridDialogActionsRu extends _TranslationsGridDialogActionsEn {
	_TranslationsGridDialogActionsRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get clearAll => 'Очистить всё';
	@override String get apply => 'Применить';
}

// Path: grid.tagFilterDialog
class _TranslationsGridTagFilterDialogRu extends _TranslationsGridTagFilterDialogEn {
	_TranslationsGridTagFilterDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Фильтр по тегам';
	@override String get searchHint => 'Поиск тегов...';
}

// Path: grid.filters
class _TranslationsGridFiltersRu extends _TranslationsGridFiltersEn {
	_TranslationsGridFiltersRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get hideFiltersTooltip => 'Скрыть фильтры';
	@override String get moreFiltersTooltip => 'Больше фильтров';
	@override String get folderChip => 'Папка';
	@override String get creatorChip => 'Автор';
	@override String get tagChip => 'Тег';
	@override String get recentTooltip => 'Недавние';
	@override String get favoritesTooltip => 'Избранное';
	@override String get variantsTooltip => 'Варианты';
	@override String indexingProgress({required Object done, required Object total}) => 'Построение поиска ${done} / ${total}…';
}

// Path: grid.sortOption
class _TranslationsGridSortOptionRu extends _TranslationsGridSortOptionEn {
	_TranslationsGridSortOptionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get relevance => 'Релевантность ↓';
	@override String get nameAsc => 'Имя ↓';
	@override String get nameDesc => 'Имя ↑';
	@override String get importNewest => 'Импортировано ↓';
	@override String get importOldest => 'Импортировано ↑';
	@override String get modifiedNewest => 'Изменено ↓';
	@override String get modifiedOldest => 'Изменено ↑';
	@override String get interactedNewest => 'Взаимодействие ↓';
	@override String get interactedOldest => 'Взаимодействие ↑';
	@override String get tokensHigh => 'Токены ↓';
	@override String get tokensLow => 'Токены ↑';
}

// Path: grid.filterController
class _TranslationsGridFilterControllerRu extends _TranslationsGridFilterControllerEn {
	_TranslationsGridFilterControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get filterCreators => 'Фильтр по авторам';
	@override String get filterTags => 'Фильтр по тегам';
	@override String get filterByFolder => 'Фильтр по папке';
}

// Path: grid.multiSelectDialog
class _TranslationsGridMultiSelectDialogRu extends _TranslationsGridMultiSelectDialogEn {
	_TranslationsGridMultiSelectDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get nothingToShow => 'Пока нечего показать.';
	@override String get noMatches => 'Совпадений нет.';
	@override String get showMore => 'Показать ещё';
}

// Path: grid.createCharacterDialog
class _TranslationsGridCreateCharacterDialogRu extends _TranslationsGridCreateCharacterDialogEn {
	_TranslationsGridCreateCharacterDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get nameEmptyError => 'Имя персонажа не может быть пустым.';
	@override String get nameInvalidCharsError => 'Имя содержит недопустимые символы (<>:"/\|?*).';
	@override String get nameExistsError => 'Персонаж с таким именем уже существует.';
	@override String get nameCheckFailedError => 'Не удалось проверить имя. Проверьте права доступа к папке и попробуйте снова.';
	@override String get title => 'Создать персонажа';
	@override String get nameLabel => 'Имя персонажа';
	@override String get createButton => 'Создать';
}

// Path: grid.variantsSheet
class _TranslationsGridVariantsSheetRu extends _TranslationsGridVariantsSheetEn {
	_TranslationsGridVariantsSheetRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Варианты';
}

// Path: grid.groupAppBar
class _TranslationsGridGroupAppBarRu extends _TranslationsGridGroupAppBarEn {
	_TranslationsGridGroupAppBarRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get characters => 'Персонажи';
	@override String get newGroup => 'Новая группа';
}

// Path: grid.thumbnailBadges
class _TranslationsGridThumbnailBadgesRu extends _TranslationsGridThumbnailBadgesEn {
	_TranslationsGridThumbnailBadgesRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get recent => 'НЕДАВНИЙ';
	@override String get original => 'ОРИГИНАЛ';
	@override String get variant => 'ВАРИАНТ';
}

// Path: grid.actionMenu
class _TranslationsGridActionMenuRu extends _TranslationsGridActionMenuEn {
	_TranslationsGridActionMenuRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get editNotes => 'Редактировать заметки';
	@override String get dismissRecent => 'Убрать из недавних';
	@override String get exportPngV2V3 => 'Экспорт как PNG (V2/V3)';
	@override String get exportJsonV3 => 'Экспорт как JSON (V3)';
	@override String get exportJsonV2 => 'Экспорт как JSON (V2)';
	@override String get duplicate => 'Дублировать';
}

// Path: grid.controllerMessages
class _TranslationsGridControllerMessagesRu extends _TranslationsGridControllerMessagesEn {
	_TranslationsGridControllerMessagesRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get duplicateFailed => 'Не удалось дублировать персонажа.';
	@override String get editVariantNotesTitle => 'Редактировать заметки варианта';
	@override String get editVariantNotesHint => 'Добавьте заметки об этом варианте...';
	@override String get deleteCardTitle => 'Удалить карточку';
	@override String get deleteCardMessage => 'Вы уверены, что хотите удалить эту карточку?';
	@override String get deletePartialFailure => 'Некоторые файлы не удалось удалить. Подробности в логах.';
}

// Path: grid.tagWrap
class _TranslationsGridTagWrapRu extends _TranslationsGridTagWrapEn {
	_TranslationsGridTagWrapRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String tagCountLabel({required Object tag, required Object count}) => '${tag} (${count})';
}

// Path: group.groupGridController
class _TranslationsGroupGroupGridControllerRu extends _TranslationsGroupGroupGridControllerEn {
	_TranslationsGroupGroupGridControllerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get renameGroupTitle => 'Переименовать группу';
	@override String get groupNameHint => 'Название группы';
	@override String get deleteGroupTitle => 'Удалить группу';
	@override String deleteGroupMessage({required Object name}) => 'Вы уверены, что хотите удалить «${name}»? Это нельзя отменить.';
}

// Path: group.groupChatPage
class _TranslationsGroupGroupChatPageRu extends _TranslationsGroupGroupChatPageEn {
	_TranslationsGroupGroupChatPageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get defaultGroupName => 'Групповой чат';
	@override String failedToLoadMessage({required Object error}) => 'Не удалось загрузить групповой чат:\n${error}';
	@override String get nextTurnTooltip => 'Следующий ход';
	@override String get stopAutoChatTooltip => 'Остановить авточат';
	@override String get startAutoChatTooltip => 'Запустить авточат';
	@override String get stopGenerationTooltip => 'Остановить генерацию';
	@override String get noCharactersYetMessage => 'В этой группе пока нет персонажей.';
	@override String get addCharacterButton => 'Добавить персонажа';
	@override String get pickCharacterMessage => 'Выберите персонажа из списка слева.';
}

// Path: group.groupGridPage
class _TranslationsGroupGroupGridPageRu extends _TranslationsGroupGroupGridPageEn {
	_TranslationsGroupGroupGridPageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String failedToLoadMessage({required Object error}) => 'Не удалось загрузить группы:\n${error}';
	@override String get unknownErrorFallback => 'неизвестная ошибка';
	@override String get noGroupsYetMessage => 'Групп пока нет — нажмите +, чтобы создать.';
}

// Path: group.tileAutoChatDelay
class _TranslationsGroupTileAutoChatDelayRu extends _TranslationsGroupTileAutoChatDelayEn {
	_TranslationsGroupTileAutoChatDelayRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Задержка авточата';
	@override String secondsAbbrev({required Object seconds}) => '${seconds} с';
}

// Path: group.tileActivationStrategy
class _TranslationsGroupTileActivationStrategyRu extends _TranslationsGroupTileActivationStrategyEn {
	_TranslationsGroupTileActivationStrategyRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Выбор говорящего';
	@override String get naturalOption => 'Естественный';
	@override String get roundRobinOption => 'По кругу';
	@override String get randomOption => 'Случайный';
	@override String get changeSelectionTooltip => 'Изменить выбор говорящего';
}

// Path: group.groupChatPageEndDrawer
class _TranslationsGroupGroupChatPageEndDrawerRu extends _TranslationsGroupGroupChatPageEndDrawerEn {
	_TranslationsGroupGroupChatPageEndDrawerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get allowWebFetchTitle => 'Разрешить веб-запросы';
	@override String get allowWebFetchSubtitle => 'Читать публичные веб-страницы, когда это уместно';
	@override String get reviewUrlTitle => 'Проверять URL перед запросом';
	@override String get reviewUrlSubtitle => 'Подтверждать каждый запрос';
	@override String get suggestNpcNamesTitle => 'Предлагать имена NPC';
	@override String get suggestNpcNamesSubtitle => 'Выбирать имена из курируемой базы';
	@override String get unrestrictedImagesTitle => 'Изображения без ограничений';
	@override String get allowNsfwImagePromptsSubtitle => 'Разрешить NSFW-промпты изображений';
	@override String get characterCanSendSelfiesTitle => 'Персонаж может отправлять селфи';
	@override String get attachSelfieWhenNaturalSubtitle => 'Прикреплять селфи, когда это естественно';
	@override String get reviewImagePromptTitle => 'Проверять промпт изображения';
	@override String get editBeforeGeneratingSubtitle => 'Редактировать перед генерацией';
	@override String get reviewToolImagePromptsTitle => 'Проверять промпты изображений от инструментов';
	@override String get editToolTriggeredPromptsSubtitle => 'Редактировать промпты, вызванные инструментами';
	@override String get allowSelfieCaptionsTitle => 'Разрешить подписи к селфи';
	@override String get captionRenderedOnImageSubtitle => 'Подпись наносится на изображение';
	@override String get groupOverridesTitle => 'Переопределения группы';
	@override String get groupOverridesSubtitle => 'Общий сценарий, основной промпт, пример диалога';
	@override String get chatSessionSubtitle => 'Сессия чата';
	@override String get allChatsLabel => 'Все чаты';
	@override String get showImageLabel => 'Показать изображение';
	@override String get groupSectionHeader => 'Группа';
	@override String get chatSectionHeader => 'Чат';
	@override String get chatThemeSectionHeader => 'Тема чата';
	@override String get unrestrictedVideosTitle => 'Видео без ограничений';
	@override String get allowNsfwVideoPromptsSubtitle => 'Разрешить NSFW-промпты видео';
	@override String get characterCanSendVideosTitle => 'Персонаж может отправлять видео';
	@override String get attachShortVideoWhenNaturalSubtitle => 'Прикреплять короткое видео, когда это естественно';
	@override String get reviewVideoPromptTitle => 'Проверять промпт видео';
}

// Path: group.groupCharacterPicker
class _TranslationsGroupGroupCharacterPickerRu extends _TranslationsGroupGroupCharacterPickerEn {
	_TranslationsGroupGroupCharacterPickerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get addButton => 'Добавить';
	@override String addWithCountButton({required Object count}) => 'Добавить ${count}';
	@override String get favoritesTooltip => 'Избранное';
	@override String noMatchMessage({required Object query}) => 'Нет персонажей по запросу «${query}»';
	@override String get noFavoritesMessage => 'Нет избранных персонажей';
	@override String get allAddedMessage => 'Все персонажи уже добавлены';
}

// Path: group.groupCharacterTile
class _TranslationsGroupGroupCharacterTileRu extends _TranslationsGroupGroupCharacterTileEn {
	_TranslationsGroupGroupCharacterTileRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get speakTooltip => 'Заставить этого персонажа говорить';
	@override String get removeFromChatTitle => 'Убрать из чата';
}

// Path: group.dialogCreateGroup
class _TranslationsGroupDialogCreateGroupRu extends _TranslationsGroupDialogCreateGroupEn {
	_TranslationsGroupDialogCreateGroupRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Новая группа';
	@override String get nameLabel => 'Название';
	@override String get nameHint => 'напр., Боб и Алиса';
}

// Path: group.dialogGroupOverrides
class _TranslationsGroupDialogGroupOverridesRu extends _TranslationsGroupDialogGroupOverridesEn {
	_TranslationsGroupDialogGroupOverridesRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get explanationMessage => 'Уникально для этого чата. Все участники группы используют эти значения вместо того, что задано в их карточках. Оставьте пустым, чтобы вернуться к значению карточки.';
	@override String get scenarioHint => 'Общая обстановка для группы (напр., «В кафе в Париже»)';
	@override String get mainPromptLabel => 'Основной промпт';
	@override String get mainPromptHint => 'Системный промпт, применяемый на каждом ходу';
	@override String get exampleDialogueLabel => 'Пример диалога';
	@override String get exampleDialogueHint => 'Общие примеры сообщений для тона/форматирования';
}

// Path: group.groupCharacterPanel
class _TranslationsGroupGroupCharacterPanelRu extends _TranslationsGroupGroupCharacterPanelEn {
	_TranslationsGroupGroupCharacterPanelRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get addCharacterButton => 'Добавить персонажа';
	@override String get noCharactersYetMessage => 'Персонажей пока нет.\nНажмите +, чтобы добавить.';
}

// Path: group.dialogSelectGroup
class _TranslationsGroupDialogSelectGroupRu extends _TranslationsGroupDialogSelectGroupEn {
	_TranslationsGroupDialogSelectGroupRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get deleteGroupTitle => 'Удалить группу?';
	@override String deleteGroupMessage({required Object name}) => '«${name}» и все её сессии чата будут безвозвратно удалены.';
	@override String get title => 'Группы';
	@override String get noGroupsYetMessage => 'Групп пока нет. Нажмите «Новая группа», чтобы создать.';
	@override String memberCountLabel({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} участник',
		few: '${n} участника',
		many: '${n} участников',
		other: '${n} участника',
	);
}

// Path: group.groupGridItem
class _TranslationsGroupGroupGridItemRu extends _TranslationsGroupGroupGridItemEn {
	_TranslationsGroupGroupGridItemRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String overflowCountBadge({required Object count}) => '+${count}';
	@override String get noMembersYetMessage => 'Пока нет участников';
}

// Path: group.groupFileService
class _TranslationsGroupGroupFileServiceRu extends _TranslationsGroupGroupFileServiceEn {
	_TranslationsGroupGroupFileServiceRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get defaultGroupName => 'Группа';
}

// Path: llmApp.mediaField
class _TranslationsLlmAppMediaFieldRu extends _TranslationsLlmAppMediaFieldEn {
	_TranslationsLlmAppMediaFieldRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get imageModel => 'Модель изображений';
	@override String get imageAspectRatio => 'Соотношение сторон изображения';
	@override String get imageNsfwAllowed => 'Разрешить NSFW-изображения';
	@override String get imageToolSelfieAllowed => 'Может отправлять селфи';
	@override String get imageToolSelfieCaptionsAllowed => 'Разрешить подписи к селфи';
	@override String get imagePromptPrefix => 'Стиль изображения';
	@override String get videoModel => 'Модель видео';
	@override String get videoResolution => 'Разрешение видео';
	@override String get videoAspectRatio => 'Соотношение сторон видео';
	@override String get videoDuration => 'Длительность видео';
	@override String get videoNsfwAllowed => 'Разрешить NSFW-видео';
	@override String get videoToolSendAllowed => 'Может отправлять видео';
	@override String get videoPromptPrefix => 'Стиль видео';
	@override String get ttsModel => 'Модель TTS';
	@override String get ttsVoice => 'Голос TTS';
	@override String get ttsLanguage => 'Язык TTS';
	@override String get webToolFetchAllowed => 'Разрешить веб-запросы';
	@override String get nameToolSuggestAllowed => 'Может предлагать имена NPC';
}

// Path: llmApp.mediaSection
class _TranslationsLlmAppMediaSectionRu extends _TranslationsLlmAppMediaSectionEn {
	_TranslationsLlmAppMediaSectionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get image => 'Изображение';
	@override String get video => 'Видео';
	@override String get tts => 'TTS';
	@override String get web => 'Веб';
	@override String get names => 'Имена';
}

// Path: llmApp.tristate
class _TranslationsLlmAppTristateRu extends _TranslationsLlmAppTristateEn {
	_TranslationsLlmAppTristateRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get on => 'Вкл.';
	@override String get off => 'Выкл.';
	@override String get inherit => 'Наследовать';
}

// Path: llmApp.mediaCellMenu
class _TranslationsLlmAppMediaCellMenuRu extends _TranslationsLlmAppMediaCellMenuEn {
	_TranslationsLlmAppMediaCellMenuRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get change => 'Изменить…';
	@override String get clear => 'Очистить';
}

// Path: llmApp.mediaHeader
class _TranslationsLlmAppMediaHeaderRu extends _TranslationsLlmAppMediaHeaderEn {
	_TranslationsLlmAppMediaHeaderRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get appDefault => 'По умолчанию';
	@override String get character => 'Персонаж';
	@override String get currentChat => 'Текущий чат';
	@override String get previousLayerTooltip => 'Предыдущий слой';
	@override String get nextLayerTooltip => 'Следующий слой';
}

// Path: llmApp.presetRow
class _TranslationsLlmAppPresetRowRu extends _TranslationsLlmAppPresetRowEn {
	_TranslationsLlmAppPresetRowRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get changeAppDefaultTitle => 'Изменить значение по умолчанию?';
	@override String get changeAppDefaultMessage => 'Это затронет каждый чат. Продолжить?';
	@override String get continueButton => 'Продолжить';
	@override String chooseModelTitle({required Object domain}) => 'Выберите модель для «${domain}»';
}

// Path: llmApp.mediaCell
class _TranslationsLlmAppMediaCellRu extends _TranslationsLlmAppMediaCellEn {
	_TranslationsLlmAppMediaCellRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get notApplicable => 'Неприменимо';
}

// Path: onboarding.storageStep
class _TranslationsOnboardingStorageStepRu extends _TranslationsOnboardingStorageStepEn {
	_TranslationsOnboardingStorageStepRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Хранение персонажей';
	@override String get subtitle => 'Где сохранять ваши карточки персонажей?';
	@override String get description => 'По умолчанию сохраняются в папке приложения. Укажите существующую папку с PNG, чтобы импортировать их.';
	@override String get startFresh => 'Начать с нуля';
	@override String get haveCards => 'У меня уже есть карточки';
	@override String get importLaterHint => 'Импортировать PNG можно позже через Файл → Импорт.';
	@override String selectedPath({required Object path}) => 'Выбрано: ${path}';
	@override String get selectedDefaultFolder => 'Выбрано: папка приложения по умолчанию';
	@override String get noFolderSelected => 'Папка ещё не выбрана.';
}

// Path: onboarding.setupStep
class _TranslationsOnboardingSetupStepRu extends _TranslationsOnboardingSetupStepEn {
	_TranslationsOnboardingSetupStepRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'ИИ и персона';
}

// Path: onboarding.aiSection
class _TranslationsOnboardingAiSectionRu extends _TranslationsOnboardingAiSectionEn {
	_TranslationsOnboardingAiSectionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get heading => 'Подключение ИИ';
	@override String get optionalHint => 'Необязательно — можно пропустить и добавить ключ позже в настройках (локальные провайдеры тоже добавляются там).';
	@override String get apiKeyLabel => 'Ключ API';
	@override String get apiKeyHint => 'Вставьте ключ (или пропустите пока)';
	@override String get supportedProviders => 'Поддерживает OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. Больше — в настройках.';
	@override String get unknownModel => '(неизвестная модель)';
	@override String get ctxUnknown => 'ctx —';
	@override String ctxValue({required Object ctx}) => 'ctx ${ctx}';
	@override String kvSuffix({required Object kv}) => ' · KV ${kv}';
	@override String get changeButton => 'Изменить';
}

// Path: onboarding.aiStatus
class _TranslationsOnboardingAiStatusRu extends _TranslationsOnboardingAiStatusEn {
	_TranslationsOnboardingAiStatusRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get connecting => 'Подключение…';
	@override String connected({required Object provider}) => 'Подключено к ${provider}. Выбрана модель чата по умолчанию.';
	@override String detected({required Object provider}) => 'Обнаружено: ${provider}';
	@override String get unrecognizedKey => 'Нераспознанный формат ключа.';
}

// Path: onboarding.personaSection
class _TranslationsOnboardingPersonaSectionRu extends _TranslationsOnboardingPersonaSectionEn {
	_TranslationsOnboardingPersonaSectionRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get heading => 'Ваша персона';
	@override String get hint => 'Ваше имя в чатах. Подробнее о персоне — в настройках.';
	@override String get nameLabel => 'Ваше имя';
}

// Path: onboarding.disclaimer
class _TranslationsOnboardingDisclaimerRu extends _TranslationsOnboardingDisclaimerEn {
	_TranslationsOnboardingDisclaimerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get prefix => 'Я прочитал(а) и принимаю ';
	@override String get linkText => 'Дисклеймер';
}

// Path: onboarding.fetchError
class _TranslationsOnboardingFetchErrorRu extends _TranslationsOnboardingFetchErrorEn {
	_TranslationsOnboardingFetchErrorRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noModels => 'Модели не получены. Проверьте свой ключ API.';
	@override String get connectionFailed => 'Не удалось подключиться. Проверьте интернет-соединение и ключ API.';
}

// Path: routing.chatCharacter
class _TranslationsRoutingChatCharacterRu extends _TranslationsRoutingChatCharacterEn {
	_TranslationsRoutingChatCharacterRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object name}) => 'Ошибка перехода к чату. Персонаж: ${name}';
}

// Path: routing.editCharacter
class _TranslationsRoutingEditCharacterRu extends _TranslationsRoutingEditCharacterEn {
	_TranslationsRoutingEditCharacterRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object name}) => 'Ошибка перехода к редактированию. Персонаж: ${name}';
}

// Path: routing.editPreset
class _TranslationsRoutingEditPresetRu extends _TranslationsRoutingEditPresetEn {
	_TranslationsRoutingEditPresetRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object presetId}) => 'Ошибка перехода к редактированию пресета: ${presetId}';
}

// Path: settings.gearMenu
class _TranslationsSettingsGearMenuRu extends _TranslationsSettingsGearMenuEn {
	_TranslationsSettingsGearMenuRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get settingsTooltip => 'Настройки';
	@override String get mediaDefaultsApp => 'Приложение';
	@override String get mediaDefaultsCharacter => 'Персонаж';
	@override String get mediaDefaultsChat => 'Чат';
	@override String get appSettings => 'Настройки приложения';
	@override String get logs => 'Логи';
}

// Path: settings.mediaDefaultsDrawerEntry
class _TranslationsSettingsMediaDefaultsDrawerEntryRu extends _TranslationsSettingsMediaDefaultsDrawerEntryEn {
	_TranslationsSettingsMediaDefaultsDrawerEntryRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get configurationHeader => 'Конфигурация';
}

// Path: settings.endDrawer
class _TranslationsSettingsEndDrawerRu extends _TranslationsSettingsEndDrawerEn {
	_TranslationsSettingsEndDrawerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get switchPersonaTooltip => 'Сменить персону';
}

// Path: settings.loadingStatus
class _TranslationsSettingsLoadingStatusRu extends _TranslationsSettingsLoadingStatusEn {
	_TranslationsSettingsLoadingStatusRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get restoringProviders => 'Восстановление провайдеров…';
	@override String fetchingModelsProgress({required Object completed, required Object total}) => 'Загрузка моделей (${completed}/${total})…';
}

// Path: settings.general
class _TranslationsSettingsGeneralRu extends _TranslationsSettingsGeneralEn {
	_TranslationsSettingsGeneralRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get characterFolderTitle => 'Папка персонажей';
	@override String get characterFolderNotSet => 'Не задана. Требуется для работы приложения.';
	@override String get browseButton => 'Обзор...';
	@override String get taxonomyTagsTitle => 'Теги таксономии';
	@override String get appThemeTitle => 'Тема приложения';
	@override String get themeSystem => 'Системная';
	@override String get themeLight => 'Светлая';
	@override String get themeDark => 'Тёмная';
	@override String get themeStyleTitle => 'Стиль темы';
	@override String get themeStyleDefault => 'По умолчанию';
	@override String get themeStyleNeon => 'Неон';
	@override String get storyMemoryTitle => 'Память истории';
	@override String get storyMemorySubtitle => 'Запоминать ранние моменты и возвращать нужные из них в длинных чатах.';
	@override String get narrativeEngineTitle => 'Нарративный движок';
	@override String get narrativeEngineSubtitle => 'Отслеживать сцену и персонажей и двигать историю по мере вашей переписки.';
	@override String get promptBreakdownTitle => 'Показывать разбор промпта';
	@override String get promptBreakdownSubtitle => 'Показывать под каждым ответом полосу, разбивающую, как промпт заполнил контекстное окно модели.';
	@override String get checkUpdatesTitle => 'Проверить обновления';
	@override String get checkUpdatesSubtitle => 'Проверить, доступна ли более новая версия приложения.';
	@override String get websiteTitle => 'Сайт';
	@override String get websiteSubtitle => 'Посетите официальный сайт для обновлений и информации.';
	@override String get disclaimerTitle => 'Дисклеймер и условия';
	@override String get disclaimerSubtitle => 'Прочитайте дисклеймер приложения и условия использования.';
	@override String versionLabel({required Object version, required Object buildNumber}) => 'Версия ${version}+${buildNumber}';
}

// Path: settings.aiSettingsTab
class _TranslationsSettingsAiSettingsTabRu extends _TranslationsSettingsAiSettingsTabEn {
	_TranslationsSettingsAiSettingsTabRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get aiProviders => 'Провайдеры ИИ';
	@override String get mediaDefaults => 'Медиа по умолчанию';
}

// Path: settings.aiTab
class _TranslationsSettingsAiTabRu extends _TranslationsSettingsAiTabEn {
	_TranslationsSettingsAiTabRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String refreshSummary({required Object updated, required Object unavailable, required Object errors}) => 'Обновлено моделей: ${updated}, недоступно: ${unavailable}, ошибок: ${errors}.';
	@override String get newProviderButton => 'Новый провайдер';
	@override String get cloudProviderMenuItem => 'Облачный провайдер';
	@override String get localProviderMenuItem => 'Локальный провайдер';
	@override String get localGgufMenuItem => 'Локальный GGUF';
	@override String get noProvidersConfigured => 'Провайдеры API не настроены.';
	@override String get addingProviderOverlay => 'Добавление провайдера…';
	@override String get neverRefreshed => 'Никогда не обновлялось';
	@override String lastRefreshedLabel({required Object time}) => 'Последнее обновление: ${time}';
	@override String get refreshModelsButton => 'Обновить модели';
	@override String get refreshNowMenuItem => 'Обновить сейчас';
	@override String get autoNeverMenuItem => 'Авто: никогда';
	@override String get autoDailyMenuItem => 'Авто: ежедневно при запуске';
	@override String get defaultModelsHeader => 'Модели по умолчанию для новых чатов';
	@override String get editModelTooltip => 'Редактировать модель';
	@override String get noModelsPlaceholder => 'Нет моделей';
	@override String get noCompatibleModelsPlaceholder => 'Нет совместимых моделей';
	@override String get tapToChoosePlaceholder => 'Нажмите, чтобы выбрать';
	@override String get modelUsedForPrefix => 'Модель для ';
	@override String get modelUsedForSuffix => ' генерации';
	@override String get chooseModelTitle => 'Выберите модель';
	@override String temperatureLabel({required Object value}) => 'Темп. ${value}';
	@override String get setDefaultButton => 'По умолчанию';
	@override String get addModelButton => 'Добавить модель';
	@override String get editProviderMenuItem => 'Редактировать провайдера';
	@override String get moreTooltip => 'Ещё';
	@override String get noModelsForProvider => 'Для этого провайдера не настроено ни одной модели.';
	@override String setDefaultConfirmTitle({required Object provider}) => 'Сделать ${provider} провайдером по умолчанию для всех функций ИИ?';
	@override String get setDefaultConfirmMessage => 'Вы можете сами выбрать модели для неподдерживаемых функций\n(например, изображение или видео) у других провайдеров.';
	@override String localGgufSubtitle({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (макс. ${native}) · KV ${kv}';
	@override String get testTtsTooltip => 'Проверить TTS';
	@override String get ttsTestPhrase => 'Здравствуйте, это проверка.';
	@override String get ttsFailedError => 'Ошибка TTS.';
	@override String get testVideoTooltip => 'Проверить генерацию видео';
	@override String get videoGeneratedWebFallback => 'Видео успешно сгенерировано (предпросмотр недоступен в вебе).';
	@override String get videoFailedError => 'Ошибка видео.';
	@override String get videoLoadFailedMessage => 'Не удалось загрузить сгенерированное видео.';
	@override String get presetPickerSearchHint => 'Поиск по провайдеру, модели или пресету…';
	@override String tempParamAbbrev({required Object value}) => 'темп. ${value}';
	@override String reasoningParamLabel({required Object level}) => 'рассуждения ${level}';
}

// Path: settings.presetConfig
class _TranslationsSettingsPresetConfigRu extends _TranslationsSettingsPresetConfigEn {
	_TranslationsSettingsPresetConfigRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get testMessageButton => 'Тестовое сообщение';
	@override String get testSuccessLabel => 'Успех';
	@override String get testFailedLabel => 'Ошибка';
	@override String get deleteModelTitle => 'Удалить модель?';
	@override String deleteModelMessage({required Object name}) => 'Безвозвратно удалить «${name}»? Это нельзя отменить.';
	@override String get editModelHeader => 'Редактировать модель';
	@override String get addModelHeader => 'Добавить модель';
	@override String get resetToDefaultsTooltip => 'Сбросить к значениям по умолчанию';
	@override String get modelNameLabel => 'Название модели';
	@override String get clearTooltip => 'Очистить';
	@override String get nameRequiredError => 'Требуется имя';
	@override String get modelLabel => 'Модель';
	@override String get selectModelHint => 'Выберите модель';
	@override String get modelRequiredError => 'Требуется модель';
	@override String filteredDomainsNote({required Object domains}) => 'Модели отфильтрованы для поддержки активных доменов: ${domains}';
	@override String get requiredValidator => 'Обязательно';
	@override String get invalidValidator => 'Недопустимо';
	@override String get testResponseTitle => 'Ответ';
}

// Path: settings.providerConfig
class _TranslationsSettingsProviderConfigRu extends _TranslationsSettingsProviderConfigEn {
	_TranslationsSettingsProviderConfigRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noModelsError => 'Модели не получены. Проверьте свой ключ API.';
	@override String get connectionFailedError => 'Не удалось подключиться. Проверьте интернет-соединение и ключ API.';
	@override String get deleteProviderTitle => 'Удалить провайдера?';
	@override String deleteProviderMessage({required Object provider}) => 'Безвозвратно удалить провайдера ${provider} и все его пресеты? Это нельзя отменить.';
	@override String lockHint({required Object roles}) => 'Нельзя удалить: используется в ${roles}.';
	@override String get editProviderHeader => 'Редактировать провайдера';
	@override String get addProviderHeader => 'Добавить провайдера';
	@override String get apiKeyLabel => 'Ключ API';
	@override String get apiKeyHintRotate => 'Вставьте новый ключ для замены';
	@override String get apiKeyHintNew => 'Вставьте ключ — провайдер определится автоматически';
	@override String get supportedProvidersNote => 'Поддерживает OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
	@override String keyMismatchError({required Object owner, required Object profile}) => 'Этот ключ принадлежит ${owner}, но профиль — ${profile}. Удалите этот профиль и добавьте новый.';
	@override String get anotherProviderFallback => 'другой провайдер';
	@override String get connectingStatus => 'Подключение…';
	@override String connectedStatus({required Object provider}) => 'Подключено к ${provider}. Будут созданы пресеты по умолчанию.';
	@override String detectedStatus({required Object provider}) => 'Обнаружено: ${provider}';
	@override String get unrecognizedKeyStatus => 'Нераспознанный формат ключа.';
}

// Path: settings.localProviderConfig
class _TranslationsSettingsLocalProviderConfigRu extends _TranslationsSettingsLocalProviderConfigEn {
	_TranslationsSettingsLocalProviderConfigRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String serverUnreachableMessage({required Object url}) => 'Не удалось связаться с ${url}. Убедитесь, что ваш локальный сервер (KoboldCpp / Ollama / LM Studio / llama.cpp) запущен.';
	@override String get noModelsError => 'Сервер доступен, но не вернул моделей. Сначала загрузите модель на локальном сервере.';
	@override String get deleteProviderMessage => 'Безвозвратно удалить этого локального провайдера и все его пресеты? Это нельзя отменить.';
	@override String get editHeader => 'Редактировать локального провайдера';
	@override String get addHeader => 'Добавить локального провайдера';
	@override String get serverUrlLabel => 'URL сервера';
	@override String get serverUrlLockedHelper => 'Заблокировано. Удалите этого провайдера и добавьте нового, чтобы указать другой сервер.';
	@override String get apiKeyOptionalLabel => 'Ключ API (необязательно)';
	@override String get apiKeyOptionalHint => 'Оставьте пустым — большинству локальных серверов ключ не нужен';
	@override String get connectFetchButton => 'Подключиться и загрузить модели';
	@override String connectedFoundModels({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Подключено. Найдена ${n} модель.',
		few: 'Подключено. Найдено ${n} модели.',
		many: 'Подключено. Найдено ${n} моделей.',
		other: 'Подключено. Найдено ${n} модели.',
	);
}

// Path: settings.localGguf
class _TranslationsSettingsLocalGgufRu extends _TranslationsSettingsLocalGgufEn {
	_TranslationsSettingsLocalGgufRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get haveLocalGgufExpanderTitle => 'У меня есть локальный файл GGUF';
	@override String get pickFileLabel => 'Выбрать файл GGUF...';
	@override String get loadModelLabel => 'Загрузить модель';
	@override String get nativeContextLabel => 'Родной контекст';
	@override String get freeVramLabel => 'Свободная VRAM';
	@override String get contextSizeLabel => 'Размер контекста';
	@override String get kvCacheLabel => 'Кэш KV';
	@override String get kvCacheAutoLabel => 'Авто';
	@override String modelTooLargeForVramMessage({required Object neededMb, required Object freeMb}) => 'Этой модели нужно около ${neededMb}МБ памяти GPU, но свободно только ${freeMb}МБ. Закройте другие приложения GPU или выберите меньшую / более квантованную модель.';
	@override String modelBarelyFitsMessage({required Object minimumContext}) => 'Эта модель едва помещается даже с KV-кэшем q4_0 при ${minimumContext} токенах. Рассмотрите более агрессивно квантованный файл модели.';
	@override String get readingMetadata => 'Чтение метаданных модели…';
	@override String get architectureLabel => 'Архитектура';
	@override String autoKvHint({required Object picked, required Object max}) => 'авто: ${picked} (макс. ${max})';
	@override String maxKvHint({required Object max, required Object picked}) => 'макс. ${max} при KV ${picked}';
	@override String ctxExceedsMaxError({required Object max, required Object picked}) => 'свыше ${max} при KV ${picked} — загрузка может вызвать OOM';
	@override String get vramNotDetected => 'не определено';
	@override String readMetadataFailedError({required Object error}) => 'Не удалось прочитать метаданные GGUF: ${error}';
	@override String loadModelFailedError({required Object error}) => 'Не удалось загрузить модель: ${error}';
}

// Path: settings.personaDialog
class _TranslationsSettingsPersonaDialogRu extends _TranslationsSettingsPersonaDialogEn {
	_TranslationsSettingsPersonaDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newTitle => 'Новая персона';
	@override String get editTitle => 'Редактировать персону';
	@override String get nameLabel => 'Имя';
	@override String get nameRequiredError => 'Требуется имя';
	@override String get descriptionLabel => 'Описание';
	@override String get descriptionHint => 'Внешность, характер, предыстория и т. д.';
}

// Path: settings.personasTab
class _TranslationsSettingsPersonasTabRu extends _TranslationsSettingsPersonasTabEn {
	_TranslationsSettingsPersonasTabRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get cannotDeleteDefaultTooltip => 'Нельзя удалить персону по умолчанию';
	@override String get deleteTooltip => 'Удалить персону';
	@override String get cannotDeleteDefaultSnackbar => 'Нельзя удалить персону по умолчанию.';
	@override String get deleteConfirmTitle => 'Удалить персону';
	@override String deleteConfirmMessage({required Object name}) => 'Вы уверены, что хотите удалить «${name}»?';
}

// Path: settings.updateCheck
class _TranslationsSettingsUpdateCheckRu extends _TranslationsSettingsUpdateCheckEn {
	_TranslationsSettingsUpdateCheckRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get upToDateTitle => 'Актуальная версия';
	@override String upToDateMessage({required Object version}) => 'У вас установлена текущая версия (${version}).';
	@override String get notApplicableTitle => 'Проверка обновлений';
	@override String get notApplicableMessage => 'Проверка версии недоступна в вебе.';
	@override String get errorTitle => 'Ошибка';
	@override String get serverErrorMessage => 'Не удалось проверить обновления. Ошибка сервера.';
	@override String get connectionErrorMessage => 'Не удалось проверить обновления. Проверьте соединение.';
}

// Path: workspace.workspaceEndDrawerImage
class _TranslationsWorkspaceWorkspaceEndDrawerImageRu extends _TranslationsWorkspaceWorkspaceEndDrawerImageEn {
	_TranslationsWorkspaceWorkspaceEndDrawerImageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get imageStyleTitle => 'Стиль изображения';
	@override String get noneValue => 'Нет';
}

// Path: workspace.workspaceEndDrawerVideo
class _TranslationsWorkspaceWorkspaceEndDrawerVideoRu extends _TranslationsWorkspaceWorkspaceEndDrawerVideoEn {
	_TranslationsWorkspaceWorkspaceEndDrawerVideoRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get videoStyleTitle => 'Стиль видео';
}

// Path: workspace.workspaceEndDrawerDisplay
class _TranslationsWorkspaceWorkspaceEndDrawerDisplayRu extends _TranslationsWorkspaceWorkspaceEndDrawerDisplayEn {
	_TranslationsWorkspaceWorkspaceEndDrawerDisplayRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Отображение';
	@override String get showCharacterImageTitle => 'Показывать изображение персонажа';
	@override String get wideScreenOnlySubtitle => 'Только в широкоэкранном редакторе';
}

// Path: workspace.workspaceEndDrawerAi
class _TranslationsWorkspaceWorkspaceEndDrawerAiRu extends _TranslationsWorkspaceWorkspaceEndDrawerAiEn {
	_TranslationsWorkspaceWorkspaceEndDrawerAiRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'ИИ';
}

// Path: workspace.workspaceEndDrawerEditing
class _TranslationsWorkspaceWorkspaceEndDrawerEditingRu extends _TranslationsWorkspaceWorkspaceEndDrawerEditingEn {
	_TranslationsWorkspaceWorkspaceEndDrawerEditingRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Редактирование';
}

// Path: workspace.workspaceEndDrawerExport
class _TranslationsWorkspaceWorkspaceEndDrawerExportRu extends _TranslationsWorkspaceWorkspaceEndDrawerExportEn {
	_TranslationsWorkspaceWorkspaceEndDrawerExportRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Экспорт';
	@override String get exportPngTitle => 'Экспорт как PNG (V2/V3)';
	@override String get exportJsonV3Title => 'Экспорт как JSON (V3)';
	@override String get exportJsonV2Title => 'Экспорт как JSON (V2)';
}

// Path: workspace.workspaceEndDrawerChatTheme
class _TranslationsWorkspaceWorkspaceEndDrawerChatThemeRu extends _TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatThemeRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get resetImagesTitle => 'Сбросить изображения';
}

// Path: workspace.workspaceEndDrawerChat
class _TranslationsWorkspaceWorkspaceEndDrawerChatRu extends _TranslationsWorkspaceWorkspaceEndDrawerChatEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get assistantCardEditsSectionHeader => 'Правки карточки ассистентом';
}

// Path: workspace.workspaceEndDrawer
class _TranslationsWorkspaceWorkspaceEndDrawerRu extends _TranslationsWorkspaceWorkspaceEndDrawerEn {
	_TranslationsWorkspaceWorkspaceEndDrawerRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get favoriteLabel => 'Избранное';
	@override String get nodesEngineTitle => 'Движок NODES';
	@override String get debugSnapshotSubtitle => 'Отладочный снимок';
	@override String get characterSubtitle => 'Персонаж';
}

// Path: workspace.stylePresetsDialog
class _TranslationsWorkspaceStylePresetsDialogRu extends _TranslationsWorkspaceStylePresetsDialogEn {
	_TranslationsWorkspaceStylePresetsDialogRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noStyleSelectedMessage => 'Стиль не выбран';
}

// Path: workspace.workspacePage
class _TranslationsWorkspaceWorkspacePageRu extends _TranslationsWorkspaceWorkspacePageEn {
	_TranslationsWorkspaceWorkspacePageRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get rebuildingChatIndexMessage => 'Перестроение индекса чата...';
	@override String get selectChatToStartMessagingMessage => 'Выберите чат, чтобы начать переписку';
	@override String get failedToLoadAssistantMessage => 'Не удалось загрузить ассистента.';
}

// Path: character.cardEditApproval.modalityLabel
class _TranslationsCharacterCardEditApprovalModalityLabelRu extends _TranslationsCharacterCardEditApprovalModalityLabelEn {
	_TranslationsCharacterCardEditApprovalModalityLabelRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get edits => 'правки';
	@override String get additions => 'добавления';
	@override String get deletions => 'удаления';
}

// Path: character.cardEditApproval.modalityVerb
class _TranslationsCharacterCardEditApprovalModalityVerbRu extends _TranslationsCharacterCardEditApprovalModalityVerbEn {
	_TranslationsCharacterCardEditApprovalModalityVerbRu._(_TranslationsRu root) : this._root = root, super._(root);

	@override final _TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get edit => 'Изменить';
	@override String get addition => 'Добавить в';
	@override String get deletion => 'Удалить из';
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
	@override late final _TranslationsMemoryZhHans memory = _TranslationsMemoryZhHans._(_root);
	@override late final _TranslationsNodesZhHans nodes = _TranslationsNodesZhHans._(_root);
	@override late final _TranslationsSearchZhHans search = _TranslationsSearchZhHans._(_root);
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

// Path: search
class _TranslationsSearchZhHans extends _TranslationsSearchEn {
	_TranslationsSearchZhHans._(_TranslationsZhHans root) : this._root = root, super._(root);

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
	@override late final _TranslationsMemoryZhHant memory = _TranslationsMemoryZhHant._(_root);
	@override late final _TranslationsNodesZhHant nodes = _TranslationsNodesZhHant._(_root);
	@override late final _TranslationsSearchZhHant search = _TranslationsSearchZhHant._(_root);
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

// Path: search
class _TranslationsSearchZhHant extends _TranslationsSearchEn {
	_TranslationsSearchZhHant._(_TranslationsZhHant root) : this._root = root, super._(root);

	@override final _TranslationsZhHant _root; // ignore: unused_field

	// Translations
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on Translations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.appBootstrapper.failedToInitializeMessage': return ({required Object error}) => 'Failed to initialize app:\n\n${error}';
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
			case 'common.logs.errorPrefix': return ({required Object error}) => 'Error: ${error}';
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
			case 'common.timeAgo.years': return ({required Object n}) => '${n}y ago';
			case 'common.timeAgo.months': return ({required Object n}) => '${n}mo ago';
			case 'common.timeAgo.days': return ({required Object n}) => '${n}d ago';
			case 'common.timeAgo.hours': return ({required Object n}) => '${n}h ago';
			case 'common.timeAgo.minutes': return ({required Object n}) => '${n}m ago';
			case 'common.timeAgo.justNow': return 'Just now';
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
			case 'editor.editorNodes.deleteNodeTitle': return 'Delete node';
			case 'editor.editorNodes.deleteNodeMessage': return 'Remove this authored node from the card?';
			case 'editor.editorNodes.engineSeedTitle': return 'Engine seed';
			case 'editor.editorNodes.visualEditorTooltip': return 'Visual editor';
			case 'editor.editorNodes.editJsonTooltip': return 'Edit JSON';
			case 'editor.editorNodes.initialGoalLabel': return 'Initial goal';
			case 'editor.editorNodes.initialSceneLabel': return 'Initial scene';
			case 'editor.editorNodes.locationLabel': return 'Location';
			case 'editor.editorNodes.timeOfDayLabel': return 'Time of day';
			case 'editor.editorNodes.presentEntitiesLabel': return 'Present (comma-separated)';
			case 'editor.editorNodes.sensoryHooksLabel': return 'Sensory hooks (comma-separated)';
			case 'editor.editorNodes.addNodeButton': return 'Add Node';
			case 'editor.editorNodes.noAuthoredNodesYet': return 'No authored nodes yet.';
			case 'editor.editorNodes.loadErrorMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: 'This card\'s nodes block has ${n} problem; editing here will overwrite the broken parts on save.',
				other: 'This card\'s nodes block has ${n} problems; editing here will overwrite the broken parts on save.',
			);
			case 'editor.editorNodes.moreErrorsSuffix': return ({required Object n}) => '… ${n} more';
			case 'editor.editorNodes.emotionBaselineLabel': return 'Emotion baseline';
			case 'editor.editorNodes.emotionChipLabel': return 'Emotion';
			case 'editor.nodeListTile.spawnsLabel': return ({required Object count}) => 'spawns: ${count}';
			case 'editor.nodesRawEditorPage.topLevelMustBeObject': return 'Top level must be a JSON object';
			case 'editor.nodesRawEditorPage.editNodesJsonTitle': return 'Edit nodes JSON';
			case 'editor.nodesRawEditorPage.fixProblemsMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: 'Fix ${n} problem to save.',
				other: 'Fix ${n} problems to save.',
			);
			case 'editor.nodesCanvasView.spawnedByPort': return 'spawned by';
			case 'editor.nodesCanvasView.spawnsPort': return 'spawns';
			case 'editor.nodesCanvasView.editNodeLabel': return 'Edit node';
			case 'editor.nodesCanvasView.addNodeTooltip': return 'Add node';
			case 'editor.nodeEditorForm.nameLabel': return 'Name';
			case 'editor.nodeEditorForm.narrativePayloadLabel': return 'Narrative payload';
			case 'editor.nodeEditorForm.removeSpawnLinkTitle': return 'Remove spawn link';
			case 'editor.nodeEditorForm.removeSpawnLinkMessage': return ({required Object nodeId}) => 'Stop this node from spawning "${nodeId}"? The node itself stays on the card.';
			case 'editor.nodeEditorForm.removeButton': return 'Remove';
			case 'editor.nodeEditorForm.typeLabel': return 'Type';
			case 'editor.nodeEditorForm.scopeLabel': return 'Scope';
			case 'editor.nodeEditorForm.originLabel': return 'Origin';
			case 'editor.nodeEditorForm.triggerProbLabel': return 'Trigger prob';
			case 'editor.nodeEditorForm.delayHelper': return 'Turns to wait before becoming eligible. -1 acts as 0.';
			case 'editor.nodeEditorForm.cooldownHelper': return 'Turns locked out after firing. -1 means no cooldown.';
			case 'editor.nodeEditorForm.stickyHelper': return 'Turns the narrative payload keeps appearing as "Lingering" after firing. -1 means permanent.';
			case 'editor.nodeEditorForm.aliveHelper': return 'Turns the node stays in the pool before removal. -1 means forever.';
			case 'editor.nodeEditorForm.setToNeverButton': return 'Set to never';
			case 'editor.nodeEditorForm.effectsSectionLabel': return 'Effects';
			case 'editor.nodeEditorForm.emotionDeltasTitle': return 'Emotion deltas';
			case 'editor.nodeEditorForm.physicalDeltasTitle': return 'Physical deltas';
			case 'editor.nodeEditorForm.relationshipDeltasTitle': return 'Relationship deltas';
			case 'editor.nodeEditorForm.addDeltaChip': return 'Add delta';
			case 'editor.nodeEditorForm.knowledgeWritesTitle': return 'Knowledge writes';
			case 'editor.nodeEditorForm.addFactChip': return 'Add fact';
			case 'editor.nodeEditorForm.topicLabel': return 'topic';
			case 'editor.nodeEditorForm.confidenceLabel': return 'confidence';
			case 'editor.nodeEditorForm.flagSetTitle': return 'Flag set';
			case 'editor.nodeEditorForm.addFlagChip': return 'Add flag';
			case 'editor.nodeEditorForm.keyLabel': return 'key';
			case 'editor.nodeEditorForm.sceneAndFlowTitle': return 'Scene & flow';
			case 'editor.nodeEditorForm.goalChangeLabel': return 'goalChange (clears the current goal when empty)';
			case 'editor.nodeEditorForm.phaseChangeLabel': return 'phaseChange';
			case 'editor.nodeEditorForm.noneOption': return '(none)';
			case 'editor.nodeEditorForm.sceneTransitionLabel': return 'sceneTransition';
			case 'editor.nodeEditorForm.sceneTransitionSubtitle': return 'When true, the engine marks the firing as a scene shift.';
			case 'editor.nodeEditorForm.spawnsSectionLabel': return 'Spawns';
			case 'editor.nodeEditorForm.addNewChip': return 'Add new';
			case 'editor.nodeEditorForm.linkExistingChip': return 'Link existing';
			case 'editor.nodeEditorForm.unlinkTooltip': return 'Unlink';
			case 'editor.nodeEditorForm.predicateLabel': return 'Predicate';
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
			case 'grid.tagWrap.tagCountLabel': return ({required Object tag, required Object count}) => '${tag} (${count})';
			case 'group.groupGridController.renameGroupTitle': return 'Rename Group';
			case 'group.groupGridController.groupNameHint': return 'Group name';
			case 'group.groupGridController.deleteGroupTitle': return 'Delete Group';
			case 'group.groupGridController.deleteGroupMessage': return ({required Object name}) => 'Are you sure you want to delete "${name}"? This cannot be undone.';
			case 'group.groupChatPage.defaultGroupName': return 'Group Chat';
			case 'group.groupChatPage.failedToLoadMessage': return ({required Object error}) => 'Failed to load group chat:\n${error}';
			case 'group.groupChatPage.nextTurnTooltip': return 'Next turn';
			case 'group.groupChatPage.stopAutoChatTooltip': return 'Stop auto-chat';
			case 'group.groupChatPage.startAutoChatTooltip': return 'Start auto-chat';
			case 'group.groupChatPage.stopGenerationTooltip': return 'Stop generation';
			case 'group.groupChatPage.noCharactersYetMessage': return 'This group has no characters yet.';
			case 'group.groupChatPage.addCharacterButton': return 'Add a character';
			case 'group.groupChatPage.pickCharacterMessage': return 'Pick a character from the list on the left.';
			case 'group.groupGridPage.failedToLoadMessage': return ({required Object error}) => 'Failed to load groups:\n${error}';
			case 'group.groupGridPage.unknownErrorFallback': return 'unknown error';
			case 'group.groupGridPage.noGroupsYetMessage': return 'No groups yet — tap + to create one.';
			case 'group.tileAutoChatDelay.title': return 'Auto-chat delay';
			case 'group.tileAutoChatDelay.secondsAbbrev': return ({required Object seconds}) => '${seconds}s';
			case 'group.tileActivationStrategy.title': return 'Speaker selection';
			case 'group.tileActivationStrategy.naturalOption': return 'Natural';
			case 'group.tileActivationStrategy.roundRobinOption': return 'Round-robin';
			case 'group.tileActivationStrategy.randomOption': return 'Random';
			case 'group.tileActivationStrategy.changeSelectionTooltip': return 'Change speaker selection';
			case 'group.groupChatPageEndDrawer.allowWebFetchTitle': return 'Allow Web Fetch';
			case 'group.groupChatPageEndDrawer.allowWebFetchSubtitle': return 'Read public web pages when relevant';
			case 'group.groupChatPageEndDrawer.reviewUrlTitle': return 'Review URL Before Fetching';
			case 'group.groupChatPageEndDrawer.reviewUrlSubtitle': return 'Confirm each fetch';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesTitle': return 'Suggest NPC Names';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesSubtitle': return 'Pick names from the curated database';
			case 'group.groupChatPageEndDrawer.unrestrictedImagesTitle': return 'Unrestricted Images';
			case 'group.groupChatPageEndDrawer.allowNsfwImagePromptsSubtitle': return 'Allow NSFW image prompts';
			case 'group.groupChatPageEndDrawer.characterCanSendSelfiesTitle': return 'Character Can Send Selfies';
			case 'group.groupChatPageEndDrawer.attachSelfieWhenNaturalSubtitle': return 'Attach a selfie when natural';
			case 'group.groupChatPageEndDrawer.reviewImagePromptTitle': return 'Review Image Prompt';
			case 'group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle': return 'Edit before generating';
			case 'group.groupChatPageEndDrawer.reviewToolImagePromptsTitle': return 'Review Tool Image Prompts';
			case 'group.groupChatPageEndDrawer.editToolTriggeredPromptsSubtitle': return 'Edit tool-triggered prompts';
			case 'group.groupChatPageEndDrawer.allowSelfieCaptionsTitle': return 'Allow Selfie Captions';
			case 'group.groupChatPageEndDrawer.captionRenderedOnImageSubtitle': return 'Caption rendered on the image';
			case 'group.groupChatPageEndDrawer.groupOverridesTitle': return 'Group overrides';
			case 'group.groupChatPageEndDrawer.groupOverridesSubtitle': return 'Shared scenario, main prompt, example dialogue';
			case 'group.groupChatPageEndDrawer.chatSessionSubtitle': return 'Chat session';
			case 'group.groupChatPageEndDrawer.allChatsLabel': return 'All Chats';
			case 'group.groupChatPageEndDrawer.showImageLabel': return 'Show Image';
			case 'group.groupChatPageEndDrawer.groupSectionHeader': return 'Group';
			case 'group.groupChatPageEndDrawer.chatSectionHeader': return 'Chat';
			case 'group.groupChatPageEndDrawer.chatThemeSectionHeader': return 'Chat Theme';
			case 'group.groupChatPageEndDrawer.unrestrictedVideosTitle': return 'Unrestricted Videos';
			case 'group.groupChatPageEndDrawer.allowNsfwVideoPromptsSubtitle': return 'Allow NSFW video prompts';
			case 'group.groupChatPageEndDrawer.characterCanSendVideosTitle': return 'Character Can Send Videos';
			case 'group.groupChatPageEndDrawer.attachShortVideoWhenNaturalSubtitle': return 'Attach a short video when natural';
			case 'group.groupChatPageEndDrawer.reviewVideoPromptTitle': return 'Review Video Prompt';
			case 'group.groupCharacterPicker.addButton': return 'Add';
			case 'group.groupCharacterPicker.addWithCountButton': return ({required Object count}) => 'Add ${count}';
			case 'group.groupCharacterPicker.favoritesTooltip': return 'Favorites';
			case 'group.groupCharacterPicker.noMatchMessage': return ({required Object query}) => 'No characters match "${query}"';
			case 'group.groupCharacterPicker.noFavoritesMessage': return 'No favorited characters available';
			case 'group.groupCharacterPicker.allAddedMessage': return 'All characters already added';
			case 'group.groupCharacterTile.speakTooltip': return 'Make this character speak';
			case 'group.groupCharacterTile.removeFromChatTitle': return 'Remove from chat';
			case 'group.dialogCreateGroup.title': return 'New Group';
			case 'group.dialogCreateGroup.nameLabel': return 'Name';
			case 'group.dialogCreateGroup.nameHint': return 'e.g. Bob & Alice';
			case 'group.dialogGroupOverrides.explanationMessage': return 'Unique to this chat. All group members use these values instead of what their character cards define. Leave empty to fall back to the card value.';
			case 'group.dialogGroupOverrides.scenarioHint': return 'Shared setting for the group (e.g. "In a cafe in Paris")';
			case 'group.dialogGroupOverrides.mainPromptLabel': return 'Main Prompt';
			case 'group.dialogGroupOverrides.mainPromptHint': return 'System prompt applied during every turn';
			case 'group.dialogGroupOverrides.exampleDialogueLabel': return 'Example Dialogue';
			case 'group.dialogGroupOverrides.exampleDialogueHint': return 'Shared example messages for tone / formatting';
			case 'group.groupCharacterPanel.addCharacterButton': return 'Add Character';
			case 'group.groupCharacterPanel.noCharactersYetMessage': return 'No characters yet.\nTap + to add one.';
			case 'group.dialogSelectGroup.deleteGroupTitle': return 'Delete group?';
			case 'group.dialogSelectGroup.deleteGroupMessage': return ({required Object name}) => '"${name}" and all of its chat sessions will be permanently removed.';
			case 'group.dialogSelectGroup.title': return 'Groups';
			case 'group.dialogSelectGroup.noGroupsYetMessage': return 'No groups yet. Tap "New group" to create one.';
			case 'group.dialogSelectGroup.memberCountLabel': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: '${n} member',
				other: '${n} members',
			);
			case 'group.groupGridItem.overflowCountBadge': return ({required Object count}) => '+${count}';
			case 'group.groupGridItem.noMembersYetMessage': return 'No members yet';
			case 'group.groupFileService.defaultGroupName': return 'Group';
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
			case 'settings.loadingStatus.restoringProviders': return 'Restoring providers…';
			case 'settings.loadingStatus.fetchingModelsProgress': return ({required Object completed, required Object total}) => 'Fetching models (${completed}/${total})…';
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
			case 'workspace.workspaceEndDrawerImage.imageStyleTitle': return 'Image Style';
			case 'workspace.workspaceEndDrawerImage.noneValue': return 'None';
			case 'workspace.workspaceEndDrawerVideo.videoStyleTitle': return 'Video Style';
			case 'workspace.workspaceEndDrawerDisplay.sectionHeader': return 'Display';
			case 'workspace.workspaceEndDrawerDisplay.showCharacterImageTitle': return 'Show Character Image';
			case 'workspace.workspaceEndDrawerDisplay.wideScreenOnlySubtitle': return 'Wide-screen editor only';
			case 'workspace.workspaceEndDrawerAi.sectionHeader': return 'AI';
			case 'workspace.workspaceEndDrawerEditing.sectionHeader': return 'Editing';
			case 'workspace.workspaceEndDrawerExport.sectionHeader': return 'Export';
			case 'workspace.workspaceEndDrawerExport.exportPngTitle': return 'Export as PNG (V2/V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV3Title': return 'Export as JSON (V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV2Title': return 'Export as JSON (V2)';
			case 'workspace.workspaceEndDrawerChatTheme.resetImagesTitle': return 'Reset Images';
			case 'workspace.workspaceEndDrawerChat.assistantCardEditsSectionHeader': return 'Assistant Card Edits';
			case 'workspace.workspaceEndDrawer.favoriteLabel': return 'Favorite';
			case 'workspace.workspaceEndDrawer.nodesEngineTitle': return 'NODES Engine';
			case 'workspace.workspaceEndDrawer.debugSnapshotSubtitle': return 'Debug snapshot';
			case 'workspace.workspaceEndDrawer.characterSubtitle': return 'Character';
			case 'workspace.stylePresetsDialog.noStyleSelectedMessage': return 'No style selected';
			case 'workspace.workspacePage.rebuildingChatIndexMessage': return 'Rebuilding chat index...';
			case 'workspace.workspacePage.selectChatToStartMessagingMessage': return 'Select a chat to start messaging';
			case 'workspace.workspacePage.failedToLoadAssistantMessage': return 'Failed to load assistant.';
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
			case 'app.appBootstrapper.failedToInitializeMessage': return ({required Object error}) => 'Не удалось запустить приложение:\n\n${error}';
			case 'character.promptPrefixDialog.styleKeywordsLabel': return 'Ключевые слова стиля';
			case 'character.promptPrefixDialog.imageTitle': return 'Стиль изображения';
			case 'character.promptPrefixDialog.imageDescription': return 'Добавляется в начало каждого промпта генерации изображения для этого персонажа (например, «стиль аниме, яркие цвета»).';
			case 'character.promptPrefixDialog.imageHint': return 'стиль аниме, яркие цвета';
			case 'character.promptPrefixDialog.videoTitle': return 'Стиль видео';
			case 'character.promptPrefixDialog.videoDescription': return 'Добавляется в начало каждого промпта генерации видео для этого персонажа (например, «кинематографично, малая глубина резкости, зерно плёнки 24 к/с»). Видеомодели реагируют на лексику движения и камеры; пишите кратко.';
			case 'character.promptPrefixDialog.videoHint': return 'кинематографично, малая глубина резкости';
			case 'character.cardEditApproval.denyAll': return 'Отклонить все';
			case 'character.cardEditApproval.approveAll': return 'Одобрить все';
			case 'character.cardEditApproval.confirm': return 'Подтвердить';
			case 'character.cardEditApproval.dialogTitle': return 'Ассистент предложил изменения';
			case 'character.cardEditApproval.dontAskAgainFor': return ({required Object modality}) => 'Не спрашивать снова для «${modality}»';
			case 'character.cardEditApproval.modalityLabel.edits': return 'правки';
			case 'character.cardEditApproval.modalityLabel.additions': return 'добавления';
			case 'character.cardEditApproval.modalityLabel.deletions': return 'удаления';
			case 'character.cardEditApproval.modalityVerb.edit': return 'Изменить';
			case 'character.cardEditApproval.modalityVerb.addition': return 'Добавить в';
			case 'character.cardEditApproval.modalityVerb.deletion': return 'Удалить из';
			case 'character.cardEditApproval.tapToDeny': return 'Нажмите, чтобы отклонить';
			case 'character.cardEditApproval.tapToApprove': return 'Нажмите, чтобы одобрить';
			case 'character.cardEditApproval.reasonLabel': return 'Причина (необязательно, отправляется обратно ассистенту)';
			case 'character.cardEditApproval.newEntryTitle': return 'Новая запись';
			case 'character.cardEditApproval.removingTitle': return 'Удаление';
			case 'character.cardEditApproval.beforeTitle': return 'До';
			case 'character.cardEditApproval.afterTitle': return 'После';
			case 'character.requireApprovalTile.edits': return 'Требовать одобрения: правки';
			case 'character.requireApprovalTile.additions': return 'Требовать одобрения: добавления';
			case 'character.requireApprovalTile.deletions': return 'Требовать одобрения: удаления';
			case 'character.loadingStatus.initial': return 'Загрузка...';
			case 'character.loadingStatus.copyingAssistant': return 'Копирование ассистента...';
			case 'character.loadingStatus.scanningForCharacters': return 'Поиск персонажей...';
			case 'character.loadingStatus.scanningForCharactersProgress': return ({required Object current, required Object total}) => 'Поиск персонажей...\n${current} / ${total}';
			case 'character.loadingStatus.loadingCharactersProgress': return ({required Object current, required Object total}) => 'Загрузка персонажей...\n${current} / ${total}';
			case 'character.savePathValidation.noLibraryFolder': return 'Папка библиотеки не настроена.';
			case 'character.savePathValidation.mustBeInsideLibrary': return 'Персонажей нужно сохранять внутри папки библиотеки.';
			case 'character.characterFilesTypeGroupLabel': return 'Файлы персонажей';
			case 'character.createController.pngImagesTypeGroupLabel': return 'Изображения PNG';
			case 'character.createController.invalidLocationTitle': return 'Недопустимое расположение';
			case 'character.createController.creationFailedTitle': return 'Не удалось создать';
			case 'character.createController.creationFailedMessage': return 'Не удалось создать персонажа. Подробности в логах.';
			case 'character.importController.failedToImport': return ({required Object fileName}) => 'Не удалось импортировать ${fileName}.';
			case 'character.importController.importedCount': return ({required Object count}) => 'Импортировано персонажей: ${count}';
			case 'character.aiActionController.aiActionFailed': return 'Действие ИИ не выполнено. Подробности в логах.';
			case 'character.aiActionController.processingProgress': return ({required Object name, required Object current, required Object total, required Object eta}) => 'Обработка ${name} (${current}/${total})...${eta}';
			case 'character.aiActionController.etaHoursMinutes': return ({required Object hours, required Object minutes}) => ' Осталось: ${hours} ч ${minutes} мин';
			case 'character.aiActionController.etaMinutesSeconds': return ({required Object minutes, required Object seconds}) => ' Осталось: ${minutes} мин ${seconds} с';
			case 'character.aiActionController.etaSeconds': return ({required Object seconds}) => ' Осталось: ${seconds} с';
			case 'character.aiActionController.processingField': return ({required Object fieldName}) => 'Обработка «${fieldName}»...';
			case 'chat.tileAiProvider.modelLabel': return 'Модель';
			case 'chat.tileAiProvider.invalidLabel': return 'Недопустимо';
			case 'chat.tileAiProvider.chooseModelTitle': return 'Выберите модель';
			case 'chat.presetTile.tapToChoose': return 'Нажмите, чтобы выбрать';
			case 'chat.tileImagePreset.titleLabel': return 'Модель изображений';
			case 'chat.tileImagePreset.chooseModelTitle': return 'Выберите модель изображений';
			case 'chat.tileVideoPreset.titleLabel': return 'Модель видео';
			case 'chat.tileVideoPreset.chooseModelTitle': return 'Выберите модель видео';
			case 'chat.tileTtsPreset.titleLabel': return 'Модель речи';
			case 'chat.tileTtsPreset.chooseModelTitle': return 'Выберите модель речи';
			case 'chat.tileImageAspectRatio.label': return 'Соотношение сторон изображения';
			case 'chat.tileVideoAspectRatio.label': return 'Соотношение сторон';
			case 'chat.tileVideoResolution.label': return 'Разрешение';
			case 'chat.tileVideoDuration.label': return 'Длительность';
			case 'chat.tileTtsVoice.label': return 'Голос';
			case 'chat.tileTtsLanguage.label': return 'Язык';
			case 'chat.tileNsfw.label': return 'NSFW / Без ограничений';
			case 'chat.tileScenario.label': return 'Сценарий';
			case 'chat.tileMaxResponseLength.titleWithBucket': return ({required Object bucket}) => 'Длина ответа — ${bucket}';
			case 'chat.tileMaxResponseLength.sliderLabel': return ({required Object bucket, required Object tokens}) => '${bucket} (${tokens} токенов)';
			case 'chat.tileMaxResponseLength.bucketVeryShort': return 'Очень короткий';
			case 'chat.tileMaxResponseLength.bucketShort': return 'Короткий';
			case 'chat.tileMaxResponseLength.bucketMedium': return 'Средний';
			case 'chat.tileMaxResponseLength.bucketLong': return 'Длинный';
			case 'chat.tileMaxResponseLength.bucketVeryLong': return 'Очень длинный';
			case 'chat.tileTrailingParagraph.label': return 'Обрезать хвост текста';
			case 'chat.tileReasoningEffort.titleWithEffort': return ({required Object effort}) => 'Рассуждения — ${effort}';
			case 'chat.tileReasoningEffort.titleOff': return 'Рассуждения выключены';
			case 'chat.tileReasoningEffort.extraTokensCaption': return 'Использует дополнительные токены сверх максимальной длины ответа.';
			case 'chat.tileChatTheme.label': return 'Тема';
			case 'chat.tileRecalledMemory.label': return 'Показывать вызванную память';
			case 'chat.characterSwitcher.favoritesTooltip': return 'Избранное';
			case 'chat.characterSwitcher.recentChatsTooltip': return 'Недавние чаты';
			case 'chat.characterSwitcher.originalBadge': return 'ОРИГИНАЛ';
			case 'chat.characterSwitcher.variantBadge': return 'ВАРИАНТ';
			case 'chat.characterSwitcher.lastActive': return ({required Object timeAgo}) => 'Последняя активность: ${timeAgo}';
			case 'chat.characterSwitcher.never': return 'Никогда';
			case 'chat.freeImagePromptDialog.title': return 'Сгенерировать изображение';
			case 'chat.freeImagePromptDialog.description': return 'Опишите, что вы хотите увидеть. Достаточно короткой фразы — модель развернёт её в полный список тегов.';
			case 'chat.freeImagePromptDialog.subjectLabel': return 'Тема';
			case 'chat.freeImagePromptDialog.subjectHint': return 'киберпанк-переулок, неоновый дождь';
			case 'chat.freeImagePromptDialog.generateButton': return 'Сгенерировать';
			case 'chat.freeVideoPromptDialog.title': return 'Сгенерировать видео';
			case 'chat.freeVideoPromptDialog.description': return 'Опишите короткий момент движения — что движется, как, где. Системная модель развернёт это в кинематографичный промпт T2V.';
			case 'chat.freeVideoPromptDialog.subjectLabel': return 'Тема';
			case 'chat.freeVideoPromptDialog.subjectHint': return 'она идёт сквозь неоновый дождь, замедленная съёмка';
			case 'chat.freeVideoPromptDialog.generateButton': return 'Сгенерировать';
			case 'chat.imagePromptReviewDialog.title': return 'Проверить промпт изображения';
			case 'chat.imagePromptReviewDialog.description': return 'Отредактируйте промпт ниже перед генерацией или нажмите «Сгенерировать», чтобы использовать как есть.';
			case 'chat.imagePromptReviewDialog.fieldLabel': return 'Промпт изображения';
			case 'chat.imagePromptReviewDialog.generateButton': return 'Сгенерировать';
			case 'chat.videoPromptReviewDialog.title': return 'Проверить промпт видео';
			case 'chat.videoPromptReviewDialog.description': return 'Отредактируйте промпт ниже перед отправкой или нажмите «Сгенерировать», чтобы использовать как есть.';
			case 'chat.videoPromptReviewDialog.fieldLabel': return 'Промпт видео';
			case 'chat.videoPromptReviewDialog.generateButton': return 'Сгенерировать';
			case 'chat.urlFetchReviewDialog.title': return 'Разрешить веб-запрос?';
			case 'chat.urlFetchReviewDialog.description': return 'Персонаж хочет прочитать содержимое этого URL.';
			case 'chat.urlFetchReviewDialog.purposeLabel': return 'Цель:';
			case 'chat.urlFetchReviewDialog.denyButton': return 'Отклонить';
			case 'chat.urlFetchReviewDialog.allowButton': return 'Разрешить';
			case 'chat.messageActionsRow.tokenCountAbbrev': return ({required Object count}) => '${count} т';
			case 'chat.messageActionsRow.generationTimeAbbrev': return ({required Object seconds}) => '${seconds} с';
			case 'chat.messageActionsRow.viewGenerationPromptTooltip': return 'Посмотреть промпт генерации';
			case 'chat.messageActionsRow.messageActionsTooltip': return 'Действия с сообщением';
			case 'chat.messageActionsRow.editAction': return 'Изменить';
			case 'chat.messageActionsRow.copyAction': return 'Копировать';
			case 'chat.messageActionsRow.shareImageAction': return 'Поделиться изображением';
			case 'chat.messageActionsRow.setAsBackgroundAction': return 'Сделать фоном';
			case 'chat.messageActionsRow.setAsCharacterImageAction': return 'Сделать изображением персонажа';
			case 'chat.messageActionsRow.deleteAction': return 'Удалить';
			case 'chat.messageActionsRow.copiedToClipboard': return 'Сообщение скопировано в буфер обмена';
			case 'chat.ttsPlayButton.stopTooltip': return 'Стоп';
			case 'chat.ttsPlayButton.readAloudTooltip': return 'Прочитать вслух';
			case 'chat.ttsPlayButton.ttsFailed': return 'Ошибка TTS.';
			case 'chat.messageSwipeFlipper.previousVersionTooltip': return 'Предыдущая версия';
			case 'chat.messageSwipeFlipper.swipeCounter': return ({required Object current, required Object total}) => '${current} / ${total}';
			case 'chat.messageSwipeFlipper.regenerateTooltip': return 'Перегенерировать';
			case 'chat.messageSwipeFlipper.nextVersionTooltip': return 'Следующая версия';
			case 'chat.videoPlayerInline.webUnsupported': return 'Воспроизведение видео не поддерживается в вебе.';
			case 'chat.videoPlayerInline.couldNotLoad': return 'Не удалось загрузить видео.';
			case 'chat.newChatLabel': return 'Новый чат';
			case 'chat.chatListItem.messageCount': return ({required Object count}) => 'Сообщений: ${count}';
			case 'chat.chatListItem.renameAction': return 'Переименовать';
			case 'chat.chatListItem.deleteChatAction': return 'Удалить чат';
			case 'chat.chatHistoryController.renameChatTitle': return 'Переименовать чат';
			case 'chat.chatHistoryController.chatNameHint': return 'Название чата';
			case 'chat.chatHistoryController.renameButton': return 'Переименовать';
			case 'chat.chatHistoryController.deleteChatTitle': return 'Удалить чат';
			case 'chat.chatHistoryController.deleteChatMessage': return 'Вы уверены, что хотите удалить историю этого чата? Это действие нельзя отменить.';
			case 'chat.chatPageController.clearAssistantHistoryMessage': return 'Очистить историю чата с ассистентом?';
			case 'chat.chatPageController.clearButton': return 'Очистить';
			case 'chat.chatPageController.deleteOrKeepMessage': return 'Удалить текущий чат или сохранить его в истории?';
			case 'chat.chatPageController.deleteCurrentButton': return 'Удалить текущий';
			case 'chat.chatPageController.keepCurrentButton': return 'Оставить текущий';
			case 'chat.imageGenerationMixin.enterPromptMessage': return 'Введите промпт для генерации изображения.';
			case 'chat.imageGenerationMixin.noCharacterMessage': return 'Нет персонажа для генерации изображения.';
			case 'chat.imageGenerationMixin.notConfiguredMessage': return 'Генерация изображений не настроена.';
			case 'chat.imageGenerationMixin.noSystemModelMessage': return 'Системная модель не настроена. Задайте её в Настройки → ИИ.';
			case 'chat.videoGenerationMixin.enterPromptMessage': return 'Введите промпт для генерации видео.';
			case 'chat.videoGenerationMixin.noCharacterMessage': return 'Нет персонажа для генерации видео.';
			case 'chat.videoGenerationMixin.notConfiguredMessage': return 'Генерация видео не настроена.';
			case 'chat.bubbleWaitingFor.thinking': return 'Размышляет…';
			case 'chat.bubbleWaitingFor.preparingImagePrompt': return 'Подготовка промпта изображения…';
			case 'chat.bubbleWaitingFor.preparingVideoPrompt': return 'Подготовка промпта видео…';
			case 'chat.bubbleWaitingFor.generatingImage': return 'Генерация изображения…';
			case 'chat.bubbleWaitingFor.generatingVideo': return 'Генерация видео…';
			case 'chat.appBarChat.hideEditorPanelTooltip': return 'Скрыть панель редактора';
			case 'chat.appBarChat.showEditorSideBySideTooltip': return 'Показать редактор рядом';
			case 'chat.allChatsDrawerList.rebuildingIndex': return 'Перестроение индекса...';
			case 'chat.allChatsDrawerList.noChatsFound': return 'Чаты не найдены.';
			case 'chat.chatInputMediaMenu.generateMediaTooltip': return 'Сгенерировать медиа';
			case 'chat.chatInputMediaMenu.generateImageLabel': return 'Сгенерировать изображение';
			case 'chat.chatInputMediaMenu.generateVideoLabel': return 'Сгенерировать видео';
			case 'chat.chatView.deleteMessageTitle': return 'Удалить сообщение';
			case 'chat.chatView.deleteMessageConfirmation': return 'Вы уверены, что хотите удалить это сообщение?';
			case 'chat.chatView.typeMessageHint': return 'Введите сообщение...';
			case 'chat.chatView.moreActionsTooltip': return 'Ещё действия';
			case 'chat.chatView.continueAction': return 'Продолжить';
			case 'chat.chatView.impersonateAction': return 'Отыграть за персонажа';
			case 'chat.chatView.generateReplyAction': return 'Сгенерировать ответ';
			case 'chat.chatView.improveMessageAction': return 'Улучшить сообщение';
			case 'chat.chatMessageBubble.imagesTypeGroupLabel': return 'Изображения';
			case 'chat.chatMessageBubble.assistantFallbackName': return 'Ассистент';
			case 'chat.chatMessageBubble.reasoningLabel': return 'Рассуждения';
			case 'chat.chatMessageBubble.sendingToProvider': return 'Отправка провайдеру…';
			case 'chat.chatMessageBubble.pollingWithPercent': return ({required Object pct}) => 'Опрос… ${pct}%';
			case 'chat.chatMessageBubble.polling': return 'Опрос…';
			case 'chat.chatMessageBubble.downloading': return 'Загрузка…';
			case 'common.actions.delete': return 'Удалить';
			case 'common.actions.ok': return 'ОК';
			case 'common.actions.cancel': return 'Отмена';
			case 'common.actions.save': return 'Сохранить';
			case 'common.actions.tryAgain': return 'Повторить';
			case 'common.actions.close': return 'Закрыть';
			case 'common.aiAction.proofread': return 'Вычитать';
			case 'common.aiAction.compact': return 'Сжать текст';
			case 'common.aiAction.translate': return 'Перевести на английский';
			case 'common.aiAction.generatePreview': return 'Создать превью';
			case 'common.aiAction.autoTag': return 'Авто-теги';
			case 'common.aiActionsTooltip': return 'Действия ИИ';
			case 'common.promptSegmentKind.identity': return 'Идентичность';
			case 'common.promptSegmentKind.systemPrompt': return 'Системный промпт';
			case 'common.promptSegmentKind.nsfwMode': return 'Режим NSFW';
			case 'common.promptSegmentKind.scenarioMode': return 'Режим сценария';
			case 'common.promptSegmentKind.description': return 'Описание';
			case 'common.promptSegmentKind.personality': return 'Характер';
			case 'common.promptSegmentKind.scenario': return 'Сценарий';
			case 'common.promptSegmentKind.userPersona': return 'Ваша персона';
			case 'common.promptSegmentKind.memory': return 'Память';
			case 'common.promptSegmentKind.situation': return 'Ситуация';
			case 'common.promptSegmentKind.cardData': return 'Данные карточки';
			case 'common.promptSegmentKind.tools': return 'Инструменты';
			case 'common.promptSegmentKind.postHistory': return 'После истории';
			case 'common.promptSegmentKind.depthPrompt': return 'Глубинный промпт';
			case 'common.promptSegmentKind.worldInfo': return 'Информация о мире';
			case 'common.promptSegmentKind.injected': return 'Внедрено';
			case 'common.promptSegmentKind.exampleDialogue': return 'Пример диалога';
			case 'common.promptSegmentKind.history': return 'История сообщений';
			case 'common.promptSegmentKind.currentMessage': return 'Текущее сообщение';
			case 'common.promptSegmentKind.reservedReply': return 'Зарезервировано для ответа';
			case 'common.promptBreakdown.free': return 'Свободно';
			case 'common.logs.title': return 'Логи';
			case 'common.logs.filterTooltip': return 'Фильтр логов';
			case 'common.logs.clearTooltip': return 'Очистить логи';
			case 'common.logs.exportTooltip': return 'Экспорт логов';
			case 'common.logs.searchHint': return 'Поиск в логах...';
			case 'common.logs.noLogsFound': return 'Логи не найдены.';
			case 'common.logs.noLogsToExport': return 'Нет логов для экспорта';
			case 'common.logs.exportedSuccessfully': return 'Логи успешно экспортированы';
			case 'common.logs.exportFailed': return 'Не удалось экспортировать логи. Подробности в логах.';
			case 'common.logs.copiedToClipboard': return 'Скопировано в буфер обмена';
			case 'common.logs.copyLogButton': return 'Копировать лог';
			case 'common.logs.copiedEntryToClipboard': return 'Запись лога скопирована в буфер обмена';
			case 'common.logs.errorPrefix': return ({required Object error}) => 'Ошибка: ${error}';
			case 'common.importErrorsDialog.title': return 'Ошибки импорта';
			case 'common.importErrorsDialog.message': return 'Следующие файлы не удалось импортировать:';
			case 'common.updateDialog.title': return 'Доступна версия';
			case 'common.updateDialog.body': return ({required Object appName, required Object currentVersion, required Object latestVersion}) => 'Доступна более новая версия ${appName}.\n\nТекущая версия: ${currentVersion}\nПоследняя версия: ${latestVersion}';
			case 'common.updateDialog.releaseNotesLabel': return 'Что нового:';
			case 'common.updateDialog.viewReleasesButton': return 'Смотреть релизы';
			case 'common.importConflictsDialog.title': return 'Конфликты импорта';
			case 'common.importConflictsDialog.message': return ({required Object count}) => 'Следующие ${count} персонажей имеют конфликты имён файлов и будут переименованы автоматически:';
			case 'common.missingProviderBanner.message': return 'Подключите провайдер ИИ.';
			case 'common.missingProviderBanner.setUpNowButton': return 'Настроить сейчас';
			case 'common.modelSelectionDialog.searchHint': return 'Поиск моделей';
			case 'common.modelSelectionDialog.subscriptionOnlyToggle': return ({required Object included, required Object total}) => 'Показывать только модели по подписке (${included}/${total})';
			case 'common.showAdvanced.less': return 'Меньше';
			case 'common.showAdvanced.more': return 'Больше';
			case 'common.messageEditDialog.title': return 'Редактировать сообщение';
			case 'common.promptBreakdownDialog.title': return 'Разбор промпта';
			case 'common.promptBreakdownDialog.breakdownTab': return 'Разбор';
			case 'common.promptBreakdownDialog.contentTab': return 'Содержимое';
			case 'common.promptBreakdownDialog.promptTotalEstimated': return 'Итого по промпту (оценка)';
			case 'common.promptBreakdownDialog.promptTotalProvider': return 'Итого по промпту (провайдер)';
			case 'common.promptBreakdownDialog.contextWindowLabel': return 'Контекстное окно';
			case 'common.promptBreakdownDialog.categoryHeader': return 'КАТЕГОРИЯ';
			case 'common.promptBreakdownDialog.tokensHeader': return 'ТОКЕНЫ';
			case 'common.promptBreakdownDialog.usageHeader': return 'ИСПОЛЬЗОВАНИЕ';
			case 'common.promptBreakdownDialog.noContentToInspect': return 'Нет содержимого для этого ответа.';
			case 'common.promptBreakdownDialog.estimatedSuffix': return ' (оценка)';
			case 'common.promptBreakdownDialog.usedSummary': return ({required Object used, required Object total}) => 'Использовано ${used} / ${total}';
			case 'common.jsonPromptDialog.title': return 'Промпт генерации';
			case 'common.progressDialog.defaultMessage': return 'Отправка...';
			case 'common.progressDialog.finished': return 'Готово!';
			case 'common.diffPanel.tokenSuffix': return ({required Object count}) => ' (${count} токенов)';
			case 'common.selectionDialog.searchHint': return 'Поиск…';
			case 'common.zdrSwitch.title': return 'Требовать нулевое хранение данных (ZDR)';
			case 'common.zdrSwitch.subtitle': return 'Показывать только модели OR с ZDR-совместимыми эндпоинтами. Включите, если ваш аккаунт openrouter.ai ограничен провайдерами ZDR.';
			case 'common.textFieldCard.labelWithTokenCount': return ({required Object label, required Object count}) => '${label} — ${count} токенов';
			case 'common.textFieldCard.tokenCountAbbrev': return ({required Object count}) => '${count} т';
			case 'common.modelCapability.reasoning': return 'Рассуждения';
			case 'common.modelCapability.vision': return 'Зрение';
			case 'common.modelCapability.tools': return 'Инструменты';
			case 'common.modelCapability.json': return 'JSON';
			case 'common.modelCapability.files': return 'Файлы';
			case 'common.modelCapability.image': return 'Изображение';
			case 'common.modelCapability.video': return 'Видео';
			case 'common.modelCapability.speech': return 'Речь';
			case 'common.modelCapability.music': return 'Музыка';
			case 'common.modelUnavailableTooltip': return 'Эта модель больше недоступна у провайдера — выберите другую.';
			case 'common.characterImageSemanticLabel': return 'Изображение персонажа';
			case 'common.appConstants.maxImageFileSizeLabel': return '10 МБ';
			case 'common.appConstants.exportFailedMessage': return 'Не удалось экспортировать. Подробности в логах.';
			case 'common.timeAgo.years': return ({required Object n}) => '${n} г. назад';
			case 'common.timeAgo.months': return ({required Object n}) => '${n} мес. назад';
			case 'common.timeAgo.days': return ({required Object n}) => '${n} д. назад';
			case 'common.timeAgo.hours': return ({required Object n}) => '${n} ч. назад';
			case 'common.timeAgo.minutes': return ({required Object n}) => '${n} мин. назад';
			case 'common.timeAgo.justNow': return 'Только что';
			case 'editor.panelLabels.basic': return 'Основное';
			case 'editor.panelLabels.greetings': return 'Приветствия';
			case 'editor.panelLabels.prompts': return 'Промпты';
			case 'editor.panelLabels.lorebook': return 'Лорбук';
			case 'editor.panelLabels.group': return 'Группа';
			case 'editor.panelLabels.creator': return 'Автор';
			case 'editor.panelLabels.appData': return 'Данные приложения';
			case 'editor.panelLabels.nodes': return 'Узлы';
			case 'editor.appBarEditor.hideAssistantPanelTooltip': return 'Скрыть панель ассистента';
			case 'editor.appBarEditor.showChatAssistantTooltip': return 'Показать чат-ассистент рядом';
			case 'editor.codeFindPanel.noneResult': return 'нет';
			case 'editor.codeFindPanel.previousTooltip': return 'Предыдущее';
			case 'editor.codeFindPanel.nextTooltip': return 'Следующее';
			case 'editor.codeFindPanel.closeTooltip': return 'Закрыть';
			case 'editor.codeFindPanel.replaceTooltip': return 'Заменить';
			case 'editor.codeFindPanel.replaceAllTooltip': return 'Заменить всё';
			case 'editor.findReplaceDialog.confirmReplaceAllTitle': return 'Подтвердите «Заменить всё»';
			case 'editor.findReplaceDialog.confirmReplaceAllMessage': return 'Вы уверены, что хотите продолжить?\nЭто действие необратимо и затрагивает все поля.';
			case 'editor.findReplaceDialog.proceedButton': return 'Продолжить';
			case 'editor.findReplaceDialog.title': return 'Найти и заменить';
			case 'editor.findReplaceDialog.findLabel': return 'Найти';
			case 'editor.findReplaceDialog.replaceWithLabel': return 'Заменить на';
			case 'editor.findReplaceDialog.replaceAllButton': return 'Заменить всё';
			case 'editor.objectValueEditor.stringType': return 'строка';
			case 'editor.objectValueEditor.numberType': return 'число';
			case 'editor.objectValueEditor.boolType': return 'булево';
			case 'editor.editorBasic.nameLabel': return 'Имя';
			case 'editor.editorBasic.nicknameLabel': return 'Прозвище (CCv3)';
			case 'editor.editorBasic.descriptionLabel': return 'Описание';
			case 'editor.editorBasic.personalityLabel': return 'Характер';
			case 'editor.editorBasic.scenarioLabel': return 'Сценарий';
			case 'editor.editorBasic.messageExampleLabel': return 'Пример сообщения';
			case 'editor.editorCreatorMetadata.systemNameLabel': return 'Системное имя (CCv3)';
			case 'editor.editorCreatorMetadata.creatorLabel': return 'Автор';
			case 'editor.editorCreatorMetadata.versionLabel': return 'Версия';
			case 'editor.editorCreatorMetadata.creatorNotesLabel': return 'Заметки автора';
			case 'editor.editorCreatorMetadata.tagsLabel': return 'Теги (через запятую)';
			case 'editor.editorPrompts.systemPromptLabel': return 'Системный промпт';
			case 'editor.editorPrompts.postHistoryInstructionsLabel': return 'Инструкции после истории';
			case 'editor.editorPrompts.depthPromptLabel': return 'Глубинный промпт (заметки о персонаже)';
			case 'editor.editorPrompts.insertionDepthLabel': return 'Глубина вставки';
			case 'editor.editorPrompts.roleLabel': return 'Роль';
			case 'editor.editorAppData.variantNotesLabel': return 'Заметки варианта';
			case 'editor.editorAppData.descriptionPreviewLabel': return 'Превью описания';
			case 'editor.editorAlternateGreetings.deleteGreetingTitle': return 'Удалить приветствие';
			case 'editor.editorAlternateGreetings.deleteGreetingMessage': return 'Вы уверены, что хотите удалить это приветствие?';
			case 'editor.editorAlternateGreetings.addGreetingButton': return 'Добавить приветствие';
			case 'editor.editorAlternateGreetings.primaryGreetingLabel': return 'Основное приветствие (first_mes)';
			case 'editor.editorAlternateGreetings.alternateGreetingLabel': return ({required Object index}) => 'Альтернативное приветствие №${index}';
			case 'editor.editorAlternateGreetings.removeTooltip': return 'Удалить';
			case 'editor.editorGroupGreetings.greetingLabel': return ({required Object index}) => 'Приветствие ${index}';
			case 'editor.editorLorebook.newEntryDefaultComment': return 'Новая запись';
			case 'editor.editorLorebook.deleteEntryTitle': return 'Удалить запись';
			case 'editor.editorLorebook.deleteEntryMessage': return 'Вы уверены, что хотите удалить эту запись?';
			case 'editor.editorLorebook.addNewEntryButton': return 'Добавить запись';
			case 'editor.editorLorebook.noEntriesFound': return 'Записи лорбука не найдены.';
			case 'editor.lorebookEntryListTile.untitledEntry': return 'Запись без названия';
			case 'editor.lorebookEntryListTile.noKeywords': return 'Нет ключевых слов';
			case 'editor.lorebookEntryEditorPage.editEntryTitle': return 'Редактировать запись лорбука';
			case 'editor.lorebookEntryEditorPage.advancedFilter': return 'Расширенно';
			case 'editor.lorebookEntryEditorPage.primaryKeywordsLabel': return 'Основные ключевые слова';
			case 'editor.lorebookEntryEditorPage.logicLabel': return 'Логика';
			case 'editor.lorebookEntryEditorPage.logicAndAny': return 'И (любое)';
			case 'editor.lorebookEntryEditorPage.logicAndAll': return 'И (все)';
			case 'editor.lorebookEntryEditorPage.logicNotAny': return 'НЕ (любое)';
			case 'editor.lorebookEntryEditorPage.logicNotAll': return 'НЕ (все)';
			case 'editor.lorebookEntryEditorPage.optionalFilterLabel': return 'Дополнительный фильтр';
			case 'editor.lorebookEntryEditorPage.contentLabel': return 'Содержимое';
			case 'editor.lorebookEntryEditorPage.nonRecursableFilter': return 'Без рекурсии';
			case 'editor.lorebookEntryEditorPage.preventFurtherRecursionFilter': return 'Запретить дальнейшую рекурсию';
			case 'editor.lorebookEntryEditorPage.delayUntilRecursionFilter': return 'Отложить до рекурсии';
			case 'editor.lorebookEntryEditorPage.ignoreBudgetFilter': return 'Игнорировать бюджет';
			case 'editor.lorebookEntryEditorPage.prioritizeFilter': return 'Приоритизировать';
			case 'editor.lorebookEntryEditorPage.inclusionGroupLabel': return 'Группа включения';
			case 'editor.lorebookEntryEditorPage.groupWeightLabel': return 'Вес группы';
			case 'editor.lorebookEntryEditorPage.stickyLabel': return 'Закреплённый';
			case 'editor.lorebookEntryEditorPage.cooldownLabel': return 'Задержка перезарядки';
			case 'editor.lorebookEntryEditorPage.delayLabel': return 'Задержка';
			case 'editor.lorebookEntryEditorPage.filterToCharactersLabel': return 'Фильтр по персонажам или тегам';
			case 'editor.lorebookEntryEditorPage.filterToTriggersLabel': return 'Фильтр по триггерам генерации';
			case 'editor.lorebookEntryEditorPage.additionalMatchingSourcesLabel': return 'Дополнительные источники совпадений:';
			case 'editor.lorebookEntryEditorPage.personaFilter': return 'Персона';
			case 'editor.lorebookEntryEditorPage.descriptionFilter': return 'Описание';
			case 'editor.lorebookEntryEditorPage.personalityFilter': return 'Характер';
			case 'editor.lorebookEntryEditorPage.depthPromptFilter': return 'Глубинный промпт';
			case 'editor.lorebookEntryEditorPage.scenarioFilter': return 'Сценарий';
			case 'editor.lorebookEntryEditorPage.creatorNotesFilter': return 'Заметки автора';
			case 'editor.lorebookEntryEditorTopSection.titleMemoLabel': return 'Заголовок/памятка';
			case 'editor.lorebookEntryEditorTopSection.strategyLabel': return 'Стратегия';
			case 'editor.lorebookEntryEditorTopSection.strategyConstant': return 'Постоянный';
			case 'editor.lorebookEntryEditorTopSection.strategyEnabled': return 'Включён';
			case 'editor.lorebookEntryEditorTopSection.strategyDisabled': return 'Отключён';
			case 'editor.lorebookEntryEditorTopSection.strategyVectorized': return 'Векторизован';
			case 'editor.lorebookEntryEditorTopSection.positionLabel': return 'Позиция';
			case 'editor.lorebookEntryEditorTopSection.positionUpChar': return '↑ Перс';
			case 'editor.lorebookEntryEditorTopSection.positionDownChar': return '↓ Перс';
			case 'editor.lorebookEntryEditorTopSection.positionUpAn': return '↑ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDownAn': return '↓ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDepthSystem': return '@D система';
			case 'editor.lorebookEntryEditorTopSection.positionDepthUser': return '@D польз.';
			case 'editor.lorebookEntryEditorTopSection.positionDepthAssistant': return '@D ассистент';
			case 'editor.lorebookEntryEditorTopSection.positionUpEm': return '↑ EM';
			case 'editor.lorebookEntryEditorTopSection.positionDownEm': return '↓ EM';
			case 'editor.lorebookEntryEditorTopSection.positionOutlet': return 'Выход';
			case 'editor.lorebookEntryEditorTopSection.depthLabel': return 'Глубина';
			case 'editor.lorebookEntryEditorTopSection.orderLabel': return 'Порядок';
			case 'editor.lorebookEntryEditorTopSection.triggerLabel': return 'Триггер %';
			case 'editor.lorebookEntryEditorScanRow.scanDepthLabel': return 'Глубина сканирования';
			case 'editor.lorebookEntryEditorScanRow.automationIdLabel': return 'ID автоматизации';
			case 'editor.lorebookEntryEditorScanRow.useRegexFilter': return 'Использовать regex';
			case 'editor.lorebookEntryEditorScanRow.caseSensitiveFilter': return 'С учётом регистра';
			case 'editor.lorebookEntryEditorScanRow.wholeWordsFilter': return 'Слова целиком';
			case 'editor.lorebookEntryEditorScanRow.groupScoringFilter': return 'Оценка группы';
			case 'editor.dialogContentCleaner.confirmActionTitle': return ({required Object actionName}) => 'Подтвердите «${actionName}»';
			case 'editor.dialogContentCleaner.title': return 'Очистка содержимого';
			case 'editor.dialogContentCleaner.normalizeFancyCharsAction': return 'Нормализовать спецсимволы';
			case 'editor.dialogContentCleaner.normalizeFancyCharsButton': return 'Нормализовать спецсимволы (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
			case 'editor.dialogContentCleaner.purgeHtmlAction': return 'Удалить HTML';
			case 'editor.dialogContentCleaner.purgeHtmlButton': return 'Удалить теги HTML';
			case 'editor.dialogContentCleaner.purgeMarkdownAction': return 'Удалить ссылки/изображения Markdown';
			case 'editor.dialogContentCleaner.purgeEmojisAction': return 'Удалить эмодзи';
			case 'editor.dialogContentCleaner.purgeExtraSpacesAction': return 'Удалить лишние пробелы';
			case 'editor.dialogContentCleaner.yoloPurgeAction': return 'Полная очистка';
			case 'editor.dialogContentCleaner.applyAllAboveButton': return 'Применить всё выше';
			case 'editor.dialogAiDiffConfirmation.applyChangesButton': return 'Применить изменения';
			case 'editor.dialogAiDiffConfirmation.originalTextTitle': return 'Исходный текст';
			case 'editor.dialogAiDiffConfirmation.suggestedTextTitle': return 'Предложенный текст';
			case 'editor.editorPageController.globalActionTitle': return ({required Object action}) => 'Глобально: ${action}';
			case 'editor.editorPageController.globalAiActionFailed': return 'Глобальное действие ИИ не выполнено. Проверьте логи.';
			case 'editor.editorPageController.compositeName': return ({required Object value}) => 'Имя:\n${value}\n';
			case 'editor.editorPageController.compositeDescription': return ({required Object value}) => 'Описание:\n${value}\n';
			case 'editor.editorPageController.compositePersonality': return ({required Object value}) => 'Характер:\n${value}\n';
			case 'editor.editorPageController.compositeScenario': return ({required Object value}) => 'Сценарий:\n${value}\n';
			case 'editor.editorPageController.compositeFirstMessage': return ({required Object value}) => 'Первое сообщение:\n${value}\n';
			case 'editor.editorPageController.compositeMessageExample': return ({required Object value}) => 'Пример сообщения:\n${value}\n';
			case 'editor.editorPageController.compositeCreatorNotes': return ({required Object value}) => 'Заметки автора:\n${value}\n';
			case 'editor.editorPageController.compositeSystemPrompt': return ({required Object value}) => 'Системный промпт:\n${value}\n';
			case 'editor.editorPageController.compositePostHistoryInstructions': return ({required Object value}) => 'Инструкции после истории:\n${value}\n';
			case 'editor.editorPageController.compositeAlternateGreeting': return ({required Object index, required Object value}) => 'Альтернативное приветствие №${index}:\n${value}\n';
			case 'editor.editorPageController.compositeGroupGreeting': return ({required Object index, required Object value}) => 'Групповое приветствие №${index}:\n${value}\n';
			case 'editor.editorPageController.compositeLorebookEntry': return ({required Object index, required Object value}) => 'Запись лорбука №${index}:\n${value}\n';
			case 'editor.editorPageController.imageTooLargeMessage': return ({required Object maxSize}) => 'Выбранное изображение слишком большое. Максимальный размер — ${maxSize}.';
			case 'editor.editorPageController.invalidPngMessage': return 'Выбранное изображение не является корректным PNG или не может быть прочитано.';
			case 'editor.editorNodes.deleteNodeTitle': return 'Удалить узел';
			case 'editor.editorNodes.deleteNodeMessage': return 'Удалить этот авторский узел из карточки?';
			case 'editor.editorNodes.engineSeedTitle': return 'Начальное состояние движка';
			case 'editor.editorNodes.visualEditorTooltip': return 'Визуальный редактор';
			case 'editor.editorNodes.editJsonTooltip': return 'Редактировать JSON';
			case 'editor.editorNodes.initialGoalLabel': return 'Начальная цель';
			case 'editor.editorNodes.initialSceneLabel': return 'Начальная сцена';
			case 'editor.editorNodes.locationLabel': return 'Место';
			case 'editor.editorNodes.timeOfDayLabel': return 'Время суток';
			case 'editor.editorNodes.presentEntitiesLabel': return 'Присутствуют (через запятую)';
			case 'editor.editorNodes.sensoryHooksLabel': return 'Сенсорные зацепки (через запятую)';
			case 'editor.editorNodes.addNodeButton': return 'Добавить узел';
			case 'editor.editorNodes.noAuthoredNodesYet': return 'Авторских узлов пока нет.';
			case 'editor.editorNodes.loadErrorMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
				one: 'В блоке узлов этой карточки ${n} проблема; редактирование здесь перезапишет повреждённые части при сохранении.',
				few: 'В блоке узлов этой карточки ${n} проблемы; редактирование здесь перезапишет повреждённые части при сохранении.',
				many: 'В блоке узлов этой карточки ${n} проблем; редактирование здесь перезапишет повреждённые части при сохранении.',
				other: 'В блоке узлов этой карточки ${n} проблемы; редактирование здесь перезапишет повреждённые части при сохранении.',
			);
			case 'editor.editorNodes.moreErrorsSuffix': return ({required Object n}) => '… ещё ${n}';
			case 'editor.editorNodes.emotionBaselineLabel': return 'Базовая эмоция';
			case 'editor.editorNodes.emotionChipLabel': return 'Эмоция';
			case 'editor.nodeListTile.spawnsLabel': return ({required Object count}) => 'порождает: ${count}';
			case 'editor.nodesRawEditorPage.topLevelMustBeObject': return 'Верхний уровень должен быть объектом JSON';
			case 'editor.nodesRawEditorPage.editNodesJsonTitle': return 'Редактировать JSON узлов';
			case 'editor.nodesRawEditorPage.fixProblemsMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
				one: 'Исправьте ${n} проблему, чтобы сохранить.',
				few: 'Исправьте ${n} проблемы, чтобы сохранить.',
				many: 'Исправьте ${n} проблем, чтобы сохранить.',
				other: 'Исправьте ${n} проблемы, чтобы сохранить.',
			);
			case 'editor.nodesCanvasView.spawnedByPort': return 'порождён';
			case 'editor.nodesCanvasView.spawnsPort': return 'порождает';
			case 'editor.nodesCanvasView.editNodeLabel': return 'Редактировать узел';
			case 'editor.nodesCanvasView.addNodeTooltip': return 'Добавить узел';
			case 'editor.nodeEditorForm.nameLabel': return 'Имя';
			case 'editor.nodeEditorForm.narrativePayloadLabel': return 'Нарративная нагрузка';
			case 'editor.nodeEditorForm.removeSpawnLinkTitle': return 'Удалить связь порождения';
			case 'editor.nodeEditorForm.removeSpawnLinkMessage': return ({required Object nodeId}) => 'Запретить этому узлу порождать «${nodeId}»? Сам узел останется на карточке.';
			case 'editor.nodeEditorForm.removeButton': return 'Удалить';
			case 'editor.nodeEditorForm.typeLabel': return 'Тип';
			case 'editor.nodeEditorForm.scopeLabel': return 'Область';
			case 'editor.nodeEditorForm.originLabel': return 'Источник';
			case 'editor.nodeEditorForm.triggerProbLabel': return 'Вероятность триггера';
			case 'editor.nodeEditorForm.delayHelper': return 'Ходов ожидания перед активацией. -1 равно 0.';
			case 'editor.nodeEditorForm.cooldownHelper': return 'Ходов блокировки после срабатывания. -1 означает без перезарядки.';
			case 'editor.nodeEditorForm.stickyHelper': return 'Ходов, в течение которых нарративная нагрузка остаётся как «Сохраняющаяся» после срабатывания. -1 означает навсегда.';
			case 'editor.nodeEditorForm.aliveHelper': return 'Ходов, в течение которых узел остаётся в пуле до удаления. -1 означает бесконечно.';
			case 'editor.nodeEditorForm.setToNeverButton': return 'Установить «никогда»';
			case 'editor.nodeEditorForm.effectsSectionLabel': return 'Эффекты';
			case 'editor.nodeEditorForm.emotionDeltasTitle': return 'Изменения эмоций';
			case 'editor.nodeEditorForm.physicalDeltasTitle': return 'Физические изменения';
			case 'editor.nodeEditorForm.relationshipDeltasTitle': return 'Изменения отношений';
			case 'editor.nodeEditorForm.addDeltaChip': return 'Добавить изменение';
			case 'editor.nodeEditorForm.knowledgeWritesTitle': return 'Записи знаний';
			case 'editor.nodeEditorForm.addFactChip': return 'Добавить факт';
			case 'editor.nodeEditorForm.topicLabel': return 'тема';
			case 'editor.nodeEditorForm.confidenceLabel': return 'уверенность';
			case 'editor.nodeEditorForm.flagSetTitle': return 'Набор флагов';
			case 'editor.nodeEditorForm.addFlagChip': return 'Добавить флаг';
			case 'editor.nodeEditorForm.keyLabel': return 'ключ';
			case 'editor.nodeEditorForm.sceneAndFlowTitle': return 'Сцена и ход';
			case 'editor.nodeEditorForm.goalChangeLabel': return 'goalChange (очищает текущую цель, если пусто)';
			case 'editor.nodeEditorForm.phaseChangeLabel': return 'phaseChange';
			case 'editor.nodeEditorForm.noneOption': return '(нет)';
			case 'editor.nodeEditorForm.sceneTransitionLabel': return 'sceneTransition';
			case 'editor.nodeEditorForm.sceneTransitionSubtitle': return 'Если true, движок помечает срабатывание как смену сцены.';
			case 'editor.nodeEditorForm.spawnsSectionLabel': return 'Порождения';
			case 'editor.nodeEditorForm.addNewChip': return 'Добавить новый';
			case 'editor.nodeEditorForm.linkExistingChip': return 'Связать существующий';
			case 'editor.nodeEditorForm.unlinkTooltip': return 'Отвязать';
			case 'editor.nodeEditorForm.predicateLabel': return 'Предикат';
			case 'grid.emptyState.noMatches': return 'Нет персонажей по вашим фильтрам';
			case 'grid.emptyState.noCharacters': return 'Персонажи ещё не импортированы';
			case 'grid.emptyState.clearAllFilters': return 'Сбросить все фильтры';
			case 'grid.emptyState.importCharacters': return 'Импортировать персонажей';
			case 'grid.emptyState.createNewCharacter': return 'Создать персонажа';
			case 'grid.appBar.groups': return 'Группы';
			case 'grid.appBar.createNew': return 'Создать';
			case 'grid.appBar.import': return 'Импорт';
			case 'grid.appBar.menuTooltip': return 'Меню';
			case 'grid.fab.addOrImportTooltip': return 'Добавить или импортировать';
			case 'grid.fab.import': return 'Импорт';
			case 'grid.fab.create': return 'Создать';
			case 'grid.drawer.mediaDefaultsApp': return 'Приложение';
			case 'grid.drawer.batchAiHeader': return 'Пакетный ИИ';
			case 'grid.drawer.batchGeneratePreviewsTitle': return 'Пакетная генерация превью';
			case 'grid.drawer.batchGeneratePreviewsEmpty': return 'У всех персонажей уже есть превью.';
			case 'grid.drawer.batchAutoTagTitle': return 'Пакетное авто-тегирование';
			case 'grid.drawer.batchAutoTagEmpty': return 'У всех персонажей уже есть теги.';
			case 'grid.drawer.libraryHeader': return 'Библиотека';
			case 'grid.drawer.reloadCharacters': return 'Перезагрузить персонажей';
			case 'grid.variantBadge.tooltip': return ({required Object count}) => 'Вариантов: ${count}';
			case 'grid.dialogActions.clearAll': return 'Очистить всё';
			case 'grid.dialogActions.apply': return 'Применить';
			case 'grid.tagFilterDialog.title': return 'Фильтр по тегам';
			case 'grid.tagFilterDialog.searchHint': return 'Поиск тегов...';
			case 'grid.filters.hideFiltersTooltip': return 'Скрыть фильтры';
			case 'grid.filters.moreFiltersTooltip': return 'Больше фильтров';
			case 'grid.filters.folderChip': return 'Папка';
			case 'grid.filters.creatorChip': return 'Автор';
			case 'grid.filters.tagChip': return 'Тег';
			case 'grid.filters.recentTooltip': return 'Недавние';
			case 'grid.filters.favoritesTooltip': return 'Избранное';
			case 'grid.filters.variantsTooltip': return 'Варианты';
			case 'grid.filters.indexingProgress': return ({required Object done, required Object total}) => 'Построение поиска ${done} / ${total}…';
			case 'grid.sortOption.relevance': return 'Релевантность ↓';
			case 'grid.sortOption.nameAsc': return 'Имя ↓';
			case 'grid.sortOption.nameDesc': return 'Имя ↑';
			case 'grid.sortOption.importNewest': return 'Импортировано ↓';
			case 'grid.sortOption.importOldest': return 'Импортировано ↑';
			case 'grid.sortOption.modifiedNewest': return 'Изменено ↓';
			case 'grid.sortOption.modifiedOldest': return 'Изменено ↑';
			case 'grid.sortOption.interactedNewest': return 'Взаимодействие ↓';
			case 'grid.sortOption.interactedOldest': return 'Взаимодействие ↑';
			case 'grid.sortOption.tokensHigh': return 'Токены ↓';
			case 'grid.sortOption.tokensLow': return 'Токены ↑';
			case 'grid.filterController.filterCreators': return 'Фильтр по авторам';
			case 'grid.filterController.filterTags': return 'Фильтр по тегам';
			case 'grid.filterController.filterByFolder': return 'Фильтр по папке';
			case 'grid.multiSelectDialog.nothingToShow': return 'Пока нечего показать.';
			case 'grid.multiSelectDialog.noMatches': return 'Совпадений нет.';
			case 'grid.multiSelectDialog.showMore': return 'Показать ещё';
			case 'grid.createCharacterDialog.nameEmptyError': return 'Имя персонажа не может быть пустым.';
			case 'grid.createCharacterDialog.nameInvalidCharsError': return 'Имя содержит недопустимые символы (<>:"/\|?*).';
			case 'grid.createCharacterDialog.nameExistsError': return 'Персонаж с таким именем уже существует.';
			case 'grid.createCharacterDialog.nameCheckFailedError': return 'Не удалось проверить имя. Проверьте права доступа к папке и попробуйте снова.';
			case 'grid.createCharacterDialog.title': return 'Создать персонажа';
			case 'grid.createCharacterDialog.nameLabel': return 'Имя персонажа';
			case 'grid.createCharacterDialog.createButton': return 'Создать';
			case 'grid.variantsSheet.title': return 'Варианты';
			case 'grid.groupAppBar.characters': return 'Персонажи';
			case 'grid.groupAppBar.newGroup': return 'Новая группа';
			case 'grid.thumbnailBadges.recent': return 'НЕДАВНИЙ';
			case 'grid.thumbnailBadges.original': return 'ОРИГИНАЛ';
			case 'grid.thumbnailBadges.variant': return 'ВАРИАНТ';
			case 'grid.actionMenu.editNotes': return 'Редактировать заметки';
			case 'grid.actionMenu.dismissRecent': return 'Убрать из недавних';
			case 'grid.actionMenu.exportPngV2V3': return 'Экспорт как PNG (V2/V3)';
			case 'grid.actionMenu.exportJsonV3': return 'Экспорт как JSON (V3)';
			case 'grid.actionMenu.exportJsonV2': return 'Экспорт как JSON (V2)';
			case 'grid.actionMenu.duplicate': return 'Дублировать';
			case 'grid.controllerMessages.duplicateFailed': return 'Не удалось дублировать персонажа.';
			case 'grid.controllerMessages.editVariantNotesTitle': return 'Редактировать заметки варианта';
			case 'grid.controllerMessages.editVariantNotesHint': return 'Добавьте заметки об этом варианте...';
			case 'grid.controllerMessages.deleteCardTitle': return 'Удалить карточку';
			case 'grid.controllerMessages.deleteCardMessage': return 'Вы уверены, что хотите удалить эту карточку?';
			case 'grid.controllerMessages.deletePartialFailure': return 'Некоторые файлы не удалось удалить. Подробности в логах.';
			case 'grid.tagWrap.tagCountLabel': return ({required Object tag, required Object count}) => '${tag} (${count})';
			case 'group.groupGridController.renameGroupTitle': return 'Переименовать группу';
			case 'group.groupGridController.groupNameHint': return 'Название группы';
			case 'group.groupGridController.deleteGroupTitle': return 'Удалить группу';
			case 'group.groupGridController.deleteGroupMessage': return ({required Object name}) => 'Вы уверены, что хотите удалить «${name}»? Это нельзя отменить.';
			case 'group.groupChatPage.defaultGroupName': return 'Групповой чат';
			case 'group.groupChatPage.failedToLoadMessage': return ({required Object error}) => 'Не удалось загрузить групповой чат:\n${error}';
			case 'group.groupChatPage.nextTurnTooltip': return 'Следующий ход';
			case 'group.groupChatPage.stopAutoChatTooltip': return 'Остановить авточат';
			case 'group.groupChatPage.startAutoChatTooltip': return 'Запустить авточат';
			case 'group.groupChatPage.stopGenerationTooltip': return 'Остановить генерацию';
			case 'group.groupChatPage.noCharactersYetMessage': return 'В этой группе пока нет персонажей.';
			case 'group.groupChatPage.addCharacterButton': return 'Добавить персонажа';
			case 'group.groupChatPage.pickCharacterMessage': return 'Выберите персонажа из списка слева.';
			case 'group.groupGridPage.failedToLoadMessage': return ({required Object error}) => 'Не удалось загрузить группы:\n${error}';
			case 'group.groupGridPage.unknownErrorFallback': return 'неизвестная ошибка';
			case 'group.groupGridPage.noGroupsYetMessage': return 'Групп пока нет — нажмите +, чтобы создать.';
			case 'group.tileAutoChatDelay.title': return 'Задержка авточата';
			case 'group.tileAutoChatDelay.secondsAbbrev': return ({required Object seconds}) => '${seconds} с';
			case 'group.tileActivationStrategy.title': return 'Выбор говорящего';
			case 'group.tileActivationStrategy.naturalOption': return 'Естественный';
			case 'group.tileActivationStrategy.roundRobinOption': return 'По кругу';
			case 'group.tileActivationStrategy.randomOption': return 'Случайный';
			case 'group.tileActivationStrategy.changeSelectionTooltip': return 'Изменить выбор говорящего';
			case 'group.groupChatPageEndDrawer.allowWebFetchTitle': return 'Разрешить веб-запросы';
			case 'group.groupChatPageEndDrawer.allowWebFetchSubtitle': return 'Читать публичные веб-страницы, когда это уместно';
			case 'group.groupChatPageEndDrawer.reviewUrlTitle': return 'Проверять URL перед запросом';
			case 'group.groupChatPageEndDrawer.reviewUrlSubtitle': return 'Подтверждать каждый запрос';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesTitle': return 'Предлагать имена NPC';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesSubtitle': return 'Выбирать имена из курируемой базы';
			case 'group.groupChatPageEndDrawer.unrestrictedImagesTitle': return 'Изображения без ограничений';
			case 'group.groupChatPageEndDrawer.allowNsfwImagePromptsSubtitle': return 'Разрешить NSFW-промпты изображений';
			case 'group.groupChatPageEndDrawer.characterCanSendSelfiesTitle': return 'Персонаж может отправлять селфи';
			case 'group.groupChatPageEndDrawer.attachSelfieWhenNaturalSubtitle': return 'Прикреплять селфи, когда это естественно';
			case 'group.groupChatPageEndDrawer.reviewImagePromptTitle': return 'Проверять промпт изображения';
			case 'group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle': return 'Редактировать перед генерацией';
			case 'group.groupChatPageEndDrawer.reviewToolImagePromptsTitle': return 'Проверять промпты изображений от инструментов';
			case 'group.groupChatPageEndDrawer.editToolTriggeredPromptsSubtitle': return 'Редактировать промпты, вызванные инструментами';
			case 'group.groupChatPageEndDrawer.allowSelfieCaptionsTitle': return 'Разрешить подписи к селфи';
			case 'group.groupChatPageEndDrawer.captionRenderedOnImageSubtitle': return 'Подпись наносится на изображение';
			case 'group.groupChatPageEndDrawer.groupOverridesTitle': return 'Переопределения группы';
			case 'group.groupChatPageEndDrawer.groupOverridesSubtitle': return 'Общий сценарий, основной промпт, пример диалога';
			case 'group.groupChatPageEndDrawer.chatSessionSubtitle': return 'Сессия чата';
			case 'group.groupChatPageEndDrawer.allChatsLabel': return 'Все чаты';
			case 'group.groupChatPageEndDrawer.showImageLabel': return 'Показать изображение';
			case 'group.groupChatPageEndDrawer.groupSectionHeader': return 'Группа';
			case 'group.groupChatPageEndDrawer.chatSectionHeader': return 'Чат';
			case 'group.groupChatPageEndDrawer.chatThemeSectionHeader': return 'Тема чата';
			case 'group.groupChatPageEndDrawer.unrestrictedVideosTitle': return 'Видео без ограничений';
			case 'group.groupChatPageEndDrawer.allowNsfwVideoPromptsSubtitle': return 'Разрешить NSFW-промпты видео';
			case 'group.groupChatPageEndDrawer.characterCanSendVideosTitle': return 'Персонаж может отправлять видео';
			case 'group.groupChatPageEndDrawer.attachShortVideoWhenNaturalSubtitle': return 'Прикреплять короткое видео, когда это естественно';
			case 'group.groupChatPageEndDrawer.reviewVideoPromptTitle': return 'Проверять промпт видео';
			case 'group.groupCharacterPicker.addButton': return 'Добавить';
			case 'group.groupCharacterPicker.addWithCountButton': return ({required Object count}) => 'Добавить ${count}';
			case 'group.groupCharacterPicker.favoritesTooltip': return 'Избранное';
			case 'group.groupCharacterPicker.noMatchMessage': return ({required Object query}) => 'Нет персонажей по запросу «${query}»';
			case 'group.groupCharacterPicker.noFavoritesMessage': return 'Нет избранных персонажей';
			case 'group.groupCharacterPicker.allAddedMessage': return 'Все персонажи уже добавлены';
			case 'group.groupCharacterTile.speakTooltip': return 'Заставить этого персонажа говорить';
			case 'group.groupCharacterTile.removeFromChatTitle': return 'Убрать из чата';
			case 'group.dialogCreateGroup.title': return 'Новая группа';
			case 'group.dialogCreateGroup.nameLabel': return 'Название';
			case 'group.dialogCreateGroup.nameHint': return 'напр., Боб и Алиса';
			case 'group.dialogGroupOverrides.explanationMessage': return 'Уникально для этого чата. Все участники группы используют эти значения вместо того, что задано в их карточках. Оставьте пустым, чтобы вернуться к значению карточки.';
			case 'group.dialogGroupOverrides.scenarioHint': return 'Общая обстановка для группы (напр., «В кафе в Париже»)';
			case 'group.dialogGroupOverrides.mainPromptLabel': return 'Основной промпт';
			case 'group.dialogGroupOverrides.mainPromptHint': return 'Системный промпт, применяемый на каждом ходу';
			case 'group.dialogGroupOverrides.exampleDialogueLabel': return 'Пример диалога';
			case 'group.dialogGroupOverrides.exampleDialogueHint': return 'Общие примеры сообщений для тона/форматирования';
			case 'group.groupCharacterPanel.addCharacterButton': return 'Добавить персонажа';
			case 'group.groupCharacterPanel.noCharactersYetMessage': return 'Персонажей пока нет.\nНажмите +, чтобы добавить.';
			case 'group.dialogSelectGroup.deleteGroupTitle': return 'Удалить группу?';
			case 'group.dialogSelectGroup.deleteGroupMessage': return ({required Object name}) => '«${name}» и все её сессии чата будут безвозвратно удалены.';
			case 'group.dialogSelectGroup.title': return 'Группы';
			case 'group.dialogSelectGroup.noGroupsYetMessage': return 'Групп пока нет. Нажмите «Новая группа», чтобы создать.';
			case 'group.dialogSelectGroup.memberCountLabel': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
				one: '${n} участник',
				few: '${n} участника',
				many: '${n} участников',
				other: '${n} участника',
			);
			case 'group.groupGridItem.overflowCountBadge': return ({required Object count}) => '+${count}';
			case 'group.groupGridItem.noMembersYetMessage': return 'Пока нет участников';
			case 'group.groupFileService.defaultGroupName': return 'Группа';
			case 'llmApp.mediaField.imageModel': return 'Модель изображений';
			case 'llmApp.mediaField.imageAspectRatio': return 'Соотношение сторон изображения';
			case 'llmApp.mediaField.imageNsfwAllowed': return 'Разрешить NSFW-изображения';
			case 'llmApp.mediaField.imageToolSelfieAllowed': return 'Может отправлять селфи';
			case 'llmApp.mediaField.imageToolSelfieCaptionsAllowed': return 'Разрешить подписи к селфи';
			case 'llmApp.mediaField.imagePromptPrefix': return 'Стиль изображения';
			case 'llmApp.mediaField.videoModel': return 'Модель видео';
			case 'llmApp.mediaField.videoResolution': return 'Разрешение видео';
			case 'llmApp.mediaField.videoAspectRatio': return 'Соотношение сторон видео';
			case 'llmApp.mediaField.videoDuration': return 'Длительность видео';
			case 'llmApp.mediaField.videoNsfwAllowed': return 'Разрешить NSFW-видео';
			case 'llmApp.mediaField.videoToolSendAllowed': return 'Может отправлять видео';
			case 'llmApp.mediaField.videoPromptPrefix': return 'Стиль видео';
			case 'llmApp.mediaField.ttsModel': return 'Модель TTS';
			case 'llmApp.mediaField.ttsVoice': return 'Голос TTS';
			case 'llmApp.mediaField.ttsLanguage': return 'Язык TTS';
			case 'llmApp.mediaField.webToolFetchAllowed': return 'Разрешить веб-запросы';
			case 'llmApp.mediaField.nameToolSuggestAllowed': return 'Может предлагать имена NPC';
			case 'llmApp.mediaSection.image': return 'Изображение';
			case 'llmApp.mediaSection.video': return 'Видео';
			case 'llmApp.mediaSection.tts': return 'TTS';
			case 'llmApp.mediaSection.web': return 'Веб';
			case 'llmApp.mediaSection.names': return 'Имена';
			case 'llmApp.tristate.on': return 'Вкл.';
			case 'llmApp.tristate.off': return 'Выкл.';
			case 'llmApp.tristate.inherit': return 'Наследовать';
			case 'llmApp.mediaCellMenu.change': return 'Изменить…';
			case 'llmApp.mediaCellMenu.clear': return 'Очистить';
			case 'llmApp.mediaHeader.appDefault': return 'По умолчанию';
			case 'llmApp.mediaHeader.character': return 'Персонаж';
			case 'llmApp.mediaHeader.currentChat': return 'Текущий чат';
			case 'llmApp.mediaHeader.previousLayerTooltip': return 'Предыдущий слой';
			case 'llmApp.mediaHeader.nextLayerTooltip': return 'Следующий слой';
			case 'llmApp.presetRow.changeAppDefaultTitle': return 'Изменить значение по умолчанию?';
			case 'llmApp.presetRow.changeAppDefaultMessage': return 'Это затронет каждый чат. Продолжить?';
			case 'llmApp.presetRow.continueButton': return 'Продолжить';
			case 'llmApp.presetRow.chooseModelTitle': return ({required Object domain}) => 'Выберите модель для «${domain}»';
			case 'llmApp.mediaCell.notApplicable': return 'Неприменимо';
			case 'onboarding.finishFailedSnackbar': return 'Не удалось завершить настройку. Подробности в логах.';
			case 'onboarding.appBarTitle': return 'Быстрая настройка';
			case 'onboarding.webWarning': return 'Экспериментальная веб-сборка — хранилище браузера может сбрасываться между обновлениями. Для постоянного хранения данных используйте десктоп или Android.';
			case 'onboarding.finishButton': return 'Завершить настройку';
			case 'onboarding.nextButton': return 'Далее';
			case 'onboarding.backButton': return 'Назад';
			case 'onboarding.storageStep.title': return 'Хранение персонажей';
			case 'onboarding.storageStep.subtitle': return 'Где сохранять ваши карточки персонажей?';
			case 'onboarding.storageStep.description': return 'По умолчанию сохраняются в папке приложения. Укажите существующую папку с PNG, чтобы импортировать их.';
			case 'onboarding.storageStep.startFresh': return 'Начать с нуля';
			case 'onboarding.storageStep.haveCards': return 'У меня уже есть карточки';
			case 'onboarding.storageStep.importLaterHint': return 'Импортировать PNG можно позже через Файл → Импорт.';
			case 'onboarding.storageStep.selectedPath': return ({required Object path}) => 'Выбрано: ${path}';
			case 'onboarding.storageStep.selectedDefaultFolder': return 'Выбрано: папка приложения по умолчанию';
			case 'onboarding.storageStep.noFolderSelected': return 'Папка ещё не выбрана.';
			case 'onboarding.setupStep.title': return 'ИИ и персона';
			case 'onboarding.aiSection.heading': return 'Подключение ИИ';
			case 'onboarding.aiSection.optionalHint': return 'Необязательно — можно пропустить и добавить ключ позже в настройках (локальные провайдеры тоже добавляются там).';
			case 'onboarding.aiSection.apiKeyLabel': return 'Ключ API';
			case 'onboarding.aiSection.apiKeyHint': return 'Вставьте ключ (или пропустите пока)';
			case 'onboarding.aiSection.supportedProviders': return 'Поддерживает OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. Больше — в настройках.';
			case 'onboarding.aiSection.unknownModel': return '(неизвестная модель)';
			case 'onboarding.aiSection.ctxUnknown': return 'ctx —';
			case 'onboarding.aiSection.ctxValue': return ({required Object ctx}) => 'ctx ${ctx}';
			case 'onboarding.aiSection.kvSuffix': return ({required Object kv}) => ' · KV ${kv}';
			case 'onboarding.aiSection.changeButton': return 'Изменить';
			case 'onboarding.aiStatus.connecting': return 'Подключение…';
			case 'onboarding.aiStatus.connected': return ({required Object provider}) => 'Подключено к ${provider}. Выбрана модель чата по умолчанию.';
			case 'onboarding.aiStatus.detected': return ({required Object provider}) => 'Обнаружено: ${provider}';
			case 'onboarding.aiStatus.unrecognizedKey': return 'Нераспознанный формат ключа.';
			case 'onboarding.personaSection.heading': return 'Ваша персона';
			case 'onboarding.personaSection.hint': return 'Ваше имя в чатах. Подробнее о персоне — в настройках.';
			case 'onboarding.personaSection.nameLabel': return 'Ваше имя';
			case 'onboarding.disclaimer.prefix': return 'Я прочитал(а) и принимаю ';
			case 'onboarding.disclaimer.linkText': return 'Дисклеймер';
			case 'onboarding.fetchError.noModels': return 'Модели не получены. Проверьте свой ключ API.';
			case 'onboarding.fetchError.connectionFailed': return 'Не удалось подключиться. Проверьте интернет-соединение и ключ API.';
			case 'routing.chatCharacter.navigationError': return ({required Object name}) => 'Ошибка перехода к чату. Персонаж: ${name}';
			case 'routing.editCharacter.navigationError': return ({required Object name}) => 'Ошибка перехода к редактированию. Персонаж: ${name}';
			case 'routing.editPreset.navigationError': return ({required Object presetId}) => 'Ошибка перехода к редактированию пресета: ${presetId}';
			case 'settings.gearLanguage': return 'Язык';
			case 'settings.languageSystemDefault': return 'Системный по умолчанию';
			case 'settings.gearMenu.settingsTooltip': return 'Настройки';
			case 'settings.gearMenu.mediaDefaultsApp': return 'Приложение';
			case 'settings.gearMenu.mediaDefaultsCharacter': return 'Персонаж';
			case 'settings.gearMenu.mediaDefaultsChat': return 'Чат';
			case 'settings.gearMenu.appSettings': return 'Настройки приложения';
			case 'settings.gearMenu.logs': return 'Логи';
			case 'settings.mediaDefaultsDrawerEntry.configurationHeader': return 'Конфигурация';
			case 'settings.endDrawer.switchPersonaTooltip': return 'Сменить персону';
			case 'settings.loadingStatus.restoringProviders': return 'Восстановление провайдеров…';
			case 'settings.loadingStatus.fetchingModelsProgress': return ({required Object completed, required Object total}) => 'Загрузка моделей (${completed}/${total})…';
			case 'settings.general.characterFolderTitle': return 'Папка персонажей';
			case 'settings.general.characterFolderNotSet': return 'Не задана. Требуется для работы приложения.';
			case 'settings.general.browseButton': return 'Обзор...';
			case 'settings.general.taxonomyTagsTitle': return 'Теги таксономии';
			case 'settings.general.appThemeTitle': return 'Тема приложения';
			case 'settings.general.themeSystem': return 'Системная';
			case 'settings.general.themeLight': return 'Светлая';
			case 'settings.general.themeDark': return 'Тёмная';
			case 'settings.general.themeStyleTitle': return 'Стиль темы';
			case 'settings.general.themeStyleDefault': return 'По умолчанию';
			case 'settings.general.themeStyleNeon': return 'Неон';
			case 'settings.general.storyMemoryTitle': return 'Память истории';
			case 'settings.general.storyMemorySubtitle': return 'Запоминать ранние моменты и возвращать нужные из них в длинных чатах.';
			case 'settings.general.narrativeEngineTitle': return 'Нарративный движок';
			case 'settings.general.narrativeEngineSubtitle': return 'Отслеживать сцену и персонажей и двигать историю по мере вашей переписки.';
			case 'settings.general.promptBreakdownTitle': return 'Показывать разбор промпта';
			case 'settings.general.promptBreakdownSubtitle': return 'Показывать под каждым ответом полосу, разбивающую, как промпт заполнил контекстное окно модели.';
			case 'settings.general.checkUpdatesTitle': return 'Проверить обновления';
			case 'settings.general.checkUpdatesSubtitle': return 'Проверить, доступна ли более новая версия приложения.';
			case 'settings.general.websiteTitle': return 'Сайт';
			case 'settings.general.websiteSubtitle': return 'Посетите официальный сайт для обновлений и информации.';
			case 'settings.general.disclaimerTitle': return 'Дисклеймер и условия';
			case 'settings.general.disclaimerSubtitle': return 'Прочитайте дисклеймер приложения и условия использования.';
			case 'settings.general.versionLabel': return ({required Object version, required Object buildNumber}) => 'Версия ${version}+${buildNumber}';
			case 'settings.aiSettingsTab.aiProviders': return 'Провайдеры ИИ';
			case 'settings.aiSettingsTab.mediaDefaults': return 'Медиа по умолчанию';
			case 'settings.aiTab.refreshSummary': return ({required Object updated, required Object unavailable, required Object errors}) => 'Обновлено моделей: ${updated}, недоступно: ${unavailable}, ошибок: ${errors}.';
			case 'settings.aiTab.newProviderButton': return 'Новый провайдер';
			case 'settings.aiTab.cloudProviderMenuItem': return 'Облачный провайдер';
			case 'settings.aiTab.localProviderMenuItem': return 'Локальный провайдер';
			case 'settings.aiTab.localGgufMenuItem': return 'Локальный GGUF';
			case 'settings.aiTab.noProvidersConfigured': return 'Провайдеры API не настроены.';
			case 'settings.aiTab.addingProviderOverlay': return 'Добавление провайдера…';
			case 'settings.aiTab.neverRefreshed': return 'Никогда не обновлялось';
			case 'settings.aiTab.lastRefreshedLabel': return ({required Object time}) => 'Последнее обновление: ${time}';
			case 'settings.aiTab.refreshModelsButton': return 'Обновить модели';
			case 'settings.aiTab.refreshNowMenuItem': return 'Обновить сейчас';
			case 'settings.aiTab.autoNeverMenuItem': return 'Авто: никогда';
			case 'settings.aiTab.autoDailyMenuItem': return 'Авто: ежедневно при запуске';
			case 'settings.aiTab.defaultModelsHeader': return 'Модели по умолчанию для новых чатов';
			case 'settings.aiTab.editModelTooltip': return 'Редактировать модель';
			case 'settings.aiTab.noModelsPlaceholder': return 'Нет моделей';
			case 'settings.aiTab.noCompatibleModelsPlaceholder': return 'Нет совместимых моделей';
			case 'settings.aiTab.tapToChoosePlaceholder': return 'Нажмите, чтобы выбрать';
			case 'settings.aiTab.modelUsedForPrefix': return 'Модель для ';
			case 'settings.aiTab.modelUsedForSuffix': return ' генерации';
			case 'settings.aiTab.chooseModelTitle': return 'Выберите модель';
			case 'settings.aiTab.temperatureLabel': return ({required Object value}) => 'Темп. ${value}';
			case 'settings.aiTab.setDefaultButton': return 'По умолчанию';
			case 'settings.aiTab.addModelButton': return 'Добавить модель';
			case 'settings.aiTab.editProviderMenuItem': return 'Редактировать провайдера';
			case 'settings.aiTab.moreTooltip': return 'Ещё';
			case 'settings.aiTab.noModelsForProvider': return 'Для этого провайдера не настроено ни одной модели.';
			case 'settings.aiTab.setDefaultConfirmTitle': return ({required Object provider}) => 'Сделать ${provider} провайдером по умолчанию для всех функций ИИ?';
			case 'settings.aiTab.setDefaultConfirmMessage': return 'Вы можете сами выбрать модели для неподдерживаемых функций\n(например, изображение или видео) у других провайдеров.';
			case 'settings.aiTab.localGgufSubtitle': return ({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (макс. ${native}) · KV ${kv}';
			case 'settings.aiTab.testTtsTooltip': return 'Проверить TTS';
			case 'settings.aiTab.ttsTestPhrase': return 'Здравствуйте, это проверка.';
			case 'settings.aiTab.ttsFailedError': return 'Ошибка TTS.';
			case 'settings.aiTab.testVideoTooltip': return 'Проверить генерацию видео';
			case 'settings.aiTab.videoGeneratedWebFallback': return 'Видео успешно сгенерировано (предпросмотр недоступен в вебе).';
			case 'settings.aiTab.videoFailedError': return 'Ошибка видео.';
			case 'settings.aiTab.videoLoadFailedMessage': return 'Не удалось загрузить сгенерированное видео.';
			case 'settings.aiTab.presetPickerSearchHint': return 'Поиск по провайдеру, модели или пресету…';
			case 'settings.aiTab.tempParamAbbrev': return ({required Object value}) => 'темп. ${value}';
			case 'settings.aiTab.reasoningParamLabel': return ({required Object level}) => 'рассуждения ${level}';
			case 'settings.presetConfig.testMessageButton': return 'Тестовое сообщение';
			case 'settings.presetConfig.testSuccessLabel': return 'Успех';
			case 'settings.presetConfig.testFailedLabel': return 'Ошибка';
			case 'settings.presetConfig.deleteModelTitle': return 'Удалить модель?';
			case 'settings.presetConfig.deleteModelMessage': return ({required Object name}) => 'Безвозвратно удалить «${name}»? Это нельзя отменить.';
			case 'settings.presetConfig.editModelHeader': return 'Редактировать модель';
			case 'settings.presetConfig.addModelHeader': return 'Добавить модель';
			case 'settings.presetConfig.resetToDefaultsTooltip': return 'Сбросить к значениям по умолчанию';
			case 'settings.presetConfig.modelNameLabel': return 'Название модели';
			case 'settings.presetConfig.clearTooltip': return 'Очистить';
			case 'settings.presetConfig.nameRequiredError': return 'Требуется имя';
			case 'settings.presetConfig.modelLabel': return 'Модель';
			case 'settings.presetConfig.selectModelHint': return 'Выберите модель';
			case 'settings.presetConfig.modelRequiredError': return 'Требуется модель';
			case 'settings.presetConfig.filteredDomainsNote': return ({required Object domains}) => 'Модели отфильтрованы для поддержки активных доменов: ${domains}';
			case 'settings.presetConfig.requiredValidator': return 'Обязательно';
			case 'settings.presetConfig.invalidValidator': return 'Недопустимо';
			case 'settings.presetConfig.testResponseTitle': return 'Ответ';
			case 'settings.providerConfig.noModelsError': return 'Модели не получены. Проверьте свой ключ API.';
			case 'settings.providerConfig.connectionFailedError': return 'Не удалось подключиться. Проверьте интернет-соединение и ключ API.';
			case 'settings.providerConfig.deleteProviderTitle': return 'Удалить провайдера?';
			case 'settings.providerConfig.deleteProviderMessage': return ({required Object provider}) => 'Безвозвратно удалить провайдера ${provider} и все его пресеты? Это нельзя отменить.';
			case 'settings.providerConfig.lockHint': return ({required Object roles}) => 'Нельзя удалить: используется в ${roles}.';
			case 'settings.providerConfig.editProviderHeader': return 'Редактировать провайдера';
			case 'settings.providerConfig.addProviderHeader': return 'Добавить провайдера';
			case 'settings.providerConfig.apiKeyLabel': return 'Ключ API';
			case 'settings.providerConfig.apiKeyHintRotate': return 'Вставьте новый ключ для замены';
			case 'settings.providerConfig.apiKeyHintNew': return 'Вставьте ключ — провайдер определится автоматически';
			case 'settings.providerConfig.supportedProvidersNote': return 'Поддерживает OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
			case 'settings.providerConfig.keyMismatchError': return ({required Object owner, required Object profile}) => 'Этот ключ принадлежит ${owner}, но профиль — ${profile}. Удалите этот профиль и добавьте новый.';
			case 'settings.providerConfig.anotherProviderFallback': return 'другой провайдер';
			case 'settings.providerConfig.connectingStatus': return 'Подключение…';
			case 'settings.providerConfig.connectedStatus': return ({required Object provider}) => 'Подключено к ${provider}. Будут созданы пресеты по умолчанию.';
			case 'settings.providerConfig.detectedStatus': return ({required Object provider}) => 'Обнаружено: ${provider}';
			case 'settings.providerConfig.unrecognizedKeyStatus': return 'Нераспознанный формат ключа.';
			case 'settings.localProviderConfig.serverUnreachableMessage': return ({required Object url}) => 'Не удалось связаться с ${url}. Убедитесь, что ваш локальный сервер (KoboldCpp / Ollama / LM Studio / llama.cpp) запущен.';
			case 'settings.localProviderConfig.noModelsError': return 'Сервер доступен, но не вернул моделей. Сначала загрузите модель на локальном сервере.';
			case 'settings.localProviderConfig.deleteProviderMessage': return 'Безвозвратно удалить этого локального провайдера и все его пресеты? Это нельзя отменить.';
			case 'settings.localProviderConfig.editHeader': return 'Редактировать локального провайдера';
			case 'settings.localProviderConfig.addHeader': return 'Добавить локального провайдера';
			case 'settings.localProviderConfig.serverUrlLabel': return 'URL сервера';
			case 'settings.localProviderConfig.serverUrlLockedHelper': return 'Заблокировано. Удалите этого провайдера и добавьте нового, чтобы указать другой сервер.';
			case 'settings.localProviderConfig.apiKeyOptionalLabel': return 'Ключ API (необязательно)';
			case 'settings.localProviderConfig.apiKeyOptionalHint': return 'Оставьте пустым — большинству локальных серверов ключ не нужен';
			case 'settings.localProviderConfig.connectFetchButton': return 'Подключиться и загрузить модели';
			case 'settings.localProviderConfig.connectedFoundModels': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
				one: 'Подключено. Найдена ${n} модель.',
				few: 'Подключено. Найдено ${n} модели.',
				many: 'Подключено. Найдено ${n} моделей.',
				other: 'Подключено. Найдено ${n} модели.',
			);
			case 'settings.localGguf.haveLocalGgufExpanderTitle': return 'У меня есть локальный файл GGUF';
			case 'settings.localGguf.pickFileLabel': return 'Выбрать файл GGUF...';
			case 'settings.localGguf.loadModelLabel': return 'Загрузить модель';
			case 'settings.localGguf.nativeContextLabel': return 'Родной контекст';
			case 'settings.localGguf.freeVramLabel': return 'Свободная VRAM';
			case 'settings.localGguf.contextSizeLabel': return 'Размер контекста';
			case 'settings.localGguf.kvCacheLabel': return 'Кэш KV';
			case 'settings.localGguf.kvCacheAutoLabel': return 'Авто';
			case 'settings.localGguf.modelTooLargeForVramMessage': return ({required Object neededMb, required Object freeMb}) => 'Этой модели нужно около ${neededMb}МБ памяти GPU, но свободно только ${freeMb}МБ. Закройте другие приложения GPU или выберите меньшую / более квантованную модель.';
			case 'settings.localGguf.modelBarelyFitsMessage': return ({required Object minimumContext}) => 'Эта модель едва помещается даже с KV-кэшем q4_0 при ${minimumContext} токенах. Рассмотрите более агрессивно квантованный файл модели.';
			case 'settings.localGguf.readingMetadata': return 'Чтение метаданных модели…';
			case 'settings.localGguf.architectureLabel': return 'Архитектура';
			case 'settings.localGguf.autoKvHint': return ({required Object picked, required Object max}) => 'авто: ${picked} (макс. ${max})';
			case 'settings.localGguf.maxKvHint': return ({required Object max, required Object picked}) => 'макс. ${max} при KV ${picked}';
			case 'settings.localGguf.ctxExceedsMaxError': return ({required Object max, required Object picked}) => 'свыше ${max} при KV ${picked} — загрузка может вызвать OOM';
			case 'settings.localGguf.vramNotDetected': return 'не определено';
			case 'settings.localGguf.readMetadataFailedError': return ({required Object error}) => 'Не удалось прочитать метаданные GGUF: ${error}';
			case 'settings.localGguf.loadModelFailedError': return ({required Object error}) => 'Не удалось загрузить модель: ${error}';
			case 'settings.personaDialog.newTitle': return 'Новая персона';
			case 'settings.personaDialog.editTitle': return 'Редактировать персону';
			case 'settings.personaDialog.nameLabel': return 'Имя';
			case 'settings.personaDialog.nameRequiredError': return 'Требуется имя';
			case 'settings.personaDialog.descriptionLabel': return 'Описание';
			case 'settings.personaDialog.descriptionHint': return 'Внешность, характер, предыстория и т. д.';
			case 'settings.personasTab.cannotDeleteDefaultTooltip': return 'Нельзя удалить персону по умолчанию';
			case 'settings.personasTab.deleteTooltip': return 'Удалить персону';
			case 'settings.personasTab.cannotDeleteDefaultSnackbar': return 'Нельзя удалить персону по умолчанию.';
			case 'settings.personasTab.deleteConfirmTitle': return 'Удалить персону';
			case 'settings.personasTab.deleteConfirmMessage': return ({required Object name}) => 'Вы уверены, что хотите удалить «${name}»?';
			case 'settings.updateCheck.upToDateTitle': return 'Актуальная версия';
			case 'settings.updateCheck.upToDateMessage': return ({required Object version}) => 'У вас установлена текущая версия (${version}).';
			case 'settings.updateCheck.notApplicableTitle': return 'Проверка обновлений';
			case 'settings.updateCheck.notApplicableMessage': return 'Проверка версии недоступна в вебе.';
			case 'settings.updateCheck.errorTitle': return 'Ошибка';
			case 'settings.updateCheck.serverErrorMessage': return 'Не удалось проверить обновления. Ошибка сервера.';
			case 'settings.updateCheck.connectionErrorMessage': return 'Не удалось проверить обновления. Проверьте соединение.';
			case 'workspace.workspaceEndDrawerImage.imageStyleTitle': return 'Стиль изображения';
			case 'workspace.workspaceEndDrawerImage.noneValue': return 'Нет';
			case 'workspace.workspaceEndDrawerVideo.videoStyleTitle': return 'Стиль видео';
			case 'workspace.workspaceEndDrawerDisplay.sectionHeader': return 'Отображение';
			case 'workspace.workspaceEndDrawerDisplay.showCharacterImageTitle': return 'Показывать изображение персонажа';
			case 'workspace.workspaceEndDrawerDisplay.wideScreenOnlySubtitle': return 'Только в широкоэкранном редакторе';
			case 'workspace.workspaceEndDrawerAi.sectionHeader': return 'ИИ';
			case 'workspace.workspaceEndDrawerEditing.sectionHeader': return 'Редактирование';
			case 'workspace.workspaceEndDrawerExport.sectionHeader': return 'Экспорт';
			case 'workspace.workspaceEndDrawerExport.exportPngTitle': return 'Экспорт как PNG (V2/V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV3Title': return 'Экспорт как JSON (V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV2Title': return 'Экспорт как JSON (V2)';
			case 'workspace.workspaceEndDrawerChatTheme.resetImagesTitle': return 'Сбросить изображения';
			case 'workspace.workspaceEndDrawerChat.assistantCardEditsSectionHeader': return 'Правки карточки ассистентом';
			case 'workspace.workspaceEndDrawer.favoriteLabel': return 'Избранное';
			case 'workspace.workspaceEndDrawer.nodesEngineTitle': return 'Движок NODES';
			case 'workspace.workspaceEndDrawer.debugSnapshotSubtitle': return 'Отладочный снимок';
			case 'workspace.workspaceEndDrawer.characterSubtitle': return 'Персонаж';
			case 'workspace.stylePresetsDialog.noStyleSelectedMessage': return 'Стиль не выбран';
			case 'workspace.workspacePage.rebuildingChatIndexMessage': return 'Перестроение индекса чата...';
			case 'workspace.workspacePage.selectChatToStartMessagingMessage': return 'Выберите чат, чтобы начать переписку';
			case 'workspace.workspacePage.failedToLoadAssistantMessage': return 'Не удалось загрузить ассистента.';
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
