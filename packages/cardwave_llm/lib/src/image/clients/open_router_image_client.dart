import 'dart:convert';
import 'dart:typed_data';

import 'package:cardwave_llm/src/image/clients/image_http_client.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/utils/utils_llm.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// OpenRouter does not expose the OpenAI `/images/generations` endpoint.
/// Image-capable OR models (Gemini Nano Banana family, GPT-5 image, etc.)
/// are invoked through `/chat/completions` with `modalities: ["image","text"]`.
/// The image is returned inside `choices[0].message.images[0].image_url.url`
/// as a base64 data URL (`data:image/png;base64,...`).
class OpenRouterImageClient extends ImageHttpClient {
  const OpenRouterImageClient();

  @override
  Future<Uint8List> generate({
    required http.Client httpClient,
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String prompt,
    Map<String, dynamic> extras = const {},
  }) async {
    // `extras` is intentionally ignored here — OR's image-capable models
    // run through `/chat/completions` with `modalities: ["image","text"]`
    // and that schema doesn't reliably accept `aspect_ratio` / `size`.
    // `LlmProvider.of(openrouter).imageRequestExtras` always returns
    // `const {}` so callers pass an empty map regardless.
    final uri = Uri.parse(p.url.join(baseUrl, 'chat/completions'));
    final body = jsonEncode({
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'modalities': ['image', 'text'],
    });
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    imageLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.imageGen,
        title: 'OUTGOING',
        body:
            '\nPOST $uri\nModel: $modelId\nPromptLen: ${prompt.length}\nPrompt: $prompt',
        modelId: modelId,
      ),
    );

    final response = await httpClient
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(minutes: 2));
    final status = response.statusCode;

    if (status != 200) {
      imageLogger.severe(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.imageGen,
          title: 'INCOMING',
          body: '\nStatus: $status\nBody: ${response.body}',
          modelId: modelId,
        ),
      );
      throw ImageGenerationServiceException(
        UtilsLlm.extractUserFriendlyError(response.body),
        statusCode: status,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const ImageGenerationServiceException(
        'OpenRouter response had no choices.',
      );
    }
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final images = message?['images'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      throw const ImageGenerationServiceException(
        'OpenRouter response had no image part. The model may not support '
        'image output — check the Image preset in Settings → AI.',
      );
    }
    final first = images.first as Map<String, dynamic>;
    final imageUrlObj = first['image_url'] as Map<String, dynamic>?;
    final dataUrl = imageUrlObj?['url'] as String?;
    if (dataUrl == null || dataUrl.isEmpty) {
      throw const ImageGenerationServiceException(
        'OpenRouter response image_url was missing or empty.',
      );
    }

    imageLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.imageGen,
        title: 'INCOMING',
        body: '\nStatus: 200 (openrouter)\nDataUrlLen: ${dataUrl.length}',
        modelId: modelId,
      ),
    );

    // Data URL shape: `data:image/<fmt>;base64,<payload>`.
    // Strip everything up to and including the first comma; whatever's
    // left is the base64 payload. If there's no comma, treat the whole
    // string as the payload (some providers elide the prefix).
    final commaIdx = dataUrl.indexOf(',');
    final b64 = commaIdx >= 0 ? dataUrl.substring(commaIdx + 1) : dataUrl;
    return base64Decode(b64);
  }
}
