import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_surname.dart';
import 'package:json_annotation/json_annotation.dart';

part 'name_pick.g.dart';

/// Result of [NameDatabase.pickName]. Carries the matched first + last
/// name records and the list of filter fields the degradation loop had
/// to drop to find a non-empty candidate pool. Empty [relaxedFilters]
/// means every original constraint was satisfied.
@JsonSerializable(explicitToJson: true)
class NamePick {
  const NamePick({
    required this.firstNameEntry,
    required this.lastNameEntry,
    required this.relaxedFilters,
  });

  factory NamePick.fromJson(Map<String, dynamic> json) =>
      _$NamePickFromJson(json);

  final NameEntry firstNameEntry;
  final NameSurname lastNameEntry;
  final List<NameFilterField> relaxedFilters;

  Map<String, dynamic> toJson() => _$NamePickToJson(this);
}
