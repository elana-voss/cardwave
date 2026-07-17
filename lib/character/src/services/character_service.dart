import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:cardwave/character/src/models/card_list_item.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/models/library_card_filter.dart';
import 'package:cardwave/character/src/repositories/character_repository.dart';
import 'package:cardwave/character/src/repositories/io_character.dart';
import 'package:cardwave/character/src/utils/utils_png.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/search/search.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;

/// Wraps non-Exception failures from `UtilsPng` (FlutterError, PlatformException)
/// so callers can use idiomatic `on Exception catch`.
class CharacterExportException implements Exception {
  const CharacterExportException(this.message);
  final String message;

  @override
  String toString() => 'CharacterExportException: $message';
}

/// Signals that one or more delete steps in `removeCharacterCompletely` failed
/// (e.g. chat history wiped but card files lingered, or vice versa). The
/// affected file is already gone from the in-memory list either way.
class CharacterDeleteException implements Exception {
  const CharacterDeleteException(this.message);
  final String message;

  @override
  String toString() => 'CharacterDeleteException: $message';
}

/// Output of [CharacterService.pickAndParseImportFiles]. `validFiles` are PNGs
/// whose embedded card payload parsed successfully; `parseFailures` are
/// already-formatted "filename: reason" strings ready for the import-errors
/// dialog. Empty `validFiles` means there's nothing to import.
class BulkImportParseResult {
  const BulkImportParseResult({
    required this.validFiles,
    required this.parseFailures,
  });
  final List<XFile> validFiles;
  final List<String> parseFailures;
}

/// Output of [CharacterService.categorizeImportFiles]. `conflicts` are files
/// whose target filename collides with an existing character on disk;
/// `nonConflicts` can be imported without renaming.
class BulkImportCategorized {
  const BulkImportCategorized({
    required this.conflicts,
    required this.nonConflicts,
  });
  final List<XFile> conflicts;
  final List<XFile> nonConflicts;
}

/// Output of [CharacterService.importParsedFiles]. `failedFileNames` lists each
/// file the import loop logged but did not add to the character list.
class BulkImportResult {
  const BulkImportResult({
    required this.importedCount,
    required this.failedFileNames,
  });
  final int importedCount;
  final List<String> failedFileNames;
}

class CharacterService extends ChangeNotifier {
  CharacterService({
    required this.characterRepository,
    required this.chatRepository,
    required this.settingsService,
    required this.appStorage,
    required this.loggingService,
    required this.searchService,
  }) {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        // TODO(qcheck): consider an exhaustive switch(state) here later (the lint
        // suggests it); not done now to avoid touching the background flush-
        // to-PNG path.
        // ignore: qcheck/prefer_switch_with_enums
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) {
          unawaited(_flushDirtyFilesToPng());
        }
      },
      // On desktop, window close fires onExitRequested before the process is
      // torn down. Await the dirty-PNG flush here (the paused/hidden path
      // above can stay fire-and-forget on mobile) so unsaved card edits in the
      // 1s debounce window reach disk before exit.
      onExitRequested: () async {
        await _flushDirtyFilesToPng();
        return AppExitResponse.exit;
      },
    );
  }
  final CharacterRepository characterRepository;
  final ChatRepository chatRepository;
  final SettingsService settingsService;
  final AppStorage appStorage;
  final LoggingService loggingService;
  final SearchService searchService;

  AppLifecycleListener? _lifecycleListener;
  bool _isFlushingToPng = false;

  // Full cards loaded and edited this session that may have a cache-only save
  // not yet flushed to PNG. Bounded to open/edited cards, so the background
  // flush no longer needs the whole library in memory.
  final Map<String, CharacterFile> _dirtyCards = {};
  final Map<String, Timer> _saveDebouncers = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // True once the first library scan has completed; lets the grid trigger the
  // initial load exactly once instead of keying off an in-memory list size.
  bool _hasScanned = false;
  bool get hasScanned => _hasScanned;

  String _loadingStatus = t.character.loadingStatus.initial;
  String get loadingStatus => _loadingStatus;

  double? _loadingProgress;
  double? get loadingProgress => _loadingProgress;

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    externalCardMutation.dispose();
    super.dispose();
  }

  /// Reads one card's full body on demand (chat, editor, actions). The grid
  /// renders light [CardListItem]s; everything that needs the heavy card body
  /// loads it here.
  Future<CharacterFile> loadFull(String imagePath) =>
      characterRepository.loadFull(imagePath);

  /// Loads the full card whose name equals [name] (first match), or null when
  /// none. Convenience for callers that key off the display name.
  Future<CharacterFile?> loadByName(String name) async {
    final path = await characterRepository.pathByName(name);
    if (path == null) return null;
    return characterRepository.loadFull(path);
  }

  // ---- Library queries (grid + filters) ----
  // Thin passthroughs to the repository so controllers/widgets keep talking to
  // the service layer, never the repository directly.

  Future<int> countCardGroups(LibraryCardFilter filter) =>
      characterRepository.countCardGroups(filter);

  Future<int> countCards(LibraryCardFilter filter) =>
      characterRepository.countCards(filter);

  Future<List<String>> allCardPaths() => characterRepository.allCardPaths();

  Future<List<CardListItem>> pageCards({
    required LibraryCardFilter filter,
    required LibrarySortColumn sortColumn,
    required bool descending,
    required int offset,
    required int limit,
  }) => characterRepository.pageCards(
    filter: filter,
    sortColumn: sortColumn,
    descending: descending,
    offset: offset,
    limit: limit,
  );

  Future<List<({CardListItem item, bool isOriginal})>> pageCardsByActivity({
    required LibraryCardFilter filter,
    required int offset,
    required int limit,
  }) => characterRepository.pageCardsByActivity(
    filter: filter,
    offset: offset,
    limit: limit,
  );

  Future<Map<String, ({int variantCount, bool isOriginal})>>
  variantInfoForPaths(List<String> paths) =>
      characterRepository.variantInfoForPaths(paths);

  Future<List<CardListItem>> cardsByPaths(
    List<String> paths,
    LibraryCardFilter filter,
  ) => characterRepository.cardsByPaths(paths, filter);

  Future<List<CardListItem>> cardsByRootId(String rootId) =>
      characterRepository.cardsByRootId(rootId);

  Future<Map<String, int>> creatorCounts(LibraryCardFilter filter) =>
      characterRepository.creatorCounts(filter);

  Future<Map<String, int>> tagCounts(LibraryCardFilter filter) =>
      characterRepository.tagCounts(filter);

  Future<Map<String, int>> folderLeafCounts(LibraryCardFilter filter) =>
      characterRepository.folderLeafCounts(filter);

  Future<List<String>> distinctFolders() =>
      characterRepository.distinctFolders();

  /// Full cards with no preview description — batch-generate work-list. Loads
  /// each matching card; bounded by how many are missing.
  Future<List<CharacterFile>> cardsMissingPreview() =>
      _loadPaths(characterRepository.pathsMissingPreview());

  /// Full cards with no app-level tags — batch auto-tag work-list.
  Future<List<CharacterFile>> cardsMissingAppTags() =>
      _loadPaths(characterRepository.pathsMissingAppTags());

  /// Loads every card in the library, full. Not paged — for the few power
  /// surfaces (group picker, character switcher) that need the whole set.
  Future<List<CharacterFile>> loadAll() =>
      _loadPaths(characterRepository.allCardPaths());

  /// Loads the full cards for the given app ids (e.g. a group's members).
  Future<List<CharacterFile>> loadByAppCardIds(List<String> ids) =>
      _loadPaths(characterRepository.pathsByAppCardIds(ids));

  Future<List<CharacterFile>> _loadPaths(
    Future<List<String>> pathsFuture,
  ) async {
    final paths = await pathsFuture;
    final files = <CharacterFile>[];
    for (final path in paths) {
      try {
        files.add(await characterRepository.loadFull(path));
      } on Exception {
        // Skip a card that can't be read.
      }
    }
    return files;
  }

  /// Absolute path to the configured library root for character cards, or
  /// empty string if no path is configured. Exposed for the desktop-Windows
  /// "save as" picker that needs an `initialDirectory`.
  String get cardRootPath =>
      settingsService.pathResolver(StorageDomainEnum.cards) ?? '';

  /// Returns `null` if [absolutePath] is a valid character save location
  /// (inside the configured library root). Otherwise returns a human-readable
  /// reason for the failure, suitable for surfacing in a "Try again?" dialog.
  String? validateCharacterSavePath(String absolutePath) {
    final root = cardRootPath;
    if (root.isEmpty) {
      return t.character.savePathValidation.noLibraryFolder;
    }

    final rootDirCanonical = p.canonicalize(root);
    final selectedPathCanonical = p.canonicalize(absolutePath);

    final isWithin =
        p.isWithin(rootDirCanonical, selectedPathCanonical) ||
        p.equals(rootDirCanonical, p.dirname(selectedPathCanonical));
    if (!isWithin) {
      return t.character.savePathValidation.mustBeInsideLibrary;
    }
    return null;
  }

  /// Decomposes an absolute save-picker result into the basename (used as the
  /// new character's name) and the relative `targetDirectory` (null for the
  /// library root). Caller must ensure the path was already validated via
  /// [validateCharacterSavePath].
  ({String name, String? targetDirectory}) parseCharacterSavePath(
    String absolutePath,
  ) {
    final rootDir = p.normalize(p.absolute(cardRootPath));
    final selectedPath = p.normalize(p.absolute(absolutePath));
    final relativeDir = p.dirname(p.relative(selectedPath, from: rootDir));
    final targetDirectory = relativeDir == '.'
        ? null
        : relativeDir.replaceAll(p.separator, '/');
    final name = p.basenameWithoutExtension(absolutePath);
    return (name: name, targetDirectory: targetDirectory);
  }

  /// Creates a new character via the repository, adds it to the in-memory
  /// list, and notifies. Throws on failure so the caller can surface a
  /// "Try again?" dialog or snackbar.
  Future<CharacterFile> createCharacterAt({
    required String name,
    String? targetDirectory,
  }) async {
    final newChar = await characterRepository.createCharacter(
      AppConstants.appPackageName,
      name: name,
      targetDirectory: targetDirectory,
    );
    await characterRepository.upsertLibraryRow(newChar);
    unawaited(searchService.queueReindex(newChar));
    notifyListeners();
    return newChar;
  }

  // =========================================================================
  // DELETE CHARACTER
  // =========================================================================

  //
  // Deletes:
  // 1. Character card PNG
  // 2. Character thumbnail
  // 3. Character JSON
  //
  Future<void> removeCharacterCompletely(CharacterFile characterFile) async {
    // Drop from the light index + search index first so the grid stops showing
    // it immediately and active file locks release; the heavy file deletes
    // follow below.
    final path = characterFile.appCardImagePath;
    _dirtyCards.remove(path);
    await characterRepository.deleteLibraryRow(path);
    searchService.removeFromIndex(path);
    notifyListeners();

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    loggingService.info('[DELETE] Deleting: ${characterFile.appCardImagePath}');

    var hasError = false;

    try {
      await chatRepository.deleteAllChatsForCharacter(characterFile);
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[DELETE] Failed to delete chats: $e',
        e,
        stackTrace,
      );
      hasError = true;
    }

    try {
      await characterRepository.deleteCharacter(characterFile);
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[DELETE] Failed to delete files: $e',
        e,
        stackTrace,
      );
      hasError = true;
    }

    if (hasError) {
      throw const CharacterDeleteException('Some files could not be deleted.');
    }
  }

  // =========================================================================
  // CLONE CHARACTER
  // =========================================================================

  Future<void> cloneCharacter(CharacterFile original) async {
    final clonedFile = await characterRepository.cloneCharacter(original);
    await characterRepository.upsertLibraryRow(clonedFile);
    unawaited(searchService.queueReindex(clonedFile));
    notifyListeners();
  }

  // =========================================================================
  // PERSISTENCE
  // =========================================================================

  /// Iterates through all loaded characters and flushes any pending UI changes to PNG.
  ///
  /// Called strictly by the internal `AppLifecycleListener` when the app
  /// is backgrounded, paused, or detached to ensure no data is lost upon unexpected exit.
  /// No snackbar on failure: the app is in the middle of being hidden/detached, so a
  /// snackbar is unlikely to be visible. The log entry is the durable record.
  Future<void> _flushDirtyFilesToPng() async {
    if (_isFlushingToPng) return;
    _isFlushingToPng = true;

    try {
      for (final characterFile in _dirtyCards.values.toList()) {
        await flushJsonInCacheAndPngIfDirtyOrPending(characterFile);
      }
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[Auto-Save] Error flushing dirty files to PNG: $e',
        e,
        stackTrace,
      );
    } finally {
      _isFlushingToPng = false;
    }
  }

  /// Queues a fast JSON cache save with a 1-second debounce.
  ///
  /// Called by UI components (like TextFields) during frequent state
  /// updates (e.g., typing). Prevents hammering the disk with heavy I/O operations
  /// while the user is actively making rapid changes.
  void queueJsonInCacheDebounced(CharacterFile characterFile) {
    final path = characterFile.appCardImagePath;
    _saveDebouncers[path]?.cancel();
    _saveDebouncers[path] = Timer(const Duration(seconds: 1), () {
      _saveDebouncers.remove(path);
      unawaited(saveJsonInCacheNow(characterFile));
    });
  }

  /// Checks if a character has a pending debounced save or is flagged as dirty.
  /// If true, it cancels the timer and forces an immediate heavy save to the PNG.
  ///
  /// Called by UI routing wrappers (e.g., `PopScope`) when navigating
  /// away from the editor or chat, or by `_flushDirtyFilesToPng` during app backgrounding.
  /// Ensures no pending changes are left hanging when a view is destroyed.
  Future<void> flushJsonInCacheAndPngIfDirtyOrPending(
    CharacterFile characterFile,
  ) async {
    final path = characterFile.appCardImagePath;
    final hasPendingSave = _saveDebouncers.containsKey(path);
    if (hasPendingSave) {
      _saveDebouncers[path]?.cancel();
      _saveDebouncers.remove(path);
    }

    if (hasPendingSave || characterFile.isDirty) {
      loggingService.info(
        '[Auto-Save] Flushing pending/dirty character to PNG: ${characterFile.card.name}',
      );
      await saveJsonInCacheAndPngNow(characterFile);
    }
  }

  /// Immediately updates token counts and persists the character data to both the
  /// fast JSON cache and the heavy encoded PNG file. Cancels any pending debouncers.
  ///
  /// Called by explicit "Overwrite PNG" UI actions or internally by
  /// `flushJsonInCacheAndPngIfNeeded` when safe navigation/lifecycle exit is required.
  ///
  /// Failures are logged but swallowed: most call sites are autosave or
  /// fire-and-forget UI actions where surfacing a per-failure snackbar would
  /// be more annoying than informative. A persistent dirty flag on the
  /// character file would survive a failed write here, so the next save
  /// attempt eventually succeeds.
  Future<void> saveJsonInCacheAndPngNow(CharacterFile characterFile) async {
    final path = characterFile.appCardImagePath;
    _saveDebouncers[path]?.cancel();
    _saveDebouncers.remove(path);

    try {
      await characterFile.updateTokenCounts();
      await characterRepository.saveJsonInPNGandCache(characterFile);

      // No global imageCache clear here: this path re-embeds JSON into the
      // PNG without changing the pixels, and card thumbnails/avatars are
      // rendered via content-keyed `Image.memory` (see ImageCharacter), so a
      // global clear only forced every unrelated image app-wide to re-decode
      // — a visible flicker/jank spike — without refreshing this card.

      await characterRepository.upsertLibraryRow(characterFile);
      _dirtyCards.remove(characterFile.appCardImagePath);
      unawaited(searchService.queueReindex(characterFile));
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[Storage] Error saving character JSON AND PNG: $e',
        e,
        stackTrace,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Immediately updates token counts and persists the character data strictly to the
  /// fast JSON cache, bypassing the heavy PNG encoding step. Cancels any pending debouncers.
  ///
  /// Called by background AI tasks, Chat updates, quick UI toggles (like "favorite"),
  /// or the `queueJsonInCacheDebounced` timer. Use when fast, guaranteed JSON persistence is needed.
  ///
  /// Failures are logged but swallowed: this is the autosave path, fired
  /// dozens of times per session (every keystroke debounce, every chat
  /// message, every favorite toggle). Surfacing each failure as a snackbar
  /// would be intrusive. The dirty flag survives a failed write so the next
  /// save attempt covers the lost write.
  Future<void> saveJsonInCacheNow(CharacterFile characterFile) async {
    final path = characterFile.appCardImagePath;
    _saveDebouncers[path]?.cancel();
    _saveDebouncers.remove(path);

    try {
      await characterFile.updateTokenCounts();
      await characterRepository.saveJsonInCache(characterFile);
      await characterRepository.upsertLibraryRow(characterFile);
      _dirtyCards[characterFile.appCardImagePath] = characterFile;
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[Storage] Error saving character JSON: $e',
        e,
        stackTrace,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Fires when an external mutation (currently: an assistant-chat
  /// card-edit tool call that landed) has changed an open card. Carries
  /// the `appCardId` of the changed card so listeners with multiple
  /// open editors can filter to their own. The counter exists only so
  /// successive mutations to the same card produce distinct values
  /// (ValueNotifier dedupes equal record values).
  ///
  /// This is intentionally a separate signal from [notifyListeners]: the
  /// service's main change-notifier fires on every keystroke-debounced
  /// save, so wiring the editor's full rebuild path to it would thrash.
  final ValueNotifier<({String appCardId, int counter})?> externalCardMutation =
      ValueNotifier(null);

  /// Applies a tool-driven mutation to [file], persists it through the
  /// fast cache path, and bumps [externalCardMutation] so any open editor
  /// for this card can rebuild and pick up the new field values. The
  /// [mutate] callback is the place to do all card mutations for one
  /// approval batch — a single save + single notifier bump covers the
  /// whole batch.
  Future<void> applyExternalCardEdits(
    CharacterFile file,
    VoidCallback mutate,
  ) async {
    mutate();
    await saveJsonInCacheNow(file);
    final prev = externalCardMutation.value;
    externalCardMutation.value = (
      appCardId: file.appCardId,
      counter: (prev?.counter ?? 0) + 1,
    );
  }

  /// Replaces the avatar PNG of a character card while preserving its embedded JSON data,
  /// generating a new thumbnail, and syncing the cache.
  ///
  /// Called by the UI when a user manually picks a new image to represent the character.
  /// Throws on failure (invalid PNG, IO error) so the caller can surface a snackbar.
  Future<void> replaceCharacterImage(
    CharacterFile characterFile,
    XFile newImageFile,
  ) async {
    final imageBytes = await newImageFile.readAsBytes();
    await characterRepository.replaceCharacterImage(characterFile, imageBytes);

    // Delete the old thumbnail so a new one can be generated from the new image.
    if (await appStorage.fileExists(
      StorageDomainEnum.cards,
      characterFile.appCardThumbnailPath,
    )) {
      await appStorage.deleteFile(
        StorageDomainEnum.cards,
        characterFile.appCardThumbnailPath,
      );
    }
    await characterRepository.ensureThumbnail(characterFile);

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    await saveJsonInCacheNow(characterFile);
  }

  // =========================================================================
  // EXISTS CHARACTER
  // =========================================================================

  Future<bool> characterPngExists(String imageFilename) =>
      appStorage.fileExists(StorageDomainEnum.cards, imageFilename);

  // =========================================================================
  // LOAD
  // =========================================================================

  /// Loads the default assistant card on demand. The assistant id is its image
  /// path (e.g. `Cass_Assistant.png`), so this reads it straight from disk.
  Future<CharacterFile?> resolveAssistantFile() async {
    final assistantId = settingsService.settings.defaultAssistantId;

    if (assistantId == null || assistantId.isEmpty) {
      loggingService.info('No default assistant ID configured.');
      return null;
    }

    try {
      final file = await characterRepository.loadFull(assistantId);
      loggingService.info(
        'Resolved assistant character: ${file.card.name} (${file.appCardId})',
      );
      return file;
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        'Failed to resolve assistant character with ID: $assistantId.',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Loads characters from disk.
  Future<void> loadCharacters() async {
    if (_isLoading) return;

    _isLoading = true;
    _loadingProgress = null;
    notifyListeners();

    _loadingStatus = t.character.loadingStatus.scanningForCharacters;
    notifyListeners();

    final onProgressCallback =
        (CharacterLoadingPhaseEnum phase, int current, int total) {
          if (current % 10 == 0 || current == total) {
            _loadingProgress = total > 0 ? current / total : 0;
            switch (phase) {
              case CharacterLoadingPhaseEnum.scanning:
                _loadingStatus = t.character.loadingStatus
                    .scanningForCharactersProgress(
                      current: current,
                      total: total,
                    );
              case CharacterLoadingPhaseEnum.processing:
                _loadingStatus = t.character.loadingStatus
                    .loadingCharactersProgress(current: current, total: total);
            }
            notifyListeners();
          }
        };

    try {
      final diff = await characterRepository.scanLibrary(
        onProgress: onProgressCallback,
      );
      loggingService.info(
        '[Init] Library indexed: ${diff.changed.length} changed, '
        '${diff.removed.length} removed.',
      );
      searchService.applyLibraryDiff(
        changed: diff.changed,
        removed: diff.removed,
      );
    } on Exception catch (e, stackTrace) {
      // Failure leaves the grid showing whatever the light index last held
      // (empty on a first run). A snackbar would be lost during initial load
      // (no Scaffold yet); the log entry is the durable record.
      loggingService.error(
        '[Init] Error loading characters: $e',
        e,
        stackTrace,
      );
    } finally {
      _isLoading = false;
      _hasScanned = true;
      notifyListeners();
    }
  }

  // =========================================================================
  // IMPORT
  // =========================================================================

  /// Opens the system file picker for PNG character cards and parses each
  /// selected file's embedded card payload via [UtilsPng.parsePng].
  ///
  /// Returns `null` when the user cancels the picker (no files selected) so
  /// callers can short-circuit without showing a "0 imported" snackbar. The
  /// returned [BulkImportParseResult.parseFailures] entries are pre-formatted
  /// `"filename: reason"` strings ready for the import-errors dialog.
  Future<BulkImportParseResult?> pickAndParseImportFiles() async {
    final typeGroup = XTypeGroup(
      label: t.character.characterFilesTypeGroupLabel,
      extensions: const ['png'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return null;

    final parseFailures = <String>[];
    final validFiles = <XFile>[];

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        UtilsPng.parsePng(bytes);
        validFiles.add(file);
      } on Exception catch (e, stackTrace) {
        loggingService.error(
          '[Import] Error reading ${file.name}: $e',
          e,
          stackTrace,
        );
        parseFailures.add('${file.name}: $e');
      }
    }

    return BulkImportParseResult(
      validFiles: validFiles,
      parseFailures: parseFailures,
    );
  }

  /// Splits already-parsed import candidates by whether their filename collides
  /// with an existing character's PNG basename. Conflicts must be auto-renamed
  /// at import time to preserve both files; non-conflicts can be written
  /// straight through.
  Future<BulkImportCategorized> categorizeImportFiles(
    List<XFile> validFiles,
  ) async {
    final conflicts = <XFile>[];
    final nonConflicts = <XFile>[];

    // Imports are written into the library root, so a name collision means a
    // PNG with that filename already sits there.
    for (final file in validFiles) {
      if (await characterPngExists(file.name)) {
        conflicts.add(file);
      } else {
        nonConflicts.add(file);
      }
    }

    return BulkImportCategorized(
      conflicts: conflicts,
      nonConflicts: nonConflicts,
    );
  }

  /// Imports each file via [characterRepository], auto-renaming filename
  /// collisions inside `importCharacter`. Per-file failures are logged and
  /// returned in [BulkImportResult.failedFileNames] so the caller can surface
  /// them; a single [notifyListeners] fires at the end if anything was added.
  Future<BulkImportResult> importParsedFiles(List<XFile> files) async {
    var importedCount = 0;
    final failedFileNames = <String>[];

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final importedFile = await characterRepository.importCharacter(
          bytes,
          file.name,
        );
        await characterRepository.ensureThumbnail(importedFile);
        await characterRepository.upsertLibraryRow(importedFile);
        unawaited(searchService.queueReindex(importedFile));
        importedCount++;
      } on Exception catch (e, stackTrace) {
        loggingService.error(
          '[Import] Error importing ${file.name}: $e',
          e,
          stackTrace,
        );
        failedFileNames.add(file.name);
      }
    }

    if (importedCount > 0) {
      notifyListeners();
    }

    return BulkImportResult(
      importedCount: importedCount,
      failedFileNames: failedFileNames,
    );
  }

  // =========================================================================
  // EXPORT
  // =========================================================================

  /// Throws [CharacterExportException] on platform-side failure (e.g. file
  /// picker cancelled or denied). Other exceptions from `UtilsPng` propagate
  /// raw. `FlutterError` is intentionally NOT caught — it's an `Error`
  /// subclass and signals a programmer bug (missing asset, etc.).
  /// Caller logs the failure; we just translate the platform exception into
  /// a typed one so the snackbar message is generic.
  Future<void> exportAsPng(CharacterFile characterFile) async {
    try {
      await UtilsPng.exportAsPng(characterFile);
    } on PlatformException catch (_, st) {
      Error.throwWithStackTrace(
        const CharacterExportException(
          'Failed to export PNG (platform error).',
        ),
        st,
      );
    }
  }

  /// Throws [CharacterExportException] on platform-side failure (same
  /// reasoning as [exportAsPng]).
  Future<void> exportAsJson(
    CharacterFile characterFile, {
    bool asV2 = false,
  }) async {
    try {
      await UtilsPng.exportAsJson(characterFile, asV2: asV2);
    } on PlatformException catch (_, st) {
      Error.throwWithStackTrace(
        const CharacterExportException(
          'Failed to export JSON (platform error).',
        ),
        st,
      );
    }
  }

}
