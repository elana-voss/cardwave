import 'dart:convert';

import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_names/src/models/name_filters.dart';
import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:cardwave_names/src/services/name_database.dart';

/// MCP method: returns a curated NPC name from the local database and
/// marks it as used in the active chat so it does not repeat. The tool
/// owns the database and the picking logic — fully encapsulated behind
/// the method. The active chat's used-name sets are reached through
/// [BuiltinToolAppData.usedFirstNames] / [BuiltinToolAppData.usedLastNames]
/// — the app side implements those by exposing the session's sets.
class SuggestNameTool extends ToolDefinition {
  SuggestNameTool({
    required this.promptRepository,
    required this.maxCallsPerTurn,
    required this.nameDatabase,
  });

  /// Stable wire-format name referenced from outside the tools layer.
  static const String toolName = 'suggest_name';

  final PromptRepository promptRepository;

  @override
  final int maxCallsPerTurn;

  final NameDatabase nameDatabase;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Pick a curated first + last name for a new NPC you are about to '
      'introduce. Optional filters (gender, culture, era, role, genre, '
      'themes, etc.) narrow the result; names already used in this chat '
      'are skipped automatically.';

  @override
  String get systemPromptText => promptRepository.toolSuggestNameAdvertisement;

  @override
  String get progressLabel => 'Picking a name…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) {
    return {
      'type': 'object',
      'properties': {
        'gender': _enumField(
          GenderEnum.values.names,
          'Gender of the new NPC.',
        ),
        'language_ethnicity': _enumField(
          LanguageEthnicityEnum.values.names,
          'Cultural root. Real-world for human characters; `fantasy_*` '
              'buckets for non-human races. Omit to let the tool pick '
              'freely.',
        ),
        'mythology': _enumField(
          MythologyEnum.values.names,
          'Pantheon the name should evoke (greek, norse, hindu, …).',
        ),
        'race': _enumField(
          RaceEnum.values.names,
          'Species / race of the NPC. Non-human races force a fantasy '
              'cultural bucket.',
        ),
        'age': _enumField(
          AgeEnum.values.names,
          'Lifestage the name fits.',
        ),
        'era': _enumField(
          EraEnum.values.names,
          'Period the name evokes (medieval, victorian, modern, …).',
        ),
        'role': _enumField(
          RoleEnum.values.names,
          'Narrative function — hero, villain, mentor, sidekick, …',
        ),
        'intelligence': _enumField(
          IntelligenceBucketEnum.values.names,
          'Coarse bucket — low / medium / high.',
        ),
        'allure': _enumField(
          AllureBucketEnum.values.names,
          'Coarse bucket — low / medium / high.',
        ),
        'genre': _enumField(
          GenreEnum.values.names,
          "The story's flavour (fantasy, sciFi, noirDetective, smut, …).",
        ),
        'themes': {
          'type': 'array',
          'items': {'type': 'string', 'enum': ThemeEnum.values.names},
          'description':
              'Zero or more decorative tags (celestial, gemstone, regal, '
              'nautical, …). Match is by overlap.',
        },
      },
    };
  }

  Map<String, Object?> _enumField(List<String> values, String description) {
    return {'type': 'string', 'enum': values, 'description': description};
  }

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final data = ctx.appData as BuiltinToolAppData;
    final filters = NameFilters.fromJson(args);
    final pick = nameDatabase.pickName(
      filters,
      data.usedFirstNames,
      data.usedLastNames,
    );
    return ToolResult.ok(data: jsonEncode(pick.toJson()));
  }
}
