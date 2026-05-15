import 'dart:async';
import 'dart:typed_data';

import 'package:cardwave_storage/src/app_storage.dart';
import 'package:cardwave_storage/src/storage_exception.dart';
import 'package:fs_shim/fs_idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:path/path.dart' as p;

AppStorage getAppStorage() => AppStorageWeb();

/// Web implementation of [AppStorage] that uses IndexedDB as a virtual file system.
///
/// This class leverages `fs_shim` to provide a file system-like API on top of
/// the browser's IndexedDB. Because this is a virtual system, all path
/// operations are inherently POSIX-style, using forward slashes (`/`).
///
/// To ensure robustness, it explicitly sanitizes all incoming relative paths by
/// replacing backslashes (`\`) with forward slashes (`/`), preventing any
/// potential path pollution from code that might accidentally pass a
/// Windows-style path.
class AppStorageWeb extends AppStorage {
  final Map<StorageDomainEnum, FileSystem> _fileSystems = {};

  @override
  Future<void> init(String? Function(StorageDomainEnum) pathResolver) async {
    final idbFactory = getIdbFactory();
    if (idbFactory == null) {
      throw UnsupportedError('IndexedDB is not supported in this browser.');
    }

    for (final domain in StorageDomainEnum.values) {
      _fileSystems[domain] = newFileSystemIdb(
        idbFactory,
        // keep this for backward compability!
        'chacama_${domain.name}',
      );
    }
  }

  /// Sanitizes incoming paths to prevent Windows backslashes from polluting
  /// the virtual POSIX file system.
  String _sanitize(String path) => path.replaceAll(r'\', '/');

  /// Returns a [File] handle within the virtual file system for the given domain.
  ///
  /// All path joining is done using `p.posix` to ensure consistency within the
  /// virtual environment.
  File _getFile(StorageDomainEnum domain, String relativePath) =>
      _fileSystems[domain]!.file(p.posix.join('/', _sanitize(relativePath)));

  /// Wraps every fs_shim call so the caller sees a Dart-`Exception`-compatible
  /// failure instead of fs_shim's `FileSystemException` (which does not
  /// implement `Exception`). Other Exception subclasses propagate unchanged,
  /// and Error subclasses (programmer mistakes — `LateInitializationError`,
  /// `StateError`, `TypeError`) propagate naturally because we only catch
  /// the specific fs_shim type.
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on FileSystemException catch (e, st) {
      throw StorageException(e.message, cause: e, causeStackTrace: st);
    }
  }

  @override
  String? absolutePathFor(StorageDomainEnum domain, String relativePath) =>
      null;

  @override
  Future<void> writeBytes(
    StorageDomainEnum domain,
    String relativePath,
    Uint8List bytes,
  ) => _guard(() async {
    final file = _getFile(domain, relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  });

  @override
  Future<List<int>> readBytes(StorageDomainEnum domain, String relativePath) =>
      _guard(() => _getFile(domain, relativePath).readAsBytes());

  @override
  Future<void> writeString(
    StorageDomainEnum domain,
    String relativePath,
    String content,
  ) => _guard(() async {
    final file = _getFile(domain, relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  });

  @override
  Future<String> readString(StorageDomainEnum domain, String relativePath) =>
      _guard(() => _getFile(domain, relativePath).readAsString());

  @override
  Future<void> deleteFile(StorageDomainEnum domain, String relativePath) =>
      _guard(() async {
        final file = _getFile(domain, relativePath);
        if (await file.exists()) {
          await file.delete();
        }
      });

  @override
  Future<void> deleteDirectory(
    StorageDomainEnum domain,
    String relativeDirectory,
  ) => _guard(() async {
    final dir = _fileSystems[domain]!.directory(
      p.posix.join('/', _sanitize(relativeDirectory)),
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  @override
  Future<void> createDirectory(
    StorageDomainEnum domain,
    String relativeDirectory,
  ) => _guard(
    () => _fileSystems[domain]!
        .directory(p.posix.join('/', _sanitize(relativeDirectory)))
        .create(recursive: true),
  );

  @override
  Future<List<String>> listDirectory(
    StorageDomainEnum domain,
    String relativeDirectory, {
    List<String>? extensions,
    bool recursive = false,
  }) => _guard(() async {
    final dir = _fileSystems[domain]!.directory(
      p.posix.join('/', _sanitize(relativeDirectory)),
    );
    if (!await dir.exists()) return [];

    var entities = dir.list(recursive: recursive);

    // Filter out hidden files and directories (any segment starting with '.')
    // *inside* the listed directory. Computing the relative path from
    // `dir.path` (not `/`) ensures the filter ignores ancestor segments —
    // important because every app-data folder lives under
    // `.cache_<app>_<version>/...`, which would otherwise filter everything.
    entities = entities.where((entity) {
      final relativePath = p.posix.relative(entity.path, from: dir.path);
      if (relativePath == '.') return false;
      return !relativePath.split('/').any((segment) => segment.startsWith('.'));
    });

    if (extensions != null && extensions.isNotEmpty) {
      final lowerCaseExtensions = extensions
          .map((e) => e.toLowerCase())
          .toSet();
      entities = entities.where(
        (e) => lowerCaseExtensions.contains(
          p.posix.extension(e.path).toLowerCase(),
        ),
      );
    }

    final entityList = await entities.toList();

    // The virtual file system's paths are absolute from its root ('/').
    // `p.posix.relative` correctly converts them to paths relative to that root,
    // fulfilling the AppStorage contract.
    return entityList.map((e) => p.posix.relative(e.path, from: '/')).toList();
  });

  @override
  Future<bool> fileExists(StorageDomainEnum domain, String relativePath) =>
      _guard(() => _getFile(domain, relativePath).exists());

  @override
  Future<bool> directoryExists(
    StorageDomainEnum domain,
    String relativeDirectory,
  ) => _guard(
    () => _fileSystems[domain]!
        .directory(p.posix.join('/', _sanitize(relativeDirectory)))
        .exists(),
  );

  @override
  Future<({DateTime modified, int size})?> statFile(
    StorageDomainEnum domain,
    String relativePath,
  ) => _guard(() async {
    final file = _getFile(domain, relativePath);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return (modified: stat.modified, size: stat.size);
  });
}
