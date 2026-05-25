import 'dart:io';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Snapshot of GPU memory at a point in time. Both values in bytes.
typedef VramSnapshot = ({int totalBytes, int freeBytes});

/// Reads free/total VRAM by piggy-backing on the embedder's already-warmed
/// llama.cpp backend. Avoids a separate engine warmup just for the query.
/// Lives in `app/lib/` (not `cardwave_llm`) because cardwave_llm does not
/// depend on cardwave_embeddings, and inverting that dep would be wrong.
class VramProbe {
  const VramProbe(this._embedder);
  final Embedder _embedder;

  /// Tries the embedder's backend first; on zeros (Vulkan can return all-zero
  /// here even when the GPU is free), falls back to `nvidia-smi`. Returns
  /// `(0, 0)` if neither produced a number.
  Future<VramSnapshot> read() async {
    await _embedder.init();
    final backend = _embedder.backend;
    if (backend != null) {
      final info = await backend.getVramInfo();
      if (info.total > 0) {
        return (totalBytes: info.total, freeBytes: info.free);
      }
    }
    return await _nvidiaSmiSnapshot() ?? (totalBytes: 0, freeBytes: 0);
  }

  /// Shells out to `nvidia-smi --query-gpu=memory.total,memory.free ...`.
  /// NVIDIA-only, but it's the most reliable fallback for the common case.
  /// Returns null if nvidia-smi isn't on PATH or fails for any reason.
  Future<VramSnapshot?> _nvidiaSmiSnapshot() async {
    if (kIsWeb) return null;
    try {
      final result = await Process.run('nvidia-smi', const [
        '--query-gpu=memory.total,memory.free',
        '--format=csv,noheader,nounits',
      ]);
      if (result.exitCode != 0) return null;
      final firstLine = (result.stdout as String).trim().split('\n').first;
      final parts = firstLine.split(',').map((s) => s.trim()).toList();
      if (parts.length != 2) return null;
      final totalMb = int.tryParse(parts[0]);
      final freeMb = int.tryParse(parts[1]);
      if (totalMb == null || freeMb == null || totalMb <= 0) return null;
      return (
        totalBytes: totalMb * 1024 * 1024,
        freeBytes: freeMb * 1024 * 1024,
      );
    } on Exception {
      return null;
    }
  }
}
