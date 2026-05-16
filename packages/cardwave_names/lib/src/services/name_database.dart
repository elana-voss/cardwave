import 'dart:convert';
import 'dart:math';

import 'package:cardwave_names/src/models/name_entry.dart';
import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_filters.dart';
import 'package:cardwave_names/src/models/name_pick.dart';
import 'package:cardwave_names/src/models/name_surname.dart';
import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads the frozen NPC name database from the bundled asset and serves
/// filtered picks to the `suggest_name` tool. Singleton; lifetime owned
/// by the host app's main entry. Filter intersection that produces no
/// candidates degrades by dropping fields in [_dropOrder] until the
/// pool is non-empty; per-call used-name sets are reset within the
/// active filter slice when every candidate is already used.
class NameDatabase {
  NameDatabase();

  /// Test-only factory. Bypasses asset loading so unit tests can drive
  /// the filter / degradation / reset paths against fixed fixtures.
  factory NameDatabase.forTesting({
    required List<NameEntry> firstNames,
    required List<NameSurname> lastNames,
  }) =>
      NameDatabase()
        .._firstNames = firstNames
        .._lastNames = lastNames;

  /// Flutter resolves package-bundled assets at this prefix at runtime.
  /// The asset lives at `assets/name_database.json` inside the package.
  static const String _assetPath =
      'packages/cardwave_names/assets/name_database.json';

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
  List<NameEntry>? _firstNames;
  List<NameSurname>? _lastNames;

  Future<void> init() async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final firstList = (json['first_names'] as List?) ?? const [];
    final lastList = (json['last_names'] as List?) ?? const [];
    _firstNames = firstList
        .map((e) => NameEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _lastNames = lastList
        .map((e) => NameSurname.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  NamePick pickName(
    NameFilters filters,
    Set<String> usedFirst,
    Set<String> usedLast,
  ) {
    final firstNames = _firstNames;
    final lastNames = _lastNames;
    if (firstNames == null || lastNames == null) {
      throw StateError(
        'NameDatabase.init() has not been called before pickName.',
      );
    }
    if (firstNames.isEmpty || lastNames.isEmpty) {
      throw StateError(
        'NameDatabase is empty — the generation script has not been run '
        'or the asset is a stub.',
      );
    }

    final relaxed = <NameFilterField>[];
    var current = filters;
    var firstCandidates = _filterFirstNames(firstNames, current);
    if (firstCandidates.isEmpty) {
      for (final field in _dropOrder) {
        current = current.withoutField(field);
        relaxed.add(field);
        firstCandidates = _filterFirstNames(firstNames, current);
        if (firstCandidates.isNotEmpty) break;
      }
    }
    final firstPick =
        _pickAndMarkUsed(firstCandidates, usedFirst, (e) => e.name);

    final lockedCulture = firstPick.languageEthnicity;
    var lastCandidates = lastNames
        .where((s) => s.languageEthnicity == lockedCulture)
        .toList();
    if (lastCandidates.isEmpty) {
      lastCandidates = lastNames;
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
    var unused = candidates.where((e) => !used.contains(nameOf(e))).toList();
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
