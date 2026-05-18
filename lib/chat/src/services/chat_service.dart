import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/chat_swipe.dart';
import 'package:cardwave/chat/src/repositories/chat_repository.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class ActiveChatNotifier extends ValueNotifier<ChatSession?> {
  ActiveChatNotifier() : super(null);

  void notify() {
    notifyListeners();
  }
}

class ChatService extends ChangeNotifier {
  ChatService({
    required this.chatRepository,
    required this.settingsService,
    required this.characterService,
    required this.pureHelpers,
  }) {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        // TODO(qcheck): consider an exhaustive switch(state) here later (the lint
        // suggests it); not done now to avoid touching the background save-
        // flush path.
        // ignore: qcheck/prefer_switch_with_enums
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) {
          _flushPendingSaves();
        }
      },
    );
  }
  final ChatRepository chatRepository;
  final SettingsService settingsService;
  final CharacterService characterService;
  final LlmPureHelpers pureHelpers;
  final LoggingService _log = LoggingService();

  final Map<String, _PendingSave> _pendingSaves = {};
  AppLifecycleListener? _lifecycleListener;

  final ActiveChatNotifier activeChat = ActiveChatNotifier();

  void setActiveChat(ChatSession? session) {
    activeChat.value = session;
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _flushPendingSaves();
    activeChat.dispose();
    super.dispose();
  }

  void _flushPendingSaves() {
    for (final pending in _pendingSaves.values) {
      pending.timer.cancel();
      unawaited(chatRepository.saveChat(pending.file, pending.session));
    }
    _pendingSaves.clear();
  }

  Future<ChatIndex> getChatsForCharacter(
    CharacterFile file, {
    VoidCallback? onRebuild,
  }) {
    return chatRepository.getChatsForCharacter(
      file,
      onRebuild: onRebuild,
    );
  }

  Future<ChatSession?> getChat(CharacterFile file, String chatId) {
    return chatRepository.getChat(file, chatId);
  }

  Future<ChatSession?> createNewChatForCharacter(
    CharacterFile file, {
    bool isAssistant = false,
  }) async {
    final settings = settingsService.settings;
    final profiles = settings.providerConfigs;
    final defaultConfigId =
        settings.domainPresetIds[LlmProviderDomainEnum.chat];

    _log.info(
      'createNewChatForCharacter: file="${file.card.name}" '
      'isAssistant=$isAssistant presetId=${defaultConfigId ?? '(none)'} '
      'firstMesLen=${file.card.firstMes.length} '
      'altGreetings=${file.card.alternateGreetings.length} '
      'profilesCount=${profiles.length}',
    );

    if (defaultConfigId == null) {
      _log.warning(
        'createNewChatForCharacter: no preset configured '
        '(isAssistant=$isAssistant). domainPresetIds=${settings.domainPresetIds}',
      );
      return null;
    }

    final preset = profiles
        .expand((p) => p.allPresets)
        .where((c) => c.id == defaultConfigId)
        .firstOrNull;
    if (preset == null) {
      _log.error(
        'createNewChatForCharacter: preset not found in profiles '
        'presetId=$defaultConfigId',
      );
      return null;
    }
    final newChat = await createChat(file, preset, isAssistant: isAssistant);
    newChat.name = file.card.name;
    await updateChat(file, newChat);
    _log.info(
      'createNewChatForCharacter: created chat id=${newChat.id} '
      'messages=${newChat.messages.length}',
    );
    return newChat;
  }

  Future<ChatSession?> getLatestChatForCharacterOrNew(
    CharacterFile file, {
    VoidCallback? onRebuild,
    bool isAssistant = false,
  }) async {
    final chat = await chatRepository.getLatestChatForCharacter(
      file,
      isAssistant: isAssistant,
      onRebuild: onRebuild,
    );

    if (chat != null) {
      return chat;
    }
    return createNewChatForCharacter(file, isAssistant: isAssistant);
  }

  Future<ChatSession> createChat(
    CharacterFile file,
    LlmPresetConfig config, {
    bool isAssistant = false,
  }) async {
    _log.info(
      'createChat: enter file="${file.card.name}" '
      'presetId=${config.id} firstMesLen=${file.card.firstMes.length}',
    );

    final fileName = p.posix.basenameWithoutExtension(file.appCardImagePath);
    final id = UtilsApp.generateId(file.card.name);

    final activePersona = settingsService.settings.activePersona;
    final localVariables = <String, String>{};
    final globalVariables = settingsService.settings.globalVariables;

    final isNsfwDetected = file.card.tags.any(
      (tag) => AppConstants.nsfwTriggers.contains(tag.toLowerCase()),
    );

    final messages = <ChatMessage>[];

    if (file.card.firstMes.isEmpty) {
      _log.warning(
        'createChat: firstMes IS EMPTY for file="${file.card.name}" — '
        'new chat will have no greeting message',
      );
    }

    if (file.card.firstMes.isNotEmpty) {
      final processedFirstMes = UtilsPrompt.replacePlaceholders(
        file.card.firstMes,
        charName: (file.card.nickname?.isNotEmpty == true)
            ? file.card.nickname!
            : file.card.name,
        userName: activePersona.name,
        localVariables: localVariables,
        globalVariables: globalVariables,
        trackingId: 'firstMes',
      );
      final firstMesTokenCount = await UtilsLlm.countTokens(processedFirstMes);
      final swipes = <ChatSwipe>[
        ChatSwipe(content: processedFirstMes, tokenCount: firstMesTokenCount),
      ];

      var greetingIndex = 0;
      for (final greeting in file.card.alternateGreetings) {
        if (greeting.isNotEmpty) {
          swipes.add(
            ChatSwipe(
              content: UtilsPrompt.replacePlaceholders(
                greeting,
                charName: (file.card.nickname?.isNotEmpty == true)
                    ? file.card.nickname!
                    : file.card.name,
                userName: activePersona.name,
                localVariables: localVariables,
                globalVariables: globalVariables,
                trackingId: 'altGreeting_$greetingIndex',
              ),
            ),
          );
          greetingIndex++;
        }
      }

      messages.add(
        ChatMessage(
          role: ChatRoleEnum.assistant,
          swipes: swipes,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _log.info(
        'createChat: built greeting message with ${swipes.length} swipe(s)',
      );
    }

    final session = ChatSession(
      id: id,
      ownerId: fileName,
      modelPresetId: config.id,
      created: DateTime.now().millisecondsSinceEpoch,
      lastActive: DateTime.now().millisecondsSinceEpoch,
      name: 'New Chat',
      isStreaming: true,
      isNsfw: isNsfwDetected,
      isScenario: false,
      removeTrailingSentences: true,
      personaName: activePersona.name,
      personaDescription: activePersona.description,
      activeStickies: {},
      activeCooldowns: {},
      localVariables: localVariables,
      messages: messages,
      isAssistant: isAssistant,
    );

    _log.info(
      'createChat: returning session id=$id '
      'messagesCount=${messages.length}',
    );
    notifyListeners();
    return session;
  }

  String trimTrailingParagraph(String text) => UtilsAppTextTrim.trim(text);

  Future<void> trimLastMessageTrailingParagraph(
    CharacterFile characterFile,
    ChatSession chat,
  ) async {
    if (chat.messages.isEmpty) return;

    final lastMsg = chat.messages.last;
    if (lastMsg.role == ChatRoleEnum.assistant && lastMsg.content.isNotEmpty) {
      final trimmed = trimTrailingParagraph(lastMsg.content);
      if (trimmed != lastMsg.content) {
        lastMsg.content = trimmed;
        lastMsg.tokenCount = await UtilsLlm.countTokens(lastMsg.content);
        await updateChat(characterFile, chat);
      }
    }
  }

  // TODO(qcheck): this returns Future<void> but never awaits — audit whether the
  // `await` / `unawaited(...)` at its call sites is meaningful or vestigial,
  // then decide whether to make it `void`.
  // ignore: qcheck/avoid_unnecessary_futures
  Future<void> updateChat(CharacterFile file, ChatSession session) async {
    session.lastActive = DateTime.now().millisecondsSinceEpoch;

    final chatId = session.id;
    _pendingSaves[chatId]?.timer.cancel();

    final timer = Timer(const Duration(milliseconds: 500), () {
      _pendingSaves.remove(chatId);
      unawaited(chatRepository.saveChat(file, session));
    });

    _pendingSaves[chatId] = _PendingSave(file, session, timer);

    if (activeChat.value?.id == session.id) {
      activeChat.notify();
    } else {
      notifyListeners();
    }
  }

  Future<void> regenerateGreetings(
    ChatSession session,
    CharacterFile file,
  ) async {
    var oldSwipeIndex = 0;
    if (session.messages.isNotEmpty) {
      oldSwipeIndex = session.messages.first.swipeIndex;
    }

    session.messages.clear();

    if (file.card.firstMes.isNotEmpty) {
      final activePersona = settingsService.settings.activePersona;
      final localVariables = session.localVariables;
      final globalVariables = settingsService.settings.globalVariables;
      final processedFirstMes = UtilsPrompt.replacePlaceholders(
        file.card.firstMes,
        charName: (file.card.nickname?.isNotEmpty == true)
            ? file.card.nickname!
            : file.card.name,
        userName: activePersona.name,
        localVariables: localVariables,
        globalVariables: globalVariables,
        trackingId: 'firstMes',
      );
      final swipes = <String>[processedFirstMes];
      var greetingIndex = 0;
      for (final greeting in file.card.alternateGreetings) {
        if (greeting.isNotEmpty) {
          swipes.add(
            UtilsPrompt.replacePlaceholders(
              greeting,
              charName: (file.card.nickname?.isNotEmpty == true)
                  ? file.card.nickname!
                  : file.card.name,
              userName: activePersona.name,
              localVariables: localVariables,
              globalVariables: globalVariables,
              trackingId: 'altGreeting_$greetingIndex',
            ),
          );
          greetingIndex++;
        }
      }

      var newSwipeIndex = oldSwipeIndex;
      if (newSwipeIndex >= swipes.length) {
        newSwipeIndex = swipes.isNotEmpty ? swipes.length - 1 : 0;
      }

      // Token count for the first message (main greeting)
      final firstMesTokenCount = await UtilsLlm.countTokens(processedFirstMes);

      final newMessage = ChatMessage(
        role: ChatRoleEnum.assistant,
        swipes: [
          ChatSwipe(content: processedFirstMes, tokenCount: firstMesTokenCount),
          ...swipes.skip(1).map((s) => ChatSwipe(content: s)),
        ],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      newMessage.swipeIndex = newSwipeIndex;
      session.messages.add(newMessage);
    }

    await updateChat(file, session);
  }

  Future<void> deleteChat(CharacterFile file, String chatId) async {
    _pendingSaves[chatId]?.timer.cancel();
    _pendingSaves.remove(chatId);

    await chatRepository.deleteChat(file, chatId);

    try {
      final chats = await chatRepository.getChatsForCharacter(file);
      if (chats.entries.isEmpty) {
        file.appCardTimestampLastChatted = null;
        await characterService.saveJsonInCacheNow(file);
      }
    } on Exception catch (e, stackTrace) {
      // Best-effort timestamp update — silent failure means the grid keeps
      // showing this character as recently chatted until something else
      // touches its file (which may be never if user doesn't reopen it).
      _log.warning(
        'Failed to clear lastChatted timestamp after deleting chat $chatId',
        e,
        stackTrace,
      );
    }

    notifyListeners();
  }
}

class _PendingSave {
  const _PendingSave(this.file, this.session, this.timer);
  final CharacterFile file;
  final ChatSession session;
  final Timer timer;
}
