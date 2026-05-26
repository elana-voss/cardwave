// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_nodes_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatNodesState _$ChatNodesStateFromJson(Map<String, dynamic> json) =>
    ChatNodesState(
      state: json['state'] == null
          ? null
          : SessionState.fromJson(json['state'] as Map<String, dynamic>),
      activeNodes: (json['active_nodes'] as List<dynamic>?)
          ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ChatNodesStateToJson(ChatNodesState instance) =>
    <String, dynamic>{
      'state': instance.state.toJson(),
      'active_nodes': instance.activeNodes.map((e) => e.toJson()).toList(),
    };
