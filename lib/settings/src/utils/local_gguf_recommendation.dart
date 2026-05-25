import 'package:cardwave/settings/src/utils/local_gguf_strings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

// VRAM weight bytes are typically ~85–95% of the GGUF file size; 5% padding
// keeps the estimate on the safe side.
const double _kModelOverhead = 1.05;
const int _kComputeBudgetBytes = 350 * 1024 * 1024;
// q4_0 packs 32 weights into 16 bytes (4-bit weight + 2-byte scale per block).
const double _kBytesPerValueFp16 = 2.0;
const double _kBytesPerValueQ80 = 1.0625;
const double _kBytesPerValueQ40 = 0.5625;

const int _kMinContextFloor = 2048;
const int _kFp16MinContext = 4096;

/// Result of the recommendation calculation.
sealed class LocalGgufRecommendation {
  const LocalGgufRecommendation();
}

class RecommendationOk extends LocalGgufRecommendation {
  const RecommendationOk({
    required this.contextSize,
    required this.kvCacheType,
  });
  final int contextSize;
  final KvCacheType kvCacheType;
}

class RecommendationWarning extends LocalGgufRecommendation {
  const RecommendationWarning({
    required this.contextSize,
    required this.kvCacheType,
    required this.message,
  });
  final int contextSize;
  final KvCacheType kvCacheType;
  final String message;
}

class RecommendationError extends LocalGgufRecommendation {
  const RecommendationError(this.message);
  final String message;
}

/// Inputs to the recommendation algorithm. All sizes in bytes / tokens.
class RecommendationInputs {
  const RecommendationInputs({
    required this.nativeContext,
    required this.layerCount,
    required this.embeddingKvSize,
    required this.fileBytes,
    required this.freeVramBytes,
  });

  final int nativeContext;
  final int layerCount;
  final int embeddingKvSize;
  final int fileBytes;
  final int freeVramBytes;
}

/// Picks a `(contextSize, kvCacheType)` pair that fits the model + chosen
/// KV quant in the available VRAM. Falls back from fp16 → q4_0 as needed.
LocalGgufRecommendation recommendLocalGgufConfig(RecommendationInputs i) {
  // `freeVramBytes == 0` means we couldn't detect available VRAM (e.g. the
  // backend doesn't expose memory queries on this platform). Skip the
  // doesn't-fit check, default to a safe context, and let the user adjust.
  if (i.freeVramBytes == 0) {
    return RecommendationOk(
      contextSize: i.nativeContext < _kFp16MinContext
          ? i.nativeContext
          : _kFp16MinContext,
      kvCacheType: KvCacheType.f16,
    );
  }

  final modelBytes = (i.fileBytes * _kModelOverhead).round();
  final availableForKv = i.freeVramBytes - modelBytes - _kComputeBudgetBytes;

  if (availableForKv <= 0) {
    final neededMb = (modelBytes + _kComputeBudgetBytes) ~/ (1024 * 1024);
    final freeMb = i.freeVramBytes ~/ (1024 * 1024);
    return RecommendationError(
      modelTooLargeForVramMessage(neededMb: neededMb, freeMb: freeMb),
    );
  }

  final ctxAtFp16 = _maxCtxAt(
    availableForKv: availableForKv,
    layerCount: i.layerCount,
    embeddingKvSize: i.embeddingKvSize,
    bytesPerValue: _kBytesPerValueFp16,
  );
  if (ctxAtFp16 >= i.nativeContext) {
    return RecommendationOk(
      contextSize: i.nativeContext,
      kvCacheType: KvCacheType.f16,
    );
  }
  if (ctxAtFp16 >= _kFp16MinContext) {
    return RecommendationOk(
      contextSize: _floorTo512(ctxAtFp16),
      kvCacheType: KvCacheType.f16,
    );
  }

  final ctxAtQ40 = _maxCtxAt(
    availableForKv: availableForKv,
    layerCount: i.layerCount,
    embeddingKvSize: i.embeddingKvSize,
    bytesPerValue: _kBytesPerValueQ40,
  );
  if (ctxAtQ40 >= i.nativeContext) {
    return RecommendationOk(
      contextSize: i.nativeContext,
      kvCacheType: KvCacheType.q4_0,
    );
  }
  if (ctxAtQ40 >= _kMinContextFloor) {
    return RecommendationOk(
      contextSize: _floorTo512(ctxAtQ40),
      kvCacheType: KvCacheType.q4_0,
    );
  }

  return RecommendationWarning(
    contextSize: _kMinContextFloor,
    kvCacheType: KvCacheType.q4_0,
    message: modelBarelyFitsMessage(minimumContext: _kMinContextFloor),
  );
}

// q8_0 sits between f16 and q4_0 — exposed in the UI picker but not picked
// by the auto-recommendation (we prefer the two endpoints).
double bytesPerKvValue(KvCacheType type) => switch (type) {
  KvCacheType.f16 => _kBytesPerValueFp16,
  KvCacheType.q8_0 => _kBytesPerValueQ80,
  KvCacheType.q4_0 => _kBytesPerValueQ40,
};

/// Largest context size that fits in the available VRAM at the chosen
/// KV quantization, using the same model + free-VRAM inputs as
/// [recommendLocalGgufConfig]. Capped at the model's native context.
/// Returns 0 when VRAM detection failed (`freeVramBytes == 0`) or the
/// model wouldn't fit at all; the caller decides whether to surface a
/// hint or an error.
int maxContextAt({
  required RecommendationInputs inputs,
  required KvCacheType kvCacheType,
}) {
  if (inputs.freeVramBytes == 0) return 0;
  final modelBytes = (inputs.fileBytes * _kModelOverhead).round();
  final availableForKv =
      inputs.freeVramBytes - modelBytes - _kComputeBudgetBytes;
  if (availableForKv <= 0) return 0;
  final raw = _maxCtxAt(
    availableForKv: availableForKv,
    layerCount: inputs.layerCount,
    embeddingKvSize: inputs.embeddingKvSize,
    bytesPerValue: bytesPerKvValue(kvCacheType),
  );
  return raw > inputs.nativeContext ? inputs.nativeContext : raw;
}

int _maxCtxAt({
  required int availableForKv,
  required int layerCount,
  required int embeddingKvSize,
  required double bytesPerValue,
}) {
  // KV bytes per token = layers × embeddingKv × 2 (K + V) × bytesPerValue
  final perToken = layerCount * embeddingKvSize * 2 * bytesPerValue;
  if (perToken <= 0) return 0;
  return (availableForKv / perToken).floor();
}

int _floorTo512(int v) => (v ~/ 512) * 512;
