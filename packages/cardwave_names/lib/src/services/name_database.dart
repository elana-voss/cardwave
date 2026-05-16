import 'dart:math';

import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_filters.dart';
import 'package:cardwave_names/src/models/name_pick.dart';
import 'package:cardwave_names/src/models/name_surname.dart';
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

  /// Priority order for the degradation loop. Decorative / mood fields
  /// drop first; identity-defining fields (gender, language, race) drop
  /// last so the LLM's strongest signals survive longest. `genre` drops
  /// before `era` because era is identity-coloring (a modern name in a
  /// 1920s scene jars more than a 1920s name without specific noir
  /// flavor); `age` stays mid-tier since 80%+ of names are tagged
  /// `adult` anyway and the axis carries little discriminating info.
  static const _dropOrder = [
    NameFilterField.themes,
    NameFilterField.allure,
    NameFilterField.intelligence,
    NameFilterField.commonness,
    NameFilterField.role,
    NameFilterField.age,
    NameFilterField.genre,
    NameFilterField.era,
    NameFilterField.mythology,
    NameFilterField.race,
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
      if (f.age != null && !e.age.contains(f.age)) return false;
      if (f.era != null && !e.era.contains(f.era)) return false;
      if (f.role != null && !e.role.contains(f.role)) return false;
      if (f.intelligence != null && e.intelligence != f.intelligence) {
        return false;
      }
      if (f.allure != null && e.allure != f.allure) return false;
      if (f.commonness != null && e.commonness != f.commonness) return false;
      // Empty entry-genre = compatible with any genre filter. Names
      // without a committed genre are "preferred but not exclusive" —
      // they join the candidate pool for any genre request instead of
      // forcing the filter to fail when the strict-match pool is tiny.
      if (f.genre != null &&
          e.genre.isNotEmpty &&
          !e.genre.contains(f.genre)) {
        return false;
      }
      final themesFilter = f.themes;
      if (themesFilter != null && themesFilter.isNotEmpty) {
        final overlap = e.themes.any(themesFilter.contains);
        if (!overlap) return false;
      }
      return true;
    }).toList();
  }
}
