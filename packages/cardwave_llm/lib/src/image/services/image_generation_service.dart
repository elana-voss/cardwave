import 'package:cardwave_llm/src/image/clients/image_http_client.dart';
import 'package:cardwave_llm/src/image/clients/open_ai_compatible_image_client.dart';
import 'package:cardwave_llm/src/image/clients/open_router_image_client.dart';
import 'package:cardwave_llm/src/image/image_generation_mode_enum.dart';
import 'package:cardwave_llm/src/image/llm_image_result.dart';
import 'package:cardwave_llm/src/image/image_options.dart';
import 'package:cardwave_llm/src/image/llm_image_prompt_request.dart';
import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/pure/llm_pure_helpers.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/utils/utils_prompt.dart';
import 'package:http/http.dart' as http;

/// Two-step image generation: chat LLM expands a mode template into a tag
/// list, then that tag list is POSTed to the user's image-domain provider.
/// Returns raw bytes — the app-side controller persists them.
class ImageGenerationService {
  ImageGenerationService({
    required this.pureHelpers,
    required this.promptRepository,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final LlmPureHelpers pureHelpers;
  final PromptRepository promptRepository;
  final http.Client httpClient;

  void dispose() {
    httpClient.close();
  }

  /// Builds the image prompt (chat LLM expands a tag template). Caller
  /// resolves [systemPreset] (the compactor) before invoking. Returns the
  /// final prompt with optional character prefix and caption suffix already
  /// applied.
  Future<String> buildImagePrompt({
    required ResolvedPreset systemPreset,
    required LlmImagePromptRequest request,
  }) async {
    final runner = pureHelpers.createRunner(
      provider: systemPreset.provider,
      model: systemPreset.model,
      preset: systemPreset.preset,
    );

    final tagsRequest = _composePromptInput(request);
    imageLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.imageGen,
        title: 'TAGS OUTGOING',
        body:
            '\nMode: ${request.mode.name}\nLen: ${tagsRequest.length}\n\n$tagsRequest',
      ),
    );

    final tagList = (await runner.complete(tagsRequest)).trim();
    imageLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.imageGen,
        title: 'TAGS INCOMING',
        body:
            '\nMode: ${request.mode.name}\nLen: ${tagList.length}\nTags: $tagList',
      ),
    );

    if (tagList.isEmpty) {
      throw const ImageGenerationServiceException(
        'The system model returned an empty image description. '
        'Check that Settings → AI → System is set to a working model.',
      );
    }

    final prefix = request.imagePromptPrefix.trim();
    final withPrefix = prefix.isNotEmpty ? '$prefix, $tagList' : tagList;

    // Append caption verbatim AFTER the system-model expansion so the system
    // model can never paraphrase or reword the user-visible caption text.
    final caption = request.caption.trim();
    if (caption.isNotEmpty) {
      return '$withPrefix, with the text "$caption" rendered on the image';
    }
    return withPrefix;
  }

  /// POSTs the pre-built [imagePrompt] to [imagePreset]'s provider and
  /// returns the bytes plus the prompt that was sent. [aspectRatioId] is
  /// null when the resolved model has no aspect roster (legacy Grok image,
  /// some OpenRouter models) — the dispatcher then falls back to the
  /// provider's default size.
  Future<LlmImageResult> generateFromPrompt({
    required ResolvedPreset imagePreset,
    required String imagePrompt,
    String? aspectRatioId,
  }) async {
    final imageProvider = imagePreset.provider;
    final imageModel = imagePreset.model;

    final imageClient = _clientForProvider(imageProvider.providerEnum);
    final providerInfo = LlmProvider.of(imageProvider.providerEnum);

    final extras = aspectRatioId == null
        ? const <String, dynamic>{}
        : providerInfo.imageRequestExtras(
            modelId: imageModel.id,
            config: ConfigImage(aspectRatioId: aspectRatioId),
          );

    imageLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'ImageGenerationService: '
            'imageProvider=${imageProvider.providerEnum.name} '
            'imageModel=${imageModel.id} '
            'promptLen=${imagePrompt.length} '
            'aspect=${aspectRatioId ?? "default"}',
      ),
    );

    final bytes = await imageClient.generate(
      httpClient: httpClient,
      apiKey: imageProvider.apiKey,
      baseUrl: imageProvider.baseUrl ?? providerInfo.defaultBaseUrl,
      modelId: imageModel.id,
      prompt: imagePrompt,
      extras: extras,
    );

    return LlmImageResult(bytes: bytes, imagePrompt: imagePrompt);
  }

  /// Convenience: builds the prompt and generates in one call.
  Future<LlmImageResult> generate({
    required ResolvedPreset systemPreset,
    required ResolvedPreset imagePreset,
    required LlmImagePromptRequest request,
    String? aspectRatioId,
  }) async {
    final imagePrompt = await buildImagePrompt(
      systemPreset: systemPreset,
      request: request,
    );
    return generateFromPrompt(
      imagePreset: imagePreset,
      imagePrompt: imagePrompt,
      aspectRatioId: aspectRatioId,
    );
  }

  ImageHttpClient _clientForProvider(LLMProviderEnum providerEnum) {
    switch (providerEnum) {
      case LLMProviderEnum.openai:
      case LLMProviderEnum.grok:
      case LLMProviderEnum.nanogpt:
        return const OpenAiCompatibleImageClient();
      case LLMProviderEnum.openrouter:
        return const OpenRouterImageClient();
      case LLMProviderEnum.anthropic:
      case LLMProviderEnum.google:
      case LLMProviderEnum.localOpenAi:
        throw ImageGenerationServiceException(
          '${providerEnum.name} is not supported for image generation yet.',
        );
    }
  }

  String _composePromptInput(LlmImagePromptRequest request) {
    String resolve(String text, String trackingId) =>
        UtilsPrompt.replacePlaceholders(
          text,
          charName: request.charName,
          userName: request.userName,
          localVariables: request.localVariables,
          globalVariables: request.globalVariables,
          trackingId: trackingId,
        );

    final rawTemplate = _templateForMode(request.mode);
    final templateWithSubject = request.mode.requiresFreePrompt
        ? rawTemplate.replaceAll('{{subject}}', request.freePrompt)
        : rawTemplate;
    final resolvedTemplate = resolve(
      templateWithSubject,
      'imageGen_${request.mode.name}',
    );

    final fullPrompt = StringBuffer();

    if (request.characterDescription.trim().isNotEmpty) {
      fullPrompt
        ..writeln('Character description:')
        ..writeln(resolve(request.characterDescription, 'imageGen_desc'))
        ..writeln();
    }

    if (request.mode.usesChatHistory && request.recentHistory.isNotEmpty) {
      fullPrompt.writeln('Recent chat history:');
      for (final m in request.recentHistory) {
        fullPrompt.writeln('${m.label}: ${m.content}');
      }
      fullPrompt.writeln();
    }

    fullPrompt.writeln(resolvedTemplate);

    if (!request.nsfwAllowed) {
      fullPrompt
        ..writeln()
        ..writeln(promptRepository.imageGenNsfwFilter);
    }

    return fullPrompt.toString();
  }

  String _templateForMode(ImageGenerationModeEnum mode) {
    switch (mode) {
      case ImageGenerationModeEnum.character:
        return promptRepository.imageGenCharacter;
      case ImageGenerationModeEnum.face:
        return promptRepository.imageGenFace;
      case ImageGenerationModeEnum.scenario:
        return promptRepository.imageGenScenario;
      case ImageGenerationModeEnum.lastMessage:
        return promptRepository.imageGenLastMessage;
      case ImageGenerationModeEnum.background:
        return promptRepository.imageGenBackground;
      case ImageGenerationModeEnum.free:
        return promptRepository.imageGenFree;
      case ImageGenerationModeEnum.selfie:
        return promptRepository.imageGenSelfie;
    }
  }
}

/// Maximum chat-history snippets the caller should pass to the service for
/// modes that use history. Defined on the service side so the contract
/// stays in one place; the chat-side controller honors it when slicing
/// `session.messages` into [LlmImagePromptRequest.recentHistory].
const int kImageGenMaxHistoryMessages = 6;
