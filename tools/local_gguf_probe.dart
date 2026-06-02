/// Standalone llamadart load probe. Sidesteps Flutter + genkit_llamadart
/// so we can iterate on GPU-offload diagnostics without rebuilding the
/// full app.
///
/// Usage (from `app/`):
///   dart run tools/local_gguf_probe.dart "<path-to-model.gguf>"
///   dart run tools/local_gguf_probe.dart "<path>" --backend=vulkan
///   dart run tools/local_gguf_probe.dart "<path>" --backend=auto --ctx=4608 --kv=q4_0 --mmap=false
///
/// Defaults: backend=auto, ctx=512, kv=f16, mmap=true (matches the
/// embedder's known-working config). Override one flag at a time to
/// isolate which ModelParams setting trips the CPU fallback.
///
/// Prints, in order:
///   1. available backends (file-system check — what DLLs are bundled)
///   2. active backend name post-load (what llama.cpp actually selected)
///   3. resolved GPU layer count (mparams.n_gpu_layers after policy)
///   4. wall-clock load time
/// Then exits.

import 'dart:io';

import 'package:llamadart/llamadart.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/local_gguf_probe.dart <path> [flags]');
    stderr.writeln('Flags: --backend=auto|vulkan|cpu|cuda|metal|hip|blas');
    stderr.writeln('       --ctx=<int>  --kv=f16|q8_0|q4_0  --mmap=true|false');
    stderr.writeln('       --flashattn=auto|enabled|disabled');
    exit(2);
  }

  // ignore: qcheck/avoid_unsafe_collection_methods
  final path = args.first;
  final flags = _parseFlags(args.skip(1));

  if (!File(path).existsSync()) {
    stderr.writeln('Model not found: $path');
    exit(2);
  }

  // Surface llamadart's Dart-side info events to stdout so we see the
  // "Loading model" / "Model loaded successfully" pair plus any error
  // records the loader emits.
  LlamaEngine.configureLogging(level: LlamaLogLevel.info);

  final backend = flags.backend;
  final params = ModelParams(
    contextSize: flags.ctx,
    gpuLayers: ModelParams.maxGpuLayers,
    preferredBackend: backend,
    mainGpu: flags.mainGpu,
    splitMode: flags.splitMode,
    flashAttention: flags.flashAttention,
    cacheTypeK: flags.kv,
    cacheTypeV: flags.kv,
    useMmap: flags.useMmap,
    batchSize: flags.batch,
    microBatchSize: flags.batch,
  );

  stdout.writeln('--- probe config ---');
  stdout.writeln('path:            $path');
  stdout.writeln('backend:         ${backend.name}');
  stdout.writeln('ctx:             ${flags.ctx}');
  stdout.writeln('kv:              ${flags.kv.name}');
  stdout.writeln('flashAttention:  ${flags.flashAttention.name}');
  stdout.writeln('useMmap:         ${flags.useMmap}');

  final engine = LlamaEngine(LlamaBackend());
  await engine.setNativeLogLevel(LlamaLogLevel.info);

  final llamaBackend = engine.backend;

  // Pre-load: available backend modules (file existence check).
  if (llamaBackend is BackendAvailability) {
    final available =
        await (llamaBackend as BackendAvailability).getAvailableBackends();
    stdout.writeln('pre-load available backends: $available');
  }

  final stopwatch = Stopwatch()..start();
  try {
    await engine.loadModel(path, modelParams: params);
  } on Exception catch (e, st) {
    stopwatch.stop();
    stderr.writeln('LOAD FAILED after ${stopwatch.elapsedMilliseconds} ms: $e');
    stderr.writeln(st);
    await engine.dispose();
    exit(1);
  }
  stopwatch.stop();

  // Post-load: what llama.cpp actually selected.
  final activeName = await llamaBackend.getBackendName();
  final resolvedLayers = llamaBackend is BackendRuntimeDiagnostics
      ? await (llamaBackend as BackendRuntimeDiagnostics).getResolvedGpuLayers()
      : null;

  stdout.writeln('--- result ---');
  stdout.writeln('load time:       ${stopwatch.elapsedMilliseconds} ms');
  stdout.writeln('active backend:  $activeName');
  stdout.writeln('resolved layers: $resolvedLayers');
  stdout.writeln('VERDICT:         '
      '${activeName.toLowerCase() == 'cpu' ? 'CPU (no offload)' : 'GPU offload to $activeName'}');

  // Inference probe: exercise actual matmul/attention kernels so we
  // catch failures that only surface during compute (e.g. Blackwell
  // cooperative-matrix crashes inside ggml-vulkan). Picks the cheapest
  // call available — embedBatch for an embedder, otherwise a 1-token
  // generation from a one-message prompt. Crashes here mean the
  // backend loaded but doesn't survive a real workload.
  stdout.writeln('--- inference probe ---');
  final inferStopwatch = Stopwatch()..start();
  try {
    // Try embedding first (returns immediately for embedder-like
    // models). If the model doesn't expose embeddings, fall back to a
    // short text generation. Either path runs real GPU kernels.
    try {
      final embeddings = await engine.embedBatch(['cardwave probe']);
      inferStopwatch.stop();
      final dim = embeddings.isEmpty ? 0 : embeddings.first.length;
      stdout.writeln('embed ok:        $dim-dim, '
          '${inferStopwatch.elapsedMilliseconds} ms');
    } on Exception {
      // Not an embedder. Try generation instead.
      final chunks = <String>[];
      await for (final chunk in engine.generate(
        'Say "ok".',
        params: const GenerationParams(maxTokens: 4),
      )) {
        chunks.add(chunk);
      }
      inferStopwatch.stop();
      stdout.writeln('generate ok:     '
          '${inferStopwatch.elapsedMilliseconds} ms, '
          'output=${chunks.join().trim()}');
    }
  } on Exception catch (e, st) {
    inferStopwatch.stop();
    stderr.writeln('INFERENCE FAILED after '
        '${inferStopwatch.elapsedMilliseconds} ms: $e');
    stderr.writeln(st);
    await engine.dispose();
    exit(1);
  }

  await engine.dispose();
}

class _Flags {
  const _Flags({
    required this.backend,
    required this.ctx,
    required this.kv,
    required this.flashAttention,
    required this.useMmap,
    required this.batch,
    required this.mainGpu,
    required this.splitMode,
  });

  final GpuBackend backend;
  final int ctx;
  final KvCacheType kv;
  final FlashAttention flashAttention;
  final bool useMmap;
  final int batch;
  final int mainGpu;
  final ModelSplitMode splitMode;
}

_Flags _parseFlags(Iterable<String> raw) {
  GpuBackend backend = GpuBackend.auto;
  int ctx = 512;
  KvCacheType kv = KvCacheType.f16;
  FlashAttention flashAttention = FlashAttention.auto;
  bool useMmap = true;
  int batch = 512;
  int mainGpu = 0;
  ModelSplitMode splitMode = ModelSplitMode.layer;

  for (final arg in raw) {
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq < 0) continue;
    final key = arg.substring(2, eq);
    final val = arg.substring(eq + 1);
    switch (key) {
      case 'backend':
        backend = GpuBackend.values.firstWhere(
          (b) => b.name == val,
          orElse: () => throw ArgumentError('Unknown backend: $val'),
        );
      case 'ctx':
        ctx = int.parse(val);
      case 'kv':
        kv = KvCacheType.values.firstWhere(
          (k) => k.name == val,
          orElse: () => throw ArgumentError('Unknown kv: $val'),
        );
      case 'flashattn':
        flashAttention = FlashAttention.values.firstWhere(
          (f) => f.name == val,
          orElse: () => throw ArgumentError('Unknown flashattn: $val'),
        );
      case 'mmap':
        useMmap = val == 'true' || val == '1';
      case 'batch':
        batch = int.parse(val);
      case 'maingpu':
        mainGpu = int.parse(val);
      case 'split':
        splitMode = ModelSplitMode.values.firstWhere(
          (s) => s.name == val,
          orElse: () => throw ArgumentError('Unknown split: $val'),
        );
    }
  }
  return _Flags(
    backend: backend,
    ctx: ctx,
    kv: kv,
    flashAttention: flashAttention,
    useMmap: useMmap,
    batch: batch,
    mainGpu: mainGpu,
    splitMode: splitMode,
  );
}
