import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_nodes/src/models/event_log_entry.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/nodes/node_pool.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// Rough char-to-token ratio for the budget estimate. Real tokenizers
/// vary by model and language; 4 is the standard rule of thumb for
/// English-language tokenizers and is the value the spec assumes.
const double _charsPerToken = 4.0;

/// Emotion value above which the state slice surfaces the field in the
/// actor's prompt. Below it, the emotion is too quiet to mention.
const double _prominentEmotionThreshold = 0.5;

/// Per-section character counts for the assembled dynamic block, plus
/// the running total and the budget the assembler was given. The debug
/// view shows this so a developer can see which section ate the budget
/// and which got dropped under pressure.
class PromptBreakdown {
  const PromptBreakdown({
    required this.sceneChars,
    required this.stateChars,
    required this.lingeringChars,
    required this.directivesChars,
    required this.nowChars,
    required this.earlierChars,
    required this.totalChars,
    required this.budgetChars,
  });

  static const PromptBreakdown empty = PromptBreakdown(
    sceneChars: 0,
    stateChars: 0,
    lingeringChars: 0,
    directivesChars: 0,
    nowChars: 0,
    earlierChars: 0,
    totalChars: 0,
    budgetChars: 0,
  );

  final int sceneChars;
  final int stateChars;
  final int lingeringChars;
  final int directivesChars;
  final int nowChars;
  final int earlierChars;
  final int totalChars;
  final int budgetChars;
}

/// What [PromptAssembler.assembleDynamicSections] returns: the dynamic
/// text the host splices into the actor's system prompt, and the
/// breakdown of section sizes for the debug view.
typedef DynamicSectionsResult = ({
  String text,
  PromptBreakdown breakdown,
});

/// Builds the actor's per-turn prompt by stacking, in spec §8.1 order:
///   1. world and scene state
///   2. character definition (caller-supplied)
///   3. session state slice (goal, phase, prominent emotions)
///   4. active sticky directives from previously fired nodes
///   5. director's directives for THIS reply (spec §6.2)
///   6. narrative payloads from nodes firing this turn
///   7. relevant earlier memories
///   8. the user's input
///
/// Sections 3–7 share an injection budget of `injectionBudgetFraction *
/// maxContextTokens`. Memory surfacing uses [embedder] when provided
/// (ranks event-log entries by cosine similarity to the user input).
/// Falls back to recency if [embedder] is null.
class PromptAssembler {
  PromptAssembler({this.embedder});

  /// Optional. When provided, event-log entries are ranked by
  /// cosine-to-user-input. Without it, recent-first is used.
  final Embedder? embedder;

  /// Per-text vector cache so the same event-log entry is not embedded
  /// every turn. Cleared automatically when the entry's text changes
  /// (the cache key is the text itself).
  final Map<String, Float32List> _vectorCache = {};

  Future<String> assemble({
    required String cardDefinition,
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required String userInput,
    required int maxContextTokens,
    List<String> pendingDirectives = const [],
  }) async {
    final blocks = await _buildSceneAndVariableBlocks(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      pendingDirectives: pendingDirectives,
      userInput: userInput,
      maxContextTokens: maxContextTokens,
    );
    return <String>[
      blocks.scene,
      cardDefinition,
      blocks.variable,
      'User: $userInput',
    ].where((s) => s.isNotEmpty).join('\n\n');
  }

  /// Returns the per-turn dynamic content as one string for the host
  /// to splice into the actor prompt, plus a [PromptBreakdown] of
  /// section sizes for the debug view. Excludes the character
  /// definition and the user input, which the host's own prompt
  /// builder already places.
  Future<DynamicSectionsResult> assembleDynamicSections({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required String userInput,
    required int maxContextTokens,
    List<String> pendingDirectives = const [],
  }) async {
    final blocks = await _buildSceneAndVariableBlocks(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      pendingDirectives: pendingDirectives,
      userInput: userInput,
      maxContextTokens: maxContextTokens,
    );
    final parts = <String>[
      blocks.scene,
      blocks.variable,
    ].where((s) => s.isNotEmpty);
    return (text: parts.join('\n\n'), breakdown: blocks.breakdown);
  }

  Future<
      ({
        String scene,
        String variable,
        PromptBreakdown breakdown,
      })> _buildSceneAndVariableBlocks({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required List<String> pendingDirectives,
    required String userInput,
    required int maxContextTokens,
  }) async {
    final budgetChars =
        (maxContextTokens * injectionBudgetFraction * _charsPerToken).round();
    final scene = _renderSceneAndWorld(state);
    final variableParts = await _renderVariableSections(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      pendingDirectives: pendingDirectives,
      userInput: userInput,
      budgetChars: budgetChars,
    );
    final variable = variableParts.text;
    final totalChars = scene.length +
        (scene.isNotEmpty && variable.isNotEmpty ? 2 : 0) +
        variable.length;
    final breakdown = PromptBreakdown(
      sceneChars: scene.length,
      stateChars: variableParts.stateChars,
      lingeringChars: variableParts.lingeringChars,
      directivesChars: variableParts.directivesChars,
      nowChars: variableParts.nowChars,
      earlierChars: variableParts.earlierChars,
      totalChars: totalChars,
      budgetChars: budgetChars,
    );
    return (scene: scene, variable: variable, breakdown: breakdown);
  }

  String _renderSceneAndWorld(SessionState state) {
    final scene = state.currentScene;
    final parts = <String>[];
    if (scene.location.isNotEmpty) parts.add('Location: ${scene.location}');
    if (scene.timeOfDay.isNotEmpty) parts.add('Time: ${scene.timeOfDay}');
    if (scene.presentEntities.isNotEmpty) {
      parts.add('Present: ${scene.presentEntities.join(", ")}');
    }
    if (scene.sensoryHooks.isNotEmpty) {
      parts.add('Sensory: ${scene.sensoryHooks.join(", ")}');
    }
    if (parts.isEmpty) return '';
    return '## Scene\n${parts.join("\n")}';
  }

  Future<
      ({
        String text,
        int stateChars,
        int lingeringChars,
        int directivesChars,
        int nowChars,
        int earlierChars,
      })> _renderVariableSections({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required List<String> pendingDirectives,
    required String userInput,
    required int budgetChars,
  }) async {
    final parts = <String>[];
    var used = 0;

    int addRendered(String block) {
      if (block.isEmpty) return 0;
      parts.add(block);
      used += block.length;
      return block.length;
    }

    int addBullets(String title, Iterable<String> items) {
      final lines = items.where((p) => p.isNotEmpty).toList();
      if (lines.isEmpty) return 0;
      return addRendered(_renderBulletSection(title, lines));
    }

    // 1. Session state slice (goal, phase, prominent per-character emotions)
    final stateChars = addRendered(_renderStateSlice(state));

    // 2. Sticky directives (lingering payloads from prior firings).
    final lingeringChars = addBullets(
      'Lingering',
      pool.active
          .where((n) => n.currentSticky > 0 || n.currentSticky == -1)
          .map((n) => n.narrativePayload),
    );

    // 3. Director directives for THIS reply (spec §6.2).
    final directivesChars = addBullets('Directives', pendingDirectives);

    // 4. New firings this turn.
    final nowChars =
        addBullets('Now', firedThisTurn.map((n) => n.narrativePayload));

    // 5. Event-log memories, only if budget remains.
    var earlierChars = 0;
    final remaining = budgetChars - used;
    if (remaining > 0 && state.eventLog.isNotEmpty) {
      final memoryLines = await _surfaceMemories(
        log: state.eventLog,
        userInput: userInput,
        budgetChars: remaining,
      );
      earlierChars = addBullets('Earlier', memoryLines);
    }

    return (
      text: parts.join('\n\n'),
      stateChars: stateChars,
      lingeringChars: lingeringChars,
      directivesChars: directivesChars,
      nowChars: nowChars,
      earlierChars: earlierChars,
    );
  }

  String _renderBulletSection(String title, Iterable<String> items) =>
      '## $title\n${items.map((s) => '- $s').join('\n')}';

  String _renderStateSlice(SessionState state) {
    final lines = <String>[];
    if (state.currentGoal.isNotEmpty) lines.add('Goal: ${state.currentGoal}');
    lines.add('Phase: ${state.currentPhase.name}');
    state.characters.forEach((id, character) {
      final strong = character.emotion.entries
          .where((e) => e.value.value >= _prominentEmotionThreshold)
          .map((e) => '${e.key.name} ${e.value.value.toStringAsFixed(2)}')
          .toList();
      if (strong.isNotEmpty) {
        lines.add('$id: ${strong.join(", ")}');
      }
    });
    return '## State\n${lines.join("\n")}';
  }

  Future<List<String>> _surfaceMemories({
    required List<EventLogEntry> log,
    required String userInput,
    required int budgetChars,
  }) async {
    final picked = embedder == null
        ? _byRecency(log, budgetChars)
        : await _byCosine(log, userInput, budgetChars);
    // Render in narrative order (oldest first) regardless of pick order.
    picked.sort((a, b) => a.turn.compareTo(b.turn));
    return picked.map((e) => e.text).toList();
  }

  List<EventLogEntry> _byRecency(List<EventLogEntry> log, int budgetChars) =>
      _fitToBudget(log.reversed, budgetChars, _entryCost);

  Future<List<EventLogEntry>> _byCosine(
    List<EventLogEntry> log,
    String userInput,
    int budgetChars,
  ) async {
    final emb = embedder!;
    final query = await emb.embedOne(userInput, task: EmbedTaskEnum.query);
    final scored = <_ScoredEntry>[];
    for (final entry in log) {
      final vec = _vectorCache[entry.text] ??=
          await emb.embedOne(entry.text, task: EmbedTaskEnum.passage);
      scored.add((entry: entry, score: cosineNormalized(query, vec)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return _fitToBudget(scored, budgetChars, (s) => _entryCost(s.entry))
        .map((s) => s.entry)
        .toList();
  }
}

/// Walks [items] in order, accepting each whose [costFn] fits the
/// remaining char budget. Stops at the first item that does not fit.
List<T> _fitToBudget<T>(
  Iterable<T> items,
  int budgetChars,
  int Function(T) costFn,
) {
  final out = <T>[];
  var used = 0;
  for (final item in items) {
    final cost = costFn(item);
    if (used + cost > budgetChars) break;
    out.add(item);
    used += cost;
  }
  return out;
}

// Each surfaced line is rendered as "- <text>\n"; cost = text + 2.
int _entryCost(EventLogEntry e) => e.text.length + 2;

typedef _ScoredEntry = ({EventLogEntry entry, double score});
