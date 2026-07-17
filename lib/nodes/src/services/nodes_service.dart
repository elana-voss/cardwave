import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/nodes/src/models/chat_nodes_state.dart';
import 'package:cardwave/nodes/src/nodes_card_extension_key.dart';
import 'package:cardwave/nodes/src/repositories/nodes_repository.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
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
    required this.settingsService,
    required this.pureHelpers,
  }) : _assembler = PromptAssembler(embedder: embedder);

  final NodesRepository repository;
  final Embedder embedder;
  final LoggingService loggingService;
  final SettingsService settingsService;
  final LlmPureHelpers pureHelpers;
  final FiringEngine _firingEngine = FiringEngine();
  final PromptAssembler _assembler;

  /// Cards the "N behavior nodes disabled" snackbar was already shown
  /// for this app session — shown once per card, not on every reopen.
  final Set<String> _invalidNodesWarnedCardIds = {};

  String? _currentSessionId;
  SessionState? _state;
  NodePool? _pool;
  StateChangeLog _changeLog = StateChangeLog();
  DirectorOutput? _lastDirectorOutput;
  PromptBreakdown _lastPromptBreakdown = PromptBreakdown.empty;

  /// The currently-loaded session state, or null when no chat is open.
  SessionState? get state => _currentSessionId == null ? null : _state;

  /// The currently-loaded pool, or null when no chat is open.
  NodePool? get pool => _currentSessionId == null ? null : _pool;

  /// Per-mutation log for the debug panel. Reset on chat swap. Spec
  /// §10 calls for "a log of every state change"; this is it.
  StateChangeLog get changeLog => _changeLog;

  /// The director's JSON output from the previous turn, or null if no
  /// director call has run yet on the current chat. Spec §10.
  DirectorOutput? get lastDirectorOutput => _lastDirectorOutput;

  /// Section-by-section character counts from the previous
  /// `assembleDynamicSections` call. Spec §10's "actor prompt
  /// assembly breakdown" surface.
  PromptBreakdown get lastPromptBreakdown => _lastPromptBreakdown;

  /// Pre-reply work: lazy-opens the chat, bumps the turn counter,
  /// ticks the pool, runs one firing pass, and assembles the dynamic
  /// NODES sections (scene + state slice + sticky directives +
  /// director directives + this-turn payloads + surfaced memories)
  /// for injection into the actor prompt. Returns the assembled
  /// section together with the fired list (relayed to the director on
  /// the same turn once that call is wired).
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
      final pending = List<String>.of(_state!.pendingDirectives);
      final result = await _assembler.assembleDynamicSections(
        state: _state!,
        pool: _pool!,
        firedThisTurn: fired,
        userInput: userInput,
        maxContextTokens: maxContextTokens,
        pendingDirectives: pending,
      );
      _state!.pendingDirectives.clear();
      _lastPromptBreakdown = result.breakdown;
      return NodesActorContext(
        promptSection: result.text,
        firedThisTurn: fired,
      );
    } catch (error, stackTrace) {
      // Plain catch: a NODES problem must never block the reply, and
      // TypeErrors in state/JSON handling are Errors, not Exceptions.
      loggingService.warning(
        'NODES turn assembly failed; replying without NODES context.',
        error,
        stackTrace,
      );
      return NodesActorContext.empty;
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
    _applyAndStashDirective(output);
    await _persistCurrent(file, session.id);
  }

  /// Post-reply fire-and-forget: calls the director with the just-
  /// completed turn (user input + actor reply + current state),
  /// applies the returned `DirectorOutput` to state + pool, then
  /// persists. When no system-domain LLM preset is configured the
  /// director call is skipped and only persistence runs — the engine
  /// still ticks, just without state writeback that turn. Internal
  /// try/catch logs failures and retries on the next turn rather
  /// than surfacing.
  Future<void> recordTurn(ChatSession session, CharacterFile file) async {
    try {
      await _ensureOpen(session, file);
      final runner = _resolveSystemRunner();
      if (runner != null) {
        final director = DirectorRunner(runner: runner);
        final output = await director.run(
          state: _state!,
          actorLastOutput: latestAssistantText(session.messages),
          userInput: latestUserText(session.messages),
        );
        _applyAndStashDirective(output);
      }
      await _persistCurrent(file, session.id);
    } catch (error, stackTrace) {
      // Plain catch: same never-block-the-reply contract as
      // [assembleNodesPrompt] — Errors must degrade too.
      loggingService.warning(
        'NODES per-turn director/persist failed; retrying next turn.',
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
    _resetTransientDebugState();
    _currentSessionId = null;
    _state = null;
    _pool = null;
  }

  /// Loads persisted state and rebuilds the pool. The card's authored
  /// nodes are registered on EVERY open — resumed sessions need them to
  /// resolve spawn ids when a node fires. Only a fresh chat (turn 0 with
  /// no persisted nodes) additionally seeds the pool + emotion baseline +
  /// initial goal/scene. No-op when [session] is already the open chat.
  Future<void> _ensureOpen(ChatSession session, CharacterFile file) async {
    if (_currentSessionId == session.id) return;
    _resetTransientDebugState();
    final loaded = await repository.loadState(file, session.id);
    _state = loaded.state;
    _pool = NodePool();
    final extension = _parseCardExtension(file);
    if (extension != null) {
      for (final node in extension.authoredNodes) {
        _pool!.registerAuthored(node);
      }
    }
    for (final node in loaded.activeNodes) {
      _pool!.add(node);
    }
    _currentSessionId = session.id;
    if (extension != null &&
        _state!.turn == 0 &&
        loaded.activeNodes.isEmpty) {
      _seedFromCardExtension(extension, file);
    }
  }

  CardNodesExtension? _parseCardExtension(CharacterFile file) {
    final extJson = file.card.extensions[nodesCardExtensionKey];
    if (extJson is! Map<String, dynamic>) return null;
    final result = loadCardNodesExtension(extJson);
    // A node whose predicate can't parse would throw on every firing
    // pass; drop just the broken nodes so the valid ones keep working
    // instead of one typo disabling the card's whole NODES behavior.
    final broken = result.extension.authoredNodes
        .where((node) => findPredicateProblems(node.predicate).isNotEmpty)
        .toList();
    if (broken.isNotEmpty) {
      result.extension.authoredNodes.removeWhere(broken.contains);
      if (_invalidNodesWarnedCardIds.add(file.appCardId)) {
        NavigationService().showSnackBar(
          t.nodes.service.invalidNodesDroppedSnackbar(count: broken.length),
        );
      }
    }
    if (result.errors.isNotEmpty) {
      loggingService.warning(
        'NODES extension on ${file.card.name} has '
        '${result.errors.length} issue(s); dropped ${broken.length} '
        'node(s) with invalid predicates and kept the rest.',
      );
    }
    return result.extension;
  }

  void _seedFromCardExtension(
    CardNodesExtension extension,
    CharacterFile file,
  ) {
    final character = _state!.characters.putIfAbsent(
      file.appCardId,
      CharacterState.new,
    );
    extension.emotionBaseline.forEach((emotion, value) {
      character.emotion[emotion]!.value = value;
    });
    if (extension.initialGoal.isNotEmpty) {
      _state!.currentGoal = extension.initialGoal;
    }
    final initialScene = extension.initialScene;
    if (initialScene != null) _state!.currentScene = initialScene;
    final nodes = extension.authoredNodes;
    // Only nodes with no incoming spawn link are seeded into the pool at
    // start — a spawned node waits for its parent to fire (mirrors the
    // old top-level-vs-child distinction).
    final spawnedIds = {for (final node in nodes) ...node.spawnIds};
    for (final node in nodes) {
      if (!spawnedIds.contains(node.id)) _pool!.add(node);
    }
  }

  List<Node> _runEngineTurn() {
    _state!.turn += 1;
    _pool!.tick();
    return _firingEngine
        .runTurn(_pool!, _state!, changeLog: _changeLog)
        .fired;
  }

  /// Applies the director's output to state + pool while keeping the
  /// directive lines for the next prompt assembly and remembering the
  /// last output for the debug panel.
  void _applyAndStashDirective(DirectorOutput output) {
    applyDirectorOutput(output, _state!, pool: _pool!, changeLog: _changeLog);
    if (output.directiveLines.isNotEmpty) {
      _state!.pendingDirectives
        ..clear()
        ..addAll(output.directiveLines);
    }
    _lastDirectorOutput = output;
  }

  void _resetTransientDebugState() {
    _changeLog = StateChangeLog();
    _lastDirectorOutput = null;
    _lastPromptBreakdown = PromptBreakdown.empty;
  }

  Future<void> _persistCurrent(CharacterFile file, String sessionId) =>
      repository.saveState(
        file,
        sessionId,
        ChatNodesState(state: _state!, activeNodes: _pool!.active.toList()),
      );

  /// Builds the system-domain runner the director uses, or null when
  /// no system preset is set or it can't be resolved (logged) — the
  /// engine then ticks without director writeback for that turn.
  LlmRunner? _resolveSystemRunner() {
    final presetId = settingsService.settings.getAppDomainPresetId(
      LlmProviderDomainEnum.system,
    );
    if (presetId == null) return null;
    try {
      final resolved = pureHelpers.resolvePreset(
        configId: presetId,
        providers: settingsService.settings.providerConfigs,
      );
      return pureHelpers.createRunner(
        provider: resolved.provider,
        model: resolved.model,
        preset: resolved.preset,
      );
    } catch (error, stackTrace) {
      // Plain catch: a stale preset id can hit a cast/null-assert
      // (TypeError) in resolvePreset — degrade the same as any failure.
      loggingService.warning(
        'NODES: system model unresolved; director writeback off this turn.',
        error,
        stackTrace,
      );
      return null;
    }
  }
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

  /// The fallback used when NODES has nothing to contribute — assistant
  /// chats (no character interiority to model) and any error path that
  /// degrades to "reply without NODES context".
  static const NodesActorContext empty = NodesActorContext(
    promptSection: '',
    firedThisTurn: [],
  );

  final String promptSection;
  final List<Node> firedThisTurn;
}
