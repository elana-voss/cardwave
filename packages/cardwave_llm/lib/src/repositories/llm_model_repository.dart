import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:http/http.dart' as http;

/// Raw model-list fetcher for the picker. Stateless across calls — the
/// module never holds a catalog cache; callers (the management service)
/// memoise on their side if they need to.
class LlmModelRepository {
  LlmModelRepository();

  final http.Client _httpClient = http.Client();

  void dispose() {
    _httpClient.close();
  }

  /// Fetches the provider's model list sorted by id. NanoGpt results are
  /// enriched with OpenRouter metadata when possible; OR results are
  /// intersected with OR's ZDR endpoint list when [requireZdr] is true.
  Future<List<LlmModel>> fetchModels({
    required LLMProviderEnum providerEnum,
    required String apiKey,
    String? baseUrl,
    bool requireZdr = false,
  }) async {
    final provider = LlmProvider.of(providerEnum);
    final effectiveBaseUrl = baseUrl ?? provider.defaultBaseUrl;

    // Kick off all needed fetches concurrently; await joins below.
    final rawModelsFuture = provider.fetchRawModels(
      client: _httpClient,
      apiKey: apiKey,
      baseUrl: effectiveBaseUrl,
    );
    final orLookupFuture = providerEnum == LLMProviderEnum.nanogpt
        ? _fetchOpenRouterLookupForEnrichment()
        : null;
    final zdrIdsFuture =
        providerEnum == LLMProviderEnum.openrouter && requireZdr
        ? _fetchOpenRouterZdrIds(
            provider: provider as OpenRouterProvider,
            baseUrl: effectiveBaseUrl,
          )
        : null;

    final rawModels = await rawModelsFuture;
    final orLookup = await orLookupFuture;
    final zdrIds = await zdrIdsFuture;

    final models = <LlmModel>[];
    for (final e in rawModels) {
      final map = Map<String, dynamic>.of((e as Map).cast<String, dynamic>());
      try {
        final model = provider.parseModel(map, openRouterLookup: orLookup);
        if (zdrIds != null && !zdrIds.contains(model.id)) continue;
        models.add(model);
      } on Exception catch (err) {
        final entryId = map['id']?.toString() ?? '<unknown>';
        modelsLogger.severe(
          LlmDiagnosticEvent(
            level: LlmDiagnosticLevel.error,
            message:
                'Failed to parse model entry for ${providerEnum.name} (id=$entryId)',
            error: err,
          ),
        );
      }
    }

    models.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
    return models;
  }

  /// A failing OR fetch must not sink a successful NanoGpt fetch —
  /// falls back to an empty lookup on error.
  Future<Map<String, Map<String, dynamic>>>
  _fetchOpenRouterLookupForEnrichment() async {
    final orProvider = LlmProvider.of(LLMProviderEnum.openrouter);
    try {
      final raw = await orProvider.fetchRawModels(
        client: _httpClient,
        apiKey: '',
        baseUrl: orProvider.defaultBaseUrl,
      );
      return _buildOpenRouterLookup(raw);
    } on LlmFetchException catch (e) {
      modelsLogger.severe(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.error,
          message: 'OpenRouter cross-reference fetch failed for nanogpt',
          error: e,
        ),
      );
      return const {};
    }
  }

  Future<Set<String>> _fetchOpenRouterZdrIds({
    required OpenRouterProvider provider,
    required String baseUrl,
  }) async {
    final raw = await provider.fetchRawZdrEntries(
      client: _httpClient,
      baseUrl: baseUrl,
    );
    final ids = <String>{};
    for (final e in raw) {
      final map = Map<String, dynamic>.of((e as Map).cast<String, dynamic>());
      final id = map['model_id'] as String?;
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Map<String, Map<String, dynamic>> _buildOpenRouterLookup(
    List<dynamic> rawList,
  ) {
    final lookup = <String, Map<String, dynamic>>{};
    for (final raw in rawList) {
      final map = Map<String, dynamic>.of((raw as Map).cast<String, dynamic>());
      final id = (map['id'] as String?)?.toLowerCase();
      if (id == null) continue;
      lookup[id] = map;
      if (id.contains('/')) {
        lookup[id.substring(id.indexOf('/') + 1)] = map;
      }
      final slug = (map['canonical_slug'] as String?)?.toLowerCase();
      if (slug != null && slug.isNotEmpty) {
        lookup[slug] = map;
        if (slug.contains('/')) {
          lookup[slug.substring(slug.indexOf('/') + 1)] = map;
        }
      }
      final hfId = (map['hugging_face_id'] as String?)?.toLowerCase();
      if (hfId != null && hfId.isNotEmpty) lookup[hfId] = map;
    }
    return lookup;
  }
}
