import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';
import 'package:cardwave_llm/src/models/llm_preset_config_reasoning_effort_enum.dart';
import 'package:llamadart/llamadart.dart' show KvCacheType;

/// Inputs passed to `LlmProvider.buildRunner`. Bundles the shared chat-side
/// configuration (auth, model id, parameter values) plus any
/// provider-specific extras (currently `localGguf` carries `modelPath`,
/// `contextSize`, `kvCacheType` — cloud providers leave those null).
class BuildRunnerInputs {
  const BuildRunnerInputs({
    required this.apiKey,
    required this.modelId,
    required this.model,
    required this.paramValues,
    this.reasoningEffort = LlmPresetConfigReasoningEffortEnum.off,
    this.baseUrl,
    this.modelPath,
    this.contextSize,
    this.kvCacheType,
  });

  final String apiKey;
  final String modelId;
  final LlmModel model;
  final Map<LlmParameterDefinitionIdEnum, double> paramValues;
  final LlmPresetConfigReasoningEffortEnum reasoningEffort;
  final String? baseUrl;
  final String? modelPath;
  final int? contextSize;
  final KvCacheType? kvCacheType;
}
