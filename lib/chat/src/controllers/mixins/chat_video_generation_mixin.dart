import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_media_history.dart';
import 'package:cardwave/chat/src/controllers/video_generation_controller.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/chat_swipe.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Adds video-generation orchestration to any chat controller. The
/// concrete controller supplies the session + target character + save
/// hook; this mixin owns the placeholder lifecycle, runs the prompt
/// through [VideoPromptBuilder] (character description + chat history +
/// per-mode template + NSFW filter → system LLM → short cinematic
/// prompt), optionally shows the review dialog, hands off to
/// [VideoGenerationController] for the submit-poll-download loop, and stamps
/// the result on the placeholder's swipe.
///
/// Video generation is expensive and multi-minute, so the optional
/// [onReviewVideoPrompt] review step before provider submit is much more
/// load-bearing here than in image gen — a bad prompt costs real money
/// and real time before the user sees output.
mixin ChatVideoGenerationMixin on BaseChatViewController {
  VideoGenerationController get videoGenerationService;
  VideoPromptBuilder get videoPromptBuilder;
  LlmPureHelpers get videoGenLlmService;
  SettingsService get videoGenSettingsService;
  ChatSession get videoGenSession;
  CharacterFile? get videoGenTargetCharacter;
  String get videoGenUserName;

  /// Persists the session after a placeholder is finalised into a real
  /// video message. Called once per successful generation. The
  /// implementation can be async or fire-and-forget; the mixin does not
  /// await.
  void videoGenPersistSession();

  /// Set by the view to show a review dialog. Returns the (possibly
  /// edited) prompt, or `null` to cancel generation.
  Future<String?> Function(String prompt)? onReviewVideoPrompt;

  bool _isGeneratingVideo = false;

  bool get isGeneratingVideo => _isGeneratingVideo;

  Future<void> generateVideo(
    VideoGenerationModeEnum mode, {
    String? freePrompt,
    ChatMessage? targetMessage,
  }) async {
    if (_isGeneratingVideo) return;

    if (mode.requiresFreePrompt &&
        (freePrompt == null || freePrompt.trim().isEmpty)) {
      NavigationService().showSnackBar('Enter a prompt to generate a video.');
      return;
    }

    final character = videoGenTargetCharacter;
    if (character == null) {
      NavigationService().showSnackBar(
        'No character available for video generation.',
      );
      return;
    }

    final session = videoGenSession;
    final settings = videoGenSettingsService.settings;

    // Resolve the merged media config up front so a misconfigured session
    // surfaces an error BEFORE we spend an LLM call compacting a prompt
    // we can't submit.
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: videoGenLlmService,
      session: session,
      character: character,
    );
    if (resolved.videoPreset == null) {
      NavigationService().showSnackBar('Video generation is not configured.');
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
        id: UtilsApp.generateId('msg'),
        role: ChatRoleEnum.assistant,
        swipes: [ChatSwipe(content: '')],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      session.messages.add(workingMessage);
    }
    workingMessage.waitingFor = BubbleWaitingForEnum.composingVideoPrompt;
    _isGeneratingVideo = true;
    notifyListeners();

    try {
      final systemPresetId =
          settings.domainPresetIds[LlmProviderDomainEnum.system];
      if (systemPresetId == null || systemPresetId.isEmpty) {
        throw const VideoPromptBuilderException(
          'No system model is configured. Set one in Settings → AI.',
        );
      }
      final systemPreset = videoGenLlmService.resolvePreset(
        configId: systemPresetId,
        providers: settings.providerConfigs,
      );

      final charName = effectiveCharName(character);
      final builderRequest = LlmVideoPromptRequest(
        mode: mode,
        charName: charName,
        userName: videoGenUserName,
        characterDescription: character.card.description,
        localVariables: session.localVariables,
        globalVariables: settings.globalVariables,
        recentHistory: extractRecentMediaHistory(
          session: session,
          charName: charName,
          userName: videoGenUserName,
          usesChatHistory: mode.usesChatHistory,
          maxMessages: kVideoGenMaxHistoryMessages,
        ),
        nsfwAllowed: resolved.videoNsfwAllowed,
        videoPromptPrefix: resolved.videoPromptPrefix,
        durationSeconds: resolved.videoDurationSeconds!,
        freePrompt: freePrompt ?? '',
      );

      var finalPrompt = await videoPromptBuilder.buildPrompt(
        systemPreset: systemPreset,
        request: builderRequest,
      );

      if ((session.configMedia?.videoPromptReview ?? false) &&
          onReviewVideoPrompt != null) {
        final reviewed = await onReviewVideoPrompt!(finalPrompt);
        if (reviewed == null) {
          // User cancelled. For user-triggered, drop the synthetic
          // placeholder. For tool-triggered, keep the message — its prose
          // (if any) persists; the absent video is the visible signal.
          if (isToolTriggered) {
            workingMessage.waitingFor = BubbleWaitingForEnum.complete;
          } else {
            session.messages.remove(workingMessage);
          }
          _isGeneratingVideo = false;
          notifyListeners();
          return;
        }
        finalPrompt = reviewed;
      }

      // Flip to "generatingVideo" right before the provider round-trip.
      // The bubble's indicator further refines the label from the live
      // job phase (Polling… NN%, Downloading…) via VideoGenerationController.
      workingMessage.waitingFor = BubbleWaitingForEnum.generatingVideo;
      notifyListeners();

      final result = await videoGenerationService.generateFromCompactedPrompt(
        placeholder: workingMessage,
        finalPrompt: finalPrompt,
        resolved: resolved,
        session: session,
        characterFile: character,
      );

      workingMessage.activeSwipe.videoPath = result.relativePath;
      if (!isToolTriggered) {
        // Narrator-style text describes the video so the LLM sees meaningful
        // history. Tool-triggered keeps the model's prose intact.
        final altText = finalPrompt.replaceAll('\n', ' ').trim();
        workingMessage.content = '*(sent a video: $altText)*';
      }
      workingMessage.waitingFor = BubbleWaitingForEnum.complete;
      _isGeneratingVideo = false;
      notifyListeners();
      videoGenPersistSession();
    } on Exception catch (e, st) {
      LoggingService().error('ChatVideoGenerationMixin.generateVideo', e, st);
      if (isToolTriggered) {
        workingMessage.waitingFor = BubbleWaitingForEnum.complete;
      } else {
        session.messages.remove(workingMessage);
      }
      _isGeneratingVideo = false;
      NavigationService().showSnackBar(
        e is VideoPromptBuilderException
            ? e.message
            : UtilsLlm.extractUserFriendlyError(e),
      );
      notifyListeners();
    }
  }
}
