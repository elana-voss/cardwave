/// All 11 taxonomy axes for the NPC name database. Enum value names are
/// the wire format: they appear in both the bundled `name_database.json`
/// and the `suggest_name` tool's parameter schema. Renaming any value
/// requires regenerating the database.
library;

enum GenderEnum {
  male,
  female,
  ambiguous,
}

enum LanguageEthnicityEnum {
  english,
  japanese,
  chinese,
  korean,
  arabic,
  hebrew,
  slavicRussian,
  slavicPolish,
  slavicOther,
  french,
  spanish,
  italian,
  portuguese,
  german,
  dutch,
  scandinavian,
  irishGaelic,
  welsh,
  scottish,
  greek,
  latin,
  hindi,
  persian,
  turkish,
  swahili,
  yoruba,
  nativeAmerican,
  hawaiian,
  vietnamese,
  thai,
  angloSaxon,
  estonian,
  finnish,
  icelandic,
  indonesian,
  maori,
  mayan,
  mongolian,
  nepalese,
  nigerian,
  norwegian,
  serbian,
  somali,
  swedish,
  ukrainian,
  fantasyElvish,
  fantasyDwarven,
  fantasyOrcish,
  fantasyGoblin,
  fantasyFae,
  fantasyAngelic,
  fantasyDemonic,
  fantasyDragon,
  fantasyVampire,
}

extension LanguageEthnicityX on LanguageEthnicityEnum {
  bool get isFantasy => name.startsWith('fantasy');
  bool get isRealWorld => !isFantasy;
}

/// Convenience for building the LLM-tool-schema enum lists from each
/// enum's `.values`. Saves writing `.map((e) => e.name).toList()` at
/// every call site.
extension EnumNamesList on Iterable<Enum> {
  List<String> get names => map((e) => e.name).toList();
}

enum MythologyEnum {
  greek,
  norse,
  roman,
  celtic,
  egyptian,
  hindu,
  japanese,
  slavic,
  mesopotamian,
  nativeAmerican,
  lovecraft,
}

enum RaceEnum {
  human,
  elf,
  dwarf,
  halfling,
  orc,
  goblin,
  vampire,
  werewolf,
  demon,
  angel,
  dragon,
  fae,
  giant,
  troll,
  lich,
  golem,
  ghost,
  witch,
  gnome,
  ogre,
  hobgoblin,
  kobold,
  oni,
  kappa,
  centaur,
  satyr,
  faun,
  minotaur,
  harpy,
  gorgon,
  naga,
  cyclops,
  ghoul,
  wight,
  wraith,
  spectre,
  zombie,
  mummy,
  draugr,
  ghast,
  hag,
  djinn,
  imp,
  succubus,
  incubus,
  mermaid,
  merman,
  siren,
  selkie,
  dryad,
  nymph,
  pixie,
  sprite,
  sylph,
  brownie,
  leprechaun,
  gremlin,
  valkyrie,
  warg,
  wendigo,
  gargoyle,
  homunculus,
  elemental,
  yeti,
  sasquatch,
  pegasus,
  unicorn,
  phoenix,
  griffon,
  hippogriff,
  wyvern,
  manticore,
  sphinx,
  thunderbird,
  roc,
  chimera,
  kraken,
  hydra,
  cockatrice,
  bugbear,
  chupacabra,
  frostGiant,
  lamassu,
  nix,
  poltergeist,
}

enum AgeEnum {
  child,
  youngAdult,
  adult,
  elder,
}

enum EraEnum {
  ancient,
  medieval,
  renaissance,
  victorian,
  nineteenTwenties,
  midcentury,
  modern,
  contemporary,
  nearFuture,
  farFuture,
  timeless,
}

enum RoleEnum {
  hero,
  villain,
  mentor,
  sidekick,
  comicRelief,
  bystander,
  loveInterest,
  antihero,
  neutral,
}

/// Tool-param bucket for the stored 1–5 `intelligence` score. `low` maps
/// to 1–2, `medium` to 3, `high` to 4–5.
enum IntelligenceBucketEnum {
  low,
  medium,
  high,
}

/// Tool-param bucket for the stored 1–5 `allure` score. Same mapping
/// as [IntelligenceBucketEnum].
enum AllureBucketEnum {
  low,
  medium,
  high,
}

extension ScoreBucketRange on IntelligenceBucketEnum {
  bool includes(int score) => switch (this) {
    IntelligenceBucketEnum.low => score >= 1 && score <= 2,
    IntelligenceBucketEnum.medium => score == 3,
    IntelligenceBucketEnum.high => score >= 4 && score <= 5,
  };
}

extension AllureRange on AllureBucketEnum {
  bool includes(int score) => switch (this) {
    AllureBucketEnum.low => score >= 1 && score <= 2,
    AllureBucketEnum.medium => score == 3,
    AllureBucketEnum.high => score >= 4 && score <= 5,
  };
}

enum GenreEnum {
  fantasy,
  sciFi,
  cyberpunk,
  steampunk,
  western,
  noirDetective,
  horror,
  smut,
  modern,
  historical,
  postApocalyptic,
}

enum ThemeEnum {
  celestial,
  floral,
  gemstone,
  military,
  literary,
  regal,
  fiery,
  icy,
  watery,
  earthy,
  airy,
  solar,
  lunar,
  nautical,
  religious,
  scholarly,
  rustic,
  exotic,
  mystical,
  brutish,
}

/// How recognizable / frequent a name is. `common` = the LLM's default-pick
/// territory (Mary, John, Smith) — useful for background NPCs. `rare` =
/// distinctive picks for named, important characters. Filter axis the
/// `suggest_name` tool can use to steer between everyday and memorable
/// names.
enum CommonnessEnum {
  rare,
  uncommon,
  common,
}
