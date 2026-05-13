import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/search.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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

class FilterController extends ChangeNotifier {
  FilterController({
    required this.characterService,
    required this.searchService,
  }) {
    searchController.addListener(_onSearchChanged);
    characterService.addListener(_onCharacterServiceUpdated);
    _onCharacterServiceUpdated();
  }
  static const String allDirectories = 'Folders';

  final CharacterService characterService;
  final SearchService searchService;

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

  // Reqid discards stale rank results (user kept typing OR the controller
  // was disposed mid-await).
  int _rankRequestId = 0;

  // Per-card combined keyword + meaning score; consumed by the relevance
  // branch of `_sortFiltered`. Empty when no query is active.
  Map<String, double> _rankScores = const {};

  List<CharacterFile> _filteredFiles = [];
  List<CharacterFile> get filteredFiles => _filteredFiles;

  List<List<CharacterFile>> _groupedFiles = [];
  List<List<CharacterFile>> get groupedFiles => _groupedFiles;

  Timer? _debounceTimer;

  final Map<String, Set<String>> _tagIndex = {};
  final Map<String, List<String>> _cardTags = {};
  final Map<String, String> _cardDirectories = {};
  final Set<String> _basePoolForTags = {};
  final Set<String> _basePoolForCreators = {};
  final Map<String, int> _variantCounts = {};
  final Set<String> _basePoolForDirectories = {};
  bool _needsIndexRebuild = true;

  @override
  void dispose() {
    // Bump first so any in-flight async rank short-circuits on its id
    // check before touching disposed state.
    _rankRequestId++;
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _debounceTimer?.cancel();
    characterService.removeListener(_onCharacterServiceUpdated);
    super.dispose();
  }

  void _onCharacterServiceUpdated() {
    _needsIndexRebuild = true;
    updateFilteredList();
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

  /// Refreshes the grid for the current query: first with the keyword-only
  /// ranking (so the user sees results immediately even if the meaning
  /// engine is busy), then again with the combined ranking once the query
  /// vector arrives.
  Future<void> _resolveQueryAndUpdate() async {
    final query = searchController.text.trim();

    if (query.length < 2) {
      _rankScores = const {};
      updateFilteredList();
      return;
    }

    final reqId = ++_rankRequestId;

    // Show keyword-only ranking right away. RRF inside the service handles
    // a single ranked list correctly, so dropping the meaning-search rank
    // doesn't break the math — it just narrows the signal to the lexical
    // channel until the embedder catches up.
    final pool = _filteredFiles.map((f) => f.appCardImagePath).toList();
    _rankScores = searchService.rankLexical(query, pool);
    updateFilteredList();

    final fused = await searchService.rank(query, pool);
    if (reqId != _rankRequestId) return;
    _rankScores = fused;
    updateFilteredList();
  }

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
    selectedTags.clear();
    selectedCreators.clear();
    selectedDirectory = allDirectories;
    filterFavorites = false;
    prioritizeRecent = false;
    filterHasVariants = false;
    updateFilteredList();
  }

  void setSortOption(CharacterSortOptionEnum option) {
    sortOption = option;
    _previousSortOption = null;
    updateFilteredList();
  }

  void togglePrioritizeRecent() {
    prioritizeRecent = !prioritizeRecent;
    updateFilteredList();
  }

  void toggleFilterFavorites() {
    filterFavorites = !filterFavorites;
    updateFilteredList();
  }

  void toggleFilterHasVariants() {
    filterHasVariants = !filterHasVariants;
    updateFilteredList();
  }

  void setTags(Set<String> tags) {
    selectedTags = tags;
    updateFilteredList();
  }

  void setCreators(Set<String> creators) {
    selectedCreators = creators;
    updateFilteredList();
  }

  void setDirectory(String directory) {
    selectedDirectory = directory;
    updateFilteredList();
  }

  /// Opens the creator multi-select dialog and applies the result. No-op on
  /// cancel.
  Future<void> openCreatorFilterDialog() async {
    final newCreators = await NavigationService().showMultiSelectDialog(
      title: 'Filter Creators',
      items: getCreatorCounts(),
      selectedItems: selectedCreators,
    );
    if (newCreators != null) setCreators(newCreators);
  }

  /// Opens the tag multi-select dialog and applies the result. Passes the
  /// un-narrowed universe of tags as `items` so re-opening with tags already
  /// selected still shows every option; [getTagCounts] runs as a dynamic
  /// callback so visible counts narrow as the selection grows.
  Future<void> openTagFilterDialog() async {
    final newTags = await NavigationService().showMultiSelectDialog(
      title: 'Filter Tags',
      items: getTagCounts({}),
      selectedItems: selectedTags,
      dynamicItemsCallback: getTagCounts,
    );
    if (newTags != null) setTags(newTags);
  }

  /// Opens the folder-tree picker and applies the result. No-op on cancel.
  Future<void> openDirectoryFilterDialog() async {
    final newDirectory = await NavigationService().showPickFolderDialog(
      title: 'Filter by Folder',
      items: getDirectoryCounts(),
      selectedItem: selectedDirectory,
      allFoldersKey: allDirectories,
    );
    if (newDirectory != null) setDirectory(newDirectory);
  }

  Map<String, int> getCreatorCounts() {
    final creatorCounts = <String, int>{};
    for (final file in characterService.characterFiles) {
      if (_basePoolForCreators.contains(file.appCardImagePath)) {
        final creator = file.card.creator.toLowerCase();
        final key = creator.isEmpty ? 'unknown' : creator;
        creatorCounts[key] = (creatorCounts[key] ?? 0) + 1;
      }
    }
    return creatorCounts;
  }

  Map<String, int> getTagCounts([Set<String>? tempSelectedTags]) {
    final tagsToEvaluate = tempSelectedTags ?? selectedTags;
    final activePool = Set<String>.of(_basePoolForTags);

    for (final tag in tagsToEvaluate) {
      final tagSet = _tagIndex[tag];
      if (tagSet == null || tagSet.isEmpty) {
        activePool.clear();
        break;
      }
      activePool.retainAll(tagSet); // Blazing fast in-place modification
      if (activePool.isEmpty) break;
    }

    final tagCounts = <String, int>{};
    if (activePool.isNotEmpty) {
      // O(N) fast tally instead of thousands of Set allocations
      for (final id in activePool) {
        final tags = _cardTags[id];
        if (tags != null) {
          for (final tag in tags) {
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
        }
      }
    }

    // Ensure actively selected tags are always present in the map
    for (final tag in tagsToEvaluate) {
      tagCounts.putIfAbsent(tag, () => 0);
    }

    return tagCounts;
  }

  Map<String, int> getDirectoryCounts() {
    final counts = <String, int>{};

    // Seed all existing directories to 0 so they don't jump/disappear
    for (final dir in _cardDirectories.values) {
      if (dir != '.') {
        final parts = dir.split('/');
        var currentPath = '';
        for (final part in parts) {
          currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
          counts.putIfAbsent(currentPath, () => 0);
        }
      }
    }

    var allCount = 0;
    for (final id in _basePoolForDirectories) {
      final dir = _cardDirectories[id];
      if (dir != null && dir != '.') {
        final parts = dir.split('/');
        var currentPath = '';
        for (final part in parts) {
          currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
          counts[currentPath] = (counts[currentPath] ?? 0) + 1;
        }
      }
      allCount++;
    }

    final result = <String, int>{FilterController.allDirectories: allCount};

    final sortedDirs = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final dir in sortedDirs) {
      result[dir] = counts[dir]!;
    }

    return result;
  }

  void updateFilteredList() {
    final allFiles = characterService.characterFiles;

    if (_needsIndexRebuild) {
      _tagIndex.clear();
      _cardTags.clear();
      _cardDirectories.clear();
      _variantCounts.clear();
      for (final file in allFiles) {
        final id = file.appCardImagePath;
        _cardTags[id] = file.card.tags;
        _cardDirectories[id] = p.posix.dirname(id);
        for (final tag in file.card.tags) {
          _tagIndex.putIfAbsent(tag, () => {}).add(id);
        }
        _variantCounts[file.appCardRootId] =
            (_variantCounts[file.appCardRootId] ?? 0) + 1;
      }
      _needsIndexRebuild = false;
    }

    final hasSelectedTags = selectedTags.isNotEmpty;
    final hasSelectedCreators = selectedCreators.isNotEmpty;
    final hasSelectedDirectory = selectedDirectory != allDirectories;

    _basePoolForTags.clear();
    _basePoolForCreators.clear();
    _basePoolForDirectories.clear();

    _filteredFiles = allFiles.where((file) {
      final card = file.card;

      if (prioritizeRecent) {
        return file.isRecent;
      }

      if (filterFavorites && !card.cardwaveData.isFavorite) return false;

      if (filterHasVariants && (_variantCounts[file.appCardRootId] ?? 0) < 2) {
        return false;
      }

      var passesCreator = true;
      if (hasSelectedCreators) {
        final creator = card.creator.toLowerCase();
        final key = creator.isEmpty ? 'unknown' : creator;
        passesCreator = selectedCreators.contains(key);
      }

      var passesTags = true;
      if (hasSelectedTags) {
        for (final tag in selectedTags) {
          if (!card.tags.contains(tag)) {
            passesTags = false;
            break;
          }
        }
      }

      var passesDirectory = true;
      if (hasSelectedDirectory) {
        final dir =
            _cardDirectories[file.appCardImagePath] ??
            p.posix.dirname(file.appCardImagePath);
        if (dir != selectedDirectory &&
            !dir.startsWith('$selectedDirectory/')) {
          passesDirectory = false;
        }
      }

      if (passesCreator && passesDirectory) {
        _basePoolForTags.add(file.appCardImagePath);
      }
      if (passesTags && passesDirectory) {
        _basePoolForCreators.add(file.appCardImagePath);
      }
      if (passesCreator && passesTags) {
        _basePoolForDirectories.add(file.appCardImagePath);
      }

      return passesCreator && passesTags && passesDirectory;
    }).toList();

    _sortFiltered();
    _updateGroupedFiles();
    notifyListeners();
  }

  void _sortFiltered() {
    int Function(CharacterFile, CharacterFile) comparator;

    switch (sortOption) {
      case CharacterSortOptionEnum.relevance:
        comparator = (a, b) {
          final scoreA = _rankScores[a.appCardImagePath] ?? 0.0;
          final scoreB = _rankScores[b.appCardImagePath] ?? 0.0;
          final scoreCompare = scoreB.compareTo(scoreA); // High to low
          if (scoreCompare != 0) return scoreCompare;
          return a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
        };
      case CharacterSortOptionEnum.nameAsc:
        comparator = (a, b) =>
            a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
      case CharacterSortOptionEnum.nameDesc:
        comparator = (a, b) =>
            b.card.name.toLowerCase().compareTo(a.card.name.toLowerCase());
      case CharacterSortOptionEnum.importNewest:
        comparator = (a, b) =>
            b.pngTimestampImported.compareTo(a.pngTimestampImported);
      case CharacterSortOptionEnum.importOldest:
        comparator = (a, b) =>
            a.pngTimestampImported.compareTo(b.pngTimestampImported);
      case CharacterSortOptionEnum.modifiedNewest:
        comparator = (a, b) => (b.appCardTimestampLastSaved ?? 0).compareTo(
          a.appCardTimestampLastSaved ?? 0,
        );
      case CharacterSortOptionEnum.modifiedOldest:
        comparator = (a, b) => (a.appCardTimestampLastSaved ?? 0).compareTo(
          b.appCardTimestampLastSaved ?? 0,
        );
      case CharacterSortOptionEnum.interactedNewest:
        comparator = (a, b) => (b.appCardTimestampLastChatted ?? 0).compareTo(
          a.appCardTimestampLastChatted ?? 0,
        );
      case CharacterSortOptionEnum.interactedOldest:
        comparator = (a, b) => (a.appCardTimestampLastChatted ?? 0).compareTo(
          b.appCardTimestampLastChatted ?? 0,
        );
      case CharacterSortOptionEnum.tokensHigh:
        comparator = (a, b) =>
            b.appCardTokenCountAll.compareTo(a.appCardTokenCountAll);
      case CharacterSortOptionEnum.tokensLow:
        comparator = (a, b) =>
            a.appCardTokenCountAll.compareTo(b.appCardTokenCountAll);
    }

    _filteredFiles.sort(comparator);
  }

  void _updateGroupedFiles() {
    final groups = <String, List<CharacterFile>>{};
    for (final file in _filteredFiles) {
      (groups[file.appCardRootId] ??= []).add(file);
    }

    final result = groups.values.toList();
    for (final stack in result) {
      if (stack.length > 1) {
        stack.sort(
          (a, b) => a.pngTimestampImported.compareTo(b.pngTimestampImported),
        );
      }
    }
    _groupedFiles = result;
  }
}
