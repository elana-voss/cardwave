// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_nodes_extension.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CardNodesExtension _$CardNodesExtensionFromJson(Map<String, dynamic> json) =>
    CardNodesExtension(
      authoredNodes: (json['authored_nodes'] as List<dynamic>?)
          ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
      emotionBaseline: (json['emotion_baseline'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$EmotionEnumEnumMap, k),
          (e as num).toDouble(),
        ),
      ),
      initialGoal: json['initial_goal'] as String? ?? '',
      initialScene: json['initial_scene'] == null
          ? null
          : Scene.fromJson(json['initial_scene'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CardNodesExtensionToJson(CardNodesExtension instance) =>
    <String, dynamic>{
      'authored_nodes': instance.authoredNodes.map((e) => e.toJson()).toList(),
      'emotion_baseline': instance.emotionBaseline.map(
        (k, e) => MapEntry(_$EmotionEnumEnumMap[k]!, e),
      ),
      'initial_goal': instance.initialGoal,
      'initial_scene': ?instance.initialScene?.toJson(),
    };

const _$EmotionEnumEnumMap = {
  EmotionEnum.joy: 'joy',
  EmotionEnum.sadness: 'sadness',
  EmotionEnum.anger: 'anger',
  EmotionEnum.fear: 'fear',
  EmotionEnum.trust: 'trust',
  EmotionEnum.disgust: 'disgust',
  EmotionEnum.surprise: 'surprise',
  EmotionEnum.anticipation: 'anticipation',
};
