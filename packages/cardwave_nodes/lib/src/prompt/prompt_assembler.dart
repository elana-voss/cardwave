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

/// Builds the actor's per-turn prompt by stacking, in spec §8.1 order:
///   1. world and scene state
///   2. character definition (caller-supplied)
///   3. session state slice (goal, phase, prominent emotions)
///   4. active sticky directives from previously fired nodes
///   5. narrative payloads from nodes firing this turn
///   6. the user's input
///
/// Sections 3–5 share an injection budget of `injectionBudgetFraction *
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
  }) async {
    final blocks = await _buildSceneAndVariableBlocks(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
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

  /// Returns just the per-turn dynamic content — world/scene block,
  /// session state slice, sticky directives, fired payloads, surfaced
  /// memories — joined as one string. Excludes the character
  /// definition and the user input, which the host's own prompt
  /// builder already places. Use this when the actor prompt is
  /// assembled outside the package and NODES only contributes its
  /// dynamic context as one injected section.
  Future<String> assembleDynamicSections({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required String userInput,
    required int maxContextTokens,
  }) async {
    final blocks = await _buildSceneAndVariableBlocks(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      userInput: userInput,
      maxContextTokens: maxContextTokens,
    );
    return <String>[blocks.scene, blocks.variable]
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }

  Future<({String scene, String variable})> _buildSceneAndVariableBlocks({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required String userInput,
    required int maxContextTokens,
  }) async {
    final budgetChars =
        (maxContextTokens * injectionBudgetFraction * _charsPerToken).round();
    final scene = _renderSceneAndWorld(state);
    final variable = await _renderVariableSections(
      state: state,
      pool: pool,
      firedThisTurn: firedThisTurn,
      userInput: userInput,
      budgetChars: budgetChars,
    );
    return (scene: scene, variable: variable);
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

  Future<String> _renderVariableSections({
    required SessionState state,
    required NodePool pool,
    required List<Node> firedThisTurn,
    required String userInput,
    required int budgetChars,
  }) async {
    final parts = <String>[];
    var used = 0;

    // 1. Session state slice (goal, phase, prominent per-character emotions)
    final stateSlice = _renderStateSlice(state);
    if (stateSlice.isNotEmpty) {
      parts.add(stateSlice);
      used += stateSlice.length;
    }

    // 2. Sticky directives (lingering from prior firings).
    final stickyLines = pool.active
        .where((n) => n.currentSticky > 0 || n.currentSticky == -1)
        .map((n) => n.narrativePayload)
        .where((p) => p.isNotEmpty)
        .toList();
    if (stickyLines.isNotEmpty) {
      final block = _renderBulletSection('Lingering', stickyLines);
      parts.add(block);
      used += block.length;
    }

    // 3. New firings this turn.
    final newLines = firedThisTurn
        .map((n) => n.narrativePayload)
        .where((p) => p.isNotEmpty)
        .toList();
    if (newLines.isNotEmpty) {
      final block = _renderBulletSection('Now', newLines);
      parts.add(block);
      used += block.length;
    }

    // 4. Event-log memories, only if budget remains.
    final remaining = budgetChars - used;
    if (remaining > 0 && state.eventLog.isNotEmpty) {
      final memoryLines = await _surfaceMemories(
        log: state.eventLog,
        userInput: userInput,
        budgetChars: remaining,
      );
      if (memoryLines.isNotEmpty) {
        parts.add(_renderBulletSection('Earlier', memoryLines));
      }
    }

    return parts.join('\n\n');
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
