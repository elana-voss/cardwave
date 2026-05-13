import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_media_history.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_video_generation_mixin.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/chat_swipe.dart';
import 'package:cardwave/chat/src/repositories/chat_repository.dart';
import 'package:cardwave/chat/src/services/builtin_tool_app_data.dart';
import 'package:cardwave/chat/src/services/chat_execution_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Adds image-generation orchestration plus the tool-dispatch closure
/// builder to any chat controller.
///
/// The concrete controller supplies the session + target character + save
/// hook; this mixin handles the placeholder lifecycle, builds the
/// primitive [LlmImagePromptRequest] from chat-domain state, drives the
/// (pure) [ImageGenerationService], persists the returned bytes via
/// [AppStorage], and substitutes the result as a markdown image link into
/// the placeholder's content. [buildToolDispatch] returns a closure that
/// runs the tool dispatcher against the in-flight bubble so side-effect
/// tools (selfie) attach to it directly.
mixin ChatImageGenerationMixin
    on BaseChatViewController, ChatVideoGenerationMixin {
  ImageGenerationService get imageGenerationService;
  ChatRepository get imageGenChatRepository;
  SettingsService get imageGenSettingsService;
  ChatSession get imageGenSession;
  CharacterFile? get imageGenTargetCharacter;
  String get imageGenUserName;

  /// Tool dispatcher invoked by [buildToolDispatch] each round of the
  /// manual tool loop. Wired in by the concrete controller's
  /// constructor.
  ToolDispatcher get toolDispatcher;

  /// Directory (relative to the cards storage domain) that holds the chat's
  /// JSON file. Generated images are nested beneath this in a `<chatId>/`
  /// subfolder so they live next to the chat they belong to.
  String get imageGenChatDirectoryPath;

  /// Persists the session after a placeholder is finalised into a real
  /// image message. Called once per successful generation. The
  /// implementation can be async or fire-and-forget; the mixin does not
  /// await.
  void imageGenPersistSession();

  /// Set by the view to show a review dialog. Returns the (possibly edited)
  /// prompt, or `null` to cancel generation.
  Future<String?> Function(String prompt)? onReviewImagePrompt;

  /// Set by the view to show a URL fetch confirmation dialog. Returns
  /// true to allow the fetch, false to deny. Required when the
  /// session's `webToolFetchReview` flag is on; without it, denies by
  /// default (safer than allowing without consent).
  Future<bool> Function(String url, {String? purpose})? onConfirmUrlFetch;

  bool _isGeneratingImage = false;

  bool get isGeneratingImage => _isGeneratingImage;

  /// Runs an image generation, either as a fresh assistant message
  /// (user-triggered via the wand) or attached to an existing message
  /// (tool-triggered, e.g. `send_selfie`).
  ///
  /// - [targetMessage] null: append a new placeholder message and finalise it
  ///   into the image-bearing assistant reply (current user-flow behaviour).
  /// - [targetMessage] non-null: skip placeholder creation and mutate the
  ///   passed message in-place. Used by the tool dispatcher when the model
  ///   emitted a tool call as part of its streamed reply — the message
  ///   already exists; we just attach the image, set the caption, and clear
  ///   the placeholder flag.
  ///
  /// [caption] is propagated through to the image-gen service (which appends
  /// it verbatim to the system-model output as a "render this on the image"
  /// instruction) and stamped onto the resulting [ChatSwipe.imageCaption] for
  /// the bubble to render underneath.
  ///
  /// Review gating: when [targetMessage] is non-null the call is considered
  /// tool-triggered and the session-layer tool-review flag is the gate;
  /// otherwise the session-layer wand-review flag is used. Both live on the
  /// session's media config — see the read inside [generateImage].
  Future<void> generateImage(
    ImageGenerationModeEnum mode, {
    String? freePrompt,
    String? caption,
    ChatMessage? targetMessage,
  }) async {
    if (_isGeneratingImage) return;

    if (mode.requiresFreePrompt &&
        (freePrompt == null || freePrompt.trim().isEmpty)) {
      NavigationService().showSnackBar('Enter a prompt to generate an image.');
      return;
    }

    final character = imageGenTargetCharacter;
    if (character == null) {
      NavigationService().showSnackBar(
        'No character available for image generation.',
      );
      return;
    }

    final session = imageGenSession;
    final settings = imageGenSettingsService.settings;

    // Resolve the merged media config + presets up front so a misconfigured
    // session surfaces an error BEFORE we spend an LLM call compacting a
    // prompt we can't submit.
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: videoGenLlmService,
      session: session,
      character: character,
    );
    final imagePreset = resolved.imagePreset;
    if (imagePreset == null) {
      NavigationService().showSnackBar('Image generation is not configured.');
      return;
    }

    final systemPresetId =
        settings.domainPresetIds[LlmProviderDomainEnum.system];
    if (systemPresetId == null || systemPresetId.isEmpty) {
      NavigationService().showSnackBar(
        'No system model is configured. Set one in Settings → AI.',
      );
      return;
    }
    final ResolvedPreset systemPreset;
    try {
      systemPreset = videoGenLlmService.resolvePreset(
        configId: systemPresetId,
        providers: settings.providerConfigs,
      );
    } on Exception catch (e) {
      NavigationService().showSnackBar(
        UtilsLlm.extractUserFriendlyError(e),
      );
      return;
    }

    final isToolTriggered = targetMessage != null;

    // For user-triggered, allocate a fresh placeholder. For tool-triggered,
    // reuse the just-streamed assistant message — its waitingFor enum
    // drives the bubble's progress indicator until generation finishes.
    final ChatMessage workingMessage;
    if (isToolTriggered) {
      workingMessage = targetMessage;
    } else {
      workingMessage = ChatMessage(
        role: ChatRoleEnum.assistant,
        swipes: [ChatSwipe(content: '')],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      session.messages.add(workingMessage);
    }
    workingMessage.waitingFor = BubbleWaitingForEnum.composingImagePrompt;
    _isGeneratingImage = true;
    notifyListeners();

    try {
      final charName = effectiveCharName(character);
      final request = LlmImagePromptRequest(
        mode: mode,
        charName: charName,
        userName: imageGenUserName,
        characterDescription: character.card.description,
        localVariables: session.localVariables,
        globalVariables: settings.globalVariables,
        recentHistory: extractRecentMediaHistory(
          session: session,
          charName: charName,
          userName: imageGenUserName,
          usesChatHistory: mode.usesChatHistory,
          maxMessages: kImageGenMaxHistoryMessages,
        ),
        nsfwAllowed: resolved.imageNsfwAllowed,
        imagePromptPrefix: resolved.imagePromptPrefix,
        freePrompt: freePrompt ?? '',
        caption: caption ?? '',
      );

      var imagePrompt = await imageGenerationService.buildImagePrompt(
        systemPreset: systemPreset,
        request: request,
      );

      // Reviewing prompts is a per-chat trust call — no character/app
      // fallback. Tool-triggered (`send_selfie`) and wand-triggered have
      // separate gates because the trust calls are different.
      final reviewEnabled = isToolTriggered
          ? (session.configMedia?.imageToolPromptReview ?? false)
          : (session.configMedia?.imagePromptReview ?? false);
      if (reviewEnabled && onReviewImagePrompt != null) {
        final reviewed = await onReviewImagePrompt!(imagePrompt);
        if (reviewed == null) {
          // User cancelled. For user-triggered, drop the synthetic placeholder.
          // For tool-triggered, keep the message — its prose (if any)
          // persists; the absent image is the visible signal.
          if (isToolTriggered) {
            workingMessage.waitingFor = BubbleWaitingForEnum.complete;
          } else {
            session.messages.remove(workingMessage);
          }
          _isGeneratingImage = false;
          notifyListeners();
          return;
        }
        imagePrompt = reviewed;
      }

      // Flip to "generatingImage" right before the provider call so the
      // bubble's indicator switches from "Preparing image prompt…" to
      // "Generating image…" — users see prompt prep distinct from the
      // actual image-gen step.
      workingMessage.waitingFor = BubbleWaitingForEnum.generatingImage;
      notifyListeners();

      final result = await imageGenerationService.generateFromPrompt(
        imagePreset: imagePreset,
        imagePrompt: imagePrompt,
        aspectRatioId: resolved.imageAspectRatioId,
      );

      final relativePath = await imageGenChatRepository.saveMessageImage(
        chatDirectoryPath: imageGenChatDirectoryPath,
        sessionId: session.id,
        bytes: result.bytes,
      );

      if (isToolTriggered) {
        // Keep the model's prose intact; just attach image + caption.
        workingMessage.attachedImages = [relativePath];
        if (caption != null && caption.trim().isNotEmpty) {
          workingMessage.imageCaption = caption.trim();
        }
      } else {
        // Narrator-style text describes the image so the LLM sees meaningful
        // history (and role alternation is preserved) without any markdown
        // image syntax. The bytes live on `attachedImages` — a first-class
        // field the bubble renders separately and the prompt builder ignores.
        final altText = result.imagePrompt.replaceAll('\n', ' ').trim();
        workingMessage.content = '*(sent an image: $altText)*';
        workingMessage.attachedImages = [relativePath];
      }
      workingMessage.waitingFor = BubbleWaitingForEnum.complete;
      _isGeneratingImage = false;
      notifyListeners();
      imageGenPersistSession();
    } on Exception catch (e, st) {
      LoggingService().error('ChatImageGenerationMixin.generateImage', e, st);
      if (isToolTriggered) {
        // Leave the model's prose visible; the absent image is the
        // visible signal that generation failed.
        workingMessage.waitingFor = BubbleWaitingForEnum.complete;
      } else {
        session.messages.remove(workingMessage);
      }
      _isGeneratingImage = false;
      NavigationService().showSnackBar(
        e is ImageGenerationServiceException
            ? e.message
            : UtilsLlm.extractUserFriendlyError(e),
      );
      notifyListeners();
    }
  }

  /// Returns whether the chat model may fetch [url]. Reads the
  /// session-only `webToolFetchReview` flag: when off, allows; when on,
  /// shows the review dialog via [onConfirmUrlFetch] and returns the
  /// user's decision. Denies if the closure isn't bound (safer default
  /// than allowing).
  Future<bool> _confirmUrlFetch(String url, {String? purpose}) async {
    final review = imageGenSession.configMedia?.webToolFetchReview ?? false;
    if (!review) return true;
    if (onConfirmUrlFetch == null) {
      LoggingService().warning(
        'ChatImageGenerationMixin: webToolFetchReview is on but no '
        'onConfirmUrlFetch closure was bound; denying fetch of $url.',
      );
      return false;
    }
    return onConfirmUrlFetch!(url, purpose: purpose);
  }

  /// Builds the dispatch closure the chat execution service uses each
  /// round of the manual tool loop. The closure constructs a
  /// [ToolCallContext] against [targetMessage] (so a side-effect tool
  /// like `send_selfie` attaches its image to the in-flight bubble)
  /// and routes through [toolDispatcher].
  ///
  /// [targetMessage]'s `waitingFor` was already set to `runningTool` by
  /// the controller's `GenerationToolLoopProgressEvent` handler before
  /// this closure runs. The finally block restores it to `callingLlm`
  /// so the bubble shows "Thinking…" while waiting for the next LLM
  /// iteration after the tools finish (or after an exception).
  ToolDispatchCallback buildToolDispatch({required ChatMessage targetMessage}) {
    return (calls, callCounts) async {
      final appData = ChatBuiltinToolAppData(
        session: imageGenSession,
        character: imageGenTargetCharacter,
        targetMessage: targetMessage,
        generateImageImpl: ({required mode, freePrompt, caption}) =>
            generateImage(
              mode,
              freePrompt: freePrompt,
              caption: caption,
              targetMessage: targetMessage,
            ),
        generateVideoImpl: ({required mode, freePrompt}) => generateVideo(
          mode,
          freePrompt: freePrompt,
          targetMessage: targetMessage,
        ),
        confirmFetchImpl: _confirmUrlFetch,
      );
      try {
        return await toolDispatcher.dispatch(
          calls,
          ToolCallContext(appData: appData),
          callCounts: callCounts,
        );
      } finally {
        targetMessage.waitingFor = BubbleWaitingForEnum.callingLlm;
        targetMessage.waitingForLabel = null;
      }
    };
  }
}
