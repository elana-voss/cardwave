// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'name_pick.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NamePick _$NamePickFromJson(Map<String, dynamic> json) => NamePick(
  firstNameEntry: NameEntry.fromJson(
    json['first_name_entry'] as Map<String, dynamic>,
  ),
  lastNameEntry: NameSurname.fromJson(
    json['last_name_entry'] as Map<String, dynamic>,
  ),
  relaxedFilters: (json['relaxed_filters'] as List<dynamic>)
      .map((e) => $enumDecode(_$NameFilterFieldEnumMap, e))
      .toList(),
);

Map<String, dynamic> _$NamePickToJson(NamePick instance) => <String, dynamic>{
  'first_name_entry': instance.firstNameEntry.toJson(),
  'last_name_entry': instance.lastNameEntry.toJson(),
  'relaxed_filters': instance.relaxedFilters
      .map((e) => _$NameFilterFieldEnumMap[e]!)
      .toList(),
};

const _$NameFilterFieldEnumMap = {
  NameFilterField.gender: 'gender',
  NameFilterField.languageEthnicity: 'languageEthnicity',
  NameFilterField.mythology: 'mythology',
  NameFilterField.race: 'race',
  NameFilterField.age: 'age',
  NameFilterField.era: 'era',
  NameFilterField.role: 'role',
  NameFilterField.intelligence: 'intelligence',
  NameFilterField.allure: 'allure',
  NameFilterField.genre: 'genre',
  NameFilterField.themes: 'themes',
};
