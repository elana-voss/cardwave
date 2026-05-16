/// All 11 taxonomy axes for the NPC name database. Enum value names are
/// the wire format: they appear in the generated `name_database_data.dart`
/// (the const-baked dataset) and in the `suggest_name` tool's parameter
/// schema. Renaming any value requires regenerating the database via
/// `dart run tools/generate_names/emit_dart.dart`.
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
  modern, // Kept: refers to the fixed historical Modernist period (~1880s–1960s).
  contemporary, // Kept: refers strictly to the present day and very recent past.
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

/// How cerebral / sophisticated a name sounds. Phonetics + cultural
/// connotation, not the bearer's IQ. Same five-level resolution Grok
/// classifies at — no bucket layer between storage and filter.
enum IntelligenceEnum {
  blunt,       // Bubba, Skip, Hank
  plain,       // Bob, Mary
  average,     // no strong signal either way
  thoughtful,  // Eleanor, Theodore
  bookish,     // Reginald, Persephone, Cassius
}

/// How sensually / aesthetically attractive a name sounds. Phonetics +
/// cultural connotation, not the bearer's looks.
enum AllureEnum {
  harsh,        // Mildred, Gary, Bertha
  unremarkable, // John, Anna
  pleasant,     // no strong signal either way
  pretty,       // Lily, Adrian
  striking,     // Aphrodite, Seraphina, Lysander
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
  // REMOVED: `modern` — "Modern" is a time period, not a genre. Set EraEnum
  // to `modern` or `contemporary` instead.
  // REMOVED: `historical` — redundant with EraEnum (ancient / medieval /
  // renaissance / victorian / nineteenTwenties / midcentury already cover
  // "historical").
  sliceOfLife, // ADDED: grounded, everyday-life stories — the replacement
  // for the rejected `modern` catch-all.
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
