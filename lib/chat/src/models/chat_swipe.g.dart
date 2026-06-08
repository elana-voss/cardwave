// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_swipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSwipe _$ChatSwipeFromJson(Map<String, dynamic> json) => ChatSwipe(
  content: json['content'] as String,
  tokenCount: (json['token_count'] as num?)?.toInt(),
  attachedImages:
      (json['attached_images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  imageCaption: json['image_caption'] as String?,
  videoPath: json['video_path'] as String?,
  toolCalls:
      (json['tool_calls'] as List<dynamic>?)
          ?.map((e) => ChatToolCallRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  recalledMemory:
      (json['recalled_memory'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$ChatSwipeToJson(ChatSwipe instance) => <String, dynamic>{
  'content': instance.content,
  'token_count': instance.tokenCount,
  'attached_images': instance.attachedImages,
  'image_caption': ?instance.imageCaption,
  'video_path': ?instance.videoPath,
  'tool_calls': instance.toolCalls.map((e) => e.toJson()).toList(),
  'recalled_memory': instance.recalledMemory,
};
