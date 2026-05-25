import 'package:json_annotation/json_annotation.dart';

part 'tracked_value.g.dart';

/// A numeric state value with lockout bookkeeping. Used for emotions,
/// physical state, and relationship fields.
///
/// [value] is the current scalar (range 0..1). [lockoutTurnsRemaining]
/// counts down each turn; while greater than 0, upward deltas are blocked
/// (lockout was triggered by a large shift to the field's opposite in a
/// recent turn).
@JsonSerializable()
class TrackedValue {
  TrackedValue({
    this.value = 0.0,
    this.lockoutTurnsRemaining = 0,
  });

  factory TrackedValue.fromJson(Map<String, dynamic> json) =>
      _$TrackedValueFromJson(json);

  double value;
  int lockoutTurnsRemaining;

  Map<String, dynamic> toJson() => _$TrackedValueToJson(this);
}
