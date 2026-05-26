import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/models/chat_nodes_state.dart';
import 'package:cardwave/nodes/src/repositories/nodes_repository.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';

/// Owns the NODES engine state for the chat the user is in: opens a
/// chat lazily on first use (loading session state and rebuilding the
/// pool from disk, seeding authored nodes from the card's extension
/// on a fresh chat), runs per-turn engine progression and prompt
/// assembly, applies director output back onto state, and persists
/// after each turn. One chat's state is held at a time; opening a
/// different chat drops the previous one.
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

  /// The currently-loaded session state, or null when no chat is open.
  SessionState? get state => _currentSessionId == null ? null : _state;

  /// The currently-loaded pool, or null when no chat is open.
  NodePool? get pool => _currentSessionId == null ? null : _pool;

  /// Bumps the turn counter, ticks the pool, runs one firing pass.
  /// Lazy-opens the chat on first call (loads persisted state + seeds
  /// authored nodes on a fresh chat). Returns the nodes that fired
  /// this turn so the caller can relay them to the director.
  Future<List<Node>> advanceTurn(
    ChatSession session,
    CharacterFile file,
  ) async {
    await _ensureOpen(session, file);
    return _runEngineTurn();
  }

  /// Same engine pass as [advanceTurn] plus assembling the actor
  /// prompt against the resulting state. Use when the caller intends
  /// to inject the prompt into the actor LLM call.
  Future<NodesActorContext> assembleActorContext({
    required ChatSession session,
    required CharacterFile file,
    required String userInput,
    required int maxContextTokens,
  }) async {
    await _ensureOpen(session, file);
    final fired = _runEngineTurn();
    final prompt = await _assembler.assemble(
      cardDefinition: _renderCardDefinition(file),
      state: _state!,
      pool: _pool!,
      firedThisTurn: fired,
      userInput: userInput,
      maxContextTokens: maxContextTokens,
    );
    return NodesActorContext(prompt: prompt, firedThisTurn: fired);
  }

  /// Applies [output] to the open chat's state + pool, then persists.
  /// Lazy-opens the chat if not already open (so callers that skip the
  /// actor pass can still record director output).
  Future<void> recordDirectorOutput({
    required ChatSession session,
    required CharacterFile file,
    required DirectorOutput output,
  }) async {
    await _ensureOpen(session, file);
    applyDirectorOutput(output, _state!, pool: _pool!);
    await _persistCurrent(file, session.id);
  }

  /// Writes the current in-memory state to disk. For callers that
  /// advanced the engine (via [advanceTurn] or [assembleActorContext])
  /// but skipped the director call, persistence still has to land so
  /// the new turn counter and pool tick survive a restart.
  Future<void> persist(ChatSession session, CharacterFile file) async {
    await _ensureOpen(session, file);
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

  /// Loads persisted state and rebuilds the pool. On a fresh chat
  /// (turn 0 with no persisted nodes) seeds authored nodes + emotion
  /// baseline + initial goal/scene from the card's
  /// `extensions.cardwave_nodes` block. No-op when [session] is
  /// already the open chat.
  Future<void> _ensureOpen(ChatSession session, CharacterFile file) async {
    if (_currentSessionId == session.id) return;
    final loaded = await repository.loadState(file, session.id);
    _state = loaded.state;
    _pool = NodePool();
    for (final node in loaded.activeNodes) {
      _pool!.add(node);
    }
    _currentSessionId = session.id;
    if (_state!.turn == 0 && loaded.activeNodes.isEmpty) {
      _seedFromCardExtension(file);
    }
  }

  void _seedFromCardExtension(CharacterFile file) {
    final extJson = file.card.extensions['cardwave_nodes'];
    if (extJson is! Map<String, dynamic>) return;
    final result = loadCardNodesExtension(extJson);
    if (result.errors.isNotEmpty) {
      loggingService.warning(
        'NODES extension on ${file.card.name} has '
        '${result.errors.length} issue(s); seeding the valid pieces.',
      );
    }
    final character = _state!.characters.putIfAbsent(
      file.appCardId,
      CharacterState.new,
    );
    result.extension.emotionBaseline.forEach((emotion, value) {
      character.emotion[emotion]!.value = value;
    });
    if (result.extension.initialGoal.isNotEmpty) {
      _state!.currentGoal = result.extension.initialGoal;
    }
    final initialScene = result.extension.initialScene;
    if (initialScene != null) _state!.currentScene = initialScene;
    for (final node in result.extension.authoredNodes) {
      _pool!.add(node);
    }
  }

  List<Node> _runEngineTurn() {
    _state!.turn += 1;
    _pool!.tick();
    return _firingEngine.runTurn(_pool!, _state!).fired;
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
