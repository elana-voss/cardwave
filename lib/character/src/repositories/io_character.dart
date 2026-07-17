import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/utils/utils_png.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

enum CharacterLoadingPhaseEnum { scanning, processing }

/// One entry of the non-card index file: `m` is the source PNG's
/// last-modified time in milliseconds since epoch; `s` is its byte size.
/// Both must match the on-disk PNG for the cached "this is not a character
/// card" verdict to be reused on the next launch.
typedef _NonCardEntry = ({int m, int s});

// ----------------------------------------------------------------------------
// Class has NO knowledge of file paths.
// All file paths are provided by callers.
// ----------------------------------------------------------------------------
class IOCharacter {
  IOCharacter({required this.loggingService, required this.appStorage});
  final LoggingService loggingService;
  final AppStorage appStorage;

  Future<void>? _lastThumbnailGeneration;
  final StreamController<CharacterFile> _thumbnailGeneratedStream =
      StreamController<CharacterFile>.broadcast();
  Stream<CharacterFile> get onThumbnailGenerated =>
      _thumbnailGeneratedStream.stream;

  // =========================================================================
  // READING CHARACTER
  // =========================================================================

  // ---------------------------------------------------------
  // Central workhorse method of the app.
  //
  // Returns CharacterFile:
  // - Initializes values
  // - Writes/reads JSON cache file.
  // ---------------------------------------------------------
  Future<CharacterFile> readCharacter(String imagePath) async {
    late CharacterFile charFile;

    try {
      final jsonFinalPath = p.posix.join(
        AppConstants.customCacheCharacterPath,
        p.posix.withoutExtension(imagePath),
        AppConstants.cardJsonFileName,
      );

      // JSON cache exists
      if (await appStorage.fileExists(StorageDomainEnum.cards, jsonFinalPath)) {
        // JSON cache exists, load from it.
        final content = await appStorage.readString(
          StorageDomainEnum.cards,
          jsonFinalPath,
        );
        final jsonData = jsonDecode(content) as Map<String, dynamic>;
        charFile = CharacterFile.fromJson(jsonData);
        charFile.appCardImagePath = imagePath; // Inject runtime path
      } else {
        // JSON cache does not exist. Parse the PNG and create a new cache file.
        final fileBytes = Uint8List.fromList(
          await appStorage.readBytes(StorageDomainEnum.cards, imagePath),
        );
        final card = UtilsPng.parsePng(fileBytes);
        final now = DateTime.now().millisecondsSinceEpoch;
        final generatedId = UtilsApp.generateId(card.name);

        charFile = CharacterFile(
          card: card,
          pngTimestampImported: now,
          pngTimestampLastSaved: now,
          appCardTokenCountPermanent: 0,
          appCardTokenCountAll: 0,
          appCardTokenCountLorebook: 0,
          appCardIsArchive: false,
          appCardId: generatedId,
          appCardRootId: generatedId,
          appCardParentId: '',
          appCardVariantNotes: '',
        );
        charFile.appCardImagePath = imagePath;

        await charFile.updateTokenCounts();

        // Save the new JSON to its correct local path using the getter.
        await appStorage.writeString(
          StorageDomainEnum.cards,
          charFile.appCardJsonPath,
          jsonEncode(charFile.toJson()),
        );
      }
    } on PngParseException catch (e, stackTrace) {
      loggingService.error(
        '[IOCharacter] Failed to parse field "${e.cause.key ?? '?'}" in ${p.posix.basename(imagePath)}: ${e.cause.innerError ?? '?'}',
        e.cause,
        stackTrace,
        const JsonEncoder.withIndent('  ').convert(e.jsonData),
      );
      rethrow;
    } on CheckedFromJsonException catch (e, stackTrace) {
      loggingService.error(
        '[IOCharacter] Failed to parse field "${e.key ?? '?'}" in ${p.posix.basename(imagePath)}: ${e.innerError ?? '?'}',
        e,
        stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      loggingService.warning(
        '[IOCharacter] Error reading character from ${p.posix.basename(imagePath)}: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
    return charFile;
  }

  /// Returns the non-card index entries, or an empty map when the file is
  /// missing or unreadable. A corrupt file is logged and rebuilt by the
  /// next pass-1 scan.
  Future<Map<String, _NonCardEntry>> _loadNonCardIndex() async {
    if (!await appStorage.fileExists(
      StorageDomainEnum.cards,
      AppConstants.customNonCardIndexPath,
    )) {
      return {};
    }
    try {
      final content = await appStorage.readString(
        StorageDomainEnum.cards,
        AppConstants.customNonCardIndexPath,
      );
      final raw = jsonDecode(content) as Map<String, dynamic>;
      final entries = raw.map((path, value) {
        final entry = value as Map<String, dynamic>;
        return MapEntry(path, (m: entry['m'] as int, s: entry['s'] as int));
      });
      loggingService.logCache(
        '[non_card_index] loaded ${entries.length} entries',
      );
      return entries;
    } on Exception catch (e, stackTrace) {
      loggingService.warning(
        '[IOCharacter] Could not read non_card_index.json, rebuilding: $e',
        e,
        stackTrace,
      );
      return {};
    }
  }

  /// Writes the merged non-card index back to disk. Failures are logged
  /// and swallowed so a cache-write blip cannot fail `loadCharacters()`
  /// after the characters have already loaded successfully.
  Future<void> _writeNonCardIndex(Map<String, _NonCardEntry> entries) async {
    try {
      final encoded = jsonEncode(
        entries.map((path, e) => MapEntry(path, {'m': e.m, 's': e.s})),
      );
      await appStorage.writeString(
        StorageDomainEnum.cards,
        AppConstants.customNonCardIndexPath,
        encoded,
      );
    } on Exception catch (e, stackTrace) {
      loggingService.warning(
        '[IOCharacter] Could not write non_card_index.json: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Scans the library folder and returns every PNG that holds a character
  /// card, each tagged with its current modified-time and size. This is the
  /// cheap pass: it never parses card bodies — the caller diffs these stats
  /// against the library database to decide which cards to actually read. The
  /// positive cache (a `card.json` sidecar means it's a card) and the negative
  /// cache (unchanged non-card PNGs are skipped) work exactly as before.
  Future<List<({String imagePath, int mtime, int size})>> scanValidCardStats({
    void Function(CharacterLoadingPhaseEnum phase, int current, int total)?
    onProgress,
  }) async {
    final allPngPaths = await appStorage.listDirectory(
      StorageDomainEnum.cards,
      '',
      extensions: ['.png'],
      recursive: true,
    );

    // Negative cache: skip the chunk walk for PNGs already proven not to
    // be character cards (when their mtime+size are unchanged on disk).
    final loadedNonCardIndex = await _loadNonCardIndex();
    final newlySeenNonCards = <String, _NonCardEntry>{};

    final valid = <({String imagePath, int mtime, int size})>[];
    const preScanBatchSize = 10;

    for (var i = 0; i < allPngPaths.length; i += preScanBatchSize) {
      final end = (i + preScanBatchSize < allPngPaths.length)
          ? i + preScanBatchSize
          : allPngPaths.length;
      final batch = allPngPaths.sublist(i, end);

      final checkFutures = batch.map((imagePath) async {
        try {
          final stat = await appStorage.statFile(
            StorageDomainEnum.cards,
            imagePath,
          );
          final mtime = stat?.modified.millisecondsSinceEpoch ?? 0;
          final size = stat?.size ?? 0;

          // Fast path: positive cache (card.json sidecar exists).
          final jsonPath = p.posix.join(
            AppConstants.customCacheCharacterPath,
            p.posix.withoutExtension(imagePath),
            AppConstants.cardJsonFileName,
          );
          if (await appStorage.fileExists(StorageDomainEnum.cards, jsonPath)) {
            return (imagePath: imagePath, mtime: mtime, size: size);
          }

          // Fast path: negative cache (mtime+size unchanged since the last
          // confirmed not-a-card verdict).
          if (stat != null) {
            final cached = loadedNonCardIndex[imagePath];
            if (cached != null && cached.m == mtime && cached.s == size) {
              return null;
            }
          }

          // Slow path: read PNG and check for 'chara'/'ccv3' chunk.
          final bytes = await appStorage.readBytes(
            StorageDomainEnum.cards,
            imagePath,
          );
          if (UtilsPng.hasCharaChunk(Uint8List.fromList(bytes))) {
            return (imagePath: imagePath, mtime: mtime, size: size);
          }

          if (stat != null) {
            newlySeenNonCards[imagePath] = (m: mtime, s: size);
          }
        } on Object {
          // Ignore errors during pre-scan (e.g., corrupted PNGs, locked files).
        }
        return null;
      }).toList();

      final results = await Future.wait(checkFutures);
      valid.addAll(
        results.whereType<({String imagePath, int mtime, int size})>(),
      );

      // Report pre-scan progress. This may cause the progress indicator to
      // fill up, then reset for the second pass, which is expected.
      onProgress?.call(
        CharacterLoadingPhaseEnum.scanning,
        i + batch.length,
        allPngPaths.length,
      );
    }

    // Reconcile the non-card index: drop entries for PNGs no longer on disk,
    // merge in newly seen entries, skip the write when nothing changed.
    final allPngPathsSet = allPngPaths.toSet();
    final mergedIndex = <String, _NonCardEntry>{
      for (final entry in loadedNonCardIndex.entries)
        if (allPngPathsSet.contains(entry.key)) entry.key: entry.value,
      ...newlySeenNonCards,
    };
    final indexChanged =
        newlySeenNonCards.isNotEmpty ||
        mergedIndex.length != loadedNonCardIndex.length;
    if (indexChanged) {
      final prunedCount = loadedNonCardIndex.keys
          .where((k) => !allPngPathsSet.contains(k))
          .length;
      loggingService.logCache(
        '[non_card_index] wrote total=${mergedIndex.length} '
        'fresh=${newlySeenNonCards.length} pruned=$prunedCount',
      );
      await _writeNonCardIndex(mergedIndex);
    }

    return valid;
  }

  Future<CharacterFile> createCharacter({
    required CharacterCardV3 card,
    required Uint8List imageBytes,
    String? targetDirectory,
  }) async {
    var safeName = card.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (safeName.trim().isEmpty) safeName = 'New Character';
    final imageFilename = '$safeName.png';

    final imagePath = targetDirectory != null && targetDirectory.isNotEmpty
        ? p.posix.join(targetDirectory, imageFilename)
        : imageFilename;

    if (await appStorage.fileExists(StorageDomainEnum.cards, imagePath)) {
      throw Exception(
        'A character named "$safeName" already exists in this folder.',
      );
    }

    card.name = safeName;

    await appStorage.writeBytes(StorageDomainEnum.cards, imagePath, imageBytes);

    final generatedId = UtilsApp.generateId(card.name);
    final now = DateTime.now().millisecondsSinceEpoch;

    final characterFile = CharacterFile(
      card: card,
      pngTimestampImported: now,
      pngTimestampLastSaved: now,
      appCardTokenCountPermanent: 0,
      appCardTokenCountAll: 0,
      appCardTokenCountLorebook: 0,
      appCardIsArchive: false,
      appCardId: generatedId,
      appCardRootId: generatedId,
      appCardParentId: '',
      appCardVariantNotes: '',
    );
    characterFile.appCardImagePath = imagePath;

    await characterFile.updateTokenCounts();

    await saveJsonInPNGandCache(characterFile);

    return characterFile;
  }

  // =========================================================================
  // WRITE
  // =========================================================================

  /// Mutates timestamps.
  /// Saves JSON to cache.
  /// Saves JSON in PNG.
  Future<void> saveJsonInPNGandCache(CharacterFile characterFile) async {
    await saveJsonInCache(characterFile, ensureUnDirty: true);
    await _saveJsonInPNG(characterFile);
  }

  /// Overwrites new JSON in existing PNG.
  Future<void> _saveJsonInPNG(CharacterFile characterFile) async {
    if (await appStorage.fileExists(
      StorageDomainEnum.cards,
      characterFile.appCardImagePath,
    )) {
      final imageBytes = await appStorage.readBytes(
        StorageDomainEnum.cards,
        characterFile.appCardImagePath,
      );
      // Keep a one-deep backup of the last-known-good PNG before re-embedding
      // and overwriting it. The atomic write (see AppStorageWindows) prevents a
      // torn file, but a bug in embedJsonInPng could still produce a valid-but-
      // wrong PNG; unlike settings.json the user's artwork has no recovery
      // mirror, so this `.bak` is its only safety net. `.bak` is excluded from
      // library scans because they filter to the `.png` extension.
      await appStorage.writeBytes(
        StorageDomainEnum.cards,
        '${characterFile.appCardImagePath}.bak',
        Uint8List.fromList(imageBytes),
      );
      final newBytes = UtilsPng.embedJsonInPng(
        characterFile.card,
        Uint8List.fromList(imageBytes),
      );
      await appStorage.writeBytes(
        StorageDomainEnum.cards,
        characterFile.appCardImagePath,
        newBytes,
      );
    }
  }

  /// Save the JSON file in cache.
  /// Updates relevant timestamps.
  Future<void> saveJsonInCache(
    CharacterFile file, {
    bool ensureUnDirty = false,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    file.appCardTimestampLastSaved = nowMs;

    file.card.modificationDate = nowMs ~/ 1000;
    file.card.creationDate ??= file.card.modificationDate;

    if (ensureUnDirty) {
      file.pngTimestampLastSaved = file.appCardTimestampLastSaved!;
    }

    await appStorage.writeString(
      StorageDomainEnum.cards,
      file.appCardJsonPath,
      jsonEncode(file.toJson()),
    );
  }

  /// Replaces the avatar PNG of a character card while preserving its embedded JSON data.
  Future<void> replaceCharacterImage(
    CharacterFile file,
    Uint8List newImageBytes,
  ) async {
    final newBytes = UtilsPng.embedJsonInPng(file.card, newImageBytes);
    await appStorage.writeBytes(
      StorageDomainEnum.cards,
      file.appCardImagePath,
      newBytes,
    );
  }

  // =========================================================================
  // IMPORT CHARACTER
  // =========================================================================

  Future<CharacterFile> importCharacter({
    required Uint8List bytes,
    required String filename,
  }) async {
    final namePart = p.posix.basenameWithoutExtension(filename);
    final extPart = p.posix.extension(filename);

    var counter = 1;
    var destName = filename;
    var destPath = destName;

    while (await appStorage.fileExists(StorageDomainEnum.cards, destPath)) {
      destName = '${namePart}_$counter$extPart';
      destPath = destName;
      counter++;
    }

    try {
      await appStorage.writeBytes(StorageDomainEnum.cards, destPath, bytes);
      return await readCharacter(destPath);
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        '[IOCharacter] Error importing character $filename: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  // =========================================================================
  // DELETE
  // =========================================================================

  Future<void> deleteCharacter(CharacterFile characterFile) async {
    // Delete user's PNG (lives in the user's character folder, not the cache).
    if (await appStorage.fileExists(
      StorageDomainEnum.cards,
      characterFile.appCardImagePath,
    )) {
      await appStorage.deleteFile(
        StorageDomainEnum.cards,
        characterFile.appCardImagePath,
      );
    }
    // Also remove the `.bak` sidecar written by _saveJsonInPNG; otherwise a
    // full copy of the "deleted" card (artwork + embedded data) stays on disk.
    final bakPath = '${characterFile.appCardImagePath}.bak';
    if (await appStorage.fileExists(StorageDomainEnum.cards, bakPath)) {
      await appStorage.deleteFile(StorageDomainEnum.cards, bakPath);
    }
    // Delete entire character cache folder (card.json, card.thumb.png, chats/).
    if (await appStorage.directoryExists(
      StorageDomainEnum.cards,
      characterFile.appCardCharacterFolder,
    )) {
      await appStorage.deleteDirectory(
        StorageDomainEnum.cards,
        characterFile.appCardCharacterFolder,
      );
    }
  }

  Future<CharacterFile> cloneCharacter(CharacterFile original) async {
    final clonedFile = CharacterFile.fromJson(original.toJson());

    final dir = p.posix.dirname(original.appCardImagePath);
    final ext = p.posix.extension(original.appCardImagePath);
    final originalBaseName = p.posix.basenameWithoutExtension(
      original.appCardImagePath,
    );

    var newFilename = '${originalBaseName}_copy$ext';
    var newPath = p.posix.join(dir, newFilename);
    var counter = 1;

    while (await appStorage.fileExists(StorageDomainEnum.cards, newPath)) {
      newFilename = '${originalBaseName}_copy_$counter$ext';
      newPath = p.posix.join(dir, newFilename);
      counter++;
    }

    final originalBytes = await appStorage.readBytes(
      StorageDomainEnum.cards,
      original.appCardImagePath,
    );

    // Assign completely unique IDs and file path for the clone
    clonedFile.appCardId = UtilsApp.generateId(newPath);
    clonedFile.appCardParentId = original.appCardId;
    clonedFile.appCardImagePath = newPath;

    await appStorage.writeBytes(
      StorageDomainEnum.cards,
      newPath,
      Uint8List.fromList(originalBytes),
    );

    clonedFile.pngTimestampImported = DateTime.now().millisecondsSinceEpoch;
    await saveJsonInPNGandCache(clonedFile);
    return clonedFile;
  }

  // =========================================================================
  // THUMBNAIL GENERATION
  // =========================================================================

  Future<void> ensureThumbnail(CharacterFile file) async {
    if (await appStorage.fileExists(
      StorageDomainEnum.cards,
      file.appCardThumbnailPath,
    )) {
      _thumbnailGeneratedStream.add(file);
      return;
    }

    // Serialize thumbnail generation to prevent OOM/Hangs during mass import
    final previous = _lastThumbnailGeneration ?? Future.value();
    final completer = Completer<void>();
    _lastThumbnailGeneration = completer.future;

    try {
      await previous;
    } on Object {
      // Ignore errors from previous tasks
    }

    try {
      final bytes = await appStorage.readBytes(
        StorageDomainEnum.cards,
        file.appCardImagePath,
      );
      final thumbBytes = await UtilsImage.generateThumbnailBytes(
        Uint8List.fromList(bytes),
      );
      if (thumbBytes != null) {
        await appStorage.writeBytes(
          StorageDomainEnum.cards,
          file.appCardThumbnailPath,
          thumbBytes,
        );
        _thumbnailGeneratedStream.add(file);
      }
    } on Exception catch (e, stackTrace) {
      loggingService.warning(
        'Error generating thumbnail for ${file.appCardThumbnailPath}: $e',
        e,
        stackTrace,
      );
    } finally {
      completer.complete();
    }
  }
}
