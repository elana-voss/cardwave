import 'package:uuid/uuid.dart';

/// Mirrors `UtilsApp.generateId` so the LLM domain has no app-side dependency.
class UtilsId {
  /// Slugifies [name] (lowercase, non-alphanumerics → `-`, collapsed) and
  /// appends a UUID v4 so ids are globally unique. Falls back to `profile`
  /// when [name] slugifies to empty.
  static String generateId(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'profile';

    return '$slug-${const Uuid().v4()}';
  }
}
