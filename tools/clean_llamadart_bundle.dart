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
