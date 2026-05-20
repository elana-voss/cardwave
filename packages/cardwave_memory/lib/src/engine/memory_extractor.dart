import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/src/engine/scene_verdict.dart';
import 'package:cardwave_memory/src/models/memory_message.dart';
import 'package:cardwave_memory/src/models/memory_role.dart';
import 'package:cardwave_memory/src/models/scene_beat_enum.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/observability/memory_logger.dart';
import 'package:cardwave_memory/src/utils/memory_id.dart';
import 'package:schemantic/schemantic.dart';

/// The events extracted from one window plus the scene-boundary [verdict].
class ExtractionResult {
  const ExtractionResult({required this.events, required this.verdict});

  final List<StoryEvent> events;
  final SceneVerdict verdict;
}

/// Extracts atomic story events from a window of chat messages in one
/// structured LLM call. Only the NEW messages are numbered and turned into
/// events; any earlier messages are shown as background context so the model
/// can place scene boundaries and write situating lines, but they are never
/// re-extracted. The scene verdict comes back as a message NUMBER — never a raw
/// id, which models miscopy. Each event is emotion-tagged via [classifier] and
/// embedded via [embedder] on the way out.
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
  static const _keySceneEnd = 'scene_end_message';
  static const _keySceneSummary = 'scene_summary';
  static const _keyText = 'text';
  static const _keyContextualPrefix = 'contextual_prefix';
  static const _keyMessageNumbers = 'message_numbers';
  static const _keyCharacters = 'characters';
  static const _keyLocations = 'locations';
  static const _keyItems = 'items';
  static const _keyConcepts = 'concepts';
  static const _keyKeywords = 'keywords';
  static const _keyImportance = 'importance';
  static const _keyBeat = 'beat';

  static final SchemanticType<Map<String, dynamic>> _eventSchema =
      _buildEventSchema();

  /// Extracts events from [window]. The first [contextCount] messages are
  /// earlier, already-remembered background — shown to the model for continuity
  /// and to situate events, but NOT numbered and NOT turned into events. Only
  /// the messages after them are extracted, so each message becomes a memory
  /// exactly once as windows advance.
  Future<ExtractionResult> extract(
    List<MemoryMessage> window, {
    int contextCount = 0,
  }) async {
    final context = contextCount > 0
        ? window.take(contextCount).toList()
        : const <MemoryMessage>[];
    final newMessages = window.skip(contextCount).toList();
    if (newMessages.isEmpty) {
      return const ExtractionResult(events: [], verdict: SceneContinues());
    }

    final numberToMessage = <int, MemoryMessage>{};
    var number = 1;
    for (final message in newMessages) {
      numberToMessage[number] = message;
      number++;
    }

    final Map<String, dynamic> raw;
    try {
      raw = await runner.completeStructured(
        _buildPrompt(context, numberToMessage),
        _eventSchema,
      );
    } on Exception catch (error, stackTrace) {
      memoryLogger.warning(
        'Event extraction failed; window stays provisional.',
        error,
        stackTrace,
      );
      return const ExtractionResult(events: [], verdict: SceneContinues());
    }

    return _parse(raw, numberToMessage);
  }

  Future<ExtractionResult> _parse(
    Map<String, dynamic> raw,
    Map<int, MemoryMessage> numberToMessage,
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
    return ExtractionResult(
      events: events,
      verdict: _parseVerdict(raw, numberToMessage),
    );
  }

  Future<StoryEvent?> _parseEvent(
    Map<dynamic, dynamic> entry,
    Map<int, MemoryMessage> numberToMessage,
  ) async {
    final text = entry[_keyText];
    if (text is! String || text.isEmpty) return null;

    final eventMessages = <MemoryMessage>[];
    final numbersJson = entry[_keyMessageNumbers];
    if (numbersJson is List) {
      for (final number in numbersJson) {
        if (number is! int) continue;
        final message = numberToMessage[number];
        if (message != null) eventMessages.add(message);
      }
    }
    // An event must anchor to at least one of the numbered (new) messages. If
    // it cites only numbers with no matching message, it can't be tied to the
    // chat — it could never be reconciled or retrieved — so drop it, and log
    // the drop so it isn't silent.
    if (eventMessages.isEmpty) {
      memoryLogger.warning(
        'Dropped an extracted event: it cited no message present in the window.',
      );
      return null;
    }

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
      beat: _parseBeat(entry[_keyBeat]),
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

  SceneVerdict _parseVerdict(
    Map<String, dynamic> raw,
    Map<int, MemoryMessage> numberToMessage,
  ) {
    final cut = raw[_keySceneEnd];
    if (cut is! int) return const SceneContinues();
    final boundary = numberToMessage[cut];
    if (boundary == null) return const SceneContinues();
    return SceneEndsAt(
      messageId: boundary.id,
      summary: _string(raw[_keySceneSummary]),
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is String) item];
  }

  static SceneBeatEnum? _parseBeat(Object? value) {
    if (value is! String) return null;
    for (final beat in SceneBeatEnum.values) {
      if (beat.name == value) return beat;
    }
    return null;
  }

  static String _buildPrompt(
    List<MemoryMessage> context,
    Map<int, MemoryMessage> numberToMessage,
  ) {
    final buffer = StringBuffer()
      ..writeln(
        'You extract story memory from a roleplay chat. Read the messages and '
        'pull out the atomic story events they contain.',
      )
      ..writeln()
      ..writeln(
        'For each event give: a short factual "text"; a one-line '
        '"contextual_prefix" situating it in the wider story (who, where, '
        'when); the "message_numbers" it draws from; the "characters", '
        '"locations", "items", "concepts" and "keywords" involved; an '
        '"importance" from 1 (trivial) to 5 (pivotal); and a scene "beat" '
        '(goal/conflict/disaster/reaction/dilemma/decision) when one clearly '
        'fits, otherwise null.',
      )
      ..writeln()
      ..writeln(
        'Then judge the scene boundary: set "scene_end_message" to the number '
        'of the last message of a scene that clearly ends inside this window, '
        'or null if the scene runs past it. Give a one-line "scene_summary" '
        'when a scene ends; leave it empty otherwise.',
      )
      ..writeln();
    if (context.isNotEmpty) {
      buffer.writeln(
        'Earlier context — already remembered, shown for background only; do '
        'NOT create events from these:',
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

  static SchemanticType<Map<String, dynamic>> _buildEventSchema() {
    final beatValues = <Object?>[
      for (final beat in SceneBeatEnum.values) beat.name,
      null,
    ];
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
        _keyBeat,
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
        _keyBeat: <String, Object?>{
          'type': <String>['string', 'null'],
          'enum': beatValues,
        },
      },
    };
    final schema = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[_keyEvents, _keySceneEnd, _keySceneSummary],
      'properties': <String, Object?>{
        _keyEvents: <String, Object?>{'type': 'array', 'items': eventItem},
        _keySceneEnd: <String, Object?>{
          'type': <String>['integer', 'null'],
          'description':
              'Number of the message where the current scene ends, or null if '
              'it continues past this window.',
        },
        _keySceneSummary: <String, Object?>{
          'type': 'string',
          'description':
              'One-line summary of the scene that just ended; empty if it '
              'continues.',
        },
      },
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }
}
