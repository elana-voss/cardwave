import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;

// GGUF metadata keys are prefixed by the model's architecture, e.g. a gemma
// model stores its trained context length under `gemma4.context_length`, not
// `llama.context_length`. We read `general.architecture` first and build the
// real key from it. `llama`/`llm`/`model` stay as fallbacks for files that
// use a generic prefix; reaching the hardcoded defaults instead would size
// the whole VRAM estimate off 4096 ctx / 32 layers for every non-llama model.
const _kFallbackPrefixes = <String>['llama', 'llm', 'model'];

const _kArchKey = 'general.architecture';
const _kNameKey = 'general.name';

// The model's built-in chat template, and the dedicated tool-use variant some
// files ship. Tool support is read from these: a template that never emits
// tool-call markers belongs to a model that wasn't trained to produce them.
const _kChatTemplateKey = 'tokenizer.chat_template';
const _kToolUseTemplateKey = 'tokenizer.chat_template.tool_use';

/// Result of a GGUF metadata probe — everything the dialog needs to drive
/// the recommendation algorithm.
class GgufMetadata {
  const GgufMetadata({
    required this.nativeContext,
    required this.layerCount,
    required this.embeddingKvSize,
    required this.architecture,
    required this.displayName,
    required this.supportsTools,
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

  /// True when the file's chat template emits tool-call markers (or ships a
  /// tool-use variant). Drives whether the local model may be handed tools.
  final bool supportsTools;
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
      final arch = meta[_kArchKey] ?? 'unknown';

      final nativeCtx =
          _archInt(meta, arch, 'context_length', extra: const ['n_ctx']) ??
          4096;
      final layers = _archInt(meta, arch, 'block_count') ?? 32;
      final embedding = _archInt(meta, arch, 'embedding_length') ?? 4096;
      final headCount = _archInt(meta, arch, 'attention.head_count') ?? 32;
      final headCountKv =
          _archInt(meta, arch, 'attention.head_count_kv') ?? headCount;
      // Embedding-size per token for K (and V separately): embedding × kv/head.
      // For MHA models headCountKv == headCount so this equals embedding.
      final kvSize = headCount > 0
          ? (embedding * headCountKv) ~/ headCount
          : embedding;

      return GgufMetadata(
        nativeContext: nativeCtx,
        layerCount: layers,
        embeddingKvSize: kvSize,
        architecture: arch,
        displayName: meta[_kNameKey] ?? p.basenameWithoutExtension(modelPath),
        supportsTools: _detectToolSupport(meta),
      );
    } finally {
      await engine.dispose();
    }
  }

  /// True when the file declares a tool-use template variant, or its main chat
  /// template emits tool-call markers. Mirrors how llama.cpp judges a template
  /// tool-capable: the marker is the model's trained tool-call delimiter, so
  /// its absence means tools handed to the model would come back as plain text.
  static bool _detectToolSupport(Map<String, String> meta) {
    if (meta.containsKey(_kToolUseTemplateKey)) return true;
    final template = meta[_kChatTemplateKey] ?? '';
    return template.contains('tool_call') ||
        template.contains('TOOL_CALLS') ||
        template.contains('tool▁call');
  }

  /// Reads an int metadata value, trying the architecture-prefixed key
  /// (`<arch>.<suffix>`) first, then the generic fallback prefixes, then any
  /// `extra` unprefixed keys. Returns null when no key holds a parseable int.
  static int? _archInt(
    Map<String, String> meta,
    String arch,
    String suffix, {
    List<String> extra = const [],
  }) {
    final keys = [
      '$arch.$suffix',
      for (final prefix in _kFallbackPrefixes) '$prefix.$suffix',
      ...extra,
    ];
    for (final k in keys) {
      final v = meta[k];
      if (v == null) continue;
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
