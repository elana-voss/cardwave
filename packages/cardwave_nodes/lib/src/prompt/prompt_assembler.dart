import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_nodes/src/models/event_log_entry.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/nodes/node_pool.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// Emotion value above which the state slice surfaces the field in the
/// actor's prompt. Below it, the emotion is too quiet to mention.
const double _prominentEmotionThreshold = 0.5;

/// Per-section token estimates for the assembled dynamic block, plus
/// the running total and the budget the assembler was given. The debug
/// view shows this so a developer can see which section ate the budget
/// and which got dropped under pressure. Counts come from
/// [UtilsLlm.countTokens], which weighs scripts differently (CJK text
/// costs ~4x more tokens per character than English).
class PromptBreakdown {
  const PromptBreakdown({
    required this.sceneTokens,
    required this.stateTokens,
    required this.lingeringTokens,
    required this.directivesTokens,
    required this.nowTokens,
    required this.earlierTokens,
    required this.totalTokens,
    required this.budgetTokens,
  });

  static const PromptBreakdown empty = PromptBreakdown(
    sceneTokens: 0,
    stateTokens: 0,
    lingeringTokens: 0,
    directivesTokens: 0,
    nowTokens: 0,
    earlierTokens: 0,
    totalTokens: 0,
    budgetTokens: 0,
  );

  final int sceneTokens;
  final int stateTokens;
  final int lingeringTokens;
  final int directivesTokens;
  final int nowTokens;
  final int earlierTokens;
  final int totalTokens;
  final int budgetTokens;
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
/// Only section 7 (earlier memories) is capped by the injection budget
/// (`injectionBudgetFraction * maxContextTokens`): sections 3–6 are
/// always appended in full — dropping state or directives would change
/// behavior — and merely reduce what memories may use of the budget.
/// Memory surfacing uses [embedder] when provided (ranks event-log
/// entries by cosine similarity to the user input). Falls back to
/// recency if [embedder] is null.
class PromptAssembler {
  PromptAssembler({this.embedder});

  /// Optional. When provided, event-log entries are ranked by
  /// cosine-to-user-input. Without it, recent-first is used.
  final Embedder? embedder;

  /// Per-text vector cache so the same event-log entry is not embedded
  /// every turn. Keyed by the entry's text; after each ranking pass,
  /// keys no longer present in the log (reworded or trimmed entries)
  /// are evicted so the cache can't grow for the whole session.
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
    final budgetTokens = (maxContextTokens * injectionBudgetFraction).round();
    final scene = _renderSceneAndWorld(state);
    final variableParts = await _renderVariableSections(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      pendingDirectives: pendingDirectives,
      userInput: userInput,
      budgetTokens: budgetTokens,
    );
    final variable = variableParts.text;
    final sceneTokens = await UtilsLlm.countTokens(scene);
    final totalTokens = sceneTokens +
        variableParts.stateTokens +
        variableParts.lingeringTokens +
        variableParts.directivesTokens +
        variableParts.nowTokens +
        variableParts.earlierTokens;
    final breakdown = PromptBreakdown(
      sceneTokens: sceneTokens,
      stateTokens: variableParts.stateTokens,
      lingeringTokens: variableParts.lingeringTokens,
      directivesTokens: variableParts.directivesTokens,
      nowTokens: variableParts.nowTokens,
      earlierTokens: variableParts.earlierTokens,
      totalTokens: totalTokens,
      budgetTokens: budgetTokens,
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
        int stateTokens,
        int lingeringTokens,
        int directivesTokens,
        int nowTokens,
        int earlierTokens,
      })> _renderVariableSections({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required List<String> pendingDirectives,
    required String userInput,
    required int budgetTokens,
  }) async {
    final parts = <String>[];
    var used = 0;

    Future<int> addRendered(String block) async {
      if (block.isEmpty) return 0;
      parts.add(block);
      final tokens = await UtilsLlm.countTokens(block);
      used += tokens;
      return tokens;
    }

    Future<int> addBullets(String title, Iterable<String> items) {
      final lines = items.where((p) => p.isNotEmpty).toList();
      if (lines.isEmpty) return Future.value(0);
      return addRendered(_renderBulletSection(title, lines));
    }

    // 1. Session state slice (goal, phase, prominent per-character emotions)
    final stateTokens = await addRendered(_renderStateSlice(state));

    // 2. Sticky directives (lingering payloads from prior firings).
    final lingeringTokens = await addBullets(
      'Lingering',
      pool.active
          .where((n) => n.currentSticky > 0 || n.currentSticky == -1)
          .map((n) => n.narrativePayload),
    );

    // 3. Director directives for THIS reply (spec §6.2).
    final directivesTokens = await addBullets('Directives', pendingDirectives);

    // 4. New firings this turn.
    final nowTokens =
        await addBullets('Now', firedThisTurn.map((n) => n.narrativePayload));

    // 5. Event-log memories, only if budget remains.
    var earlierTokens = 0;
    final remaining = budgetTokens - used;
    if (remaining > 0 && state.eventLog.isNotEmpty) {
      final memoryLines = await _surfaceMemories(
        log: state.eventLog,
        userInput: userInput,
        budgetTokens: remaining,
      );
      earlierTokens = await addBullets('Earlier', memoryLines);
    }

    return (
      text: parts.join('\n\n'),
      stateTokens: stateTokens,
      lingeringTokens: lingeringTokens,
      directivesTokens: directivesTokens,
      nowTokens: nowTokens,
      earlierTokens: earlierTokens,
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
    required int budgetTokens,
  }) async {
    final picked = embedder == null
        ? await _byRecency(log, budgetTokens)
        : await _byCosine(log, userInput, budgetTokens);
    // Render in narrative order (oldest first) regardless of pick order.
    picked.sort((a, b) => a.turn.compareTo(b.turn));
    return picked.map((e) => e.text).toList();
  }

  Future<List<EventLogEntry>> _byRecency(
    List<EventLogEntry> log,
    int budgetTokens,
  ) =>
      _fitToBudget(log.reversed, budgetTokens, _entryCost);

  Future<List<EventLogEntry>> _byCosine(
    List<EventLogEntry> log,
    String userInput,
    int budgetTokens,
  ) async {
    final emb = embedder!;
    final query = await emb.embedOne(userInput, task: EmbedTaskEnum.query);
    final scored = <_ScoredEntry>[];
    for (final entry in log) {
      final vec = _vectorCache[entry.text] ??=
          await emb.embedOne(entry.text, task: EmbedTaskEnum.passage);
      scored.add((entry: entry, score: cosineNormalized(query, vec)));
    }
    final currentTexts = {for (final entry in log) entry.text};
    _vectorCache.removeWhere((text, _) => !currentTexts.contains(text));
    scored.sort((a, b) => b.score.compareTo(a.score));
    final picked =
        await _fitToBudget(scored, budgetTokens, (s) => _entryCost(s.entry));
    return picked.map((s) => s.entry).toList();
  }
}

/// Walks [items] in order, accepting each whose [costFn] fits the
/// remaining token budget. Stops at the first item that does not fit.
Future<List<T>> _fitToBudget<T>(
  Iterable<T> items,
  int budgetTokens,
  Future<int> Function(T) costFn,
) async {
  final out = <T>[];
  var used = 0;
  for (final item in items) {
    final cost = await costFn(item);
    if (used + cost > budgetTokens) break;
    out.add(item);
    used += cost;
  }
  return out;
}

// Each surfaced line is rendered as "- <text>\n"; +1 covers the bullet.
Future<int> _entryCost(EventLogEntry e) async =>
    await UtilsLlm.countTokens(e.text) + 1;

typedef _ScoredEntry = ({EventLogEntry entry, double score});
