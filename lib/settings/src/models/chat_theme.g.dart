// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_theme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatTheme _$ChatThemeFromJson(Map<String, dynamic> json) => ChatTheme(
  name: json['name'] as String,
  layoutType: $enumDecode(_$ChatLayoutTypeEnumEnumMap, json['layout_type']),
  backgroundColor: (json['background_color'] as num).toInt(),
  userBackgroundColor: (json['user_background_color'] as num).toInt(),
  assistantBackgroundColor: (json['assistant_background_color'] as num).toInt(),
  userTextColor: (json['user_text_color'] as num).toInt(),
  assistantTextColor: (json['assistant_text_color'] as num).toInt(),
  italicColor: (json['italic_color'] as num).toInt(),
  underlineColor: (json['underline_color'] as num).toInt(),
  quoteColor: (json['quote_color'] as num).toInt(),
  dividerColor: (json['divider_color'] as num).toInt(),
  asteriskColor: (json['asterisk_color'] as num).toInt(),
  userMetaColor: (json['user_meta_color'] as num).toInt(),
  assistantMetaColor: (json['assistant_meta_color'] as num).toInt(),
  blurTintColor: (json['blur_tint_color'] as num).toInt(),
  shadowColor: (json['shadow_color'] as num).toInt(),
  textShadowColor: (json['text_shadow_color'] as num).toInt(),
  borderColor: (json['border_color'] as num).toInt(),
  blurStrength: (json['blur_strength'] as num).toDouble(),
  shadowWidth: (json['shadow_width'] as num).toDouble(),
);

Map<String, dynamic> _$ChatThemeToJson(ChatTheme instance) => <String, dynamic>{
  'name': instance.name,
  'layout_type': _$ChatLayoutTypeEnumEnumMap[instance.layoutType]!,
  'background_color': instance.backgroundColor,
  'user_background_color': instance.userBackgroundColor,
  'assistant_background_color': instance.assistantBackgroundColor,
  'user_text_color': instance.userTextColor,
  'assistant_text_color': instance.assistantTextColor,
  'italic_color': instance.italicColor,
  'underline_color': instance.underlineColor,
  'quote_color': instance.quoteColor,
  'divider_color': instance.dividerColor,
  'asterisk_color': instance.asteriskColor,
  'user_meta_color': instance.userMetaColor,
  'assistant_meta_color': instance.assistantMetaColor,
  'blur_tint_color': instance.blurTintColor,
  'shadow_color': instance.shadowColor,
  'text_shadow_color': instance.textShadowColor,
  'border_color': instance.borderColor,
  'blur_strength': instance.blurStrength,
  'shadow_width': instance.shadowWidth,
};

const _$ChatLayoutTypeEnumEnumMap = {
  ChatLayoutTypeEnum.bubbles: 'bubbles',
  ChatLayoutTypeEnum.flat: 'flat',
};
