import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/repositories/io_group.dart';
import 'package:cardwave_storage/cardwave_storage.dart';

class GroupRepository {
  GroupRepository({required this.loggingService, required this.appStorage})
    : _ioGroup = IOGroup(
        loggingService: loggingService,
        appStorage: appStorage,
      );
  final LoggingService loggingService;
  final AppStorage appStorage;
  final IOGroup _ioGroup;

  String get _folder => AppConstants.customCacheGroupPath;

  Future<GroupFile?> loadGroup(String groupId) =>
      _ioGroup.loadGroup(_folder, groupId);

  Future<void> saveGroup(GroupFile file) => _ioGroup.saveGroup(_folder, file);

  Future<void> deleteGroup(String groupId) =>
      _ioGroup.deleteGroup(_folder, groupId);

  Future<List<GroupFile>> listGroups() => _ioGroup.listGroups(_folder);
}
