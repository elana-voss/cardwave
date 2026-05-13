// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterFile _$CharacterFileFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CharacterFile',
      json,
      ($checkedConvert) {
        final val = CharacterFile(
          card: $checkedConvert(
            'card',
            (v) => _cardFromJson(v as Map<String, dynamic>),
          ),
          pngTimestampImported: $checkedConvert(
            'png_timestamp_imported',
            (v) => (v as num).toInt(),
          ),
          pngTimestampLastSaved: $checkedConvert(
            'png_timestamp_last_saved',
            (v) => (v as num).toInt(),
          ),
          appCardTokenCountPermanent: $checkedConvert(
            'app_card_token_count_permanent',
            (v) => (v as num).toInt(),
          ),
          appCardTokenCountAll: $checkedConvert(
            'app_card_token_count_all',
            (v) => (v as num).toInt(),
          ),
          appCardTokenCountLorebook: $checkedConvert(
            'app_card_token_count_lorebook',
            (v) => (v as num).toInt(),
          ),
          appCardVariantNotes: $checkedConvert(
            'app_card_variant_notes',
            (v) => v as String,
          ),
          appCardIsArchive: $checkedConvert(
            'app_card_is_archive',
            (v) => v as bool,
          ),
          appCardId: $checkedConvert('app_card_id', (v) => v as String),
          appCardRootId: $checkedConvert(
            'app_card_root_id',
            (v) => v as String,
          ),
          appCardParentId: $checkedConvert(
            'app_card_parent_id',
            (v) => v as String,
          ),
          appCardTimestampLastChatted: $checkedConvert(
            'app_card_timestamp_last_chatted',
            (v) => (v as num?)?.toInt(),
          ),
          appCardTimestampLastChattedDismissed: $checkedConvert(
            'app_card_timestamp_last_chatted_dismissed',
            (v) => (v as num?)?.toInt(),
          ),
          appCardTimestampLastSaved: $checkedConvert(
            'app_card_timestamp_last_saved',
            (v) => (v as num?)?.toInt(),
          ),
          appCardTags: $checkedConvert(
            'app_card_tags',
            (v) => (v as List<dynamic>?)?.map((e) => e as String).toSet() ?? {},
          ),
          configMedia: $checkedConvert(
            'config_media',
            (v) => v == null
                ? null
                : ConfigMediaCharacter.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'pngTimestampImported': 'png_timestamp_imported',
        'pngTimestampLastSaved': 'png_timestamp_last_saved',
        'appCardTokenCountPermanent': 'app_card_token_count_permanent',
        'appCardTokenCountAll': 'app_card_token_count_all',
        'appCardTokenCountLorebook': 'app_card_token_count_lorebook',
        'appCardVariantNotes': 'app_card_variant_notes',
        'appCardIsArchive': 'app_card_is_archive',
        'appCardId': 'app_card_id',
        'appCardRootId': 'app_card_root_id',
        'appCardParentId': 'app_card_parent_id',
        'appCardTimestampLastChatted': 'app_card_timestamp_last_chatted',
        'appCardTimestampLastChattedDismissed':
            'app_card_timestamp_last_chatted_dismissed',
        'appCardTimestampLastSaved': 'app_card_timestamp_last_saved',
        'appCardTags': 'app_card_tags',
        'configMedia': 'config_media',
      },
    );

Map<String, dynamic> _$CharacterFileToJson(CharacterFile instance) =>
    <String, dynamic>{
      'card': _cardToJson(instance.card),
      'png_timestamp_imported': instance.pngTimestampImported,
      'png_timestamp_last_saved': instance.pngTimestampLastSaved,
      'app_card_token_count_permanent': instance.appCardTokenCountPermanent,
      'app_card_token_count_all': instance.appCardTokenCountAll,
      'app_card_token_count_lorebook': instance.appCardTokenCountLorebook,
      'app_card_timestamp_last_chatted': instance.appCardTimestampLastChatted,
      'app_card_timestamp_last_chatted_dismissed':
          instance.appCardTimestampLastChattedDismissed,
      'app_card_timestamp_last_saved': instance.appCardTimestampLastSaved,
      'app_card_tags': instance.appCardTags.toList(),
      'app_card_variant_notes': instance.appCardVariantNotes,
      'app_card_is_archive': instance.appCardIsArchive,
      'app_card_id': instance.appCardId,
      'app_card_root_id': instance.appCardRootId,
      'app_card_parent_id': instance.appCardParentId,
      'config_media': ?instance.configMedia?.toJson(),
    };
