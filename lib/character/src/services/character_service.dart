import 'dart:async';

import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/repositories/character_repository.dart';
import 'package:cardwave/character/src/repositories/io_character.dart';
import 'package:cardwave/character/src/utils/utils_png.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
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

  List<CharacterFile> _characterFiles = [];
  final Map<String, Timer> _saveDebouncers = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _loadingStatus = 'Loading...';
  String get loadingStatus => _loadingStatus;

  double? _loadingProgress;
  double? get loadingProgress => _loadingProgress;

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    externalCardMutation.dispose();
    super.dispose();
  }

  /// Returns the list of characters held in memory.
  /// Since this returns the direct list reference, modifications to this list
  /// (like add/remove) will persist in memory for the session.
  List<CharacterFile> get characterFiles => _characterFiles;

  /// Returns a sorted list of unique directory paths that contain characters.
  ///
  /// Returns an empty list if all characters are in the root directory, as no
  /// filtering is needed. The root directory is represented as 'Root'.
  List<String> get directoriesWithCharacters {
    if (_characterFiles.isEmpty) {
      return [];
    }
    final dirs = _characterFiles
        .map((file) => p.posix.dirname(file.appCardImagePath))
        .toSet();

    // If there's only one directory and it's the root, no filter is needed.
    // `dirs` is non-empty here — it's derived from the non-empty
    // `_characterFiles` list checked above — so `length <= 1` means exactly 1.
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (dirs.length <= 1 && dirs.first == '.') {
      return [];
    }

    final dirList = dirs.map((d) => d == '.' ? 'Root' : d).toList();
    dirList.sort((a, b) {
      if (a == 'Root') return -1;
      if (b == 'Root') return 1;
      return a.compareTo(b);
    });
    return dirList;
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
    if (root.isEmpty) return 'No library folder configured.';

    final rootDirCanonical = p.canonicalize(root);
    final selectedPathCanonical = p.canonicalize(absolutePath);

    final isWithin =
        p.isWithin(rootDirCanonical, selectedPathCanonical) ||
        p.equals(rootDirCanonical, p.dirname(selectedPathCanonical));
    if (!isWithin) {
      return 'Characters must be saved inside your library folder.';
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
    _characterFiles.add(newChar);
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
    // Remove from state immediately to update the UI and drop active file locks
    _characterFiles.removeWhere(
      (f) => f.appCardImagePath == characterFile.appCardImagePath,
    );
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
      throw const CharacterDeleteException(
        'Some files could not be deleted.',
      );
    }
  }

  // =========================================================================
  // CLONE CHARACTER
  // =========================================================================

  Future<void> cloneCharacter(CharacterFile original) async {
    final clonedFile = await characterRepository.cloneCharacter(original);
    _characterFiles.add(clonedFile);
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
      for (final characterFile in _characterFiles) {
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

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

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
    void Function() mutate,
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

  CharacterFile? resolveAssistantFile() {
    final assistantId = settingsService.settings.defaultAssistantId;

    if (assistantId == null || assistantId.isEmpty) {
      loggingService.info('No default assistant ID configured.');
      return null;
    }

    final file = _characterFiles
        .where(
          (char) =>
              char.appCardId == assistantId ||
              char.appCardImagePath.endsWith(assistantId),
        )
        .firstOrNull;

    if (file == null) {
      loggingService.error(
        'Failed to resolve assistant character with ID: $assistantId. Character not found in loaded files.',
      );
      return null;
    }

    loggingService.info(
      'Successfully resolved assistant character: ${file.card.name} (${file.appCardId})',
    );
    return file;
  }

  /// Loads characters from disk.
  Future<void> loadCharacters() async {
    if (_isLoading) return;

    _isLoading = true;
    _loadingStatus = 'Copying assistant...';
    _loadingProgress = null;
    notifyListeners();

    await _copyDefaultAssistant();

    _loadingStatus = 'Scanning for characters...';
    notifyListeners();

    final onProgressCallback =
        (CharacterLoadingPhaseEnum phase, int current, int total) {
          if (current % 10 == 0 || current == total) {
            _loadingProgress = total > 0 ? current / total : 0;
            switch (phase) {
              case CharacterLoadingPhaseEnum.scanning:
                _loadingStatus =
                    'Scanning for characters...\n$current / $total';
              case CharacterLoadingPhaseEnum.processing:
                _loadingStatus = 'Loading characters...\n$current / $total';
            }
            notifyListeners();
          }
        };

    try {
      _characterFiles = await characterRepository.readDirectory(
        onProgress: onProgressCallback,
      );
      loggingService.info(
        '[Init] Loaded ${_characterFiles.length} characters successfully.',
      );
    } on Exception catch (e, stackTrace) {
      // Failure leaves `_characterFiles` empty and the grid renders the empty
      // state. A snackbar would be lost during initial load (no Scaffold yet)
      // and on user-triggered reloads the empty grid plus the log entry are
      // sufficient. Callers are not given a typed signal here because the
      // empty list IS the user-visible signal.
      loggingService.error(
        '[Init] Error loading characters: $e',
        e,
        stackTrace,
      );
    } finally {
      _isLoading = false;
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
    const typeGroup = XTypeGroup(label: 'Character Files', extensions: ['png']);
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
  BulkImportCategorized categorizeImportFiles(List<XFile> validFiles) {
    final conflicts = <XFile>[];
    final nonConflicts = <XFile>[];

    for (final file in validFiles) {
      final fileMatch = _characterFiles.any((characterFile) {
        final existingFileName = p.posix.basename(
          characterFile.appCardImagePath,
        );
        return existingFileName == file.name;
      });
      if (fileMatch) {
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
        _characterFiles.add(importedFile);
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
    } on PlatformException {
      throw const CharacterExportException(
        'Failed to export PNG (platform error).',
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
    } on PlatformException {
      throw const CharacterExportException(
        'Failed to export JSON (platform error).',
      );
    }
  }

  /// `characterRepository.copyDefaultAssistant` calls `rootBundle.load`, which
  /// throws `FlutterError` (an Error subclass) if the bundled asset is missing.
  /// That signals a build/pubspec misconfiguration — a programmer bug, not a
  /// runtime condition to handle, so no try/catch here. `loadCharacters` wraps
  /// this call in `on Exception catch`, which intentionally won't catch the
  /// FlutterError; it'll propagate to the global zone error handler.
  Future<void> _copyDefaultAssistant() async {
    final didCopyAssistant = await characterRepository.copyDefaultAssistant();
    if (didCopyAssistant) {
      loggingService.info('[COPY ASSISTANT] Copied assistant.');
    } else {
      loggingService.info(
        '[COPY ASSISTANT] Not copied assistant, file already present.',
      );
    }
  }
}
