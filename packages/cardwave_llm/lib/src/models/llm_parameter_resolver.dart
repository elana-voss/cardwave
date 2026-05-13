import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';

/// Single-source parameter resolver. Collapses the previous four-layer walk
/// (user preset -> model defaults -> model-supported filter -> common defaults)
/// into one call site.
class LlmParameterResolver {
  const LlmParameterResolver({required this.model, required this.userValues});
  final LlmModel model;
  final Map<LlmParameterDefinitionIdEnum, double> userValues;

  double? resolve(LlmParameterDefinitionIdEnum id) {
    final isMaxResponse = id == LlmParameterDefinitionIdEnum.maxResponseLength;
    if (!model.supportedParameters.contains(id) && !isMaxResponse) {
      return null;
    }
    if (userValues.containsKey(id)) return userValues[id];
    if (model.defaultParameters.containsKey(id)) {
      return model.defaultParameters[id];
    }
    if (isMaxResponse) return model.maxOutputTokens.toDouble();
    return _commonParametersById[id]?.defaultValue;
  }

  int? resolveInt(LlmParameterDefinitionIdEnum id) => resolve(id)?.toInt();
}

final Map<LlmParameterDefinitionIdEnum, LlmParameterDefinition>
_commonParametersById = {for (final p in commonParameters) p.id: p};
