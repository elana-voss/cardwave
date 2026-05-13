import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Abstract base for provider-specific image generation HTTP clients.
///
/// Implementations take a resolved model id + prompt and return the raw
/// image bytes (PNG/JPEG — caller doesn't care which). Failures are thrown
/// as [ImageGenerationServiceException] so there is a single exception type
/// the mixin layer needs to catch.
abstract class ImageHttpClient {
  const ImageHttpClient();

  /// Generates image bytes. [extras] carries provider/model-specific JSON
  /// body keys resolved upstream by `LlmProvider.imageRequestExtras` —
  /// e.g. `{'aspect_ratio': '16:9'}` for Grok/Flux or `{'size': '1792x1024'}`
  /// for DALL-E 3. Clients merge [extras] into the POST body alongside
  /// `model` / `prompt` / `n` / `response_format`; no per-provider
  /// branching happens inside the client.
  Future<Uint8List> generate({
    required http.Client httpClient,
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String prompt,
    Map<String, dynamic> extras = const {},
  });
}

class ImageGenerationServiceException implements Exception {
  const ImageGenerationServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
