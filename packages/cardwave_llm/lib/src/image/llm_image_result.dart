import 'dart:typed_data';

/// Result of a package-level image generation. Carries the raw bytes the
/// provider produced plus the final tag-list prompt that was sent. The
/// app-side controller persists the bytes and stamps the resulting
/// relative path on the chat message.
class LlmImageResult {
  const LlmImageResult({
    required this.bytes,
    required this.imagePrompt,
    this.thumbnailBytes,
  });

  /// Raw image bytes returned by the provider. Caller chooses the file
  /// extension based on content (`UtilsImage.detectExtension`).
  final Uint8List bytes;

  /// The tag-list prompt actually sent to the image model. Used as
  /// markdown alt text (truncated) and for logging.
  final String imagePrompt;

  /// Pre-computed thumbnail bytes for cards-grid display. Optional —
  /// JPEG providers produce bytes that are already compact enough to
  /// reuse as the thumbnail; PNG providers benefit from a downscaled
  /// thumbnail. Null means "use [bytes] as the thumbnail".
  final Uint8List? thumbnailBytes;
}
