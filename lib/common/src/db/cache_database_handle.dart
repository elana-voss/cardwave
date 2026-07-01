import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:drift/drift.dart';

/// Opens (and reopens on a library switch) a drift database that lives inside
/// the current card library's disposable cache folder. The native path is
/// re-resolved on every [ensureOpen] from the `cards` storage domain, so when
/// the library folder changes the old database is closed and the one beside the
/// new library is opened — the index always travels with its cards and never
/// orphans.
///
/// Concurrent first-load callers share one in-flight open instead of each
/// constructing a second database on the same file (which deadlocks with
/// "database is locked"). A failed open is not cached, so the next call retries.
class CacheDatabaseHandle<D extends GeneratedDatabase> {
  CacheDatabaseHandle({
    required this.appStorage,
    required this.relativePath,
    required this.webName,
    required this.opener,
    this.onOpened,
  });

  final AppStorage appStorage;
  final String relativePath;
  final String webName;
  final Future<D> Function({
    required String nativePath,
    required String webName,
  })
  opener;

  /// Runs right after a new database opens — e.g. to clear a per-card id cache
  /// the previous database populated.
  final void Function()? onOpened;

  D? _db;
  Future<D>? _opening;
  String? _openedPath;

  Future<D> ensureOpen() {
    final nativePath = appStorage.absolutePathFor(
      StorageDomainEnum.cards,
      relativePath,
    );
    final pending = _opening;
    if (pending != null && _openedPath == nativePath) return pending;
    // Record the target path synchronously so concurrent callers share this one
    // open instead of each constructing a second database on the same file.
    _openedPath = nativePath;
    return _opening = _open(nativePath);
  }

  Future<D> _open(String? nativePath) async {
    final previous = _db;
    _db = null;
    await previous?.close();
    try {
      final db = await opener(nativePath: nativePath ?? '', webName: webName);
      _db = db;
      onOpened?.call();
      return db;
    } on Exception {
      // A failed open must not stay cached as the in-flight future, or every
      // later query would await the same error and never recover this session.
      _opening = null;
      _openedPath = null;
      rethrow;
    }
  }

  Future<void> close() async {
    await _opening;
    await _db?.close();
    _db = null;
    _opening = null;
    _openedPath = null;
  }
}
