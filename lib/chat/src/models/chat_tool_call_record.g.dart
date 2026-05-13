// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_tool_call_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatToolCallRecord _$ChatToolCallRecordFromJson(Map<String, dynamic> json) =>
    ChatToolCallRecord(
      toolName: json['tool_name'] as String,
      args: json['args'] as Map<String, dynamic>,
      success: json['success'] as bool,
      resultData: json['result_data'] as String?,
      errorMessage: json['error_message'] as String?,
    );

Map<String, dynamic> _$ChatToolCallRecordToJson(ChatToolCallRecord instance) =>
    <String, dynamic>{
      'tool_name': instance.toolName,
      'args': instance.args,
      'result_data': ?instance.resultData,
      'success': instance.success,
      'error_message': ?instance.errorMessage,
    };
