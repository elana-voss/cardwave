import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_model_capabilities_enum.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';
import 'package:cardwave_llm/src/models/llm_preset_config.dart';
import 'package:cardwave_llm/src/models/llm_preset_config_reasoning_effort_enum.dart';
import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_config.dart';
import 'package:cardwave_llm/src/models/llm_provider_domain_enum.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:cardwave_llm/src/models/llm_runner.dart';
import 'package:cardwave_llm/src/models/tts_option.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/repositories/llm_model_repository.dart';

typedef ResolvedPreset = ({
  LlmProviderConfig provider,
  LlmModel model,
  LlmPresetConfig preset,
});

/// Read-only / pure-compute helpers — model fetch, lookup, capability
/// checks, runner construction, options enrichment. Nothing here mutates
/// `AppSettings` or persists anything; the writer side lives in
/// `LlmManagementService`.
///
/// Holds [_repository] only because [fetchModels] needs the cached HTTP
/// client and the on-disk model cache. Everything else is closed over the
/// arguments.
class LlmPureHelpers {
  const LlmPureHelpers({required LlmModelRepository repository})
    : _repository = repository;
  final LlmModelRepository _repository;

  Future<List<LlmModel>> fetchModels({
    required LLMProviderEnum provider,
    required String apiKey,
    String? baseUrl,
    bool requireZdr = false,
  }) {
    return _repository.fetchModels(
      providerEnum: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      requireZdr: requireZdr,
    );
  }

  /// Populates `optionsVideo` on every adopted video-capable model in
  /// [profile] from the provider's hardcoded per-model rosters. Pure
  /// in-memory — no network hops.
  void populateVideoOptions(LlmProviderConfig profile) {
    final provider = LlmProvider.of(profile.providerEnum);
    for (final model in profile.models) {
      if (!_hasCapability(model, LlmModelCapabilitiesEnum.video)) continue;
      final options = provider.videoOptionsFor(model.id);
      if (options == null) continue;
      model.optionsVideo = options;
    }
  }

  /// Populates `optionsImage` on every adopted image-capable model in
  /// [profile] from the provider's hardcoded per-model rosters. Pure
  /// in-memory — no network hops. Models whose provider returns null
  /// (aspect control not supported or not wired) stay at `optionsImage
  /// = null`; the drawer tile hides itself in that case.
  void populateImageOptions(LlmProviderConfig profile) {
    final provider = LlmProvider.of(profile.providerEnum);
    for (final model in profile.models) {
      if (!_hasCapability(model, LlmModelCapabilitiesEnum.image)) continue;
      final options = provider.imageOptionsFor(model.id);
      if (options == null) continue;
      model.optionsImage = options;
    }
  }

  /// Populates `optionsTts` on every adopted TTS-capable model in [profile]
  /// by calling the provider's runtime voice endpoint and merging in the
  /// static language list. Non-TTS models are left untouched. Failures are
  /// swallowed per-model so one bad response doesn't poison the rest.
  /// Fetches run in parallel via [Future.wait] since each hits the network.
  Future<void> populateTtsVoices(LlmProviderConfig profile) async {
    final provider = LlmProvider.of(profile.providerEnum);
    final baseUrl = profile.baseUrl ?? provider.defaultBaseUrl;
    await Future.wait([
      for (final model in profile.models)
        if (_hasCapability(model, LlmModelCapabilitiesEnum.audioTts))
          _populateModelTtsVoices(
            model: model,
            provider: provider,
            apiKey: profile.apiKey,
            baseUrl: baseUrl,
          ),
    ]);
  }

  Future<void> _populateModelTtsVoices({
    required LlmModel model,
    required LlmProvider provider,
    required String apiKey,
    required String baseUrl,
  }) async {
    try {
      final voices = await provider.fetchTtsVoices(
        apiKey: apiKey,
        baseUrl: baseUrl,
        modelId: model.id,
      );
      if (voices.isEmpty) return;
      model.optionsTts = OptionsTts(
        voices: voices,
        languages: provider.ttsLanguages,
      );
      ttsLogger.info(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.info,
          message:
              'TTS options enriched for ${provider.enumValue.name}/${model.id}: '
              '${voices.length} voices, ${provider.ttsLanguages.length} languages.',
        ),
      );
    } on Exception catch (e, st) {
      ttsLogger.severe(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.error,
          message:
              'TTS options fetch failed for ${provider.enumValue.name}/${model.id}',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  String? getDefaultModelIdForDomain(
    LLMProviderEnum providerEnum,
    LlmProviderDomainEnum domain,
  ) => LlmProvider.of(providerEnum).defaultModelIds[domain];

  LlmModelCapabilitiesEnum getRequiredOutputModality(
    LlmProviderDomainEnum domain,
  ) => _getRequiredModality(domain);

  bool canServeDomain(LlmModel model, LlmProviderDomainEnum domain) =>
      _meetsDomainRequirements(model, domain);

  /// Canonical name for the auto-seeded default preset of a (domain, provider)
  /// pair. Same string used by add-provider flows and by
  /// `resetDomainsToProviderDefaults` to recognise its own seeded preset —
  /// identification is by name because preset ids carry a random suffix.
  String canonicalDefaultPresetName(
    LlmProviderDomainEnum domain,
    String providerLabel,
  ) => '${domain.label} · $providerLabel';

  /// Walks all persisted providers/models for a model by id.
  LlmModel? findModel(String modelId, List<LlmProviderConfig> providers) {
    for (final provider in providers) {
      for (final model in provider.models) {
        if (model.id == modelId) return model;
      }
    }
    return null;
  }

  /// Resolves a preset id to its owning provider + model + preset, or null
  /// if the preset isn't found. UI code that renders conditionally on the
  /// active preset uses this.
  ResolvedPreset? resolvePresetOrNull({
    required String configId,
    required List<LlmProviderConfig> providers,
  }) {
    for (final provider in providers) {
      for (final model in provider.models) {
        for (final preset in model.presets) {
          if (preset.id == configId) {
            return (provider: provider, model: model, preset: preset);
          }
        }
      }
    }
    return null;
  }

  /// Non-null variant — throws if the preset id isn't found. Used by code
  /// paths that have already validated (or healed) the active preset id.
  ResolvedPreset resolvePreset({
    required String configId,
    required List<LlmProviderConfig> providers,
  }) {
    final found = resolvePresetOrNull(configId: configId, providers: providers);
    if (found == null) {
      throw Exception('Connection profile or model configuration not found.');
    }
    return found;
  }

  /// Builds a runner from a resolved preset. [paramOverrides] are merged on
  /// top of the preset's stored parameter values (e.g. a one-shot
  /// maxResponseLength override).
  LlmRunner createRunner({
    required LlmProviderConfig provider,
    required LlmModel model,
    required LlmPresetConfig preset,
    Map<LlmParameterDefinitionIdEnum, double>? paramOverrides,
  }) {
    final params = <LlmParameterDefinitionIdEnum, double>{
      ...preset.parameterValues,
      ...?paramOverrides,
    };
    return LlmProvider.of(provider.providerEnum).buildRunner(
      apiKey: provider.apiKey,
      modelId: model.id,
      model: model,
      paramValues: params,
      reasoningEffort: preset.reasoningEffort,
      baseUrl: provider.baseUrl,
    );
  }

  /// Raw runner construction — used by UI flows that don't yet have a saved
  /// preset (e.g. the preset-edit test-message button). The caller supplies
  /// the already-fetched [LlmModel] so no repository lookup is needed.
  LlmRunner createRunnerRaw({
    required LLMProviderEnum providerEnum,
    required String apiKey,
    required LlmModel model,
    required Map<LlmParameterDefinitionIdEnum, double> paramValues,
    LlmPresetConfigReasoningEffortEnum reasoningEffort =
        LlmPresetConfigReasoningEffortEnum.off,
    String? baseUrl,
  }) {
    return LlmProvider.of(providerEnum).buildRunner(
      apiKey: apiKey,
      modelId: model.id,
      model: model,
      paramValues: paramValues,
      reasoningEffort: reasoningEffort,
      baseUrl: baseUrl,
    );
  }

  List<LlmModel> pruneAdoptedToIds(
    List<LlmModel> models,
    Set<String> validIds,
  ) => models.where((m) => validIds.contains(m.id)).toList();

  String resolveModelForDomain(
    LlmProviderDomainEnum domain,
    String preferredModelId,
    List<LlmModel> models,
  ) {
    final exactModel = models
        .where((m) => m.id == preferredModelId || m.name == preferredModelId)
        .firstOrNull;
    if (exactModel != null && _meetsDomainRequirements(exactModel, domain)) {
      return exactModel.id;
    }

    final preferredModel = models
        .where((m) => m.id.contains(preferredModelId))
        .firstOrNull;
    if (preferredModel != null &&
        _meetsDomainRequirements(preferredModel, domain)) {
      return preferredModel.id;
    }

    final fallbackModel = models
        .where((m) => _meetsDomainRequirements(m, domain))
        .firstOrNull;
    if (fallbackModel != null) return fallbackModel.id;

    return '';
  }

  List<({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})>
  getValidPresetsForDomain(
    LlmProviderDomainEnum domain,
    List<LlmProviderConfig> profiles,
  ) {
    final result =
        <
          ({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})
        >[];

    for (final profile in profiles) {
      for (final model in profile.models) {
        if (!_meetsDomainRequirements(model, domain)) continue;
        for (final preset in model.presets) {
          result.add((profile: profile, model: model, config: preset));
        }
      }
    }
    return result;
  }

  LlmModelCapabilitiesEnum _getRequiredModality(LlmProviderDomainEnum domain) {
    switch (domain) {
      case LlmProviderDomainEnum.chat:
      case LlmProviderDomainEnum.system:
      case LlmProviderDomainEnum.assistant:
        return LlmModelCapabilitiesEnum.text;
      case LlmProviderDomainEnum.image:
        return LlmModelCapabilitiesEnum.image;
      case LlmProviderDomainEnum.audioTts:
        return LlmModelCapabilitiesEnum.audioTts;
      case LlmProviderDomainEnum.audioMusic:
        return LlmModelCapabilitiesEnum.audioMusic;
      case LlmProviderDomainEnum.video:
        return LlmModelCapabilitiesEnum.video;
    }
  }

  bool _hasCapability(LlmModel model, LlmModelCapabilitiesEnum modality) {
    if (model.capabilities.outputModalities.isEmpty) {
      return modality == LlmModelCapabilitiesEnum.text;
    }
    return model.capabilities.outputModalities.contains(modality);
  }

  /// Returns true if [model] meets every requirement of [domain]. The
  /// modality check is the base rule; the system domain additionally
  /// requires structured-output support, since auto-tag (and any future
  /// system-domain caller) constrains the reply to a JSON schema. Mirrors
  /// the image / video / tts pattern: the picker, the auto-seed fallback,
  /// and `LlmManagementService.healDomainAssignments` all defer to this
  /// single rule. Public access is via [canServeDomain].
  bool _meetsDomainRequirements(LlmModel model, LlmProviderDomainEnum domain) {
    if (!_hasCapability(model, _getRequiredModality(domain))) return false;
    if (domain == LlmProviderDomainEnum.system &&
        !model.capabilities.structuredOutput) {
      return false;
    }
    return true;
  }

  bool hasCapabilityForModel(
    LlmModel model,
    LlmModelCapabilitiesEnum modality,
  ) => _hasCapability(model, modality);
}
