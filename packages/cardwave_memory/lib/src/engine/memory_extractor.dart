import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/src/models/event_type_enum.dart';
import 'package:cardwave_memory/src/models/memory_fact.dart';
import 'package:cardwave_memory/src/models/memory_message.dart';
import 'package:cardwave_memory/src/models/memory_role.dart';
import 'package:cardwave_memory/src/models/memory_thread.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/observability/memory_logger.dart';
import 'package:cardwave_memory/src/utils/memory_id.dart';
import 'package:schemantic/schemantic.dart';

/// What one extraction call produced: the [events] ("what happened"), the new
/// [facts] ("what's true now"), the newly opened [threads] ("what's pending"),
/// [supersedes] — a map from an existing fact's id to the new fact id that
/// overrode it — and [resolvedThreadIds] — ids of existing open threads the
/// window's messages closed. A thread is closed by the messages, not by a
/// replacement record, so resolution is a set of ids, not a map.
class ExtractionResult {
  const ExtractionResult({
    required this.events,
    required this.facts,
    required this.threads,
    required this.supersedes,
    required this.resolvedThreadIds,
  });

  final List<StoryEvent> events;
  final List<MemoryFact> facts;
  final List<MemoryThread> threads;
  final Map<String, String> supersedes;
  final Set<String> resolvedThreadIds;

  static const empty = ExtractionResult(
    events: [],
    facts: [],
    threads: [],
    supersedes: {},
    resolvedThreadIds: {},
  );
}

/// Extracts story memory from a window of chat messages in one structured LLM
/// call. It pulls out two things at once: atomic [StoryEvent]s ("what
/// happened", embedded for similarity search) and [MemoryFact]s ("what's true
/// now" about the entities, recalled by name). Only the NEW messages are
/// numbered and turned into memory; earlier messages are shown as background so
/// the model can write situating lines, but are never re-extracted.
///
/// Known facts that the window's text touches are passed in as [candidateFacts]
/// and labelled F1, F2, … so the model can flag — without a second call — which
/// of them a new fact makes false. Each event is emotion-tagged via [classifier]
/// and embedded via [embedder] on the way out; facts are neither.
///
/// [runner], [embedder], and [classifier] are injected: this package never
/// reads settings, resolves presets, or builds runners.
class MemoryExtractor {
  const MemoryExtractor({
    required this.runner,
    required this.embedder,
    required this.classifier,
  });

  final LlmRunner runner;
  final Embedder embedder;
  final EmotionClassifier classifier;

  // Output field names, named once so the schema and the parser cannot drift.
  static const _keyEvents = 'events';
  static const _keyFacts = 'facts';
  static const _keyThreads = 'threads';
  static const _keyResolvedThreads = 'resolved_threads';
  static const _keyText = 'text';
  static const _keyContextualPrefix = 'contextual_prefix';
  static const _keyEventType = 'event_type';
  static const _keyCause = 'cause';
  static const _keyEffect = 'effect';
  static const _keyMessageNumbers = 'message_numbers';
  static const _keyCharacters = 'characters';
  static const _keyLocations = 'locations';
  static const _keyItems = 'items';
  static const _keyConcepts = 'concepts';
  static const _keyKeywords = 'keywords';
  static const _keyImportance = 'importance';
  static const _keySubjects = 'subjects';
  static const _keySupersedes = 'supersedes';

  /// Extracts from [window]. The first [contextCount] messages are earlier,
  /// already-remembered background — shown to the model for continuity but NOT
  /// numbered and NOT turned into memory. [candidateFacts] are existing facts
  /// the window's text touches; the model may mark one superseded by a new
  /// fact. [candidateThreads] are still-open threads the text touches; the model
  /// may mark one resolved. Only the messages after the background are
  /// extracted, so each message becomes memory exactly once as windows advance.
  Future<ExtractionResult> extract(
    List<MemoryMessage> window, {
    int contextCount = 0,
    List<MemoryFact> candidateFacts = const [],
    List<MemoryThread> candidateThreads = const [],
  }) async {
    final context = contextCount > 0
        ? window.take(contextCount).toList()
        : const <MemoryMessage>[];
    final newMessages = window.skip(contextCount).toList();
    if (newMessages.isEmpty) return ExtractionResult.empty;

    final numberToMessage = <int, MemoryMessage>{};
    var number = 1;
    for (final message in newMessages) {
      numberToMessage[number] = message;
      number++;
    }

    // Candidate facts are labelled F1, F2, … and candidate open threads T1,
    // T2, … so the model references them without colliding with the message
    // numbers above or with each other.
    final labelToFact = <String, MemoryFact>{};
    var factNumber = 1;
    for (final fact in candidateFacts) {
      labelToFact['F$factNumber'] = fact;
      factNumber++;
    }
    final labelToThread = <String, MemoryThread>{};
    var threadNumber = 1;
    for (final thread in candidateThreads) {
      labelToThread['T$threadNumber'] = thread;
      threadNumber++;
    }

    final Map<String, dynamic> raw;
    try {
      raw = await runner.completeStructured(
        _buildPrompt(context, numberToMessage, labelToFact, labelToThread),
        _buildSchema(labelToFact.keys.toList(), labelToThread.keys.toList()),
      );
    } on Exception catch (error, stackTrace) {
      logMemoryWarning(
        'Memory extraction failed; window will be retried next pass.',
        error,
        stackTrace,
      );
      return ExtractionResult.empty;
    }

    return _parse(raw, numberToMessage, labelToFact, labelToThread);
  }

  Future<ExtractionResult> _parse(
    Map<String, dynamic> raw,
    Map<int, MemoryMessage> numberToMessage,
    Map<String, MemoryFact> labelToFact,
    Map<String, MemoryThread> labelToThread,
  ) async {
    // LLM output is untrusted: read every field by type and skip what does not
    // fit, the same way the sidecar codec tolerates bad bytes. No try/catch —
    // that is reserved for the completeStructured call itself.
    final events = <StoryEvent>[];
    final eventsJson = raw[_keyEvents];
    if (eventsJson is List) {
      for (final entry in eventsJson) {
        if (entry is! Map) continue;
        final event = await _parseEvent(entry, numberToMessage);
        if (event != null) events.add(event);
      }
    }

    final facts = <MemoryFact>[];
    final supersedes = <String, String>{};
    final factsJson = raw[_keyFacts];
    if (factsJson is List) {
      for (final entry in factsJson) {
        if (entry is! Map) continue;
        final fact = _parseFact(entry, numberToMessage);
        if (fact == null) continue;
        facts.add(fact);
        final supersededLabel = entry[_keySupersedes];
        if (supersededLabel is String) {
          final superseded = labelToFact[supersededLabel];
          if (superseded != null) supersedes[superseded.id] = fact.id;
        }
      }
    }

    final threads = <MemoryThread>[];
    final threadsJson = raw[_keyThreads];
    if (threadsJson is List) {
      for (final entry in threadsJson) {
        if (entry is! Map) continue;
        final thread = _parseThread(entry, numberToMessage);
        if (thread != null) threads.add(thread);
      }
    }

    // Resolved threads are cited by their candidate label (T1, T2, …); map each
    // back to the open thread's id the engine will close.
    final resolvedThreadIds = <String>{};
    final resolvedJson = raw[_keyResolvedThreads];
    if (resolvedJson is List) {
      for (final label in resolvedJson) {
        final thread = label is String ? labelToThread[label] : null;
        if (thread != null) resolvedThreadIds.add(thread.id);
      }
    }

    return ExtractionResult(
      events: events,
      facts: facts,
      threads: threads,
      supersedes: supersedes,
      resolvedThreadIds: resolvedThreadIds,
    );
  }

  Future<StoryEvent?> _parseEvent(
    Map<dynamic, dynamic> entry,
    Map<int, MemoryMessage> numberToMessage,
  ) async {
    final text = entry[_keyText];
    if (text is! String || text.isEmpty) return null;

    final eventMessages = _citedMessages(entry, numberToMessage, 'event');
    if (eventMessages == null) return null;

    final contextualPrefix = _string(entry[_keyContextualPrefix]);
    final userText = eventMessages
        .where((m) => m.role == MemoryRole.user)
        .map((m) => m.text)
        .join('\n');
    final characterText = eventMessages
        .where((m) => m.role == MemoryRole.character)
        .map((m) => m.text)
        .join('\n');
    final emotions = await classifier.classifyPair(userText, characterText);

    final event = StoryEvent(
      id: newEventId(),
      recordedAt: DateTime.now().millisecondsSinceEpoch,
      text: text,
      contextualPrefix: contextualPrefix,
      eventType: EventTypeEnum.fromWireName(_string(entry[_keyEventType])),
      cause: _string(entry[_keyCause]),
      effect: _string(entry[_keyEffect]),
      messageIds: [for (final message in eventMessages) message.id],
      characterEmotion: emotions.character.label,
      userEmotion: emotions.user.label,
      importance: _clampImportance(entry[_keyImportance]),
      characters: _stringList(entry[_keyCharacters]),
      locations: _stringList(entry[_keyLocations]),
      items: _stringList(entry[_keyItems]),
      concepts: _stringList(entry[_keyConcepts]),
      keywords: _stringList(entry[_keyKeywords]),
    );
    // Contextual prepend before embedding (Anthropic contextual retrieval).
    event.vector = await embedder.embedOne(
      contextualPrefix.isEmpty ? text : '$contextualPrefix $text',
      task: EmbedTaskEnum.passage,
    );
    return event;
  }

  // Facts carry no vector and no emotion: they are recalled by their subject
  // names, not by similarity, so there is nothing to embed or classify.
  MemoryFact? _parseFact(
    Map<dynamic, dynamic> entry,
    Map<int, MemoryMessage> numberToMessage,
  ) {
    final text = entry[_keyText];
    if (text is! String || text.isEmpty) return null;

    final subjects = _normalizeSubjects(entry[_keySubjects]);
    if (subjects.isEmpty) return null;

    final messages = _citedMessages(entry, numberToMessage, 'fact');
    if (messages == null) return null;

    return MemoryFact(
      id: newFactId(),
      subjects: subjects,
      text: text,
      messageIds: [for (final message in messages) message.id],
    );
  }

  // Threads, like facts, carry no vector — recalled by subject name. Opened
  // here; closed later when a window's messages resolve them.
  MemoryThread? _parseThread(
    Map<dynamic, dynamic> entry,
    Map<int, MemoryMessage> numberToMessage,
  ) {
    final text = entry[_keyText];
    if (text is! String || text.isEmpty) return null;

    final subjects = _normalizeSubjects(entry[_keySubjects]);
    if (subjects.isEmpty) return null;

    final messages = _citedMessages(entry, numberToMessage, 'thread');
    if (messages == null) return null;

    return MemoryThread(
      id: newThreadId(),
      subjects: subjects,
      text: text,
      messageIds: [for (final message in messages) message.id],
    );
  }

  // The model's importance, clamped to 1-5; anything missing or out of range
  // becomes 3 (neutral) so a malformed value neither buries nor over-lifts the
  // event in ranking.
  static int _clampImportance(Object? value) {
    if (value is! int) return 3;
    return value.clamp(1, 5);
  }

  // Resolves the cited message numbers to the window messages they point at,
  // or null (after logging) when none match. An extracted event or fact that
  // anchors to no real message can't be reconciled or retrieved, so it is
  // dropped rather than stored orphaned.
  static List<MemoryMessage>? _citedMessages(
    Map<dynamic, dynamic> entry,
    Map<int, MemoryMessage> numberToMessage,
    String kind,
  ) {
    final messages = <MemoryMessage>[];
    final numbersJson = entry[_keyMessageNumbers];
    if (numbersJson is List) {
      for (final number in numbersJson) {
        if (number is! int) continue;
        final message = numberToMessage[number];
        if (message != null) messages.add(message);
      }
    }
    if (messages.isEmpty) {
      logMemoryWarning(
        'Dropped an extracted $kind: it cited no message present in the window.',
      );
      return null;
    }
    return messages;
  }

  // Trimmed, lower-cased entity names — the shared lookup-key form for both
  // fact and thread subjects, so the two cannot drift.
  static List<String> _normalizeSubjects(Object? value) => [
    for (final subject in _stringList(value))
      if (subject.trim().isNotEmpty) subject.trim().toLowerCase(),
  ];

  static String _string(Object? value) => value is String ? value : '';

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is String) item];
  }

  static String _buildPrompt(
    List<MemoryMessage> context,
    Map<int, MemoryMessage> numberToMessage,
    Map<String, MemoryFact> labelToFact,
    Map<String, MemoryThread> labelToThread,
  ) {
    final buffer = StringBuffer()
      ..writeln(
        'You extract story memory from a roleplay chat. Read the messages and '
        'pull out three things: the atomic events that happened, the facts '
        'about the characters and world that hold true as of these messages, '
        'and the open threads left unresolved.',
      )
      ..writeln()
      ..writeln(
        'For each event give: a short factual "text"; a one-line '
        '"contextual_prefix" situating it in the wider story (who, where, '
        'when); an "event_type" from the list below; a short "cause" (why it '
        'happened) and "effect" (what came of it), each "" if not clear; the '
        '"message_numbers" it draws from; the "characters", "locations", '
        '"items", "concepts" and "keywords" involved; and an "importance".',
      )
      ..writeln()
      ..writeln('event_type — choose the closest:')
      ..writeAll([
        for (final type in EventTypeEnum.values)
          '  ${type.wireName}: ${type.description}\n',
      ])
      ..writeln()
      ..writeln(
        'importance — 1 to 5, judged the same way across every event_type (a '
        'quiet conversation can outrank a fight); score by lasting impact on '
        'the characters or story, not by how dramatic the type sounds:',
      )
      ..writeln(
        '  1 trivial: ambient or routine, forgotten within the scene.',
      )
      ..writeln('  2 minor: a small real beat worth light recall.')
      ..writeln('  3 notable: shapes the near-term mood or plan.')
      ..writeln(
        '  4 major: lastingly changes a relationship or situation.',
      )
      ..writeln('  5 pivotal: a turning point the story hinges on.')
      ..writeln()
      ..writeln(
        'For each fact give: the "subjects" it is about (character or place '
        'names); the "text" of the fact, a short present-tense statement (e.g. '
        '"Mayla and the captain are enemies"); and the "message_numbers" it '
        'draws from. A fact is durable current state — a relationship, trait, '
        'possession, role, or goal — not a one-off action, which is an event.',
      )
      ..writeln()
      ..writeln(
        'For each NEW open thread give: the "subjects" it is about; the "text" '
        'of what is left pending (a promise made, a debt owed, an unanswered '
        'question); and the "message_numbers" it draws from. Only threads these '
        'messages newly raise — not ones already listed below.',
      )
      ..writeln();

    if (labelToFact.isNotEmpty) {
      buffer.writeln(
        'Known facts that these messages may change. If one is no longer true '
        'after these messages, set the new fact\'s "supersedes" to its label '
        '(otherwise null):',
      );
      labelToFact.forEach((label, fact) {
        buffer.writeln('$label. ${fact.text}');
      });
      buffer.writeln();
    }

    if (labelToThread.isNotEmpty) {
      buffer.writeln(
        'Open threads so far. If these messages resolve any, list its label in '
        '"resolved_threads":',
      );
      labelToThread.forEach((label, thread) {
        buffer.writeln('$label. ${thread.text}');
      });
      buffer.writeln();
    }

    if (context.isNotEmpty) {
      buffer.writeln(
        'Earlier context — already remembered, shown for background only; do '
        'NOT create events or facts from these:',
      );
      for (final message in context) {
        buffer.writeln('- ${message.role.name}: ${message.text}');
      }
      buffer.writeln();
    }

    buffer.writeln('Messages:');
    numberToMessage.forEach((number, message) {
      buffer.writeln('$number. ${message.role.name}: ${message.text}');
    });
    return buffer.toString();
  }

  static SchemanticType<Map<String, dynamic>> _buildSchema(
    List<String> factLabels,
    List<String> threadLabels,
  ) {
    final stringArray = <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{'type': 'string'},
    };
    final eventItem = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[
        _keyText,
        _keyContextualPrefix,
        _keyEventType,
        _keyCause,
        _keyEffect,
        _keyMessageNumbers,
        _keyCharacters,
        _keyLocations,
        _keyItems,
        _keyConcepts,
        _keyKeywords,
        _keyImportance,
      ],
      'properties': <String, Object?>{
        _keyText: <String, Object?>{
          'type': 'string',
          'description': 'What happened, in one or two sentences.',
        },
        _keyContextualPrefix: <String, Object?>{
          'type': 'string',
          'description':
              'One line situating the event in the wider story; prepended '
              'before embedding.',
        },
        _keyEventType: <String, Object?>{
          'type': 'string',
          'enum': <String>[for (final t in EventTypeEnum.values) t.wireName],
          'description': 'The kind of moment; see the list in the prompt.',
        },
        _keyCause: <String, Object?>{
          'type': 'string',
          'description': 'Why it happened, or "" if unclear.',
        },
        _keyEffect: <String, Object?>{
          'type': 'string',
          'description': 'What came of it, or "" if unclear.',
        },
        _keyMessageNumbers: <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'integer'},
          'description': 'The numbered messages this event is drawn from.',
        },
        _keyCharacters: stringArray,
        _keyLocations: stringArray,
        _keyItems: stringArray,
        _keyConcepts: stringArray,
        _keyKeywords: stringArray,
        _keyImportance: <String, Object?>{
          'type': 'integer',
          'description': '1 (trivial) to 5 (pivotal); see the prompt rubric.',
        },
      },
    };
    final threadItem = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[_keySubjects, _keyText, _keyMessageNumbers],
      'properties': <String, Object?>{
        _keySubjects: <String, Object?>{
          ...stringArray,
          'description': 'Character or place names this thread is about.',
        },
        _keyText: <String, Object?>{
          'type': 'string',
          'description': 'What is left pending — a promise, debt, or question.',
        },
        _keyMessageNumbers: <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'integer'},
          'description': 'The numbered messages this thread is drawn from.',
        },
      },
    };
    final factItem = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[
        _keySubjects,
        _keyText,
        _keyMessageNumbers,
        _keySupersedes,
      ],
      'properties': <String, Object?>{
        _keySubjects: <String, Object?>{
          ...stringArray,
          'description': 'Character or place names this fact is about.',
        },
        _keyText: <String, Object?>{
          'type': 'string',
          'description': 'A short present-tense statement of current state.',
        },
        _keyMessageNumbers: <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'integer'},
          'description': 'The numbered messages this fact is drawn from.',
        },
        _keySupersedes: <String, Object?>{
          'type': <String>['string', 'null'],
          // Constrain to the offered labels only when there are some; an
          // empty chat has no candidate facts, and a one-value [null] list is
          // a degenerate constraint a strict backend may reject.
          if (factLabels.isNotEmpty) 'enum': <Object?>[...factLabels, null],
          'description':
              'The label of a known fact this one makes no longer true, or '
              'null.',
        },
      },
    };
    final schema = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[
        _keyEvents,
        _keyFacts,
        _keyThreads,
        _keyResolvedThreads,
      ],
      'properties': <String, Object?>{
        _keyEvents: <String, Object?>{'type': 'array', 'items': eventItem},
        _keyFacts: <String, Object?>{'type': 'array', 'items': factItem},
        _keyThreads: <String, Object?>{'type': 'array', 'items': threadItem},
        _keyResolvedThreads: <String, Object?>{
          'type': 'array',
          // Constrain to the offered thread labels only when there are some, the
          // same guard the fact "supersedes" enum uses.
          'items': <String, Object?>{
            'type': 'string',
            if (threadLabels.isNotEmpty) 'enum': threadLabels,
          },
          'description':
              'Labels of the open threads above that these messages resolve.',
        },
      },
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }
}
