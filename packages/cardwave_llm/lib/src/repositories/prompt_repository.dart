import 'package:flutter/services.dart' show rootBundle;

class PromptRepository {
  final Map<String, String> _prompts = {};

  // Flutter exposes package assets at "packages/<pkg>/<asset>" via rootBundle.
  static const _assetDir = 'packages/cardwave_llm/assets/prompts';

  static const _files = {
    'description_preview': 'description_preview.txt',
    'taxonomy_tagging': 'taxonomy_tagging.txt',
    'prose_compacting': 'prose_compacting.txt',
    'prose_proofread': 'prose_proofread.txt',
    'translation': 'translation.txt',
    'unlimited_mode': 'unlimited_mode.txt',
    'scenario_mode': 'scenario_mode.txt',
    'test_message': 'test_message.txt',
    'continue_chat': 'continue_chat.txt',
    'impersonate_user': 'impersonate_user.txt',
    'improve_user_message_pre_history': 'improve_user_message_pre_history.txt',
    'improve_user_message_post_history':
        'improve_user_message_post_history.txt',
    'image_gen_character': 'image_gen_character.txt',
    'image_gen_face': 'image_gen_face.txt',
    'image_gen_scenario': 'image_gen_scenario.txt',
    'image_gen_last_message': 'image_gen_last_message.txt',
    'image_gen_background': 'image_gen_background.txt',
    'image_gen_free': 'image_gen_free.txt',
    'image_gen_selfie': 'image_gen_selfie.txt',
    'image_gen_nsfw_filter': 'image_gen_nsfw_filter.txt',
    'tool_advertisement_preamble': 'tool_advertisement_preamble.txt',
    'tool_send_selfie_advertisement': 'tool_send_selfie_advertisement.txt',
    'tool_send_video_advertisement': 'tool_send_video_advertisement.txt',
    'tool_fetch_website_advertisement': 'tool_fetch_website_advertisement.txt',
    'tool_suggest_name_advertisement': 'tool_suggest_name_advertisement.txt',
    'audio_gen_music': 'audio_gen_music.txt',
    'video_test': 'video_test.txt',
    'video_gen_character': 'video_gen_character.txt',
    'video_gen_face': 'video_gen_face.txt',
    'video_gen_scenario': 'video_gen_scenario.txt',
    'video_gen_last_message': 'video_gen_last_message.txt',
    'video_gen_background': 'video_gen_background.txt',
    'video_gen_free': 'video_gen_free.txt',
    'video_gen_selfie': 'video_gen_selfie.txt',
    'video_gen_nsfw_filter': 'video_gen_nsfw_filter.txt',
  };

  Future<void> init() async {
    for (final entry in _files.entries) {
      _prompts[entry.key] = await rootBundle.loadString(
        '$_assetDir/${entry.value}',
      );
    }
  }

  String _get(String key) {
    final value = _prompts[key];
    if (value == null) {
      throw StateError(
        'PromptRepository not initialized or missing prompt "$key". '
        'Call init() before accessing prompts.',
      );
    }
    return value;
  }

  String get descriptionPreview => _get('description_preview');
  String get taxonomyTagging => _get('taxonomy_tagging');
  String get proseCompacting => _get('prose_compacting');
  String get proseProofread => _get('prose_proofread');
  String get translation => _get('translation');
  String get unlimitedMode => _get('unlimited_mode');
  String get scenarioMode => _get('scenario_mode');
  String get testMessage => _get('test_message');
  String get continueChat => _get('continue_chat');
  String get impersonateUser => _get('impersonate_user');
  String get improveUserMessagePreHistory =>
      _get('improve_user_message_pre_history');
  String get improveUserMessagePostHistory =>
      _get('improve_user_message_post_history');
  String get imageGenCharacter => _get('image_gen_character');
  String get imageGenFace => _get('image_gen_face');
  String get imageGenScenario => _get('image_gen_scenario');
  String get imageGenLastMessage => _get('image_gen_last_message');
  String get imageGenBackground => _get('image_gen_background');
  String get imageGenFree => _get('image_gen_free');
  String get imageGenSelfie => _get('image_gen_selfie');
  String get imageGenNsfwFilter => _get('image_gen_nsfw_filter');
  String get toolAdvertisementPreamble => _get('tool_advertisement_preamble');
  String get toolSendSelfieAdvertisement =>
      _get('tool_send_selfie_advertisement');
  String get toolSendVideoAdvertisement =>
      _get('tool_send_video_advertisement');
  String get toolFetchWebsiteAdvertisement =>
      _get('tool_fetch_website_advertisement');
  String get toolSuggestNameAdvertisement =>
      _get('tool_suggest_name_advertisement');
  String get audioGenMusic => _get('audio_gen_music');
  String get videoTest => _get('video_test');
  String get videoGenCharacter => _get('video_gen_character');
  String get videoGenFace => _get('video_gen_face');
  String get videoGenScenario => _get('video_gen_scenario');
  String get videoGenLastMessage => _get('video_gen_last_message');
  String get videoGenBackground => _get('video_gen_background');
  String get videoGenFree => _get('video_gen_free');
  String get videoGenSelfie => _get('video_gen_selfie');
  String get videoGenNsfwFilter => _get('video_gen_nsfw_filter');
}
