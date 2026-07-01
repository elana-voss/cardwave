import 'package:cardwave/common/common.dart';
import 'package:path/path.dart' as p;

/// A light, display-only view of one card for the grid. Carries just the
/// fields the grid tile renders — never the heavy card body (description,
/// personality, scenario, greetings, lorebook). The full [CharacterFile]
/// is loaded on demand (chat, editor, actions) via
/// `CharacterService.loadFull`, so the grid stays flat in memory no matter
/// how large the library is.
///
/// Assembled from a library-database row plus the group's variant count, so
/// it is not a 1:1 mirror of any single stored row.
class CardListItem {
  const CardListItem({
    required this.appCardImagePath,
    required this.name,
    required this.creator,
    required this.tags,
    required this.previewDescription,
    required this.appCardRootId,
    required this.isFavorite,
    required this.variantNotes,
    required this.pngTimestampImported,
    required this.pngTimestampLastSaved,
    required this.timestampLastChatted,
    required this.timestampLastChattedDismissed,
    required this.variantCount,
  });

  /// Window after a chat in which a card counts as "recent" (drives the
  /// recent border and the prioritize-recent filter). Mirrors the same
  /// window used by [CharacterFile.isRecent].
  static const Duration recentWindow = Duration(days: 30);

  final String appCardImagePath;
  final String name;
  final String creator;
  final List<String> tags;
  final String previewDescription;
  final String appCardRootId;
  final bool isFavorite;
  final String variantNotes;
  final int pngTimestampImported;
  final int pngTimestampLastSaved;
  final int? timestampLastChatted;
  final int? timestampLastChattedDismissed;

  /// Number of cards in this card's variant group (within the current
  /// filtered view). 1 means the tile is a single card; >1 shows the
  /// variant badge.
  final int variantCount;

  String get appCardCharacterFolder => p.posix.join(
    AppConstants.customCacheCharacterPath,
    p.posix.withoutExtension(appCardImagePath),
  );

  String get appCardThumbnailPath =>
      p.posix.join(appCardCharacterFolder, AppConstants.cardThumbnailFileName);

  bool get isRecent {
    final chatted = timestampLastChatted ?? 0;
    if (chatted == 0) return false;
    final dismissed = timestampLastChattedDismissed ?? 0;
    if (dismissed >= chatted) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return chatted > (now - recentWindow.inMilliseconds);
  }
}
