import 'package:cardwave_embeddings/src/engine/embedder.dart';

/// Single entry-point bundling the package's stateful embedder. Held by
/// the app via Provider; `dispose()` unloads the GGUF model file from
/// RAM (and VRAM on CUDA / Vulkan) by delegating to the embedder. Direct
/// field access today; a future `invoke(toolName, args, secrets,
/// cancelToken)` + `listTools()` surface will wrap the same embedder for
/// cross-process MCP deployment.
class CardwaveEmbeddingsModule {
  CardwaveEmbeddingsModule({Embedder? embedder})
    : embedder = embedder ?? Embedder();

  final Embedder embedder;

  Future<void> dispose() => embedder.dispose();
}
