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
// completed batches. The file is NOT deleted on success — a re-run
// will detect everything is done and exit immediately. Delete the
// progress file manually to force a full re-classify.
//
// Output: tools/generate_names/data/name_database.tagged.json

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'loaders/local_taxonomy.dart';

const _slimPath = 'tools/generate_names/data/name_database.slim.json';
const _outputPath = 'tools/generate_names/data/name_database.tagged.json';
const _progressPath =
    'tools/generate_names/.cache/.classify_progress.json';

const _defaultModel = 'grok-4.3';
const _defaultBatchSize = 100;
const _apiUrl = 'https://api.x.ai/v1/chat/completions';
const _defaultRetryAfterSeconds = 5;

const _grokKey = String.fromEnvironment('GROK_API_KEY');

// Taxonomy enum value lists sourced from `local_taxonomy.dart`, which
// mirrors `cardwave_names`. Single source of truth: an enum value
// rename or addition flows here automatically.
final _ageValues = AgeEnum.values.names;
final _roleValues = RoleEnum.values.names;
final _eraValues = EraEnum.values.names;
final _intelligenceValues = IntelligenceEnum.values.names;
final _allureValues = AllureEnum.values.names;
final _commonnessValues = CommonnessEnum.values.names;
final _genreValues = GenreEnum.values.names;
final _themeValues = ThemeEnum.values.names;

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
  final totals = _TokenTotals()
    ..loadFrom(progress['tokens'] as Map<String, dynamic>?);
  if (totals.batches > 0) {
    stdout.writeln(
      '[resume] token totals so far: ${totals.batches} batches, '
      '${totals.promptTokens} input + ${totals.completionTokens} output',
    );
  }

  Map<String, dynamic> progressSnapshot() => {
    'first_done': firstDone,
    'last_done': lastDone,
    'tokens': totals.toJson(),
  };

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
      totals: totals,
      saveProgress: () => _saveProgress(progressSnapshot()),
    );
    await _classifyAll(
      kind: 'last',
      entries: lastNames,
      done: lastDone,
      batchSize: cli.batchSize,
      batchLimit: cli.limit,
      model: cli.model,
      client: client,
      totals: totals,
      saveProgress: () => _saveProgress(progressSnapshot()),
    );
  } finally {
    client.close(force: true);
  }

  stdout.writeln(
    '[tokens] total: ${totals.batches} batches, '
    '${totals.promptTokens} input + ${totals.completionTokens} output '
    '= ${totals.total} tokens',
  );

  // Write the final tagged JSON. Keep the progress file so re-runs
  // can detect that work is done and skip re-billing. Delete it
  // manually to force a clean re-classify.
  final out = File(_outputPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'first_names': firstDone,
      'last_names': lastDone,
    }),
  );

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
  required _TokenTotals totals,
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

    final result = await _classifyBatch(
      kind: kind,
      batch: batch,
      model: model,
      client: client,
    );
    totals.add(result.promptTokens, result.completionTokens);

    // Strict JSON schema enforces shape, not content — Grok can drop or
    // rename input names in the response. Index by name; for any input
    // name missing from the response, keep its sentinel tags so the
    // overall run survives one-off model misses.
    final byName = <String, Map<String, dynamic>>{};
    for (final t in result.tagged) {
      final n = (t['name'] as String).toLowerCase();
      byName[n] = t;
    }
    var missed = 0;
    for (final orig in batch) {
      final key = (orig['name'] as String).toLowerCase();
      final fill = byName[key];
      if (fill == null) {
        missed += 1;
        stderr.writeln('[$kind] missed: "${orig['name']}"');
      } else {
        _applyTags(orig, fill);
      }
      done.add(orig);
    }
    saveProgress();

    stdout.writeln(
      '[$kind] batch ${b + 1}/$runBatches: +${batch.length} '
      '(missed $missed; ${done.length} cumulative; '
      '+${result.promptTokens} in / +${result.completionTokens} out; '
      'run ${totals.promptTokens} in / ${totals.completionTokens} out)',
    );
  }
}

class _TokenTotals {
  int promptTokens = 0;
  int completionTokens = 0;
  int batches = 0;

  void add(int prompt, int completion) {
    batches += 1;
    promptTokens += prompt;
    completionTokens += completion;
  }

  int get total => promptTokens + completionTokens;

  Map<String, int> toJson() => {
    'prompt_tokens': promptTokens,
    'completion_tokens': completionTokens,
    'batches': batches,
  };

  void loadFrom(Map<String, dynamic>? json) {
    if (json == null) return;
    promptTokens = (json['prompt_tokens'] as int?) ?? 0;
    completionTokens = (json['completion_tokens'] as int?) ?? 0;
    batches = (json['batches'] as int?) ?? 0;
  }
}

typedef _BatchResult = ({
  List<Map<String, dynamic>> tagged,
  int promptTokens,
  int completionTokens,
});

Future<_BatchResult> _classifyBatch({
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

  // Usage block in OpenAI-compatible responses: {prompt_tokens,
  // completion_tokens, total_tokens}. Defaults to 0 if missing.
  final usage = (json['usage'] as Map<String, dynamic>?) ?? const {};
  return (
    tagged: tagged,
    promptTokens: (usage['prompt_tokens'] as int?) ?? 0,
    completionTokens: (usage['completion_tokens'] as int?) ?? 0,
  );
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
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $_grokKey');
      // .write() encodes as Latin-1, which fails on non-ASCII names
      // (Ailín, Akgül, …). Send raw UTF-8 bytes instead.
      request.add(utf8.encode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return text;
      if (response.statusCode == 429) {
        final retryAfter =
            int.tryParse(response.headers.value('retry-after') ?? '') ??
                _defaultRetryAfterSeconds;
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

final _firstSystemPrompt = '''
You assign tags to character first names for a roleplay name database.
For each name, fill in age, era, role, intelligence, allure, commonness,
themes, and genre based on the name's cultural, historical, and
phonetic feel. Tag the name itself — not a hypothetical bearer.

RULES:
- NEVER invent names — only tag the names provided.
- Tag each name in isolation; treat the list as independent items.
- Same name across batches should get the same tags.
- Use the known facts (gender, language, race, mythology) as context
  — an ancient Greek name should not be tagged like a contemporary
  English one.
- `age`, `era`, `role` are ARRAYS. Pick the values that fit the name,
  capped at 3 per field. NEVER return an empty array for these — pick
  at least one value.
- `themes` and `genre` are ARRAYS. Pick the values that fit. Empty is
  allowed when none of the listed values fits.

FIELD DEFINITIONS:

`age` (array, 1-3 values) — lifestages the name evokes. Available:
  child       — names mostly used for young children (Bobby, Tommy)
  youngAdult  — names that feel teen / early-twenties (Tyler, Becky)
  adult       — names with no strong age lock (Sarah, James)
  elder       — names that feel old-fashioned / retired (Ethel, Wilbur)

`era` (array, 1-3 values) — periods the name evokes. Available:
  ancient          — pre-medieval, classical / mythological (Apollo, Lysander, Diana)
  medieval         — Anglo-Saxon, Norman, Arthurian (Aldous, Hildegard, Roland)
  renaissance      — 15th–17th century (Lorenzo, Cosimo, Beatrice)
  victorian        — 1837–1901 (Edith, Reginald, Florence)
  nineteenTwenties — flapper era (Mabel, Vivian, Buster)
  midcentury       — 1940s–1960s (Patricia, Donald, Carol)
  modern           — Modernist period (~1880s–1960s), broad umbrella over the four above (Eleanor, Theodore)
  contemporary     — present day / very recent past (Mason, Aiden, Aria)
  nearFuture       — sci-fi-coded near future (Zephyr, Kael, Nova)
  farFuture        — alien-coded far future (Xax, Vyn, Korr)
  timeless         — spans many eras with no period lock (Mary, John, Anna)

`role` (array, 1-3 values) — narrative archetypes the name evokes.
Available values:
  hero          — heroic / protagonist-coded (Arthur, Diana)
  villain       — villain-coded (Maleficent, Lucius)
  mentor        — wise / authoritative (Albus, Gandalf, Persephone)
  sidekick      — supporting-cast feel (Buck, Robin, Mabel)
  comicRelief   — comedic / goofy (Bambi, Lumpkin)
  bystander     — background NPC feel (Bob, Dave, Linda)
  loveInterest  — romantic-lead feel (Romeo, Juliet, Aphrodite)
  antihero      — morally grey / edgy (Wolverine, Vex)
  neutral       — no strong archetype

`intelligence` — how cerebral / sophisticated the NAME sounds (not the
bearer's actual IQ). Phonetics + cultural connotation. Available:
  blunt       — unsophisticated (Bubba, Skip, Hank)
  plain       — simple (Bob, Mary)
  average     — phonetics carry no strong intelligence signal
  thoughtful  — literate (Eleanor, Theodore)
  bookish     — calculating / cerebral (Reginald, Persephone, Cassius)

`allure` — how sensually / aesthetically attractive the NAME sounds
(not the bearer's looks). Phonetics + cultural connotation. Available:
  harsh         — grating (Mildred, Gary, Bertha)
  unremarkable  — plain-sounding (John, Anna)
  pleasant      — phonetics carry no strong allure signal
  pretty        — soft (Lily, Adrian)
  striking      — sensual / dramatic (Aphrodite, Seraphina, Lysander)

`commonness` — how recognizable to a general audience. One of:
  common    — household names most readers know (Mary, John)
  uncommon  — somewhat known but not everyday
  rare      — distinctive / unusual (Polkinghorne, Cthulhu, Sarepta)

`themes` — decorative tags the name evokes. Available:
  ${_themeValues.join(', ')}

`genre` — story flavours the name fits. Empty is allowed when none of
the listed values fits. Available:
  fantasy         — magic / mythic / sword & sorcery (Aelar, Lirien, Galadriel)
  sciFi           — space / future tech / alien-coded (Zephyr, Korr, Nyx)
  cyberpunk       — neon / dystopian / hacker handles (Glitch, Razor, Spike)
  steampunk       — Victorian-mechanical (Aurelius, Cogsworth, Phineas)
  western         — frontier / cowboy (Wyatt, Jesse, Clementine)
  noirDetective   — hardboiled / 1920s–50s urban (Cassius, Vince, Lash)
  horror          — gothic / sinister phonetics (Edgar, Lavinia, Vlad)
  smut            — sensual / romance-lead (Aphrodite, Seraphina, Lysander)
  sliceOfLife     — grounded everyday real-world names (Sarah, Yuki, Aiden)
  postApocalyptic — wasteland / survivor-coded (Raze, Ash, Vex)
''';

final _lastSystemPrompt = '''
You assign tags to character surnames for a roleplay name database.
For each surname, fill in role, allure, commonness, themes, and genre
based on the name's cultural, historical, and phonetic feel.

RULES:
- NEVER invent names — only tag the surnames provided.
- Tag each name in isolation.
- Same name across batches should get the same tags.
- Use the known facts (language, era, race, mythology) as context.
- `role` is an ARRAY. Pick the archetypes that fit, capped at 3. NEVER
  return an empty array — pick at least one value.
- `themes` and `genre` are ARRAYS. Empty is allowed when none of the
  listed values fits.

FIELD DEFINITIONS:

`role` (array, 1-3 values) — narrative archetypes the surname evokes.
Available:
  hero          — heroic / valorous-sounding (Ashford, Pendragon)
  villain       — villain-coded / sinister-sounding (Blackwood, Ravencrest, Grimshaw)
  mentor        — wise / scholarly (Pemberton, Aldwych)
  sidekick      — supporting-cast feel (Brown, Wells, Stubbs)
  comicRelief   — goofy / clumsy-sounding (Bumble, Pratt)
  bystander     — background-NPC feel (Smith, Jones, Davis)
  loveInterest  — romantic / lyrical (Beauregard, Verlaine)
  antihero      — morally grey / edgy (Steele, Drake, Vex)
  neutral       — no strong archetype

`allure` — how sensually / aesthetically attractive the SURNAME sounds.
Phonetics + cultural connotation. Available:
  harsh         — grating (Gussard, Drupp)
  unremarkable  — plain-sounding (Smith, Jones)
  pleasant      — phonetics carry no strong allure signal
  pretty        — soft (Vega, Ashford)
  striking      — sophisticated / dramatic (Featherstonehaugh, Silvercrest, Belmonte)

`commonness` — how recognizable to a general audience. One of:
  common    — surnames most readers know (Smith, Garcia, Yamamoto)
  uncommon  — somewhat known but not everyday
  rare      — distinctive / unusual (Polkinghorne, Featherstonehaugh)

`themes` — decorative tags the surname evokes. Empty is allowed when
none of the listed values fits. Available:
  ${_themeValues.join(', ')}

`genre` — story flavours the surname fits. Empty is allowed when none
of the listed values fits. Available:
  fantasy         — fae / elvish / mythic (Silverleaf, Ravencrest, Stormwind)
  sciFi           — alien-coded / future (Voss, Stellaris, Korr)
  cyberpunk       — corp / street / Japanese-loan (Saburo, Kazama, Nakamura)
  steampunk       — Victorian-mechanical (Aetherson, Cogsworth, Brassington)
  western         — frontier / homesteader (McCoy, Calhoun, Dalton)
  noirDetective   — hardboiled / urban (Diamond, Sharpe, Vance)
  horror          — gothic / sinister (Blackwood, Ashworth, Ravenscroft)
  smut            — sensual / poetic (Beauregard, Verlaine, Belmonte)
  sliceOfLife     — grounded everyday surnames (Smith, Tanaka, Garcia)
  postApocalyptic — wasteland / survivor (Ash, Storm, Crow)
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
    final eras = (e['era'] as List).cast<String>();
    knownParts.add('era=${eras.join('|')}');
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
            'age': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 3,
              'items': {'type': 'string', 'enum': _ageValues},
            },
            'era': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 3,
              'items': {'type': 'string', 'enum': _eraValues},
            },
            'role': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 3,
              'items': {'type': 'string', 'enum': _roleValues},
            },
            'intelligence': {'type': 'string', 'enum': _intelligenceValues},
            'allure': {'type': 'string', 'enum': _allureValues},
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
            'name', 'age', 'era', 'role', 'intelligence', 'allure',
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
            'role': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 3,
              'items': {'type': 'string', 'enum': _roleValues},
            },
            'allure': {'type': 'string', 'enum': _allureValues},
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
          'required': ['name', 'role', 'allure', 'commonness', 'themes', 'genre'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['tagged'],
    'additionalProperties': false,
  };
}

/// Fields Grok can fill on a sentinel-marked entry. Gender stays off
/// the list — the loader either knows it or it doesn't, Grok doesn't
/// classify it. Wire-format strings match the JSON keys and the
/// SentinelField enum names.
const _llmFillableFields = <String>[
  'age', 'era', 'role',
  'intelligence', 'allure', 'commonness',
  'themes', 'genre',
];

/// Merge Grok's tag answer into the entry, but only for fields the
/// entry's sentinel_fields list says were unfilled. Then drop the
/// sentinel_fields key from the entry.
void _applyTags(Map<String, dynamic> entry, Map<String, dynamic> tagged) {
  final sentinels =
      (entry['sentinel_fields'] as List?)?.cast<String>().toSet() ?? const {};
  for (final field in _llmFillableFields) {
    if (sentinels.contains(field) && tagged.containsKey(field)) {
      entry[field] = tagged[field];
    }
  }

  entry.remove('sentinel_fields');
}
