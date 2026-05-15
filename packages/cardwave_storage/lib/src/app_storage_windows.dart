import 'dart:async';
import 'dart:io' as io; // Imported specifically for the native watcher
import 'dart:typed_data';

import 'package:cardwave_storage/src/app_storage.dart';
import 'package:cardwave_storage/src/storage_exception.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:path/path.dart' as p;

AppStorage getAppStorage() => AppStorageWindows();

/// Native platform implementation of [AppStorage] that uses `dart:io`.
///
/// This class is used for all non-web platforms (Windows, Android, iOS, etc.).
/// It interacts directly with the host operating system's file system.
///
/// To fulfill the [AppStorage] contract of using POSIX-style paths internally,
/// this class performs two key transformations:
/// 1.  **Input Normalization**: It uses `p.normalize()` on the root path provided
///     by the `pathResolver` to ensure it uses the correct OS-specific separators
///     (e.g., `\` on Windows).
/// 2.  **Output Standardization**: When returning paths from `listDirectory`, it
///     converts the native file system paths back into the standardized,
///     relative POSIX format (using `/`) before returning them to the rest of
///     the application.
class AppStorageWindows extends AppStorage {
  late final String? Function(StorageDomainEnum) _pathResolver;
  // Initialize the native IO file system from fs_shim
  final FileSystem _fs = fileSystemIo;

  @override
  Future<void> init(String? Function(StorageDomainEnum) pathResolver) async {
    _pathResolver = pathResolver;
  }

  /// Resolves the absolute base path for a given domain on the native file system.
  ///
  /// It normalizes the path from the resolver to ensure it uses the correct
  /// OS-specific separators (e.g., `\` on Windows).
  String _getBasePath(StorageDomainEnum domain) {
    final path = _pathResolver(domain);
    if (path == null) {
      throw StateError('Path for domain $domain is not configured.');
    }
    if (path.isEmpty && (io.Platform.isAndroid || io.Platform.isIOS)) {
      throw StateError(
        'On mobile devices, pathResolver must return an absolute writable directory (e.g., from path_provider). Using an empty string resolves to the read-only OS root "/".',
      );
    }
    // Normalizes the path to use the correct OS-specific separators.
    return p.normalize(path);
  }

  /// Returns a [File] handle for the given domain and relative path.
  ///
  /// It joins the OS-specific base path with the incoming relative path.
  /// The `path` package's `join` method correctly handles this, even if the
  /// `relativePath` uses forward slashes on Windows.
  File _getFile(StorageDomainEnum domain, String relativePath) =>
      _fs.file(p.join(_getBasePath(domain), relativePath));

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
      p.join(_getBasePath(domain), relativePath);

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
    final dir = _fs.directory(p.join(_getBasePath(domain), relativeDirectory));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  @override
  Future<void> createDirectory(
    StorageDomainEnum domain,
    String relativeDirectory,
  ) => _guard(
    () => _fs
        .directory(p.join(_getBasePath(domain), relativeDirectory))
        .create(recursive: true),
  );

  @override
  Future<List<String>> listDirectory(
    StorageDomainEnum domain,
    String relativeDirectory, {
    List<String>? extensions,
    bool recursive = false,
  }) => _guard(() async {
    final dir = _fs.directory(p.join(_getBasePath(domain), relativeDirectory));
    if (!await dir.exists()) return [];

    var entities = dir.list(recursive: recursive);
    final basePath = _getBasePath(domain);

    // Filter out hidden files and directories (any segment starting with '.')
    // *inside* the listed directory. Computing the relative path from
    // `dir.path` (not `basePath`) ensures the filter ignores ancestor
    // segments — important because every app-data folder lives under
    // `.cache_<app>_<version>/...`, which would otherwise filter everything.
    entities = entities.where((entity) {
      final relativePath = p.relative(entity.path, from: dir.path);
      if (relativePath == '.') return false;
      return !relativePath
          .split(p.separator)
          .any((segment) => segment.startsWith('.'));
    });

    // Apply extension filtering if provided
    if (extensions != null && extensions.isNotEmpty) {
      final lowerCaseExtensions = extensions
          .map((e) => e.toLowerCase())
          .toSet();
      entities = entities.where(
        (e) => lowerCaseExtensions.contains(p.extension(e.path).toLowerCase()),
      );
    }

    final entityList = await entities.toList();

    // Converts native paths (which may use `\`) to relative, POSIX-style
    // paths (using `/`) to conform to the AppStorage contract.
    return entityList
        .map(
          (e) =>
              p.relative(e.path, from: basePath).replaceAll(p.separator, '/'),
        )
        .toList();
  });

  @override
  Future<bool> fileExists(StorageDomainEnum domain, String relativePath) =>
      _guard(() => _getFile(domain, relativePath).exists());

  @override
  Future<bool> directoryExists(
    StorageDomainEnum domain,
    String relativeDirectory,
  ) => _guard(
    () =>
        _fs.directory(p.join(_getBasePath(domain), relativeDirectory)).exists(),
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
