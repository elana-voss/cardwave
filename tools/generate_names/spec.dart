// Generation spec: taxonomy bindings, batch plan, plausible-combo rules.
// Imported by generate.dart. Edit values here, not in generate.dart.

import 'package:cardwave_names/cardwave_names.dart';

/// Per-genre allowlist of cultural buckets that fit the genre. A batch
/// for (genre, culture) outside this map is skipped. Fantasy buckets
/// pair only with `fantasy` and `smut`; modern/cyberpunk skews to
/// industrialised cultures; victorian/historical skews to European.
const Map<GenreEnum, Set<LanguageEthnicityEnum>> genreCultureAllowlist = {
  GenreEnum.fantasy: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.scandinavian,
    LanguageEthnicityEnum.irishGaelic,
    LanguageEthnicityEnum.welsh,
    LanguageEthnicityEnum.greek,
    LanguageEthnicityEnum.latin,
    LanguageEthnicityEnum.fantasyElvish,
    LanguageEthnicityEnum.fantasyDwarven,
    LanguageEthnicityEnum.fantasyOrcish,
    LanguageEthnicityEnum.fantasyGoblin,
    LanguageEthnicityEnum.fantasyFae,
    LanguageEthnicityEnum.fantasyAngelic,
    LanguageEthnicityEnum.fantasyDemonic,
    LanguageEthnicityEnum.fantasyDragon,
    LanguageEthnicityEnum.fantasyVampire,
  },
  GenreEnum.sciFi: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.chinese,
    LanguageEthnicityEnum.korean,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.german,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.hindi,
  },
  GenreEnum.cyberpunk: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.korean,
    LanguageEthnicityEnum.chinese,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.scandinavian,
  },
  GenreEnum.steampunk: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.scottish,
    LanguageEthnicityEnum.irishGaelic,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.german,
  },
  GenreEnum.western: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.spanish,
    LanguageEthnicityEnum.irishGaelic,
    LanguageEthnicityEnum.nativeAmerican,
  },
  GenreEnum.noirDetective: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.italian,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.german,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.spanish,
  },
  GenreEnum.horror: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.slavicPolish,
    LanguageEthnicityEnum.german,
    LanguageEthnicityEnum.scandinavian,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.fantasyVampire,
    LanguageEthnicityEnum.fantasyDemonic,
  },
  GenreEnum.smut: {
    // Permissive — smut overlays any culture
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.korean,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.italian,
    LanguageEthnicityEnum.spanish,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.scandinavian,
    LanguageEthnicityEnum.fantasyElvish,
    LanguageEthnicityEnum.fantasyVampire,
    LanguageEthnicityEnum.fantasyDemonic,
  },
  GenreEnum.modern: {
    // All real-world cultures — modern is the default catch-all
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.chinese,
    LanguageEthnicityEnum.korean,
    LanguageEthnicityEnum.arabic,
    LanguageEthnicityEnum.hebrew,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.slavicPolish,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.spanish,
    LanguageEthnicityEnum.italian,
    LanguageEthnicityEnum.portuguese,
    LanguageEthnicityEnum.german,
    LanguageEthnicityEnum.dutch,
    LanguageEthnicityEnum.scandinavian,
    LanguageEthnicityEnum.irishGaelic,
    LanguageEthnicityEnum.greek,
    LanguageEthnicityEnum.hindi,
    LanguageEthnicityEnum.persian,
    LanguageEthnicityEnum.turkish,
    LanguageEthnicityEnum.swahili,
    LanguageEthnicityEnum.yoruba,
    LanguageEthnicityEnum.hawaiian,
    LanguageEthnicityEnum.vietnamese,
    LanguageEthnicityEnum.thai,
  },
  GenreEnum.historical: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.scottish,
    LanguageEthnicityEnum.irishGaelic,
    LanguageEthnicityEnum.welsh,
    LanguageEthnicityEnum.french,
    LanguageEthnicityEnum.german,
    LanguageEthnicityEnum.italian,
    LanguageEthnicityEnum.spanish,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.greek,
    LanguageEthnicityEnum.latin,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.chinese,
  },
  GenreEnum.postApocalyptic: {
    LanguageEthnicityEnum.english,
    LanguageEthnicityEnum.slavicRussian,
    LanguageEthnicityEnum.japanese,
    LanguageEthnicityEnum.spanish,
    LanguageEthnicityEnum.arabic,
    LanguageEthnicityEnum.persian,
  },
};

/// Race → forced fantasy `languageEthnicity`. Used to remap a generation
/// batch whose race is non-human into the right cultural bucket. Human
/// maps to null — human characters use real-world buckets, not the
/// fantasy ones.
const Map<RaceEnum, LanguageEthnicityEnum?> raceToFantasyCulture = {
  RaceEnum.human: null,
  RaceEnum.elf: LanguageEthnicityEnum.fantasyElvish,
  RaceEnum.dwarf: LanguageEthnicityEnum.fantasyDwarven,
  RaceEnum.halfling: LanguageEthnicityEnum.fantasyDwarven,
  RaceEnum.orc: LanguageEthnicityEnum.fantasyOrcish,
  RaceEnum.goblin: LanguageEthnicityEnum.fantasyGoblin,
  RaceEnum.fae: LanguageEthnicityEnum.fantasyFae,
  RaceEnum.angel: LanguageEthnicityEnum.fantasyAngelic,
  RaceEnum.demon: LanguageEthnicityEnum.fantasyDemonic,
  RaceEnum.dragon: LanguageEthnicityEnum.fantasyDragon,
  RaceEnum.vampire: LanguageEthnicityEnum.fantasyVampire,
  RaceEnum.werewolf: LanguageEthnicityEnum.fantasyDemonic,
};

/// Curated list of names the LLM tends to reach for that we want to
/// explicitly exclude from the generated pool. Anything on this list
/// gets dropped during the post-generation validation pass too.
const List<String> aiismRejectList = [
  'Elara', 'Aria', 'Liam', 'Marcus', 'Mira', 'Lyra', 'Zara', 'Kai',
  'Sera', 'Cassian', 'Lucien', 'Ezra', 'Maeve', 'Rowan', 'Silas',
  'Lyric', 'Aurora', 'Phoenix', 'Sage', 'Ember', 'Wren', 'Atlas',
  'Orion', 'Nova', 'Indigo', 'Storm', 'River', 'Skyler',
];

/// Names per (genre, culture, gender) batch. Surnames get more per
/// batch since their tag space is smaller.
const int firstNamesPerBatch = 6;
const int surnamesPerBatch = 50;
