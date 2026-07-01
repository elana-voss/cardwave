import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

/// Result of [ChatPageController.promptNewChat]'s "what to do with the current
/// chat?" dialog. Used in place of magic strings so the call site reads as a
/// switch on a typed value.
enum NewChatPromptActionEnum { cancel, deleteCurrent, keepCurrent }

class ChatPageController extends ChangeNotifier {
  ChatPageController({
    required CharacterFile characterFile,
    required this.chatService,
    required this.characterService,
    required this.settingsService,
    this.isAssistant = false,
  }) : characterFile = characterFile {
    unawaited(_init());
    characterService.addListener(_onCharacterUpdated);
  }

  /// For an assistant chat the target card is loaded from disk (async), so it
  /// is swapped in after construction and listeners rebuild once it lands.
  CharacterFile characterFile;
  final ChatService chatService;
  final CharacterService characterService;
  final SettingsService settingsService;
  final bool isAssistant;
  final LoggingService _log = LoggingService();

  ChatSession? _selectedChat;
  bool _isLoading = true;
  bool _isRebuildingIndex = false;
  bool _isDisposed = false;

  ChatSession? get selectedChat => _selectedChat;
  bool get isLoading => _isLoading;
  bool get isRebuildingIndex => _isRebuildingIndex;

  @override
  void dispose() {
    _isDisposed = true;
    characterService.removeListener(_onCharacterUpdated);
    super.dispose();
  }

  Future<void> _init() async {
    if (isAssistant) {
      final resolved = await characterService.resolveAssistantFile();
      if (resolved != null && !_isDisposed) {
        characterFile = resolved;
        notifyListeners();
      }
    }
    await _loadLatestChatOrNew();
  }

  Future<void> _onCharacterUpdated() async {
    if (_selectedChat == null || _isDisposed) return;

    final chat = _selectedChat!;
    final isUntouched =
        chat.messages.isEmpty ||
        (chat.messages.length == 1 &&
            chat.messages.first.role == ChatRoleEnum.assistant);

    if (isUntouched) {
      await chatService.regenerateGreetings(chat, characterFile);
      if (_isDisposed) return;
      notifyListeners();
    }
  }

  /// Validates that the active model preset exists within the available connection profiles.
  /// If the current preset is invalid or missing, it attempts to fall back to the
  /// default preset defined in the user's settings.
  ///
  /// Returns [isValid] indicating if the connection is usable, and [wasHealed] if the preset was modified.
  ({bool wasHealed, bool isValid}) _checkAndHealConnection(ChatSession chat) {
    final profiles = settingsService.settings.providerConfigs;
    if (profiles.isEmpty) return (wasHealed: false, isValid: false);

    final allConfigs = profiles.expand((p) => p.allPresets);
    final hasValidConfig = allConfigs.any((c) => c.id == chat.modelPresetId);

    if (hasValidConfig) return (wasHealed: false, isValid: true);

    final defaultId =
        settingsService.settings.domainPresetIds[LlmProviderDomainEnum.chat];
    if (defaultId != null) {
      final hasDefaultConfig = allConfigs.any((c) => c.id == defaultId);
      if (hasDefaultConfig) {
        chat.modelPresetId = defaultId;
        return (wasHealed: true, isValid: true);
      }
    }
    return (wasHealed: false, isValid: false);
  }

  Future<void> _loadLatestChatOrNew() async {
    // No provider configured: nothing to load with. Skip the attempt
    // entirely — the onboarding banner above the chat already prompts
    // the user to connect an AI. Trying anyway would just log an
    // error for an expected state.
    if (settingsService.settings.domainPresetIds.isEmpty) {
      if (_isDisposed) return;
      _selectedChat = null;
      chatService.setActiveChat(null);
      _isLoading = false;
      _isRebuildingIndex = false;
      notifyListeners();
      return;
    }

    final chat = await chatService.getLatestChatForCharacterOrNew(
      characterFile,
      isAssistant: isAssistant,
      onRebuild: () {
        if (_isDisposed) return;
        _isRebuildingIndex = true;
        notifyListeners();
      },
    );

    if (_isDisposed) return;

    if (chat != null) {
      final connection = _checkAndHealConnection(chat);
      if (!connection.isValid) {
        _log.warning(
          '_loadLatestChatOrNew: connection invalid for chat id=${chat.id} '
          'isAssistant=$isAssistant',
        );
      } else if (connection.wasHealed) {
        await chatService.updateChat(characterFile, chat);
        _log.info(
          '_loadLatestChatOrNew: healed connection for chat id=${chat.id}',
        );
      }
    }

    _selectedChat = chat;
    chatService.setActiveChat(chat);
    _isLoading = false;
    _isRebuildingIndex = false;

    if (chat == null) {
      // Providers exist but chat creation still failed — real problem
      // (assistant lookup failure, preset desync, etc.).
      _log.error(
        '_loadLatestChatOrNew: chat is null after getLatestChatForCharacterOrNew '
        'isAssistant=$isAssistant file="${characterFile.card.name}"',
      );
    }
    notifyListeners();
  }

  Future<void> createNewChat() async {
    final newChat = await chatService.createNewChatForCharacter(characterFile);

    if (_isDisposed) return;

    if (newChat == null) {
      notifyListeners();
    } else {
      final connection = _checkAndHealConnection(newChat);
      if (connection.wasHealed) {
        await chatService.updateChat(characterFile, newChat);
      }
      _selectedChat = newChat;
      chatService.setActiveChat(newChat);
      notifyListeners();
    }
  }

  Future<void> selectChat(String chatId) async {
    final fullChat = await chatService.getChat(characterFile, chatId);
    if (_isDisposed) return;

    if (fullChat != null) {
      final connection = _checkAndHealConnection(fullChat);
      if (connection.wasHealed) {
        await chatService.updateChat(characterFile, fullChat);
      }
      _selectedChat = fullChat;
      chatService.setActiveChat(fullChat);
      notifyListeners();
    }
  }

  void clearSelectedChat() {
    if (_isDisposed) return;
    _selectedChat = null;
    chatService.setActiveChat(null);
    notifyListeners();
  }

  Future<void> promptNewChat(BuildContext context) async {
    if (isAssistant) {
      if (_selectedChat == null) return;
      final confirm = await NavigationService().showConfirmCancelDialog(
        title: 'New Chat',
        message: 'Clear the assistant chat history?',
        confirmText: 'Clear',
        confirmColor: Theme.of(context).colorScheme.error,
      );

      if (_isDisposed) return;

      if (confirm) {
        await chatService.regenerateGreetings(_selectedChat!, characterFile);
        if (_isDisposed) return;
        notifyListeners();
      }
      return;
    }

    if (_selectedChat != null && _selectedChat!.messages.isNotEmpty) {
      final action = await showDialog<NewChatPromptActionEnum>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Chat'),
          content: const Text(
            'Would you like to delete the current chat or keep it in your history?',
          ),
          actions: [
            TextButton(
              key: const Key('dialog-cancel'),
              onPressed: () =>
                  Navigator.pop(context, NewChatPromptActionEnum.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('new-chat-delete-current'),
              onPressed: () =>
                  Navigator.pop(context, NewChatPromptActionEnum.deleteCurrent),
              child: Text(
                'Delete Current',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            FilledButton(
              key: const Key('dialog-confirm'),
              onPressed: () =>
                  Navigator.pop(context, NewChatPromptActionEnum.keepCurrent),
              child: const Text('Keep Current'),
            ),
          ],
        ),
      );

      if (_isDisposed) return;

      switch (action) {
        case null:
        case NewChatPromptActionEnum.cancel:
          return;
        case NewChatPromptActionEnum.deleteCurrent:
          await deleteChat(_selectedChat!.id);
        case NewChatPromptActionEnum.keepCurrent:
          break;
      }
    }

    await createNewChat();
  }

  Future<void> deleteChat(String chatId) async {
    await chatService.deleteChat(characterFile, chatId);
  }

  Future<void> reloadLatestChat() async {
    await _loadLatestChatOrNew();
  }

  void refresh() {
    if (_isDisposed) return;
    notifyListeners();
  }

  Future<void> updateSelectedChatSettings({
    bool? isNsfw,
    bool? isScenario,
    bool? removeTrailingSentences,
    bool? imageNsfwAllowed,
    bool? videoNsfwAllowed,
    bool? imagePromptReview,
    bool? videoPromptReview,
    bool? imageToolPromptReview,
    bool? imageToolSelfieAllowed,
    bool? imageToolSelfieCaptionsAllowed,
    bool? videoToolSendAllowed,
    bool? webToolFetchAllowed,
    bool? webToolFetchReview,
    bool? nameToolSuggestAllowed,
  }) async {
    if (_selectedChat == null || _isDisposed) return;

    if (isNsfw != null) _selectedChat!.isNsfw = isNsfw;
    if (isScenario != null) _selectedChat!.isScenario = isScenario;
    if (removeTrailingSentences != null) {
      _selectedChat!.removeTrailingSentences = removeTrailingSentences;
    }

    // Lazily allocate the session-side media config when the user first
    // toggles any media-related setting in this chat.
    final touchesConfigMedia =
        imageNsfwAllowed != null ||
        videoNsfwAllowed != null ||
        imagePromptReview != null ||
        videoPromptReview != null ||
        imageToolPromptReview != null ||
        imageToolSelfieAllowed != null ||
        imageToolSelfieCaptionsAllowed != null ||
        videoToolSendAllowed != null ||
        webToolFetchAllowed != null ||
        webToolFetchReview != null ||
        nameToolSuggestAllowed != null;
    if (touchesConfigMedia) {
      final cm = _selectedChat!.configMedia ??= ConfigMediaSession();
      if (imageNsfwAllowed != null) cm.imageNsfwAllowed = imageNsfwAllowed;
      if (videoNsfwAllowed != null) cm.videoNsfwAllowed = videoNsfwAllowed;
      if (imagePromptReview != null) cm.imagePromptReview = imagePromptReview;
      if (videoPromptReview != null) cm.videoPromptReview = videoPromptReview;
      if (imageToolPromptReview != null) {
        cm.imageToolPromptReview = imageToolPromptReview;
      }
      if (imageToolSelfieAllowed != null) {
        cm.imageToolSelfieAllowed = imageToolSelfieAllowed;
      }
      if (imageToolSelfieCaptionsAllowed != null) {
        cm.imageToolSelfieCaptionsAllowed = imageToolSelfieCaptionsAllowed;
      }
      if (videoToolSendAllowed != null) {
        cm.videoToolSendAllowed = videoToolSendAllowed;
      }
      if (webToolFetchAllowed != null) {
        cm.webToolFetchAllowed = webToolFetchAllowed;
      }
      if (webToolFetchReview != null) {
        cm.webToolFetchReview = webToolFetchReview;
      }
      if (nameToolSuggestAllowed != null) {
        cm.nameToolSuggestAllowed = nameToolSuggestAllowed;
      }
    }

    await chatService.updateChat(characterFile, _selectedChat!);
    if (_isDisposed) return;
    notifyListeners();
  }

  Future<void> setBackgroundImage(String? path) async {
    if (_selectedChat == null || _isDisposed) return;
    _selectedChat!.backgroundImage = path;
    await chatService.updateChat(characterFile, _selectedChat!);
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Persists the current selected chat session verbatim + notifies. Used
  /// by drawer tiles that mutate `session` fields directly (e.g. TTS voice
  /// / language) and need a save trigger afterwards.
  Future<void> persistActiveChat() async {
    if (_selectedChat == null || _isDisposed) return;
    await chatService.updateChat(characterFile, _selectedChat!);
    if (_isDisposed) return;
    notifyListeners();
  }

  Future<void> trimTrailingParagraph() async {
    if (_selectedChat == null || _isDisposed) return;
    await chatService.trimLastMessageTrailingParagraph(
      characterFile,
      _selectedChat!,
    );
    if (_isDisposed) return;
    notifyListeners();
  }

  void toggleFavorite() {
    if (_isDisposed) return;
    characterFile.card.cardwaveData.isFavorite =
        !characterFile.card.cardwaveData.isFavorite;
    notifyListeners();
    characterService.queueJsonInCacheDebounced(characterFile);
  }
}
