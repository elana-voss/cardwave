import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/chat_group.dart' show ChatGroup;
import 'package:cardwave/group/src/models/group_data.dart' show GroupData;
import 'package:cardwave/group/src/models/group_file.dart' show GroupFile;
import 'package:cardwave/group/src/services/group_file_service.dart'
    show GroupFileService;
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// Persistence for group [ChatSession]s. One responsibility: reading and
/// writing the ChatSession files for a given group. Does NOT manage the
/// [GroupFile]/[ChatGroup] identity — that lives in [GroupFileService].
///
/// Storage layout: `customCacheGroupPath/<groupId>/chats/<sessionId>/session.json`.
/// Chats live in a `chats/` subfolder of the group's own folder so a group's
/// definition and sessions form a single deletable subtree.
class GroupChatService extends ChangeNotifier {
  GroupChatService({required IOChat ioChat}) : _ioChat = ioChat {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        // ignore: qcheck/prefer_switch_with_enums
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) {
          unawaited(_flushPendingSaves());
        }
      },
      // Desktop window close: persist pending group-chat saves before exit,
      // matching ChatService. The paused/hidden path stays fire-and-forget.
      onExitRequested: () async {
        await _flushPendingSaves();
        return AppExitResponse.exit;
      },
    );
  }
  static const String _chatsSubfolder = 'chats';

  final IOChat _ioChat;
  final Map<String, _PendingGroupSave> _pendingSaves = {};
  AppLifecycleListener? _lifecycleListener;

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    unawaited(_flushPendingSaves());
    super.dispose();
  }

  /// Fires every pending debounced save and awaits them all. Awaited by
  /// `onExitRequested`; dispose and the paused/hidden path may ignore the
  /// returned future.
  Future<void> _flushPendingSaves() async {
    final futures = <Future<void>>[];
    for (final pending in _pendingSaves.values) {
      pending.timer.cancel();
      futures.add(
        _ioChat.saveChat(_folderFor(pending.groupId), pending.session),
      );
    }
    _pendingSaves.clear();
    await Future.wait(futures);
  }

  /// Single source of truth for the chats subfolder of a group. Reused by
  /// the group chat controller when it needs to derive sibling paths (e.g.
  /// generated-image storage) so the "chats live under the group" invariant
  /// lives in one place.
  static String chatsFolderFor(String groupId) =>
      p.posix.join(AppConstants.customCacheGroupPath, groupId, _chatsSubfolder);

  String _folderFor(String groupId) => chatsFolderFor(groupId);

  /// Builds an empty [ChatSession] for a group. Groups have multiple
  /// characters with no single firstMes to project, so the session starts
  /// with no messages — first activation fills the conversation.
  /// Caller persists via [updateChat] or [flushChat].
  ChatSession createChat({
    required GroupFile groupFile,
    required String chatPresetId,
    required String userName,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ChatSession(
      id: 'group_$now',
      ownerId: groupFile.id,
      modelPresetId: chatPresetId,
      created: now,
      lastActive: now,
      name: t.group.groupChatPage.defaultGroupName,
      isStreaming: true,
      isNsfw: false,
      isScenario: false,
      removeTrailingSentences: false,
      personaName: userName,
      personaDescription: '',
      activeStickies: {},
      activeCooldowns: {},
      localVariables: {},
      messages: [],
      groupData: GroupData(),
    );
  }

  Future<ChatSession?> getLatestChatForGroup(String groupId) =>
      _ioChat.getLatestChat(_folderFor(groupId));

  Future<ChatSession?> getChat(String groupId, String chatId) =>
      _ioChat.getChat(_folderFor(groupId), chatId);

  /// Debounced save, matching the 1:1 `ChatService.updateChat` pattern.
  // TODO(qcheck): see ChatService.updateChat — same Future<void>-but-never-awaits note.
  // ignore: qcheck/avoid_unnecessary_futures
  Future<void> updateChat(String groupId, ChatSession session) async {
    session.lastActive = DateTime.now().millisecondsSinceEpoch;
    final chatId = session.id;
    _pendingSaves[chatId]?.timer.cancel();
    final timer = Timer(const Duration(milliseconds: 500), () {
      _pendingSaves.remove(chatId);
      unawaited(_ioChat.saveChat(_folderFor(groupId), session));
    });
    _pendingSaves[chatId] = _PendingGroupSave(groupId, session, timer);
    notifyListeners();
  }

  /// Immediate save, bypassing the debounce window. Used on dispose or
  /// when the caller cannot afford the 500ms delay.
  Future<void> flushChat(String groupId, ChatSession session) async {
    _pendingSaves[session.id]?.timer.cancel();
    _pendingSaves.remove(session.id);
    session.lastActive = DateTime.now().millisecondsSinceEpoch;
    await _ioChat.saveChat(_folderFor(groupId), session);
  }

  Future<void> deleteChat(String groupId, String chatId) async {
    _pendingSaves[chatId]?.timer.cancel();
    _pendingSaves.remove(chatId);
    await _ioChat.deleteChat(_folderFor(groupId), chatId);
    notifyListeners();
  }

  Future<void> deleteAllChatsForGroup(String groupId) async {
    await _ioChat.deleteAllChats(_folderFor(groupId));
    notifyListeners();
  }
}

/// A debounced group-chat save waiting to fire: the [groupId] its session
/// belongs to (needed to resolve the storage folder on a flush) plus the live
/// [session] and its pending [timer].
class _PendingGroupSave {
  const _PendingGroupSave(this.groupId, this.session, this.timer);
  final String groupId;
  final ChatSession session;
  final Timer timer;
}
