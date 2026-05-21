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
  facts:
      (json['facts'] as List<dynamic>?)
          ?.map((e) => MemoryFact.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$MemoryGraphToJson(MemoryGraph instance) =>
    <String, dynamic>{
      'events': instance.events.map((e) => e.toJson()).toList(),
      'facts': instance.facts.map((e) => e.toJson()).toList(),
    };
