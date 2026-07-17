import 'package:cardwave/common/common.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart' show embeddingsDim;
import 'package:drift/drift.dart';

part 'search_database.g.dart';

final _log = LoggingService();

/// One light registry row per card. Maps the stable [imagePath] search key
/// to an integer id used as the `cards_fts` rowid. [name] backs the
/// exact-name match boost. Heavy text bodies are not stored here — the
/// searchable text lives in `cards_fts`, the vectors in [CardVectors].
@DataClassName('CardRow')
@TableIndex(name: 'idx_cards_name_lower', columns: {#nameLower})
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get imagePath => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  // Dart-lowercased copy of [name] for the exact-name match. SQLite's own
  // lower() only folds ASCII, so comparing against a Dart toLowerCase value
  // is the only way to match accented / non-Latin names correctly.
  TextColumn get nameLower => text().withDefault(const Constant(''))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {imagePath},
  ];
}

/// One row per embedded chunk: the owning card, which field it came from,
/// the chunk's order within that field, and the float32 embedding as a
/// little-endian blob. Replaces the old per-card `*.embedding.bin` sidecars
/// and the in-memory vector map.
@DataClassName('CardVectorRow')
@TableIndex(name: 'idx_card_vectors_card', columns: {#cardId})
class CardVectors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  TextColumn get field => text()();
  IntColumn get chunkIndex => integer()();
  BlobColumn get embedding => blob()();
}

/// Per-field source-text hash for change detection — the same FNV hash the
/// indexer computed before, now persisted so re-launches skip unchanged
/// fields instead of re-embedding the whole library.
@DataClassName('CardFieldHashRow')
class CardFieldHashes extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  TextColumn get field => text()();
  TextColumn get hash => text()();

  @override
  Set<Column<Object>> get primaryKey => {cardId, field};
}

/// The on-device search store: card registry, embedding vectors, change
/// hashes, plus an FTS5 keyword index (`cards_fts`) created in the
/// migration. One file per card library, inside its disposable cache
/// folder. Native opens it directly; web hosts it in a worker.
@DriftDatabase(tables: [Cards, CardVectors, CardFieldHashes])
class SearchDatabase extends _$SearchDatabase {
  SearchDatabase(super.executor);

  // Whether the sqlite-vec add-on is usable on this database (Windows with
  // vec0.dll loaded). Set once during the open migration, since registration
  // happens on the helper isolate and can't report back directly. Read
  // synchronously by writes and exposed to the repository so the search
  // service can route a large meaning query through the approximate fast path.
  bool _vecReady = false;
  bool get vecReady => _vecReady;

  /// Opens (or creates) the database for the given location. [nativePath]
  /// is the absolute file path on native; [webName] the logical database
  /// name on web.
  static Future<SearchDatabase> open({
    required String nativePath,
    required String webName,
  }) async {
    final executor = await openDriftConnection(
      nativePath: nativePath,
      webName: webName,
    );
    return SearchDatabase(executor);
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Standalone FTS5 index. Column order matches CardSearchFieldEnum so
      // the per-column bm25 weights line up. remove_diacritics folds
      // accented text (e.g. Vietnamese) to its base letters for matching.
      await customStatement(
        'CREATE VIRTUAL TABLE cards_fts USING fts5('
        'name, tags, personality, description, scenario, '
        "tokenize = 'unicode61 remove_diacritics 2')",
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // The sqlite-vec add-on is registered per-connection on the database
      // helper isolate (see connection_native.dart), only on Windows with the
      // binary present. When its functions are there, keep a vector index
      // mirroring card_vectors for the approximate-search fast path; otherwise
      // search stays on the exact brute-force scan everywhere.
      if (await _vecFunctionsPresent()) {
        await _createVecTableIfMissing();
        _vecReady = true;
      }
    },
  );

  // True when the sqlite-vec functions are registered on this connection (the
  // add-on loaded). The bundled SQLite omits the introspection pragmas that
  // would let us list functions, so the only portable check is to call one of
  // the add-on's functions: vec_version() exists only when sqlite-vec
  // registered (Windows with the binary). Any failure — the function is absent,
  // or any read error — means the fast path is off and search uses the exact
  // scan; drift surfaces all of them as an Exception.
  Future<bool> _vecFunctionsPresent() async {
    try {
      final rows = await customSelect('SELECT vec_version() AS v').get();
      final version = rows.first.read<String>('v');
      _log.info('[SEARCH-VEC] sqlite-vec loaded: $version');
      return true;
    } on Exception {
      _log.info('[SEARCH-VEC] sqlite-vec not available (vec0.dll absent or failed to load)');
      return false;
    }
  }

  // Creates the vector index on first sight and backfills it from the vectors
  // already stored as blobs — no re-embedding. A no-op on later opens once the
  // table exists and is populated.
  Future<void> _createVecTableIfMissing() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS vec_cards '
      'USING vec0(embedding float[$embeddingsDim])',
    );
    final countRows = await customSelect(
      'SELECT count(*) AS c FROM vec_cards',
    ).get();
    // COUNT without GROUP BY yields exactly one row — 0 on an empty table.
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (countRows.first.read<int>('c') == 0) {
      await customStatement(
        'INSERT INTO vec_cards(rowid, embedding) '
        'SELECT id, embedding FROM card_vectors',
      );
    }
  }

  /// Inserts or updates the registry row for [imagePath], returning its id.
  Future<int> upsertCard(String imagePath, String name) async {
    final lower = name.toLowerCase();
    await into(cards).insert(
      CardsCompanion.insert(
        imagePath: imagePath,
        name: Value(name),
        nameLower: Value(lower),
      ),
      onConflict: DoUpdate(
        (_) => CardsCompanion(name: Value(name), nameLower: Value(lower)),
        target: [cards.imagePath],
      ),
    );
    final row = await (select(cards)
          ..where((c) => c.imagePath.equals(imagePath)))
        .getSingle();
    return row.id;
  }

  /// Replaces every stored chunk for one (card, field) with [blobs].
  Future<void> replaceFieldVectors(
    int cardId,
    String field,
    List<Uint8List> blobs,
  ) async {
    await transaction(() async {
      // vec_cards keys only by rowid, so its rows to drop are the card_vectors
      // ids about to be deleted — read those ids before deleting them.
      if (_vecReady) {
        final staleIds = await (selectOnly(cardVectors)
              ..addColumns([cardVectors.id])
              ..where(
                cardVectors.cardId.equals(cardId) &
                    cardVectors.field.equals(field),
              ))
            .map((r) => r.read(cardVectors.id)!)
            .get();
        for (final id in staleIds) {
          await customStatement('DELETE FROM vec_cards WHERE rowid = ?', [id]);
        }
      }
      await (delete(cardVectors)
            ..where((v) => v.cardId.equals(cardId) & v.field.equals(field)))
          .go();
      for (var i = 0; i < blobs.length; i++) {
        // The insert runs whether or not the add-on is ready; only the mirror
        // row below is conditional, so this cannot move inside the guard.
        final rowId = await into(cardVectors).insert(
          CardVectorsCompanion.insert(
            cardId: cardId,
            field: field,
            chunkIndex: i,
            embedding: blobs[i],
          ),
        );
        if (_vecReady) {
          await customStatement(
            'INSERT INTO vec_cards(rowid, embedding) VALUES (?, ?)',
            [rowId, blobs[i]],
          );
        }
      }
    });
  }

  Future<void> upsertHash(int cardId, String field, String hash) =>
      into(cardFieldHashes).insert(
        CardFieldHashesCompanion.insert(
          cardId: cardId,
          field: field,
          hash: hash,
        ),
        onConflict: DoUpdate(
          (_) => CardFieldHashesCompanion(hash: Value(hash)),
          target: [cardFieldHashes.cardId, cardFieldHashes.field],
        ),
      );

  /// Rewrites the card's single FTS row (all five fields at once). FTS5
  /// has no per-column update, so the row is deleted by rowid and reinserted.
  Future<void> writeFtsRow(
    int cardId, {
    required String name,
    required String tags,
    required String personality,
    required String description,
    required String scenario,
  }) async {
    await transaction(() async {
      await customStatement('DELETE FROM cards_fts WHERE rowid = ?', [cardId]);
      await customStatement(
        'INSERT INTO cards_fts(rowid, name, tags, personality, description, '
        'scenario) VALUES (?, ?, ?, ?, ?, ?)',
        [cardId, name, tags, personality, description, scenario],
      );
    });
  }

  /// Removes a card and everything keyed to it. The relational children
  /// (vectors, hashes) cascade through the foreign key; the FTS row is
  /// dropped by rowid.
  Future<void> deleteCardByPath(String imagePath) async {
    final row = await (select(cards)
          ..where((c) => c.imagePath.equals(imagePath)))
        .getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await customStatement('DELETE FROM cards_fts WHERE rowid = ?', [row.id]);
      await (delete(cards)..where((c) => c.id.equals(row.id))).go();
    });
  }

  /// Every stored hash with its card's image path — read once at startup to
  /// rebuild the in-memory change-detection cache.
  Future<List<({String imagePath, String field, String hash})>>
  allHashes() async {
    final query = select(cardFieldHashes).join([
      innerJoin(cards, cards.id.equalsExp(cardFieldHashes.cardId)),
    ]);
    final rows = await query.get();
    return rows.map((r) {
      final h = r.readTable(cardFieldHashes);
      final c = r.readTable(cards);
      return (imagePath: c.imagePath, field: h.field, hash: h.hash);
    }).toList();
  }

  /// FTS5 keyword ranking. [matchExpr] is a pre-sanitised MATCH expression;
  /// [columnWeights] are the per-column bm25 boosts in CardSearchFieldEnum
  /// order. Returns image paths best-match-first (bm25 is most negative for
  /// the best match, so ascending order is best-first).
  Future<List<String>> rankLexicalPaths(
    String matchExpr,
    List<double> columnWeights,
  ) async {
    final weights = columnWeights.join(', ');
    final rows = await customSelect(
      'SELECT c.image_path AS image_path '
      'FROM cards_fts JOIN cards c ON c.id = cards_fts.rowid '
      'WHERE cards_fts MATCH ? '
      'ORDER BY bm25(cards_fts, $weights) ASC',
      variables: [Variable<String>(matchExpr)],
      readsFrom: {cards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  /// Image paths whose card name equals [lowerName] (already lower-cased).
  Future<List<String>> exactNamePaths(String lowerName) async {
    final rows = await customSelect(
      'SELECT image_path FROM cards WHERE name_lower = ?',
      variables: [Variable<String>(lowerName)],
      readsFrom: {cards},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }

  /// Every chunk vector for the given image paths, tagged with its card and
  /// field. The caller groups these into per-card field vectors for cosine
  /// scoring; batching the paths keeps each read's memory bounded.
  Future<List<({String imagePath, String field, Uint8List blob})>>
  vectorsForPaths(List<String> paths) async {
    if (paths.isEmpty) return const [];
    final query = select(cardVectors).join([
      innerJoin(cards, cards.id.equalsExp(cardVectors.cardId)),
    ])..where(cards.imagePath.isIn(paths));
    final rows = await query.get();
    return rows.map((r) {
      final v = r.readTable(cardVectors);
      final c = r.readTable(cards);
      return (imagePath: c.imagePath, field: v.field, blob: v.embedding);
    }).toList();
  }

  /// Approximate-nearest image paths for [queryBlob] (a float32 query vector
  /// as a little-endian blob): over-fetches the [nearestChunks] closest chunk
  /// vectors from the sqlite-vec index and maps them back to their cards,
  /// closest first. A card may repeat (one row per matched chunk). Valid only
  /// when [vecReady] — the search service gates the fast path on that.
  Future<List<String>> annNearestPaths(
    Uint8List queryBlob,
    int nearestChunks,
  ) async {
    final rows = await customSelect(
      'WITH knn AS ('
      '  SELECT rowid, distance FROM vec_cards '
      '  WHERE embedding MATCH ? AND k = ?'
      ') '
      'SELECT c.image_path AS image_path FROM knn '
      'JOIN card_vectors v ON v.id = knn.rowid '
      'JOIN cards c ON c.id = v.card_id '
      'ORDER BY knn.distance',
      variables: [Variable<Uint8List>(queryBlob), Variable<int>(nearestChunks)],
      readsFrom: {cards, cardVectors},
    ).get();
    return rows.map((r) => r.read<String>('image_path')).toList();
  }
}
