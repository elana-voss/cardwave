import 'package:json_annotation/json_annotation.dart';

part 'chat_persona.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatPersona {
  ChatPersona({required this.name, required this.description, String? id})
    : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory ChatPersona.fromJson(Map<String, dynamic> json) =>
      _$ChatPersonaFromJson(json);
  String id;
  String name;
  String description;
  Map<String, dynamic> toJson() => _$ChatPersonaToJson(this);
}
