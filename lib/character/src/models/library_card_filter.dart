/// Which stored column the grid sorts by. The library database maps each to
/// its column and uses the [LibraryCardQuery.descending] flag to pick the
/// direction (and, for variant groups, whether the group's position comes
/// from the newest or oldest card in it). Relevance ordering is not here — a
/// search query is ranked in the search service and ordered in Dart.
enum LibrarySortColumn {
  imported('png_timestamp_imported'),
  modified('timestamp_last_saved'),
  interacted('timestamp_last_chatted'),
  tokens('token_count_all'),
  name('name_lower');

  const LibrarySortColumn(this.column);

  /// Snake-case database column name. Whitelisted here so it is never built
  /// from untrusted input.
  final String column;
}

/// The set of grid filters, translated by the library database into one SQL
/// `WHERE` clause shared by the page, count, and filter-dialog-count queries.
///
/// [recentOnly] is special: when on, it overrides the other tag/creator/folder
/// filters and keeps only cards chatted within [CardListItem.recentWindow] —
/// matching the old in-memory behaviour where prioritize-recent short-circuited
/// the rest. [restrictToPaths] still applies on top, so a search composes with
/// it.
class LibraryCardFilter {
  const LibraryCardFilter({
    this.tags = const {},
    this.creators = const {},
    this.folder,
    this.favoritesOnly = false,
    this.variantsOnly = false,
    this.recentOnly = false,
    this.restrictToPaths,
  });

  /// A card must carry every tag in this set (AND).
  final Set<String> tags;

  /// A card's creator must be one of these lower-cased keys (OR). The key
  /// `unknown` matches cards with no creator.
  final Set<String> creators;

  /// Posix folder path to restrict to (the card's folder equals it or sits
  /// under it). Null means every folder.
  final String? folder;

  final bool favoritesOnly;
  final bool variantsOnly;
  final bool recentOnly;

  /// When non-null, only cards whose image path is in this set match. Holds the
  /// bounded result of an active search query so counts, sort, and paging all
  /// scope to what the search found rather than the whole library. An empty set
  /// matches nothing.
  final Set<String>? restrictToPaths;

  /// The filter with one dimension cleared — used to build each filter
  /// dialog's counts from the pool that passes the *other* filters. The search
  /// restriction is kept so dialog counts stay scoped to the search.
  LibraryCardFilter without({
    bool tags = false,
    bool creators = false,
    bool folder = false,
  }) => LibraryCardFilter(
    tags: tags ? const {} : this.tags,
    creators: creators ? const {} : this.creators,
    folder: folder ? null : this.folder,
    favoritesOnly: favoritesOnly,
    variantsOnly: variantsOnly,
    recentOnly: recentOnly,
    restrictToPaths: restrictToPaths,
  );
}
