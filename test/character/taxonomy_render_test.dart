import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/src/models/taxonomy_data.dart';
import 'package:cardwave/character/src/repositories/taxonomy_repository.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TaxonomyRepository repo;
  late TaxonomyData data;

  setUpAll(() {
    final raw = File('assets/tags/taxonomy.json').readAsStringSync();
    data = TaxonomyData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    repo = TaxonomyRepository(loggingService: LoggingService());
    repo.hydrateFromJson(raw);
  });

  test('every tag references an existing group', () {
    final groupIds = data.groups.map((g) => g.groupId).toSet();
    final orphans = data.tags
        .where((t) => !groupIds.contains(t.groupId))
        .map((t) => '${t.tagId} -> ${t.groupId}')
        .toList();
    expect(orphans, isEmpty);
  });

  test('group_explain populated on every group', () {
    final missing = data.groups
        .where((g) => g.groupExplain.isEmpty)
        .map((g) => g.groupId)
        .toList();
    expect(missing, isEmpty);
  });

  group('getLlmPromptString', () {
    late String prompt;
    setUpAll(() => prompt = repo.getLlmPromptString());

    test('renders group headers and group explanations', () {
      expect(prompt, contains('[Format]'));
      expect(prompt, contains('  > What kind of card this is'));
    });

    test('renders tag explanations indented under their tag line', () {
      expect(prompt, contains('fmt_world - Lorebook'));
      expect(prompt, contains('    > World-information document'));
    });

    test('preserves synonyms and EXCLUSIVE marker', () {
      expect(
        prompt,
        contains(
          'fmt_character - Single-character (Single Character, Individual Persona) (EXCLUSIVE)',
        ),
      );
    });

    test('omits explanation lines for tags with empty tag_explain', () {
      // fmt_assistant has no tag_explain — the next line after it should
      // be the next tag, not a `> ...` continuation.
      final lines = prompt.split('\n');
      final assistantIdx = lines.indexWhere(
        (l) => l.contains('fmt_assistant - Assistant'),
      );
      expect(assistantIdx, isNot(-1));
      final next = lines[assistantIdx + 1];
      expect(next.trim().startsWith('>'), isFalse);
    });
  });

  group('buildAutoTagSchema', () {
    late Map<String, Object?> schema;
    late Map<String, Object?> properties;

    setUpAll(() {
      schema = repo.buildAutoTagSchema().jsonSchema();
      properties = (schema['properties'] as Map).cast<String, Object?>();
    });

    test('strict-mode flags set', () {
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], false);
      expect((schema['required'] as List).length, properties.length);
    });

    test('every property carries a non-empty description', () {
      for (final entry in properties.entries) {
        final prop = entry.value as Map<String, Object?>;
        final desc = prop['description'];
        expect(desc, isA<String>(), reason: '${entry.key} missing description');
        expect(
          (desc as String).isNotEmpty,
          isTrue,
          reason: '${entry.key} has empty description',
        );
      }
    });

    test('exclusive groups expose [string, null] enum including null', () {
      final formatExcl = properties['format_exclusive'] as Map<String, Object?>;
      expect(formatExcl['type'], ['string', 'null']);
      expect((formatExcl['enum'] as List).contains(null), isTrue);
    });

    test('flag groups expose array of enum strings', () {
      // tone is a flag-only group (no exclusive tags).
      final toneFlags = properties['tone_flags'] as Map<String, Object?>;
      expect(toneFlags['type'], 'array');
      final items = toneFlags['items'] as Map<String, Object?>;
      expect(items['type'], 'string');
      expect(items['enum'], isA<List<Object?>>());
    });
  });
}
