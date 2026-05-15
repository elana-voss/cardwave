// philipperemy/name-dataset loader.
//
// Source: per-country JSON produced by philipperemy_to_json.py from the
// upstream Python pickles. Each country file contains the top 2000 names
// for that country, ranked, with gender (first names only).
//
// Fills directly: gender, language_ethnicity (via country map), race=human.
// Sentinel: age, role, intelligence, allure, themes, genre, era.

import 'dart:convert';
import 'dart:io';

import 'candidate_record.dart';
import 'country_map.dart';
import 'local_taxonomy.dart';

const _datasetRoot = '$datasetRoot/philipperemy/converted';

LoaderResult loadPhilipperemy() {
  final dir = Directory(_datasetRoot);
  if (!dir.existsSync()) {
    stderr.writeln(
      '[philipperemy] $_datasetRoot missing — run philipperemy_to_json.py.',
    );
    return const LoaderResult();
  }

  final firstNames = <CandidateFirstName>[];
  final lastNames = <CandidateLastName>[];

  for (final entity in dir.listSync().whereType<File>()) {
    final filename = entity.uri.pathSegments.last;
    if (!filename.endsWith('.json')) continue;

    final match = _filenameRe.firstMatch(filename);
    if (match == null) continue;

    final countryCode = match.group(1)!;
    final kind = match.group(2)!;
    final ethnicity = isoCountryToEthnicity[countryCode];
    if (ethnicity == null) continue;

    final entries = jsonDecode(entity.readAsStringSync()) as List<dynamic>;
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      final name = (entry['name'] as String).trim();
      if (name.isEmpty) continue;

      if (kind == 'first') {
        final genderCode = entry['gender'] as String?;
        firstNames.add(
          CandidateFirstName.sentinel(
            name: name,
            languageEthnicity: ethnicity,
            gender: _genderFromCode(genderCode),
          ),
        );
      } else {
        lastNames.add(
          CandidateLastName.sentinel(
            name: name,
            languageEthnicity: ethnicity,
          ),
        );
      }
    }
  }

  return LoaderResult(firstNames: firstNames, lastNames: lastNames);
}

GenderEnum? _genderFromCode(String? code) => switch (code) {
  'M' => GenderEnum.male,
  'F' => GenderEnum.female,
  _ => null,
};

final _filenameRe = RegExp(r'^([A-Z]{2})_(first|last)\.json$');
