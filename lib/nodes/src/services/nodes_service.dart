import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/models/chat_nodes_state.dart';
import 'package:cardwave/nodes/src/repositories/nodes_repository.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';

/// Owns the NODES engine state for the chat the user is in: opens a
/// chat (loading session state and rebuilding the pool from disk),
/// runs the pre-reply pipeline (tick → fire → assemble actor prompt),
/// applies director output back onto state, and persists after each
/// turn. One chat's state is held at a time; opening a different chat
/// drops the previous one.
///
/// The director LLM call is NOT made here — the chat orchestrator
/// owns that (it already owns the actor call) and hands the
/// [DirectorOutput] to [recordDirectorOutput]. This keeps the service
/// independent of LLM provider plumbing.
class NodesService {
  NodesService({
    required this.repository,
    required this.embedder,
    required this.loggingService,
  }) : _assembler = PromptAssembler(embedder: embedder);

  final NodesRepository repository;
  final Embedder embedder;
  final LoggingService loggingService;
  final FiringEngine _firingEngine = FiringEngine();
  final PromptAssembler _assembler;

  String? _currentSessionId;
  SessionState? _state;
  NodePool? _pool;

  /// Loads the chat's NODES state from disk and rebuilds the in-memory
  /// pool from the persisted active-nodes list. No-op when [session]
  /// is already the current one.
  Future<void> openChat(ChatSession session, CharacterFile file) async {
    if (_currentSessionId == session.id) return;
    final loaded = await repository.loadState(file, session.id);
    _state = loaded.state;
    _pool = NodePool();
    for (final node in loaded.activeNodes) {
      _pool!.add(node);
    }
    _currentSessionId = session.id;
  }

  /// The currently-loaded session state, or null when no chat is open.
  SessionState? get state => _currentSessionId == null ? null : _state;

  /// The currently-loaded pool, or null when no chat is open.
  NodePool? get pool => _currentSessionId == null ? null : _pool;

  /// Seeds authored nodes + emotion baseline + initial goal/scene from
  /// the card's `extensions.cardwave_nodes` block onto the open chat's
  /// state for [characterId]. Appends every call — callers gate on
  /// whether the chat is fresh (typically `state.turn == 0`).
  ///
  /// Cards with no `cardwave_nodes` extension, or a non-object value
  /// there, are a no-op. Validation problems are logged and the valid
  /// authored nodes still seed.
  void seedFromCardExtension(CharacterFile file, String characterId) {
    final currentState = _state;
    final currentPool = _pool;
    if (currentState == null || currentPool == null) return;
    final extJson = file.card.extensions['cardwave_nodes'];
    if (extJson is! Map<String, dynamic>) return;
    final result = loadCardNodesExtension(extJson);
    if (result.errors.isNotEmpty) {
      loggingService.warning(
        'NODES extension on ${file.card.name} has '
        '${result.errors.length} issue(s); seeding the valid pieces.',
      );
    }
    final character = currentState.characters.putIfAbsent(
      characterId,
      CharacterState.new,
    );
    result.extension.emotionBaseline.forEach((emotion, value) {
      character.emotion[emotion]!.value = value;
    });
    if (result.extension.initialGoal.isNotEmpty) {
      currentState.currentGoal = result.extension.initialGoal;
    }
    final initialScene = result.extension.initialScene;
    if (initialScene != null) currentState.currentScene = initialScene;
    for (final node in result.extension.authoredNodes) {
      currentPool.add(node);
    }
  }

  /// Bumps the turn counter, ticks the pool, runs one firing pass,
  /// then assembles the actor prompt against the resulting state.
  /// Returns the prompt + the nodes that fired (the caller relays
  /// the fired list to the director on the same turn). Returns null
  /// when [session] is not the open chat.
  Future<NodesActorContext?> assembleActorContext({
    required ChatSession session,
    required CharacterFile file,
    required String userInput,
    required int maxContextTokens,
  }) async {
    if (_currentSessionId != session.id) return null;
    final currentState = _state!;
    final currentPool = _pool!;
    currentState.turn += 1;
    currentPool.tick();
    final firing = _firingEngine.runTurn(currentPool, currentState);
    final prompt = await _assembler.assemble(
      cardDefinition: _renderCardDefinition(file),
      state: currentState,
      pool: currentPool,
      firedThisTurn: firing.fired,
      userInput: userInput,
      maxContextTokens: maxContextTokens,
    );
    return NodesActorContext(prompt: prompt, firedThisTurn: firing.fired);
  }

  /// Applies [output] to the open chat's state + pool, then persists.
  /// No-op when [session] is not the open chat.
  Future<void> recordDirectorOutput({
    required ChatSession session,
    required CharacterFile file,
    required DirectorOutput output,
  }) async {
    if (_currentSessionId != session.id) return;
    applyDirectorOutput(output, _state!, pool: _pool!);
    await _persistCurrent(file, session.id);
  }

  /// Writes the current in-memory state to disk without applying a
  /// director output. For turns where the director was skipped but
  /// actor-side state changes (`turn`, pool ticks) should survive a
  /// restart. No-op when [session] is not the open chat.
  Future<void> persist(ChatSession session, CharacterFile file) async {
    if (_currentSessionId != session.id) return;
    await _persistCurrent(file, session.id);
  }

  /// Drops the in-memory state when the chat closes. No-op when
  /// [sessionId] is not the open chat (a different chat already
  /// swapped it out).
  void releaseChat(String sessionId) {
    if (_currentSessionId != sessionId) return;
    _currentSessionId = null;
    _state = null;
    _pool = null;
  }

  Future<void> _persistCurrent(CharacterFile file, String sessionId) =>
      repository.saveState(
        file,
        sessionId,
        ChatNodesState(state: _state!, activeNodes: _pool!.active.toList()),
      );

  static String _renderCardDefinition(CharacterFile file) {
    final card = file.card;
    final parts = <String>['## ${card.name}'];
    if (card.description.isNotEmpty) parts.add(card.description);
    return parts.join('\n');
  }
}

/// The return shape of [NodesService.assembleActorContext]: the
/// assembled actor prompt to inject into the LLM call, plus the
/// nodes that fired this turn (relayed to the director on the same
/// turn so it can react to them).
class NodesActorContext {
  const NodesActorContext({required this.prompt, required this.firedThisTurn});

  final String prompt;
  final List<Node> firedThisTurn;
}
