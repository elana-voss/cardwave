import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_surname.dart';

/// Result of [NameDatabase.pickName]. Carries the matched first + last
/// name records and the list of filter fields the degradation loop had
/// to drop to find a non-empty candidate pool. Empty [relaxedFilters]
/// means every original constraint was satisfied.
///
/// [toJson] emits the full first-name and surname classification so the
/// LLM can colour narration with it.
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
      'role': firstNameEntry.role.map((r) => r.name).toList(),
      'intelligence': firstNameEntry.intelligence.name,
      'allure': firstNameEntry.allure.name,
      'commonness': firstNameEntry.commonness.name,
      'genre': firstNameEntry.genre.map((g) => g.name).toList(),
      'themes': firstNameEntry.themes.map((t) => t.name).toList(),
      'last_name_role': lastNameEntry.role.map((r) => r.name).toList(),
      'last_name_allure': lastNameEntry.allure.name,
      'last_name_commonness': lastNameEntry.commonness.name,
      'last_name_genre': lastNameEntry.genre.map((g) => g.name).toList(),
      'last_name_themes': lastNameEntry.themes.map((t) => t.name).toList(),
      if (mythology != null) 'mythology': mythology.name,
      if (relaxedFilters.isNotEmpty)
        'relaxed_filters': relaxedFilters.map((f) => f.name).toList(),
    };
  }
}
