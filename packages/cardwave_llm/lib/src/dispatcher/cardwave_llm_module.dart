import 'package:cardwave_llm/src/audio/services/text_to_speech_service.dart';
import 'package:cardwave_llm/src/image/services/image_generation_service.dart';
import 'package:cardwave_llm/src/pure/llm_pure_helpers.dart';
import 'package:cardwave_llm/src/repositories/llm_model_repository.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/tools/tool_registry.dart';
import 'package:cardwave_llm/src/video/services/video_generation_service.dart';
import 'package:cardwave_llm/src/video/services/video_prompt_builder.dart';

/// Single entry-point bundling the package's stateless services. Held by
/// the app via Provider; `dispose()` releases held HTTP clients on app
/// shutdown. Direct field access today; a future `invoke(toolName, args,
/// secrets, cancelToken)` + `listTools()` surface will wrap the same
/// services for cross-process MCP deployment.
class CardwaveLlmModule {
  const CardwaveLlmModule({
    required this.pureHelpers,
    required this.modelRepository,
    required this.promptRepository,
    required this.imageGenerationService,
    required this.videoGenerationService,
    required this.videoPromptBuilder,
    required this.textToSpeechService,
    required this.toolRegistry,
  });

  final LlmPureHelpers pureHelpers;
  final LlmModelRepository modelRepository;
  final PromptRepository promptRepository;
  final ImageGenerationService imageGenerationService;
  final VideoGenerationService videoGenerationService;
  final VideoPromptBuilder videoPromptBuilder;
  final TextToSpeechService textToSpeechService;
  final ToolRegistry toolRegistry;

  /// Closes long-lived resources held inside the module — the HTTP clients
  /// behind [LlmModelRepository], [ImageGenerationService], and the
  /// [FetchWebsiteTool] in the registry. Safe to call once at app shutdown;
  /// subsequent service calls would fail because the clients are closed.
  void dispose() {
    modelRepository.dispose();
    imageGenerationService.dispose();
    toolRegistry.dispose();
  }
}
