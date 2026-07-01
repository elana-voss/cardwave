import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/search.dart';
import 'package:flutter/material.dart';

enum CharacterSortOptionEnum {
  relevance('Relevance ↓'),
  nameAsc('Name ↓'),
  nameDesc('Name ↑'),
  importNewest('Imported ↓'),
  importOldest('Imported ↑'),
  modifiedNewest('Modified ↓'),
  modifiedOldest('Modified ↑'),
  interactedNewest('Interacted ↓'),
  interactedOldest('Interacted ↑'),
  tokensHigh('Tokens ↓'),
  tokensLow('Tokens ↑')
  ;

  final String label;
  const CharacterSortOptionEnum(this.label);
}

/// One row: a card (loaded full) plus how many cards its variant group holds
/// and whether this card is the group's oldest. In grouped mode (the grid) the
/// card is always the group's display card, so [isOriginal] is true; in flat
/// mode (the character switcher) every variant is its own row, so [isOriginal]
/// distinguishes the ORIGINAL from the VARIANT rows.
typedef GridEntry = ({CharacterFile file, int variantCount, bool isOriginal});

/// Drives the character grid off the on-device library database. Filtering,
/// sorting, variant grouping, and counting all happen as SQL queries; only the
/// visible page of cards is loaded into memory at a time, so the grid stays
/// flat however large the library is.
///
/// Two modes:
/// - **Browse** (no query): pages variant groups straight from the database,
///   loading more as the user scrolls.
/// - **Search** (query of 2+ chars): the search service ranks the whole
///   library to a bounded list of paths; those are grouped and ordered by
///   score in memory (already small), then their cards are loaded.
class FilterController extends ChangeNotifier {
  FilterController({
    required this.characterService,
    required this.searchService,
    this.groupVariants = true,
  }) {
    searchController.addListener(_onSearchChanged);
    characterService.addListener(_onCharacterServiceUpdated);
    searchService.addListener(_onSearchIndexChanged);
    unawaited(_refreshLibraryCounters());
    unawaited(_reload());
  }

  static const String allDirectories = 'Folders';
  static const int _pageSize = 60;

  final CharacterService characterService;
  final SearchService searchService;

  /// When false, browse and search list every variant as its own row ordered
  /// by last activity (the character switcher) instead of collapsing each
  /// variant group to one display card (the grid).
  final bool groupVariants;

  final TextEditingController searchController = TextEditingController();
  Set<String> selectedTags = {};
  Set<String> selectedCreators = {};
  String selectedDirectory = allDirectories;
  CharacterSortOptionEnum sortOption = CharacterSortOptionEnum.importNewest;
  bool prioritizeRecent = false;
  bool filterFavorites = false;
  bool filterHasVariants = false;

  String _lastSearchQuery = '';
  CharacterSortOptionEnum? _previousSortOption;

  // Per-card combined keyword + meaning score, set while a query is active.
  Map<String, double> _rankScores = const {};
  // The set of paths the active search matched, kept in step with _rankScores.
  // Scopes counts, sort, and paging to the search result.
  Set<String> _matchedPaths = {};

  // Discards stale page loads when the filter/query changes mid-await.
  int _loadToken = 0;
  // Discards stale rank results when the user keeps typing.
  int _rankRequestId = 0;

  List<GridEntry> _entries = [];
  List<GridEntry> get entries => _entries;

  int _groupTotal = 0; // total variant groups passing the filter (paging)
  int _offset = 0; // groups consumed from the browse cursor
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _cardTotal = 0; // all cards (count-pill denominator)
  int get totalCount => _cardTotal;
  int _filteredCardCount = 0;
  int get filteredCount => _filteredCardCount;

  bool _hasFolders = false;
  bool get hasFolders => _hasFolders;

  Timer? _debounceTimer;
  Timer? _indexReRankTimer;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    // Bump first so any in-flight async load/rank short-circuits before
    // touching disposed state.
    _loadToken++;
    _rankRequestId++;
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _debounceTimer?.cancel();
    _indexReRankTimer?.cancel();
    characterService.removeListener(_onCharacterServiceUpdated);
    searchService.removeListener(_onSearchIndexChanged);
    super.dispose();
  }

  bool get _isQueryActive => searchController.text.trim().length >= 2;

  LibraryCardFilter get _filter => _buildFilter();

  /// The active grid filter. While a search runs, [withSearchScope] narrows
  /// every query to the cards the search matched, so counts, sort, and paging
  /// all reflect the search result. The relevance load passes false because it
  /// restricts to the ranked paths explicitly (and orders them by score).
  LibraryCardFilter _buildFilter({
    bool withSearchScope = true,
    Set<String>? tags,
  }) =>
      LibraryCardFilter(
        tags: tags ?? selectedTags,
        creators: selectedCreators,
        folder: selectedDirectory == allDirectories ? null : selectedDirectory,
        favoritesOnly: filterFavorites,
        variantsOnly: filterHasVariants,
        recentOnly: prioritizeRecent,
        restrictToPaths: (withSearchScope && _isQueryActive)
            ? _matchedPaths
            : null,
      );

  void _setRankScores(Map<String, double> scores) {
    _rankScores = scores;
    _matchedPaths = scores.keys.toSet();
  }

  // Browse and column-sorted search results page in from the database; only a
  // relevance-ordered search loads its whole (bounded) result set at once.
  bool get _isPaged =>
      !_isQueryActive || sortOption != CharacterSortOptionEnum.relevance;

  (LibrarySortColumn, bool) get _sort {
    switch (sortOption) {
      case CharacterSortOptionEnum.nameAsc:
        return (LibrarySortColumn.name, false);
      case CharacterSortOptionEnum.nameDesc:
        return (LibrarySortColumn.name, true);
      case CharacterSortOptionEnum.importOldest:
        return (LibrarySortColumn.imported, false);
      case CharacterSortOptionEnum.modifiedNewest:
        return (LibrarySortColumn.modified, true);
      case CharacterSortOptionEnum.modifiedOldest:
        return (LibrarySortColumn.modified, false);
      case CharacterSortOptionEnum.interactedNewest:
        return (LibrarySortColumn.interacted, true);
      case CharacterSortOptionEnum.interactedOldest:
        return (LibrarySortColumn.interacted, false);
      case CharacterSortOptionEnum.tokensHigh:
        return (LibrarySortColumn.tokens, true);
      case CharacterSortOptionEnum.tokensLow:
        return (LibrarySortColumn.tokens, false);
      // Relevance ordering is applied in memory (search mode); the column here
      // is only a fallback for the empty-query case, where importNewest shows.
      case CharacterSortOptionEnum.relevance:
      case CharacterSortOptionEnum.importNewest:
        return (LibrarySortColumn.imported, true);
    }
  }

  // ---- Listeners ----

  void _onCharacterServiceUpdated() {
    // The initial library scan upserts cards in bursts and notifies every ten
    // of them. Reloading the grid on each tick would flash much of the library
    // through the first page (newest-imported sorts the just-parsed cards to
    // the top) and queue a thumbnail for every card that flickers past. The
    // loading overlay covers the grid while the scan runs, so hold off and
    // reload once when it finishes. In-app edits (create/clone/delete/import)
    // don't set this flag, so they still refresh the grid immediately.
    if (characterService.isLoading) return;
    unawaited(_refreshLibraryCounters());
    unawaited(_reload());
  }

  // Re-rank during an active search so newly-indexed or edited cards surface
  // without the user clearing the field. Rate-limit, not debounce — the search
  // service notifies in continuous bursts during indexing.
  void _onSearchIndexChanged() {
    if (!_isQueryActive) return;
    if (_indexReRankTimer?.isActive ?? false) return;
    _indexReRankTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_isQueryActive) return;
      unawaited(_resolveQueryAndUpdate());
    });
  }

  void _onSearchChanged() {
    final query = searchController.text;
    if (query != _lastSearchQuery) {
      if (query.isNotEmpty && _lastSearchQuery.isEmpty) {
        _previousSortOption = sortOption;
        sortOption = CharacterSortOptionEnum.relevance;
      } else if (query.isEmpty &&
          _lastSearchQuery.isNotEmpty &&
          _previousSortOption != null) {
        sortOption = _previousSortOption!;
        _previousSortOption = null;
      }
      _lastSearchQuery = query;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      _resolveQueryAndUpdate,
    );
  }

  // ---- Filter state ----

  bool get hasActiveFilters =>
      searchController.text.isNotEmpty ||
      selectedTags.isNotEmpty ||
      selectedDirectory != allDirectories ||
      selectedCreators.isNotEmpty ||
      filterFavorites ||
      prioritizeRecent ||
      filterHasVariants;

  void clearAllFilters() {
    searchController.clear();
    selectedTags = {};
    selectedCreators = {};
    selectedDirectory = allDirectories;
    filterFavorites = false;
    prioritizeRecent = false;
    filterHasVariants = false;
    unawaited(_reload());
  }

  void setSortOption(CharacterSortOptionEnum option) {
    sortOption = option;
    _previousSortOption = null;
    unawaited(_reload());
  }

  void togglePrioritizeRecent() {
    prioritizeRecent = !prioritizeRecent;
    unawaited(_reload());
  }

  void toggleFilterFavorites() {
    filterFavorites = !filterFavorites;
    unawaited(_reload());
  }

  void toggleFilterHasVariants() {
    filterHasVariants = !filterHasVariants;
    unawaited(_reload());
  }

  void setTags(Set<String> tags) {
    selectedTags = tags;
    unawaited(_reload());
  }

  void setCreators(Set<String> creators) {
    selectedCreators = creators;
    unawaited(_reload());
  }

  void setDirectory(String directory) {
    selectedDirectory = directory;
    unawaited(_reload());
  }

  // ---- Filter dialogs ----

  Future<void> openCreatorFilterDialog() async {
    final newCreators = await NavigationService().showMultiSelectDialog(
      title: 'Filter Creators',
      items: await characterService.creatorCounts(_filter),
      selectedItems: selectedCreators,
    );
    if (newCreators != null) setCreators(newCreators);
  }

  Future<void> openTagFilterDialog() async {
    final newTags = await NavigationService().showMultiSelectDialog(
      title: 'Filter Tags',
      items: await _tagCounts(selectedTags),
      selectedItems: selectedTags,
      dynamicItemsCallback: _tagCounts,
    );
    if (newTags != null) setTags(newTags);
  }

  Future<void> openDirectoryFilterDialog() async {
    final newDirectory = await NavigationService().showPickFolderDialog(
      title: 'Filter by Folder',
      items: await _directoryCounts(),
      selectedItem: selectedDirectory,
      allFoldersKey: allDirectories,
    );
    if (newDirectory != null) setDirectory(newDirectory);
  }

  // Per-tag counts over the pool passing the current creator/folder/favorite/
  // variant filters plus whatever tags are tentatively selected in the dialog.
  Future<Map<String, int>> _tagCounts(Set<String> selected) async {
    final counts = await characterService.tagCounts(_buildFilter(tags: selected));
    for (final tag in selected) {
      counts.putIfAbsent(tag, () => 0);
    }
    return counts;
  }

  // Rolls the per-folder leaf counts up the folder tree (each card counts for
  // every ancestor path), seeding all known folders to 0 so empty ones still
  // appear in the picker.
  Future<Map<String, int>> _directoryCounts() async {
    final leaf = await characterService.folderLeafCounts(_filter);

    // In browse mode, seed every folder to 0 so empty ones are still
    // navigable. During a search, skip the seeding so only folders that hold a
    // matching card appear — picking a folder with no results is then
    // impossible.
    final counts = <String, int>{};
    if (!_isQueryActive) {
      final allFolders = await characterService.distinctFolders();
      for (final dir in allFolders) {
        if (dir == '.') continue;
        var current = '';
        for (final part in dir.split('/')) {
          current = current.isEmpty ? part : '$current/$part';
          counts.putIfAbsent(current, () => 0);
        }
      }
    }

    var allCount = 0;
    for (final entry in leaf.entries) {
      allCount += entry.value;
      if (entry.key == '.') continue;
      var current = '';
      for (final part in entry.key.split('/')) {
        current = current.isEmpty ? part : '$current/$part';
        counts[current] = (counts[current] ?? 0) + entry.value;
      }
    }

    final result = <String, int>{allDirectories: allCount};
    final sorted = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final dir in sorted) {
      result[dir] = counts[dir]!;
    }
    return result;
  }

  // ---- Loading ----

  // The unfiltered card total and whether any folders exist depend only on the
  // library, not the active filter — so they're refreshed when the library
  // changes (scan / create / clone / delete / import), not on every filter flip
  // or search reload, where re-running a full COUNT / DISTINCT would be wasted.
  Future<void> _refreshLibraryCounters() async {
    final (folders, total) = await (
      characterService.distinctFolders(),
      characterService.countCards(const LibraryCardFilter()),
    ).wait;
    if (_disposed) return;
    _hasFolders = folders.any((dir) => dir != '.');
    _cardTotal = total;
    notifyListeners();
  }

  Future<void> _reload() async {
    final token = ++_loadToken;
    _isLoading = true;
    notifyListeners();

    // A relevance-ordered search is ordered by score in Dart; every other case
    // (browse, or a search with an explicit sort column) pages from the
    // database with the filter scoped to the search result.
    if (_isQueryActive && sortOption == CharacterSortOptionEnum.relevance) {
      await _loadSearch(token);
    } else {
      await _loadBrowseFirstPage(token);
    }
  }

  Future<void> _loadBrowseFirstPage(int token) async {
    final filter = _filter;

    if (!groupVariants) {
      final (cardCount, page) = await (
        characterService.countCards(filter),
        characterService.pageCardsByActivity(
          filter: filter,
          offset: 0,
          limit: _pageSize,
        ),
      ).wait;
      if (token != _loadToken) return;
      final loaded = await _loadEntries([
        for (final row in page)
          (
            path: row.item.appCardImagePath,
            variantCount: row.item.variantCount,
            isOriginal: row.isOriginal,
          ),
      ]);
      if (token != _loadToken) return;

      _groupTotal = cardCount;
      _filteredCardCount = cardCount;
      _entries = loaded;
      _offset = page.length;
      _hasMore = _offset < _groupTotal;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final (column, descending) = _sort;
    // The two counts and the first page are independent reads of the same
    // filter, so issue them together rather than one after another.
    final (groupTotal, cardCount, page) = await (
      characterService.countCardGroups(filter),
      characterService.countCards(filter),
      characterService.pageCards(
        filter: filter,
        sortColumn: column,
        descending: descending,
        offset: 0,
        limit: _pageSize,
      ),
    ).wait;
    if (token != _loadToken) return;
    final loaded = await _loadEntries([
      for (final item in page)
        (
          path: item.appCardImagePath,
          variantCount: item.variantCount,
          isOriginal: true,
        ),
    ]);
    if (token != _loadToken) return;

    _groupTotal = groupTotal;
    _filteredCardCount = cardCount;
    _entries = loaded;
    _offset = page.length;
    _hasMore = _offset < _groupTotal;
    _isLoading = false;
    notifyListeners();
  }

  /// Loads the next browse page and appends it. No-op during a search (search
  /// results are already fully loaded) or when nothing is left.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || !_isPaged) return;
    final token = _loadToken;
    _isLoading = true;
    notifyListeners();

    if (!groupVariants) {
      final page = await characterService.pageCardsByActivity(
        filter: _filter,
        offset: _offset,
        limit: _pageSize,
      );
      if (token != _loadToken) return;
      final loaded = await _loadEntries([
        for (final row in page)
          (
            path: row.item.appCardImagePath,
            variantCount: row.item.variantCount,
            isOriginal: row.isOriginal,
          ),
      ]);
      if (token != _loadToken) return;

      _entries = [..._entries, ...loaded];
      _offset += page.length;
      _hasMore = _offset < _groupTotal;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final (column, descending) = _sort;
    final page = await characterService.pageCards(
      filter: _filter,
      sortColumn: column,
      descending: descending,
      offset: _offset,
      limit: _pageSize,
    );
    if (token != _loadToken) return;
    final loaded = await _loadEntries([
      for (final item in page)
        (
          path: item.appCardImagePath,
          variantCount: item.variantCount,
          isOriginal: true,
        ),
    ]);
    if (token != _loadToken) return;

    _entries = [..._entries, ...loaded];
    _offset += page.length;
    _hasMore = _offset < _groupTotal;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSearch(int token) async {
    final ranked = _rankScores.keys.toList()
      ..sort((a, b) => (_rankScores[b] ?? 0).compareTo(_rankScores[a] ?? 0));
    // The ranked paths already restrict the result, so the filter passed here
    // carries only the tag/creator/folder narrowing, not the search scope.
    final filter = _buildFilter(withSearchScope: false);

    if (!groupVariants) {
      // Switcher: keep each matched card as its own row, in score order. Badges
      // come from the whole-library variant info, so a matched variant shows
      // VARIANT even when its original isn't a match. The two reads don't depend
      // on each other, so issue them together.
      final (rows, info) = await (
        characterService.cardsByPaths(ranked, filter),
        characterService.variantInfoForPaths(ranked),
      ).wait;
      if (token != _loadToken) return;
      final byPath = {for (final row in rows) row.appCardImagePath: row};
      final ordered = [
        for (final path in ranked)
          if (byPath[path] != null) byPath[path]!,
      ];
      final loaded = await _loadEntries([
        for (final row in ordered)
          (
            path: row.appCardImagePath,
            variantCount: info[row.appCardImagePath]!.variantCount,
            isOriginal: info[row.appCardImagePath]!.isOriginal,
          ),
      ]);
      if (token != _loadToken) return;

      _entries = loaded;
      _groupTotal = loaded.length;
      _offset = loaded.length;
      _hasMore = false;
      _filteredCardCount = rows.length;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final rows = await characterService.cardsByPaths(ranked, filter);
    if (token != _loadToken) return;

    // Group by root id: the oldest variant represents the group; order groups
    // by their best-scoring card.
    final byRoot = <String, List<CardListItem>>{};
    for (final row in rows) {
      (byRoot[row.appCardRootId] ??= []).add(row);
    }
    final groups = <({CardListItem repr, int count, double score})>[];
    for (final cards in byRoot.values) {
      cards.sort(
        (a, b) => a.pngTimestampImported.compareTo(b.pngTimestampImported),
      );
      var score = 0.0;
      for (final card in cards) {
        final cardScore = _rankScores[card.appCardImagePath] ?? 0;
        if (cardScore > score) score = cardScore;
      }
      groups.add((repr: cards.first, count: cards.length, score: score));
    }
    groups.sort((a, b) => b.score.compareTo(a.score));

    final loaded = await _loadEntries([
      for (final group in groups)
        (
          path: group.repr.appCardImagePath,
          variantCount: group.count,
          isOriginal: true,
        ),
    ]);
    if (token != _loadToken) return;

    _entries = loaded;
    _groupTotal = loaded.length;
    _offset = loaded.length;
    _hasMore = false;
    _filteredCardCount = rows.length;
    _isLoading = false;
    notifyListeners();
  }

  /// Loads each path's full card body into a grid entry, in order, skipping any
  /// card that can't be read. Backs both the paged browse load and the ranked
  /// search load — they differ only in where the variant count comes from.
  Future<List<GridEntry>> _loadEntries(
    Iterable<({String path, int variantCount, bool isOriginal})> items,
  ) async {
    final result = <GridEntry>[];
    for (final item in items) {
      try {
        final file = await characterService.loadFull(item.path);
        result.add((
          file: file,
          variantCount: item.variantCount,
          isOriginal: item.isOriginal,
        ));
      } on Exception {
        // Skip a card that can't be read.
      }
    }
    return result;
  }

  /// Refreshes the grid for the current query: first the keyword-only ranking
  /// (instant), then the combined keyword + meaning ranking once the query
  /// vector arrives.
  Future<void> _resolveQueryAndUpdate() async {
    final query = searchController.text.trim();
    if (query.length < 2) {
      _setRankScores(const {});
      await _reload();
      return;
    }

    final reqId = ++_rankRequestId;
    final pool = await characterService.allCardPaths();
    if (reqId != _rankRequestId) return;

    final lexical = await searchService.rankLexical(query, pool);
    if (reqId != _rankRequestId) return;
    _setRankScores(lexical);
    await _reload();

    final fused = await searchService.rank(query, pool);
    if (reqId != _rankRequestId) return;
    _setRankScores(fused);
    await _reload();
  }
}
