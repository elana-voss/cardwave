import 'package:json_annotation/json_annotation.dart';

part 'scene.g.dart';

/// Current scene context. Updated only via fired-node effects, not by the
/// director directly.
@JsonSerializable()
class Scene {
  Scene({
    this.location = '',
    this.timeOfDay = '',
    List<String>? presentEntities,
    List<String>? sensoryHooks,
  })  : presentEntities = presentEntities ?? [],
        sensoryHooks = sensoryHooks ?? [];

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);

  String location;
  String timeOfDay;
  List<String> presentEntities;
  List<String> sensoryHooks;

  Map<String, dynamic> toJson() => _$SceneToJson(this);
}
