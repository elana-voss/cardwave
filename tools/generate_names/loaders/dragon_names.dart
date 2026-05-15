// kraihn/dragon-names loader.
//
// Source: data/<medium>-dragon-names.json — flat string arrays per
// medium (animated, comic, film, game, literature, television).
//
// Fills directly: race=dragon, themes=[literary] (the corpus is
// media-derived). Each name treated as a "first name" — dragons don't
// follow first+last convention.
// Sentinel: gender, language_ethnicity, era, age, role, intelligence,
// allure, genre.

import 'dart:convert';
import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetRoot = '$datasetRoot/dragon-names/data';

LoaderResult loadDragonNames() {
  final dir = Directory(_datasetRoot);
  if (!dir.existsSync()) {
    stderr.writeln('[dragon-names] $_datasetRoot missing.');
    return const LoaderResult();
  }

  final firstNames = <CandidateFirstName>[];

  for (final entity in dir.listSync().whereType<File>()) {
    final filename = entity.uri.pathSegments.last;
    if (!filename.endsWith('-dragon-names.json')) continue;

    final entries = jsonDecode(entity.readAsStringSync()) as List<dynamic>;
    for (final raw in entries) {
      final name = (raw as String).trim();
      if (name.isEmpty) continue;
      // Some entries are full phrases ("Ancalagon the Black"); keep them
      // as-is. The LLM can use them verbatim.

      firstNames.add(
        CandidateFirstName.sentinel(
          name: name,
          languageEthnicity: LanguageEthnicityEnum.fantasyDragon,
          race: RaceEnum.dragon,
          themes: const [ThemeEnum.literary],
        ),
      );
    }
  }

  return LoaderResult(firstNames: firstNames);
}
