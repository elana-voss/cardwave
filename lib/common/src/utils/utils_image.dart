import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Stateless image utilities: thumbnail generation, format detection,
/// sidecar path convention.
class UtilsImage {
  const UtilsImage._();

  /// Default width (pixels) for generated thumbnails.
  static const int thumbnailWidth = 350;

  /// Returns the thumbnail sidecar path for a given original path.
  ///
  /// Always uses `.thumb.png` because [generateThumbnailBytes] outputs PNG
  /// regardless of the source format.
  ///
  /// Example: `'foo/img-xyz.jpg'` → `'foo/img-xyz.thumb.png'`
  static String thumbnailPathFor(String originalPath) {
    final withoutExt = p.posix.withoutExtension(originalPath);
    return '$withoutExt.thumb.png';
  }

  /// Detects image format from the first bytes of [data].
  ///
  /// Returns `'.jpg'` for JPEG (`FF D8 FF`), `'.png'` for PNG
  /// (`89 50 4E 47`). Falls back to `'.png'` if unrecognized.
  static String detectExtension(Uint8List data) {
    if (data.length >= 3 &&
        data.first == 0xFF &&
        data[1] == 0xD8 &&
        data[2] == 0xFF) {
      return '.jpg';
    }
    return '.png';
  }

  /// Generates a thumbnail from raw image bytes.
  ///
  /// Returns PNG-encoded bytes scaled to [targetWidth] pixels wide
  /// (aspect ratio preserved), or `null` if decoding fails.
  static Future<Uint8List?> generateThumbnailBytes(
    Uint8List sourceBytes, {
    int targetWidth = thumbnailWidth,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        sourceBytes,
        targetWidth: targetWidth,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      codec.dispose();
      return byteData?.buffer.asUint8List();
    } on Exception catch (e) {
      debugPrint('UtilsImage.generateThumbnailBytes failed: $e');
      return null;
    }
  }
}
