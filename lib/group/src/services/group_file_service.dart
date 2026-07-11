import 'package:cardwave/group/src/models/chat_group.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/repositories/group_repository.dart';
import 'package:cardwave/group/src/services/group_chat_service.dart'
    show GroupChatService;
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/foundation.dart';

/// CRUD service for [GroupFile]. One responsibility: managing the persistent
/// identity of a group (its members, its name). Not responsible for the
/// group's chat sessions — that lives in [GroupChatService].
class GroupFileService extends ChangeNotifier {
  GroupFileService({required this.groupRepository});
  final GroupRepository groupRepository;

  Future<GroupFile?> loadGroup(String groupId) =>
      groupRepository.loadGroup(groupId);

  /// Loads the group with [groupId], or creates and persists a fresh empty
  /// group with that id if no file exists.
  Future<GroupFile> loadOrCreate(
    String groupId, {
    String? name,
  }) async {
    final existing = await groupRepository.loadGroup(groupId);
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = GroupFile(
      group: ChatGroup(id: groupId, name: name ?? t.group.groupFileService.defaultGroupName),
      created: now,
      lastActive: now,
    );
    await groupRepository.saveGroup(fresh);
    return fresh;
  }

  Future<void> saveGroup(GroupFile file) async {
    file.lastActive = DateTime.now().millisecondsSinceEpoch;
    await groupRepository.saveGroup(file);
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    await groupRepository.deleteGroup(groupId);
    notifyListeners();
  }

  Future<List<GroupFile>> listGroups() => groupRepository.listGroups();
}
