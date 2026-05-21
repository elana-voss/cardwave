import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/src/models/memory_fact.dart';
import 'package:cardwave_memory/src/models/memory_message.dart';
import 'package:cardwave_memory/src/models/memory_role.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/observability/memory_logger.dart';
import 'package:cardwave_memory/src/utils/memory_id.dart';
import 'package:schemantic/schemantic.dart';

/// What one extraction call produced: the [events] ("what happened"), the new
/// [facts] ("what's true now"), and [supersedes] — a map from an existing
/// fact's id to the new fact id that overrode it, so the engine can retire the
/// stale fact.
class ExtractionResult {
  const ExtractionResult({
    required this.events,
    required this.facts,
    required this.supersedes,
  });

  final List<StoryEvent> events;
  final List<MemoryFact> facts;
  final Map<String, String> supersedes;

  static const empty = ExtractionResult(events: [], facts: [], supersedes: {});
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
  static const _keyText = 'text';
  static const _keyContextualPrefix = 'contextual_prefix';
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
  /// fact. Only the messages after the background are extracted, so each
  /// message becomes memory exactly once as windows advance.
  Future<ExtractionResult> extract(
    List<MemoryMessage> window, {
    int contextCount = 0,
    List<MemoryFact> candidateFacts = const [],
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

    // Candidate facts are labelled F1, F2, … so the model references them
    // without colliding with the message numbers above.
    final labelToFact = <String, MemoryFact>{};
    var factNumber = 1;
    for (final fact in candidateFacts) {
      labelToFact['F$factNumber'] = fact;
      factNumber++;
    }

    final Map<String, dynamic> raw;
    try {
      raw = await runner.completeStructured(
        _buildPrompt(context, numberToMessage, labelToFact),
        _buildSchema(labelToFact.keys.toList()),
      );
    } on Exception catch (error, stackTrace) {
      memoryLogger.warning(
        'Memory extraction failed; window will be retried next pass.',
        error,
        stackTrace,
      );
      return ExtractionResult.empty;
    }

    return _parse(raw, numberToMessage, labelToFact);
  }

  Future<ExtractionResult> _parse(
    Map<String, dynamic> raw,
    Map<int, MemoryMessage> numberToMessage,
    Map<String, MemoryFact> labelToFact,
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

    return ExtractionResult(events: events, facts: facts, supersedes: supersedes);
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

    final importance = entry[_keyImportance];
    final event = StoryEvent(
      id: newEventId(),
      recordedAt: DateTime.now().millisecondsSinceEpoch,
      text: text,
      contextualPrefix: contextualPrefix,
      messageIds: [for (final message in eventMessages) message.id],
      characterEmotion: emotions.character.label,
      userEmotion: emotions.user.label,
      importance: importance is int ? importance : 0,
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

    final subjects = <String>[
      for (final subject in _stringList(entry[_keySubjects]))
        if (subject.trim().isNotEmpty) subject.trim().toLowerCase(),
    ];
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
      memoryLogger.warning(
        'Dropped an extracted $kind: it cited no message present in the window.',
      );
      return null;
    }
    return messages;
  }

  static String _string(Object? value) => value is String ? value : '';

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is String) item];
  }

  static String _buildPrompt(
    List<MemoryMessage> context,
    Map<int, MemoryMessage> numberToMessage,
    Map<String, MemoryFact> labelToFact,
  ) {
    final buffer = StringBuffer()
      ..writeln(
        'You extract story memory from a roleplay chat. Read the messages and '
        'pull out two things: the atomic events that happened, and the facts '
        'about the characters and world that hold true as of these messages.',
      )
      ..writeln()
      ..writeln(
        'For each event give: a short factual "text"; a one-line '
        '"contextual_prefix" situating it in the wider story (who, where, '
        'when); the "message_numbers" it draws from; the "characters", '
        '"locations", "items", "concepts" and "keywords" involved; and an '
        '"importance" from 1 (trivial) to 5 (pivotal).',
      )
      ..writeln()
      ..writeln(
        'For each fact give: the "subjects" it is about (character or place '
        'names); the "text" of the fact, a short present-tense statement (e.g. '
        '"Mayla and the captain are enemies"); and the "message_numbers" it '
        'draws from. A fact is durable current state — a relationship, trait, '
        'possession, role, or goal — not a one-off action, which is an event.',
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
          'description': '1 (trivial) to 5 (pivotal).',
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
      'required': <String>[_keyEvents, _keyFacts],
      'properties': <String, Object?>{
        _keyEvents: <String, Object?>{'type': 'array', 'items': eventItem},
        _keyFacts: <String, Object?>{'type': 'array', 'items': factItem},
      },
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }
}
