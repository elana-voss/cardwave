// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
  id: json['id'] as String,
  origin: $enumDecode(_$NodeOriginEnumEnumMap, json['origin']),
  type: $enumDecode(_$NodeTypeEnumEnumMap, json['type']),
  triggerProb: (json['trigger_prob'] as num).toDouble(),
  delay: (json['delay'] as num).toInt(),
  cooldown: (json['cooldown'] as num).toInt(),
  sticky: (json['sticky'] as num).toInt(),
  alive: (json['alive'] as num).toInt(),
  scope: $enumDecode(_$NodeScopeEnumEnumMap, json['scope']),
  predicate: json['predicate'] as String,
  narrativePayload: json['narrative_payload'] as String,
  effects: json['effects'] == null
      ? null
      : NodeEffects.fromJson(json['effects'] as Map<String, dynamic>),
  spawns: (json['spawns'] as List<dynamic>?)
      ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentDelay: (json['current_delay'] as num?)?.toInt(),
  currentCooldown: (json['current_cooldown'] as num?)?.toInt(),
  currentSticky: (json['current_sticky'] as num?)?.toInt(),
  currentAlive: (json['current_alive'] as num?)?.toInt(),
);

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
  'id': instance.id,
  'origin': _$NodeOriginEnumEnumMap[instance.origin]!,
  'type': _$NodeTypeEnumEnumMap[instance.type]!,
  'trigger_prob': instance.triggerProb,
  'delay': instance.delay,
  'cooldown': instance.cooldown,
  'sticky': instance.sticky,
  'alive': instance.alive,
  'scope': _$NodeScopeEnumEnumMap[instance.scope]!,
  'predicate': instance.predicate,
  'narrative_payload': instance.narrativePayload,
  'effects': instance.effects.toJson(),
  'spawns': instance.spawns.map((e) => e.toJson()).toList(),
  'current_delay': instance.currentDelay,
  'current_cooldown': instance.currentCooldown,
  'current_sticky': instance.currentSticky,
  'current_alive': instance.currentAlive,
};

const _$NodeOriginEnumEnumMap = {
  NodeOriginEnum.authored: 'authored',
  NodeOriginEnum.generated: 'generated',
};

const _$NodeTypeEnumEnumMap = {
  NodeTypeEnum.characterBehavior: 'characterBehavior',
  NodeTypeEnum.environmental: 'environmental',
  NodeTypeEnum.event: 'event',
  NodeTypeEnum.pacing: 'pacing',
};

const _$NodeScopeEnumEnumMap = {
  NodeScopeEnum.phase: 'phase',
  NodeScopeEnum.scene: 'scene',
  NodeScopeEnum.session: 'session',
  NodeScopeEnum.oneShot: 'oneShot',
};
