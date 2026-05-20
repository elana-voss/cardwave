import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/tree_level_enum.dart';
import 'package:cardwave_memory/src/models/tree_node.dart';
import 'package:cardwave_memory/src/observability/memory_logger.dart';
import 'package:cardwave_memory/src/utils/memory_id.dart';
import 'package:schemantic/schemantic.dart';

/// Groups already-committed scenes into chapters over their one-line
/// summaries — a separate, lower-frequency judgment from per-window event
/// extraction. Runs over numbered scene SUMMARIES, never message ids, and is
/// never called from the extraction path.
class ChapterGrouper {
  const ChapterGrouper({required this.runner, this.minScenes = 3});

  final LlmRunner runner;

  /// Skip until at least this many ungrouped scenes exist — chapter judgment
  /// is rare relative to scene commits.
  final int minScenes;

  // Output field names, named once so the schema and the parser cannot drift.
  static const _keyChapters = 'chapters';
  static const _keySceneNumbers = 'scene_numbers';
  static const _keySummary = 'summary';

  static final SchemanticType<Map<String, dynamic>> _chapterSchema =
      _buildChapterSchema();

  Future<void> groupScenes(MemoryGraph graph) async {
    final scenes = <TreeNode>[
      for (final node in graph.nodes)
        if (node.level == TreeLevelEnum.scene && node.parentId == null) node,
    ];
    if (scenes.length < minScenes) return;

    final numberToScene = <int, TreeNode>{};
    var number = 1;
    for (final scene in scenes) {
      numberToScene[number] = scene;
      number++;
    }

    final Map<String, dynamic> raw;
    try {
      raw = await runner.completeStructured(
        _buildPrompt(numberToScene),
        _chapterSchema,
      );
    } on Exception catch (error, stackTrace) {
      memoryLogger.warning(
        'Chapter grouping failed; scenes stay ungrouped.',
        error,
        stackTrace,
      );
      return;
    }

    _applyChapters(raw, numberToScene, graph);
  }

  void _applyChapters(
    Map<String, dynamic> raw,
    Map<int, TreeNode> numberToScene,
    MemoryGraph graph,
  ) {
    final chaptersJson = raw[_keyChapters];
    if (chaptersJson is! List) return;

    final byId = {for (final node in graph.nodes) node.id: node};
    final chapterNodes = <TreeNode>[];
    for (final entry in chaptersJson) {
      if (entry is! Map) continue;
      final numbersJson = entry[_keySceneNumbers];
      if (numbersJson is! List) continue;

      final childIds = <String>[];
      for (final number in numbersJson) {
        if (number is! int) continue;
        final scene = numberToScene[number];
        if (scene != null) childIds.add(scene.id);
      }
      if (childIds.isEmpty) continue;

      final chapterId = newChapterId();
      final summary = entry[_keySummary] is String
          ? entry[_keySummary] as String
          : '';
      for (final childId in childIds) {
        final scene = byId[childId];
        if (scene != null) byId[childId] = _withParent(scene, chapterId);
      }
      chapterNodes.add(
        TreeNode(
          id: chapterId,
          level: TreeLevelEnum.chapter,
          childIds: childIds,
          summary: summary,
        ),
      );
    }

    graph.nodes
      ..clear()
      ..addAll(byId.values)
      ..addAll(chapterNodes);
  }

  static TreeNode _withParent(TreeNode node, String parentId) => TreeNode(
    id: node.id,
    level: node.level,
    parentId: parentId,
    childIds: node.childIds,
    messageIds: node.messageIds,
    summary: node.summary,
    eventIds: node.eventIds,
  );

  static String _buildPrompt(Map<int, TreeNode> numberToScene) {
    final buffer = StringBuffer()
      ..writeln(
        'You group scenes of a roleplay story into chapters. Read the '
        'numbered scene summaries and decide which consecutive scenes belong '
        'to the same chapter.',
      )
      ..writeln()
      ..writeln(
        'Return "chapters", each with the "scene_numbers" it contains and a '
        'one-line "summary" of the chapter.',
      )
      ..writeln()
      ..writeln('Scenes:');
    numberToScene.forEach((number, scene) {
      buffer.writeln('$number. ${scene.summary}');
    });
    return buffer.toString();
  }

  static SchemanticType<Map<String, dynamic>> _buildChapterSchema() {
    final chapterItem = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[_keySceneNumbers, _keySummary],
      'properties': <String, Object?>{
        _keySceneNumbers: <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'integer'},
          'description': 'The numbered scenes that form this chapter.',
        },
        _keySummary: <String, Object?>{
          'type': 'string',
          'description': 'One-line chapter summary.',
        },
      },
    };
    final schema = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[_keyChapters],
      'properties': <String, Object?>{
        _keyChapters: <String, Object?>{'type': 'array', 'items': chapterItem},
      },
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }
}
