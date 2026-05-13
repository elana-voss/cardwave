import 'package:cardwave/character/src/models/taxonomy_group.dart';
import 'package:cardwave/character/src/models/taxonomy_tag.dart';
import 'package:cardwave/character/src/repositories/taxonomy_repository.dart';
import 'package:flutter/foundation.dart';

/// Controller layer between [DialogTaxonomyEditor] and [TaxonomyRepository].
/// Exists so the UI satisfies the project's UI → Controller → Repository
/// rule (CLAUDE.md "Architectural layering"), and so the editor's mutations
/// have one place to trim input, validate the outcome, track save state,
/// and rebroadcast it to the dialog.
///
/// Read methods delegate to the repository unchanged. Write methods return
/// a `String?` — null on success, a human-readable error message on
/// failure (id collisions, cycle attempts, missing groups, disk failures).
/// The dialog hands that string straight to a snackbar.
///
/// This class is a [ChangeNotifier]; the repository deliberately is not.
/// Save status (`lastSavedAt`, `lastSaveError`) lives here so the
/// repository can stay a plain `Provider<TaxonomyRepository>` value while
/// the dialog still gets push-based rebuilds on every save outcome.
class TaxonomyEditorController extends ChangeNotifier {
  TaxonomyEditorController(this._repository);

  final TaxonomyRepository _repository;

  DateTime? _lastSavedAt;
  Object? _lastSaveError;

  /// Last-saved timestamp; null until the first successful save.
  DateTime? get lastSavedAt => _lastSavedAt;

  /// Last save failure, cleared by the next successful save. The
  /// repository's `loggingService.error` is always called first, so the
  /// dev log stays the source of truth — this field exists purely so the
  /// editor footer can flag the user that their last change didn't land.
  Object? get lastSaveError => _lastSaveError;

  /// Read access — the dialog walks the tree to render. Read methods
  /// don't mutate, don't notify, and don't validate.

  TaxonomyGroup? getGroup(String groupId) => _repository.getGroup(groupId);
  TaxonomyTag? getTag(String tagId) => _repository.getTag(tagId);
  List<TaxonomyGroup> getRootGroups() => _repository.getRootGroups();
  List<TaxonomyGroup> getChildGroups(String parentId) =>
      _repository.getChildGroups(parentId);
  List<TaxonomyTag> getTagsInGroup(String groupId) =>
      _repository.getTagsInGroup(groupId);

  /// Resolved on-disk path of the saved taxonomy file. Used by the
  /// editor's "Open Data Folder" action.
  String? getSavedFilePath() => _repository.getSavedFilePath();

  /// Runs [op] (a mutation that ends in a repo `save()`) and tracks save
  /// outcome on this controller. Returns the operation's result on
  /// success, `null` if a disk failure was caught (the caller treats this
  /// as failure and reads [lastSaveError] for the cause).
  Future<T?> _runWithSaveTracking<T>(Future<T> Function() op) async {
    try {
      final result = await op();
      _lastSavedAt = DateTime.now();
      _lastSaveError = null;
      notifyListeners();
      return result;
    } on Exception catch (e) {
      _lastSaveError = e;
      notifyListeners();
      return null;
    }
  }

  /// Group mutations.

  Future<String?> addGroup({
    required String groupId,
    required String name,
    required String groupExplain,
    String? parentGroupId,
  }) async {
    final id = groupId.trim();
    final n = name.trim();
    if (id.isEmpty || n.isEmpty) return 'Group ID and name are required.';
    final siblings = parentGroupId == null
        ? _repository.getRootGroups()
        : _repository.getChildGroups(parentGroupId);
    final group = TaxonomyGroup(
      groupId: id,
      name: n,
      parentGroupId: parentGroupId,
      displayOrder: siblings.length,
      groupExplain: groupExplain.trim(),
    );
    final result = await _runWithSaveTracking(
      () => _repository.addGroup(group),
    );
    if (result == null) return 'Save failed — see logs.';
    return result ? null : 'Group ID already exists.';
  }

  Future<String?> updateGroup({
    required String oldGroupId,
    required String newGroupId,
    required String name,
    required String groupExplain,
  }) async {
    final newId = newGroupId.trim();
    final n = name.trim();
    if (newId.isEmpty || n.isEmpty) return 'Group ID and name are required.';
    final result = await _runWithSaveTracking<bool>(() async {
      if (newId != oldGroupId) {
        final renamed = await _repository.updateGroupId(oldGroupId, newId);
        if (!renamed) return false;
      }
      final updated = _repository.getGroup(newId);
      if (updated == null) return false;
      updated.name = n;
      updated.groupExplain = groupExplain.trim();
      await _repository.save();
      return true;
    });
    if (result == null) return 'Save failed — see logs.';
    return result ? null : 'Group ID already exists.';
  }

  Future<String?> deleteGroup(String groupId) async {
    if (_repository.getGroup(groupId) == null) return 'Group not found.';
    final result = await _runWithSaveTracking<bool>(() async {
      await _repository.deleteGroup(groupId);
      return true;
    });
    if (result == null) return 'Save failed — see logs.';
    return null;
  }

  Future<String?> moveGroup(String groupId, String? newParentId) async {
    final result = await _runWithSaveTracking(
      () => _repository.moveGroup(groupId, newParentId),
    );
    if (result == null) return 'Save failed — see logs.';
    return result
        ? null
        : 'Cannot drop a group into itself or its descendants.';
  }

  /// Tag mutations.

  Future<String?> addTag({
    required String tagId,
    required String tagName,
    required String tagExplain,
    required List<String> synonyms,
    required String groupId,
    required bool isExclusive,
  }) async {
    final id = tagId.trim();
    final name = tagName.trim();
    if (id.isEmpty || name.isEmpty) return 'Tag ID and name are required.';
    if (_repository.getGroup(groupId) == null) return 'Group not found.';
    final siblings = _repository.getTagsInGroup(groupId);
    final tag = TaxonomyTag(
      tagId: id,
      tagName: name,
      tagExplain: tagExplain.trim(),
      synonyms: synonyms,
      groupId: groupId,
      isExclusive: isExclusive,
      displayOrder: siblings.length,
    );
    final result = await _runWithSaveTracking(() => _repository.addTag(tag));
    if (result == null) return 'Save failed — see logs.';
    return result ? null : 'Tag ID already exists.';
  }

  Future<String?> updateTag({
    required String oldTagId,
    required String newTagId,
    required String tagName,
    required String tagExplain,
    required List<String> synonyms,
    required String groupId,
    required bool isExclusive,
  }) async {
    final newId = newTagId.trim();
    final name = tagName.trim();
    if (newId.isEmpty || name.isEmpty) return 'Tag ID and name are required.';
    final result = await _runWithSaveTracking<String?>(() async {
      if (newId != oldTagId) {
        final renamed = await _repository.updateTagId(oldTagId, newId);
        if (!renamed) return 'Tag ID already exists.';
      }
      final tag = _repository.getTag(newId);
      if (tag == null) return 'Tag not found.';
      if (groupId != tag.groupId) {
        final moved = await _repository.moveTag(newId, groupId);
        if (!moved) return 'Target group not found.';
      }
      tag.tagName = name;
      tag.tagExplain = tagExplain.trim();
      tag.synonyms = synonyms;
      tag.isExclusive = isExclusive;
      await _repository.save();
      return null;
    });
    if (result == null && _lastSaveError != null) {
      return 'Save failed — see logs.';
    }
    return result;
  }

  Future<String?> deleteTag(String tagId) async {
    if (_repository.getTag(tagId) == null) return 'Tag not found.';
    final result = await _runWithSaveTracking<bool>(() async {
      await _repository.deleteTag(tagId);
      return true;
    });
    if (result == null) return 'Save failed — see logs.';
    return null;
  }

  Future<String?> moveTag(String tagId, String newGroupId) async {
    final result = await _runWithSaveTracking(
      () => _repository.moveTag(tagId, newGroupId),
    );
    if (result == null) return 'Save failed — see logs.';
    return result ? null : 'Target group not found.';
  }
}
