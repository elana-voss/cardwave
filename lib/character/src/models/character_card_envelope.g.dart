// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_card_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterCardEnvelope _$CharacterCardEnvelopeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CharacterCardEnvelope', json, ($checkedConvert) {
  final val = CharacterCardEnvelope(
    spec: $checkedConvert('spec', (v) => v as String? ?? ''),
    specVersion: $checkedConvert('spec_version', (v) => v as String? ?? ''),
    data: $checkedConvert('data', (v) => v as Map<String, dynamic>),
  );
  return val;
}, fieldKeyMap: const {'specVersion': 'spec_version'});

Map<String, dynamic> _$CharacterCardEnvelopeToJson(
  CharacterCardEnvelope instance,
) => <String, dynamic>{
  'spec': instance.spec,
  'spec_version': instance.specVersion,
  'data': instance.data,
};
