import 'dart:math';

import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_filters.dart';
import 'package:cardwave_names/src/models/name_pick.dart';
import 'package:cardwave_names/src/models/name_surname.dart';
import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:cardwave_names/src/services/name_database_data.dart';

/// Serves filtered NPC name picks to the `suggest_name` tool. Entry data
/// is a const top-level list compiled into the binary (see
/// [name_database_data.dart]). Filter intersection that produces no
/// candidates degrades by dropping fields in [_dropOrder] until the pool
/// is non-empty; per-call used-name sets are reset within the active
/// filter slice when every candidate is already used.
class NameDatabase {
  NameDatabase() : this._(firstNamesData, lastNamesData);

  /// Test-only entry point. Lets unit tests drive filter / degradation /
  /// reset paths against fixed fixtures.
  NameDatabase.forTesting({
    required List<NameEntry> firstNames,
    required List<NameSurname> lastNames,
  }) : this._(firstNames, lastNames);

  NameDatabase._(this._firstNames, this._lastNames);

  /// Priority order for the degradation loop. Subjective / decorative
  /// fields drop first; identity-defining fields (gender, language,
  /// genre) drop last so the LLM's strongest signals survive longest.
  static const _dropOrder = [
    NameFilterField.themes,
    NameFilterField.allure,
    NameFilterField.intelligence,
    NameFilterField.commonness,
    NameFilterField.role,
    NameFilterField.age,
    NameFilterField.era,
    NameFilterField.mythology,
    NameFilterField.race,
    NameFilterField.genre,
    NameFilterField.languageEthnicity,
    NameFilterField.gender,
  ];

  final Random _rng = Random.secure();
  final List<NameEntry> _firstNames;
  final List<NameSurname> _lastNames;

  NamePick pickName(
    NameFilters filters,
    Set<String> usedFirst,
    Set<String> usedLast,
  ) {
    if (_firstNames.isEmpty || _lastNames.isEmpty) {
      throw StateError(
        'NameDatabase is empty — the generation script has not been run.',
      );
    }

    final relaxed = <NameFilterField>[];
    var current = filters;
    var firstCandidates = _filterFirstNames(_firstNames, current);
    if (firstCandidates.isEmpty) {
      for (final field in _dropOrder) {
        current = current.withoutField(field);
        relaxed.add(field);
        firstCandidates = _filterFirstNames(_firstNames, current);
        if (firstCandidates.isNotEmpty) break;
      }
    }
    final firstPick =
        _pickAndMarkUsed(firstCandidates, usedFirst, (e) => e.name);

    final lockedCulture = firstPick.languageEthnicity;
    var lastCandidates = _lastNames
        .where((s) => s.languageEthnicity == lockedCulture)
        .toList();
    if (lastCandidates.isEmpty) {
      lastCandidates = _lastNames;
    }
    final lastPick =
        _pickAndMarkUsed(lastCandidates, usedLast, (s) => s.name);

    return NamePick(
      firstNameEntry: firstPick,
      lastNameEntry: lastPick,
      relaxedFilters: relaxed,
    );
  }

  T _pickAndMarkUsed<T>(
    List<T> candidates,
    Set<String> used,
    String Function(T) nameOf,
  ) {
    // Empty used-set is the common first-pick case in a fresh chat —
    // skip the redundant filter+copy and pick from `candidates` directly.
    var unused = used.isEmpty
        ? candidates
        : candidates.where((e) => !used.contains(nameOf(e))).toList();
    if (unused.isEmpty) {
      used.removeAll(candidates.map(nameOf));
      unused = candidates;
    }
    final pick = unused[_rng.nextInt(unused.length)];
    used.add(nameOf(pick));
    return pick;
  }

  static List<NameEntry> _filterFirstNames(
    List<NameEntry> pool,
    NameFilters f,
  ) {
    return pool.where((e) {
      if (f.gender != null && e.gender != f.gender) return false;
      if (f.languageEthnicity != null &&
          e.languageEthnicity != f.languageEthnicity) {
        return false;
      }
      if (f.mythology != null && e.mythology != f.mythology) return false;
      if (f.race != null && e.race != f.race) return false;
      if (f.age != null && e.age != f.age) return false;
      if (f.era != null && e.era != f.era) return false;
      if (f.role != null && e.role != f.role) return false;
      final intelFilter = f.intelligence;
      if (intelFilter != null && !intelFilter.includes(e.intelligence)) {
        return false;
      }
      final allureFilter = f.allure;
      if (allureFilter != null && !allureFilter.includes(e.allure)) {
        return false;
      }
      if (f.commonness != null && e.commonness != f.commonness) return false;
      if (f.genre != null && !e.genre.contains(f.genre)) return false;
      final themesFilter = f.themes;
      if (themesFilter != null && themesFilter.isNotEmpty) {
        final overlap = e.themes.any(themesFilter.contains);
        if (!overlap) return false;
      }
      return true;
    }).toList();
  }
}
