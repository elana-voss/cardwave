/// Identifies one of the 15 multi-layer media settings rendered in the
/// grid. Order is the render order. Each row carries its label, cell type,
/// and whether the App layer participates (only the three model-preset
/// rows do).
enum MediaSettingsGridField {
  imageModel(
    label: 'Image model',
    cellType: MediaSettingsGridCellType.preset,
    hasAppLayer: true,
  ),
  imageAspectRatio(
    label: 'Image aspect ratio',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  imageNsfwAllowed(
    label: 'Image NSFW allowed',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imageToolSelfieAllowed(
    label: 'Can send selfies',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imageToolSelfieCaptionsAllowed(
    label: 'Allow selfie captions',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  imagePromptPrefix(
    label: 'Image style',
    cellType: MediaSettingsGridCellType.text,
    hasAppLayer: false,
  ),
  videoModel(
    label: 'Video model',
    cellType: MediaSettingsGridCellType.preset,
    hasAppLayer: true,
  ),
  videoResolution(
    label: 'Video resolution',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoAspectRatio(
    label: 'Video aspect ratio',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoDuration(
    label: 'Video duration',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  videoNsfwAllowed(
    label: 'Video NSFW allowed',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  videoToolSendAllowed(
    label: 'Can send videos',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  ),
  videoPromptPrefix(
    label: 'Video style',
    cellType: MediaSettingsGridCellType.text,
    hasAppLayer: false,
  ),
  ttsModel(
    label: 'TTS model',
    cellType: MediaSettingsGridCellType.preset,
    hasAppLayer: true,
  ),
  ttsVoice(
    label: 'TTS voice',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  ttsLanguage(
    label: 'TTS language',
    cellType: MediaSettingsGridCellType.dropdown,
    hasAppLayer: false,
  ),
  webToolFetchAllowed(
    label: 'Allow web fetch',
    cellType: MediaSettingsGridCellType.tristate,
    hasAppLayer: false,
  );

  const MediaSettingsGridField({
    required this.label,
    required this.cellType,
    required this.hasAppLayer,
  });

  final String label;
  final MediaSettingsGridCellType cellType;
  final bool hasAppLayer;

  /// Section label used to group rows in the page. Derived from the field
  /// name prefix.
  String get sectionLabel {
    final n = name;
    if (n.startsWith('image')) return 'Image';
    if (n.startsWith('video')) return 'Video';
    if (n.startsWith('tts')) return 'TTS';
    if (n.startsWith('web')) return 'Web';
    return n;
  }
}

enum MediaSettingsGridCellType { preset, dropdown, tristate, text }

/// Which layer a cell sits in. Drives both visual state (winning vs
/// overridden vs inheriting) and write dispatch.
enum MediaSettingsGridLayer { app, character, session }

/// Which column(s) the page renders. Set by the entry point.
///   - [sessionOnly]: legacy single-column view; no live entry point today.
///   - [allColumns]: chat-drawer "Configure all" — app + character + session.
///   - [appOnly]: gear-menu "Media Defaults" — app column only.
///   - [appAndCharacter]: editor-drawer "Configure media" — app + character.
enum MediaSettingsGridFocus { sessionOnly, allColumns, appOnly, appAndCharacter }
