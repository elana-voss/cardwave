import 'dart:convert';
import 'dart:typed_data';

import 'package:cardwave_llm/src/image/clients/image_http_client.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/utils/utils_llm.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class OpenAiCompatibleImageClient extends ImageHttpClient {
  const OpenAiCompatibleImageClient();

  @override
  Future<Uint8List> generate({
    required http.Client httpClient,
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String prompt,
    Map<String, dynamic> extras = const {},
  }) async {
    final uri = Uri.parse(p.url.join(baseUrl, 'images/generations'));
    final body = jsonEncode({
      'model': modelId,
      'prompt': prompt,
      'n': 1,
      'response_format': 'b64_json',
      ...extras,
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
    final dataList = decoded['data'] as List<dynamic>?;
    if (dataList == null || dataList.isEmpty) {
      throw const ImageGenerationServiceException(
        'Image provider response missing "data" array.',
      );
    }
    final first = dataList.first as Map<String, dynamic>;

    // Prefer inline base64; fall back to a URL fetch if the provider returned
    // one instead. Some providers honour response_format, others don't.
    final b64 = first['b64_json'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      imageLogger.info(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.imageGen,
          title: 'INCOMING',
          body: '\nStatus: 200 (b64)\nBase64Len: ${b64.length}',
          modelId: modelId,
        ),
      );
      return base64Decode(b64);
    }

    final url = first['url'] as String?;
    if (url != null && url.isNotEmpty) {
      imageLogger.info(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.imageGen,
          title: 'INCOMING',
          body: '\nStatus: 200 (url)\nURL: $url',
          modelId: modelId,
        ),
      );
      final imgResponse = await httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (imgResponse.statusCode != 200) {
        throw ImageGenerationServiceException(
          'Failed to download image from $url',
          statusCode: imgResponse.statusCode,
        );
      }
      return imgResponse.bodyBytes;
    }

    throw const ImageGenerationServiceException(
      'Image provider response had neither b64_json nor url.',
    );
  }
}
