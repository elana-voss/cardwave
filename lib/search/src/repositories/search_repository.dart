import 'dart:typed_data';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/src/db/search_database.dart';
import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave_storage/cardwave_storage.dart';

/// Per-card field vectors, grouped for cosine scoring.
typedef FieldVectors = Map<CardSearchFieldEnum, List<Float32List>>;

/// Owns the on-device [SearchDatabase] and maps between the database's
/// primitive rows and the search domain's types (field enum, float vectors,
/// FTS match expressions).
///
/// The database file lives inside the current card library's disposable
/// cache folder. [ensureOpen] re-resolves that location on every call, so
/// switching libraries (onboarding / settings) closes the old database and
/// opens the one beside the new library — the index always travels with its
/// cards and never orphans.
class SearchRepository {
  SearchRepository({required AppStorage appStorage}) {
    _db = CacheDatabaseHandle(
      appStorage: appStorage,
      relativePath: '${AppConstants.customCacheRootPath}/search/cards.sqlite',
      webName: 'cardwave_search',
      opener: SearchDatabase.open,
      // The cached ids belong to the previous database; drop them on a switch.
      onOpened: _idByPath.clear,
    );
  }

  // The search index database beside the current card library, opened on first
  // use and reopened when the library folder changes.
  late final CacheDatabaseHandle<SearchDatabase> _db;

  // image path -> card registry id, so repeated writes for one card skip the
  // upsert+select round-trip.
  final Map<String, int> _idByPath = {};

  // bm25 per-column boosts in CardSearchFieldEnum order (weight / 10), the
  // single source for both the keyword channel's field weighting and this SQL.
  static final List<double> _bm25ColumnWeights = [
    for (final f in CardSearchFieldEnum.values) f.weight / 10,
  ];

  static final Map<String, CardSearchFieldEnum> _fieldByName = {
    for (final f in CardSearchFieldEnum.values) f.name: f,
  };

  Future<SearchDatabase> ensureOpen() => _db.ensureOpen();

  Future<void> close() async {
    await _db.close();
    _idByPath.clear();
  }

  /// Persists one field's vectors + change hash for a card.
  Future<void> writeField(
    String imagePath,
    String name,
    CardSearchFieldEnum field,
    List<Float32List> vectors,
    String hash,
  ) async {
    final db = await ensureOpen();
    final cardId = await _cardId(db, imagePath, name);
    final blobs = [for (final v in vectors) _blobOf(v)];
    await db.replaceFieldVectors(cardId, field.name, blobs);
    await db.upsertHash(cardId, field.name, hash);
  }

  /// Rewrites a card's keyword (FTS) row from its current field texts. The
  /// registry name is kept current by [writeField] — a name change always
  /// re-indexes the name field — so this only needs the card's id.
  Future<void> writeFts(
    String imagePath,
    String name,
    Map<CardSearchFieldEnum, String> texts,
  ) async {
    final db = await ensureOpen();
    final cardId = await _cardId(db, imagePath, name);
    await db.writeFtsRow(
      cardId,
      name: texts[CardSearchFieldEnum.name] ?? '',
      tags: texts[CardSearchFieldEnum.tags] ?? '',
      personality: texts[CardSearchFieldEnum.personality] ?? '',
      description: texts[CardSearchFieldEnum.description] ?? '',
      scenario: texts[CardSearchFieldEnum.scenario] ?? '',
    );
  }

  Future<void> removeCard(String imagePath) async {
    final db = await ensureOpen();
    await db.deleteCardByPath(imagePath);
    _idByPath.remove(imagePath);
  }

  /// Per-card field hashes read once at startup to seed the in-memory
  /// change-detection cache. Hashes stored under a field name no longer in
  /// the enum are dropped.
  Future<Map<String, Map<CardSearchFieldEnum, String>>> loadHashes() async {
    final db = await ensureOpen();
    final rows = await db.allHashes();
    final result = <String, Map<CardSearchFieldEnum, String>>{};
    for (final row in rows) {
      final field = _fieldByName[row.field];
      if (field == null) continue;
      (result[row.imagePath] ??= {})[field] = row.hash;
    }
    return result;
  }

  /// Keyword ranking for [tokens]: image paths best-match-first. Empty when
  /// there are no tokens.
  Future<List<String>> rankLexicalPaths(List<String> tokens) async {
    if (tokens.isEmpty) return const [];
    final db = await ensureOpen();
    final matchExpr = tokens
        .map((t) => '"${t.replaceAll('"', '""')}"')
        .join(' OR ');
    return db.rankLexicalPaths(matchExpr, _bm25ColumnWeights);
  }

  Future<List<String>> exactNamePaths(String lowerName) async {
    final db = await ensureOpen();
    return db.exactNamePaths(lowerName);
  }

  /// Field vectors for [paths], grouped per card. Callers batch [paths] to
  /// keep each read's memory bounded.
  Future<Map<String, FieldVectors>> vectorsForPaths(
    Iterable<String> paths,
  ) async {
    final list = paths.toList();
    if (list.isEmpty) return const {};
    final db = await ensureOpen();
    final rows = await db.vectorsForPaths(list);
    final result = <String, FieldVectors>{};
    for (final row in rows) {
      final field = _fieldByName[row.field];
      if (field == null) continue;
      ((result[row.imagePath] ??= {})[field] ??= []).add(_vectorsOf(row.blob));
    }
    return result;
  }

  /// Whether the approximate-nearest add-on is active for the current database
  /// (Windows with the sqlite-vec binary loaded). Drives the search fast path;
  /// false everywhere else, where search uses the exact brute-force scan.
  Future<bool> vecAvailable() async => (await ensureOpen()).vecReady;

  /// Approximate-nearest image paths for [query], over-fetching the
  /// [nearestChunks] closest chunk vectors and mapping them to their cards
  /// (deduplicated). Only meaningful when [vecAvailable]; callers gate on it.
  Future<Set<String>> annNearestPaths(
    Float32List query,
    int nearestChunks,
  ) async {
    final db = await ensureOpen();
    final paths = await db.annNearestPaths(_blobOf(query), nearestChunks);
    return paths.toSet();
  }

  Future<int> _cardId(SearchDatabase db, String imagePath, String name) async {
    final cached = _idByPath[imagePath];
    if (cached != null) return cached;
    final id = await db.upsertCard(imagePath, name);
    _idByPath[imagePath] = id;
    return id;
  }

  Uint8List _blobOf(Float32List v) =>
      v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);

  Float32List _vectorsOf(Uint8List blob) => Float32List.view(
    blob.buffer,
    blob.offsetInBytes,
    blob.lengthInBytes ~/ Float32List.bytesPerElement,
  );
}
