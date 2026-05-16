// Phase 2 of the name-database build. Reads the slim JSON, sends batches
// to Grok 4.3 to fill the subjective tag fields (age, role, intelligence,
// allure, commonness, themes, genre), writes the tagged JSON.
//
// Run from app/ via:
//   dart run --define=GROK_API_KEY=xai-... tools/generate_names/classify.dart
//
// Optional flags:
//   --limit=N        cap at first N batches (smoke run; default unlimited)
//   --batch-size=N   names per request (default 100)
//   --model=MODEL    override model id (default grok-4.3)
//
// Per-batch progress is saved to
//   tools/generate_names/.cache/.classify_progress.json
// A failed run resumes from where it stopped without re-billing for
// completed batches. Delete the progress file to force a full re-run.
//
// Output: tools/generate_names/data/name_database.tagged.json

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _slimPath = 'tools/generate_names/data/name_database.slim.json';
const _outputPath = 'tools/generate_names/data/name_database.tagged.json';
const _progressPath =
    'tools/generate_names/.cache/.classify_progress.json';

const _defaultModel = 'grok-4.3';
const _defaultBatchSize = 100;
const _apiUrl = 'https://api.x.ai/v1/chat/completions';

const _grokKey = String.fromEnvironment('GROK_API_KEY');

// Taxonomy enum values — mirror cardwave_names. Must stay in sync.
const _ageValues = ['child', 'youngAdult', 'adult', 'elder'];
const _roleValues = [
  'hero', 'villain', 'mentor', 'sidekick', 'comicRelief',
  'bystander', 'loveInterest', 'antihero', 'neutral',
];
const _commonnessValues = ['rare', 'uncommon', 'common'];
const _genreValues = [
  'fantasy', 'sciFi', 'cyberpunk', 'steampunk', 'western',
  'noirDetective', 'horror', 'smut', 'modern', 'historical',
  'postApocalyptic',
];
const _themeValues = [
  'celestial', 'floral', 'gemstone', 'military', 'literary',
  'regal', 'fiery', 'icy', 'watery', 'earthy', 'airy', 'solar',
  'lunar', 'nautical', 'religious', 'scholarly', 'rustic',
  'exotic', 'mystical', 'brutish',
];

Future<void> main(List<String> args) async {
  if (_grokKey.isEmpty) {
    stderr.writeln(
      '[classify] GROK_API_KEY not set. Pass via '
      '--dart-define=GROK_API_KEY=xai-...',
    );
    exit(1);
  }

  final cli = _parseArgs(args);

  final slimFile = File(_slimPath);
  if (!slimFile.existsSync()) {
    stderr.writeln('[classify] $_slimPath missing — run slim_candidate.dart.');
    exit(1);
  }
  final slim = jsonDecode(slimFile.readAsStringSync()) as Map<String, dynamic>;
  final firstNames = (slim['first_names'] as List).cast<Map<String, dynamic>>();
  final lastNames = (slim['last_names'] as List).cast<Map<String, dynamic>>();

  stdout.writeln(
    '[load] ${firstNames.length} first names, ${lastNames.length} last '
    'names from $_slimPath',
  );

  final progress = _loadProgress();
  final completedFirst = (progress['first_done'] as List?)?.length ?? 0;
  final completedLast = (progress['last_done'] as List?)?.length ?? 0;
  if (completedFirst > 0 || completedLast > 0) {
    stdout.writeln(
      '[resume] $completedFirst first + $completedLast last names already '
      'tagged from a previous run',
    );
  }
  final firstDone = (progress['first_done'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final lastDone = (progress['last_done'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  final client = HttpClient();
  try {
    await _classifyAll(
      kind: 'first',
      entries: firstNames,
      done: firstDone,
      batchSize: cli.batchSize,
      batchLimit: cli.limit,
      model: cli.model,
      client: client,
      saveProgress: () => _saveProgress({
        'first_done': firstDone,
        'last_done': lastDone,
      }),
    );
    await _classifyAll(
      kind: 'last',
      entries: lastNames,
      done: lastDone,
      batchSize: cli.batchSize,
      batchLimit: cli.limit,
      model: cli.model,
      client: client,
      saveProgress: () => _saveProgress({
        'first_done': firstDone,
        'last_done': lastDone,
      }),
    );
  } finally {
    client.close(force: true);
  }

  // Write the final tagged JSON, then delete the progress file.
  final out = File(_outputPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'first_names': firstDone,
      'last_names': lastDone,
    }),
  );
  final progressFile = File(_progressPath);
  if (progressFile.existsSync()) progressFile.deleteSync();

  stdout.writeln(
    '[done] wrote ${firstDone.length} first + ${lastDone.length} last '
    'names → $_outputPath',
  );
}

class _Cli {
  const _Cli({required this.limit, required this.batchSize, required this.model});
  final int? limit;
  final int batchSize;
  final String model;
}

_Cli _parseArgs(List<String> args) {
  int? limit;
  var batchSize = _defaultBatchSize;
  var model = _defaultModel;
  for (final raw in args) {
    if (raw.startsWith('--limit=')) {
      limit = int.parse(raw.substring('--limit='.length));
    } else if (raw.startsWith('--batch-size=')) {
      batchSize = int.parse(raw.substring('--batch-size='.length));
    } else if (raw.startsWith('--model=')) {
      model = raw.substring('--model='.length);
    } else {
      stderr.writeln('[classify] unknown flag: $raw');
      exit(1);
    }
  }
  return _Cli(limit: limit, batchSize: batchSize, model: model);
}

Map<String, dynamic> _loadProgress() {
  final file = File(_progressPath);
  if (!file.existsSync()) return {};
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _saveProgress(Map<String, dynamic> data) {
  final file = File(_progressPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));
}

Future<void> _classifyAll({
  required String kind,
  required List<Map<String, dynamic>> entries,
  required List<Map<String, dynamic>> done,
  required int batchSize,
  required int? batchLimit,
  required String model,
  required HttpClient client,
  required void Function() saveProgress,
}) async {
  final startIndex = done.length;
  if (startIndex >= entries.length) {
    stdout.writeln('[skip] $kind names — all ${entries.length} already tagged');
    return;
  }
  final remaining = entries.sublist(startIndex);
  final totalBatches = (remaining.length + batchSize - 1) ~/ batchSize;
  final runBatches = batchLimit != null && batchLimit < totalBatches
      ? batchLimit
      : totalBatches;

  stdout.writeln(
    '[$kind] $runBatches batch(es) of up to $batchSize names '
    '(resuming from index $startIndex of ${entries.length})',
  );

  for (var b = 0; b < runBatches; b++) {
    final batchStart = b * batchSize;
    final batchEnd = (batchStart + batchSize).clamp(0, remaining.length);
    final batch = remaining.sublist(batchStart, batchEnd);

    final tagged = await _classifyBatch(
      kind: kind,
      batch: batch,
      model: model,
      client: client,
    );

    // Merge each tagged response back into the original entry, applying
    // only the fields the entry's sentinel_fields list says to fill.
    // tagged.length == batch.length is verified in _classifyBatch.
    for (var i = 0; i < batch.length; i++) {
      final orig = batch[i];
      // ignore: qcheck/avoid_unsafe_collection_methods
      final fill = tagged[i];
      _applyTags(orig, fill);
      done.add(orig);
    }
    saveProgress();

    stdout.writeln(
      '[$kind] batch ${b + 1}/$runBatches: +${batch.length} '
      '(${done.length} cumulative)',
    );
  }
}

Future<List<Map<String, dynamic>>> _classifyBatch({
  required String kind,
  required List<Map<String, dynamic>> batch,
  required String model,
  required HttpClient client,
}) async {
  final isFirstName = kind == 'first';
  final schema = isFirstName
      ? _firstNameBatchSchema(batch.length)
      : _lastNameBatchSchema(batch.length);
  final systemPrompt = isFirstName ? _firstSystemPrompt : _lastSystemPrompt;
  final userPrompt = _buildUserPrompt(kind: kind, batch: batch);

  final body = jsonEncode({
    'model': model,
    'reasoning_effort': 'none',
    'response_format': {
      'type': 'json_schema',
      'json_schema': {
        'name': 'name_tag_batch',
        'schema': schema,
        'strict': true,
      },
    },
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ],
  });

  final responseBody = await _postWithRetry(client: client, body: body);
  final json = jsonDecode(responseBody) as Map<String, dynamic>;
  final choices = json['choices'] as List;
  if (choices.isEmpty) {
    throw StateError('Grok response missing the choices array.');
  }
  final content = (choices.first as Map)['message']['content'] as String;
  final parsed = jsonDecode(content) as Map<String, dynamic>;
  final tagged = (parsed['tagged'] as List).cast<Map<String, dynamic>>();

  if (tagged.length != batch.length) {
    throw StateError(
      'Grok returned ${tagged.length} tagged records for a batch of '
      '${batch.length}. Aborting.',
    );
  }
  return tagged;
}

Future<String> _postWithRetry({
  required HttpClient client,
  required String body,
}) async {
  const maxAttempts = 4;
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      final request = await client.postUrl(Uri.parse(_apiUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $_grokKey');
      request.write(body);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return text;
      if (response.statusCode == 429) {
        final retryAfter =
            int.tryParse(response.headers.value('retry-after') ?? '') ?? 5;
        stderr.writeln('[retry] 429 — waiting ${retryAfter}s');
        await Future<void>.delayed(Duration(seconds: retryAfter));
        continue;
      }
      if (response.statusCode >= 500 && attempt < maxAttempts) {
        final wait = 1 << (attempt - 1);
        stderr.writeln(
          '[retry] HTTP ${response.statusCode} — waiting ${wait}s '
          '(attempt $attempt/$maxAttempts)',
        );
        await Future<void>.delayed(Duration(seconds: wait));
        continue;
      }
      throw HttpException(
        'Grok returned HTTP ${response.statusCode}: '
        '${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
      );
    } on SocketException catch (e) {
      if (attempt >= maxAttempts) rethrow;
      final wait = 1 << (attempt - 1);
      stderr.writeln('[retry] network error: $e — waiting ${wait}s');
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }
}

const _firstSystemPrompt = '''
You assign tags to character first names for a roleplay name database.
For each name, fill in age, role, intelligence (1-5), allure (1-5),
commonness, themes, and genre based on the name's cultural, historical,
and recognizability feel.

Never invent names — only tag the names provided.
Tag each name in isolation; treat the list as independent items.
Be consistent: the same name across batches should get similar tags.

`commonness=common` means the name is one most readers recognize
(Mary, John, Yamato). `rare` means distinctive / unusual (Polkinghorne,
Cthulhu, Sarepta). `uncommon` is the middle.

`themes` and `genre` are zero-or-more arrays. Pick only tags that
clearly fit; leave empty if no strong association.
''';

const _lastSystemPrompt = '''
You assign tags to character surnames for a roleplay name database.
For each surname, fill in commonness, themes, and genre based on the
name's cultural, historical, and recognizability feel.

Never invent names — only tag the surnames provided.
Tag each name in isolation.

`commonness=common` means a surname most readers recognize (Smith,
Garcia, Yamamoto). `rare` means distinctive / unusual (Polkinghorne,
Featherstonehaugh). `uncommon` is the middle.

`themes` and `genre` are zero-or-more arrays. Pick only tags that
clearly fit; leave empty if no strong association.
''';

String _buildUserPrompt({
  required String kind,
  required List<Map<String, dynamic>> batch,
}) {
  final buf = StringBuffer();
  buf.writeln(
    'Tag these ${batch.length} ${kind == 'first' ? 'first names' : 'surnames'}. '
    'Use the known facts as context for each.',
  );
  buf.writeln();
  for (var i = 0; i < batch.length; i++) {
    final e = batch[i];
    final name = e['name'];
    final knownParts = <String>[];
    if (kind == 'first') {
      knownParts.add('gender=${e['gender']}');
    }
    knownParts.add('language=${e['language_ethnicity']}');
    if (e['mythology'] != null) knownParts.add('mythology=${e['mythology']}');
    knownParts.add('race=${e['race']}');
    knownParts.add('era=${e['era']}');
    final genre = (e['genre'] as List).cast<String>();
    if (genre.isNotEmpty) knownParts.add('genre=${genre.join('|')}');
    final themes = (e['themes'] as List).cast<String>();
    if (themes.isNotEmpty) knownParts.add('themes=${themes.join('|')}');
    buf.writeln('${i + 1}. $name  (${knownParts.join(', ')})');
  }
  return buf.toString();
}

Map<String, dynamic> _firstNameBatchSchema(int count) {
  return {
    'type': 'object',
    'properties': {
      'tagged': {
        'type': 'array',
        'minItems': count,
        'maxItems': count,
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'age': {'type': 'string', 'enum': _ageValues},
            'role': {'type': 'string', 'enum': _roleValues},
            'intelligence': {'type': 'integer', 'minimum': 1, 'maximum': 5},
            'allure': {'type': 'integer', 'minimum': 1, 'maximum': 5},
            'commonness': {'type': 'string', 'enum': _commonnessValues},
            'themes': {
              'type': 'array',
              'items': {'type': 'string', 'enum': _themeValues},
            },
            'genre': {
              'type': 'array',
              'items': {'type': 'string', 'enum': _genreValues},
            },
          },
          'required': [
            'name', 'age', 'role', 'intelligence', 'allure',
            'commonness', 'themes', 'genre',
          ],
          'additionalProperties': false,
        },
      },
    },
    'required': ['tagged'],
    'additionalProperties': false,
  };
}

Map<String, dynamic> _lastNameBatchSchema(int count) {
  return {
    'type': 'object',
    'properties': {
      'tagged': {
        'type': 'array',
        'minItems': count,
        'maxItems': count,
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'commonness': {'type': 'string', 'enum': _commonnessValues},
            'themes': {
              'type': 'array',
              'items': {'type': 'string', 'enum': _themeValues},
            },
            'genre': {
              'type': 'array',
              'items': {'type': 'string', 'enum': _genreValues},
            },
          },
          'required': ['name', 'commonness', 'themes', 'genre'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['tagged'],
    'additionalProperties': false,
  };
}

/// Merge Grok's tag answer into the entry, but only for fields the
/// entry's sentinel_fields list says were unfilled. Then drop the
/// sentinel_fields key from the entry.
void _applyTags(Map<String, dynamic> entry, Map<String, dynamic> tagged) {
  final sentinels =
      (entry['sentinel_fields'] as List?)?.cast<String>().toSet() ?? const {};

  if (sentinels.contains('age') && tagged.containsKey('age')) {
    entry['age'] = tagged['age'];
  }
  if (sentinels.contains('role') && tagged.containsKey('role')) {
    entry['role'] = tagged['role'];
  }
  if (sentinels.contains('intelligence') &&
      tagged.containsKey('intelligence')) {
    entry['intelligence'] = tagged['intelligence'];
  }
  if (sentinels.contains('allure') && tagged.containsKey('allure')) {
    entry['allure'] = tagged['allure'];
  }
  if (sentinels.contains('commonness') && tagged.containsKey('commonness')) {
    entry['commonness'] = tagged['commonness'];
  }
  if (sentinels.contains('themes') && tagged.containsKey('themes')) {
    entry['themes'] = tagged['themes'];
  }
  if (sentinels.contains('genre') && tagged.containsKey('genre')) {
    entry['genre'] = tagged['genre'];
  }

  entry.remove('sentinel_fields');
}
