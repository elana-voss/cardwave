import 'dart:convert';

/// Stable, non-cryptographic string hash for cache keys and sidecar
/// invalidation. Paired 32-bit ints keep it correct on web's 53-bit int.
class UtilsHash {
  const UtilsHash._();

  /// FNV-1a 64-bit, 16-char lowercase hex.
  static String fnv1a64Hex(String input) {
    var hi = 0xcbf29ce4;
    var lo = 0x84222325;
    for (final b in utf8.encode(input)) {
      lo = (lo ^ b) & 0xffffffff;
      final mulLo = lo * 0x1b3;
      final newLo = mulLo & 0xffffffff;
      final newHi =
          ((lo & 0xffffff) * 0x100 + hi * 0x1b3 + (mulLo ~/ 0x100000000)) &
          0xffffffff;
      lo = newLo;
      hi = newHi;
    }
    return hi.toRadixString(16).padLeft(8, '0') +
        lo.toRadixString(16).padLeft(8, '0');
  }
}
