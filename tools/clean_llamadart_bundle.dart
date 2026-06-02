/// Removes cached llamadart native bundles + the Flutter build's
/// emitted DLLs so the next `dart pub get` re-fetches them via the
/// hook. Used when the patched/upstream bundle source URL is changed
/// and the cache needs to be invalidated.

import 'dart:io';

void main() {
  // Wipe both .dart_tool dirs (fork + app) plus the Flutter build
  // output entirely. The hooks_runner caches builds by content hash;
  // partial wipes leave stale output.json pointing at deleted dirs.
  // Re-run `flutter pub get` after this script.
  final targets = [
    Directory(r'c:\Users\theco\ai\software\llamadart\.dart_tool'),
    Directory(r'c:\Users\theco\ai\software\own_card_editor\app\.dart_tool'),
    Directory(
      r'c:\Users\theco\ai\software\own_card_editor\app\build\windows',
    ),
    // Each git-ref llamadart checkout in the pub cache holds its own
    // downloaded+extracted native bundle under .dart_tool, keyed by the
    // llama.cpp tag. When the override release is re-published under the SAME
    // tag (asset content changed, tag unchanged), this cache is a hit and the
    // stale DLL is reused — so it must be wiped too, or the swap never lands.
    ..._pubCacheLlamadartDartToolDirs(),
  ];

  for (final entity in targets) {
    if (entity.existsSync()) {
      entity.deleteSync(recursive: true);
      stdout.writeln('removed: ${entity.path}');
    } else {
      stdout.writeln('absent:  ${entity.path}');
    }
  }
}

List<Directory> _pubCacheLlamadartDartToolDirs() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null) return const [];
  final gitCache = Directory('$localAppData\\Pub\\Cache\\git');
  if (!gitCache.existsSync()) return const [];
  return gitCache
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.split(Platform.pathSeparator).last.startsWith(
            'llamadart-',
          ))
      .map((d) => Directory('${d.path}\\.dart_tool'))
      .where((d) => d.existsSync())
      .toList();
}
