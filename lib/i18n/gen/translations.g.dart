/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 9
/// Strings: 2717 (301 per locale)

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
	@override late final _TranslationsAppAppBootstrapperPtBr appBootstrapper = _TranslationsAppAppBootstrapperPtBr._(_root);
}

// Path: character
class _TranslationsCharacterPtBr extends _TranslationsCharacterEn {
	_TranslationsCharacterPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsCharacterPromptPrefixDialogPtBr promptPrefixDialog = _TranslationsCharacterPromptPrefixDialogPtBr._(_root);
	@override late final _TranslationsCharacterCardEditApprovalPtBr cardEditApproval = _TranslationsCharacterCardEditApprovalPtBr._(_root);
	@override late final _TranslationsCharacterRequireApprovalTilePtBr requireApprovalTile = _TranslationsCharacterRequireApprovalTilePtBr._(_root);
	@override late final _TranslationsCharacterLoadingStatusPtBr loadingStatus = _TranslationsCharacterLoadingStatusPtBr._(_root);
	@override late final _TranslationsCharacterSavePathValidationPtBr savePathValidation = _TranslationsCharacterSavePathValidationPtBr._(_root);
	@override String get characterFilesTypeGroupLabel => 'Arquivos de personagem';
	@override late final _TranslationsCharacterCreateControllerPtBr createController = _TranslationsCharacterCreateControllerPtBr._(_root);
	@override late final _TranslationsCharacterImportControllerPtBr importController = _TranslationsCharacterImportControllerPtBr._(_root);
	@override late final _TranslationsCharacterAiActionControllerPtBr aiActionController = _TranslationsCharacterAiActionControllerPtBr._(_root);
}

// Path: chat
class _TranslationsChatPtBr extends _TranslationsChatEn {
	_TranslationsChatPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsChatTileAiProviderPtBr tileAiProvider = _TranslationsChatTileAiProviderPtBr._(_root);
	@override late final _TranslationsChatPresetTilePtBr presetTile = _TranslationsChatPresetTilePtBr._(_root);
	@override late final _TranslationsChatTileImagePresetPtBr tileImagePreset = _TranslationsChatTileImagePresetPtBr._(_root);
	@override late final _TranslationsChatTileVideoPresetPtBr tileVideoPreset = _TranslationsChatTileVideoPresetPtBr._(_root);
	@override late final _TranslationsChatTileTtsPresetPtBr tileTtsPreset = _TranslationsChatTileTtsPresetPtBr._(_root);
	@override late final _TranslationsChatTileImageAspectRatioPtBr tileImageAspectRatio = _TranslationsChatTileImageAspectRatioPtBr._(_root);
	@override late final _TranslationsChatTileVideoAspectRatioPtBr tileVideoAspectRatio = _TranslationsChatTileVideoAspectRatioPtBr._(_root);
	@override late final _TranslationsChatTileVideoResolutionPtBr tileVideoResolution = _TranslationsChatTileVideoResolutionPtBr._(_root);
	@override late final _TranslationsChatTileVideoDurationPtBr tileVideoDuration = _TranslationsChatTileVideoDurationPtBr._(_root);
	@override late final _TranslationsChatTileTtsVoicePtBr tileTtsVoice = _TranslationsChatTileTtsVoicePtBr._(_root);
	@override late final _TranslationsChatTileTtsLanguagePtBr tileTtsLanguage = _TranslationsChatTileTtsLanguagePtBr._(_root);
	@override late final _TranslationsChatTileNsfwPtBr tileNsfw = _TranslationsChatTileNsfwPtBr._(_root);
	@override late final _TranslationsChatTileScenarioPtBr tileScenario = _TranslationsChatTileScenarioPtBr._(_root);
	@override late final _TranslationsChatTileMaxResponseLengthPtBr tileMaxResponseLength = _TranslationsChatTileMaxResponseLengthPtBr._(_root);
	@override late final _TranslationsChatTileTrailingParagraphPtBr tileTrailingParagraph = _TranslationsChatTileTrailingParagraphPtBr._(_root);
	@override late final _TranslationsChatTileReasoningEffortPtBr tileReasoningEffort = _TranslationsChatTileReasoningEffortPtBr._(_root);
	@override late final _TranslationsChatTileChatThemePtBr tileChatTheme = _TranslationsChatTileChatThemePtBr._(_root);
	@override late final _TranslationsChatTileRecalledMemoryPtBr tileRecalledMemory = _TranslationsChatTileRecalledMemoryPtBr._(_root);
	@override late final _TranslationsChatCharacterSwitcherPtBr characterSwitcher = _TranslationsChatCharacterSwitcherPtBr._(_root);
	@override late final _TranslationsChatFreeImagePromptDialogPtBr freeImagePromptDialog = _TranslationsChatFreeImagePromptDialogPtBr._(_root);
	@override late final _TranslationsChatFreeVideoPromptDialogPtBr freeVideoPromptDialog = _TranslationsChatFreeVideoPromptDialogPtBr._(_root);
	@override late final _TranslationsChatImagePromptReviewDialogPtBr imagePromptReviewDialog = _TranslationsChatImagePromptReviewDialogPtBr._(_root);
	@override late final _TranslationsChatVideoPromptReviewDialogPtBr videoPromptReviewDialog = _TranslationsChatVideoPromptReviewDialogPtBr._(_root);
	@override late final _TranslationsChatUrlFetchReviewDialogPtBr urlFetchReviewDialog = _TranslationsChatUrlFetchReviewDialogPtBr._(_root);
	@override late final _TranslationsChatMessageActionsRowPtBr messageActionsRow = _TranslationsChatMessageActionsRowPtBr._(_root);
	@override late final _TranslationsChatTtsPlayButtonPtBr ttsPlayButton = _TranslationsChatTtsPlayButtonPtBr._(_root);
	@override late final _TranslationsChatMessageSwipeFlipperPtBr messageSwipeFlipper = _TranslationsChatMessageSwipeFlipperPtBr._(_root);
	@override late final _TranslationsChatVideoPlayerInlinePtBr videoPlayerInline = _TranslationsChatVideoPlayerInlinePtBr._(_root);
	@override String get newChatLabel => 'Nova conversa';
	@override late final _TranslationsChatChatListItemPtBr chatListItem = _TranslationsChatChatListItemPtBr._(_root);
	@override late final _TranslationsChatChatHistoryControllerPtBr chatHistoryController = _TranslationsChatChatHistoryControllerPtBr._(_root);
	@override late final _TranslationsChatChatPageControllerPtBr chatPageController = _TranslationsChatChatPageControllerPtBr._(_root);
	@override late final _TranslationsChatImageGenerationMixinPtBr imageGenerationMixin = _TranslationsChatImageGenerationMixinPtBr._(_root);
	@override late final _TranslationsChatVideoGenerationMixinPtBr videoGenerationMixin = _TranslationsChatVideoGenerationMixinPtBr._(_root);
	@override late final _TranslationsChatBubbleWaitingForPtBr bubbleWaitingFor = _TranslationsChatBubbleWaitingForPtBr._(_root);
	@override late final _TranslationsChatAppBarChatPtBr appBarChat = _TranslationsChatAppBarChatPtBr._(_root);
	@override late final _TranslationsChatAllChatsDrawerListPtBr allChatsDrawerList = _TranslationsChatAllChatsDrawerListPtBr._(_root);
	@override late final _TranslationsChatChatInputMediaMenuPtBr chatInputMediaMenu = _TranslationsChatChatInputMediaMenuPtBr._(_root);
	@override late final _TranslationsChatChatViewPtBr chatView = _TranslationsChatChatViewPtBr._(_root);
	@override late final _TranslationsChatChatMessageBubblePtBr chatMessageBubble = _TranslationsChatChatMessageBubblePtBr._(_root);
}

// Path: common
class _TranslationsCommonPtBr extends _TranslationsCommonEn {
	_TranslationsCommonPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsCommonActionsPtBr actions = _TranslationsCommonActionsPtBr._(_root);
	@override late final _TranslationsCommonAiActionPtBr aiAction = _TranslationsCommonAiActionPtBr._(_root);
	@override String get aiActionsTooltip => 'Ações de IA';
	@override late final _TranslationsCommonPromptSegmentKindPtBr promptSegmentKind = _TranslationsCommonPromptSegmentKindPtBr._(_root);
	@override late final _TranslationsCommonPromptBreakdownPtBr promptBreakdown = _TranslationsCommonPromptBreakdownPtBr._(_root);
	@override late final _TranslationsCommonLogsPtBr logs = _TranslationsCommonLogsPtBr._(_root);
	@override late final _TranslationsCommonImportErrorsDialogPtBr importErrorsDialog = _TranslationsCommonImportErrorsDialogPtBr._(_root);
	@override late final _TranslationsCommonUpdateDialogPtBr updateDialog = _TranslationsCommonUpdateDialogPtBr._(_root);
	@override late final _TranslationsCommonImportConflictsDialogPtBr importConflictsDialog = _TranslationsCommonImportConflictsDialogPtBr._(_root);
	@override late final _TranslationsCommonMissingProviderBannerPtBr missingProviderBanner = _TranslationsCommonMissingProviderBannerPtBr._(_root);
	@override late final _TranslationsCommonModelSelectionDialogPtBr modelSelectionDialog = _TranslationsCommonModelSelectionDialogPtBr._(_root);
	@override late final _TranslationsCommonShowAdvancedPtBr showAdvanced = _TranslationsCommonShowAdvancedPtBr._(_root);
	@override late final _TranslationsCommonMessageEditDialogPtBr messageEditDialog = _TranslationsCommonMessageEditDialogPtBr._(_root);
	@override late final _TranslationsCommonPromptBreakdownDialogPtBr promptBreakdownDialog = _TranslationsCommonPromptBreakdownDialogPtBr._(_root);
	@override late final _TranslationsCommonJsonPromptDialogPtBr jsonPromptDialog = _TranslationsCommonJsonPromptDialogPtBr._(_root);
	@override late final _TranslationsCommonProgressDialogPtBr progressDialog = _TranslationsCommonProgressDialogPtBr._(_root);
	@override late final _TranslationsCommonDiffPanelPtBr diffPanel = _TranslationsCommonDiffPanelPtBr._(_root);
	@override late final _TranslationsCommonSelectionDialogPtBr selectionDialog = _TranslationsCommonSelectionDialogPtBr._(_root);
	@override late final _TranslationsCommonZdrSwitchPtBr zdrSwitch = _TranslationsCommonZdrSwitchPtBr._(_root);
	@override late final _TranslationsCommonTextFieldCardPtBr textFieldCard = _TranslationsCommonTextFieldCardPtBr._(_root);
	@override late final _TranslationsCommonModelCapabilityPtBr modelCapability = _TranslationsCommonModelCapabilityPtBr._(_root);
	@override String get modelUnavailableTooltip => 'Este modelo não está mais disponível no provedor — escolha outro.';
	@override String get characterImageSemanticLabel => 'Imagem do personagem';
	@override late final _TranslationsCommonAppConstantsPtBr appConstants = _TranslationsCommonAppConstantsPtBr._(_root);
	@override late final _TranslationsCommonTimeAgoPtBr timeAgo = _TranslationsCommonTimeAgoPtBr._(_root);
}

// Path: editor
class _TranslationsEditorPtBr extends _TranslationsEditorEn {
	_TranslationsEditorPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsEditorPanelLabelsPtBr panelLabels = _TranslationsEditorPanelLabelsPtBr._(_root);
	@override late final _TranslationsEditorAppBarEditorPtBr appBarEditor = _TranslationsEditorAppBarEditorPtBr._(_root);
	@override late final _TranslationsEditorCodeFindPanelPtBr codeFindPanel = _TranslationsEditorCodeFindPanelPtBr._(_root);
	@override late final _TranslationsEditorFindReplaceDialogPtBr findReplaceDialog = _TranslationsEditorFindReplaceDialogPtBr._(_root);
	@override late final _TranslationsEditorObjectValueEditorPtBr objectValueEditor = _TranslationsEditorObjectValueEditorPtBr._(_root);
	@override late final _TranslationsEditorEditorBasicPtBr editorBasic = _TranslationsEditorEditorBasicPtBr._(_root);
	@override late final _TranslationsEditorEditorCreatorMetadataPtBr editorCreatorMetadata = _TranslationsEditorEditorCreatorMetadataPtBr._(_root);
	@override late final _TranslationsEditorEditorPromptsPtBr editorPrompts = _TranslationsEditorEditorPromptsPtBr._(_root);
	@override late final _TranslationsEditorEditorAppDataPtBr editorAppData = _TranslationsEditorEditorAppDataPtBr._(_root);
	@override late final _TranslationsEditorEditorAlternateGreetingsPtBr editorAlternateGreetings = _TranslationsEditorEditorAlternateGreetingsPtBr._(_root);
	@override late final _TranslationsEditorEditorGroupGreetingsPtBr editorGroupGreetings = _TranslationsEditorEditorGroupGreetingsPtBr._(_root);
	@override late final _TranslationsEditorEditorLorebookPtBr editorLorebook = _TranslationsEditorEditorLorebookPtBr._(_root);
	@override late final _TranslationsEditorLorebookEntryListTilePtBr lorebookEntryListTile = _TranslationsEditorLorebookEntryListTilePtBr._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorPagePtBr lorebookEntryEditorPage = _TranslationsEditorLorebookEntryEditorPagePtBr._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorTopSectionPtBr lorebookEntryEditorTopSection = _TranslationsEditorLorebookEntryEditorTopSectionPtBr._(_root);
	@override late final _TranslationsEditorLorebookEntryEditorScanRowPtBr lorebookEntryEditorScanRow = _TranslationsEditorLorebookEntryEditorScanRowPtBr._(_root);
	@override late final _TranslationsEditorDialogContentCleanerPtBr dialogContentCleaner = _TranslationsEditorDialogContentCleanerPtBr._(_root);
	@override late final _TranslationsEditorDialogAiDiffConfirmationPtBr dialogAiDiffConfirmation = _TranslationsEditorDialogAiDiffConfirmationPtBr._(_root);
	@override late final _TranslationsEditorEditorPageControllerPtBr editorPageController = _TranslationsEditorEditorPageControllerPtBr._(_root);
	@override late final _TranslationsEditorEditorNodesPtBr editorNodes = _TranslationsEditorEditorNodesPtBr._(_root);
	@override late final _TranslationsEditorNodeListTilePtBr nodeListTile = _TranslationsEditorNodeListTilePtBr._(_root);
	@override late final _TranslationsEditorNodesRawEditorPagePtBr nodesRawEditorPage = _TranslationsEditorNodesRawEditorPagePtBr._(_root);
	@override late final _TranslationsEditorNodesCanvasViewPtBr nodesCanvasView = _TranslationsEditorNodesCanvasViewPtBr._(_root);
	@override late final _TranslationsEditorNodeEditorFormPtBr nodeEditorForm = _TranslationsEditorNodeEditorFormPtBr._(_root);
}

// Path: grid
class _TranslationsGridPtBr extends _TranslationsGridEn {
	_TranslationsGridPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsGridEmptyStatePtBr emptyState = _TranslationsGridEmptyStatePtBr._(_root);
	@override late final _TranslationsGridAppBarPtBr appBar = _TranslationsGridAppBarPtBr._(_root);
	@override late final _TranslationsGridFabPtBr fab = _TranslationsGridFabPtBr._(_root);
	@override late final _TranslationsGridDrawerPtBr drawer = _TranslationsGridDrawerPtBr._(_root);
	@override late final _TranslationsGridVariantBadgePtBr variantBadge = _TranslationsGridVariantBadgePtBr._(_root);
	@override late final _TranslationsGridDialogActionsPtBr dialogActions = _TranslationsGridDialogActionsPtBr._(_root);
	@override late final _TranslationsGridTagFilterDialogPtBr tagFilterDialog = _TranslationsGridTagFilterDialogPtBr._(_root);
	@override late final _TranslationsGridFiltersPtBr filters = _TranslationsGridFiltersPtBr._(_root);
	@override late final _TranslationsGridSortOptionPtBr sortOption = _TranslationsGridSortOptionPtBr._(_root);
	@override late final _TranslationsGridFilterControllerPtBr filterController = _TranslationsGridFilterControllerPtBr._(_root);
	@override late final _TranslationsGridMultiSelectDialogPtBr multiSelectDialog = _TranslationsGridMultiSelectDialogPtBr._(_root);
	@override late final _TranslationsGridCreateCharacterDialogPtBr createCharacterDialog = _TranslationsGridCreateCharacterDialogPtBr._(_root);
	@override late final _TranslationsGridVariantsSheetPtBr variantsSheet = _TranslationsGridVariantsSheetPtBr._(_root);
	@override late final _TranslationsGridGroupAppBarPtBr groupAppBar = _TranslationsGridGroupAppBarPtBr._(_root);
	@override late final _TranslationsGridThumbnailBadgesPtBr thumbnailBadges = _TranslationsGridThumbnailBadgesPtBr._(_root);
	@override late final _TranslationsGridActionMenuPtBr actionMenu = _TranslationsGridActionMenuPtBr._(_root);
	@override late final _TranslationsGridControllerMessagesPtBr controllerMessages = _TranslationsGridControllerMessagesPtBr._(_root);
	@override late final _TranslationsGridTagWrapPtBr tagWrap = _TranslationsGridTagWrapPtBr._(_root);
}

// Path: group
class _TranslationsGroupPtBr extends _TranslationsGroupEn {
	_TranslationsGroupPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsGroupGroupGridControllerPtBr groupGridController = _TranslationsGroupGroupGridControllerPtBr._(_root);
	@override late final _TranslationsGroupGroupChatPagePtBr groupChatPage = _TranslationsGroupGroupChatPagePtBr._(_root);
	@override late final _TranslationsGroupGroupGridPagePtBr groupGridPage = _TranslationsGroupGroupGridPagePtBr._(_root);
	@override late final _TranslationsGroupTileAutoChatDelayPtBr tileAutoChatDelay = _TranslationsGroupTileAutoChatDelayPtBr._(_root);
	@override late final _TranslationsGroupTileActivationStrategyPtBr tileActivationStrategy = _TranslationsGroupTileActivationStrategyPtBr._(_root);
	@override late final _TranslationsGroupGroupChatPageEndDrawerPtBr groupChatPageEndDrawer = _TranslationsGroupGroupChatPageEndDrawerPtBr._(_root);
	@override late final _TranslationsGroupGroupCharacterPickerPtBr groupCharacterPicker = _TranslationsGroupGroupCharacterPickerPtBr._(_root);
	@override late final _TranslationsGroupGroupCharacterTilePtBr groupCharacterTile = _TranslationsGroupGroupCharacterTilePtBr._(_root);
	@override late final _TranslationsGroupDialogCreateGroupPtBr dialogCreateGroup = _TranslationsGroupDialogCreateGroupPtBr._(_root);
	@override late final _TranslationsGroupDialogGroupOverridesPtBr dialogGroupOverrides = _TranslationsGroupDialogGroupOverridesPtBr._(_root);
	@override late final _TranslationsGroupGroupCharacterPanelPtBr groupCharacterPanel = _TranslationsGroupGroupCharacterPanelPtBr._(_root);
	@override late final _TranslationsGroupDialogSelectGroupPtBr dialogSelectGroup = _TranslationsGroupDialogSelectGroupPtBr._(_root);
	@override late final _TranslationsGroupGroupGridItemPtBr groupGridItem = _TranslationsGroupGroupGridItemPtBr._(_root);
	@override late final _TranslationsGroupGroupFileServicePtBr groupFileService = _TranslationsGroupGroupFileServicePtBr._(_root);
}

// Path: llmApp
class _TranslationsLlmAppPtBr extends _TranslationsLlmAppEn {
	_TranslationsLlmAppPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLlmAppMediaFieldPtBr mediaField = _TranslationsLlmAppMediaFieldPtBr._(_root);
	@override late final _TranslationsLlmAppMediaSectionPtBr mediaSection = _TranslationsLlmAppMediaSectionPtBr._(_root);
	@override late final _TranslationsLlmAppTristatePtBr tristate = _TranslationsLlmAppTristatePtBr._(_root);
	@override late final _TranslationsLlmAppMediaCellMenuPtBr mediaCellMenu = _TranslationsLlmAppMediaCellMenuPtBr._(_root);
	@override late final _TranslationsLlmAppMediaHeaderPtBr mediaHeader = _TranslationsLlmAppMediaHeaderPtBr._(_root);
	@override late final _TranslationsLlmAppPresetRowPtBr presetRow = _TranslationsLlmAppPresetRowPtBr._(_root);
	@override late final _TranslationsLlmAppMediaCellPtBr mediaCell = _TranslationsLlmAppMediaCellPtBr._(_root);
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
	@override String get finishFailedSnackbar => 'Falha na configuração. Veja os logs para detalhes.';
	@override String get appBarTitle => 'Configuração rápida';
	@override String get webWarning => 'Build web experimental — o armazenamento do navegador pode ser redefinido entre atualizações. Use desktop ou Android para dados persistentes.';
	@override String get finishButton => 'Concluir configuração';
	@override String get nextButton => 'Avançar';
	@override String get backButton => 'Voltar';
	@override late final _TranslationsOnboardingStorageStepPtBr storageStep = _TranslationsOnboardingStorageStepPtBr._(_root);
	@override late final _TranslationsOnboardingSetupStepPtBr setupStep = _TranslationsOnboardingSetupStepPtBr._(_root);
	@override late final _TranslationsOnboardingAiSectionPtBr aiSection = _TranslationsOnboardingAiSectionPtBr._(_root);
	@override late final _TranslationsOnboardingAiStatusPtBr aiStatus = _TranslationsOnboardingAiStatusPtBr._(_root);
	@override late final _TranslationsOnboardingPersonaSectionPtBr personaSection = _TranslationsOnboardingPersonaSectionPtBr._(_root);
	@override late final _TranslationsOnboardingDisclaimerPtBr disclaimer = _TranslationsOnboardingDisclaimerPtBr._(_root);
	@override late final _TranslationsOnboardingFetchErrorPtBr fetchError = _TranslationsOnboardingFetchErrorPtBr._(_root);
}

// Path: routing
class _TranslationsRoutingPtBr extends _TranslationsRoutingEn {
	_TranslationsRoutingPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsRoutingChatCharacterPtBr chatCharacter = _TranslationsRoutingChatCharacterPtBr._(_root);
	@override late final _TranslationsRoutingEditCharacterPtBr editCharacter = _TranslationsRoutingEditCharacterPtBr._(_root);
	@override late final _TranslationsRoutingEditPresetPtBr editPreset = _TranslationsRoutingEditPresetPtBr._(_root);
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
	@override String get gearLanguage => 'Idioma';
	@override String get languageSystemDefault => 'Padrão do sistema';
	@override late final _TranslationsSettingsGearMenuPtBr gearMenu = _TranslationsSettingsGearMenuPtBr._(_root);
	@override late final _TranslationsSettingsMediaDefaultsDrawerEntryPtBr mediaDefaultsDrawerEntry = _TranslationsSettingsMediaDefaultsDrawerEntryPtBr._(_root);
	@override late final _TranslationsSettingsEndDrawerPtBr endDrawer = _TranslationsSettingsEndDrawerPtBr._(_root);
	@override late final _TranslationsSettingsLoadingStatusPtBr loadingStatus = _TranslationsSettingsLoadingStatusPtBr._(_root);
	@override late final _TranslationsSettingsGeneralPtBr general = _TranslationsSettingsGeneralPtBr._(_root);
	@override late final _TranslationsSettingsAiSettingsTabPtBr aiSettingsTab = _TranslationsSettingsAiSettingsTabPtBr._(_root);
	@override late final _TranslationsSettingsAiTabPtBr aiTab = _TranslationsSettingsAiTabPtBr._(_root);
	@override late final _TranslationsSettingsPresetConfigPtBr presetConfig = _TranslationsSettingsPresetConfigPtBr._(_root);
	@override late final _TranslationsSettingsProviderConfigPtBr providerConfig = _TranslationsSettingsProviderConfigPtBr._(_root);
	@override late final _TranslationsSettingsLocalProviderConfigPtBr localProviderConfig = _TranslationsSettingsLocalProviderConfigPtBr._(_root);
	@override late final _TranslationsSettingsLocalGgufPtBr localGguf = _TranslationsSettingsLocalGgufPtBr._(_root);
	@override late final _TranslationsSettingsPersonaDialogPtBr personaDialog = _TranslationsSettingsPersonaDialogPtBr._(_root);
	@override late final _TranslationsSettingsPersonasTabPtBr personasTab = _TranslationsSettingsPersonasTabPtBr._(_root);
	@override late final _TranslationsSettingsUpdateCheckPtBr updateCheck = _TranslationsSettingsUpdateCheckPtBr._(_root);
}

// Path: workspace
class _TranslationsWorkspacePtBr extends _TranslationsWorkspaceEn {
	_TranslationsWorkspacePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerImagePtBr workspaceEndDrawerImage = _TranslationsWorkspaceWorkspaceEndDrawerImagePtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerVideoPtBr workspaceEndDrawerVideo = _TranslationsWorkspaceWorkspaceEndDrawerVideoPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerDisplayPtBr workspaceEndDrawerDisplay = _TranslationsWorkspaceWorkspaceEndDrawerDisplayPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerAiPtBr workspaceEndDrawerAi = _TranslationsWorkspaceWorkspaceEndDrawerAiPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerEditingPtBr workspaceEndDrawerEditing = _TranslationsWorkspaceWorkspaceEndDrawerEditingPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerExportPtBr workspaceEndDrawerExport = _TranslationsWorkspaceWorkspaceEndDrawerExportPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerChatThemePtBr workspaceEndDrawerChatTheme = _TranslationsWorkspaceWorkspaceEndDrawerChatThemePtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerChatPtBr workspaceEndDrawerChat = _TranslationsWorkspaceWorkspaceEndDrawerChatPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspaceEndDrawerPtBr workspaceEndDrawer = _TranslationsWorkspaceWorkspaceEndDrawerPtBr._(_root);
	@override late final _TranslationsWorkspaceStylePresetsDialogPtBr stylePresetsDialog = _TranslationsWorkspaceStylePresetsDialogPtBr._(_root);
	@override late final _TranslationsWorkspaceWorkspacePagePtBr workspacePage = _TranslationsWorkspaceWorkspacePagePtBr._(_root);
}

// Path: app.appBootstrapper
class _TranslationsAppAppBootstrapperPtBr extends _TranslationsAppAppBootstrapperEn {
	_TranslationsAppAppBootstrapperPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String failedToInitializeMessage({required Object error}) => 'Falha ao inicializar o app:\n\n${error}';
}

// Path: character.promptPrefixDialog
class _TranslationsCharacterPromptPrefixDialogPtBr extends _TranslationsCharacterPromptPrefixDialogEn {
	_TranslationsCharacterPromptPrefixDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get styleKeywordsLabel => 'Palavras-chave de estilo';
	@override String get imageTitle => 'Estilo de imagem';
	@override String get imageDescription => 'Adicionado no início de cada prompt de geração de imagem deste personagem (ex.: "estilo anime, cores vibrantes").';
	@override String get imageHint => 'estilo anime, cores vibrantes';
	@override String get videoTitle => 'Estilo de vídeo';
	@override String get videoDescription => 'Adicionado no início de cada prompt de geração de vídeo deste personagem (ex.: "cinematográfico, profundidade de campo rasa, granulação de filme 24fps"). Modelos de vídeo respondem a vocabulário de movimento e câmera; mantenha curto.';
	@override String get videoHint => 'cinematográfico, profundidade de campo rasa';
}

// Path: character.cardEditApproval
class _TranslationsCharacterCardEditApprovalPtBr extends _TranslationsCharacterCardEditApprovalEn {
	_TranslationsCharacterCardEditApprovalPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get denyAll => 'Recusar tudo';
	@override String get approveAll => 'Aprovar tudo';
	@override String get confirm => 'Confirmar';
	@override String get dialogTitle => 'O assistente propôs alterações';
	@override String dontAskAgainFor({required Object modality}) => 'Não perguntar de novo para ${modality}';
	@override late final _TranslationsCharacterCardEditApprovalModalityLabelPtBr modalityLabel = _TranslationsCharacterCardEditApprovalModalityLabelPtBr._(_root);
	@override late final _TranslationsCharacterCardEditApprovalModalityVerbPtBr modalityVerb = _TranslationsCharacterCardEditApprovalModalityVerbPtBr._(_root);
	@override String get tapToDeny => 'Toque para recusar';
	@override String get tapToApprove => 'Toque para aprovar';
	@override String get reasonLabel => 'Motivo (opcional, enviado de volta ao assistente)';
	@override String get newEntryTitle => 'Nova entrada';
	@override String get removingTitle => 'Removendo';
	@override String get beforeTitle => 'Antes';
	@override String get afterTitle => 'Depois';
}

// Path: character.requireApprovalTile
class _TranslationsCharacterRequireApprovalTilePtBr extends _TranslationsCharacterRequireApprovalTileEn {
	_TranslationsCharacterRequireApprovalTilePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get edits => 'Exigir aprovação: edições';
	@override String get additions => 'Exigir aprovação: adições';
	@override String get deletions => 'Exigir aprovação: exclusões';
}

// Path: character.loadingStatus
class _TranslationsCharacterLoadingStatusPtBr extends _TranslationsCharacterLoadingStatusEn {
	_TranslationsCharacterLoadingStatusPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get initial => 'Carregando...';
	@override String get copyingAssistant => 'Copiando assistente...';
	@override String get scanningForCharacters => 'Procurando personagens...';
	@override String scanningForCharactersProgress({required Object current, required Object total}) => 'Procurando personagens...\n${current} / ${total}';
	@override String loadingCharactersProgress({required Object current, required Object total}) => 'Carregando personagens...\n${current} / ${total}';
}

// Path: character.savePathValidation
class _TranslationsCharacterSavePathValidationPtBr extends _TranslationsCharacterSavePathValidationEn {
	_TranslationsCharacterSavePathValidationPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noLibraryFolder => 'Nenhuma pasta de biblioteca configurada.';
	@override String get mustBeInsideLibrary => 'Os personagens devem ser salvos dentro da sua pasta de biblioteca.';
}

// Path: character.createController
class _TranslationsCharacterCreateControllerPtBr extends _TranslationsCharacterCreateControllerEn {
	_TranslationsCharacterCreateControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get pngImagesTypeGroupLabel => 'Imagens PNG';
	@override String get invalidLocationTitle => 'Local inválido';
	@override String get creationFailedTitle => 'Falha na criação';
	@override String get creationFailedMessage => 'Não foi possível criar o personagem. Veja os logs para detalhes.';
}

// Path: character.importController
class _TranslationsCharacterImportControllerPtBr extends _TranslationsCharacterImportControllerEn {
	_TranslationsCharacterImportControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String failedToImport({required Object fileName}) => 'Falha ao importar ${fileName}.';
	@override String importedCount({required Object count}) => '${count} personagens importados';
}

// Path: character.aiActionController
class _TranslationsCharacterAiActionControllerPtBr extends _TranslationsCharacterAiActionControllerEn {
	_TranslationsCharacterAiActionControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get aiActionFailed => 'Ação de IA falhou. Veja os logs para detalhes.';
	@override String processingProgress({required Object name, required Object current, required Object total, required Object eta}) => 'Processando ${name} (${current}/${total})...${eta}';
	@override String etaHoursMinutes({required Object hours, required Object minutes}) => ' Restante: ${hours}h ${minutes}m';
	@override String etaMinutesSeconds({required Object minutes, required Object seconds}) => ' Restante: ${minutes}m ${seconds}s';
	@override String etaSeconds({required Object seconds}) => ' Restante: ${seconds}s';
	@override String processingField({required Object fieldName}) => 'Processando ${fieldName}...';
}

// Path: chat.tileAiProvider
class _TranslationsChatTileAiProviderPtBr extends _TranslationsChatTileAiProviderEn {
	_TranslationsChatTileAiProviderPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get modelLabel => 'Modelo';
	@override String get invalidLabel => 'Inválido';
	@override String get chooseModelTitle => 'Escolha um modelo';
}

// Path: chat.presetTile
class _TranslationsChatPresetTilePtBr extends _TranslationsChatPresetTileEn {
	_TranslationsChatPresetTilePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get tapToChoose => 'Toque para escolher';
}

// Path: chat.tileImagePreset
class _TranslationsChatTileImagePresetPtBr extends _TranslationsChatTileImagePresetEn {
	_TranslationsChatTileImagePresetPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Modelo de imagem';
	@override String get chooseModelTitle => 'Escolha um modelo de imagem';
}

// Path: chat.tileVideoPreset
class _TranslationsChatTileVideoPresetPtBr extends _TranslationsChatTileVideoPresetEn {
	_TranslationsChatTileVideoPresetPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Modelo de vídeo';
	@override String get chooseModelTitle => 'Escolha um modelo de vídeo';
}

// Path: chat.tileTtsPreset
class _TranslationsChatTileTtsPresetPtBr extends _TranslationsChatTileTtsPresetEn {
	_TranslationsChatTileTtsPresetPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get titleLabel => 'Modelo de fala';
	@override String get chooseModelTitle => 'Escolha um modelo de fala';
}

// Path: chat.tileImageAspectRatio
class _TranslationsChatTileImageAspectRatioPtBr extends _TranslationsChatTileImageAspectRatioEn {
	_TranslationsChatTileImageAspectRatioPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Proporção da imagem';
}

// Path: chat.tileVideoAspectRatio
class _TranslationsChatTileVideoAspectRatioPtBr extends _TranslationsChatTileVideoAspectRatioEn {
	_TranslationsChatTileVideoAspectRatioPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Proporção';
}

// Path: chat.tileVideoResolution
class _TranslationsChatTileVideoResolutionPtBr extends _TranslationsChatTileVideoResolutionEn {
	_TranslationsChatTileVideoResolutionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Resolução';
}

// Path: chat.tileVideoDuration
class _TranslationsChatTileVideoDurationPtBr extends _TranslationsChatTileVideoDurationEn {
	_TranslationsChatTileVideoDurationPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Duração';
}

// Path: chat.tileTtsVoice
class _TranslationsChatTileTtsVoicePtBr extends _TranslationsChatTileTtsVoiceEn {
	_TranslationsChatTileTtsVoicePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Voz';
}

// Path: chat.tileTtsLanguage
class _TranslationsChatTileTtsLanguagePtBr extends _TranslationsChatTileTtsLanguageEn {
	_TranslationsChatTileTtsLanguagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Idioma';
}

// Path: chat.tileNsfw
class _TranslationsChatTileNsfwPtBr extends _TranslationsChatTileNsfwEn {
	_TranslationsChatTileNsfwPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'NSFW / Ilimitado';
}

// Path: chat.tileScenario
class _TranslationsChatTileScenarioPtBr extends _TranslationsChatTileScenarioEn {
	_TranslationsChatTileScenarioPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Cenário';
}

// Path: chat.tileMaxResponseLength
class _TranslationsChatTileMaxResponseLengthPtBr extends _TranslationsChatTileMaxResponseLengthEn {
	_TranslationsChatTileMaxResponseLengthPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String titleWithBucket({required Object bucket}) => 'Tamanho da resposta — ${bucket}';
	@override String sliderLabel({required Object bucket, required Object tokens}) => '${bucket} (${tokens} tokens)';
	@override String get bucketVeryShort => 'Muito curto';
	@override String get bucketShort => 'Curto';
	@override String get bucketMedium => 'Médio';
	@override String get bucketLong => 'Longo';
	@override String get bucketVeryLong => 'Muito longo';
}

// Path: chat.tileTrailingParagraph
class _TranslationsChatTileTrailingParagraphPtBr extends _TranslationsChatTileTrailingParagraphEn {
	_TranslationsChatTileTrailingParagraphPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Cortar texto final';
}

// Path: chat.tileReasoningEffort
class _TranslationsChatTileReasoningEffortPtBr extends _TranslationsChatTileReasoningEffortEn {
	_TranslationsChatTileReasoningEffortPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String titleWithEffort({required Object effort}) => 'Raciocínio — ${effort}';
	@override String get titleOff => 'Raciocínio desligado';
	@override String get extraTokensCaption => 'Usa tokens extras além do tamanho máximo da resposta.';
}

// Path: chat.tileChatTheme
class _TranslationsChatTileChatThemePtBr extends _TranslationsChatTileChatThemeEn {
	_TranslationsChatTileChatThemePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Tema';
}

// Path: chat.tileRecalledMemory
class _TranslationsChatTileRecalledMemoryPtBr extends _TranslationsChatTileRecalledMemoryEn {
	_TranslationsChatTileRecalledMemoryPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get label => 'Mostrar memória recuperada';
}

// Path: chat.characterSwitcher
class _TranslationsChatCharacterSwitcherPtBr extends _TranslationsChatCharacterSwitcherEn {
	_TranslationsChatCharacterSwitcherPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get favoritesTooltip => 'Favoritos';
	@override String get recentChatsTooltip => 'Conversas recentes';
	@override String get originalBadge => 'ORIGINAL';
	@override String get variantBadge => 'VARIANTE';
	@override String lastActive({required Object timeAgo}) => 'Última atividade: ${timeAgo}';
	@override String get never => 'Nunca';
}

// Path: chat.freeImagePromptDialog
class _TranslationsChatFreeImagePromptDialogPtBr extends _TranslationsChatFreeImagePromptDialogEn {
	_TranslationsChatFreeImagePromptDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gerar imagem';
	@override String get description => 'Descreva o que você quer ver. Uma frase curta já basta — o modelo a expandirá em uma lista completa de tags.';
	@override String get subjectLabel => 'Tema';
	@override String get subjectHint => 'beco cyberpunk, chuva de neon';
	@override String get generateButton => 'Gerar';
}

// Path: chat.freeVideoPromptDialog
class _TranslationsChatFreeVideoPromptDialogPtBr extends _TranslationsChatFreeVideoPromptDialogEn {
	_TranslationsChatFreeVideoPromptDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gerar vídeo';
	@override String get description => 'Descreva um breve momento de movimento — o que se move, como, onde. O modelo do sistema o expandirá em um prompt cinematográfico T2V.';
	@override String get subjectLabel => 'Tema';
	@override String get subjectHint => 'ela caminha sob a chuva de neon, câmera lenta';
	@override String get generateButton => 'Gerar';
}

// Path: chat.imagePromptReviewDialog
class _TranslationsChatImagePromptReviewDialogPtBr extends _TranslationsChatImagePromptReviewDialogEn {
	_TranslationsChatImagePromptReviewDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Revisar prompt de imagem';
	@override String get description => 'Edite o prompt abaixo antes de gerar, ou toque em Gerar para usá-lo como está.';
	@override String get fieldLabel => 'Prompt de imagem';
	@override String get generateButton => 'Gerar';
}

// Path: chat.videoPromptReviewDialog
class _TranslationsChatVideoPromptReviewDialogPtBr extends _TranslationsChatVideoPromptReviewDialogEn {
	_TranslationsChatVideoPromptReviewDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Revisar prompt de vídeo';
	@override String get description => 'Edite o prompt abaixo antes de enviar, ou toque em Gerar para usá-lo como está.';
	@override String get fieldLabel => 'Prompt de vídeo';
	@override String get generateButton => 'Gerar';
}

// Path: chat.urlFetchReviewDialog
class _TranslationsChatUrlFetchReviewDialogPtBr extends _TranslationsChatUrlFetchReviewDialogEn {
	_TranslationsChatUrlFetchReviewDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Permitir busca na web?';
	@override String get description => 'O personagem quer ler o conteúdo deste URL.';
	@override String get purposeLabel => 'Finalidade:';
	@override String get denyButton => 'Recusar';
	@override String get allowButton => 'Permitir';
}

// Path: chat.messageActionsRow
class _TranslationsChatMessageActionsRowPtBr extends _TranslationsChatMessageActionsRowEn {
	_TranslationsChatMessageActionsRowPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String tokenCountAbbrev({required Object count}) => '${count}t';
	@override String generationTimeAbbrev({required Object seconds}) => '${seconds}s';
	@override String get viewGenerationPromptTooltip => 'Ver prompt de geração';
	@override String get messageActionsTooltip => 'Ações da mensagem';
	@override String get editAction => 'Editar';
	@override String get copyAction => 'Copiar';
	@override String get shareImageAction => 'Compartilhar imagem';
	@override String get setAsBackgroundAction => 'Definir como plano de fundo';
	@override String get setAsCharacterImageAction => 'Definir como imagem do personagem';
	@override String get deleteAction => 'Excluir';
	@override String get copiedToClipboard => 'Mensagem copiada para a área de transferência';
}

// Path: chat.ttsPlayButton
class _TranslationsChatTtsPlayButtonPtBr extends _TranslationsChatTtsPlayButtonEn {
	_TranslationsChatTtsPlayButtonPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get stopTooltip => 'Parar';
	@override String get readAloudTooltip => 'Ler em voz alta';
	@override String get ttsFailed => 'TTS falhou.';
}

// Path: chat.messageSwipeFlipper
class _TranslationsChatMessageSwipeFlipperPtBr extends _TranslationsChatMessageSwipeFlipperEn {
	_TranslationsChatMessageSwipeFlipperPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get previousVersionTooltip => 'Versão anterior';
	@override String swipeCounter({required Object current, required Object total}) => '${current} / ${total}';
	@override String get regenerateTooltip => 'Regenerar';
	@override String get nextVersionTooltip => 'Próxima versão';
}

// Path: chat.videoPlayerInline
class _TranslationsChatVideoPlayerInlinePtBr extends _TranslationsChatVideoPlayerInlineEn {
	_TranslationsChatVideoPlayerInlinePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get webUnsupported => 'Reprodução de vídeo não suportada na web.';
	@override String get couldNotLoad => 'Não foi possível carregar o vídeo.';
}

// Path: chat.chatListItem
class _TranslationsChatChatListItemPtBr extends _TranslationsChatChatListItemEn {
	_TranslationsChatChatListItemPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String messageCount({required Object count}) => '${count} mensagens';
	@override String get renameAction => 'Renomear';
	@override String get deleteChatAction => 'Excluir conversa';
}

// Path: chat.chatHistoryController
class _TranslationsChatChatHistoryControllerPtBr extends _TranslationsChatChatHistoryControllerEn {
	_TranslationsChatChatHistoryControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get renameChatTitle => 'Renomear conversa';
	@override String get chatNameHint => 'Nome da conversa';
	@override String get renameButton => 'Renomear';
	@override String get deleteChatTitle => 'Excluir conversa';
	@override String get deleteChatMessage => 'Tem certeza de que deseja excluir este histórico de conversa? Esta ação não pode ser desfeita.';
}

// Path: chat.chatPageController
class _TranslationsChatChatPageControllerPtBr extends _TranslationsChatChatPageControllerEn {
	_TranslationsChatChatPageControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get clearAssistantHistoryMessage => 'Limpar o histórico de conversa com o assistente?';
	@override String get clearButton => 'Limpar';
	@override String get deleteOrKeepMessage => 'Deseja excluir a conversa atual ou mantê-la no seu histórico?';
	@override String get deleteCurrentButton => 'Excluir atual';
	@override String get keepCurrentButton => 'Manter atual';
}

// Path: chat.imageGenerationMixin
class _TranslationsChatImageGenerationMixinPtBr extends _TranslationsChatImageGenerationMixinEn {
	_TranslationsChatImageGenerationMixinPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get enterPromptMessage => 'Digite um prompt para gerar uma imagem.';
	@override String get noCharacterMessage => 'Nenhum personagem disponível para geração de imagem.';
	@override String get notConfiguredMessage => 'A geração de imagem não está configurada.';
	@override String get noSystemModelMessage => 'Nenhum modelo do sistema configurado. Defina um em Configurações → IA.';
}

// Path: chat.videoGenerationMixin
class _TranslationsChatVideoGenerationMixinPtBr extends _TranslationsChatVideoGenerationMixinEn {
	_TranslationsChatVideoGenerationMixinPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get enterPromptMessage => 'Digite um prompt para gerar um vídeo.';
	@override String get noCharacterMessage => 'Nenhum personagem disponível para geração de vídeo.';
	@override String get notConfiguredMessage => 'A geração de vídeo não está configurada.';
}

// Path: chat.bubbleWaitingFor
class _TranslationsChatBubbleWaitingForPtBr extends _TranslationsChatBubbleWaitingForEn {
	_TranslationsChatBubbleWaitingForPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get thinking => 'Pensando…';
	@override String get preparingImagePrompt => 'Preparando prompt de imagem…';
	@override String get preparingVideoPrompt => 'Preparando prompt de vídeo…';
	@override String get generatingImage => 'Gerando imagem…';
	@override String get generatingVideo => 'Gerando vídeo…';
}

// Path: chat.appBarChat
class _TranslationsChatAppBarChatPtBr extends _TranslationsChatAppBarChatEn {
	_TranslationsChatAppBarChatPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get hideEditorPanelTooltip => 'Ocultar painel do editor';
	@override String get showEditorSideBySideTooltip => 'Mostrar editor lado a lado';
}

// Path: chat.allChatsDrawerList
class _TranslationsChatAllChatsDrawerListPtBr extends _TranslationsChatAllChatsDrawerListEn {
	_TranslationsChatAllChatsDrawerListPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get rebuildingIndex => 'Reconstruindo índice...';
	@override String get noChatsFound => 'Nenhuma conversa encontrada.';
}

// Path: chat.chatInputMediaMenu
class _TranslationsChatChatInputMediaMenuPtBr extends _TranslationsChatChatInputMediaMenuEn {
	_TranslationsChatChatInputMediaMenuPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get generateMediaTooltip => 'Gerar mídia';
	@override String get generateImageLabel => 'Gerar imagem';
	@override String get generateVideoLabel => 'Gerar vídeo';
}

// Path: chat.chatView
class _TranslationsChatChatViewPtBr extends _TranslationsChatChatViewEn {
	_TranslationsChatChatViewPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get deleteMessageTitle => 'Excluir mensagem';
	@override String get deleteMessageConfirmation => 'Tem certeza de que deseja excluir esta mensagem?';
	@override String get typeMessageHint => 'Digite uma mensagem...';
	@override String get moreActionsTooltip => 'Mais ações';
	@override String get continueAction => 'Continuar';
	@override String get impersonateAction => 'Interpretar';
	@override String get generateReplyAction => 'Gerar resposta';
	@override String get improveMessageAction => 'Melhorar mensagem';
}

// Path: chat.chatMessageBubble
class _TranslationsChatChatMessageBubblePtBr extends _TranslationsChatChatMessageBubbleEn {
	_TranslationsChatChatMessageBubblePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get imagesTypeGroupLabel => 'Imagens';
	@override String get assistantFallbackName => 'Assistente';
	@override String get reasoningLabel => 'Raciocínio';
	@override String get sendingToProvider => 'Enviando ao provedor…';
	@override String pollingWithPercent({required Object pct}) => 'Consultando… ${pct}%';
	@override String get polling => 'Consultando…';
	@override String get downloading => 'Baixando…';
}

// Path: common.actions
class _TranslationsCommonActionsPtBr extends _TranslationsCommonActionsEn {
	_TranslationsCommonActionsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Excluir';
	@override String get ok => 'OK';
	@override String get cancel => 'Cancelar';
	@override String get save => 'Salvar';
	@override String get tryAgain => 'Tentar novamente';
	@override String get close => 'Fechar';
}

// Path: common.aiAction
class _TranslationsCommonAiActionPtBr extends _TranslationsCommonAiActionEn {
	_TranslationsCommonAiActionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get proofread => 'Revisar';
	@override String get compact => 'Compactar prosa';
	@override String get translate => 'Traduzir para o inglês';
	@override String get generatePreview => 'Gerar prévia';
	@override String get autoTag => 'Marcação automática';
}

// Path: common.promptSegmentKind
class _TranslationsCommonPromptSegmentKindPtBr extends _TranslationsCommonPromptSegmentKindEn {
	_TranslationsCommonPromptSegmentKindPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get identity => 'Identidade';
	@override String get systemPrompt => 'Prompt do sistema';
	@override String get nsfwMode => 'Modo NSFW';
	@override String get scenarioMode => 'Modo cenário';
	@override String get description => 'Descrição';
	@override String get personality => 'Personalidade';
	@override String get scenario => 'Cenário';
	@override String get userPersona => 'Sua persona';
	@override String get memory => 'Memória';
	@override String get situation => 'Situação';
	@override String get cardData => 'Dados do cartão';
	@override String get tools => 'Ferramentas';
	@override String get postHistory => 'Pós-histórico';
	@override String get depthPrompt => 'Prompt de profundidade';
	@override String get worldInfo => 'Informações do mundo';
	@override String get injected => 'Injetado';
	@override String get exampleDialogue => 'Diálogo de exemplo';
	@override String get history => 'Histórico de mensagens';
	@override String get currentMessage => 'Mensagem atual';
	@override String get reservedReply => 'Resposta reservada';
}

// Path: common.promptBreakdown
class _TranslationsCommonPromptBreakdownPtBr extends _TranslationsCommonPromptBreakdownEn {
	_TranslationsCommonPromptBreakdownPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get free => 'Livre';
}

// Path: common.logs
class _TranslationsCommonLogsPtBr extends _TranslationsCommonLogsEn {
	_TranslationsCommonLogsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logs';
	@override String get filterTooltip => 'Filtrar logs';
	@override String get clearTooltip => 'Limpar logs';
	@override String get exportTooltip => 'Exportar logs';
	@override String get searchHint => 'Buscar logs...';
	@override String get noLogsFound => 'Nenhum log encontrado.';
	@override String get noLogsToExport => 'Nenhum log para exportar';
	@override String get exportedSuccessfully => 'Logs exportados com sucesso';
	@override String get exportFailed => 'Falha ao exportar logs. Veja os logs para detalhes.';
	@override String get copiedToClipboard => 'Copiado para a área de transferência';
	@override String get copyLogButton => 'Copiar log';
	@override String get copiedEntryToClipboard => 'Entrada de log copiada para a área de transferência';
	@override String errorPrefix({required Object error}) => 'Erro: ${error}';
}

// Path: common.importErrorsDialog
class _TranslationsCommonImportErrorsDialogPtBr extends _TranslationsCommonImportErrorsDialogEn {
	_TranslationsCommonImportErrorsDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Erros de importação';
	@override String get message => 'Os seguintes arquivos não puderam ser importados:';
}

// Path: common.updateDialog
class _TranslationsCommonUpdateDialogPtBr extends _TranslationsCommonUpdateDialogEn {
	_TranslationsCommonUpdateDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Versão disponível';
	@override String body({required Object appName, required Object currentVersion, required Object latestVersion}) => 'Uma versão mais nova do ${appName} está disponível.\n\nVersão atual: ${currentVersion}\nVersão mais recente: ${latestVersion}';
	@override String get releaseNotesLabel => 'Notas da versão:';
	@override String get viewReleasesButton => 'Ver versões';
}

// Path: common.importConflictsDialog
class _TranslationsCommonImportConflictsDialogPtBr extends _TranslationsCommonImportConflictsDialogEn {
	_TranslationsCommonImportConflictsDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Conflitos de importação';
	@override String message({required Object count}) => 'Os ${count} personagens a seguir têm conflitos de nome de arquivo e serão renomeados automaticamente:';
}

// Path: common.missingProviderBanner
class _TranslationsCommonMissingProviderBannerPtBr extends _TranslationsCommonMissingProviderBannerEn {
	_TranslationsCommonMissingProviderBannerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get message => 'Conecte um provedor de IA.';
	@override String get setUpNowButton => 'Configurar agora';
}

// Path: common.modelSelectionDialog
class _TranslationsCommonModelSelectionDialogPtBr extends _TranslationsCommonModelSelectionDialogEn {
	_TranslationsCommonModelSelectionDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Buscar modelos';
	@override String subscriptionOnlyToggle({required Object included, required Object total}) => 'Mostrar apenas modelos por assinatura (${included}/${total})';
}

// Path: common.showAdvanced
class _TranslationsCommonShowAdvancedPtBr extends _TranslationsCommonShowAdvancedEn {
	_TranslationsCommonShowAdvancedPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get less => 'Menos';
	@override String get more => 'Mais';
}

// Path: common.messageEditDialog
class _TranslationsCommonMessageEditDialogPtBr extends _TranslationsCommonMessageEditDialogEn {
	_TranslationsCommonMessageEditDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editar mensagem';
}

// Path: common.promptBreakdownDialog
class _TranslationsCommonPromptBreakdownDialogPtBr extends _TranslationsCommonPromptBreakdownDialogEn {
	_TranslationsCommonPromptBreakdownDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Detalhamento do prompt';
	@override String get breakdownTab => 'Detalhamento';
	@override String get contentTab => 'Conteúdo';
	@override String get promptTotalEstimated => 'Total do prompt (estimado)';
	@override String get promptTotalProvider => 'Total do prompt (provedor)';
	@override String get contextWindowLabel => 'Janela de contexto';
	@override String get categoryHeader => 'CATEGORIA';
	@override String get tokensHeader => 'TOKENS';
	@override String get usageHeader => 'USO';
	@override String get noContentToInspect => 'Nenhum conteúdo para inspecionar nesta resposta.';
	@override String get estimatedSuffix => ' (estimado)';
	@override String usedSummary({required Object used, required Object total}) => '${used} / ${total} usados';
}

// Path: common.jsonPromptDialog
class _TranslationsCommonJsonPromptDialogPtBr extends _TranslationsCommonJsonPromptDialogEn {
	_TranslationsCommonJsonPromptDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Prompt de geração';
}

// Path: common.progressDialog
class _TranslationsCommonProgressDialogPtBr extends _TranslationsCommonProgressDialogEn {
	_TranslationsCommonProgressDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get defaultMessage => 'Enviando...';
	@override String get finished => 'Concluído!';
}

// Path: common.diffPanel
class _TranslationsCommonDiffPanelPtBr extends _TranslationsCommonDiffPanelEn {
	_TranslationsCommonDiffPanelPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String tokenSuffix({required Object count}) => ' (${count} tokens)';
}

// Path: common.selectionDialog
class _TranslationsCommonSelectionDialogPtBr extends _TranslationsCommonSelectionDialogEn {
	_TranslationsCommonSelectionDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Buscar…';
}

// Path: common.zdrSwitch
class _TranslationsCommonZdrSwitchPtBr extends _TranslationsCommonZdrSwitchEn {
	_TranslationsCommonZdrSwitchPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exigir Zero Data Retention (ZDR)';
	@override String get subtitle => 'Mostrar apenas modelos do OR com endpoints compatíveis com ZDR. Ative se sua conta openrouter.ai restringe a provedores ZDR.';
}

// Path: common.textFieldCard
class _TranslationsCommonTextFieldCardPtBr extends _TranslationsCommonTextFieldCardEn {
	_TranslationsCommonTextFieldCardPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String labelWithTokenCount({required Object label, required Object count}) => '${label} - ${count} tokens';
	@override String tokenCountAbbrev({required Object count}) => '${count} t';
}

// Path: common.modelCapability
class _TranslationsCommonModelCapabilityPtBr extends _TranslationsCommonModelCapabilityEn {
	_TranslationsCommonModelCapabilityPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get reasoning => 'Raciocínio';
	@override String get vision => 'Visão';
	@override String get tools => 'Ferramentas';
	@override String get json => 'JSON';
	@override String get files => 'Arquivos';
	@override String get image => 'Imagem';
	@override String get video => 'Vídeo';
	@override String get speech => 'Fala';
	@override String get music => 'Música';
}

// Path: common.appConstants
class _TranslationsCommonAppConstantsPtBr extends _TranslationsCommonAppConstantsEn {
	_TranslationsCommonAppConstantsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get maxImageFileSizeLabel => '10 MB';
	@override String get exportFailedMessage => 'Falha na exportação. Veja os logs para detalhes.';
}

// Path: common.timeAgo
class _TranslationsCommonTimeAgoPtBr extends _TranslationsCommonTimeAgoEn {
	_TranslationsCommonTimeAgoPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String years({required Object n}) => 'há ${n}a';
	@override String months({required Object n}) => 'há ${n}mes';
	@override String days({required Object n}) => 'há ${n}d';
	@override String hours({required Object n}) => 'há ${n}h';
	@override String minutes({required Object n}) => 'há ${n}min';
	@override String get justNow => 'Agora mesmo';
}

// Path: editor.panelLabels
class _TranslationsEditorPanelLabelsPtBr extends _TranslationsEditorPanelLabelsEn {
	_TranslationsEditorPanelLabelsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get basic => 'Básico';
	@override String get greetings => 'Saudações';
	@override String get prompts => 'Prompts';
	@override String get lorebook => 'Lorebook';
	@override String get group => 'Grupo';
	@override String get creator => 'Criador';
	@override String get appData => 'Dados do app';
	@override String get nodes => 'Nós';
}

// Path: editor.appBarEditor
class _TranslationsEditorAppBarEditorPtBr extends _TranslationsEditorAppBarEditorEn {
	_TranslationsEditorAppBarEditorPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get hideAssistantPanelTooltip => 'Ocultar painel do assistente';
	@override String get showChatAssistantTooltip => 'Mostrar assistente de conversa lado a lado';
}

// Path: editor.codeFindPanel
class _TranslationsEditorCodeFindPanelPtBr extends _TranslationsEditorCodeFindPanelEn {
	_TranslationsEditorCodeFindPanelPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noneResult => 'nenhum';
	@override String get previousTooltip => 'Anterior';
	@override String get nextTooltip => 'Próximo';
	@override String get closeTooltip => 'Fechar';
	@override String get replaceTooltip => 'Substituir';
	@override String get replaceAllTooltip => 'Substituir tudo';
}

// Path: editor.findReplaceDialog
class _TranslationsEditorFindReplaceDialogPtBr extends _TranslationsEditorFindReplaceDialogEn {
	_TranslationsEditorFindReplaceDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get confirmReplaceAllTitle => 'Confirmar Substituir tudo';
	@override String get confirmReplaceAllMessage => 'Tem certeza de que deseja continuar?\nEsta ação é irreversível e afeta todos os campos.';
	@override String get proceedButton => 'Prosseguir';
	@override String get title => 'Localizar e substituir';
	@override String get findLabel => 'Localizar';
	@override String get replaceWithLabel => 'Substituir por';
	@override String get replaceAllButton => 'Substituir tudo';
}

// Path: editor.objectValueEditor
class _TranslationsEditorObjectValueEditorPtBr extends _TranslationsEditorObjectValueEditorEn {
	_TranslationsEditorObjectValueEditorPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get stringType => 'string';
	@override String get numberType => 'número';
	@override String get boolType => 'bool';
}

// Path: editor.editorBasic
class _TranslationsEditorEditorBasicPtBr extends _TranslationsEditorEditorBasicEn {
	_TranslationsEditorEditorBasicPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get nameLabel => 'Nome';
	@override String get nicknameLabel => 'Apelido (CCv3)';
	@override String get descriptionLabel => 'Descrição';
	@override String get personalityLabel => 'Personalidade';
	@override String get scenarioLabel => 'Cenário';
	@override String get messageExampleLabel => 'Exemplo de mensagem';
}

// Path: editor.editorCreatorMetadata
class _TranslationsEditorEditorCreatorMetadataPtBr extends _TranslationsEditorEditorCreatorMetadataEn {
	_TranslationsEditorEditorCreatorMetadataPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get systemNameLabel => 'Nome de sistema (CCv3)';
	@override String get creatorLabel => 'Criador';
	@override String get versionLabel => 'Versão';
	@override String get creatorNotesLabel => 'Notas do criador';
	@override String get tagsLabel => 'Tags (separadas por vírgula)';
}

// Path: editor.editorPrompts
class _TranslationsEditorEditorPromptsPtBr extends _TranslationsEditorEditorPromptsEn {
	_TranslationsEditorEditorPromptsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get systemPromptLabel => 'Prompt do sistema';
	@override String get postHistoryInstructionsLabel => 'Instruções pós-histórico';
	@override String get depthPromptLabel => 'Prompt de profundidade (notas do personagem)';
	@override String get insertionDepthLabel => 'Profundidade de inserção';
	@override String get roleLabel => 'Papel';
}

// Path: editor.editorAppData
class _TranslationsEditorEditorAppDataPtBr extends _TranslationsEditorEditorAppDataEn {
	_TranslationsEditorEditorAppDataPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get variantNotesLabel => 'Notas da variante';
	@override String get descriptionPreviewLabel => 'Prévia da descrição';
}

// Path: editor.editorAlternateGreetings
class _TranslationsEditorEditorAlternateGreetingsPtBr extends _TranslationsEditorEditorAlternateGreetingsEn {
	_TranslationsEditorEditorAlternateGreetingsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get deleteGreetingTitle => 'Excluir saudação';
	@override String get deleteGreetingMessage => 'Tem certeza de que deseja excluir esta saudação?';
	@override String get addGreetingButton => 'Adicionar saudação';
	@override String get primaryGreetingLabel => 'Saudação principal (first_mes)';
	@override String alternateGreetingLabel({required Object index}) => 'Saudação alternativa nº${index}';
	@override String get removeTooltip => 'Remover';
}

// Path: editor.editorGroupGreetings
class _TranslationsEditorEditorGroupGreetingsPtBr extends _TranslationsEditorEditorGroupGreetingsEn {
	_TranslationsEditorEditorGroupGreetingsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String greetingLabel({required Object index}) => 'Saudação ${index}';
}

// Path: editor.editorLorebook
class _TranslationsEditorEditorLorebookPtBr extends _TranslationsEditorEditorLorebookEn {
	_TranslationsEditorEditorLorebookPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get newEntryDefaultComment => 'Nova entrada';
	@override String get deleteEntryTitle => 'Excluir entrada';
	@override String get deleteEntryMessage => 'Tem certeza de que deseja excluir esta entrada?';
	@override String get addNewEntryButton => 'Adicionar nova entrada';
	@override String get noEntriesFound => 'Nenhuma entrada de lorebook encontrada.';
}

// Path: editor.lorebookEntryListTile
class _TranslationsEditorLorebookEntryListTilePtBr extends _TranslationsEditorLorebookEntryListTileEn {
	_TranslationsEditorLorebookEntryListTilePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get untitledEntry => 'Entrada sem título';
	@override String get noKeywords => 'Sem palavras-chave';
}

// Path: editor.lorebookEntryEditorPage
class _TranslationsEditorLorebookEntryEditorPagePtBr extends _TranslationsEditorLorebookEntryEditorPageEn {
	_TranslationsEditorLorebookEntryEditorPagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get editEntryTitle => 'Editar entrada de lorebook';
	@override String get advancedFilter => 'Avançado';
	@override String get primaryKeywordsLabel => 'Palavras-chave principais';
	@override String get logicLabel => 'Lógica';
	@override String get logicAndAny => 'E QUALQUER';
	@override String get logicAndAll => 'E TODAS';
	@override String get logicNotAny => 'NÃO QUALQUER';
	@override String get logicNotAll => 'NÃO TODAS';
	@override String get optionalFilterLabel => 'Filtro opcional';
	@override String get contentLabel => 'Conteúdo';
	@override String get nonRecursableFilter => 'Não recursável';
	@override String get preventFurtherRecursionFilter => 'Impedir recursão adicional';
	@override String get delayUntilRecursionFilter => 'Adiar até a recursão';
	@override String get ignoreBudgetFilter => 'Ignorar orçamento';
	@override String get prioritizeFilter => 'Priorizar';
	@override String get inclusionGroupLabel => 'Grupo de inclusão';
	@override String get groupWeightLabel => 'Peso do grupo';
	@override String get stickyLabel => 'Fixo';
	@override String get cooldownLabel => 'Tempo de espera';
	@override String get delayLabel => 'Atraso';
	@override String get filterToCharactersLabel => 'Filtrar para personagens ou tags';
	@override String get filterToTriggersLabel => 'Filtrar para gatilhos de geração';
	@override String get additionalMatchingSourcesLabel => 'Fontes de correspondência adicionais:';
	@override String get personaFilter => 'Persona';
	@override String get descriptionFilter => 'Descrição';
	@override String get personalityFilter => 'Personalidade';
	@override String get depthPromptFilter => 'Prompt de profundidade';
	@override String get scenarioFilter => 'Cenário';
	@override String get creatorNotesFilter => 'Notas do criador';
}

// Path: editor.lorebookEntryEditorTopSection
class _TranslationsEditorLorebookEntryEditorTopSectionPtBr extends _TranslationsEditorLorebookEntryEditorTopSectionEn {
	_TranslationsEditorLorebookEntryEditorTopSectionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get titleMemoLabel => 'Título/nota';
	@override String get strategyLabel => 'Estratégia';
	@override String get strategyConstant => 'Constante';
	@override String get strategyEnabled => 'Ativada';
	@override String get strategyDisabled => 'Desativada';
	@override String get strategyVectorized => 'Vetorizada';
	@override String get positionLabel => 'Posição';
	@override String get positionUpChar => '↑ Pers';
	@override String get positionDownChar => '↓ Pers';
	@override String get positionUpAn => '↑ AN';
	@override String get positionDownAn => '↓ AN';
	@override String get positionDepthSystem => '@D Sistema';
	@override String get positionDepthUser => '@D Usuário';
	@override String get positionDepthAssistant => '@D Assistente';
	@override String get positionUpEm => '↑ EM';
	@override String get positionDownEm => '↓ EM';
	@override String get positionOutlet => 'Saída';
	@override String get depthLabel => 'Profundidade';
	@override String get orderLabel => 'Ordem';
	@override String get triggerLabel => 'Gatilho %';
}

// Path: editor.lorebookEntryEditorScanRow
class _TranslationsEditorLorebookEntryEditorScanRowPtBr extends _TranslationsEditorLorebookEntryEditorScanRowEn {
	_TranslationsEditorLorebookEntryEditorScanRowPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get scanDepthLabel => 'Profundidade de varredura';
	@override String get automationIdLabel => 'ID de automação';
	@override String get useRegexFilter => 'Usar regex';
	@override String get caseSensitiveFilter => 'Diferenciar maiúsculas';
	@override String get wholeWordsFilter => 'Palavras inteiras';
	@override String get groupScoringFilter => 'Pontuação de grupo';
}

// Path: editor.dialogContentCleaner
class _TranslationsEditorDialogContentCleanerPtBr extends _TranslationsEditorDialogContentCleanerEn {
	_TranslationsEditorDialogContentCleanerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String confirmActionTitle({required Object actionName}) => 'Confirmar ${actionName}';
	@override String get title => 'Limpador de conteúdo';
	@override String get normalizeFancyCharsAction => 'Normalizar caracteres especiais';
	@override String get normalizeFancyCharsButton => 'Normalizar caracteres especiais (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
	@override String get purgeHtmlAction => 'Remover HTML';
	@override String get purgeHtmlButton => 'Remover tags HTML';
	@override String get purgeMarkdownAction => 'Remover links/imagens Markdown';
	@override String get purgeEmojisAction => 'Remover emojis';
	@override String get purgeExtraSpacesAction => 'Remover espaços extras';
	@override String get yoloPurgeAction => 'Limpeza total';
	@override String get applyAllAboveButton => 'Aplicar tudo acima';
}

// Path: editor.dialogAiDiffConfirmation
class _TranslationsEditorDialogAiDiffConfirmationPtBr extends _TranslationsEditorDialogAiDiffConfirmationEn {
	_TranslationsEditorDialogAiDiffConfirmationPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get applyChangesButton => 'Aplicar alterações';
	@override String get originalTextTitle => 'Texto original';
	@override String get suggestedTextTitle => 'Texto sugerido';
}

// Path: editor.editorPageController
class _TranslationsEditorEditorPageControllerPtBr extends _TranslationsEditorEditorPageControllerEn {
	_TranslationsEditorEditorPageControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String globalActionTitle({required Object action}) => '${action} global';
	@override String get globalAiActionFailed => 'Ação de IA global falhou. Verifique os logs.';
	@override String compositeName({required Object value}) => 'Nome:\n${value}\n';
	@override String compositeDescription({required Object value}) => 'Descrição:\n${value}\n';
	@override String compositePersonality({required Object value}) => 'Personalidade:\n${value}\n';
	@override String compositeScenario({required Object value}) => 'Cenário:\n${value}\n';
	@override String compositeFirstMessage({required Object value}) => 'Primeira mensagem:\n${value}\n';
	@override String compositeMessageExample({required Object value}) => 'Exemplo de mensagem:\n${value}\n';
	@override String compositeCreatorNotes({required Object value}) => 'Notas do criador:\n${value}\n';
	@override String compositeSystemPrompt({required Object value}) => 'Prompt do sistema:\n${value}\n';
	@override String compositePostHistoryInstructions({required Object value}) => 'Instruções pós-histórico:\n${value}\n';
	@override String compositeAlternateGreeting({required Object index, required Object value}) => 'Saudação alternativa nº${index}:\n${value}\n';
	@override String compositeGroupGreeting({required Object index, required Object value}) => 'Saudação de grupo nº${index}:\n${value}\n';
	@override String compositeLorebookEntry({required Object index, required Object value}) => 'Entrada de lorebook nº${index}:\n${value}\n';
	@override String imageTooLargeMessage({required Object maxSize}) => 'A imagem selecionada é grande demais. O tamanho máximo é ${maxSize}.';
	@override String get invalidPngMessage => 'A imagem selecionada não é um PNG válido ou não pôde ser lida.';
}

// Path: editor.editorNodes
class _TranslationsEditorEditorNodesPtBr extends _TranslationsEditorEditorNodesEn {
	_TranslationsEditorEditorNodesPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get deleteNodeTitle => 'Excluir nó';
	@override String get deleteNodeMessage => 'Remover este nó autoral do cartão?';
	@override String get engineSeedTitle => 'Semente do motor';
	@override String get visualEditorTooltip => 'Editor visual';
	@override String get editJsonTooltip => 'Editar JSON';
	@override String get initialGoalLabel => 'Objetivo inicial';
	@override String get initialSceneLabel => 'Cena inicial';
	@override String get locationLabel => 'Local';
	@override String get timeOfDayLabel => 'Hora do dia';
	@override String get presentEntitiesLabel => 'Presentes (separados por vírgula)';
	@override String get sensoryHooksLabel => 'Ganchos sensoriais (separados por vírgula)';
	@override String get addNodeButton => 'Adicionar nó';
	@override String get noAuthoredNodesYet => 'Nenhum nó autoral ainda.';
	@override String loadErrorMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
		one: 'O bloco de nós deste cartão tem ${n} problema; editar aqui sobrescreverá as partes corrompidas ao salvar.',
		other: 'O bloco de nós deste cartão tem ${n} problemas; editar aqui sobrescreverá as partes corrompidas ao salvar.',
	);
	@override String moreErrorsSuffix({required Object n}) => '… mais ${n}';
	@override String get emotionBaselineLabel => 'Emoção base';
	@override String get emotionChipLabel => 'Emoção';
}

// Path: editor.nodeListTile
class _TranslationsEditorNodeListTilePtBr extends _TranslationsEditorNodeListTileEn {
	_TranslationsEditorNodeListTilePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String spawnsLabel({required Object count}) => 'gera: ${count}';
}

// Path: editor.nodesRawEditorPage
class _TranslationsEditorNodesRawEditorPagePtBr extends _TranslationsEditorNodesRawEditorPageEn {
	_TranslationsEditorNodesRawEditorPagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get topLevelMustBeObject => 'O nível superior deve ser um objeto JSON';
	@override String get editNodesJsonTitle => 'Editar JSON dos nós';
	@override String fixProblemsMessage({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
		one: 'Corrija ${n} problema para salvar.',
		other: 'Corrija ${n} problemas para salvar.',
	);
}

// Path: editor.nodesCanvasView
class _TranslationsEditorNodesCanvasViewPtBr extends _TranslationsEditorNodesCanvasViewEn {
	_TranslationsEditorNodesCanvasViewPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get spawnedByPort => 'gerado por';
	@override String get spawnsPort => 'gera';
	@override String get editNodeLabel => 'Editar nó';
	@override String get addNodeTooltip => 'Adicionar nó';
}

// Path: editor.nodeEditorForm
class _TranslationsEditorNodeEditorFormPtBr extends _TranslationsEditorNodeEditorFormEn {
	_TranslationsEditorNodeEditorFormPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get nameLabel => 'Nome';
	@override String get narrativePayloadLabel => 'Carga narrativa';
	@override String get removeSpawnLinkTitle => 'Remover vínculo de geração';
	@override String removeSpawnLinkMessage({required Object nodeId}) => 'Impedir este nó de gerar "${nodeId}"? O nó em si permanece no cartão.';
	@override String get removeButton => 'Remover';
	@override String get typeLabel => 'Tipo';
	@override String get scopeLabel => 'Escopo';
	@override String get originLabel => 'Origem';
	@override String get triggerProbLabel => 'Prob. de gatilho';
	@override String get delayHelper => 'Turnos a esperar antes de ficar elegível. -1 age como 0.';
	@override String get cooldownHelper => 'Turnos bloqueado após disparar. -1 significa sem tempo de espera.';
	@override String get stickyHelper => 'Turnos em que a carga narrativa continua aparecendo como "Persistente" após disparar. -1 significa permanente.';
	@override String get aliveHelper => 'Turnos em que o nó permanece no pool antes da remoção. -1 significa para sempre.';
	@override String get setToNeverButton => 'Definir como nunca';
	@override String get effectsSectionLabel => 'Efeitos';
	@override String get emotionDeltasTitle => 'Variações de emoção';
	@override String get physicalDeltasTitle => 'Variações físicas';
	@override String get relationshipDeltasTitle => 'Variações de relacionamento';
	@override String get addDeltaChip => 'Adicionar variação';
	@override String get knowledgeWritesTitle => 'Escritas de conhecimento';
	@override String get addFactChip => 'Adicionar fato';
	@override String get topicLabel => 'tópico';
	@override String get confidenceLabel => 'confiança';
	@override String get flagSetTitle => 'Definição de flag';
	@override String get addFlagChip => 'Adicionar flag';
	@override String get keyLabel => 'chave';
	@override String get sceneAndFlowTitle => 'Cena e fluxo';
	@override String get goalChangeLabel => 'goalChange (limpa o objetivo atual quando vazio)';
	@override String get phaseChangeLabel => 'phaseChange';
	@override String get noneOption => '(nenhum)';
	@override String get sceneTransitionLabel => 'sceneTransition';
	@override String get sceneTransitionSubtitle => 'Quando verdadeiro, o motor marca o disparo como uma mudança de cena.';
	@override String get spawnsSectionLabel => 'Gerações';
	@override String get addNewChip => 'Adicionar novo';
	@override String get linkExistingChip => 'Vincular existente';
	@override String get unlinkTooltip => 'Desvincular';
	@override String get predicateLabel => 'Predicado';
}

// Path: grid.emptyState
class _TranslationsGridEmptyStatePtBr extends _TranslationsGridEmptyStateEn {
	_TranslationsGridEmptyStatePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noMatches => 'Nenhum personagem corresponde aos seus filtros';
	@override String get noCharacters => 'Nenhum personagem importado ainda';
	@override String get clearAllFilters => 'Limpar todos os filtros';
	@override String get importCharacters => 'Importar personagens';
	@override String get createNewCharacter => 'Criar novo personagem';
}

// Path: grid.appBar
class _TranslationsGridAppBarPtBr extends _TranslationsGridAppBarEn {
	_TranslationsGridAppBarPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get groups => 'Grupos';
	@override String get createNew => 'Criar';
	@override String get import => 'Importar';
	@override String get menuTooltip => 'Menu';
}

// Path: grid.fab
class _TranslationsGridFabPtBr extends _TranslationsGridFabEn {
	_TranslationsGridFabPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get addOrImportTooltip => 'Adicionar ou importar';
	@override String get import => 'Importar';
	@override String get create => 'Criar';
}

// Path: grid.drawer
class _TranslationsGridDrawerPtBr extends _TranslationsGridDrawerEn {
	_TranslationsGridDrawerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get mediaDefaultsApp => 'App';
	@override String get batchAiHeader => 'IA em lote';
	@override String get batchGeneratePreviewsTitle => 'Gerar prévias em lote';
	@override String get batchGeneratePreviewsEmpty => 'Todos os personagens já têm prévias.';
	@override String get batchAutoTagTitle => 'Marcação automática em lote';
	@override String get batchAutoTagEmpty => 'Todos os personagens já têm tags.';
	@override String get libraryHeader => 'Biblioteca';
	@override String get reloadCharacters => 'Recarregar personagens';
}

// Path: grid.variantBadge
class _TranslationsGridVariantBadgePtBr extends _TranslationsGridVariantBadgeEn {
	_TranslationsGridVariantBadgePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String tooltip({required Object count}) => '${count} variantes';
}

// Path: grid.dialogActions
class _TranslationsGridDialogActionsPtBr extends _TranslationsGridDialogActionsEn {
	_TranslationsGridDialogActionsPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get clearAll => 'Limpar tudo';
	@override String get apply => 'Aplicar';
}

// Path: grid.tagFilterDialog
class _TranslationsGridTagFilterDialogPtBr extends _TranslationsGridTagFilterDialogEn {
	_TranslationsGridTagFilterDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrar tags';
	@override String get searchHint => 'Buscar tags...';
}

// Path: grid.filters
class _TranslationsGridFiltersPtBr extends _TranslationsGridFiltersEn {
	_TranslationsGridFiltersPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get hideFiltersTooltip => 'Ocultar filtros';
	@override String get moreFiltersTooltip => 'Mais filtros';
	@override String get folderChip => 'Pasta';
	@override String get creatorChip => 'Criador';
	@override String get tagChip => 'Tag';
	@override String get recentTooltip => 'Recentes';
	@override String get favoritesTooltip => 'Favoritos';
	@override String get variantsTooltip => 'Variantes';
	@override String indexingProgress({required Object done, required Object total}) => 'Criando busca ${done} / ${total}…';
}

// Path: grid.sortOption
class _TranslationsGridSortOptionPtBr extends _TranslationsGridSortOptionEn {
	_TranslationsGridSortOptionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get relevance => 'Relevância ↓';
	@override String get nameAsc => 'Nome ↓';
	@override String get nameDesc => 'Nome ↑';
	@override String get importNewest => 'Importado ↓';
	@override String get importOldest => 'Importado ↑';
	@override String get modifiedNewest => 'Modificado ↓';
	@override String get modifiedOldest => 'Modificado ↑';
	@override String get interactedNewest => 'Interagido ↓';
	@override String get interactedOldest => 'Interagido ↑';
	@override String get tokensHigh => 'Tokens ↓';
	@override String get tokensLow => 'Tokens ↑';
}

// Path: grid.filterController
class _TranslationsGridFilterControllerPtBr extends _TranslationsGridFilterControllerEn {
	_TranslationsGridFilterControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get filterCreators => 'Filtrar criadores';
	@override String get filterTags => 'Filtrar tags';
	@override String get filterByFolder => 'Filtrar por pasta';
}

// Path: grid.multiSelectDialog
class _TranslationsGridMultiSelectDialogPtBr extends _TranslationsGridMultiSelectDialogEn {
	_TranslationsGridMultiSelectDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get nothingToShow => 'Nada para mostrar ainda.';
	@override String get noMatches => 'Nenhuma correspondência.';
	@override String get showMore => 'Mostrar mais';
}

// Path: grid.createCharacterDialog
class _TranslationsGridCreateCharacterDialogPtBr extends _TranslationsGridCreateCharacterDialogEn {
	_TranslationsGridCreateCharacterDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get nameEmptyError => 'O nome do personagem não pode ficar vazio.';
	@override String get nameInvalidCharsError => 'O nome contém caracteres inválidos (<>:"/\|?*).';
	@override String get nameExistsError => 'Já existe um personagem com esse nome.';
	@override String get nameCheckFailedError => 'Não foi possível verificar o nome. Verifique as permissões da pasta e tente novamente.';
	@override String get title => 'Criar novo personagem';
	@override String get nameLabel => 'Nome do personagem';
	@override String get createButton => 'Criar';
}

// Path: grid.variantsSheet
class _TranslationsGridVariantsSheetPtBr extends _TranslationsGridVariantsSheetEn {
	_TranslationsGridVariantsSheetPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Variantes';
}

// Path: grid.groupAppBar
class _TranslationsGridGroupAppBarPtBr extends _TranslationsGridGroupAppBarEn {
	_TranslationsGridGroupAppBarPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get characters => 'Personagens';
	@override String get newGroup => 'Novo grupo';
}

// Path: grid.thumbnailBadges
class _TranslationsGridThumbnailBadgesPtBr extends _TranslationsGridThumbnailBadgesEn {
	_TranslationsGridThumbnailBadgesPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get recent => 'RECENTE';
	@override String get original => 'ORIGINAL';
	@override String get variant => 'VARIANTE';
}

// Path: grid.actionMenu
class _TranslationsGridActionMenuPtBr extends _TranslationsGridActionMenuEn {
	_TranslationsGridActionMenuPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get editNotes => 'Editar notas';
	@override String get dismissRecent => 'Remover de recentes';
	@override String get exportPngV2V3 => 'Exportar como PNG (V2/V3)';
	@override String get exportJsonV3 => 'Exportar como JSON (V3)';
	@override String get exportJsonV2 => 'Exportar como JSON (V2)';
	@override String get duplicate => 'Duplicar';
}

// Path: grid.controllerMessages
class _TranslationsGridControllerMessagesPtBr extends _TranslationsGridControllerMessagesEn {
	_TranslationsGridControllerMessagesPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get duplicateFailed => 'Não foi possível duplicar o personagem.';
	@override String get editVariantNotesTitle => 'Editar notas da variante';
	@override String get editVariantNotesHint => 'Adicione notas sobre esta variante...';
	@override String get deleteCardTitle => 'Excluir cartão';
	@override String get deleteCardMessage => 'Tem certeza de que deseja excluir este cartão?';
	@override String get deletePartialFailure => 'Alguns arquivos não puderam ser excluídos. Veja os logs para detalhes.';
}

// Path: grid.tagWrap
class _TranslationsGridTagWrapPtBr extends _TranslationsGridTagWrapEn {
	_TranslationsGridTagWrapPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String tagCountLabel({required Object tag, required Object count}) => '${tag} (${count})';
}

// Path: group.groupGridController
class _TranslationsGroupGroupGridControllerPtBr extends _TranslationsGroupGroupGridControllerEn {
	_TranslationsGroupGroupGridControllerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get renameGroupTitle => 'Renomear grupo';
	@override String get groupNameHint => 'Nome do grupo';
	@override String get deleteGroupTitle => 'Excluir grupo';
	@override String deleteGroupMessage({required Object name}) => 'Tem certeza de que deseja excluir "${name}"? Isso não pode ser desfeito.';
}

// Path: group.groupChatPage
class _TranslationsGroupGroupChatPagePtBr extends _TranslationsGroupGroupChatPageEn {
	_TranslationsGroupGroupChatPagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get defaultGroupName => 'Conversa em grupo';
	@override String failedToLoadMessage({required Object error}) => 'Falha ao carregar a conversa em grupo:\n${error}';
	@override String get nextTurnTooltip => 'Próximo turno';
	@override String get stopAutoChatTooltip => 'Parar conversa automática';
	@override String get startAutoChatTooltip => 'Iniciar conversa automática';
	@override String get stopGenerationTooltip => 'Parar geração';
	@override String get noCharactersYetMessage => 'Este grupo ainda não tem personagens.';
	@override String get addCharacterButton => 'Adicionar um personagem';
	@override String get pickCharacterMessage => 'Escolha um personagem na lista à esquerda.';
}

// Path: group.groupGridPage
class _TranslationsGroupGroupGridPagePtBr extends _TranslationsGroupGroupGridPageEn {
	_TranslationsGroupGroupGridPagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String failedToLoadMessage({required Object error}) => 'Falha ao carregar os grupos:\n${error}';
	@override String get unknownErrorFallback => 'erro desconhecido';
	@override String get noGroupsYetMessage => 'Nenhum grupo ainda — toque em + para criar um.';
}

// Path: group.tileAutoChatDelay
class _TranslationsGroupTileAutoChatDelayPtBr extends _TranslationsGroupTileAutoChatDelayEn {
	_TranslationsGroupTileAutoChatDelayPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Atraso da conversa automática';
	@override String secondsAbbrev({required Object seconds}) => '${seconds}s';
}

// Path: group.tileActivationStrategy
class _TranslationsGroupTileActivationStrategyPtBr extends _TranslationsGroupTileActivationStrategyEn {
	_TranslationsGroupTileActivationStrategyPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Seleção de quem fala';
	@override String get naturalOption => 'Natural';
	@override String get roundRobinOption => 'Rodízio';
	@override String get randomOption => 'Aleatório';
	@override String get changeSelectionTooltip => 'Alterar seleção de quem fala';
}

// Path: group.groupChatPageEndDrawer
class _TranslationsGroupGroupChatPageEndDrawerPtBr extends _TranslationsGroupGroupChatPageEndDrawerEn {
	_TranslationsGroupGroupChatPageEndDrawerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get allowWebFetchTitle => 'Permitir busca na web';
	@override String get allowWebFetchSubtitle => 'Ler páginas web públicas quando relevante';
	@override String get reviewUrlTitle => 'Revisar URL antes de buscar';
	@override String get reviewUrlSubtitle => 'Confirmar cada busca';
	@override String get suggestNpcNamesTitle => 'Sugerir nomes de NPC';
	@override String get suggestNpcNamesSubtitle => 'Escolher nomes do banco de dados curado';
	@override String get unrestrictedImagesTitle => 'Imagens sem restrição';
	@override String get allowNsfwImagePromptsSubtitle => 'Permitir prompts de imagem NSFW';
	@override String get characterCanSendSelfiesTitle => 'Personagem pode enviar selfies';
	@override String get attachSelfieWhenNaturalSubtitle => 'Anexar uma selfie quando natural';
	@override String get reviewImagePromptTitle => 'Revisar prompt de imagem';
	@override String get editBeforeGeneratingSubtitle => 'Editar antes de gerar';
	@override String get reviewToolImagePromptsTitle => 'Revisar prompts de imagem das ferramentas';
	@override String get editToolTriggeredPromptsSubtitle => 'Editar prompts acionados por ferramentas';
	@override String get allowSelfieCaptionsTitle => 'Permitir legendas de selfie';
	@override String get captionRenderedOnImageSubtitle => 'Legenda renderizada sobre a imagem';
	@override String get groupOverridesTitle => 'Substituições do grupo';
	@override String get groupOverridesSubtitle => 'Cenário, prompt principal e diálogo de exemplo compartilhados';
	@override String get chatSessionSubtitle => 'Sessão de conversa';
	@override String get allChatsLabel => 'Todas as conversas';
	@override String get showImageLabel => 'Mostrar imagem';
	@override String get groupSectionHeader => 'Grupo';
	@override String get chatSectionHeader => 'Conversa';
	@override String get chatThemeSectionHeader => 'Tema da conversa';
	@override String get unrestrictedVideosTitle => 'Vídeos sem restrição';
	@override String get allowNsfwVideoPromptsSubtitle => 'Permitir prompts de vídeo NSFW';
	@override String get characterCanSendVideosTitle => 'Personagem pode enviar vídeos';
	@override String get attachShortVideoWhenNaturalSubtitle => 'Anexar um vídeo curto quando natural';
	@override String get reviewVideoPromptTitle => 'Revisar prompt de vídeo';
}

// Path: group.groupCharacterPicker
class _TranslationsGroupGroupCharacterPickerPtBr extends _TranslationsGroupGroupCharacterPickerEn {
	_TranslationsGroupGroupCharacterPickerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get addButton => 'Adicionar';
	@override String addWithCountButton({required Object count}) => 'Adicionar ${count}';
	@override String get favoritesTooltip => 'Favoritos';
	@override String noMatchMessage({required Object query}) => 'Nenhum personagem corresponde a "${query}"';
	@override String get noFavoritesMessage => 'Nenhum personagem favoritado disponível';
	@override String get allAddedMessage => 'Todos os personagens já foram adicionados';
}

// Path: group.groupCharacterTile
class _TranslationsGroupGroupCharacterTilePtBr extends _TranslationsGroupGroupCharacterTileEn {
	_TranslationsGroupGroupCharacterTilePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get speakTooltip => 'Fazer este personagem falar';
	@override String get removeFromChatTitle => 'Remover da conversa';
}

// Path: group.dialogCreateGroup
class _TranslationsGroupDialogCreateGroupPtBr extends _TranslationsGroupDialogCreateGroupEn {
	_TranslationsGroupDialogCreateGroupPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Novo grupo';
	@override String get nameLabel => 'Nome';
	@override String get nameHint => 'ex.: Bob e Alice';
}

// Path: group.dialogGroupOverrides
class _TranslationsGroupDialogGroupOverridesPtBr extends _TranslationsGroupDialogGroupOverridesEn {
	_TranslationsGroupDialogGroupOverridesPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get explanationMessage => 'Exclusivo desta conversa. Todos os membros do grupo usam estes valores em vez do que os cartões de personagem definem. Deixe vazio para voltar ao valor do cartão.';
	@override String get scenarioHint => 'Ambiente compartilhado do grupo (ex.: "Em um café em Paris")';
	@override String get mainPromptLabel => 'Prompt principal';
	@override String get mainPromptHint => 'Prompt do sistema aplicado a cada turno';
	@override String get exampleDialogueLabel => 'Diálogo de exemplo';
	@override String get exampleDialogueHint => 'Mensagens de exemplo compartilhadas para tom / formatação';
}

// Path: group.groupCharacterPanel
class _TranslationsGroupGroupCharacterPanelPtBr extends _TranslationsGroupGroupCharacterPanelEn {
	_TranslationsGroupGroupCharacterPanelPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get addCharacterButton => 'Adicionar personagem';
	@override String get noCharactersYetMessage => 'Nenhum personagem ainda.\nToque em + para adicionar um.';
}

// Path: group.dialogSelectGroup
class _TranslationsGroupDialogSelectGroupPtBr extends _TranslationsGroupDialogSelectGroupEn {
	_TranslationsGroupDialogSelectGroupPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get deleteGroupTitle => 'Excluir grupo?';
	@override String deleteGroupMessage({required Object name}) => '"${name}" e todas as suas sessões de conversa serão removidas permanentemente.';
	@override String get title => 'Grupos';
	@override String get noGroupsYetMessage => 'Nenhum grupo ainda. Toque em "Novo grupo" para criar um.';
	@override String memberCountLabel({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
		one: '${n} membro',
		other: '${n} membros',
	);
}

// Path: group.groupGridItem
class _TranslationsGroupGroupGridItemPtBr extends _TranslationsGroupGroupGridItemEn {
	_TranslationsGroupGroupGridItemPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String overflowCountBadge({required Object count}) => '+${count}';
	@override String get noMembersYetMessage => 'Ainda sem membros';
}

// Path: group.groupFileService
class _TranslationsGroupGroupFileServicePtBr extends _TranslationsGroupGroupFileServiceEn {
	_TranslationsGroupGroupFileServicePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get defaultGroupName => 'Grupo';
}

// Path: llmApp.mediaField
class _TranslationsLlmAppMediaFieldPtBr extends _TranslationsLlmAppMediaFieldEn {
	_TranslationsLlmAppMediaFieldPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get imageModel => 'Modelo de imagem';
	@override String get imageAspectRatio => 'Proporção da imagem';
	@override String get imageNsfwAllowed => 'Permitir imagens NSFW';
	@override String get imageToolSelfieAllowed => 'Pode enviar selfies';
	@override String get imageToolSelfieCaptionsAllowed => 'Permitir legendas de selfie';
	@override String get imagePromptPrefix => 'Estilo de imagem';
	@override String get videoModel => 'Modelo de vídeo';
	@override String get videoResolution => 'Resolução do vídeo';
	@override String get videoAspectRatio => 'Proporção do vídeo';
	@override String get videoDuration => 'Duração do vídeo';
	@override String get videoNsfwAllowed => 'Permitir vídeos NSFW';
	@override String get videoToolSendAllowed => 'Pode enviar vídeos';
	@override String get videoPromptPrefix => 'Estilo de vídeo';
	@override String get ttsModel => 'Modelo de TTS';
	@override String get ttsVoice => 'Voz do TTS';
	@override String get ttsLanguage => 'Idioma do TTS';
	@override String get webToolFetchAllowed => 'Permitir busca na web';
	@override String get nameToolSuggestAllowed => 'Pode sugerir nomes de NPC';
}

// Path: llmApp.mediaSection
class _TranslationsLlmAppMediaSectionPtBr extends _TranslationsLlmAppMediaSectionEn {
	_TranslationsLlmAppMediaSectionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get image => 'Imagem';
	@override String get video => 'Vídeo';
	@override String get tts => 'TTS';
	@override String get web => 'Web';
	@override String get names => 'Nomes';
}

// Path: llmApp.tristate
class _TranslationsLlmAppTristatePtBr extends _TranslationsLlmAppTristateEn {
	_TranslationsLlmAppTristatePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get on => 'Ligado';
	@override String get off => 'Desligado';
	@override String get inherit => 'Herdar';
}

// Path: llmApp.mediaCellMenu
class _TranslationsLlmAppMediaCellMenuPtBr extends _TranslationsLlmAppMediaCellMenuEn {
	_TranslationsLlmAppMediaCellMenuPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get change => 'Alterar…';
	@override String get clear => 'Limpar';
}

// Path: llmApp.mediaHeader
class _TranslationsLlmAppMediaHeaderPtBr extends _TranslationsLlmAppMediaHeaderEn {
	_TranslationsLlmAppMediaHeaderPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get appDefault => 'Padrão do app';
	@override String get character => 'Personagem';
	@override String get currentChat => 'Conversa atual';
	@override String get previousLayerTooltip => 'Camada anterior';
	@override String get nextLayerTooltip => 'Próxima camada';
}

// Path: llmApp.presetRow
class _TranslationsLlmAppPresetRowPtBr extends _TranslationsLlmAppPresetRowEn {
	_TranslationsLlmAppPresetRowPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get changeAppDefaultTitle => 'Alterar o padrão do app?';
	@override String get changeAppDefaultMessage => 'Isso afeta todas as conversas. Continuar?';
	@override String get continueButton => 'Continuar';
	@override String chooseModelTitle({required Object domain}) => 'Escolha um modelo de ${domain}';
}

// Path: llmApp.mediaCell
class _TranslationsLlmAppMediaCellPtBr extends _TranslationsLlmAppMediaCellEn {
	_TranslationsLlmAppMediaCellPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get notApplicable => 'Não aplicável';
}

// Path: onboarding.storageStep
class _TranslationsOnboardingStorageStepPtBr extends _TranslationsOnboardingStorageStepEn {
	_TranslationsOnboardingStorageStepPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Armazenamento de personagens';
	@override String get subtitle => 'Onde devemos salvar seus cartões de personagem?';
	@override String get description => 'Salvos na pasta do app por padrão. Aponte para uma pasta PNG existente para importar.';
	@override String get startFresh => 'Começar do zero';
	@override String get haveCards => 'Já tenho cartões';
	@override String get importLaterHint => 'Importe PNGs depois em Arquivo → Importar.';
	@override String selectedPath({required Object path}) => 'Selecionado: ${path}';
	@override String get selectedDefaultFolder => 'Selecionado: pasta padrão do app';
	@override String get noFolderSelected => 'Nenhuma pasta selecionada ainda.';
}

// Path: onboarding.setupStep
class _TranslationsOnboardingSetupStepPtBr extends _TranslationsOnboardingSetupStepEn {
	_TranslationsOnboardingSetupStepPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'IA e persona';
}

// Path: onboarding.aiSection
class _TranslationsOnboardingAiSectionPtBr extends _TranslationsOnboardingAiSectionEn {
	_TranslationsOnboardingAiSectionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get heading => 'Conexão de IA';
	@override String get optionalHint => 'Opcional — pule e adicione uma chave depois nas Configurações (provedores locais também podem ser adicionados lá).';
	@override String get apiKeyLabel => 'API key';
	@override String get apiKeyHint => 'Cole sua chave (ou pule por enquanto)';
	@override String get supportedProviders => 'Suporta OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. Mais nas Configurações.';
	@override String get unknownModel => '(modelo desconhecido)';
	@override String get ctxUnknown => 'ctx —';
	@override String ctxValue({required Object ctx}) => 'ctx ${ctx}';
	@override String kvSuffix({required Object kv}) => ' · KV ${kv}';
	@override String get changeButton => 'Alterar';
}

// Path: onboarding.aiStatus
class _TranslationsOnboardingAiStatusPtBr extends _TranslationsOnboardingAiStatusEn {
	_TranslationsOnboardingAiStatusPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get connecting => 'Conectando…';
	@override String connected({required Object provider}) => 'Conectado a ${provider}. Modelo de conversa padrão selecionado.';
	@override String detected({required Object provider}) => 'Detectado: ${provider}';
	@override String get unrecognizedKey => 'Formato de chave não reconhecido.';
}

// Path: onboarding.personaSection
class _TranslationsOnboardingPersonaSectionPtBr extends _TranslationsOnboardingPersonaSectionEn {
	_TranslationsOnboardingPersonaSectionPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get heading => 'Sua persona';
	@override String get hint => 'Seu nome nas conversas. Mais detalhes da persona nas Configurações.';
	@override String get nameLabel => 'Seu nome';
}

// Path: onboarding.disclaimer
class _TranslationsOnboardingDisclaimerPtBr extends _TranslationsOnboardingDisclaimerEn {
	_TranslationsOnboardingDisclaimerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get prefix => 'Li e concordo com o ';
	@override String get linkText => 'Aviso legal';
}

// Path: onboarding.fetchError
class _TranslationsOnboardingFetchErrorPtBr extends _TranslationsOnboardingFetchErrorEn {
	_TranslationsOnboardingFetchErrorPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noModels => 'Nenhum modelo retornado. Verifique sua API key.';
	@override String get connectionFailed => 'Não foi possível conectar. Verifique sua conexão com a internet e a API key.';
}

// Path: routing.chatCharacter
class _TranslationsRoutingChatCharacterPtBr extends _TranslationsRoutingChatCharacterEn {
	_TranslationsRoutingChatCharacterPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object name}) => 'Erro de navegação para a conversa. Personagem: ${name}';
}

// Path: routing.editCharacter
class _TranslationsRoutingEditCharacterPtBr extends _TranslationsRoutingEditCharacterEn {
	_TranslationsRoutingEditCharacterPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object name}) => 'Erro de navegação para a edição. Personagem: ${name}';
}

// Path: routing.editPreset
class _TranslationsRoutingEditPresetPtBr extends _TranslationsRoutingEditPresetEn {
	_TranslationsRoutingEditPresetPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String navigationError({required Object presetId}) => 'Erro de navegação para editar a predefinição: ${presetId}';
}

// Path: settings.gearMenu
class _TranslationsSettingsGearMenuPtBr extends _TranslationsSettingsGearMenuEn {
	_TranslationsSettingsGearMenuPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get settingsTooltip => 'Configurações';
	@override String get mediaDefaultsApp => 'App';
	@override String get mediaDefaultsCharacter => 'Personagem';
	@override String get mediaDefaultsChat => 'Conversa';
	@override String get appSettings => 'Configurações do app';
	@override String get logs => 'Logs';
}

// Path: settings.mediaDefaultsDrawerEntry
class _TranslationsSettingsMediaDefaultsDrawerEntryPtBr extends _TranslationsSettingsMediaDefaultsDrawerEntryEn {
	_TranslationsSettingsMediaDefaultsDrawerEntryPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get configurationHeader => 'Configuração';
}

// Path: settings.endDrawer
class _TranslationsSettingsEndDrawerPtBr extends _TranslationsSettingsEndDrawerEn {
	_TranslationsSettingsEndDrawerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get switchPersonaTooltip => 'Trocar de persona';
}

// Path: settings.loadingStatus
class _TranslationsSettingsLoadingStatusPtBr extends _TranslationsSettingsLoadingStatusEn {
	_TranslationsSettingsLoadingStatusPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get restoringProviders => 'Restaurando provedores…';
	@override String fetchingModelsProgress({required Object completed, required Object total}) => 'Buscando modelos (${completed}/${total})…';
}

// Path: settings.general
class _TranslationsSettingsGeneralPtBr extends _TranslationsSettingsGeneralEn {
	_TranslationsSettingsGeneralPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get characterFolderTitle => 'Pasta de personagens';
	@override String get characterFolderNotSet => 'Não definida. Necessária para o app funcionar.';
	@override String get browseButton => 'Procurar...';
	@override String get taxonomyTagsTitle => 'Tags de taxonomia';
	@override String get appThemeTitle => 'Tema do app';
	@override String get themeSystem => 'Sistema';
	@override String get themeLight => 'Claro';
	@override String get themeDark => 'Escuro';
	@override String get themeStyleTitle => 'Estilo do tema';
	@override String get themeStyleDefault => 'Padrão';
	@override String get themeStyleNeon => 'Neon';
	@override String get storyMemoryTitle => 'Memória da história';
	@override String get storyMemorySubtitle => 'Lembra momentos anteriores e traz os relevantes de volta em conversas longas.';
	@override String get narrativeEngineTitle => 'Motor narrativo';
	@override String get narrativeEngineSubtitle => 'Acompanha a cena e os personagens e faz a história avançar enquanto você conversa.';
	@override String get promptBreakdownTitle => 'Mostrar detalhamento do prompt';
	@override String get promptBreakdownSubtitle => 'Mostra uma barra sob cada resposta detalhando como o prompt preencheu a janela de contexto do modelo.';
	@override String get checkUpdatesTitle => 'Verificar atualizações';
	@override String get checkUpdatesSubtitle => 'Verificar se há uma versão mais nova do app disponível.';
	@override String get websiteTitle => 'Site';
	@override String get websiteSubtitle => 'Visite o site oficial para atualizações e informações.';
	@override String get disclaimerTitle => 'Aviso legal e termos';
	@override String get disclaimerSubtitle => 'Leia o aviso legal e os termos de uso do aplicativo.';
	@override String versionLabel({required Object version, required Object buildNumber}) => 'Versão ${version}+${buildNumber}';
}

// Path: settings.aiSettingsTab
class _TranslationsSettingsAiSettingsTabPtBr extends _TranslationsSettingsAiSettingsTabEn {
	_TranslationsSettingsAiSettingsTabPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get aiProviders => 'Provedores de IA';
	@override String get mediaDefaults => 'Padrões de mídia';
}

// Path: settings.aiTab
class _TranslationsSettingsAiTabPtBr extends _TranslationsSettingsAiTabEn {
	_TranslationsSettingsAiTabPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String refreshSummary({required Object updated, required Object unavailable, required Object errors}) => '${updated} modelos atualizados, ${unavailable} indisponíveis, ${errors} erros.';
	@override String get newProviderButton => 'Novo provedor';
	@override String get cloudProviderMenuItem => 'Provedor na nuvem';
	@override String get localProviderMenuItem => 'Provedor local';
	@override String get localGgufMenuItem => 'GGUF local';
	@override String get noProvidersConfigured => 'Nenhum provedor de API configurado.';
	@override String get addingProviderOverlay => 'Adicionando provedor…';
	@override String get neverRefreshed => 'Nunca atualizado';
	@override String lastRefreshedLabel({required Object time}) => 'Última atualização: ${time}';
	@override String get refreshModelsButton => 'Atualizar modelos';
	@override String get refreshNowMenuItem => 'Atualizar agora';
	@override String get autoNeverMenuItem => 'Auto: Nunca';
	@override String get autoDailyMenuItem => 'Auto: Diariamente ao iniciar';
	@override String get defaultModelsHeader => 'Modelos padrão para novas conversas';
	@override String get editModelTooltip => 'Editar modelo';
	@override String get noModelsPlaceholder => 'Sem modelos';
	@override String get noCompatibleModelsPlaceholder => 'Nenhum modelo compatível';
	@override String get tapToChoosePlaceholder => 'Toque para escolher';
	@override String get modelUsedForPrefix => 'Modelo usado para ';
	@override String get modelUsedForSuffix => ' geração';
	@override String get chooseModelTitle => 'Escolha um modelo';
	@override String temperatureLabel({required Object value}) => 'Temp ${value}';
	@override String get setDefaultButton => 'Definir padrão';
	@override String get addModelButton => 'Adicionar modelo';
	@override String get editProviderMenuItem => 'Editar provedor';
	@override String get moreTooltip => 'Mais';
	@override String get noModelsForProvider => 'Nenhum modelo configurado para este provedor.';
	@override String setDefaultConfirmTitle({required Object provider}) => 'Definir ${provider} como padrão para todos os recursos de IA?';
	@override String get setDefaultConfirmMessage => 'Você pode escolher modelos para recursos não suportados\n(como imagem ou vídeo) de outros provedores por conta própria.';
	@override String localGgufSubtitle({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (máx ${native}) · KV ${kv}';
	@override String get testTtsTooltip => 'Testar TTS';
	@override String get ttsTestPhrase => 'Olá, isto é um teste.';
	@override String get ttsFailedError => 'TTS falhou.';
	@override String get testVideoTooltip => 'Testar geração de vídeo';
	@override String get videoGeneratedWebFallback => 'Vídeo gerado com sucesso (prévia indisponível na web).';
	@override String get videoFailedError => 'Vídeo falhou.';
	@override String get videoLoadFailedMessage => 'Não foi possível carregar o vídeo gerado.';
	@override String get presetPickerSearchHint => 'Buscar por provedor, modelo ou predefinição…';
	@override String tempParamAbbrev({required Object value}) => 'temp ${value}';
	@override String reasoningParamLabel({required Object level}) => 'raciocínio ${level}';
}

// Path: settings.presetConfig
class _TranslationsSettingsPresetConfigPtBr extends _TranslationsSettingsPresetConfigEn {
	_TranslationsSettingsPresetConfigPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get testMessageButton => 'Mensagem de teste';
	@override String get testSuccessLabel => 'Sucesso';
	@override String get testFailedLabel => 'Falhou';
	@override String get deleteModelTitle => 'Excluir modelo?';
	@override String deleteModelMessage({required Object name}) => 'Excluir "${name}" permanentemente? Isso não pode ser desfeito.';
	@override String get editModelHeader => 'Editar modelo';
	@override String get addModelHeader => 'Adicionar modelo';
	@override String get resetToDefaultsTooltip => 'Redefinir para os padrões';
	@override String get modelNameLabel => 'Nome do modelo';
	@override String get clearTooltip => 'Limpar';
	@override String get nameRequiredError => 'O nome é obrigatório';
	@override String get modelLabel => 'Modelo';
	@override String get selectModelHint => 'Selecione um modelo';
	@override String get modelRequiredError => 'O modelo é obrigatório';
	@override String filteredDomainsNote({required Object domains}) => 'Os modelos são filtrados para suportar os domínios ativos: ${domains}';
	@override String get requiredValidator => 'Obrigatório';
	@override String get invalidValidator => 'Inválido';
	@override String get testResponseTitle => 'Resposta';
}

// Path: settings.providerConfig
class _TranslationsSettingsProviderConfigPtBr extends _TranslationsSettingsProviderConfigEn {
	_TranslationsSettingsProviderConfigPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noModelsError => 'Nenhum modelo retornado. Verifique sua API key.';
	@override String get connectionFailedError => 'Não foi possível conectar. Verifique sua conexão com a internet e a API key.';
	@override String get deleteProviderTitle => 'Excluir provedor?';
	@override String deleteProviderMessage({required Object provider}) => 'Excluir permanentemente o provedor ${provider} e todas as suas predefinições? Isso não pode ser desfeito.';
	@override String lockHint({required Object roles}) => 'Não é possível excluir: em uso por ${roles}.';
	@override String get editProviderHeader => 'Editar provedor';
	@override String get addProviderHeader => 'Adicionar provedor';
	@override String get apiKeyLabel => 'API key';
	@override String get apiKeyHintRotate => 'Cole uma nova chave para trocar';
	@override String get apiKeyHintNew => 'Cole sua chave — o provedor é detectado automaticamente';
	@override String get supportedProvidersNote => 'Suporta OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
	@override String keyMismatchError({required Object owner, required Object profile}) => 'Esta chave pertence a ${owner}, mas este perfil é ${profile}. Exclua este perfil e adicione um novo.';
	@override String get anotherProviderFallback => 'outro provedor';
	@override String get connectingStatus => 'Conectando…';
	@override String connectedStatus({required Object provider}) => 'Conectado a ${provider}. Predefinições padrão serão criadas.';
	@override String detectedStatus({required Object provider}) => 'Detectado: ${provider}';
	@override String get unrecognizedKeyStatus => 'Formato de chave não reconhecido.';
}

// Path: settings.localProviderConfig
class _TranslationsSettingsLocalProviderConfigPtBr extends _TranslationsSettingsLocalProviderConfigEn {
	_TranslationsSettingsLocalProviderConfigPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String serverUnreachableMessage({required Object url}) => 'Não foi possível acessar ${url}. Verifique se o seu servidor local (KoboldCpp / Ollama / LM Studio / llama.cpp) está em execução.';
	@override String get noModelsError => 'Servidor acessível, mas não retornou modelos. Carregue um modelo no seu servidor local primeiro.';
	@override String get deleteProviderMessage => 'Excluir permanentemente este provedor local e todas as suas predefinições? Isso não pode ser desfeito.';
	@override String get editHeader => 'Editar provedor local';
	@override String get addHeader => 'Adicionar provedor local';
	@override String get serverUrlLabel => 'URL do servidor';
	@override String get serverUrlLockedHelper => 'Bloqueado. Exclua este provedor e adicione um novo para apontar para outro servidor.';
	@override String get apiKeyOptionalLabel => 'API key (opcional)';
	@override String get apiKeyOptionalHint => 'Deixe em branco — a maioria dos servidores locais não precisa de uma';
	@override String get connectFetchButton => 'Conectar e buscar modelos';
	@override String connectedFoundModels({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
		one: 'Conectado. ${n} modelo encontrado.',
		other: 'Conectado. ${n} modelos encontrados.',
	);
}

// Path: settings.localGguf
class _TranslationsSettingsLocalGgufPtBr extends _TranslationsSettingsLocalGgufEn {
	_TranslationsSettingsLocalGgufPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get haveLocalGgufExpanderTitle => 'Tenho um arquivo GGUF local';
	@override String get pickFileLabel => 'Escolher arquivo GGUF...';
	@override String get loadModelLabel => 'Carregar modelo';
	@override String get nativeContextLabel => 'Contexto nativo';
	@override String get freeVramLabel => 'VRAM livre';
	@override String get contextSizeLabel => 'Tamanho do contexto';
	@override String get kvCacheLabel => 'Cache KV';
	@override String get kvCacheAutoLabel => 'Auto';
	@override String modelTooLargeForVramMessage({required Object neededMb, required Object freeMb}) => 'Este modelo precisa de cerca de ${neededMb}MB de memória da GPU, mas só há ${freeMb}MB livres. Feche outros apps que usam a GPU ou escolha um modelo menor / mais quantizado.';
	@override String modelBarelyFitsMessage({required Object minimumContext}) => 'Este modelo mal cabe mesmo com cache KV q4_0 em ${minimumContext} tokens. Considere um arquivo de modelo mais agressivamente quantizado.';
	@override String get readingMetadata => 'Lendo metadados do modelo…';
	@override String get architectureLabel => 'Arquitetura';
	@override String autoKvHint({required Object picked, required Object max}) => 'auto: ${picked} (máx ${max})';
	@override String maxKvHint({required Object max, required Object picked}) => 'máx ${max} com KV ${picked}';
	@override String ctxExceedsMaxError({required Object max, required Object picked}) => 'acima de ${max} com KV ${picked} — o carregamento pode causar OOM';
	@override String get vramNotDetected => 'não detectada';
	@override String readMetadataFailedError({required Object error}) => 'Falha ao ler metadados GGUF: ${error}';
	@override String loadModelFailedError({required Object error}) => 'Falha ao carregar o modelo: ${error}';
}

// Path: settings.personaDialog
class _TranslationsSettingsPersonaDialogPtBr extends _TranslationsSettingsPersonaDialogEn {
	_TranslationsSettingsPersonaDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get newTitle => 'Nova persona';
	@override String get editTitle => 'Editar persona';
	@override String get nameLabel => 'Nome';
	@override String get nameRequiredError => 'O nome é obrigatório';
	@override String get descriptionLabel => 'Descrição';
	@override String get descriptionHint => 'Aparência, personalidade, histórico etc.';
}

// Path: settings.personasTab
class _TranslationsSettingsPersonasTabPtBr extends _TranslationsSettingsPersonasTabEn {
	_TranslationsSettingsPersonasTabPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get cannotDeleteDefaultTooltip => 'Não é possível excluir a persona padrão';
	@override String get deleteTooltip => 'Excluir persona';
	@override String get cannotDeleteDefaultSnackbar => 'Não é possível excluir a persona padrão.';
	@override String get deleteConfirmTitle => 'Excluir persona';
	@override String deleteConfirmMessage({required Object name}) => 'Tem certeza de que deseja excluir "${name}"?';
}

// Path: settings.updateCheck
class _TranslationsSettingsUpdateCheckPtBr extends _TranslationsSettingsUpdateCheckEn {
	_TranslationsSettingsUpdateCheckPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get upToDateTitle => 'Atualizado';
	@override String upToDateMessage({required Object version}) => 'Você está na versão atual (${version}).';
	@override String get notApplicableTitle => 'Verificação de atualização';
	@override String get notApplicableMessage => 'A verificação de versão não se aplica na Web.';
	@override String get errorTitle => 'Erro';
	@override String get serverErrorMessage => 'Não foi possível verificar atualizações. Erro do servidor.';
	@override String get connectionErrorMessage => 'Não foi possível verificar atualizações. Verifique sua conexão.';
}

// Path: workspace.workspaceEndDrawerImage
class _TranslationsWorkspaceWorkspaceEndDrawerImagePtBr extends _TranslationsWorkspaceWorkspaceEndDrawerImageEn {
	_TranslationsWorkspaceWorkspaceEndDrawerImagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get imageStyleTitle => 'Estilo de imagem';
	@override String get noneValue => 'Nenhum';
}

// Path: workspace.workspaceEndDrawerVideo
class _TranslationsWorkspaceWorkspaceEndDrawerVideoPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerVideoEn {
	_TranslationsWorkspaceWorkspaceEndDrawerVideoPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get videoStyleTitle => 'Estilo de vídeo';
}

// Path: workspace.workspaceEndDrawerDisplay
class _TranslationsWorkspaceWorkspaceEndDrawerDisplayPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerDisplayEn {
	_TranslationsWorkspaceWorkspaceEndDrawerDisplayPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Exibição';
	@override String get showCharacterImageTitle => 'Mostrar imagem do personagem';
	@override String get wideScreenOnlySubtitle => 'Apenas no editor de tela larga';
}

// Path: workspace.workspaceEndDrawerAi
class _TranslationsWorkspaceWorkspaceEndDrawerAiPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerAiEn {
	_TranslationsWorkspaceWorkspaceEndDrawerAiPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'IA';
}

// Path: workspace.workspaceEndDrawerEditing
class _TranslationsWorkspaceWorkspaceEndDrawerEditingPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerEditingEn {
	_TranslationsWorkspaceWorkspaceEndDrawerEditingPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Edição';
}

// Path: workspace.workspaceEndDrawerExport
class _TranslationsWorkspaceWorkspaceEndDrawerExportPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerExportEn {
	_TranslationsWorkspaceWorkspaceEndDrawerExportPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get sectionHeader => 'Exportar';
	@override String get exportPngTitle => 'Exportar como PNG (V2/V3)';
	@override String get exportJsonV3Title => 'Exportar como JSON (V3)';
	@override String get exportJsonV2Title => 'Exportar como JSON (V2)';
}

// Path: workspace.workspaceEndDrawerChatTheme
class _TranslationsWorkspaceWorkspaceEndDrawerChatThemePtBr extends _TranslationsWorkspaceWorkspaceEndDrawerChatThemeEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatThemePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get resetImagesTitle => 'Redefinir imagens';
}

// Path: workspace.workspaceEndDrawerChat
class _TranslationsWorkspaceWorkspaceEndDrawerChatPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerChatEn {
	_TranslationsWorkspaceWorkspaceEndDrawerChatPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get assistantCardEditsSectionHeader => 'Edições de cartão pelo assistente';
}

// Path: workspace.workspaceEndDrawer
class _TranslationsWorkspaceWorkspaceEndDrawerPtBr extends _TranslationsWorkspaceWorkspaceEndDrawerEn {
	_TranslationsWorkspaceWorkspaceEndDrawerPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get favoriteLabel => 'Favorito';
	@override String get nodesEngineTitle => 'Motor NODES';
	@override String get debugSnapshotSubtitle => 'Captura de depuração';
	@override String get characterSubtitle => 'Personagem';
}

// Path: workspace.stylePresetsDialog
class _TranslationsWorkspaceStylePresetsDialogPtBr extends _TranslationsWorkspaceStylePresetsDialogEn {
	_TranslationsWorkspaceStylePresetsDialogPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noStyleSelectedMessage => 'Nenhum estilo selecionado';
}

// Path: workspace.workspacePage
class _TranslationsWorkspaceWorkspacePagePtBr extends _TranslationsWorkspaceWorkspacePageEn {
	_TranslationsWorkspaceWorkspacePagePtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get rebuildingChatIndexMessage => 'Reconstruindo índice de conversas...';
	@override String get selectChatToStartMessagingMessage => 'Selecione uma conversa para começar';
	@override String get failedToLoadAssistantMessage => 'Falha ao carregar o assistente.';
}

// Path: character.cardEditApproval.modalityLabel
class _TranslationsCharacterCardEditApprovalModalityLabelPtBr extends _TranslationsCharacterCardEditApprovalModalityLabelEn {
	_TranslationsCharacterCardEditApprovalModalityLabelPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get edits => 'edições';
	@override String get additions => 'adições';
	@override String get deletions => 'exclusões';
}

// Path: character.cardEditApproval.modalityVerb
class _TranslationsCharacterCardEditApprovalModalityVerbPtBr extends _TranslationsCharacterCardEditApprovalModalityVerbEn {
	_TranslationsCharacterCardEditApprovalModalityVerbPtBr._(_TranslationsPtBr root) : this._root = root, super._(root);

	@override final _TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get edit => 'Editar';
	@override String get addition => 'Adicionar a';
	@override String get deletion => 'Remover de';
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
			case 'app.appBootstrapper.failedToInitializeMessage': return ({required Object error}) => 'Falha ao inicializar o app:\n\n${error}';
			case 'character.promptPrefixDialog.styleKeywordsLabel': return 'Palavras-chave de estilo';
			case 'character.promptPrefixDialog.imageTitle': return 'Estilo de imagem';
			case 'character.promptPrefixDialog.imageDescription': return 'Adicionado no início de cada prompt de geração de imagem deste personagem (ex.: "estilo anime, cores vibrantes").';
			case 'character.promptPrefixDialog.imageHint': return 'estilo anime, cores vibrantes';
			case 'character.promptPrefixDialog.videoTitle': return 'Estilo de vídeo';
			case 'character.promptPrefixDialog.videoDescription': return 'Adicionado no início de cada prompt de geração de vídeo deste personagem (ex.: "cinematográfico, profundidade de campo rasa, granulação de filme 24fps"). Modelos de vídeo respondem a vocabulário de movimento e câmera; mantenha curto.';
			case 'character.promptPrefixDialog.videoHint': return 'cinematográfico, profundidade de campo rasa';
			case 'character.cardEditApproval.denyAll': return 'Recusar tudo';
			case 'character.cardEditApproval.approveAll': return 'Aprovar tudo';
			case 'character.cardEditApproval.confirm': return 'Confirmar';
			case 'character.cardEditApproval.dialogTitle': return 'O assistente propôs alterações';
			case 'character.cardEditApproval.dontAskAgainFor': return ({required Object modality}) => 'Não perguntar de novo para ${modality}';
			case 'character.cardEditApproval.modalityLabel.edits': return 'edições';
			case 'character.cardEditApproval.modalityLabel.additions': return 'adições';
			case 'character.cardEditApproval.modalityLabel.deletions': return 'exclusões';
			case 'character.cardEditApproval.modalityVerb.edit': return 'Editar';
			case 'character.cardEditApproval.modalityVerb.addition': return 'Adicionar a';
			case 'character.cardEditApproval.modalityVerb.deletion': return 'Remover de';
			case 'character.cardEditApproval.tapToDeny': return 'Toque para recusar';
			case 'character.cardEditApproval.tapToApprove': return 'Toque para aprovar';
			case 'character.cardEditApproval.reasonLabel': return 'Motivo (opcional, enviado de volta ao assistente)';
			case 'character.cardEditApproval.newEntryTitle': return 'Nova entrada';
			case 'character.cardEditApproval.removingTitle': return 'Removendo';
			case 'character.cardEditApproval.beforeTitle': return 'Antes';
			case 'character.cardEditApproval.afterTitle': return 'Depois';
			case 'character.requireApprovalTile.edits': return 'Exigir aprovação: edições';
			case 'character.requireApprovalTile.additions': return 'Exigir aprovação: adições';
			case 'character.requireApprovalTile.deletions': return 'Exigir aprovação: exclusões';
			case 'character.loadingStatus.initial': return 'Carregando...';
			case 'character.loadingStatus.copyingAssistant': return 'Copiando assistente...';
			case 'character.loadingStatus.scanningForCharacters': return 'Procurando personagens...';
			case 'character.loadingStatus.scanningForCharactersProgress': return ({required Object current, required Object total}) => 'Procurando personagens...\n${current} / ${total}';
			case 'character.loadingStatus.loadingCharactersProgress': return ({required Object current, required Object total}) => 'Carregando personagens...\n${current} / ${total}';
			case 'character.savePathValidation.noLibraryFolder': return 'Nenhuma pasta de biblioteca configurada.';
			case 'character.savePathValidation.mustBeInsideLibrary': return 'Os personagens devem ser salvos dentro da sua pasta de biblioteca.';
			case 'character.characterFilesTypeGroupLabel': return 'Arquivos de personagem';
			case 'character.createController.pngImagesTypeGroupLabel': return 'Imagens PNG';
			case 'character.createController.invalidLocationTitle': return 'Local inválido';
			case 'character.createController.creationFailedTitle': return 'Falha na criação';
			case 'character.createController.creationFailedMessage': return 'Não foi possível criar o personagem. Veja os logs para detalhes.';
			case 'character.importController.failedToImport': return ({required Object fileName}) => 'Falha ao importar ${fileName}.';
			case 'character.importController.importedCount': return ({required Object count}) => '${count} personagens importados';
			case 'character.aiActionController.aiActionFailed': return 'Ação de IA falhou. Veja os logs para detalhes.';
			case 'character.aiActionController.processingProgress': return ({required Object name, required Object current, required Object total, required Object eta}) => 'Processando ${name} (${current}/${total})...${eta}';
			case 'character.aiActionController.etaHoursMinutes': return ({required Object hours, required Object minutes}) => ' Restante: ${hours}h ${minutes}m';
			case 'character.aiActionController.etaMinutesSeconds': return ({required Object minutes, required Object seconds}) => ' Restante: ${minutes}m ${seconds}s';
			case 'character.aiActionController.etaSeconds': return ({required Object seconds}) => ' Restante: ${seconds}s';
			case 'character.aiActionController.processingField': return ({required Object fieldName}) => 'Processando ${fieldName}...';
			case 'chat.tileAiProvider.modelLabel': return 'Modelo';
			case 'chat.tileAiProvider.invalidLabel': return 'Inválido';
			case 'chat.tileAiProvider.chooseModelTitle': return 'Escolha um modelo';
			case 'chat.presetTile.tapToChoose': return 'Toque para escolher';
			case 'chat.tileImagePreset.titleLabel': return 'Modelo de imagem';
			case 'chat.tileImagePreset.chooseModelTitle': return 'Escolha um modelo de imagem';
			case 'chat.tileVideoPreset.titleLabel': return 'Modelo de vídeo';
			case 'chat.tileVideoPreset.chooseModelTitle': return 'Escolha um modelo de vídeo';
			case 'chat.tileTtsPreset.titleLabel': return 'Modelo de fala';
			case 'chat.tileTtsPreset.chooseModelTitle': return 'Escolha um modelo de fala';
			case 'chat.tileImageAspectRatio.label': return 'Proporção da imagem';
			case 'chat.tileVideoAspectRatio.label': return 'Proporção';
			case 'chat.tileVideoResolution.label': return 'Resolução';
			case 'chat.tileVideoDuration.label': return 'Duração';
			case 'chat.tileTtsVoice.label': return 'Voz';
			case 'chat.tileTtsLanguage.label': return 'Idioma';
			case 'chat.tileNsfw.label': return 'NSFW / Ilimitado';
			case 'chat.tileScenario.label': return 'Cenário';
			case 'chat.tileMaxResponseLength.titleWithBucket': return ({required Object bucket}) => 'Tamanho da resposta — ${bucket}';
			case 'chat.tileMaxResponseLength.sliderLabel': return ({required Object bucket, required Object tokens}) => '${bucket} (${tokens} tokens)';
			case 'chat.tileMaxResponseLength.bucketVeryShort': return 'Muito curto';
			case 'chat.tileMaxResponseLength.bucketShort': return 'Curto';
			case 'chat.tileMaxResponseLength.bucketMedium': return 'Médio';
			case 'chat.tileMaxResponseLength.bucketLong': return 'Longo';
			case 'chat.tileMaxResponseLength.bucketVeryLong': return 'Muito longo';
			case 'chat.tileTrailingParagraph.label': return 'Cortar texto final';
			case 'chat.tileReasoningEffort.titleWithEffort': return ({required Object effort}) => 'Raciocínio — ${effort}';
			case 'chat.tileReasoningEffort.titleOff': return 'Raciocínio desligado';
			case 'chat.tileReasoningEffort.extraTokensCaption': return 'Usa tokens extras além do tamanho máximo da resposta.';
			case 'chat.tileChatTheme.label': return 'Tema';
			case 'chat.tileRecalledMemory.label': return 'Mostrar memória recuperada';
			case 'chat.characterSwitcher.favoritesTooltip': return 'Favoritos';
			case 'chat.characterSwitcher.recentChatsTooltip': return 'Conversas recentes';
			case 'chat.characterSwitcher.originalBadge': return 'ORIGINAL';
			case 'chat.characterSwitcher.variantBadge': return 'VARIANTE';
			case 'chat.characterSwitcher.lastActive': return ({required Object timeAgo}) => 'Última atividade: ${timeAgo}';
			case 'chat.characterSwitcher.never': return 'Nunca';
			case 'chat.freeImagePromptDialog.title': return 'Gerar imagem';
			case 'chat.freeImagePromptDialog.description': return 'Descreva o que você quer ver. Uma frase curta já basta — o modelo a expandirá em uma lista completa de tags.';
			case 'chat.freeImagePromptDialog.subjectLabel': return 'Tema';
			case 'chat.freeImagePromptDialog.subjectHint': return 'beco cyberpunk, chuva de neon';
			case 'chat.freeImagePromptDialog.generateButton': return 'Gerar';
			case 'chat.freeVideoPromptDialog.title': return 'Gerar vídeo';
			case 'chat.freeVideoPromptDialog.description': return 'Descreva um breve momento de movimento — o que se move, como, onde. O modelo do sistema o expandirá em um prompt cinematográfico T2V.';
			case 'chat.freeVideoPromptDialog.subjectLabel': return 'Tema';
			case 'chat.freeVideoPromptDialog.subjectHint': return 'ela caminha sob a chuva de neon, câmera lenta';
			case 'chat.freeVideoPromptDialog.generateButton': return 'Gerar';
			case 'chat.imagePromptReviewDialog.title': return 'Revisar prompt de imagem';
			case 'chat.imagePromptReviewDialog.description': return 'Edite o prompt abaixo antes de gerar, ou toque em Gerar para usá-lo como está.';
			case 'chat.imagePromptReviewDialog.fieldLabel': return 'Prompt de imagem';
			case 'chat.imagePromptReviewDialog.generateButton': return 'Gerar';
			case 'chat.videoPromptReviewDialog.title': return 'Revisar prompt de vídeo';
			case 'chat.videoPromptReviewDialog.description': return 'Edite o prompt abaixo antes de enviar, ou toque em Gerar para usá-lo como está.';
			case 'chat.videoPromptReviewDialog.fieldLabel': return 'Prompt de vídeo';
			case 'chat.videoPromptReviewDialog.generateButton': return 'Gerar';
			case 'chat.urlFetchReviewDialog.title': return 'Permitir busca na web?';
			case 'chat.urlFetchReviewDialog.description': return 'O personagem quer ler o conteúdo deste URL.';
			case 'chat.urlFetchReviewDialog.purposeLabel': return 'Finalidade:';
			case 'chat.urlFetchReviewDialog.denyButton': return 'Recusar';
			case 'chat.urlFetchReviewDialog.allowButton': return 'Permitir';
			case 'chat.messageActionsRow.tokenCountAbbrev': return ({required Object count}) => '${count}t';
			case 'chat.messageActionsRow.generationTimeAbbrev': return ({required Object seconds}) => '${seconds}s';
			case 'chat.messageActionsRow.viewGenerationPromptTooltip': return 'Ver prompt de geração';
			case 'chat.messageActionsRow.messageActionsTooltip': return 'Ações da mensagem';
			case 'chat.messageActionsRow.editAction': return 'Editar';
			case 'chat.messageActionsRow.copyAction': return 'Copiar';
			case 'chat.messageActionsRow.shareImageAction': return 'Compartilhar imagem';
			case 'chat.messageActionsRow.setAsBackgroundAction': return 'Definir como plano de fundo';
			case 'chat.messageActionsRow.setAsCharacterImageAction': return 'Definir como imagem do personagem';
			case 'chat.messageActionsRow.deleteAction': return 'Excluir';
			case 'chat.messageActionsRow.copiedToClipboard': return 'Mensagem copiada para a área de transferência';
			case 'chat.ttsPlayButton.stopTooltip': return 'Parar';
			case 'chat.ttsPlayButton.readAloudTooltip': return 'Ler em voz alta';
			case 'chat.ttsPlayButton.ttsFailed': return 'TTS falhou.';
			case 'chat.messageSwipeFlipper.previousVersionTooltip': return 'Versão anterior';
			case 'chat.messageSwipeFlipper.swipeCounter': return ({required Object current, required Object total}) => '${current} / ${total}';
			case 'chat.messageSwipeFlipper.regenerateTooltip': return 'Regenerar';
			case 'chat.messageSwipeFlipper.nextVersionTooltip': return 'Próxima versão';
			case 'chat.videoPlayerInline.webUnsupported': return 'Reprodução de vídeo não suportada na web.';
			case 'chat.videoPlayerInline.couldNotLoad': return 'Não foi possível carregar o vídeo.';
			case 'chat.newChatLabel': return 'Nova conversa';
			case 'chat.chatListItem.messageCount': return ({required Object count}) => '${count} mensagens';
			case 'chat.chatListItem.renameAction': return 'Renomear';
			case 'chat.chatListItem.deleteChatAction': return 'Excluir conversa';
			case 'chat.chatHistoryController.renameChatTitle': return 'Renomear conversa';
			case 'chat.chatHistoryController.chatNameHint': return 'Nome da conversa';
			case 'chat.chatHistoryController.renameButton': return 'Renomear';
			case 'chat.chatHistoryController.deleteChatTitle': return 'Excluir conversa';
			case 'chat.chatHistoryController.deleteChatMessage': return 'Tem certeza de que deseja excluir este histórico de conversa? Esta ação não pode ser desfeita.';
			case 'chat.chatPageController.clearAssistantHistoryMessage': return 'Limpar o histórico de conversa com o assistente?';
			case 'chat.chatPageController.clearButton': return 'Limpar';
			case 'chat.chatPageController.deleteOrKeepMessage': return 'Deseja excluir a conversa atual ou mantê-la no seu histórico?';
			case 'chat.chatPageController.deleteCurrentButton': return 'Excluir atual';
			case 'chat.chatPageController.keepCurrentButton': return 'Manter atual';
			case 'chat.imageGenerationMixin.enterPromptMessage': return 'Digite um prompt para gerar uma imagem.';
			case 'chat.imageGenerationMixin.noCharacterMessage': return 'Nenhum personagem disponível para geração de imagem.';
			case 'chat.imageGenerationMixin.notConfiguredMessage': return 'A geração de imagem não está configurada.';
			case 'chat.imageGenerationMixin.noSystemModelMessage': return 'Nenhum modelo do sistema configurado. Defina um em Configurações → IA.';
			case 'chat.videoGenerationMixin.enterPromptMessage': return 'Digite um prompt para gerar um vídeo.';
			case 'chat.videoGenerationMixin.noCharacterMessage': return 'Nenhum personagem disponível para geração de vídeo.';
			case 'chat.videoGenerationMixin.notConfiguredMessage': return 'A geração de vídeo não está configurada.';
			case 'chat.bubbleWaitingFor.thinking': return 'Pensando…';
			case 'chat.bubbleWaitingFor.preparingImagePrompt': return 'Preparando prompt de imagem…';
			case 'chat.bubbleWaitingFor.preparingVideoPrompt': return 'Preparando prompt de vídeo…';
			case 'chat.bubbleWaitingFor.generatingImage': return 'Gerando imagem…';
			case 'chat.bubbleWaitingFor.generatingVideo': return 'Gerando vídeo…';
			case 'chat.appBarChat.hideEditorPanelTooltip': return 'Ocultar painel do editor';
			case 'chat.appBarChat.showEditorSideBySideTooltip': return 'Mostrar editor lado a lado';
			case 'chat.allChatsDrawerList.rebuildingIndex': return 'Reconstruindo índice...';
			case 'chat.allChatsDrawerList.noChatsFound': return 'Nenhuma conversa encontrada.';
			case 'chat.chatInputMediaMenu.generateMediaTooltip': return 'Gerar mídia';
			case 'chat.chatInputMediaMenu.generateImageLabel': return 'Gerar imagem';
			case 'chat.chatInputMediaMenu.generateVideoLabel': return 'Gerar vídeo';
			case 'chat.chatView.deleteMessageTitle': return 'Excluir mensagem';
			case 'chat.chatView.deleteMessageConfirmation': return 'Tem certeza de que deseja excluir esta mensagem?';
			case 'chat.chatView.typeMessageHint': return 'Digite uma mensagem...';
			case 'chat.chatView.moreActionsTooltip': return 'Mais ações';
			case 'chat.chatView.continueAction': return 'Continuar';
			case 'chat.chatView.impersonateAction': return 'Interpretar';
			case 'chat.chatView.generateReplyAction': return 'Gerar resposta';
			case 'chat.chatView.improveMessageAction': return 'Melhorar mensagem';
			case 'chat.chatMessageBubble.imagesTypeGroupLabel': return 'Imagens';
			case 'chat.chatMessageBubble.assistantFallbackName': return 'Assistente';
			case 'chat.chatMessageBubble.reasoningLabel': return 'Raciocínio';
			case 'chat.chatMessageBubble.sendingToProvider': return 'Enviando ao provedor…';
			case 'chat.chatMessageBubble.pollingWithPercent': return ({required Object pct}) => 'Consultando… ${pct}%';
			case 'chat.chatMessageBubble.polling': return 'Consultando…';
			case 'chat.chatMessageBubble.downloading': return 'Baixando…';
			case 'common.actions.delete': return 'Excluir';
			case 'common.actions.ok': return 'OK';
			case 'common.actions.cancel': return 'Cancelar';
			case 'common.actions.save': return 'Salvar';
			case 'common.actions.tryAgain': return 'Tentar novamente';
			case 'common.actions.close': return 'Fechar';
			case 'common.aiAction.proofread': return 'Revisar';
			case 'common.aiAction.compact': return 'Compactar prosa';
			case 'common.aiAction.translate': return 'Traduzir para o inglês';
			case 'common.aiAction.generatePreview': return 'Gerar prévia';
			case 'common.aiAction.autoTag': return 'Marcação automática';
			case 'common.aiActionsTooltip': return 'Ações de IA';
			case 'common.promptSegmentKind.identity': return 'Identidade';
			case 'common.promptSegmentKind.systemPrompt': return 'Prompt do sistema';
			case 'common.promptSegmentKind.nsfwMode': return 'Modo NSFW';
			case 'common.promptSegmentKind.scenarioMode': return 'Modo cenário';
			case 'common.promptSegmentKind.description': return 'Descrição';
			case 'common.promptSegmentKind.personality': return 'Personalidade';
			case 'common.promptSegmentKind.scenario': return 'Cenário';
			case 'common.promptSegmentKind.userPersona': return 'Sua persona';
			case 'common.promptSegmentKind.memory': return 'Memória';
			case 'common.promptSegmentKind.situation': return 'Situação';
			case 'common.promptSegmentKind.cardData': return 'Dados do cartão';
			case 'common.promptSegmentKind.tools': return 'Ferramentas';
			case 'common.promptSegmentKind.postHistory': return 'Pós-histórico';
			case 'common.promptSegmentKind.depthPrompt': return 'Prompt de profundidade';
			case 'common.promptSegmentKind.worldInfo': return 'Informações do mundo';
			case 'common.promptSegmentKind.injected': return 'Injetado';
			case 'common.promptSegmentKind.exampleDialogue': return 'Diálogo de exemplo';
			case 'common.promptSegmentKind.history': return 'Histórico de mensagens';
			case 'common.promptSegmentKind.currentMessage': return 'Mensagem atual';
			case 'common.promptSegmentKind.reservedReply': return 'Resposta reservada';
			case 'common.promptBreakdown.free': return 'Livre';
			case 'common.logs.title': return 'Logs';
			case 'common.logs.filterTooltip': return 'Filtrar logs';
			case 'common.logs.clearTooltip': return 'Limpar logs';
			case 'common.logs.exportTooltip': return 'Exportar logs';
			case 'common.logs.searchHint': return 'Buscar logs...';
			case 'common.logs.noLogsFound': return 'Nenhum log encontrado.';
			case 'common.logs.noLogsToExport': return 'Nenhum log para exportar';
			case 'common.logs.exportedSuccessfully': return 'Logs exportados com sucesso';
			case 'common.logs.exportFailed': return 'Falha ao exportar logs. Veja os logs para detalhes.';
			case 'common.logs.copiedToClipboard': return 'Copiado para a área de transferência';
			case 'common.logs.copyLogButton': return 'Copiar log';
			case 'common.logs.copiedEntryToClipboard': return 'Entrada de log copiada para a área de transferência';
			case 'common.logs.errorPrefix': return ({required Object error}) => 'Erro: ${error}';
			case 'common.importErrorsDialog.title': return 'Erros de importação';
			case 'common.importErrorsDialog.message': return 'Os seguintes arquivos não puderam ser importados:';
			case 'common.updateDialog.title': return 'Versão disponível';
			case 'common.updateDialog.body': return ({required Object appName, required Object currentVersion, required Object latestVersion}) => 'Uma versão mais nova do ${appName} está disponível.\n\nVersão atual: ${currentVersion}\nVersão mais recente: ${latestVersion}';
			case 'common.updateDialog.releaseNotesLabel': return 'Notas da versão:';
			case 'common.updateDialog.viewReleasesButton': return 'Ver versões';
			case 'common.importConflictsDialog.title': return 'Conflitos de importação';
			case 'common.importConflictsDialog.message': return ({required Object count}) => 'Os ${count} personagens a seguir têm conflitos de nome de arquivo e serão renomeados automaticamente:';
			case 'common.missingProviderBanner.message': return 'Conecte um provedor de IA.';
			case 'common.missingProviderBanner.setUpNowButton': return 'Configurar agora';
			case 'common.modelSelectionDialog.searchHint': return 'Buscar modelos';
			case 'common.modelSelectionDialog.subscriptionOnlyToggle': return ({required Object included, required Object total}) => 'Mostrar apenas modelos por assinatura (${included}/${total})';
			case 'common.showAdvanced.less': return 'Menos';
			case 'common.showAdvanced.more': return 'Mais';
			case 'common.messageEditDialog.title': return 'Editar mensagem';
			case 'common.promptBreakdownDialog.title': return 'Detalhamento do prompt';
			case 'common.promptBreakdownDialog.breakdownTab': return 'Detalhamento';
			case 'common.promptBreakdownDialog.contentTab': return 'Conteúdo';
			case 'common.promptBreakdownDialog.promptTotalEstimated': return 'Total do prompt (estimado)';
			case 'common.promptBreakdownDialog.promptTotalProvider': return 'Total do prompt (provedor)';
			case 'common.promptBreakdownDialog.contextWindowLabel': return 'Janela de contexto';
			case 'common.promptBreakdownDialog.categoryHeader': return 'CATEGORIA';
			case 'common.promptBreakdownDialog.tokensHeader': return 'TOKENS';
			case 'common.promptBreakdownDialog.usageHeader': return 'USO';
			case 'common.promptBreakdownDialog.noContentToInspect': return 'Nenhum conteúdo para inspecionar nesta resposta.';
			case 'common.promptBreakdownDialog.estimatedSuffix': return ' (estimado)';
			case 'common.promptBreakdownDialog.usedSummary': return ({required Object used, required Object total}) => '${used} / ${total} usados';
			case 'common.jsonPromptDialog.title': return 'Prompt de geração';
			case 'common.progressDialog.defaultMessage': return 'Enviando...';
			case 'common.progressDialog.finished': return 'Concluído!';
			case 'common.diffPanel.tokenSuffix': return ({required Object count}) => ' (${count} tokens)';
			case 'common.selectionDialog.searchHint': return 'Buscar…';
			case 'common.zdrSwitch.title': return 'Exigir Zero Data Retention (ZDR)';
			case 'common.zdrSwitch.subtitle': return 'Mostrar apenas modelos do OR com endpoints compatíveis com ZDR. Ative se sua conta openrouter.ai restringe a provedores ZDR.';
			case 'common.textFieldCard.labelWithTokenCount': return ({required Object label, required Object count}) => '${label} - ${count} tokens';
			case 'common.textFieldCard.tokenCountAbbrev': return ({required Object count}) => '${count} t';
			case 'common.modelCapability.reasoning': return 'Raciocínio';
			case 'common.modelCapability.vision': return 'Visão';
			case 'common.modelCapability.tools': return 'Ferramentas';
			case 'common.modelCapability.json': return 'JSON';
			case 'common.modelCapability.files': return 'Arquivos';
			case 'common.modelCapability.image': return 'Imagem';
			case 'common.modelCapability.video': return 'Vídeo';
			case 'common.modelCapability.speech': return 'Fala';
			case 'common.modelCapability.music': return 'Música';
			case 'common.modelUnavailableTooltip': return 'Este modelo não está mais disponível no provedor — escolha outro.';
			case 'common.characterImageSemanticLabel': return 'Imagem do personagem';
			case 'common.appConstants.maxImageFileSizeLabel': return '10 MB';
			case 'common.appConstants.exportFailedMessage': return 'Falha na exportação. Veja os logs para detalhes.';
			case 'common.timeAgo.years': return ({required Object n}) => 'há ${n}a';
			case 'common.timeAgo.months': return ({required Object n}) => 'há ${n}mes';
			case 'common.timeAgo.days': return ({required Object n}) => 'há ${n}d';
			case 'common.timeAgo.hours': return ({required Object n}) => 'há ${n}h';
			case 'common.timeAgo.minutes': return ({required Object n}) => 'há ${n}min';
			case 'common.timeAgo.justNow': return 'Agora mesmo';
			case 'editor.panelLabels.basic': return 'Básico';
			case 'editor.panelLabels.greetings': return 'Saudações';
			case 'editor.panelLabels.prompts': return 'Prompts';
			case 'editor.panelLabels.lorebook': return 'Lorebook';
			case 'editor.panelLabels.group': return 'Grupo';
			case 'editor.panelLabels.creator': return 'Criador';
			case 'editor.panelLabels.appData': return 'Dados do app';
			case 'editor.panelLabels.nodes': return 'Nós';
			case 'editor.appBarEditor.hideAssistantPanelTooltip': return 'Ocultar painel do assistente';
			case 'editor.appBarEditor.showChatAssistantTooltip': return 'Mostrar assistente de conversa lado a lado';
			case 'editor.codeFindPanel.noneResult': return 'nenhum';
			case 'editor.codeFindPanel.previousTooltip': return 'Anterior';
			case 'editor.codeFindPanel.nextTooltip': return 'Próximo';
			case 'editor.codeFindPanel.closeTooltip': return 'Fechar';
			case 'editor.codeFindPanel.replaceTooltip': return 'Substituir';
			case 'editor.codeFindPanel.replaceAllTooltip': return 'Substituir tudo';
			case 'editor.findReplaceDialog.confirmReplaceAllTitle': return 'Confirmar Substituir tudo';
			case 'editor.findReplaceDialog.confirmReplaceAllMessage': return 'Tem certeza de que deseja continuar?\nEsta ação é irreversível e afeta todos os campos.';
			case 'editor.findReplaceDialog.proceedButton': return 'Prosseguir';
			case 'editor.findReplaceDialog.title': return 'Localizar e substituir';
			case 'editor.findReplaceDialog.findLabel': return 'Localizar';
			case 'editor.findReplaceDialog.replaceWithLabel': return 'Substituir por';
			case 'editor.findReplaceDialog.replaceAllButton': return 'Substituir tudo';
			case 'editor.objectValueEditor.stringType': return 'string';
			case 'editor.objectValueEditor.numberType': return 'número';
			case 'editor.objectValueEditor.boolType': return 'bool';
			case 'editor.editorBasic.nameLabel': return 'Nome';
			case 'editor.editorBasic.nicknameLabel': return 'Apelido (CCv3)';
			case 'editor.editorBasic.descriptionLabel': return 'Descrição';
			case 'editor.editorBasic.personalityLabel': return 'Personalidade';
			case 'editor.editorBasic.scenarioLabel': return 'Cenário';
			case 'editor.editorBasic.messageExampleLabel': return 'Exemplo de mensagem';
			case 'editor.editorCreatorMetadata.systemNameLabel': return 'Nome de sistema (CCv3)';
			case 'editor.editorCreatorMetadata.creatorLabel': return 'Criador';
			case 'editor.editorCreatorMetadata.versionLabel': return 'Versão';
			case 'editor.editorCreatorMetadata.creatorNotesLabel': return 'Notas do criador';
			case 'editor.editorCreatorMetadata.tagsLabel': return 'Tags (separadas por vírgula)';
			case 'editor.editorPrompts.systemPromptLabel': return 'Prompt do sistema';
			case 'editor.editorPrompts.postHistoryInstructionsLabel': return 'Instruções pós-histórico';
			case 'editor.editorPrompts.depthPromptLabel': return 'Prompt de profundidade (notas do personagem)';
			case 'editor.editorPrompts.insertionDepthLabel': return 'Profundidade de inserção';
			case 'editor.editorPrompts.roleLabel': return 'Papel';
			case 'editor.editorAppData.variantNotesLabel': return 'Notas da variante';
			case 'editor.editorAppData.descriptionPreviewLabel': return 'Prévia da descrição';
			case 'editor.editorAlternateGreetings.deleteGreetingTitle': return 'Excluir saudação';
			case 'editor.editorAlternateGreetings.deleteGreetingMessage': return 'Tem certeza de que deseja excluir esta saudação?';
			case 'editor.editorAlternateGreetings.addGreetingButton': return 'Adicionar saudação';
			case 'editor.editorAlternateGreetings.primaryGreetingLabel': return 'Saudação principal (first_mes)';
			case 'editor.editorAlternateGreetings.alternateGreetingLabel': return ({required Object index}) => 'Saudação alternativa nº${index}';
			case 'editor.editorAlternateGreetings.removeTooltip': return 'Remover';
			case 'editor.editorGroupGreetings.greetingLabel': return ({required Object index}) => 'Saudação ${index}';
			case 'editor.editorLorebook.newEntryDefaultComment': return 'Nova entrada';
			case 'editor.editorLorebook.deleteEntryTitle': return 'Excluir entrada';
			case 'editor.editorLorebook.deleteEntryMessage': return 'Tem certeza de que deseja excluir esta entrada?';
			case 'editor.editorLorebook.addNewEntryButton': return 'Adicionar nova entrada';
			case 'editor.editorLorebook.noEntriesFound': return 'Nenhuma entrada de lorebook encontrada.';
			case 'editor.lorebookEntryListTile.untitledEntry': return 'Entrada sem título';
			case 'editor.lorebookEntryListTile.noKeywords': return 'Sem palavras-chave';
			case 'editor.lorebookEntryEditorPage.editEntryTitle': return 'Editar entrada de lorebook';
			case 'editor.lorebookEntryEditorPage.advancedFilter': return 'Avançado';
			case 'editor.lorebookEntryEditorPage.primaryKeywordsLabel': return 'Palavras-chave principais';
			case 'editor.lorebookEntryEditorPage.logicLabel': return 'Lógica';
			case 'editor.lorebookEntryEditorPage.logicAndAny': return 'E QUALQUER';
			case 'editor.lorebookEntryEditorPage.logicAndAll': return 'E TODAS';
			case 'editor.lorebookEntryEditorPage.logicNotAny': return 'NÃO QUALQUER';
			case 'editor.lorebookEntryEditorPage.logicNotAll': return 'NÃO TODAS';
			case 'editor.lorebookEntryEditorPage.optionalFilterLabel': return 'Filtro opcional';
			case 'editor.lorebookEntryEditorPage.contentLabel': return 'Conteúdo';
			case 'editor.lorebookEntryEditorPage.nonRecursableFilter': return 'Não recursável';
			case 'editor.lorebookEntryEditorPage.preventFurtherRecursionFilter': return 'Impedir recursão adicional';
			case 'editor.lorebookEntryEditorPage.delayUntilRecursionFilter': return 'Adiar até a recursão';
			case 'editor.lorebookEntryEditorPage.ignoreBudgetFilter': return 'Ignorar orçamento';
			case 'editor.lorebookEntryEditorPage.prioritizeFilter': return 'Priorizar';
			case 'editor.lorebookEntryEditorPage.inclusionGroupLabel': return 'Grupo de inclusão';
			case 'editor.lorebookEntryEditorPage.groupWeightLabel': return 'Peso do grupo';
			case 'editor.lorebookEntryEditorPage.stickyLabel': return 'Fixo';
			case 'editor.lorebookEntryEditorPage.cooldownLabel': return 'Tempo de espera';
			case 'editor.lorebookEntryEditorPage.delayLabel': return 'Atraso';
			case 'editor.lorebookEntryEditorPage.filterToCharactersLabel': return 'Filtrar para personagens ou tags';
			case 'editor.lorebookEntryEditorPage.filterToTriggersLabel': return 'Filtrar para gatilhos de geração';
			case 'editor.lorebookEntryEditorPage.additionalMatchingSourcesLabel': return 'Fontes de correspondência adicionais:';
			case 'editor.lorebookEntryEditorPage.personaFilter': return 'Persona';
			case 'editor.lorebookEntryEditorPage.descriptionFilter': return 'Descrição';
			case 'editor.lorebookEntryEditorPage.personalityFilter': return 'Personalidade';
			case 'editor.lorebookEntryEditorPage.depthPromptFilter': return 'Prompt de profundidade';
			case 'editor.lorebookEntryEditorPage.scenarioFilter': return 'Cenário';
			case 'editor.lorebookEntryEditorPage.creatorNotesFilter': return 'Notas do criador';
			case 'editor.lorebookEntryEditorTopSection.titleMemoLabel': return 'Título/nota';
			case 'editor.lorebookEntryEditorTopSection.strategyLabel': return 'Estratégia';
			case 'editor.lorebookEntryEditorTopSection.strategyConstant': return 'Constante';
			case 'editor.lorebookEntryEditorTopSection.strategyEnabled': return 'Ativada';
			case 'editor.lorebookEntryEditorTopSection.strategyDisabled': return 'Desativada';
			case 'editor.lorebookEntryEditorTopSection.strategyVectorized': return 'Vetorizada';
			case 'editor.lorebookEntryEditorTopSection.positionLabel': return 'Posição';
			case 'editor.lorebookEntryEditorTopSection.positionUpChar': return '↑ Pers';
			case 'editor.lorebookEntryEditorTopSection.positionDownChar': return '↓ Pers';
			case 'editor.lorebookEntryEditorTopSection.positionUpAn': return '↑ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDownAn': return '↓ AN';
			case 'editor.lorebookEntryEditorTopSection.positionDepthSystem': return '@D Sistema';
			case 'editor.lorebookEntryEditorTopSection.positionDepthUser': return '@D Usuário';
			case 'editor.lorebookEntryEditorTopSection.positionDepthAssistant': return '@D Assistente';
			case 'editor.lorebookEntryEditorTopSection.positionUpEm': return '↑ EM';
			case 'editor.lorebookEntryEditorTopSection.positionDownEm': return '↓ EM';
			case 'editor.lorebookEntryEditorTopSection.positionOutlet': return 'Saída';
			case 'editor.lorebookEntryEditorTopSection.depthLabel': return 'Profundidade';
			case 'editor.lorebookEntryEditorTopSection.orderLabel': return 'Ordem';
			case 'editor.lorebookEntryEditorTopSection.triggerLabel': return 'Gatilho %';
			case 'editor.lorebookEntryEditorScanRow.scanDepthLabel': return 'Profundidade de varredura';
			case 'editor.lorebookEntryEditorScanRow.automationIdLabel': return 'ID de automação';
			case 'editor.lorebookEntryEditorScanRow.useRegexFilter': return 'Usar regex';
			case 'editor.lorebookEntryEditorScanRow.caseSensitiveFilter': return 'Diferenciar maiúsculas';
			case 'editor.lorebookEntryEditorScanRow.wholeWordsFilter': return 'Palavras inteiras';
			case 'editor.lorebookEntryEditorScanRow.groupScoringFilter': return 'Pontuação de grupo';
			case 'editor.dialogContentCleaner.confirmActionTitle': return ({required Object actionName}) => 'Confirmar ${actionName}';
			case 'editor.dialogContentCleaner.title': return 'Limpador de conteúdo';
			case 'editor.dialogContentCleaner.normalizeFancyCharsAction': return 'Normalizar caracteres especiais';
			case 'editor.dialogContentCleaner.normalizeFancyCharsButton': return 'Normalizar caracteres especiais (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)';
			case 'editor.dialogContentCleaner.purgeHtmlAction': return 'Remover HTML';
			case 'editor.dialogContentCleaner.purgeHtmlButton': return 'Remover tags HTML';
			case 'editor.dialogContentCleaner.purgeMarkdownAction': return 'Remover links/imagens Markdown';
			case 'editor.dialogContentCleaner.purgeEmojisAction': return 'Remover emojis';
			case 'editor.dialogContentCleaner.purgeExtraSpacesAction': return 'Remover espaços extras';
			case 'editor.dialogContentCleaner.yoloPurgeAction': return 'Limpeza total';
			case 'editor.dialogContentCleaner.applyAllAboveButton': return 'Aplicar tudo acima';
			case 'editor.dialogAiDiffConfirmation.applyChangesButton': return 'Aplicar alterações';
			case 'editor.dialogAiDiffConfirmation.originalTextTitle': return 'Texto original';
			case 'editor.dialogAiDiffConfirmation.suggestedTextTitle': return 'Texto sugerido';
			case 'editor.editorPageController.globalActionTitle': return ({required Object action}) => '${action} global';
			case 'editor.editorPageController.globalAiActionFailed': return 'Ação de IA global falhou. Verifique os logs.';
			case 'editor.editorPageController.compositeName': return ({required Object value}) => 'Nome:\n${value}\n';
			case 'editor.editorPageController.compositeDescription': return ({required Object value}) => 'Descrição:\n${value}\n';
			case 'editor.editorPageController.compositePersonality': return ({required Object value}) => 'Personalidade:\n${value}\n';
			case 'editor.editorPageController.compositeScenario': return ({required Object value}) => 'Cenário:\n${value}\n';
			case 'editor.editorPageController.compositeFirstMessage': return ({required Object value}) => 'Primeira mensagem:\n${value}\n';
			case 'editor.editorPageController.compositeMessageExample': return ({required Object value}) => 'Exemplo de mensagem:\n${value}\n';
			case 'editor.editorPageController.compositeCreatorNotes': return ({required Object value}) => 'Notas do criador:\n${value}\n';
			case 'editor.editorPageController.compositeSystemPrompt': return ({required Object value}) => 'Prompt do sistema:\n${value}\n';
			case 'editor.editorPageController.compositePostHistoryInstructions': return ({required Object value}) => 'Instruções pós-histórico:\n${value}\n';
			case 'editor.editorPageController.compositeAlternateGreeting': return ({required Object index, required Object value}) => 'Saudação alternativa nº${index}:\n${value}\n';
			case 'editor.editorPageController.compositeGroupGreeting': return ({required Object index, required Object value}) => 'Saudação de grupo nº${index}:\n${value}\n';
			case 'editor.editorPageController.compositeLorebookEntry': return ({required Object index, required Object value}) => 'Entrada de lorebook nº${index}:\n${value}\n';
			case 'editor.editorPageController.imageTooLargeMessage': return ({required Object maxSize}) => 'A imagem selecionada é grande demais. O tamanho máximo é ${maxSize}.';
			case 'editor.editorPageController.invalidPngMessage': return 'A imagem selecionada não é um PNG válido ou não pôde ser lida.';
			case 'editor.editorNodes.deleteNodeTitle': return 'Excluir nó';
			case 'editor.editorNodes.deleteNodeMessage': return 'Remover este nó autoral do cartão?';
			case 'editor.editorNodes.engineSeedTitle': return 'Semente do motor';
			case 'editor.editorNodes.visualEditorTooltip': return 'Editor visual';
			case 'editor.editorNodes.editJsonTooltip': return 'Editar JSON';
			case 'editor.editorNodes.initialGoalLabel': return 'Objetivo inicial';
			case 'editor.editorNodes.initialSceneLabel': return 'Cena inicial';
			case 'editor.editorNodes.locationLabel': return 'Local';
			case 'editor.editorNodes.timeOfDayLabel': return 'Hora do dia';
			case 'editor.editorNodes.presentEntitiesLabel': return 'Presentes (separados por vírgula)';
			case 'editor.editorNodes.sensoryHooksLabel': return 'Ganchos sensoriais (separados por vírgula)';
			case 'editor.editorNodes.addNodeButton': return 'Adicionar nó';
			case 'editor.editorNodes.noAuthoredNodesYet': return 'Nenhum nó autoral ainda.';
			case 'editor.editorNodes.loadErrorMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
				one: 'O bloco de nós deste cartão tem ${n} problema; editar aqui sobrescreverá as partes corrompidas ao salvar.',
				other: 'O bloco de nós deste cartão tem ${n} problemas; editar aqui sobrescreverá as partes corrompidas ao salvar.',
			);
			case 'editor.editorNodes.moreErrorsSuffix': return ({required Object n}) => '… mais ${n}';
			case 'editor.editorNodes.emotionBaselineLabel': return 'Emoção base';
			case 'editor.editorNodes.emotionChipLabel': return 'Emoção';
			case 'editor.nodeListTile.spawnsLabel': return ({required Object count}) => 'gera: ${count}';
			case 'editor.nodesRawEditorPage.topLevelMustBeObject': return 'O nível superior deve ser um objeto JSON';
			case 'editor.nodesRawEditorPage.editNodesJsonTitle': return 'Editar JSON dos nós';
			case 'editor.nodesRawEditorPage.fixProblemsMessage': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
				one: 'Corrija ${n} problema para salvar.',
				other: 'Corrija ${n} problemas para salvar.',
			);
			case 'editor.nodesCanvasView.spawnedByPort': return 'gerado por';
			case 'editor.nodesCanvasView.spawnsPort': return 'gera';
			case 'editor.nodesCanvasView.editNodeLabel': return 'Editar nó';
			case 'editor.nodesCanvasView.addNodeTooltip': return 'Adicionar nó';
			case 'editor.nodeEditorForm.nameLabel': return 'Nome';
			case 'editor.nodeEditorForm.narrativePayloadLabel': return 'Carga narrativa';
			case 'editor.nodeEditorForm.removeSpawnLinkTitle': return 'Remover vínculo de geração';
			case 'editor.nodeEditorForm.removeSpawnLinkMessage': return ({required Object nodeId}) => 'Impedir este nó de gerar "${nodeId}"? O nó em si permanece no cartão.';
			case 'editor.nodeEditorForm.removeButton': return 'Remover';
			case 'editor.nodeEditorForm.typeLabel': return 'Tipo';
			case 'editor.nodeEditorForm.scopeLabel': return 'Escopo';
			case 'editor.nodeEditorForm.originLabel': return 'Origem';
			case 'editor.nodeEditorForm.triggerProbLabel': return 'Prob. de gatilho';
			case 'editor.nodeEditorForm.delayHelper': return 'Turnos a esperar antes de ficar elegível. -1 age como 0.';
			case 'editor.nodeEditorForm.cooldownHelper': return 'Turnos bloqueado após disparar. -1 significa sem tempo de espera.';
			case 'editor.nodeEditorForm.stickyHelper': return 'Turnos em que a carga narrativa continua aparecendo como "Persistente" após disparar. -1 significa permanente.';
			case 'editor.nodeEditorForm.aliveHelper': return 'Turnos em que o nó permanece no pool antes da remoção. -1 significa para sempre.';
			case 'editor.nodeEditorForm.setToNeverButton': return 'Definir como nunca';
			case 'editor.nodeEditorForm.effectsSectionLabel': return 'Efeitos';
			case 'editor.nodeEditorForm.emotionDeltasTitle': return 'Variações de emoção';
			case 'editor.nodeEditorForm.physicalDeltasTitle': return 'Variações físicas';
			case 'editor.nodeEditorForm.relationshipDeltasTitle': return 'Variações de relacionamento';
			case 'editor.nodeEditorForm.addDeltaChip': return 'Adicionar variação';
			case 'editor.nodeEditorForm.knowledgeWritesTitle': return 'Escritas de conhecimento';
			case 'editor.nodeEditorForm.addFactChip': return 'Adicionar fato';
			case 'editor.nodeEditorForm.topicLabel': return 'tópico';
			case 'editor.nodeEditorForm.confidenceLabel': return 'confiança';
			case 'editor.nodeEditorForm.flagSetTitle': return 'Definição de flag';
			case 'editor.nodeEditorForm.addFlagChip': return 'Adicionar flag';
			case 'editor.nodeEditorForm.keyLabel': return 'chave';
			case 'editor.nodeEditorForm.sceneAndFlowTitle': return 'Cena e fluxo';
			case 'editor.nodeEditorForm.goalChangeLabel': return 'goalChange (limpa o objetivo atual quando vazio)';
			case 'editor.nodeEditorForm.phaseChangeLabel': return 'phaseChange';
			case 'editor.nodeEditorForm.noneOption': return '(nenhum)';
			case 'editor.nodeEditorForm.sceneTransitionLabel': return 'sceneTransition';
			case 'editor.nodeEditorForm.sceneTransitionSubtitle': return 'Quando verdadeiro, o motor marca o disparo como uma mudança de cena.';
			case 'editor.nodeEditorForm.spawnsSectionLabel': return 'Gerações';
			case 'editor.nodeEditorForm.addNewChip': return 'Adicionar novo';
			case 'editor.nodeEditorForm.linkExistingChip': return 'Vincular existente';
			case 'editor.nodeEditorForm.unlinkTooltip': return 'Desvincular';
			case 'editor.nodeEditorForm.predicateLabel': return 'Predicado';
			case 'grid.emptyState.noMatches': return 'Nenhum personagem corresponde aos seus filtros';
			case 'grid.emptyState.noCharacters': return 'Nenhum personagem importado ainda';
			case 'grid.emptyState.clearAllFilters': return 'Limpar todos os filtros';
			case 'grid.emptyState.importCharacters': return 'Importar personagens';
			case 'grid.emptyState.createNewCharacter': return 'Criar novo personagem';
			case 'grid.appBar.groups': return 'Grupos';
			case 'grid.appBar.createNew': return 'Criar';
			case 'grid.appBar.import': return 'Importar';
			case 'grid.appBar.menuTooltip': return 'Menu';
			case 'grid.fab.addOrImportTooltip': return 'Adicionar ou importar';
			case 'grid.fab.import': return 'Importar';
			case 'grid.fab.create': return 'Criar';
			case 'grid.drawer.mediaDefaultsApp': return 'App';
			case 'grid.drawer.batchAiHeader': return 'IA em lote';
			case 'grid.drawer.batchGeneratePreviewsTitle': return 'Gerar prévias em lote';
			case 'grid.drawer.batchGeneratePreviewsEmpty': return 'Todos os personagens já têm prévias.';
			case 'grid.drawer.batchAutoTagTitle': return 'Marcação automática em lote';
			case 'grid.drawer.batchAutoTagEmpty': return 'Todos os personagens já têm tags.';
			case 'grid.drawer.libraryHeader': return 'Biblioteca';
			case 'grid.drawer.reloadCharacters': return 'Recarregar personagens';
			case 'grid.variantBadge.tooltip': return ({required Object count}) => '${count} variantes';
			case 'grid.dialogActions.clearAll': return 'Limpar tudo';
			case 'grid.dialogActions.apply': return 'Aplicar';
			case 'grid.tagFilterDialog.title': return 'Filtrar tags';
			case 'grid.tagFilterDialog.searchHint': return 'Buscar tags...';
			case 'grid.filters.hideFiltersTooltip': return 'Ocultar filtros';
			case 'grid.filters.moreFiltersTooltip': return 'Mais filtros';
			case 'grid.filters.folderChip': return 'Pasta';
			case 'grid.filters.creatorChip': return 'Criador';
			case 'grid.filters.tagChip': return 'Tag';
			case 'grid.filters.recentTooltip': return 'Recentes';
			case 'grid.filters.favoritesTooltip': return 'Favoritos';
			case 'grid.filters.variantsTooltip': return 'Variantes';
			case 'grid.filters.indexingProgress': return ({required Object done, required Object total}) => 'Criando busca ${done} / ${total}…';
			case 'grid.sortOption.relevance': return 'Relevância ↓';
			case 'grid.sortOption.nameAsc': return 'Nome ↓';
			case 'grid.sortOption.nameDesc': return 'Nome ↑';
			case 'grid.sortOption.importNewest': return 'Importado ↓';
			case 'grid.sortOption.importOldest': return 'Importado ↑';
			case 'grid.sortOption.modifiedNewest': return 'Modificado ↓';
			case 'grid.sortOption.modifiedOldest': return 'Modificado ↑';
			case 'grid.sortOption.interactedNewest': return 'Interagido ↓';
			case 'grid.sortOption.interactedOldest': return 'Interagido ↑';
			case 'grid.sortOption.tokensHigh': return 'Tokens ↓';
			case 'grid.sortOption.tokensLow': return 'Tokens ↑';
			case 'grid.filterController.filterCreators': return 'Filtrar criadores';
			case 'grid.filterController.filterTags': return 'Filtrar tags';
			case 'grid.filterController.filterByFolder': return 'Filtrar por pasta';
			case 'grid.multiSelectDialog.nothingToShow': return 'Nada para mostrar ainda.';
			case 'grid.multiSelectDialog.noMatches': return 'Nenhuma correspondência.';
			case 'grid.multiSelectDialog.showMore': return 'Mostrar mais';
			case 'grid.createCharacterDialog.nameEmptyError': return 'O nome do personagem não pode ficar vazio.';
			case 'grid.createCharacterDialog.nameInvalidCharsError': return 'O nome contém caracteres inválidos (<>:"/\|?*).';
			case 'grid.createCharacterDialog.nameExistsError': return 'Já existe um personagem com esse nome.';
			case 'grid.createCharacterDialog.nameCheckFailedError': return 'Não foi possível verificar o nome. Verifique as permissões da pasta e tente novamente.';
			case 'grid.createCharacterDialog.title': return 'Criar novo personagem';
			case 'grid.createCharacterDialog.nameLabel': return 'Nome do personagem';
			case 'grid.createCharacterDialog.createButton': return 'Criar';
			case 'grid.variantsSheet.title': return 'Variantes';
			case 'grid.groupAppBar.characters': return 'Personagens';
			case 'grid.groupAppBar.newGroup': return 'Novo grupo';
			case 'grid.thumbnailBadges.recent': return 'RECENTE';
			case 'grid.thumbnailBadges.original': return 'ORIGINAL';
			case 'grid.thumbnailBadges.variant': return 'VARIANTE';
			case 'grid.actionMenu.editNotes': return 'Editar notas';
			case 'grid.actionMenu.dismissRecent': return 'Remover de recentes';
			case 'grid.actionMenu.exportPngV2V3': return 'Exportar como PNG (V2/V3)';
			case 'grid.actionMenu.exportJsonV3': return 'Exportar como JSON (V3)';
			case 'grid.actionMenu.exportJsonV2': return 'Exportar como JSON (V2)';
			case 'grid.actionMenu.duplicate': return 'Duplicar';
			case 'grid.controllerMessages.duplicateFailed': return 'Não foi possível duplicar o personagem.';
			case 'grid.controllerMessages.editVariantNotesTitle': return 'Editar notas da variante';
			case 'grid.controllerMessages.editVariantNotesHint': return 'Adicione notas sobre esta variante...';
			case 'grid.controllerMessages.deleteCardTitle': return 'Excluir cartão';
			case 'grid.controllerMessages.deleteCardMessage': return 'Tem certeza de que deseja excluir este cartão?';
			case 'grid.controllerMessages.deletePartialFailure': return 'Alguns arquivos não puderam ser excluídos. Veja os logs para detalhes.';
			case 'grid.tagWrap.tagCountLabel': return ({required Object tag, required Object count}) => '${tag} (${count})';
			case 'group.groupGridController.renameGroupTitle': return 'Renomear grupo';
			case 'group.groupGridController.groupNameHint': return 'Nome do grupo';
			case 'group.groupGridController.deleteGroupTitle': return 'Excluir grupo';
			case 'group.groupGridController.deleteGroupMessage': return ({required Object name}) => 'Tem certeza de que deseja excluir "${name}"? Isso não pode ser desfeito.';
			case 'group.groupChatPage.defaultGroupName': return 'Conversa em grupo';
			case 'group.groupChatPage.failedToLoadMessage': return ({required Object error}) => 'Falha ao carregar a conversa em grupo:\n${error}';
			case 'group.groupChatPage.nextTurnTooltip': return 'Próximo turno';
			case 'group.groupChatPage.stopAutoChatTooltip': return 'Parar conversa automática';
			case 'group.groupChatPage.startAutoChatTooltip': return 'Iniciar conversa automática';
			case 'group.groupChatPage.stopGenerationTooltip': return 'Parar geração';
			case 'group.groupChatPage.noCharactersYetMessage': return 'Este grupo ainda não tem personagens.';
			case 'group.groupChatPage.addCharacterButton': return 'Adicionar um personagem';
			case 'group.groupChatPage.pickCharacterMessage': return 'Escolha um personagem na lista à esquerda.';
			case 'group.groupGridPage.failedToLoadMessage': return ({required Object error}) => 'Falha ao carregar os grupos:\n${error}';
			case 'group.groupGridPage.unknownErrorFallback': return 'erro desconhecido';
			case 'group.groupGridPage.noGroupsYetMessage': return 'Nenhum grupo ainda — toque em + para criar um.';
			case 'group.tileAutoChatDelay.title': return 'Atraso da conversa automática';
			case 'group.tileAutoChatDelay.secondsAbbrev': return ({required Object seconds}) => '${seconds}s';
			case 'group.tileActivationStrategy.title': return 'Seleção de quem fala';
			case 'group.tileActivationStrategy.naturalOption': return 'Natural';
			case 'group.tileActivationStrategy.roundRobinOption': return 'Rodízio';
			case 'group.tileActivationStrategy.randomOption': return 'Aleatório';
			case 'group.tileActivationStrategy.changeSelectionTooltip': return 'Alterar seleção de quem fala';
			case 'group.groupChatPageEndDrawer.allowWebFetchTitle': return 'Permitir busca na web';
			case 'group.groupChatPageEndDrawer.allowWebFetchSubtitle': return 'Ler páginas web públicas quando relevante';
			case 'group.groupChatPageEndDrawer.reviewUrlTitle': return 'Revisar URL antes de buscar';
			case 'group.groupChatPageEndDrawer.reviewUrlSubtitle': return 'Confirmar cada busca';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesTitle': return 'Sugerir nomes de NPC';
			case 'group.groupChatPageEndDrawer.suggestNpcNamesSubtitle': return 'Escolher nomes do banco de dados curado';
			case 'group.groupChatPageEndDrawer.unrestrictedImagesTitle': return 'Imagens sem restrição';
			case 'group.groupChatPageEndDrawer.allowNsfwImagePromptsSubtitle': return 'Permitir prompts de imagem NSFW';
			case 'group.groupChatPageEndDrawer.characterCanSendSelfiesTitle': return 'Personagem pode enviar selfies';
			case 'group.groupChatPageEndDrawer.attachSelfieWhenNaturalSubtitle': return 'Anexar uma selfie quando natural';
			case 'group.groupChatPageEndDrawer.reviewImagePromptTitle': return 'Revisar prompt de imagem';
			case 'group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle': return 'Editar antes de gerar';
			case 'group.groupChatPageEndDrawer.reviewToolImagePromptsTitle': return 'Revisar prompts de imagem das ferramentas';
			case 'group.groupChatPageEndDrawer.editToolTriggeredPromptsSubtitle': return 'Editar prompts acionados por ferramentas';
			case 'group.groupChatPageEndDrawer.allowSelfieCaptionsTitle': return 'Permitir legendas de selfie';
			case 'group.groupChatPageEndDrawer.captionRenderedOnImageSubtitle': return 'Legenda renderizada sobre a imagem';
			case 'group.groupChatPageEndDrawer.groupOverridesTitle': return 'Substituições do grupo';
			case 'group.groupChatPageEndDrawer.groupOverridesSubtitle': return 'Cenário, prompt principal e diálogo de exemplo compartilhados';
			case 'group.groupChatPageEndDrawer.chatSessionSubtitle': return 'Sessão de conversa';
			case 'group.groupChatPageEndDrawer.allChatsLabel': return 'Todas as conversas';
			case 'group.groupChatPageEndDrawer.showImageLabel': return 'Mostrar imagem';
			case 'group.groupChatPageEndDrawer.groupSectionHeader': return 'Grupo';
			case 'group.groupChatPageEndDrawer.chatSectionHeader': return 'Conversa';
			case 'group.groupChatPageEndDrawer.chatThemeSectionHeader': return 'Tema da conversa';
			case 'group.groupChatPageEndDrawer.unrestrictedVideosTitle': return 'Vídeos sem restrição';
			case 'group.groupChatPageEndDrawer.allowNsfwVideoPromptsSubtitle': return 'Permitir prompts de vídeo NSFW';
			case 'group.groupChatPageEndDrawer.characterCanSendVideosTitle': return 'Personagem pode enviar vídeos';
			case 'group.groupChatPageEndDrawer.attachShortVideoWhenNaturalSubtitle': return 'Anexar um vídeo curto quando natural';
			case 'group.groupChatPageEndDrawer.reviewVideoPromptTitle': return 'Revisar prompt de vídeo';
			case 'group.groupCharacterPicker.addButton': return 'Adicionar';
			case 'group.groupCharacterPicker.addWithCountButton': return ({required Object count}) => 'Adicionar ${count}';
			case 'group.groupCharacterPicker.favoritesTooltip': return 'Favoritos';
			case 'group.groupCharacterPicker.noMatchMessage': return ({required Object query}) => 'Nenhum personagem corresponde a "${query}"';
			case 'group.groupCharacterPicker.noFavoritesMessage': return 'Nenhum personagem favoritado disponível';
			case 'group.groupCharacterPicker.allAddedMessage': return 'Todos os personagens já foram adicionados';
			case 'group.groupCharacterTile.speakTooltip': return 'Fazer este personagem falar';
			case 'group.groupCharacterTile.removeFromChatTitle': return 'Remover da conversa';
			case 'group.dialogCreateGroup.title': return 'Novo grupo';
			case 'group.dialogCreateGroup.nameLabel': return 'Nome';
			case 'group.dialogCreateGroup.nameHint': return 'ex.: Bob e Alice';
			case 'group.dialogGroupOverrides.explanationMessage': return 'Exclusivo desta conversa. Todos os membros do grupo usam estes valores em vez do que os cartões de personagem definem. Deixe vazio para voltar ao valor do cartão.';
			case 'group.dialogGroupOverrides.scenarioHint': return 'Ambiente compartilhado do grupo (ex.: "Em um café em Paris")';
			case 'group.dialogGroupOverrides.mainPromptLabel': return 'Prompt principal';
			case 'group.dialogGroupOverrides.mainPromptHint': return 'Prompt do sistema aplicado a cada turno';
			case 'group.dialogGroupOverrides.exampleDialogueLabel': return 'Diálogo de exemplo';
			case 'group.dialogGroupOverrides.exampleDialogueHint': return 'Mensagens de exemplo compartilhadas para tom / formatação';
			case 'group.groupCharacterPanel.addCharacterButton': return 'Adicionar personagem';
			case 'group.groupCharacterPanel.noCharactersYetMessage': return 'Nenhum personagem ainda.\nToque em + para adicionar um.';
			case 'group.dialogSelectGroup.deleteGroupTitle': return 'Excluir grupo?';
			case 'group.dialogSelectGroup.deleteGroupMessage': return ({required Object name}) => '"${name}" e todas as suas sessões de conversa serão removidas permanentemente.';
			case 'group.dialogSelectGroup.title': return 'Grupos';
			case 'group.dialogSelectGroup.noGroupsYetMessage': return 'Nenhum grupo ainda. Toque em "Novo grupo" para criar um.';
			case 'group.dialogSelectGroup.memberCountLabel': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
				one: '${n} membro',
				other: '${n} membros',
			);
			case 'group.groupGridItem.overflowCountBadge': return ({required Object count}) => '+${count}';
			case 'group.groupGridItem.noMembersYetMessage': return 'Ainda sem membros';
			case 'group.groupFileService.defaultGroupName': return 'Grupo';
			case 'llmApp.mediaField.imageModel': return 'Modelo de imagem';
			case 'llmApp.mediaField.imageAspectRatio': return 'Proporção da imagem';
			case 'llmApp.mediaField.imageNsfwAllowed': return 'Permitir imagens NSFW';
			case 'llmApp.mediaField.imageToolSelfieAllowed': return 'Pode enviar selfies';
			case 'llmApp.mediaField.imageToolSelfieCaptionsAllowed': return 'Permitir legendas de selfie';
			case 'llmApp.mediaField.imagePromptPrefix': return 'Estilo de imagem';
			case 'llmApp.mediaField.videoModel': return 'Modelo de vídeo';
			case 'llmApp.mediaField.videoResolution': return 'Resolução do vídeo';
			case 'llmApp.mediaField.videoAspectRatio': return 'Proporção do vídeo';
			case 'llmApp.mediaField.videoDuration': return 'Duração do vídeo';
			case 'llmApp.mediaField.videoNsfwAllowed': return 'Permitir vídeos NSFW';
			case 'llmApp.mediaField.videoToolSendAllowed': return 'Pode enviar vídeos';
			case 'llmApp.mediaField.videoPromptPrefix': return 'Estilo de vídeo';
			case 'llmApp.mediaField.ttsModel': return 'Modelo de TTS';
			case 'llmApp.mediaField.ttsVoice': return 'Voz do TTS';
			case 'llmApp.mediaField.ttsLanguage': return 'Idioma do TTS';
			case 'llmApp.mediaField.webToolFetchAllowed': return 'Permitir busca na web';
			case 'llmApp.mediaField.nameToolSuggestAllowed': return 'Pode sugerir nomes de NPC';
			case 'llmApp.mediaSection.image': return 'Imagem';
			case 'llmApp.mediaSection.video': return 'Vídeo';
			case 'llmApp.mediaSection.tts': return 'TTS';
			case 'llmApp.mediaSection.web': return 'Web';
			case 'llmApp.mediaSection.names': return 'Nomes';
			case 'llmApp.tristate.on': return 'Ligado';
			case 'llmApp.tristate.off': return 'Desligado';
			case 'llmApp.tristate.inherit': return 'Herdar';
			case 'llmApp.mediaCellMenu.change': return 'Alterar…';
			case 'llmApp.mediaCellMenu.clear': return 'Limpar';
			case 'llmApp.mediaHeader.appDefault': return 'Padrão do app';
			case 'llmApp.mediaHeader.character': return 'Personagem';
			case 'llmApp.mediaHeader.currentChat': return 'Conversa atual';
			case 'llmApp.mediaHeader.previousLayerTooltip': return 'Camada anterior';
			case 'llmApp.mediaHeader.nextLayerTooltip': return 'Próxima camada';
			case 'llmApp.presetRow.changeAppDefaultTitle': return 'Alterar o padrão do app?';
			case 'llmApp.presetRow.changeAppDefaultMessage': return 'Isso afeta todas as conversas. Continuar?';
			case 'llmApp.presetRow.continueButton': return 'Continuar';
			case 'llmApp.presetRow.chooseModelTitle': return ({required Object domain}) => 'Escolha um modelo de ${domain}';
			case 'llmApp.mediaCell.notApplicable': return 'Não aplicável';
			case 'onboarding.finishFailedSnackbar': return 'Falha na configuração. Veja os logs para detalhes.';
			case 'onboarding.appBarTitle': return 'Configuração rápida';
			case 'onboarding.webWarning': return 'Build web experimental — o armazenamento do navegador pode ser redefinido entre atualizações. Use desktop ou Android para dados persistentes.';
			case 'onboarding.finishButton': return 'Concluir configuração';
			case 'onboarding.nextButton': return 'Avançar';
			case 'onboarding.backButton': return 'Voltar';
			case 'onboarding.storageStep.title': return 'Armazenamento de personagens';
			case 'onboarding.storageStep.subtitle': return 'Onde devemos salvar seus cartões de personagem?';
			case 'onboarding.storageStep.description': return 'Salvos na pasta do app por padrão. Aponte para uma pasta PNG existente para importar.';
			case 'onboarding.storageStep.startFresh': return 'Começar do zero';
			case 'onboarding.storageStep.haveCards': return 'Já tenho cartões';
			case 'onboarding.storageStep.importLaterHint': return 'Importe PNGs depois em Arquivo → Importar.';
			case 'onboarding.storageStep.selectedPath': return ({required Object path}) => 'Selecionado: ${path}';
			case 'onboarding.storageStep.selectedDefaultFolder': return 'Selecionado: pasta padrão do app';
			case 'onboarding.storageStep.noFolderSelected': return 'Nenhuma pasta selecionada ainda.';
			case 'onboarding.setupStep.title': return 'IA e persona';
			case 'onboarding.aiSection.heading': return 'Conexão de IA';
			case 'onboarding.aiSection.optionalHint': return 'Opcional — pule e adicione uma chave depois nas Configurações (provedores locais também podem ser adicionados lá).';
			case 'onboarding.aiSection.apiKeyLabel': return 'API key';
			case 'onboarding.aiSection.apiKeyHint': return 'Cole sua chave (ou pule por enquanto)';
			case 'onboarding.aiSection.supportedProviders': return 'Suporta OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. Mais nas Configurações.';
			case 'onboarding.aiSection.unknownModel': return '(modelo desconhecido)';
			case 'onboarding.aiSection.ctxUnknown': return 'ctx —';
			case 'onboarding.aiSection.ctxValue': return ({required Object ctx}) => 'ctx ${ctx}';
			case 'onboarding.aiSection.kvSuffix': return ({required Object kv}) => ' · KV ${kv}';
			case 'onboarding.aiSection.changeButton': return 'Alterar';
			case 'onboarding.aiStatus.connecting': return 'Conectando…';
			case 'onboarding.aiStatus.connected': return ({required Object provider}) => 'Conectado a ${provider}. Modelo de conversa padrão selecionado.';
			case 'onboarding.aiStatus.detected': return ({required Object provider}) => 'Detectado: ${provider}';
			case 'onboarding.aiStatus.unrecognizedKey': return 'Formato de chave não reconhecido.';
			case 'onboarding.personaSection.heading': return 'Sua persona';
			case 'onboarding.personaSection.hint': return 'Seu nome nas conversas. Mais detalhes da persona nas Configurações.';
			case 'onboarding.personaSection.nameLabel': return 'Seu nome';
			case 'onboarding.disclaimer.prefix': return 'Li e concordo com o ';
			case 'onboarding.disclaimer.linkText': return 'Aviso legal';
			case 'onboarding.fetchError.noModels': return 'Nenhum modelo retornado. Verifique sua API key.';
			case 'onboarding.fetchError.connectionFailed': return 'Não foi possível conectar. Verifique sua conexão com a internet e a API key.';
			case 'routing.chatCharacter.navigationError': return ({required Object name}) => 'Erro de navegação para a conversa. Personagem: ${name}';
			case 'routing.editCharacter.navigationError': return ({required Object name}) => 'Erro de navegação para a edição. Personagem: ${name}';
			case 'routing.editPreset.navigationError': return ({required Object presetId}) => 'Erro de navegação para editar a predefinição: ${presetId}';
			case 'settings.gearLanguage': return 'Idioma';
			case 'settings.languageSystemDefault': return 'Padrão do sistema';
			case 'settings.gearMenu.settingsTooltip': return 'Configurações';
			case 'settings.gearMenu.mediaDefaultsApp': return 'App';
			case 'settings.gearMenu.mediaDefaultsCharacter': return 'Personagem';
			case 'settings.gearMenu.mediaDefaultsChat': return 'Conversa';
			case 'settings.gearMenu.appSettings': return 'Configurações do app';
			case 'settings.gearMenu.logs': return 'Logs';
			case 'settings.mediaDefaultsDrawerEntry.configurationHeader': return 'Configuração';
			case 'settings.endDrawer.switchPersonaTooltip': return 'Trocar de persona';
			case 'settings.loadingStatus.restoringProviders': return 'Restaurando provedores…';
			case 'settings.loadingStatus.fetchingModelsProgress': return ({required Object completed, required Object total}) => 'Buscando modelos (${completed}/${total})…';
			case 'settings.general.characterFolderTitle': return 'Pasta de personagens';
			case 'settings.general.characterFolderNotSet': return 'Não definida. Necessária para o app funcionar.';
			case 'settings.general.browseButton': return 'Procurar...';
			case 'settings.general.taxonomyTagsTitle': return 'Tags de taxonomia';
			case 'settings.general.appThemeTitle': return 'Tema do app';
			case 'settings.general.themeSystem': return 'Sistema';
			case 'settings.general.themeLight': return 'Claro';
			case 'settings.general.themeDark': return 'Escuro';
			case 'settings.general.themeStyleTitle': return 'Estilo do tema';
			case 'settings.general.themeStyleDefault': return 'Padrão';
			case 'settings.general.themeStyleNeon': return 'Neon';
			case 'settings.general.storyMemoryTitle': return 'Memória da história';
			case 'settings.general.storyMemorySubtitle': return 'Lembra momentos anteriores e traz os relevantes de volta em conversas longas.';
			case 'settings.general.narrativeEngineTitle': return 'Motor narrativo';
			case 'settings.general.narrativeEngineSubtitle': return 'Acompanha a cena e os personagens e faz a história avançar enquanto você conversa.';
			case 'settings.general.promptBreakdownTitle': return 'Mostrar detalhamento do prompt';
			case 'settings.general.promptBreakdownSubtitle': return 'Mostra uma barra sob cada resposta detalhando como o prompt preencheu a janela de contexto do modelo.';
			case 'settings.general.checkUpdatesTitle': return 'Verificar atualizações';
			case 'settings.general.checkUpdatesSubtitle': return 'Verificar se há uma versão mais nova do app disponível.';
			case 'settings.general.websiteTitle': return 'Site';
			case 'settings.general.websiteSubtitle': return 'Visite o site oficial para atualizações e informações.';
			case 'settings.general.disclaimerTitle': return 'Aviso legal e termos';
			case 'settings.general.disclaimerSubtitle': return 'Leia o aviso legal e os termos de uso do aplicativo.';
			case 'settings.general.versionLabel': return ({required Object version, required Object buildNumber}) => 'Versão ${version}+${buildNumber}';
			case 'settings.aiSettingsTab.aiProviders': return 'Provedores de IA';
			case 'settings.aiSettingsTab.mediaDefaults': return 'Padrões de mídia';
			case 'settings.aiTab.refreshSummary': return ({required Object updated, required Object unavailable, required Object errors}) => '${updated} modelos atualizados, ${unavailable} indisponíveis, ${errors} erros.';
			case 'settings.aiTab.newProviderButton': return 'Novo provedor';
			case 'settings.aiTab.cloudProviderMenuItem': return 'Provedor na nuvem';
			case 'settings.aiTab.localProviderMenuItem': return 'Provedor local';
			case 'settings.aiTab.localGgufMenuItem': return 'GGUF local';
			case 'settings.aiTab.noProvidersConfigured': return 'Nenhum provedor de API configurado.';
			case 'settings.aiTab.addingProviderOverlay': return 'Adicionando provedor…';
			case 'settings.aiTab.neverRefreshed': return 'Nunca atualizado';
			case 'settings.aiTab.lastRefreshedLabel': return ({required Object time}) => 'Última atualização: ${time}';
			case 'settings.aiTab.refreshModelsButton': return 'Atualizar modelos';
			case 'settings.aiTab.refreshNowMenuItem': return 'Atualizar agora';
			case 'settings.aiTab.autoNeverMenuItem': return 'Auto: Nunca';
			case 'settings.aiTab.autoDailyMenuItem': return 'Auto: Diariamente ao iniciar';
			case 'settings.aiTab.defaultModelsHeader': return 'Modelos padrão para novas conversas';
			case 'settings.aiTab.editModelTooltip': return 'Editar modelo';
			case 'settings.aiTab.noModelsPlaceholder': return 'Sem modelos';
			case 'settings.aiTab.noCompatibleModelsPlaceholder': return 'Nenhum modelo compatível';
			case 'settings.aiTab.tapToChoosePlaceholder': return 'Toque para escolher';
			case 'settings.aiTab.modelUsedForPrefix': return 'Modelo usado para ';
			case 'settings.aiTab.modelUsedForSuffix': return ' geração';
			case 'settings.aiTab.chooseModelTitle': return 'Escolha um modelo';
			case 'settings.aiTab.temperatureLabel': return ({required Object value}) => 'Temp ${value}';
			case 'settings.aiTab.setDefaultButton': return 'Definir padrão';
			case 'settings.aiTab.addModelButton': return 'Adicionar modelo';
			case 'settings.aiTab.editProviderMenuItem': return 'Editar provedor';
			case 'settings.aiTab.moreTooltip': return 'Mais';
			case 'settings.aiTab.noModelsForProvider': return 'Nenhum modelo configurado para este provedor.';
			case 'settings.aiTab.setDefaultConfirmTitle': return ({required Object provider}) => 'Definir ${provider} como padrão para todos os recursos de IA?';
			case 'settings.aiTab.setDefaultConfirmMessage': return 'Você pode escolher modelos para recursos não suportados\n(como imagem ou vídeo) de outros provedores por conta própria.';
			case 'settings.aiTab.localGgufSubtitle': return ({required Object loaded, required Object native, required Object kv}) => '${loaded} ctx (máx ${native}) · KV ${kv}';
			case 'settings.aiTab.testTtsTooltip': return 'Testar TTS';
			case 'settings.aiTab.ttsTestPhrase': return 'Olá, isto é um teste.';
			case 'settings.aiTab.ttsFailedError': return 'TTS falhou.';
			case 'settings.aiTab.testVideoTooltip': return 'Testar geração de vídeo';
			case 'settings.aiTab.videoGeneratedWebFallback': return 'Vídeo gerado com sucesso (prévia indisponível na web).';
			case 'settings.aiTab.videoFailedError': return 'Vídeo falhou.';
			case 'settings.aiTab.videoLoadFailedMessage': return 'Não foi possível carregar o vídeo gerado.';
			case 'settings.aiTab.presetPickerSearchHint': return 'Buscar por provedor, modelo ou predefinição…';
			case 'settings.aiTab.tempParamAbbrev': return ({required Object value}) => 'temp ${value}';
			case 'settings.aiTab.reasoningParamLabel': return ({required Object level}) => 'raciocínio ${level}';
			case 'settings.presetConfig.testMessageButton': return 'Mensagem de teste';
			case 'settings.presetConfig.testSuccessLabel': return 'Sucesso';
			case 'settings.presetConfig.testFailedLabel': return 'Falhou';
			case 'settings.presetConfig.deleteModelTitle': return 'Excluir modelo?';
			case 'settings.presetConfig.deleteModelMessage': return ({required Object name}) => 'Excluir "${name}" permanentemente? Isso não pode ser desfeito.';
			case 'settings.presetConfig.editModelHeader': return 'Editar modelo';
			case 'settings.presetConfig.addModelHeader': return 'Adicionar modelo';
			case 'settings.presetConfig.resetToDefaultsTooltip': return 'Redefinir para os padrões';
			case 'settings.presetConfig.modelNameLabel': return 'Nome do modelo';
			case 'settings.presetConfig.clearTooltip': return 'Limpar';
			case 'settings.presetConfig.nameRequiredError': return 'O nome é obrigatório';
			case 'settings.presetConfig.modelLabel': return 'Modelo';
			case 'settings.presetConfig.selectModelHint': return 'Selecione um modelo';
			case 'settings.presetConfig.modelRequiredError': return 'O modelo é obrigatório';
			case 'settings.presetConfig.filteredDomainsNote': return ({required Object domains}) => 'Os modelos são filtrados para suportar os domínios ativos: ${domains}';
			case 'settings.presetConfig.requiredValidator': return 'Obrigatório';
			case 'settings.presetConfig.invalidValidator': return 'Inválido';
			case 'settings.presetConfig.testResponseTitle': return 'Resposta';
			case 'settings.providerConfig.noModelsError': return 'Nenhum modelo retornado. Verifique sua API key.';
			case 'settings.providerConfig.connectionFailedError': return 'Não foi possível conectar. Verifique sua conexão com a internet e a API key.';
			case 'settings.providerConfig.deleteProviderTitle': return 'Excluir provedor?';
			case 'settings.providerConfig.deleteProviderMessage': return ({required Object provider}) => 'Excluir permanentemente o provedor ${provider} e todas as suas predefinições? Isso não pode ser desfeito.';
			case 'settings.providerConfig.lockHint': return ({required Object roles}) => 'Não é possível excluir: em uso por ${roles}.';
			case 'settings.providerConfig.editProviderHeader': return 'Editar provedor';
			case 'settings.providerConfig.addProviderHeader': return 'Adicionar provedor';
			case 'settings.providerConfig.apiKeyLabel': return 'API key';
			case 'settings.providerConfig.apiKeyHintRotate': return 'Cole uma nova chave para trocar';
			case 'settings.providerConfig.apiKeyHintNew': return 'Cole sua chave — o provedor é detectado automaticamente';
			case 'settings.providerConfig.supportedProvidersNote': return 'Suporta OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.';
			case 'settings.providerConfig.keyMismatchError': return ({required Object owner, required Object profile}) => 'Esta chave pertence a ${owner}, mas este perfil é ${profile}. Exclua este perfil e adicione um novo.';
			case 'settings.providerConfig.anotherProviderFallback': return 'outro provedor';
			case 'settings.providerConfig.connectingStatus': return 'Conectando…';
			case 'settings.providerConfig.connectedStatus': return ({required Object provider}) => 'Conectado a ${provider}. Predefinições padrão serão criadas.';
			case 'settings.providerConfig.detectedStatus': return ({required Object provider}) => 'Detectado: ${provider}';
			case 'settings.providerConfig.unrecognizedKeyStatus': return 'Formato de chave não reconhecido.';
			case 'settings.localProviderConfig.serverUnreachableMessage': return ({required Object url}) => 'Não foi possível acessar ${url}. Verifique se o seu servidor local (KoboldCpp / Ollama / LM Studio / llama.cpp) está em execução.';
			case 'settings.localProviderConfig.noModelsError': return 'Servidor acessível, mas não retornou modelos. Carregue um modelo no seu servidor local primeiro.';
			case 'settings.localProviderConfig.deleteProviderMessage': return 'Excluir permanentemente este provedor local e todas as suas predefinições? Isso não pode ser desfeito.';
			case 'settings.localProviderConfig.editHeader': return 'Editar provedor local';
			case 'settings.localProviderConfig.addHeader': return 'Adicionar provedor local';
			case 'settings.localProviderConfig.serverUrlLabel': return 'URL do servidor';
			case 'settings.localProviderConfig.serverUrlLockedHelper': return 'Bloqueado. Exclua este provedor e adicione um novo para apontar para outro servidor.';
			case 'settings.localProviderConfig.apiKeyOptionalLabel': return 'API key (opcional)';
			case 'settings.localProviderConfig.apiKeyOptionalHint': return 'Deixe em branco — a maioria dos servidores locais não precisa de uma';
			case 'settings.localProviderConfig.connectFetchButton': return 'Conectar e buscar modelos';
			case 'settings.localProviderConfig.connectedFoundModels': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(n,
				one: 'Conectado. ${n} modelo encontrado.',
				other: 'Conectado. ${n} modelos encontrados.',
			);
			case 'settings.localGguf.haveLocalGgufExpanderTitle': return 'Tenho um arquivo GGUF local';
			case 'settings.localGguf.pickFileLabel': return 'Escolher arquivo GGUF...';
			case 'settings.localGguf.loadModelLabel': return 'Carregar modelo';
			case 'settings.localGguf.nativeContextLabel': return 'Contexto nativo';
			case 'settings.localGguf.freeVramLabel': return 'VRAM livre';
			case 'settings.localGguf.contextSizeLabel': return 'Tamanho do contexto';
			case 'settings.localGguf.kvCacheLabel': return 'Cache KV';
			case 'settings.localGguf.kvCacheAutoLabel': return 'Auto';
			case 'settings.localGguf.modelTooLargeForVramMessage': return ({required Object neededMb, required Object freeMb}) => 'Este modelo precisa de cerca de ${neededMb}MB de memória da GPU, mas só há ${freeMb}MB livres. Feche outros apps que usam a GPU ou escolha um modelo menor / mais quantizado.';
			case 'settings.localGguf.modelBarelyFitsMessage': return ({required Object minimumContext}) => 'Este modelo mal cabe mesmo com cache KV q4_0 em ${minimumContext} tokens. Considere um arquivo de modelo mais agressivamente quantizado.';
			case 'settings.localGguf.readingMetadata': return 'Lendo metadados do modelo…';
			case 'settings.localGguf.architectureLabel': return 'Arquitetura';
			case 'settings.localGguf.autoKvHint': return ({required Object picked, required Object max}) => 'auto: ${picked} (máx ${max})';
			case 'settings.localGguf.maxKvHint': return ({required Object max, required Object picked}) => 'máx ${max} com KV ${picked}';
			case 'settings.localGguf.ctxExceedsMaxError': return ({required Object max, required Object picked}) => 'acima de ${max} com KV ${picked} — o carregamento pode causar OOM';
			case 'settings.localGguf.vramNotDetected': return 'não detectada';
			case 'settings.localGguf.readMetadataFailedError': return ({required Object error}) => 'Falha ao ler metadados GGUF: ${error}';
			case 'settings.localGguf.loadModelFailedError': return ({required Object error}) => 'Falha ao carregar o modelo: ${error}';
			case 'settings.personaDialog.newTitle': return 'Nova persona';
			case 'settings.personaDialog.editTitle': return 'Editar persona';
			case 'settings.personaDialog.nameLabel': return 'Nome';
			case 'settings.personaDialog.nameRequiredError': return 'O nome é obrigatório';
			case 'settings.personaDialog.descriptionLabel': return 'Descrição';
			case 'settings.personaDialog.descriptionHint': return 'Aparência, personalidade, histórico etc.';
			case 'settings.personasTab.cannotDeleteDefaultTooltip': return 'Não é possível excluir a persona padrão';
			case 'settings.personasTab.deleteTooltip': return 'Excluir persona';
			case 'settings.personasTab.cannotDeleteDefaultSnackbar': return 'Não é possível excluir a persona padrão.';
			case 'settings.personasTab.deleteConfirmTitle': return 'Excluir persona';
			case 'settings.personasTab.deleteConfirmMessage': return ({required Object name}) => 'Tem certeza de que deseja excluir "${name}"?';
			case 'settings.updateCheck.upToDateTitle': return 'Atualizado';
			case 'settings.updateCheck.upToDateMessage': return ({required Object version}) => 'Você está na versão atual (${version}).';
			case 'settings.updateCheck.notApplicableTitle': return 'Verificação de atualização';
			case 'settings.updateCheck.notApplicableMessage': return 'A verificação de versão não se aplica na Web.';
			case 'settings.updateCheck.errorTitle': return 'Erro';
			case 'settings.updateCheck.serverErrorMessage': return 'Não foi possível verificar atualizações. Erro do servidor.';
			case 'settings.updateCheck.connectionErrorMessage': return 'Não foi possível verificar atualizações. Verifique sua conexão.';
			case 'workspace.workspaceEndDrawerImage.imageStyleTitle': return 'Estilo de imagem';
			case 'workspace.workspaceEndDrawerImage.noneValue': return 'Nenhum';
			case 'workspace.workspaceEndDrawerVideo.videoStyleTitle': return 'Estilo de vídeo';
			case 'workspace.workspaceEndDrawerDisplay.sectionHeader': return 'Exibição';
			case 'workspace.workspaceEndDrawerDisplay.showCharacterImageTitle': return 'Mostrar imagem do personagem';
			case 'workspace.workspaceEndDrawerDisplay.wideScreenOnlySubtitle': return 'Apenas no editor de tela larga';
			case 'workspace.workspaceEndDrawerAi.sectionHeader': return 'IA';
			case 'workspace.workspaceEndDrawerEditing.sectionHeader': return 'Edição';
			case 'workspace.workspaceEndDrawerExport.sectionHeader': return 'Exportar';
			case 'workspace.workspaceEndDrawerExport.exportPngTitle': return 'Exportar como PNG (V2/V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV3Title': return 'Exportar como JSON (V3)';
			case 'workspace.workspaceEndDrawerExport.exportJsonV2Title': return 'Exportar como JSON (V2)';
			case 'workspace.workspaceEndDrawerChatTheme.resetImagesTitle': return 'Redefinir imagens';
			case 'workspace.workspaceEndDrawerChat.assistantCardEditsSectionHeader': return 'Edições de cartão pelo assistente';
			case 'workspace.workspaceEndDrawer.favoriteLabel': return 'Favorito';
			case 'workspace.workspaceEndDrawer.nodesEngineTitle': return 'Motor NODES';
			case 'workspace.workspaceEndDrawer.debugSnapshotSubtitle': return 'Captura de depuração';
			case 'workspace.workspaceEndDrawer.characterSubtitle': return 'Personagem';
			case 'workspace.stylePresetsDialog.noStyleSelectedMessage': return 'Nenhum estilo selecionado';
			case 'workspace.workspacePage.rebuildingChatIndexMessage': return 'Reconstruindo índice de conversas...';
			case 'workspace.workspacePage.selectChatToStartMessagingMessage': return 'Selecione uma conversa para começar';
			case 'workspace.workspacePage.failedToLoadAssistantMessage': return 'Falha ao carregar o assistente.';
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
