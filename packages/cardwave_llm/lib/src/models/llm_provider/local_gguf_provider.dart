part of '../llm_provider.dart';

/// In-process local-GGUF chat provider via `genkit_llamadart`. Loads the model
/// into VRAM in the same process — no separate server. The dialog/onboarding
/// flow chooses contextSize and kvCacheType based on detected free VRAM and
/// the file's metadata; those values come in through buildRunner.
class LocalGgufProvider extends LlmProvider {
  const LocalGgufProvider();

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.localGguf;

  @override
  String get label => 'Local GGUF (in-process)';

  @override
  String get defaultBaseUrl => ''; // unused — file path lives on the profile

  @override
  Map<LlmProviderDomainEnum, String> get defaultModelIds => const {};

  @override
  Future<List<dynamic>> fetchRawModels({
    required http.Client client,
    required String apiKey,
    required String baseUrl,
  }) async {
    // The "model" is the file the user picked. The caller passes the path
    // through `baseUrl` here only because that's the contract; the real model
    // discovery happens in the picker dialog.
    if (baseUrl.isEmpty) return const [];
    return [
      {'id': p.basename(baseUrl), 'path': baseUrl},
    ];
  }

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    final rawId = json['id'];
    if (rawId is! String || rawId.isEmpty) {
      throw FormatException(
        'Local GGUF model entry missing or invalid id: $json',
      );
    }
    // A local model's usable context is whatever it was loaded with, not a
    // notional native maximum. The add dialog passes the loaded size through
    // `context_length` so prompt budgeting and the model label reflect what
    // actually fits in VRAM; without it the model would claim the 128k
    // fallback and overflow the in-VRAM context when composing a prompt.
    final rawCtx = json['context_length'];
    // llama.cpp grammar-constrains any local model's reply into a required
    // JSON shape regardless of how the model was trained, so structured output
    // is always available — this is what makes a local file eligible for the
    // system domain. Tool calling, by contrast, only works when the file's own
    // chat template emits tool-call markers; that signal is detected from the
    // gguf metadata at add time and arrives here as `supports_tools`.
    final supportsTools = json['supports_tools'] == true;
    return LlmModel(
      id: rawId,
      name: rawId,
      contextLength: rawCtx is int && rawCtx > 0
          ? rawCtx
          : LlmConstants.fallbackContextLength,
      capabilities: LlmCapabilities(
        structuredOutput: true,
        toolCalling: supportsTools,
      ),
      supportedParameters: const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.topP,
        LlmParameterDefinitionIdEnum.topK,
        LlmParameterDefinitionIdEnum.minP,
        LlmParameterDefinitionIdEnum.maxResponseLength,
        LlmParameterDefinitionIdEnum.repetitionPenalty,
      ],
    );
  }

  @override
  LlmRunner buildRunner(BuildRunnerInputs inputs) {
    final BuildRunnerInputs(
      :modelId,
      :model,
      :paramValues,
      kvCacheType: kvType,
    ) = inputs;
    final path = inputs.modelPath!;
    final ctx = inputs.contextSize!;
    final r = LlmParameterResolver(model: model, userValues: paramValues);
    // On Windows the cpu+vulkan bundle enumerates both the integrated and the
    // discrete GPU. Without pinning, llama.cpp spreads layers across all of
    // them, and the integrated GPU's memory is shared system RAM — so the
    // model ends up in RAM instead of the discrete card's VRAM. When the
    // dialog detected a discrete GPU, pin offload to it: select Vulkan, point
    // main_gpu at that device, and turn off layer splitting so only it is
    // used. Off Windows (Metal, mobile) we leave the default auto handling.
    final pinnedGpu = Platform.isWindows ? inputs.gpuDeviceIndex : null;
    // Cache key encodes path + ctx + kv + pinned GPU so changing any of them
    // yields a fresh plugin (and `disposeRuntimeFor(path)` finds stale entries
    // via path substring match).
    final cacheKey =
        '${enumValue.name}:$path|ctx=$ctx|kv=${kvType?.name ?? ''}'
        '|gpu=${pinnedGpu ?? ''}';
    // Backend defaults to `auto` (the embedder's working setup).
    // `useMmap: false` materializes weights into VRAM eagerly, matching
    // kobold-cpp for this same model.
    // `batchSize: 512` caps the GPU compute buffer at around 310 MiB.
    // The llama.cpp default `n_batch == contextSize` allocates a
    // scratch buffer scaled to processing every context token in one
    // shot. At ctx 4608 that balloons to roughly 2.4 GiB, which
    // overflows an 8 GiB GPU on top of a 7 GiB Q4 12B model. Kobold
    // uses `blasbatchsize 1024`; 512 is safer for tight VRAM.
    // flash-attn stays enabled so non-fp16 KV cache types remain legal
    // (`ModelParams.validate` enforces this).
    const kSafeBatchSize = 512;
    final preferredBackend = pinnedGpu != null
        ? GpuBackend.vulkan
        : GpuBackend.auto;
    final splitMode = pinnedGpu != null
        ? ModelSplitMode.none
        : ModelSplitMode.layer;
    final mainGpu = pinnedGpu ?? 0;
    final modelParams = kvType == null
        ? ModelParams(
            contextSize: ctx,
            gpuLayers: ModelParams.maxGpuLayers,
            preferredBackend: preferredBackend,
            splitMode: splitMode,
            mainGpu: mainGpu,
            flashAttention: FlashAttention.enabled,
            useMmap: false,
            batchSize: kSafeBatchSize,
            microBatchSize: kSafeBatchSize,
          )
        : ModelParams(
            contextSize: ctx,
            gpuLayers: ModelParams.maxGpuLayers,
            preferredBackend: preferredBackend,
            splitMode: splitMode,
            mainGpu: mainGpu,
            flashAttention: FlashAttention.enabled,
            useMmap: false,
            batchSize: kSafeBatchSize,
            microBatchSize: kSafeBatchSize,
            cacheTypeK: kvType,
            cacheTypeV: kvType,
          );
    // Trace the exact ModelParams we hand to llamadart. With native logs
    // enabled at info level inside the worker, the immediate llama.cpp
    // output that follows ("ggml_backend_load: ...", "load_tensors:
    // offloaded N/M layers to GPU") is the diagnostic for whether the
    // Vulkan backend actually picked up the request.
    debugPrint(
      '[LocalGgufProvider] loading via genkit_llamadart: '
      'path=$path, ctx=$ctx, '
      'kv=${kvType?.name ?? 'f16'}, '
      'preferredBackend=${modelParams.preferredBackend.name}, '
      'gpuLayers=${modelParams.gpuLayers}, '
      'mainGpu=${modelParams.mainGpu}, '
      'splitMode=${modelParams.splitMode.name}, '
      'flashAttn=${modelParams.flashAttention.name}, '
      'mmap=${modelParams.useMmap}',
    );
    // LlamaDartPlugin doesn't override `GenkitPlugin.resolve` — its actions
    // are materialised by the registry on first generate(). So we skip
    // `_modelFor` (which expects synchronous resolve) and hand `LlmRunner`
    // a `ModelRef` instead; genkit's generate() resolves it lazily.
    _pluginByConfig.putIfAbsent(cacheKey, () {
      final p = llamaDart(
        models: [
          LlamaModelDefinition(
            name: modelId,
            modelPath: path,
            modelParams: modelParams,
            supportsEmbeddings: false,
          ),
        ],
      );
      _genkit.registry.registerPlugin(p);
      return p;
    });
    final ModelRef<Object?> genkitModel = llamaDart.model(modelId);
    final opts = LlamaDartGenerationConfig(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
      topK: r.resolveInt(LlmParameterDefinitionIdEnum.topK),
      minP: r.resolve(LlmParameterDefinitionIdEnum.minP),
      penalty: r.resolve(LlmParameterDefinitionIdEnum.repetitionPenalty),
      maxTokens: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }
}
