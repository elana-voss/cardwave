class AppConstants {
  static const String appPackageName = 'Cardwave';
  static final String appPackageNameLowerCase = appPackageName.toLowerCase();

  static const String website = 'https://cardwave.cc';
  static const String disclaimer = '$website/disclaimer.html';
  static const String version = 'https://cardwave.cc/version.json';

  static const String defaultPersonaName = 'Jax';

  static const String defaultAssistantId = 'Cass_Assistant.png';

  static final String settingsFileName =
      '${AppConstants.appPackageNameLowerCase}_settings.json';

  /// Sibling of [settingsFileName] under the app-data folder. Mirror of
  /// the minimum fields needed to reconstruct each provider
  /// (`{id, provider_type, api_key, base_url}`) plus its own
  /// `schema_version`. Written on every settings save and read only when
  /// `settings.json` is missing or invalidated, so API keys survive an
  /// `AppConstants.cacheVersion` bump.
  static const String llmProvidersRecoveryFileName =
      'llm-providers-recovery.json';

  /// User-editable copy of the taxonomy under the app-data folder. On launch
  /// the app reads this if it exists; otherwise it falls back to the bundled
  /// asset at [taxonomyAssetPath]. Mutations in the editor write through to
  /// this file. Devs ship a new bundled asset by copying this back into
  /// `assets/tags/` and rebuilding.
  static const String taxonomyFileName = 'taxonomy.json';

  /// Bundled seed taxonomy. Loaded on first launch when the app-data file
  /// at [taxonomyFileName] doesn't exist yet.
  static const String taxonomyAssetPath = 'assets/tags/taxonomy.json';

  /// Per-character JSON sidecar inside `customCacheCharacterPath/<basename>/`.
  /// Mirror of the parsed PNG payload; lets subsequent launches skip the PNG
  /// chunk walk for known cards.
  static const String cardJsonFileName = 'card.json';

  /// Per-character thumbnail PNG inside `customCacheCharacterPath/<basename>/`.
  static const String cardThumbnailFileName = 'card.thumb.png';

  /// Per-card sidecar file name under each character's cache folder.
  /// The vector dimension, model id, and per-chunk token cap live with
  /// the embeddings package — only the on-disk filename is app-side.
  static const String embeddingsSidecarFilename = 'card.embedding.bin';

  static const Set<String> nsfwTriggers = {
    'nsfw',
    'smut',
  };

  static const double dialogMaxWidth = 800;

  static const double mobileBreakpoint = 700;
  static const double tabletBreakpoint = 900;

  static const double defaultMaxResponseTokens = 350;
  static const int fallbackMaxResponseTokens = 4096;
  static const int fallbackContextLength = 128000;

  /// Pixel distance from the bottom (in reverse-scroll coords, so `position.pixels`)
  /// at which the chat is considered "stuck to bottom" for auto-follow purposes.
  /// Must be tight — SillyTavern uses 1px — otherwise small user drags during
  /// streaming never register as detached and the 250ms auto-scroll tick yanks
  /// the user back to the live edge mid-gesture.
  static const double chatScrollStickThreshold = 1;
  static const double chatSwipeVelocityThreshold = 300;

  static const double gridMaxCrossAxisExtent = 500;
  static const double gridMainAxisExtent = 160;
  static const double gridCrossAxisSpacing = 16;
  static const double gridMainAxisSpacing = 16;
  static const double gridThumbnailWidth = 120;

  static const double editorMaxWidth = 1000;
  static const double editorDesktopImageWidth = 250;

  /// Bumped via `--dart-define=APP_VERSION=<major.minor>`; change resets settings+cache.
  static const String cacheVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  /// Root cache folder placed inside the user's character folder.
  /// Single source of truth — all `customCache*Path` entries live under this.
  static final String customCacheRootPath =
      '.cache_${AppConstants.appPackageNameLowerCase}_$cacheVersion';

  /// Per-character folder containing card.json, card.thumb.png, and chats/.
  static final String customCacheCharacterPath =
      '$customCacheRootPath/characters';

  /// Negative-cache index of PNGs in the character folder that were
  /// confirmed not to contain a character payload. Read on every scan to
  /// skip the chunk walk for unchanged non-card PNGs.
  static final String customNonCardIndexPath =
      '$customCacheCharacterPath/non_card_index.json';

  /// Root folder for groups. Each group owns `<groupId>/group.json` (its
  /// definition) and a `<groupId>/chats/` subfolder that holds its chat
  /// sessions, media cache, and per-session sidecars. Group content is fully
  /// nested under the group folder so deleting a group is a single subtree
  /// removal.
  static final String customCacheGroupPath = '$customCacheRootPath/groups';

  static const int fallbackMaxRetries = 3;
  static const int fallbackLlmTimeoutSeconds = 60;

  /// Per-turn cap on `send_selfie` calls. The selfie tool is side-effect
  /// only — one selfie per assistant turn is the documented UX contract.
  static const int toolSendSelfieMaxPerTurn = 1;

  /// Per-turn cap on `send_video` calls. Videos cost real money and take
  /// minutes to generate; one per turn matches the selfie contract and
  /// prevents a runaway loop from billing the user repeatedly.
  static const int toolSendVideoMaxPerTurn = 1;

  /// Per-turn cap on `fetch_website` calls. Three lets the model gather
  /// supporting links (e.g. an article + cited references) without giving
  /// it an unbounded research budget.
  static const int toolFetchWebsiteMaxPerTurn = 3;

  /// Hard ceiling on rounds in the manual tool loop (chat → tool → chat
  /// → tool → …). Caps cost when a misbehaving model keeps emitting tool
  /// calls; the loop bails after this many model invocations.
  static const int toolLoopMaxIterations = 5;

  /// Per-request HTTP timeout for the `fetch_website` tool's GET.
  static const Duration toolFetchWebsiteTimeout = Duration(seconds: 15);

  /// Hard byte cap on the response body before HTML parsing. Bigger pages
  /// are truncated at the byte boundary (the dropped tail may corrupt
  /// the last DOM node, which the parser tolerates).
  static const int toolFetchWebsiteMaxBodyBytes = 1 * 1024 * 1024;

  /// Hard char cap on the markdown returned to the LLM. Keeps a single
  /// fetch from blowing the model's context budget; if exceeded, a
  /// `\n\n…(truncated)` marker is appended so the model knows.
  static const int toolFetchWebsiteMaxResponseChars = 8000;

  static const Duration modelRefreshIntervalDaily = Duration(hours: 24);

  /// Replace PNG, max size
  static const int maxImageFileSizeBytes = 10 * 1024 * 1024;
  static const String maxImageFileSizeLabel = '10 MB';

  /// Snackbar shown when card export (PNG / JSON) fails. Duplicated across
  /// the grid item action menu and the workspace end-drawer export tiles.
  static const String exportFailedMessage =
      'Export failed. See logs for details.';
}
