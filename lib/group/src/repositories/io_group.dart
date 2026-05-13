import 'dart:convert';

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:path/path.dart' as p;

/// Raw IO for [GroupFile]s.
///
/// Each group owns a subfolder under [groupsFolder]:
///   `<groupsFolder>/<groupId>/group.json`    ← definition
///   `<groupsFolder>/<groupId>/chats/...`     ← sessions + media (owned by
///                                              [GroupChatService] / [IOChat])
///
/// Listing enumerates subdirectories and reads each `group.json`; deletion
/// removes the whole `<groupId>/` subtree so chats/media go with it.
class IOGroup {
  const IOGroup({required this.loggingService, required this.appStorage});
  static const String _groupFileName = 'group.json';

  final LoggingService loggingService;
  final AppStorage appStorage;

  String _folderFor(String groupsFolder, String groupId) =>
      p.posix.join(groupsFolder, groupId);

  String _pathFor(String groupsFolder, String groupId) =>
      p.posix.join(_folderFor(groupsFolder, groupId), _groupFileName);

  Future<GroupFile?> loadGroup(String groupsFolder, String groupId) async {
    final filePath = _pathFor(groupsFolder, groupId);
    if (!await appStorage.fileExists(StorageDomainEnum.cards, filePath)) {
      return null;
    }
    try {
      final content = await appStorage.readString(
        StorageDomainEnum.cards,
        filePath,
      );
      final json = jsonDecode(content) as Map<String, dynamic>;
      return GroupFile.fromJson(json);
    } on Exception catch (e) {
      loggingService.error('Error loading group $groupId: $e');
      return null;
    }
  }

  Future<void> saveGroup(String groupsFolder, GroupFile file) async {
    final filePath = _pathFor(groupsFolder, file.id);
    final jsonString = jsonEncode(file.toJson());
    await appStorage.writeString(StorageDomainEnum.cards, filePath, jsonString);
  }

  /// Deletes the entire `<groupsFolder>/<groupId>/` subtree — definition,
  /// chats, and any media sidecars. A single recursive delete keeps the group
  /// folder self-contained; callers no longer need to clear chats separately.
  Future<void> deleteGroup(String groupsFolder, String groupId) async {
    final folder = _folderFor(groupsFolder, groupId);
    if (await appStorage.directoryExists(StorageDomainEnum.cards, folder)) {
      await appStorage.deleteDirectory(StorageDomainEnum.cards, folder);
    }
  }

  Future<List<GroupFile>> listGroups(String groupsFolder) async {
    if (!await appStorage.directoryExists(
      StorageDomainEnum.cards,
      groupsFolder,
    )) {
      return [];
    }
    final filePaths = await appStorage.listDirectory(
      StorageDomainEnum.cards,
      groupsFolder,
      extensions: ['.json'],
      recursive: true,
    );
    final results = <GroupFile>[];
    for (final filePath in filePaths) {
      if (p.posix.basename(filePath) != _groupFileName) continue;
      try {
        final content = await appStorage.readString(
          StorageDomainEnum.cards,
          filePath,
        );
        final json = jsonDecode(content) as Map<String, dynamic>;
        results.add(GroupFile.fromJson(json));
      } on Exception catch (e) {
        loggingService.error('Error loading group $filePath: $e');
      }
    }
    results.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    return results;
  }
}
