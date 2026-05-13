import 'dart:math' as math;

/// Mirrors `UtilsApp.generateId` so the LLM domain has no app-side dependency.
class UtilsId {
  /// Slugifies [name] (lowercase, non-alphanumerics → `-`, collapsed) and
  /// appends a random 5-char suffix so concurrent calls with the same input
  /// don't collide. Falls back to `profile` when [name] slugifies to empty.
  static String generateId(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'profile';

    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    final suffix = List.generate(
      5,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();

    return '$slug-$suffix';
  }
}
