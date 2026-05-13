import 'package:json_annotation/json_annotation.dart';

part 'character_card_envelope.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class CharacterCardEnvelope {
  CharacterCardEnvelope({
    required this.spec,
    required this.specVersion,
    required this.data,
  });

  factory CharacterCardEnvelope.fromJson(Map<String, dynamic> json) =>
      _$CharacterCardEnvelopeFromJson(json);
  @JsonKey(defaultValue: '')
  String spec;
  @JsonKey(defaultValue: '')
  String specVersion;
  Map<String, dynamic> data;
  Map<String, dynamic> toJson() => _$CharacterCardEnvelopeToJson(this);
}
