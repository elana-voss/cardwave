import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/memory/src/repositories/memory_repository.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/cardwave_memory.dart';

/// Owns story memory for the chat the user is in: it loads that chat's graph
/// when the chat opens, retrieves relevant past events to feed the prompt
/// before each reply, and — after the reply lands — reconciles edits and
/// extracts new events in the background. One chat's graph is held at a time;
/// opening a different chat drops the previous one.
///
/// Retrieval needs only the on-device embedder, so it works even when no
/// system model is configured. Extraction needs the system-domain model; when
/// none is set it is skipped (retrieval still runs).
class MemoryService {
  MemoryService({
    required this.repository,
    required this.embedder,
    required this.settingsService,
    required this.loggingService,
    required this.pureHelpers,
  });

  final MemoryRepository repository;
  final Embedder embedder;
  final SettingsService settingsService;
  final LoggingService loggingService;
  final LlmPureHelpers pureHelpers;

  /// How many messages accumulate between extraction passes. Extraction is an
  /// LLM call, so it runs on this cadence rather than every turn; reconcile,
  /// which is cheap and keeps memory honest after edits, runs every turn.
  static const int _extractionCadenceMessages = 4;

  String? _currentSessionId;
  // Mapped-message count at the last extraction pass; the cadence gate fires
  // once this many new messages have accumulated past it. Reset per chat.
  int _lastExtractedCount = 0;
  MemoryEngine? _engine;
  MemoryRetriever? _retriever;

  /// Retrieves the memory most relevant to the user's latest message as a list
  /// of preformatted "- …" lines — recalled events plus current entity facts —
  /// for the `<memory>` prompt section. Returns empty (and the section is
  /// omitted) when memory is unavailable for any reason — a missing embedder, an
  /// empty graph, or a failure — so a memory problem never blocks the reply. The
  /// caller joins the lines for the prompt and also stores them on the reply.
  Future<List<String>> retrieveContext(
    ChatSession session,
    CharacterFile file,
  ) async {
    if (!embedder.isReady) return const [];
    try {
      await _ensureLoaded(session, file);
      final retriever = _retriever;
      if (retriever == null) return const [];
      final query = latestUserText(session.messages);
      if (query.isEmpty) return const [];
      final events = await retriever.retrieve(query);
      // Facts carry current state ("what's true now"); threads carry what's
      // still pending; events carry "what happened". All keyed off the query or
      // the active character's name.
      final facts = retriever.retrieveFacts(
        query,
        activeSubjects: [file.card.name],
      );
      final threads = retriever.retrieveThreads(
        query,
        activeSubjects: [file.card.name],
      );
      if (events.isNotEmpty || facts.isNotEmpty || threads.isNotEmpty) {
        loggingService.info(
          'Memory: recalled ${events.length} events, ${facts.length} facts, '
          '${threads.length} threads.',
        );
      }
      // Order each section oldest-to-newest by its earliest source message, so
      // the block reads as one timeline rather than in relevance order.
      final order = _messageOrder(session.messages);
      final orderedEvents = _byEarliestMessage(events, (e) => e.messageIds, order);
      final orderedFacts = _byEarliestMessage(facts, (f) => f.messageIds, order);
      final orderedThreads =
          _byEarliestMessage(threads, (t) => t.messageIds, order);
      final lines = <String>[
        for (final event in orderedEvents) _formatEvent(event),
        for (final fact in orderedFacts) '- (current) ${fact.text}',
        for (final thread in orderedThreads) '- (open thread) ${thread.text}',
      ];
      return lines;
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'Memory retrieval failed; replying without memory context.',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  /// Reconciles edits/deletions since the last pass and, on cadence, extracts
  /// new events. Fire-and-forget after a turn; failures are logged and retried
  /// next turn rather than surfaced. Reconcile runs every call so deleted or
  /// edited messages drop out of memory promptly; only the LLM extraction is
  /// throttled by [_extractionCadenceMessages].
  Future<void> recordTurn(ChatSession session, CharacterFile file) async {
    try {
      await _ensureLoaded(session, file);
      final engine = _engine;
      final retriever = _retriever;
      // No system model configured ⇒ no runner ⇒ extraction is impossible.
      // Retrieval over whatever already exists is unaffected.
      if (engine == null || retriever == null) return;

      final messages = _mapMessages(session.messages);
      // Work through the captured [engine], not the live fields: if the chat
      // closes mid-extraction, releaseChat clears them, and saving an empty
      // graph would erase this chat's memory on disk. The captured engine
      // still holds the real graph.
      final graph = engine.graph;

      // Reconcile every turn so edits and deletions drop out of memory
      // promptly; rewind the cadence mark to the change so the affected tail
      // re-extracts once enough messages build back up.
      final eventsBeforeReconcile = graph.events.length;
      final factsBeforeReconcile = graph.facts.length;
      final reconcile = engine.reconcile(messages);
      if (reconcile.recomputeFromIndex != -1) {
        _lastExtractedCount = reconcile.recomputeFromIndex;
        final droppedEvents = eventsBeforeReconcile - graph.events.length;
        final droppedFacts = factsBeforeReconcile - graph.facts.length;
        if (droppedEvents > 0 || droppedFacts > 0) {
          loggingService.info(
            'Memory: an edit dropped $droppedEvents events, $droppedFacts facts.',
          );
        }
      }

      // Extraction is an LLM call — run it only once enough new messages have
      // accumulated since the last pass, not every turn.
      final eventCountBefore = graph.events.length;
      final factCountBefore = graph.facts.length;
      final threadCountBefore = graph.threads.length;
      final resolvedThreadsBefore = _resolvedThreadCount(graph);
      if (messages.length - _lastExtractedCount >= _extractionCadenceMessages) {
        await engine.processMessages(messages);
        _lastExtractedCount = messages.length;
        final newEvents = graph.events.length - eventCountBefore;
        final newFacts = graph.facts.length - factCountBefore;
        final newThreads = graph.threads.length - threadCountBefore;
        if (newEvents > 0 || newFacts > 0 || newThreads > 0) {
          loggingService.info(
            'Memory: extracted $newEvents events, $newFacts facts, '
            '$newThreads threads.',
          );
        }
      }

      // A resolved thread changes no count, so check the resolved tally too,
      // or a resolve-only pass would never be saved.
      final extracted =
          graph.events.length != eventCountBefore ||
          graph.facts.length != factCountBefore ||
          graph.threads.length != threadCountBefore ||
          _resolvedThreadCount(graph) != resolvedThreadsBefore;
      final changed = reconcile.recomputeFromIndex != -1 || extracted;
      if (!changed) return;

      await retriever.rebuildIndex();
      await repository.saveGraph(file, session.id, graph);
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'Memory extraction failed; retrying next turn.',
        error,
        stackTrace,
      );
    }
  }

  /// Drops the in-memory graph when its chat closes. A no-op for any other
  /// chat — opening a different chat already swaps the graph out.
  void releaseChat(String sessionId) {
    if (_currentSessionId != sessionId) return;
    _currentSessionId = null;
    _lastExtractedCount = 0;
    _engine = null;
    _retriever = null;
  }

  /// Loads the graph for [session] (when not already current) and builds the
  /// retriever and — when a system model is configured — the extraction engine
  /// over the same graph, so events committed by extraction are retrievable.
  Future<void> _ensureLoaded(ChatSession session, CharacterFile file) async {
    if (_currentSessionId == session.id) return;
    final loaded = await repository.loadGraph(file, session.id);

    final runner = _resolveSystemRunner();
    final MemoryGraph graph;
    if (runner != null) {
      final engine = MemoryEngine(
        extractor: MemoryExtractor(
          runner: runner,
          embedder: embedder,
          classifier: EmotionClassifier(embedder),
        ),
      );
      engine.loadGraph(loaded, _mapMessages(session.messages));
      _engine = engine;
      graph = engine.graph;
    } else {
      _engine = null;
      graph = loaded;
    }

    final retriever = MemoryRetriever(embedder: embedder, graph: graph);
    await retriever.rebuildIndex();
    _retriever = retriever;
    _lastExtractedCount = 0;
    _currentSessionId = session.id;
  }

  /// Builds the system-domain runner extraction uses, or null when no system
  /// preset is set or it can't be resolved (logged) — extraction then stays off
  /// while retrieval keeps working.
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
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'Memory: system model unresolved; extraction off this session.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Maps chat turns to memory messages. The user stays the user; the
  /// assistant or named character becomes the character; system messages carry
  /// no story content and are left out (see [MemoryRole]).
  List<MemoryMessage> _mapMessages(List<ChatMessage> messages) => [
    for (final message in messages)
      if (_memoryRole(message.role) case final role?)
        MemoryMessage(
          id: message.id,
          role: role,
          text: message.content,
          timestamp: message.timestamp,
          characterId: message.characterId,
        ),
  ];

  static MemoryRole? _memoryRole(ChatRoleEnum role) => switch (role) {
    ChatRoleEnum.user => MemoryRole.user,
    ChatRoleEnum.assistant || ChatRoleEnum.character => MemoryRole.character,
    ChatRoleEnum.system => null,
  };

  static int _resolvedThreadCount(MemoryGraph graph) =>
      graph.threads.where((thread) => thread.resolvedAt != null).length;

  // Returns the whole "- …" block, leading dash included, so the caller joins
  // these as-is — an event can span three lines and must not be re-prefixed.
  static String _formatEvent(StoryEvent event) {
    final text = event.contextualPrefix.isEmpty
        ? event.text
        : '${event.contextualPrefix} ${event.text}';
    final buffer = StringBuffer('- [${event.eventType.wireName}] $text');
    if (event.cause.isNotEmpty) buffer.write('\n  Cause: ${event.cause}');
    if (event.effect.isNotEmpty) buffer.write('\n  Effect: ${event.effect}');
    return buffer.toString();
  }

  // Message id to chat position, so recalled memory can be ordered as a
  // timeline rather than by relevance.
  static Map<String, int> _messageOrder(List<ChatMessage> messages) => {
    for (var i = 0; i < messages.length; i++) messages[i].id: i,
  };

  // Orders recalled items oldest-to-newest by their earliest source message.
  // Each item's position is computed once up front, not on every comparison.
  static List<T> _byEarliestMessage<T>(
    List<T> items,
    List<String> Function(T) messageIds,
    Map<String, int> order,
  ) {
    final keyed = [
      for (final item in items)
        (position: _earliestPosition(messageIds(item), order), item: item),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return [for (final entry in keyed) entry.item];
  }

  // The earliest chat position among [ids]; ids not in the chat sort last.
  static int _earliestPosition(List<String> ids, Map<String, int> order) {
    var earliest = order.length;
    for (final id in ids) {
      final pos = order[id];
      if (pos != null && pos < earliest) earliest = pos;
    }
    return earliest;
  }
}
