import 'dart:convert';

import 'package:cardwave/character/src/models/card_list_item.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/models/library_card_filter.dart';
import 'package:cardwave/common/common.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

part 'library_database.g.dart';

/// One light row per card — everything the grid renders, sorts, and filters
/// on, but never the heavy card body. Keyed by the stable [imagePath]. The
/// `*Lower` columns hold Dart-lower-cased copies (SQLite's own `lower()` only
/// folds ASCII), [mtime]/[size] back the change-detection scan, and the
/// derived [folder]/[tagsJson] let the grid filter and group entirely in SQL.
@DataClassName('LibraryCardRow')
@TableIndex(name: 'idx_library_cards_root', columns: {#rootId})
@TableIndex(name: 'idx_library_cards_folder', columns: {#folder})
@TableIndex(name: 'idx_library_cards_creator', columns: {#creatorLower})
class LibraryCards extends Table {
  TextColumn get imagePath => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get nameLower => text().withDefault(const Constant(''))();
  TextColumn get creator => text().withDefault(const Constant(''))();
  TextColumn get creatorLower => text().withDefault(const Constant(''))();
  TextColumn get folder => text().withDefault(const Constant('.'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get previewDescription =>
      text().withDefault(const Constant(''))();
  TextColumn get rootId => text().withDefault(const Constant(''))();
  TextColumn get parentId => text().withDefault(const Constant(''))();
  TextColumn get appCardId => text().withDefault(const Constant(''))();
  TextColumn get variantNotes => text().withDefault(const Constant(''))();
  // App-level tags (CharacterFile.appCardTags), separate from the card's own
  // tags. JSON array; backs the batch auto-tag "missing tags" work-list.
  TextColumn get appCardTagsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchive => boolean().withDefault(const Constant(false))();
  IntColumn get pngTimestampImported =>
      integer().withDefault(const Constant(0))();
  IntColumn get pngTimestampLastSaved =>
      integer().withDefault(const Constant(0))();
  IntColumn get timestampLastSaved => integer().nullable()();
  IntColumn get timestampLastChatted => integer().nullable()();
  IntColumn get timestampLastChattedDismissed => integer().nullable()();
  IntColumn get tokenCountAll => integer().withDefault(const Constant(0))();
  IntColumn get mtime => integer().withDefault(const Constant(0))();
  IntColumn get size => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {imagePath};
}

/// Raw light-row fields for one card, straight from the database. The service
/// maps these to a [CardListItem] (decoding [tagsJson] and attaching the
/// variant count).
typedef LibraryCardData = ({
  String imagePath,
  String name,
  String creator,
  String tagsJson,
  String previewDescription,
  String rootId,
  bool isFavorite,
  String variantNotes,
  int pngTimestampImported,
  int pngTimestampLastSaved,
  int? timestampLastChatted,
  int? timestampLastChattedDismissed,
});

/// One scanned card's identity for change detection.
typedef LibraryCardStat = ({String imagePath, int mtime, int size});

/// The card-library index: one light row per card, queried in pages so the
/// grid never holds the whole library in memory. Lives beside the search
/// database in the current library's disposable cache folder; a folder switch
/// reopens it against the new location.
@DriftDatabase(tables: [LibraryCards])
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase(super.executor);

  static Future<LibraryDatabase> open({
    required String nativePath,
    required String webName,
  }) async {
    final executor = await openDriftConnection(
      nativePath: nativePath,
      webName: webName,
    );
    return LibraryDatabase(executor);
  }

  @override
  int get schemaVersion => 1;

  /// Inserts or updates the light row for [file]. [mtime]/[size] are the
  /// source PNG's stats, stored so the next scan can skip unchanged cards.
  Future<void> upsertCard(
    CharacterFile file, {
    required int mtime,
    required int size,
  }) async {
    final name = file.card.name;
    final creator = file.card.creator;
    await into(libraryCards).insertOnConflictUpdate(
      LibraryCardsCompanion.insert(
        imagePath: file.appCardImagePath,
        name: Value(name),
        nameLower: Value(name.toLowerCase()),
        creator: Value(creator),
        creatorLower: Value(creator.toLowerCase()),
        folder: Value(p.posix.dirname(file.appCardImagePath)),
        tagsJson: Value(jsonEncode(file.card.tags)),
        previewDescription: Value(
          file.card.cardwaveData.previewDescription ?? '',
        ),
        rootId: Value(file.appCardRootId),
        parentId: Value(file.appCardParentId),
        appCardId: Value(file.appCardId),
        variantNotes: Value(file.appCardVariantNotes),
        appCardTagsJson: Value(jsonEncode(file.appCardTags.toList())),
        isFavorite: Value(file.card.cardwaveData.isFavorite),
        isArchive: Value(file.appCardIsArchive),
        pngTimestampImported: Value(file.pngTimestampImported),
        pngTimestampLastSaved: Value(file.pngTimestampLastSaved),
        timestampLastSaved: Value(file.appCardTimestampLastSaved),
        timestampLastChatted: Value(file.appCardTimestampLastChatted),
        timestampLastChattedDismissed: Value(
          file.appCardTimestampLastChattedDismissed,
        ),
        tokenCountAll: Value(file.appCardTokenCountAll),
        mtime: Value(mtime),
        size: Value(size),
      ),
    );
  }

  Future<void> deleteByPath(String imagePath) =>
      (delete(libraryCards)..where((c) => c.imagePath.equals(imagePath))).go();

  /// Every stored card's identity, read once per scan to find what was added,
  /// changed (mtime/size differ), or removed since last launch.
  Future<List<LibraryCardStat>> allStats() async {
    final rows = await customSelect(
      'SELECT image_path, mtime, size FROM library_cards',
      readsFrom: {libraryCards},
    ).get();
    return rows
        .map(
          (r) => (
            imagePath: r.read<String>('image_path'),
            mtime: r.read<int>('mtime'),
            size: r.read<int>('size'),
          ),
        )
        .toList();
  }

  /// Number of variant groups (distinct root ids) that pass [filter] — the
  /// grid's tile count.
  Future<int> countGroups(LibraryCardFilter filter) async {
    final (where, vars) = _whereFor(filter);
    final rows = await customSelect(
      'SELECT COUNT(DISTINCT root_id) AS c FROM library_cards WHERE $where',
      variables: vars,
      readsFrom: {libraryCards},
    ).get();
    return rows.first.read<int>('c');
  }

  /// Number of cards (not groups) passing [filter] — the count pill's
  /// numerator/denominator.
  Future<int> countCards(LibraryCardFilter filter) async {
    final (where, vars) = _whereFor(filter);
    final rows = await customSelect(
      'SELECT COUNT(*) AS c FROM library_cards WHERE $where',
      variables: vars,
      readsFrom: {libraryCards},
    ).get();
    return rows.first.read<int>('c');
  }

  /// Image paths of cards with no preview description — batch-generate
  /// work-list.
  Future<List<String>> pathsMissingPreview() async {
    final rows = await customSelect(
      "SELECT image_path FROM library_cards WHERE preview_description = ''",
      readsFrom: {libraryCards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  /// Image paths of cards with no app-level tags — batch auto-tag work-list.
  Future<List<String>> pathsMissingAppTags() async {
    final rows = await customSelect(
      "SELECT image_path FROM library_cards "
      "WHERE app_card_tags_json = '[]' OR app_card_tags_json = ''",
      readsFrom: {libraryCards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  /// Every card's image path — the candidate pool a search query ranks over.
  Future<List<String>> allCardPaths() async {
    final rows = await customSelect(
      'SELECT image_path FROM library_cards',
      readsFrom: {libraryCards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  // The two window columns that describe a card's variant group: the group's
  // size, and this card's rank by import order (rank 1 = the oldest card, the
  // "original"). Shared by every query that badges a card or picks a group's
  // display card, so the "which card is the original" rule has one definition.
  static const String _variantWindowColumns =
      'COUNT(*) OVER (PARTITION BY root_id) AS grp_count, '
      'ROW_NUMBER() OVER (PARTITION BY root_id '
      'ORDER BY png_timestamp_imported ASC, image_path ASC) AS repr_rank';

  /// One page of variant groups passing [filter], ordered by [sortColumn].
  /// Each result is the group's display card (its oldest variant) plus how
  /// many cards the group holds. A window query partitions by root id: the
  /// group's sort position comes from its newest/oldest card (per
  /// [descending]); the display card is always the oldest variant.
  Future<List<({LibraryCardData card, int variantCount})>> pageGroups({
    required LibraryCardFilter filter,
    required LibrarySortColumn sortColumn,
    required bool descending,
    required int offset,
    required int limit,
  }) async {
    final (where, whereVars) = _whereFor(filter);
    final agg = descending ? 'MAX' : 'MIN';
    final dir = descending ? 'DESC' : 'ASC';
    final rows = await customSelect(
      'SELECT * FROM ('
      'SELECT *, $_variantWindowColumns, '
      '$agg(${sortColumn.column}) OVER (PARTITION BY root_id) AS grp_sort '
      'FROM library_cards WHERE $where'
      ') WHERE repr_rank = 1 '
      'ORDER BY grp_sort $dir, name_lower ASC, root_id ASC '
      'LIMIT ? OFFSET ?',
      variables: [...whereVars, Variable<int>(limit), Variable<int>(offset)],
      readsFrom: {libraryCards},
    ).get();
    return rows
        .map((r) => (card: _dataOf(r), variantCount: r.read<int>('grp_count')))
        .toList();
  }

  /// One page of individual cards passing [filter] — every variant is its own
  /// row, not collapsed to its group — ordered by last activity (most recently
  /// chatted or saved first). Each row carries its group's size and whether it
  /// is the group's oldest card, so the caller can show the ORIGINAL / VARIANT
  /// badge. Backs the character switcher, which lists variants individually.
  ///
  /// The group size and oldest-card rank are computed over the whole library
  /// (the windows run before the filter), so a card keeps its true badge even
  /// when a filter — favourites, recent — hides its siblings; the filter,
  /// ordering, and paging then apply to the result.
  Future<List<({LibraryCardData card, int variantCount, bool isOriginal})>>
  pageCardsByActivity({
    required LibraryCardFilter filter,
    required int offset,
    required int limit,
  }) async {
    final (where, whereVars) = _whereFor(filter);
    final rows = await customSelect(
      'SELECT * FROM ('
      'SELECT *, $_variantWindowColumns, '
      'MAX(COALESCE(timestamp_last_chatted, 0), '
      'COALESCE(timestamp_last_saved, 0)) AS last_activity '
      'FROM library_cards'
      ') WHERE $where '
      'ORDER BY last_activity DESC, name_lower ASC, image_path ASC '
      'LIMIT ? OFFSET ?',
      variables: [...whereVars, Variable<int>(limit), Variable<int>(offset)],
      readsFrom: {libraryCards},
    ).get();
    return rows
        .map(
          (r) => (
            card: _dataOf(r),
            variantCount: r.read<int>('grp_count'),
            isOriginal: r.read<int>('repr_rank') == 1,
          ),
        )
        .toList();
  }

  /// Group size and oldest-card flag for each path in [paths], computed over the
  /// whole library so a matched variant is badged correctly even when its
  /// original is not in [paths]. Backs the switcher's search results.
  Future<Map<String, ({int variantCount, bool isOriginal})>> variantInfoForPaths(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return const {};
    final placeholders = List.filled(paths.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT image_path, grp_count, repr_rank FROM ('
      'SELECT image_path, $_variantWindowColumns '
      'FROM library_cards'
      ') WHERE image_path IN ($placeholders)',
      variables: paths.map(Variable<String>.new).toList(),
      readsFrom: {libraryCards},
    ).get();
    return {
      for (final r in rows)
        r.read<String>('image_path'): (
          variantCount: r.read<int>('grp_count'),
          isOriginal: r.read<int>('repr_rank') == 1,
        ),
    };
  }

  /// Light rows for [paths] that also pass [filter], in arbitrary order. Used
  /// by the relevance path: the search service hands back a bounded ranked
  /// list of paths, which the controller reorders by score and groups in Dart.
  Future<List<LibraryCardData>> cardsByPaths(
    List<String> paths,
    LibraryCardFilter filter,
  ) async {
    if (paths.isEmpty) return const [];
    final (where, whereVars) = _whereFor(filter);
    final placeholders = List.filled(paths.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT * FROM library_cards '
      'WHERE image_path IN ($placeholders) AND $where',
      variables: [...paths.map(Variable<String>.new), ...whereVars],
      readsFrom: {libraryCards},
    ).get();
    return rows.map(_dataOf).toList();
  }

  /// Every card in one variant group, oldest first — backs the variants sheet.
  Future<List<LibraryCardData>> cardsByRootId(String rootId) async {
    final rows = await customSelect(
      'SELECT * FROM library_cards WHERE root_id = ? '
      'ORDER BY png_timestamp_imported ASC, image_path ASC',
      variables: [Variable<String>(rootId)],
      readsFrom: {libraryCards},
    ).get();
    return rows.map(_dataOf).toList();
  }

  /// Per-creator card counts over the pool that passes every filter except
  /// the creator one. Keyed by the lower-cased creator; the empty creator is
  /// reported under `unknown`.
  Future<Map<String, int>> creatorCounts(LibraryCardFilter filter) async {
    final (where, vars) = _whereFor(filter.without(creators: true));
    final rows = await customSelect(
      'SELECT creator_lower AS k, COUNT(*) AS c FROM library_cards '
      'WHERE $where GROUP BY creator_lower',
      variables: vars,
      readsFrom: {libraryCards},
    ).get();
    return {
      for (final r in rows)
        (r.read<String>('k').isEmpty ? 'unknown' : r.read<String>('k')):
            r.read<int>('c'),
    };
  }

  /// Per-tag card counts over the pool that passes the current creator/folder
  /// filters plus whatever tags are already chosen (so counts narrow as the
  /// selection grows). [filter] should carry the in-dialog tag selection.
  Future<Map<String, int>> tagCounts(LibraryCardFilter filter) async {
    final (where, vars) = _whereFor(filter);
    final rows = await customSelect(
      'SELECT je.value AS tag, COUNT(*) AS c '
      'FROM library_cards AS lc, json_each(lc.tags_json) AS je '
      'WHERE $where GROUP BY je.value',
      variables: vars,
      readsFrom: {libraryCards},
    ).get();
    return {for (final r in rows) r.read<String>('tag'): r.read<int>('c')};
  }

  /// Per-folder leaf card counts over the pool that passes every filter except
  /// the folder one. The controller rolls these up into the folder tree.
  Future<Map<String, int>> folderLeafCounts(LibraryCardFilter filter) async {
    final (where, vars) = _whereFor(filter.without(folder: true));
    final rows = await customSelect(
      'SELECT folder AS f, COUNT(*) AS c FROM library_cards '
      'WHERE $where GROUP BY folder',
      variables: vars,
      readsFrom: {libraryCards},
    ).get();
    return {for (final r in rows) r.read<String>('f'): r.read<int>('c')};
  }

  /// Image paths of the cards whose app id is in [ids] (group members).
  Future<List<String>> pathsByAppCardIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT image_path FROM library_cards WHERE app_card_id IN ($placeholders)',
      variables: ids.map(Variable<String>.new).toList(),
      readsFrom: {libraryCards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  /// Image path of the first card whose name equals [name], or null. Backs
  /// name-keyed lookups (default assistant, test helpers).
  Future<String?> pathByName(String name) async {
    final rows = await customSelect(
      'SELECT image_path FROM library_cards WHERE name = ? LIMIT 1',
      variables: [Variable<String>(name)],
      readsFrom: {libraryCards},
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('image_path');
  }

  /// Every distinct folder in the library — seeds the folder tree so folders
  /// with no current matches still appear.
  Future<List<String>> distinctFolders() async {
    final rows = await customSelect(
      'SELECT DISTINCT folder AS f FROM library_cards',
      readsFrom: {libraryCards},
    ).get();
    return rows.map((r) => r.read<String>('f')).toList();
  }

  LibraryCardData _dataOf(QueryRow r) => (
    imagePath: r.read<String>('image_path'),
    name: r.read<String>('name'),
    creator: r.read<String>('creator'),
    tagsJson: r.read<String>('tags_json'),
    previewDescription: r.read<String>('preview_description'),
    rootId: r.read<String>('root_id'),
    isFavorite: r.read<int>('is_favorite') != 0,
    variantNotes: r.read<String>('variant_notes'),
    pngTimestampImported: r.read<int>('png_timestamp_imported'),
    pngTimestampLastSaved: r.read<int>('png_timestamp_last_saved'),
    timestampLastChatted: r.read<int?>('timestamp_last_chatted'),
    timestampLastChattedDismissed: r.read<int?>(
      'timestamp_last_chatted_dismissed',
    ),
  );

  /// Builds the shared `WHERE` clause + its positional variables for [filter].
  /// `recentOnly` overrides the other tag/creator/folder filters (matching the
  /// old prioritize-recent short-circuit); `restrictToPaths` still applies on
  /// top, so an active search composes with every filter. Folder uses a prefix
  /// compare via `substr` rather than `LIKE`, so folder names containing
  /// `%`/`_` match correctly.
  (String, List<Variable>) _whereFor(LibraryCardFilter f) {
    final clauses = <String>[];
    final vars = <Variable>[];

    if (f.recentOnly) {
      final threshold =
          DateTime.now().millisecondsSinceEpoch -
          CardListItem.recentWindow.inMilliseconds;
      clauses.add(
        'timestamp_last_chatted IS NOT NULL AND timestamp_last_chatted > 0 '
        'AND COALESCE(timestamp_last_chatted_dismissed, 0) < timestamp_last_chatted '
        'AND timestamp_last_chatted > ?',
      );
      vars.add(Variable<int>(threshold));
    } else {
      if (f.favoritesOnly) clauses.add('is_favorite = 1');
      if (f.variantsOnly) {
        clauses.add(
          'root_id IN (SELECT root_id FROM library_cards '
          'GROUP BY root_id HAVING COUNT(*) >= 2)',
        );
      }
      for (final tag in f.tags) {
        clauses.add(
          'EXISTS (SELECT 1 FROM json_each(tags_json) WHERE value = ?)',
        );
        vars.add(Variable<String>(tag));
      }
      if (f.creators.isNotEmpty) {
        final keys = [for (final c in f.creators) c == 'unknown' ? '' : c];
        clauses.add(
          'creator_lower IN (${List.filled(keys.length, '?').join(', ')})',
        );
        vars.addAll(keys.map(Variable<String>.new));
      }
      final folder = f.folder;
      if (folder != null) {
        final prefix = '$folder/';
        clauses.add('(folder = ? OR substr(folder, 1, ?) = ?)');
        vars
          ..add(Variable<String>(folder))
          ..add(Variable<int>(prefix.length))
          ..add(Variable<String>(prefix));
      }
    }

    final restrict = f.restrictToPaths;
    if (restrict != null) {
      if (restrict.isEmpty) {
        clauses.add('0 = 1');
      } else {
        clauses.add(
          'image_path IN (${List.filled(restrict.length, '?').join(', ')})',
        );
        vars.addAll(restrict.map(Variable<String>.new));
      }
    }

    return (clauses.isEmpty ? '1 = 1' : clauses.join(' AND '), vars);
  }
}
