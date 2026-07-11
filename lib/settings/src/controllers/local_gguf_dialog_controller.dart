import 'dart:async';
import 'dart:io';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/utils/gpu_device_selection.dart';
import 'package:cardwave/settings/src/utils/local_gguf_recommendation.dart';
import 'package:cardwave/settings/src/utils/vram_probe.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// State + workflow for the "Add Local GGUF" dialog. One instance per dialog
/// open, owned by the dialog widget. The widget never owns inference state —
/// everything that survives across rebuilds lives here.
class LocalGgufDialogController extends ChangeNotifier {
  LocalGgufDialogController({
    required Embedder embedder,
  }) : _embedder = embedder;

  final Embedder _embedder;

  String? _pickedPath;
  String? get pickedPath => _pickedPath;

  GgufMetadata? _metadata;
  GgufMetadata? get metadata => _metadata;

  VramSnapshot? _vram;
  VramSnapshot? get vram => _vram;

  int? _contextSize;
  int? get contextSize => _contextSize;

  /// User's KV cache choice. `null` means "Auto" — persisted as null so
  /// llamadart's default (fp16) is used.
  KvCacheType? _kvCacheType;
  KvCacheType? get kvCacheType => _kvCacheType;

  /// Discrete GPU to pin offload to, detected at file-pick time. Null when the
  /// machine has no discrete GPU (offload stays on default device handling).
  int? _gpuDeviceIndex;

  bool _probing = false;
  bool get isProbing => _probing;

  bool _loadingModel = false;
  bool get isLoadingModel => _loadingModel;

  bool _modelLoaded = false;
  bool get isModelLoaded => _modelLoaded;

  LocalGgufRecommendation? _recommendation;
  LocalGgufRecommendation? get recommendation => _recommendation;

  /// Inputs to the recommendation algorithm — captured at probe time so
  /// the max-ctx hint under the context field can be recomputed live
  /// when the user changes the KV cache pick (without re-running the
  /// metadata + VRAM probes).
  RecommendationInputs? _recInputs;

  /// Resolves the KV cache type for calculation, persistence, and the
  /// actual model load. When the user has set an explicit type, that
  /// wins. When the picker is on "Auto" (`_kvCacheType == null`), we
  /// pick the highest-quality KV (fp16 first, then q8_0, then q4_0)
  /// whose max-fitting context is at least the user's chosen context
  /// size — so Auto means "best quality that fits the ctx I picked",
  /// not "llama.cpp's default fp16 (which usually doesn't fit on tight
  /// GPUs)".
  KvCacheType get effectiveKvCacheType {
    final explicit = _kvCacheType;
    if (explicit != null) return explicit;
    final inputs = _recInputs;
    final ctx = _contextSize;
    if (inputs == null || ctx == null) return KvCacheType.f16;
    for (final candidate in const [
      KvCacheType.f16,
      KvCacheType.q8_0,
      KvCacheType.q4_0,
    ]) {
      if (maxContextAt(inputs: inputs, kvCacheType: candidate) >= ctx) {
        return candidate;
      }
    }
    return KvCacheType.q4_0;
  }

  /// Largest context size that fits in the available VRAM at the
  /// currently-effective KV quantization (see [effectiveKvCacheType]).
  /// Null until a file is picked; 0 when VRAM detection failed (the
  /// dialog hides the hint then).
  int? get maxContextAtCurrentKv {
    final inputs = _recInputs;
    if (inputs == null) return null;
    return maxContextAt(
      inputs: inputs,
      kvCacheType: effectiveKvCacheType,
    );
  }

  String? _error;
  String? get error => _error;

  bool get canLoadModel =>
      _pickedPath != null && _metadata != null && _contextSize != null;

  /// Opens the OS file picker, then runs metadata + VRAM probes and seeds
  /// the recommendation. Safe to call again to pick a different file.
  Future<void> pickFile() async {
    const ggufType = XTypeGroup(label: 'GGUF', extensions: ['gguf']);
    final XFile? file = await openFile(acceptedTypeGroups: [ggufType]);
    if (file == null) return; // user cancelled

    _pickedPath = file.path;
    _metadata = null;
    _vram = null;
    _gpuDeviceIndex = null;
    _recommendation = null;
    _modelLoaded = false;
    _error = null;
    _probing = true;
    notifyListeners();

    try {
      // Free any chat GGUF already resident so the VRAM reading reflects a
      // card with no model loaded — otherwise the new model is measured
      // against the leftovers of the old one and wrongly refused. The freed
      // model lazily reloads on the next chat send if the user cancels.
      await LlmProvider.disposeAllLocalGgufRuntimes();
      // Probes are independent; run them in parallel so the file-pick step
      // doesn't pay the metadata-load + embedder-warmup latencies serially.
      final (probed, vramSnapshot, gpuIndex) = await (
        GgufMetadataProbe.probe(file.path),
        VramProbe(_embedder).read(),
        _detectDiscreteGpuIndex(),
      ).wait;
      _gpuDeviceIndex = gpuIndex;
      final inputs = RecommendationInputs(
        nativeContext: probed.nativeContext,
        layerCount: probed.layerCount,
        embeddingKvSize: probed.embeddingKvSize,
        fileBytes: File(file.path).lengthSync(),
        freeVramBytes: vramSnapshot.freeBytes,
      );
      final rec = recommendLocalGgufConfig(inputs);
      _metadata = probed;
      _vram = vramSnapshot;
      _recInputs = inputs;
      _recommendation = rec;
      // Seed only the context size from the recommendation. KV cache
      // pick stays on Auto (null) so the user starts at the
      // highest-quality KV that fits the recommended ctx —
      // [effectiveKvCacheType] resolves it concretely at use time.
      switch (rec) {
        case RecommendationOk(contextSize: final ctx, kvCacheType: _):
          _contextSize = ctx;
        case RecommendationWarning(
            contextSize: final ctx,
            kvCacheType: _,
            message: final msg,
          ):
          _contextSize = ctx;
          _error = msg;
        case RecommendationError(message: final msg):
          _error = msg;
      }
    } on Exception catch (e, st) {
      LoggingService().error(
        '[LocalGgufDialog] probe failed for ${file.path}',
        e,
        st,
      );
      _error = t.settings.localGguf.readMetadataFailedError(error: '$e');
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  /// Enumerates the backend's GPUs (via the embedder's warmed backend) and
  /// returns the discrete GPU to pin offload to, or null when there's none.
  Future<int?> _detectDiscreteGpuIndex() async {
    await _embedder.init();
    final backend = _embedder.backend;
    if (backend == null) return null;
    final devices = await backend.listGpuDevices();
    final picked = pickDiscreteGpuIndex(devices);
    LoggingService().info(
      '[LocalGgufDialog] GPU devices: '
      '${devices.map((d) => '#${d.index} ${d.name} (${d.type.name}, '
          'free ${d.memoryFreeBytes ~/ (1024 * 1024)} MiB)').join('; ')} '
      '-> pinned ${picked ?? 'none (default device handling)'}',
    );
    return picked;
  }

  void setContextSize(int value) {
    _contextSize = value;
    _modelLoaded = false; // any change invalidates a prior load
    notifyListeners();
  }

  void setKvCacheType(KvCacheType? value) {
    _kvCacheType = value;
    _modelLoaded = false;
    // Re-seed the context for the newly chosen quant. An explicit quant gets
    // the most that fits at it (cheaper KV → more tokens), floored to 512 so
    // it lands on the same number the recommendation would. Auto restores the
    // original recommended context, so reselecting Auto always returns to the
    // value shown right after the file was picked.
    final inputs = _recInputs;
    if (inputs != null) {
      if (value == null) {
        _contextSize = _recommendedContextSize(inputs) ?? _contextSize;
      } else {
        final max = maxContextAt(inputs: inputs, kvCacheType: value);
        if (max > 0) _contextSize = floorContextTo512(max);
      }
    }
    notifyListeners();
  }

  int? _recommendedContextSize(RecommendationInputs inputs) {
    final rec = recommendLocalGgufConfig(inputs);
    return switch (rec) {
      RecommendationOk(contextSize: final ctx) ||
      RecommendationWarning(contextSize: final ctx) => ctx,
      RecommendationError() => null,
    };
  }

  /// Performs a real model load via `LocalGgufProvider.buildRunner` and a
  /// short test inference. Surfaces load errors (corrupt file, OOM) here so
  /// the user sees them before they hit Save.
  Future<void> loadModel() async {
    final path = _pickedPath;
    final ctx = _contextSize;
    if (path == null || ctx == null) return;
    _loadingModel = true;
    _modelLoaded = false;
    _error = null;
    notifyListeners();
    try {
      // Dispose any stale plugin under this path (different ctx/kv) before
      // building the new one — the actual VRAM allocation race fix.
      await LlmProvider.disposeRuntimeFor(path);
      final provider = LlmProvider.of(LLMProviderEnum.localGguf);
      final model = provider.parseModel({'id': p.basename(path)});
      final runner = provider.buildRunner(
        BuildRunnerInputs(
          apiKey: '',
          modelId: model.id,
          model: model,
          paramValues: const {},
          modelPath: path,
          contextSize: ctx,
          kvCacheType: effectiveKvCacheType,
          gpuDeviceIndex: _gpuDeviceIndex,
        ),
      );
      // Tiny test inference to confirm the model actually serves tokens.
      await runner.complete('Hello.');
      _modelLoaded = true;
    } on Exception catch (e, st) {
      LoggingService().error(
        '[LocalGgufDialog] loadModel failed for $path (ctx=$ctx, kv=$_kvCacheType)',
        e,
        st,
      );
      _error = t.settings.localGguf.loadModelFailedError(error: '$e');
    } finally {
      _loadingModel = false;
      notifyListeners();
    }
  }

  /// Builds the [LlmProviderConfig] the dialog returns on Save. Null if the
  /// user hasn't loaded a model yet.
  LlmProviderConfig? buildProfile() {
    final path = _pickedPath;
    final ctx = _contextSize;
    if (!_modelLoaded || path == null || ctx == null) return null;
    final provider = LlmProvider.of(LLMProviderEnum.localGguf);
    final model = provider.parseModel({
      'id': p.basename(path),
      'context_length': ctx,
      'supports_tools': _metadata!.supportsTools,
    });
    return LlmProviderConfig(
      id: UtilsApp.generateId(LLMProviderEnum.localGguf.name),
      apiKey: '',
      providerEnum: LLMProviderEnum.localGguf,
      models: [model],
      modelPath: path,
      contextSize: ctx,
      // Persist the resolved KV (not raw _kvCacheType) so future
      // chat sends use the same KV that loadModel just succeeded
      // with. Storing null/Auto would force the runtime to fall
      // back to llama.cpp's fp16 default, breaking tight-fit loads.
      kvCacheType: effectiveKvCacheType,
      gpuDeviceIndex: _gpuDeviceIndex,
    );
  }

  /// Tells the controller the dialog completed via Save — so [dispose] won't
  /// tear down the runtime we just built. Without this flag, dismissing the
  /// dialog (cancel, Escape, drag-to-dismiss) after a successful
  /// `loadModel` would leak the loaded plugin in VRAM.
  bool _saved = false;
  void markSaved() => _saved = true;

  @override
  void dispose() {
    final path = _pickedPath;
    if (_modelLoaded && !_saved && path != null) {
      unawaited(LlmProvider.disposeRuntimeFor(path));
    }
    super.dispose();
  }
}
