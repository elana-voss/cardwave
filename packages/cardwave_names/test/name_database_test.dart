import 'package:cardwave_names/cardwave_names.dart';
import 'package:flutter_test/flutter_test.dart';

NameEntry _entry({
  required String name,
  GenderEnum gender = GenderEnum.female,
  LanguageEthnicityEnum culture = LanguageEthnicityEnum.english,
  MythologyEnum? mythology,
  RaceEnum race = RaceEnum.human,
  List<AgeEnum> age = const [AgeEnum.adult],
  List<EraEnum> era = const [EraEnum.modern],
  List<RoleEnum> role = const [RoleEnum.neutral],
  int intelligence = 3,
  int allure = 3,
  CommonnessEnum commonness = CommonnessEnum.uncommon,
  List<GenreEnum> genre = const [GenreEnum.sliceOfLife],
  List<ThemeEnum> themes = const [],
}) => NameEntry(
  name: name,
  gender: gender,
  languageEthnicity: culture,
  mythology: mythology,
  race: race,
  age: age,
  era: era,
  role: role,
  intelligence: intelligence,
  allure: allure,
  commonness: commonness,
  genre: genre,
  themes: themes,
);

NameSurname _surname({
  required String name,
  LanguageEthnicityEnum culture = LanguageEthnicityEnum.english,
  MythologyEnum? mythology,
  RaceEnum race = RaceEnum.human,
  List<EraEnum> era = const [EraEnum.modern],
  CommonnessEnum commonness = CommonnessEnum.uncommon,
  List<GenreEnum> genre = const [GenreEnum.sliceOfLife],
  List<ThemeEnum> themes = const [],
}) => NameSurname(
  name: name,
  languageEthnicity: culture,
  mythology: mythology,
  race: race,
  era: era,
  commonness: commonness,
  genre: genre,
  themes: themes,
);

void main() {
  group('NameDatabase.pickName', () {
    test('matches gender + culture filter exactly', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(name: 'Hana', gender: GenderEnum.female, culture: LanguageEthnicityEnum.japanese),
          _entry(name: 'Yuki', gender: GenderEnum.female, culture: LanguageEthnicityEnum.japanese),
          _entry(name: 'Alice', gender: GenderEnum.female, culture: LanguageEthnicityEnum.english),
        ],
        lastNames: [
          _surname(name: 'Tanaka', culture: LanguageEthnicityEnum.japanese),
          _surname(name: 'Smith', culture: LanguageEthnicityEnum.english),
        ],
      );

      final pick = db.pickName(
        const NameFilters(
          gender: GenderEnum.female,
          languageEthnicity: LanguageEthnicityEnum.japanese,
        ),
        <String>{},
        <String>{},
      );

      expect(pick.firstNameEntry.gender, GenderEnum.female);
      expect(pick.firstNameEntry.languageEthnicity, LanguageEthnicityEnum.japanese);
      expect(['Hana', 'Yuki'], contains(pick.firstNameEntry.name));
      expect(pick.relaxedFilters, isEmpty);
    });

    test('drops filters in priority order when intersection is empty', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(
            name: 'Mira',
            gender: GenderEnum.female,
            culture: LanguageEthnicityEnum.slavicRussian,
            role: const [RoleEnum.villain],
            intelligence: 5,
            allure: 4,
            genre: const [GenreEnum.horror, GenreEnum.sliceOfLife],
            themes: const [ThemeEnum.regal],
          ),
        ],
        lastNames: [
          _surname(name: 'Volkov', culture: LanguageEthnicityEnum.slavicRussian),
        ],
      );

      final pick = db.pickName(
        const NameFilters(
          gender: GenderEnum.female,
          languageEthnicity: LanguageEthnicityEnum.slavicRussian,
          age: AgeEnum.child,
          era: EraEnum.nineteenTwenties,
          role: RoleEnum.villain,
          intelligence: IntelligenceBucketEnum.high,
          themes: [ThemeEnum.celestial],
        ),
        <String>{},
        <String>{},
      );

      expect(pick.firstNameEntry.name, 'Mira');
      expect(pick.relaxedFilters, contains(NameFilterField.themes));
      expect(pick.relaxedFilters, contains(NameFilterField.age));
      expect(pick.relaxedFilters, contains(NameFilterField.era));
      expect(
        pick.relaxedFilters.indexOf(NameFilterField.themes),
        lessThan(pick.relaxedFilters.indexOf(NameFilterField.age)),
        reason: 'themes should drop before age',
      );
    });

    test('resets the used set within the active filter slice when exhausted', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(name: 'Hana', gender: GenderEnum.female, culture: LanguageEthnicityEnum.japanese),
          _entry(name: 'Yuki', gender: GenderEnum.female, culture: LanguageEthnicityEnum.japanese),
        ],
        lastNames: [
          _surname(name: 'Tanaka', culture: LanguageEthnicityEnum.japanese),
        ],
      );

      final usedFirst = <String>{};
      final usedLast = <String>{};
      const filters = NameFilters(languageEthnicity: LanguageEthnicityEnum.japanese);
      db.pickName(filters, usedFirst, usedLast);
      db.pickName(filters, usedFirst, usedLast);
      expect(usedFirst, hasLength(2));

      final third = db.pickName(filters, usedFirst, usedLast);

      expect(['Hana', 'Yuki'], contains(third.firstNameEntry.name));
      expect(usedFirst, hasLength(1));
      expect(usedFirst, contains(third.firstNameEntry.name));
    });

    test('surname culture always matches the first name even without a culture filter', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(name: 'Hana', culture: LanguageEthnicityEnum.japanese),
        ],
        lastNames: [
          _surname(name: 'Tanaka', culture: LanguageEthnicityEnum.japanese),
          _surname(name: 'Smith', culture: LanguageEthnicityEnum.english),
          _surname(name: 'Volkov', culture: LanguageEthnicityEnum.slavicRussian),
        ],
      );

      final pick = db.pickName(const NameFilters(), <String>{}, <String>{});

      expect(pick.firstNameEntry.languageEthnicity, LanguageEthnicityEnum.japanese);
      expect(pick.lastNameEntry.languageEthnicity, LanguageEthnicityEnum.japanese);
      expect(pick.lastNameEntry.name, 'Tanaka');
    });

    test('intelligence bucket maps low=1-2, medium=3, high=4-5', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(name: 'Dim', intelligence: 1),
          _entry(name: 'Mid', intelligence: 3),
          _entry(name: 'Sharp', intelligence: 5),
        ],
        lastNames: [_surname(name: 'Generic')],
      );

      final low = db.pickName(
        const NameFilters(intelligence: IntelligenceBucketEnum.low),
        <String>{},
        <String>{},
      );
      final mid = db.pickName(
        const NameFilters(intelligence: IntelligenceBucketEnum.medium),
        <String>{},
        <String>{},
      );
      final high = db.pickName(
        const NameFilters(intelligence: IntelligenceBucketEnum.high),
        <String>{},
        <String>{},
      );

      expect(low.firstNameEntry.name, 'Dim');
      expect(mid.firstNameEntry.name, 'Mid');
      expect(high.firstNameEntry.name, 'Sharp');
    });

    test('fantasy race pairs with fantasy ethnicity (db-level invariant)', () {
      final db = NameDatabase.forTesting(
        firstNames: [
          _entry(
            name: 'Lirien',
            culture: LanguageEthnicityEnum.fantasyElvish,
            race: RaceEnum.elf,
          ),
        ],
        lastNames: [
          _surname(
            name: 'Silverleaf',
            culture: LanguageEthnicityEnum.fantasyElvish,
            race: RaceEnum.elf,
          ),
        ],
      );

      final pick = db.pickName(
        const NameFilters(race: RaceEnum.elf),
        <String>{},
        <String>{},
      );

      expect(pick.firstNameEntry.languageEthnicity.isFantasy, isTrue);
      expect(pick.lastNameEntry.languageEthnicity.isFantasy, isTrue);
    });

    test('multi-era entry matches each of its eras', () {
      // Eleanor-style: tagged across victorian and midcentury. A request
      // for either era should pull this entry; a request for an era NOT
      // in the list (e.g. ancient) should not.
      final eleanor = _entry(
        name: 'Eleanor',
        era: const [EraEnum.victorian, EraEnum.midcentury],
      );
      final beatrice = _entry(
        name: 'Beatrice',
        era: const [EraEnum.ancient],
      );
      final db = NameDatabase.forTesting(
        firstNames: [eleanor, beatrice],
        lastNames: [_surname(name: 'Generic')],
      );

      final victorianPick = db.pickName(
        const NameFilters(era: EraEnum.victorian),
        <String>{},
        <String>{},
      );
      final midcenturyPick = db.pickName(
        const NameFilters(era: EraEnum.midcentury),
        <String>{},
        <String>{},
      );
      final ancientPick = db.pickName(
        const NameFilters(era: EraEnum.ancient),
        <String>{},
        <String>{},
      );

      expect(victorianPick.firstNameEntry.name, 'Eleanor');
      expect(midcenturyPick.firstNameEntry.name, 'Eleanor');
      expect(ancientPick.firstNameEntry.name, 'Beatrice');
    });
  });
}
