// Offline name-database generator. Calls Anthropic's API per batch and
// writes the result to packages/cardwave_names/assets/name_database.json.
//
// Run from app/ via:
//   dart run --define=ANTHROPIC_API_KEY=sk-ant-... tools/generate_names/generate.dart
//
// Optional: --limit=N to cap the number of batches for a smoke run.
//
// Progress is tracked in tools/generate_names/.progress so a failed run
// resumes without re-billing for completed batches.

import 'dart:convert';
import 'dart:io';

import 'package:cardwave_names/cardwave_names.dart';
import 'package:http/http.dart' as http;

import 'spec.dart';

const String _model = 'claude-opus-4-7';
const String _apiUrl = 'https://api.anthropic.com/v1/messages';
const int _maxTokens = 4096;
const String _anthropicVersion = '2023-06-01';

const String _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

const String _outputPath =
    'packages/cardwave_names/assets/name_database.json';
const String _progressPath = 'tools/generate_names/.progress';

Future<void> main(List<String> args) async {
  if (_apiKey.isEmpty) {
    stderr.writeln(
      'ANTHROPIC_API_KEY is empty. Pass it via '
      '--define=ANTHROPIC_API_KEY=sk-ant-...',
    );
    exit(64);
  }

  final limit = _parseLimit(args);
  final firstBatches = _planFirstNameBatches();
  final surnameBatches = _planSurnameBatches();
  final allBatches = [...firstBatches, ...surnameBatches];
  final progress = _loadProgress();

  final existing = _loadExistingOutput();
  final firstAccum = existing.$1;
  final lastAccum = existing.$2;

  var done = 0;
  for (final batch in allBatches) {
    if (limit != null && done >= limit) break;
    done++;

    final key = batch.progressKey;
    if (progress.contains(key)) {
      stdout.writeln('[skip] $key (already done)');
      continue;
    }
    stdout.writeln('[batch $done/${allBatches.length}] $key');

    try {
      if (batch is _FirstBatch) {
        final names = await _generateFirstNames(batch);
        firstAccum.addAll(names);
      } else if (batch is _SurnameBatch) {
        final surnames = await _generateSurnames(batch);
        lastAccum.addAll(surnames);
      }
      progress.add(key);
      _saveProgress(progress);
      _saveOutput(firstAccum, lastAccum);
    } on Exception catch (e) {
      stderr.writeln('  failed: $e — stopping. Re-run to resume.');
      exit(1);
    }
  }

  final deduped = _dedupe(firstAccum, lastAccum);
  _saveOutput(deduped.$1, deduped.$2);
  stdout.writeln(
    'Done. ${deduped.$1.length} first names + ${deduped.$2.length} '
    'surnames written to $_outputPath.',
  );
}

int? _parseLimit(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--limit=')) {
      return int.tryParse(arg.substring('--limit='.length));
    }
  }
  return null;
}

abstract class _Batch {
  String get progressKey;
}

class _FirstBatch implements _Batch {
  const _FirstBatch({
    required this.genre,
    required this.culture,
    required this.gender,
  });
  final GenreEnum genre;
  final LanguageEthnicityEnum culture;
  final GenderEnum gender;

  @override
  String get progressKey => 'first:${genre.name}:${culture.name}:${gender.name}';
}

class _SurnameBatch implements _Batch {
  const _SurnameBatch({required this.culture});
  final LanguageEthnicityEnum culture;

  @override
  String get progressKey => 'surname:${culture.name}';
}

List<_FirstBatch> _planFirstNameBatches() {
  final batches = <_FirstBatch>[];
  for (final genreEntry in genreCultureAllowlist.entries) {
    for (final culture in genreEntry.value) {
      for (final gender in GenderEnum.values) {
        batches.add(
          _FirstBatch(
            genre: genreEntry.key,
            culture: culture,
            gender: gender,
          ),
        );
      }
    }
  }
  return batches;
}

List<_SurnameBatch> _planSurnameBatches() {
  return [
    for (final culture in LanguageEthnicityEnum.values)
      _SurnameBatch(culture: culture),
  ];
}

Future<List<NameEntry>> _generateFirstNames(_FirstBatch batch) async {
  final raceHint = batch.culture.isFantasy
      ? _raceHintForCulture(batch.culture)
      : 'human';
  final prompt = '''
Generate $firstNamesPerBatch first names that fit ALL of these tags:

- gender: ${batch.gender.name}
- languageEthnicity: ${batch.culture.name}
- race: $raceHint
- genre: ${batch.genre.name}

For each name, return tagged with: gender, languageEthnicity, mythology
(or null), race, age (child / youngAdult / adult / elder), era (one of:
${EraEnum.values.map((e) => e.name).join(', ')}), role (one of:
${RoleEnum.values.map((e) => e.name).join(', ')}), intelligence (1-5),
sexyness (1-5), genre (array, this batch's genre plus any others that
fit), themes (array of zero or more: ${ThemeEnum.values.map((e) => e.name).join(', ')}).

Do NOT use any of these AIism names: ${aiismRejectList.join(', ')}.
Names should be plausible within ${batch.culture.name}; for fantasy
buckets, use the stylistic conventions of the matching race (Tolkien-
Elvish high vowels, Norse-Dwarvish hard consonants, etc.). Each name
should be distinct in feel from the others in this batch.

Return ONLY a JSON object:
{
  "names": [
    { "name": "...", "gender": "...", "languageEthnicity": "...",
      "mythology": null, "race": "...", "age": "...", "era": "...",
      "role": "...", "intelligence": 0, "sexyness": 0,
      "genre": ["..."], "themes": ["..."] }
  ]
}
''';
  final json = await _callAnthropic(prompt);
  final namesRaw = (json['names'] as List?) ?? const [];
  return namesRaw
      .map((e) => NameEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<NameSurname>> _generateSurnames(_SurnameBatch batch) async {
  final raceHint = batch.culture.isFantasy
      ? _raceHintForCulture(batch.culture)
      : 'human';
  final cultureNote = _surnameCultureNote(batch.culture);
  final prompt = '''
Generate $surnamesPerBatch surnames in the style of
${batch.culture.name}. $cultureNote

For each, return tagged with: languageEthnicity, mythology (or null),
race (default to $raceHint unless the name is mythological), era (one
of: ${EraEnum.values.map((e) => e.name).join(', ')}), genre (array of
zero or more: ${GenreEnum.values.map((e) => e.name).join(', ')}), themes
(array of zero or more: ${ThemeEnum.values.map((e) => e.name).join(', ')}).

Return ONLY a JSON object:
{
  "surnames": [
    { "name": "...", "languageEthnicity": "${batch.culture.name}",
      "mythology": null, "race": "$raceHint", "era": "...",
      "genre": ["..."], "themes": ["..."] }
  ]
}
''';
  final json = await _callAnthropic(prompt);
  final surnamesRaw = (json['surnames'] as List?) ?? const [];
  return surnamesRaw
      .map((e) => NameSurname.fromJson(e as Map<String, dynamic>))
      .toList();
}

String _raceHintForCulture(LanguageEthnicityEnum culture) {
  for (final entry in raceToFantasyCulture.entries) {
    if (entry.value == culture) return entry.key.name;
  }
  return 'human';
}

// Sparse on purpose — cultures not listed fall through to the generic
// "use names typical of this culture" hint at the call site.
// ignore: avoid_missing_enum_constant_in_map
const Map<LanguageEthnicityEnum, String> _surnameCultureNotes = {
  LanguageEthnicityEnum.slavicRussian:
      'Use patronymic suffixes (-ov / -ova, -ovich / -ovna) and noble '
          'roots. Gender-inflect endings.',
  LanguageEthnicityEnum.japanese:
      'Use locative/nature-based roots (Yamamoto = base of mountain, '
          'Tanaka = rice field).',
  LanguageEthnicityEnum.irishGaelic:
      "Use Mac- / O'- prefixes plus genitive forms.",
  LanguageEthnicityEnum.arabic:
      'Use bin/ibn (son of) chains and Al- (family / tribe) prefixes.',
  LanguageEthnicityEnum.german:
      'Mix occupational roots (Schmidt, Müller) and noble von-prefixed.',
  LanguageEthnicityEnum.fantasyElvish:
      'Use Tolkien-style high-vowel constructions with melodic '
          'multi-syllable endings.',
  LanguageEthnicityEnum.fantasyDwarven:
      'Use Norse-Dwarven hard consonants and short, percussive '
          'syllables.',
};

String _surnameCultureNote(LanguageEthnicityEnum culture) =>
    _surnameCultureNotes[culture] ?? 'Use names typical of this culture.';

Future<Map<String, dynamic>> _callAnthropic(String prompt) async {
  final body = jsonEncode({
    'model': _model,
    'max_tokens': _maxTokens,
    'messages': [
      {'role': 'user', 'content': prompt},
    ],
  });

  final response = await http.post(
    Uri.parse(_apiUrl),
    headers: {
      'x-api-key': _apiKey,
      'anthropic-version': _anthropicVersion,
      'content-type': 'application/json',
    },
    body: body,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Anthropic API ${response.statusCode}: ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final content = (decoded['content'] as List?) ?? const [];
  if (content.isEmpty) {
    throw Exception('Empty response: ${response.body}');
  }
  final text = (content.first as Map<String, dynamic>)['text'] as String;
  return jsonDecode(_extractJson(text)) as Map<String, dynamic>;
}

/// Strips markdown fences if the model wrapped JSON in ```json ... ```.
String _extractJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('```')) {
    final firstNewline = trimmed.indexOf('\n');
    final lastFence = trimmed.lastIndexOf('```');
    if (firstNewline > 0 && lastFence > firstNewline) {
      return trimmed.substring(firstNewline + 1, lastFence).trim();
    }
  }
  return trimmed;
}

Set<String> _loadProgress() {
  final file = File(_progressPath);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toSet();
}

void _saveProgress(Set<String> progress) {
  File(_progressPath).writeAsStringSync(progress.join('\n'));
}

(List<NameEntry>, List<NameSurname>) _loadExistingOutput() {
  final file = File(_outputPath);
  if (!file.existsSync()) return (<NameEntry>[], <NameSurname>[]);
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final first = ((json['firstNames'] as List?) ?? const [])
        .map((e) => NameEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final last = ((json['lastNames'] as List?) ?? const [])
        .map((e) => NameSurname.fromJson(e as Map<String, dynamic>))
        .toList();
    return (first, last);
  } on Exception {
    return (<NameEntry>[], <NameSurname>[]);
  }
}

void _saveOutput(List<NameEntry> firstNames, List<NameSurname> lastNames) {
  final json = {
    'firstNames': firstNames.map((e) => e.toJson()).toList(),
    'lastNames': lastNames.map((e) => e.toJson()).toList(),
  };
  File(_outputPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
}

(List<NameEntry>, List<NameSurname>) _dedupe(
  List<NameEntry> firstNames,
  List<NameSurname> lastNames,
) {
  final rejectLower = aiismRejectList.map((s) => s.toLowerCase()).toSet();
  final firstSeen = <String>{};
  final firstOut = <NameEntry>[];
  for (final e in firstNames) {
    final key = e.name.toLowerCase();
    if (rejectLower.contains(key)) continue;
    if (firstSeen.add(key)) firstOut.add(e);
  }
  final lastSeen = <String>{};
  final lastOut = <NameSurname>[];
  for (final s in lastNames) {
    final key = s.name.toLowerCase();
    if (lastSeen.add(key)) lastOut.add(s);
  }
  return (firstOut, lastOut);
}
