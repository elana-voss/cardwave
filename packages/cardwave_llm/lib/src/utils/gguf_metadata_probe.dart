import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;

/// GGUF metadata keys we read (spec-defined; not all GGUF files set all keys).
const _kContextLengthKeys = <String>[
  'llama.context_length',
  'llm.context_length',
  'model.context_length',
  'n_ctx',
];

const _kBlockCountKeys = <String>[
  'llama.block_count',
  'llm.block_count',
  'model.block_count',
];

const _kEmbeddingLengthKeys = <String>[
  'llama.embedding_length',
  'llm.embedding_length',
  'model.embedding_length',
];

const _kHeadCountKvKeys = <String>[
  'llama.attention.head_count_kv',
  'llm.attention.head_count_kv',
  'model.attention.head_count_kv',
];

const _kHeadCountKeys = <String>[
  'llama.attention.head_count',
  'llm.attention.head_count',
  'model.attention.head_count',
];

const _kArchKey = 'general.architecture';
const _kNameKey = 'general.name';

/// Result of a GGUF metadata probe — everything the dialog needs to drive
/// the recommendation algorithm.
class GgufMetadata {
  const GgufMetadata({
    required this.nativeContext,
    required this.layerCount,
    required this.embeddingKvSize,
    required this.architecture,
    required this.displayName,
  });

  /// `n_ctx_train` from the file — the model's trained context length.
  final int nativeContext;

  /// Number of transformer layers (`block_count`).
  final int layerCount;

  /// Per-token K (or V) cache size in elements, accounting for grouped-query
  /// attention. Computed from embedding_length × head_count_kv / head_count.
  /// Used by the recommendation formula to size KV cache budgets.
  final int embeddingKvSize;

  /// Architecture name from `general.architecture` (e.g. "llama").
  final String architecture;

  /// Human-readable name from `general.name`, or the file basename if absent.
  final String displayName;
}

/// Loads a GGUF just long enough to read its header, then disposes. Uses
/// `gpuLayers: 0` and `useMmap: true` so the read pages in only the
/// metadata block (typically &lt;1 MB), not the full weights.
class GgufMetadataProbe {
  const GgufMetadataProbe._();

  static Future<GgufMetadata> probe(String modelPath) async {
    final engine = LlamaEngine(LlamaBackend());
    try {
      await engine.loadModel(
        modelPath,
        modelParams: const ModelParams(
          contextSize: 512,
          gpuLayers: 0,
          useMmap: true,
        ),
      );
      final meta = await engine.getMetadata();

      final nativeCtx = _firstInt(meta, _kContextLengthKeys) ?? 4096;
      final layers = _firstInt(meta, _kBlockCountKeys) ?? 32;
      final embedding = _firstInt(meta, _kEmbeddingLengthKeys) ?? 4096;
      final headCount = _firstInt(meta, _kHeadCountKeys) ?? 32;
      final headCountKv = _firstInt(meta, _kHeadCountKvKeys) ?? headCount;
      // Embedding-size per token for K (and V separately): embedding × kv/head.
      // For MHA models headCountKv == headCount so this equals embedding.
      final kvSize = headCount > 0
          ? (embedding * headCountKv) ~/ headCount
          : embedding;

      return GgufMetadata(
        nativeContext: nativeCtx,
        layerCount: layers,
        embeddingKvSize: kvSize,
        architecture: meta[_kArchKey] ?? 'unknown',
        displayName: meta[_kNameKey] ?? p.basenameWithoutExtension(modelPath),
      );
    } finally {
      await engine.dispose();
    }
  }

  static int? _firstInt(Map<String, String> meta, List<String> keys) {
    for (final k in keys) {
      final v = meta[k];
      if (v == null) continue;
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
