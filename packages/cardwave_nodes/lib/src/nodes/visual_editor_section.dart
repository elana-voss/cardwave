import 'package:json_annotation/json_annotation.dart';

part 'visual_editor_section.g.dart';

/// The node's `visual_editor` JSON section: where the node's box sits on
/// the visual editor canvas. Authoring data — kept on save, never
/// touched by the firing engine.
@JsonSerializable()
class VisualEditorSection {
  const VisualEditorSection({this.x = 0, this.y = 0});

  factory VisualEditorSection.fromJson(Map<String, dynamic> json) =>
      _$VisualEditorSectionFromJson(json);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => _$VisualEditorSectionToJson(this);
}
