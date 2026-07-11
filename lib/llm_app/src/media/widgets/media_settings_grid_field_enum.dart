import 'package:cardwave/i18n/gen/translations.g.dart';

/// Identifies one of the 16 multi-layer media settings rendered in the
/// grid. Order is the render order. Each row carries its label, cell type,
/// and whether the App layer participates (only the three model-preset
/// rows do).
enum MediaSettingsGridField {
  imageModel(cellType: MediaSettingsGridCellType.preset, hasAppLayer: true),
  imageAspectRatio(
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  imageNsfwAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imageToolSelfieAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imageToolSelfieCaptionsAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imagePromptPrefix(
    cellType: MediaSettingsGridCellType.text,
    hasAppLayer: false,
  ),
  videoModel(cellType: MediaSettingsGridCellType.preset, hasAppLayer: true),
  videoResolution(
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoAspectRatio(
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoDuration(
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoNsfwAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  videoToolSendAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  videoPromptPrefix(
    cellType: MediaSettingsGridCellType.text,
    hasAppLayer: false,
  ),
  ttsModel(cellType: MediaSettingsGridCellType.preset, hasAppLayer: true),
  ttsVoice(cellType: MediaSettingsGridCellType.dropdown, hasAppLayer: false),
  ttsLanguage(
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  webToolFetchAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  nameToolSuggestAllowed(
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  );

  const MediaSettingsGridField({
    required this.cellType,
    required this.hasAppLayer,
  });

  final MediaSettingsGridCellType cellType;
  final bool hasAppLayer;

  String get label => switch (this) {
    MediaSettingsGridField.imageModel => t.llmApp.mediaField.imageModel,
    MediaSettingsGridField.imageAspectRatio =>
      t.llmApp.mediaField.imageAspectRatio,
    MediaSettingsGridField.imageNsfwAllowed =>
      t.llmApp.mediaField.imageNsfwAllowed,
    MediaSettingsGridField.imageToolSelfieAllowed =>
      t.llmApp.mediaField.imageToolSelfieAllowed,
    MediaSettingsGridField.imageToolSelfieCaptionsAllowed =>
      t.llmApp.mediaField.imageToolSelfieCaptionsAllowed,
    MediaSettingsGridField.imagePromptPrefix =>
      t.llmApp.mediaField.imagePromptPrefix,
    MediaSettingsGridField.videoModel => t.llmApp.mediaField.videoModel,
    MediaSettingsGridField.videoResolution =>
      t.llmApp.mediaField.videoResolution,
    MediaSettingsGridField.videoAspectRatio =>
      t.llmApp.mediaField.videoAspectRatio,
    MediaSettingsGridField.videoDuration =>
      t.llmApp.mediaField.videoDuration,
    MediaSettingsGridField.videoNsfwAllowed =>
      t.llmApp.mediaField.videoNsfwAllowed,
    MediaSettingsGridField.videoToolSendAllowed =>
      t.llmApp.mediaField.videoToolSendAllowed,
    MediaSettingsGridField.videoPromptPrefix =>
      t.llmApp.mediaField.videoPromptPrefix,
    MediaSettingsGridField.ttsModel => t.llmApp.mediaField.ttsModel,
    MediaSettingsGridField.ttsVoice => t.llmApp.mediaField.ttsVoice,
    MediaSettingsGridField.ttsLanguage => t.llmApp.mediaField.ttsLanguage,
    MediaSettingsGridField.webToolFetchAllowed =>
      t.llmApp.mediaField.webToolFetchAllowed,
    MediaSettingsGridField.nameToolSuggestAllowed =>
      t.llmApp.mediaField.nameToolSuggestAllowed,
  };

  /// Section label used to group rows in the page. Derived from the field
  /// name prefix.
  String get sectionLabel {
    final n = name;
    if (n.startsWith('image')) return t.llmApp.mediaSection.image;
    if (n.startsWith('video')) return t.llmApp.mediaSection.video;
    if (n.startsWith('tts')) return t.llmApp.mediaSection.tts;
    if (n.startsWith('web')) return t.llmApp.mediaSection.web;
    if (n.startsWith('nameTool')) return t.llmApp.mediaSection.names;
    return n;
  }
}

enum MediaSettingsGridCellType { preset, dropdown, tristate, text }

/// Which layer a cell sits in. Drives both visual state (winning vs
/// overridden vs inheriting) and write dispatch.
enum MediaSettingsGridLayer { app, character, session }

/// The entry point that opened the grid. All three columns always render;
/// this only picks which column the narrow-layout switcher opens on
/// (app / character / session).
///   - [sessionOnly]: legacy; no live entry point today.
///   - [allColumns]: chat-drawer "Configure all" — opens on session.
///   - [appOnly]: gear-menu "Media Defaults" — opens on app.
///   - [appAndCharacter]: editor-drawer "Configure media" — opens on character.
enum MediaSettingsGridFocus { sessionOnly, allColumns, appOnly, appAndCharacter }
