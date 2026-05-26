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
/// on a fresh chat), runs the per-turn engine pass + dynamic-section
/// assembly for the actor prompt, applies director output back onto
/// state, and persists after each turn. One chat's state is held at a
/// time; opening a different chat drops the previous one.
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

  /// Key under which authored nodes + emotion baseline + initial
  /// goal/scene live in a SillyTavern v3 card's `extensions` map.
  static const String _cardExtensionKey = 'cardwave_nodes';

  String? _currentSessionId;
  SessionState? _state;
  NodePool? _pool;

  /// The currently-loaded session state, or null when no chat is open.
  SessionState? get state => _currentSessionId == null ? null : _state;

  /// The currently-loaded pool, or null when no chat is open.
  NodePool? get pool => _currentSessionId == null ? null : _pool;

  /// Pre-reply work: lazy-opens the chat, bumps the turn counter,
  /// ticks the pool, runs one firing pass, and assembles the dynamic
  /// NODES sections (scene + state slice + sticky directives + this-
  /// turn payloads + surfaced memories) for injection into the actor
  /// prompt. Returns the assembled section together with the fired
  /// list (relayed to the director on the same turn once that call is
  /// wired).
  ///
  /// Any failure (disk, embedder, engine) is caught and returned as
  /// an empty context, with a warning logged — a NODES problem must
  /// never block the reply. The chat replies without NODES injection
  /// for that turn.
  Future<NodesActorContext> assembleNodesPrompt({
    required ChatSession session,
    required CharacterFile file,
    required String userInput,
    required int maxContextTokens,
  }) async {
    try {
      await _ensureOpen(session, file);
      final fired = _runEngineTurn();
      final promptSection = await _assembler.assembleDynamicSections(
        state: _state!,
        pool: _pool!,
        firedThisTurn: fired,
        userInput: userInput,
        maxContextTokens: maxContextTokens,
      );
      return NodesActorContext(
        promptSection: promptSection,
        firedThisTurn: fired,
      );
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'NODES turn assembly failed; replying without NODES context.',
        error,
        stackTrace,
      );
      return const NodesActorContext(promptSection: '', firedThisTurn: []);
    }
  }

  /// Applies [output] to the open chat's state + pool, then persists.
  /// Lazy-opens the chat if not already open.
  Future<void> recordDirectorOutput({
    required ChatSession session,
    required CharacterFile file,
    required DirectorOutput output,
  }) async {
    await _ensureOpen(session, file);
    applyDirectorOutput(output, _state!, pool: _pool!);
    await _persistCurrent(file, session.id);
  }

  /// Post-reply fire-and-forget: persists the in-memory state so the
  /// just-advanced turn survives a restart. Internal try/catch logs
  /// IO failures and retries on the next turn rather than surfacing
  /// the error.
  Future<void> recordTurn(ChatSession session, CharacterFile file) async {
    try {
      await _ensureOpen(session, file);
      await _persistCurrent(file, session.id);
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'NODES per-turn persist failed; retrying next turn.',
        error,
        stackTrace,
      );
    }
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
    final extJson = file.card.extensions[_cardExtensionKey];
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
}

/// What [NodesService.assembleNodesPrompt] returns: the dynamic NODES
/// prompt block to inject into the actor LLM call's system message
/// (empty when there is nothing to inject — failure or quiet turn),
/// and the list of nodes that fired this turn so the caller can
/// relay them to the director on the same turn.
class NodesActorContext {
  const NodesActorContext({
    required this.promptSection,
    required this.firedThisTurn,
  });

  final String promptSection;
  final List<Node> firedThisTurn;
}
