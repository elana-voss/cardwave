// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_graph.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryGraph _$MemoryGraphFromJson(Map<String, dynamic> json) => MemoryGraph(
  events:
      (json['events'] as List<dynamic>?)
          ?.map((e) => StoryEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  nodes:
      (json['nodes'] as List<dynamic>?)
          ?.map((e) => TreeNode.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  roots:
      (json['roots'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$MemoryGraphToJson(MemoryGraph instance) =>
    <String, dynamic>{
      'events': instance.events.map((e) => e.toJson()).toList(),
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'roots': instance.roots,
    };
