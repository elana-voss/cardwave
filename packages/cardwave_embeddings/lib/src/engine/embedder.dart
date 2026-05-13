import 'dart:io' show Directory, File;

import 'package:cardwave_embeddings/src/models/embed_task_enum.dart';
import 'package:cardwave_embeddings/src/models/embeddings_exception.dart';
import 'package:cardwave_embeddings/src/utils/embedder_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device text embedder + tokenizer around `llamadart`. Held by
/// [CardwaveEmbeddingsModule] as a long-lived field for the model-load
/// cache; consumers receive it via constructor injection.
class Embedder {
  LlamaEngine? _engine;
  Future<void>? _initFuture;

  bool get isReady => _engine != null;

  /// Caller must serialize: do not call while `embed` / `chunkByTokens` are
  /// in flight, or the native engine could free model weights mid-inference.
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _initFuture = null;
    if (engine != null) {
      await engine.dispose();
    }
  }

  /// Idempotent. Concurrent callers share the same in-flight init future;
  /// on failure the cache resets so retry can succeed.
  Future<void> init() {
    if (_engine != null) return Future<void>.value();
    return _initFuture ??= _runInit();
  }

  Future<void> _runInit() async {
    final LlamaEngine engine;
    try {
      final modelSource = kIsWeb ? _webModelUrl() : await _extractAsset();
      engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(modelSource, modelParams: _modelParams());
    } on Exception catch (e) {
      _initFuture = null;
      throw EmbeddingsException(
        'Failed to initialize on-device embedder.',
        cause: e,
      );
    }
    // dispose() nulls _initFuture; if it ran while we were loading, drop
    // the fresh engine instead of leaving it loaded with no owner.
    if (_initFuture == null) {
      await engine.dispose();
      return;
    }
    _engine = engine;
  }

  ModelParams _modelParams() => kIsWeb
      ? const ModelParams(
          contextSize: embeddingsModelContextTokens,
          preferredBackend: GpuBackend.cpu,
        )
      : const ModelParams(contextSize: embeddingsModelContextTokens);

  /// Builds the HTTP URL where the bundled GGUF asset is served. Flutter
  /// web serves package assets at
  /// `<origin>/assets/packages/<pkg>/<asset-path>`; a pubspec entry
  /// `assets/models/foo.gguf` in `cardwave_embeddings` lands at
  /// `<origin>/assets/packages/cardwave_embeddings/assets/models/foo.gguf`.
  /// If a future Flutter release breaks this convention, fall back to
  /// AssetManifest-based lookup.
  String _webModelUrl() {
    const path =
        'assets/packages/cardwave_embeddings/assets/models/$embeddingsModelFilename';
    return Uri.base.resolve(path).toString();
  }

  /// 384-dim L2-normalized embedding for [text] under [task].
  Future<Float32List> embedOne(
    String text, {
    required EmbedTaskEnum task,
  }) async {
    final results = await embed([text], task: task);
    // `embed` yields one embedding per input string, so a single-element
    // request always produces a single-element result.
    // ignore: qcheck/avoid_unsafe_collection_methods
    return results.first;
  }

  /// One embedding per input string (order preserved). e5 prefixes are
  /// applied per [EmbedTaskEnum].
  Future<List<Float32List>> embed(
    List<String> texts, {
    required EmbedTaskEnum task,
  }) async {
    await init();
    final engine = _engine!;
    try {
      final prefix = task.prefix;
      final prefixed = texts.map((t) => '$prefix$t').toList();
      final response = await engine.embedBatch(prefixed);
      return response.map(Float32List.fromList).toList();
    } on Exception catch (e) {
      throw EmbeddingsException('Embedding generation failed.', cause: e);
    }
  }

  /// Splits [text] into chunks each tokenizing to at most
  /// [embeddingsMaxTokensPerChunk] tokens of raw input. The cap lives on
  /// the package side because it's tied to the model's BERT context
  /// (512 trained position embeddings minus headroom for the e5 task
  /// prefix and BERT's [CLS]/[SEP] specials). Recursive bisection by
  /// character midpoint.
  Future<List<String>> chunkByTokens(String text) async {
    await init();
    if (text.isEmpty) return const [];
    return _bisect(text, embeddingsMaxTokensPerChunk);
  }

  Future<List<String>> _bisect(String text, int maxTokens) async {
    final engine = _engine!;
    final count = await engine.getTokenCount(text);
    if (count <= maxTokens) return [text];
    if (text.length <= 1) return [text]; // unsplittable, accept the overflow
    final mid = _safeMidpoint(text);
    final left = await _bisect(text.substring(0, mid), maxTokens);
    final right = await _bisect(text.substring(mid), maxTokens);
    return [...left, ...right];
  }

  /// Midpoint of [text] that never lands inside a UTF-16 surrogate pair.
  /// Splitting between a high and low surrogate produces malformed UTF-16
  /// strings that mistokenize or throw at the FFI boundary. Cards contain
  /// emoji and rare CJK that use surrogate pairs.
  int _safeMidpoint(String text) {
    final mid = text.length ~/ 2;
    // A low surrogate at `mid` means `mid - 1` is its high surrogate.
    // Move the split back by one to keep the pair on the left half.
    if (mid > 0) {
      final unit = text.codeUnitAt(mid);
      if (unit >= 0xDC00 && unit <= 0xDFFF) return mid - 1;
    }
    return mid;
  }

  /// Writes the bundled package asset to OS-managed cache space if not
  /// already present, returning the absolute path. The OS may evict; the
  /// module re-extracts on the next call. `LlamaEngine.loadModel` requires
  /// an absolute filesystem path — Flutter asset URIs are not accepted.
  Future<String> _extractAsset() async {
    final cacheDir = await getApplicationCacheDirectory();
    final dir = Directory(p.join(cacheDir.path, 'cardwave_embeddings'))
      ..createSync(recursive: true);
    final target = p.join(dir.path, embeddingsModelFilename);
    final file = File(target);
    if (file.existsSync()) return target;
    final bytes = await rootBundle.load(
      'packages/cardwave_embeddings/assets/models/$embeddingsModelFilename',
    );
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return target;
  }
}
