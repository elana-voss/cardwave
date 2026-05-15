import 'dart:convert';

import 'package:cardwave/character/src/models/taxonomy_data.dart';
import 'package:cardwave/character/src/models/taxonomy_group.dart';
import 'package:cardwave/character/src/models/taxonomy_tag.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:schemantic/schemantic.dart';

/// Holds the taxonomy in memory and persists user edits.
///
/// Layout: a flat list of [TaxonomyGroup] (forming a tree via
/// [TaxonomyGroup.parentGroupId]) plus a flat list of [TaxonomyTag] whose
/// [TaxonomyTag.groupId] points at the most specific group it belongs to.
/// Tags are flat within their group; all hierarchy lives in groups.
///
/// **Load order:** if the user-editable copy at
/// `<appData>/taxonomyFileName` exists, that wins. Otherwise the bundled
/// seed at [AppConstants.taxonomyAssetPath] is loaded. Every mutation calls
/// [save] write-through, so subsequent launches see the user copy.
///
/// Save errors are logged AND rethrown — the editor controller catches at
/// the call site to surface them in the UI. Save state (last-saved time,
/// last error) lives on the controller, not here, so this class can stay
/// a plain `Provider<TaxonomyRepository>` value.
class TaxonomyRepository {
  TaxonomyRepository({required this.loggingService});
  final LoggingService loggingService;

  final Map<String, TaxonomyGroup> _groups = {};
  final Map<String, TaxonomyTag> _tags = {};

  Future<void> init() async {
    try {
      final exists = await AppStorage.instance.fileExists(
        StorageDomainEnum.settings,
        AppConstants.taxonomyFileName,
      );
      final raw = exists
          ? await AppStorage.instance.readString(
              StorageDomainEnum.settings,
              AppConstants.taxonomyFileName,
            )
          : await rootBundle.loadString(AppConstants.taxonomyAssetPath);
      hydrateFromJson(raw);
    } on Exception catch (e, st) {
      loggingService.error('Failed to load taxonomy', e, st);
    }
  }

  /// Replaces in-memory state with the contents of [raw] (a taxonomy
  /// JSON string). Called by [init] after picking the user/asset copy,
  /// and exposed for tests that seed the repo without going through
  /// AppStorage / rootBundle.
  void hydrateFromJson(String raw) {
    final data = TaxonomyData.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _groups.clear();
    _tags.clear();
    for (final g in data.groups) {
      _groups[g.groupId] = g;
    }
    for (final t in data.tags) {
      _tags[t.tagId] = t;
    }
  }

  /// Read access

  TaxonomyGroup? getGroup(String groupId) => _groups[groupId];

  TaxonomyTag? getTag(String tagId) => _tags[tagId];

  /// All top-level groups (parentGroupId == null), sorted by displayOrder.
  List<TaxonomyGroup> getRootGroups() {
    return _groups.values.where((g) => g.parentGroupId == null).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Direct children of [parentGroupId], sorted by displayOrder.
  List<TaxonomyGroup> getChildGroups(String parentGroupId) {
    return _groups.values
        .where((g) => g.parentGroupId == parentGroupId)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Tags directly attached to [groupId] (not its descendants), sorted by
  /// displayOrder.
  List<TaxonomyTag> getTagsInGroup(String groupId) {
    return _tags.values.where((t) => t.groupId == groupId).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Group mutations — every method below calls [save] write-through.

  /// Adds [group]. Caller is responsible for picking a unique groupId and
  /// the desired displayOrder. Returns false if the id already exists.
  Future<bool> addGroup(TaxonomyGroup group) async {
    if (_groups.containsKey(group.groupId)) return false;
    _groups[group.groupId] = group;
    await save();
    return true;
  }

  /// Deletes [groupId] and every group/tag in its subtree. Cascades because
  /// orphaning would leave broken references; the editor confirms with the
  /// user before calling this.
  Future<void> deleteGroup(String groupId) async {
    final descendants = _collectDescendantGroupIds(groupId)..add(groupId);
    _tags.removeWhere((_, t) => descendants.contains(t.groupId));
    descendants.forEach(_groups.remove);
    await save();
  }

  Set<String> _collectDescendantGroupIds(String groupId) {
    final result = <String>{};
    final stack = <String>[groupId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final g in _groups.values) {
        if (g.parentGroupId == current && result.add(g.groupId)) {
          stack.add(g.groupId);
        }
      }
    }
    return result;
  }

  /// Renames a group. Updates the parentGroupId pointer on every child group
  /// and the groupId pointer on every tag in that group. Returns false if
  /// [newId] is already taken; true on success or no-op when ids match.
  Future<bool> updateGroupId(String oldId, String newId) async {
    if (oldId == newId) return true;
    if (_groups.containsKey(newId)) return false;
    final group = _groups.remove(oldId);
    if (group == null) return false;
    group.groupId = newId;
    _groups[newId] = group;
    for (final g in _groups.values) {
      if (g.parentGroupId == oldId) g.parentGroupId = newId;
    }
    for (final t in _tags.values) {
      if (t.groupId == oldId) t.groupId = newId;
    }
    await save();
    return true;
  }

  /// Reparents [groupId] under [newParentId] (null = top-level). Returns
  /// false on cycle (target is the group itself or one of its descendants),
  /// true on success.
  Future<bool> moveGroup(String groupId, String? newParentId) async {
    final group = _groups[groupId];
    if (group == null) return false;
    if (newParentId != null) {
      if (newParentId == groupId) return false;
      if (_collectDescendantGroupIds(groupId).contains(newParentId)) {
        return false;
      }
      if (!_groups.containsKey(newParentId)) return false;
    }
    group.parentGroupId = newParentId;
    await save();
    return true;
  }

  /// Reorders [groupId] within its parent's children. The caller passes the
  /// desired final displayOrder index; siblings are renumbered to make room.
  Future<void> reorderGroup(String groupId, int newIndex) async {
    final group = _groups[groupId];
    if (group == null) return;
    final siblings =
        _groups.values
            .where((g) => g.parentGroupId == group.parentGroupId)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    siblings.remove(group);
    final clamped = newIndex.clamp(0, siblings.length);
    siblings.insert(clamped, group);
    for (var i = 0; i < siblings.length; i++) {
      siblings[i].displayOrder = i;
    }
    await save();
  }

  /// Tag mutations — same write-through pattern.

  Future<bool> addTag(TaxonomyTag tag) async {
    if (_tags.containsKey(tag.tagId)) return false;
    if (!_groups.containsKey(tag.groupId)) return false;
    _tags[tag.tagId] = tag;
    await save();
    return true;
  }

  Future<void> deleteTag(String tagId) async {
    _tags.remove(tagId);
    await save();
  }

  /// Renames a tag id. Returns false if [newId] is taken; true on success
  /// or when [oldId] equals [newId].
  Future<bool> updateTagId(String oldId, String newId) async {
    if (oldId == newId) return true;
    if (_tags.containsKey(newId)) return false;
    final tag = _tags.remove(oldId);
    if (tag == null) return false;
    tag.tagId = newId;
    _tags[newId] = tag;
    await save();
    return true;
  }

  /// Moves a tag to a different group. Returns false if [newGroupId]
  /// doesn't exist; true on success.
  Future<bool> moveTag(String tagId, String newGroupId) async {
    final tag = _tags[tagId];
    if (tag == null) return false;
    if (!_groups.containsKey(newGroupId)) return false;
    tag.groupId = newGroupId;
    await save();
    return true;
  }

  /// Reorders [tagId] among its sibling tags within the same group.
  Future<void> reorderTag(String tagId, int newIndex) async {
    final tag = _tags[tagId];
    if (tag == null) return;
    final siblings = getTagsInGroup(tag.groupId);
    siblings.remove(tag);
    final clamped = newIndex.clamp(0, siblings.length);
    siblings.insert(clamped, tag);
    for (var i = 0; i < siblings.length; i++) {
      siblings[i].displayOrder = i;
    }
    await save();
  }

  /// Persists the in-memory state to `<appData>/taxonomy.json`. Called
  /// write-through after every mutation so editor edits survive restart.
  Future<void> save() async {
    try {
      final groups = _groups.values.toList()
        ..sort((a, b) {
          final byParent = (a.parentGroupId ?? '').compareTo(
            b.parentGroupId ?? '',
          );
          if (byParent != 0) return byParent;
          return a.displayOrder.compareTo(b.displayOrder);
        });
      final tags = _tags.values.toList()
        ..sort((a, b) {
          final byGroup = a.groupId.compareTo(b.groupId);
          if (byGroup != 0) return byGroup;
          return a.displayOrder.compareTo(b.displayOrder);
        });
      final data = TaxonomyData(groups: groups, tags: tags);
      const encoder = JsonEncoder.withIndent('  ');
      await AppStorage.instance.writeString(
        StorageDomainEnum.settings,
        AppConstants.taxonomyFileName,
        encoder.convert(data.toJson()),
      );
    } on Exception catch (e, st) {
      loggingService.error('Failed to save taxonomy', e, st);
      rethrow;
    }
  }

  /// Returns the resolved on-disk path of the saved taxonomy file (or null
  /// on platforms where absolute paths have no meaning, e.g. web). Used by
  /// the editor's "Open data folder" affordance.
  String? getSavedFilePath() {
    return AppStorage.instance.absolutePathFor(
      StorageDomainEnum.settings,
      AppConstants.taxonomyFileName,
    );
  }

  /// Renders the taxonomy for the LLM auto-tagger prompt. Walks the group
  /// tree depth-first, indents by depth, lists each group's tags with an
  /// `(EXCLUSIVE)` marker on the exclusive ones. Group headers are
  /// organizational only — see `assets/prompts/taxonomy_tagging.txt` for
  /// the leaf-only output rule the model is told to follow.
  ///
  /// When a group or tag has a non-empty explanation, it is rendered on
  /// the line right below it, prefixed with `> `, indented one level deeper.
  ///
  /// Example output:
  /// ```text
  /// [Format]
  ///   > What kind of card this is — single character, multi-character group, etc.
  ///   fmt_character - Single-character (EXCLUSIVE)
  ///   fmt_world - Lorebook (EXCLUSIVE)
  ///     > World-information document — defines setting lore.
  ///
  /// [Source Material]
  ///   > Where the character or world comes from.
  ///   src_oc - Original Character (EXCLUSIVE)
  ///   [Established IP]
  ///     > Existing intellectual property — books, film, anime, games.
  ///     src_ip_books - Books / Literature
  /// ```
  String getLlmPromptString() {
    final buffer = StringBuffer();
    for (final root in getRootGroups()) {
      _renderGroup(buffer, root, 0);
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  void _renderGroup(StringBuffer buffer, TaxonomyGroup group, int depth) {
    final indent = '  ' * depth;
    buffer.writeln('$indent[${group.name}]');
    if (group.groupExplain.isNotEmpty) {
      buffer.writeln('$indent  > ${group.groupExplain}');
    }
    for (final tag in getTagsInGroup(group.groupId)) {
      final syn = tag.synonyms.isNotEmpty
          ? ' (${tag.synonyms.join(", ")})'
          : '';
      final excl = tag.isExclusive ? ' (EXCLUSIVE)' : '';
      buffer.writeln('$indent  ${tag.tagId} - ${tag.tagName}$syn$excl');
      if (tag.tagExplain.isNotEmpty) {
        buffer.writeln('$indent    > ${tag.tagExplain}');
      }
    }
    for (final child in getChildGroups(group.groupId)) {
      _renderGroup(buffer, child, depth + 1);
    }
  }

  /// Builds the JSON-schema the auto-tagger constrains the system-domain
  /// LLM's reply to. Pure-parent groups (no direct tags) emit no fields.
  /// Schema is rebuilt per call so editor edits flow through with no
  /// cache invalidation. Strict mode (`additionalProperties: false`,
  /// every key in `required`) — required by OpenAI's strict
  /// structured-output mode and harmless on Anthropic / Google.
  ///
  /// Each property carries the group's `groupExplain` (or its display
  /// name when empty) as the JSON-Schema `description`, reinforcing the
  /// prompt-string guidance at the structured-output layer.
  SchemanticType<Map<String, dynamic>> buildAutoTagSchema() {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final group in _groups.values) {
      final tagsInGroup = getTagsInGroup(group.groupId);
      final exclusiveIds = tagsInGroup
          .where((t) => t.isExclusive)
          .map((t) => t.tagId)
          .toList();
      final flagIds = tagsInGroup
          .where((t) => !t.isExclusive)
          .map((t) => t.tagId)
          .toList();
      final description = group.groupExplain.isNotEmpty
          ? group.groupExplain
          : group.name;
      if (exclusiveIds.isNotEmpty) {
        final key = '${group.groupId}_exclusive';
        properties[key] = <String, Object?>{
          'description': description,
          'type': ['string', 'null'],
          'enum': [...exclusiveIds, null],
        };
        required.add(key);
      }
      if (flagIds.isNotEmpty) {
        final key = '${group.groupId}_flags';
        properties[key] = <String, Object?>{
          'description': description,
          'type': 'array',
          'items': <String, Object?>{'type': 'string', 'enum': flagIds},
        };
        required.add(key);
      }
    }
    final schema = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': required,
      'properties': properties,
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }
}
