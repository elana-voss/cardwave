import 'dart:async';
import 'dart:convert';

import 'package:cardwave/character/src/db/library_database.dart';
import 'package:cardwave/character/src/models/card_list_item.dart';
import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/models/library_card_filter.dart';
import 'package:cardwave/character/src/repositories/io_character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/services.dart';

class CharacterRepository {
  CharacterRepository({required this.loggingService, required this.appStorage})
    : _ioCharacter = IOCharacter(
        loggingService: loggingService,
        appStorage: appStorage,
      ),
      _library = CacheDatabaseHandle(
        appStorage: appStorage,
        relativePath:
            '${AppConstants.customCacheRootPath}/library/cards.sqlite',
        webName: 'cardwave_library',
        opener: LibraryDatabase.open,
      );
  final LoggingService loggingService;
  final AppStorage appStorage;
  final IOCharacter _ioCharacter;

  // The light index database beside the current card library, opened on first
  // use and reopened when the library folder changes.
  final CacheDatabaseHandle<LibraryDatabase> _library;

  Stream<CharacterFile> get onThumbnailGenerated =>
      _ioCharacter.onThumbnailGenerated;

  Future<LibraryDatabase> _ensureLibraryOpen() => _library.ensureOpen();

  /// Scans the library folder, brings the light index up to date, and reports
  /// which cards changed (added or edited on disk since last launch) and which
  /// were removed. Parses card bodies one at a time and discards them, so
  /// memory stays flat however many cards changed. The caller forwards
  /// [changed]/[removed] to the search service for re-indexing.
  Future<({List<String> changed, List<String> removed})> scanLibrary({
    void Function(CharacterLoadingPhaseEnum phase, int current, int total)?
    onProgress,
  }) async {
    final db = await _ensureLibraryOpen();
    final stats = await _ioCharacter.scanValidCardStats(onProgress: onProgress);

    final existing = {for (final s in await db.allStats()) s.imagePath: s};
    final onDisk = {for (final s in stats) s.imagePath};

    final removed = [
      for (final path in existing.keys)
        if (!onDisk.contains(path)) path,
    ];
    for (final path in removed) {
      await db.deleteByPath(path);
    }

    final changedStats = [
      for (final s in stats)
        if (existing[s.imagePath] == null ||
            existing[s.imagePath]!.mtime != s.mtime ||
            existing[s.imagePath]!.size != s.size)
          s,
    ];

    final changed = <String>[];
    final total = changedStats.length;
    var done = 0;
    onProgress?.call(CharacterLoadingPhaseEnum.processing, 0, total);
    for (final s in changedStats) {
      try {
        final file = await _ioCharacter.readCharacter(s.imagePath);
        await db.upsertCard(file, mtime: s.mtime, size: s.size);
        changed.add(s.imagePath);
      } on Object {
        // readCharacter already logged the parse failure; skip this card.
      }
      done++;
      onProgress?.call(CharacterLoadingPhaseEnum.processing, done, total);
    }

    return (changed: changed, removed: removed);
  }

  /// Reads one card's full body on demand (chat, editor, actions). The grid
  /// never holds these — it renders [CardListItem]s from the light index.
  Future<CharacterFile> loadFull(String imagePath) =>
      _ioCharacter.readCharacter(imagePath);

  Future<int> countCardGroups(LibraryCardFilter filter) async =>
      (await _ensureLibraryOpen()).countGroups(filter);

  Future<int> countCards(LibraryCardFilter filter) async =>
      (await _ensureLibraryOpen()).countCards(filter);

  Future<List<String>> allCardPaths() async =>
      (await _ensureLibraryOpen()).allCardPaths();

  Future<List<String>> pathsMissingPreview() async =>
      (await _ensureLibraryOpen()).pathsMissingPreview();

  Future<List<String>> pathsMissingAppTags() async =>
      (await _ensureLibraryOpen()).pathsMissingAppTags();

  /// One page of variant groups for the grid, each a display card plus its
  /// variant count, ordered by [sortColumn]/[descending].
  Future<List<CardListItem>> pageCards({
    required LibraryCardFilter filter,
    required LibrarySortColumn sortColumn,
    required bool descending,
    required int offset,
    required int limit,
  }) async {
    final db = await _ensureLibraryOpen();
    final rows = await db.pageGroups(
      filter: filter,
      sortColumn: sortColumn,
      descending: descending,
      offset: offset,
      limit: limit,
    );
    return [for (final r in rows) _toItem(r.card, r.variantCount)];
  }

  /// One page of individual cards (each variant its own row) ordered by last
  /// activity, with each card's group size and oldest-card flag — backs the
  /// character switcher's flat list.
  Future<List<({CardListItem item, bool isOriginal})>> pageCardsByActivity({
    required LibraryCardFilter filter,
    required int offset,
    required int limit,
  }) async {
    final db = await _ensureLibraryOpen();
    final rows = await db.pageCardsByActivity(
      filter: filter,
      offset: offset,
      limit: limit,
    );
    return [
      for (final r in rows)
        (item: _toItem(r.card, r.variantCount), isOriginal: r.isOriginal),
    ];
  }

  Future<Map<String, ({int variantCount, bool isOriginal})>> variantInfoForPaths(
    List<String> paths,
  ) async => (await _ensureLibraryOpen()).variantInfoForPaths(paths);

  /// Light rows for [paths] that also pass [filter] — the relevance path. Each
  /// carries variant count 1; the controller regroups by root id and reorders
  /// by rank.
  Future<List<CardListItem>> cardsByPaths(
    List<String> paths,
    LibraryCardFilter filter,
  ) async {
    final db = await _ensureLibraryOpen();
    final rows = await db.cardsByPaths(paths, filter);
    return [for (final r in rows) _toItem(r, 1)];
  }

  /// Every card in one variant group, oldest first — backs the variants sheet.
  Future<List<CardListItem>> cardsByRootId(String rootId) async {
    final db = await _ensureLibraryOpen();
    final rows = await db.cardsByRootId(rootId);
    return [for (final r in rows) _toItem(r, rows.length)];
  }

  Future<Map<String, int>> creatorCounts(LibraryCardFilter filter) async =>
      (await _ensureLibraryOpen()).creatorCounts(filter);

  Future<Map<String, int>> tagCounts(LibraryCardFilter filter) async =>
      (await _ensureLibraryOpen()).tagCounts(filter);

  Future<Map<String, int>> folderLeafCounts(LibraryCardFilter filter) async =>
      (await _ensureLibraryOpen()).folderLeafCounts(filter);

  Future<List<String>> distinctFolders() async =>
      (await _ensureLibraryOpen()).distinctFolders();

  Future<String?> pathByName(String name) async =>
      (await _ensureLibraryOpen()).pathByName(name);

  Future<List<String>> pathsByAppCardIds(List<String> ids) async =>
      (await _ensureLibraryOpen()).pathsByAppCardIds(ids);

  /// Refreshes the light index row for [file] after a save / edit / clone /
  /// import, restatting the PNG so change detection stays correct.
  Future<void> upsertLibraryRow(CharacterFile file) async {
    final db = await _ensureLibraryOpen();
    final stat = await appStorage.statFile(
      StorageDomainEnum.cards,
      file.appCardImagePath,
    );
    await db.upsertCard(
      file,
      mtime: stat?.modified.millisecondsSinceEpoch ?? 0,
      size: stat?.size ?? 0,
    );
  }

  Future<void> deleteLibraryRow(String imagePath) async {
    final db = await _ensureLibraryOpen();
    await db.deleteByPath(imagePath);
  }

  CardListItem _toItem(LibraryCardData data, int variantCount) {
    final tags = (jsonDecode(data.tagsJson) as List).cast<String>();
    return CardListItem(
      appCardImagePath: data.imagePath,
      name: data.name,
      creator: data.creator,
      tags: tags,
      previewDescription: data.previewDescription,
      appCardRootId: data.rootId,
      isFavorite: data.isFavorite,
      variantNotes: data.variantNotes,
      pngTimestampImported: data.pngTimestampImported,
      pngTimestampLastSaved: data.pngTimestampLastSaved,
      timestampLastChatted: data.timestampLastChatted,
      timestampLastChattedDismissed: data.timestampLastChattedDismissed,
      variantCount: variantCount,
    );
  }

  Future<void> deleteCharacter(CharacterFile characterFile) =>
      _ioCharacter.deleteCharacter(characterFile);

  Future<void> saveJsonInPNGandCache(CharacterFile characterFile) async {
    await _ioCharacter.saveJsonInPNGandCache(characterFile);
  }

  Future<void> replaceCharacterImage(
    CharacterFile characterFile,
    Uint8List newImageBytes,
  ) async {
    await _ioCharacter.replaceCharacterImage(characterFile, newImageBytes);
  }

  Future<void> saveJsonInCache(CharacterFile characterFile) async {
    await _ioCharacter.saveJsonInCache(characterFile);
  }

  Future<CharacterFile> cloneCharacter(CharacterFile original) {
    return _ioCharacter.cloneCharacter(original);
  }

  Future<CharacterFile> importCharacter(
    Uint8List bytes,
    String filename,
  ) {
    return _ioCharacter.importCharacter(bytes: bytes, filename: filename);
  }

  Future<void> ensureThumbnail(CharacterFile file) async {
    await _ioCharacter.ensureThumbnail(file);
  }

  Future<CharacterFile> createCharacter(
    String creator, {
    required String name,
    String? targetDirectory,
  }) async {
    Uint8List bytesToUse;
    final cardToUse = CharacterCardV3.createDefault();
    cardToUse.creator = creator;
    cardToUse.name = name;

    final byteData = await rootBundle.load(
      'assets/images/default_character.png',
    );
    bytesToUse = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    return _ioCharacter.createCharacter(
      card: cardToUse,
      imageBytes: bytesToUse,
      targetDirectory: targetDirectory,
    );
  }

  Future<bool> copyDefaultAssistant() async {
    final byteData = await rootBundle.load('assets/cards/Cass_Assistant.png');

    final bytesToUse = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    return _ioCharacter.ensureDefaultAssistantExists(
      bytesToUse,
      'Cass_Assistant.png',
    );
  }
}
