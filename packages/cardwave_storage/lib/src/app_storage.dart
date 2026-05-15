import 'dart:async';
import 'dart:typed_data';

// Conditional exports: routes to the correct file at compile time
import 'package:cardwave_storage/src/app_storage_stub.dart'
    if (dart.library.io) 'app_storage_windows.dart'
    if (dart.library.js_interop) 'app_storage_web.dart'
    if (dart.library.html) 'app_storage_web.dart';
import 'package:cardwave_storage/src/storage_exception.dart';

enum StorageDomainEnum { settings, cards }

/// An abstract facade for platform-agnostic file system operations.
///
/// This class defines a common interface for interacting with storage, whether
/// it's the native file system (on Windows, Android, etc.) or a virtual one
/// like IndexedDB (on the Web).
///
/// A key design principle is the standardization of path separators. All methods
/// that accept or return a `relativePath` or `relativeDirectory` expect and
/// provide paths using the POSIX-style forward slash (`/`) as a separator.
/// Implementations are responsible for normalizing platform-specific paths
/// to this standard, ensuring that higher-level application logic can be
/// written in a platform-agnostic way.
///
/// **Error contract:** every IO method below throws [StorageException] on
/// failure (file not found, permission denied, disk full, IndexedDB error,
/// etc.). This wraps `fs_shim`'s native exception type, which doesn't
/// implement Dart's `Exception` interface — wrapping it here lets callers
/// use narrow `on Exception catch` without storage errors slipping through.
abstract class AppStorage {
  static AppStorage? _instance;

  /// Singleton access to the storage facade
  static AppStorage get instance {
    _instance ??= getAppStorage();
    return _instance!;
  }

  /// Initialize the storage.
  ///
  /// On native platforms, this uses a `pathResolver` callback to determine the
  /// absolute root directory for each [StorageDomainEnum].
  ///
  /// On the Web, it maps domains to distinct IndexedDB instances natively and
  /// the `pathResolver` is ignored.
  Future<void> init(String? Function(StorageDomainEnum) pathResolver);

  /// Core IO operations
  /// Writes a list of bytes to a file at the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<void> writeBytes(
    StorageDomainEnum domain,
    String relativePath,
    Uint8List bytes,
  );

  /// Reads a file as a list of bytes from the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<List<int>> readBytes(StorageDomainEnum domain, String relativePath);

  /// Writes a string to a file at the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<void> writeString(
    StorageDomainEnum domain,
    String relativePath,
    String content,
  );

  /// Reads a file as a string from the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<String> readString(StorageDomainEnum domain, String relativePath);

  /// Deletes a specific file at the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<void> deleteFile(StorageDomainEnum domain, String relativePath);

  /// Deletes a directory and all its contents recursively.
  /// The `relativeDirectory` path must use POSIX-style forward slashes (`/`).
  Future<void> deleteDirectory(
    StorageDomainEnum domain,
    String relativeDirectory,
  );

  /// Creates a directory recursively at the given `relativeDirectory`.
  /// The `relativeDirectory` path must use POSIX-style forward slashes (`/`).
  Future<void> createDirectory(
    StorageDomainEnum domain,
    String relativeDirectory,
  );

  /// Lists files in a directory.
  ///
  /// Returns a list of full paths, relative to the domain's root, using
  /// POSIX-style forward slashes (`/`).
  ///
  /// If `extensions` are provided (e.g., `['.png', '.jpg']`), the result is
  /// filtered to include only files with those extensions. The comparison is
  /// case-insensitive.
  Future<List<String>> listDirectory(
    StorageDomainEnum domain,
    String relativeDirectory, {
    List<String>? extensions,
    bool recursive = false,
  });

  /// Checks if a specific file exists at the given `relativePath`.
  /// The `relativePath` must use POSIX-style forward slashes (`/`).
  Future<bool> fileExists(StorageDomainEnum domain, String relativePath);

  /// Checks if a specific directory exists at the given `relativeDirectory`.
  /// The `relativeDirectory` must use POSIX-style forward slashes (`/`).
  Future<bool> directoryExists(
    StorageDomainEnum domain,
    String relativeDirectory,
  );

  /// Resolves [relativePath] to an absolute native filesystem path. Returns
  /// null when absolute paths have no meaning for the backing store (web /
  /// IndexedDB). Needed by surfaces that hand paths to native APIs that
  /// want a real file (e.g. `video_player`).
  String? absolutePathFor(StorageDomainEnum domain, String relativePath);

  /// Returns the file's last-modified timestamp and byte size, or `null` when
  /// the file does not exist. Lets callers answer "does this file exist, and
  /// what are its current metadata values?" in one call without using
  /// try/catch as control flow.
  ///
  /// Throws [StorageException] on real I/O failures (locked file, permission
  /// denied, IndexedDB error). The non-existence case returns null instead of
  /// throwing.
  Future<({DateTime modified, int size})?> statFile(
    StorageDomainEnum domain,
    String relativePath,
  );
}
