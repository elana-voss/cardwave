import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_surname.dart';

/// Result of [NameDatabase.pickName]. Carries the matched first + last
/// name records and the list of filter fields the degradation loop had
/// to drop to find a non-empty candidate pool. Empty [relaxedFilters]
/// means every original constraint was satisfied.
///
/// [toJson] emits the LLM-facing flat shape: just first/last name plus
/// the identity axes the model uses to colour its description (gender,
/// language_ethnicity, race, age, era, optional mythology). The full
/// taxonomy classification stays on the local records — the model
/// already passed those filters and doesn't need them echoed back.
class NamePick {
  const NamePick({
    required this.firstNameEntry,
    required this.lastNameEntry,
    required this.relaxedFilters,
  });

  final NameEntry firstNameEntry;
  final NameSurname lastNameEntry;
  final List<NameFilterField> relaxedFilters;

  Map<String, dynamic> toJson() {
    final mythology = firstNameEntry.mythology;
    return {
      'first_name': firstNameEntry.name,
      'last_name': lastNameEntry.name,
      'gender': firstNameEntry.gender.name,
      'language_ethnicity': firstNameEntry.languageEthnicity.name,
      'race': firstNameEntry.race.name,
      'age': firstNameEntry.age.map((a) => a.name).toList(),
      'era': firstNameEntry.era.map((e) => e.name).toList(),
      if (mythology != null) 'mythology': mythology.name,
      if (relaxedFilters.isNotEmpty)
        'relaxed_filters': relaxedFilters.map((f) => f.name).toList(),
    };
  }
}
