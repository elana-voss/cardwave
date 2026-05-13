// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupData _$GroupDataFromJson(Map<String, dynamic> json) => GroupData(
  overrideScenario: json['override_scenario'] as String?,
  overrideSystemPrompt: json['override_system_prompt'] as String?,
  overrideMesExample: json['override_mes_example'] as String?,
  mutedMemberAppCardIds:
      (json['muted_member_app_card_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$GroupDataToJson(GroupData instance) => <String, dynamic>{
  'override_scenario': instance.overrideScenario,
  'override_system_prompt': instance.overrideSystemPrompt,
  'override_mes_example': instance.overrideMesExample,
  'muted_member_app_card_ids': instance.mutedMemberAppCardIds,
};
