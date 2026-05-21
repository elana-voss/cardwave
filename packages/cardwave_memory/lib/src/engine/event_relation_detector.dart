import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/observability/memory_logger.dart';
import 'package:schemantic/schemantic.dart';

/// Records the two relations between events that the embedder can't infer on
/// its own:
///
/// - *supersedes* — a later event makes an earlier one no longer true (a death,
///   a destroyed place, a changed status). Stamps [StoryEvent.supersededAt] on
///   the earlier event so it drops out of normal retrieval but stays recallable
///   for "remember when…" questions.
/// - *links* — one event calls back to or is caused by another (a payoff, a
///   returning character). Fills [StoryEvent.linkedEventIds] so retrieval can
///   pull the related event in one hop.
///
/// A separate, lower-frequency judgment than per-window extraction — the same
/// shape as `ChapterGrouper`, and never on the extraction path. [runner] is the
/// injected system-domain model; this package never resolves models.
class EventRelationDetector {
  const EventRelationDetector({
    required this.runner,
    this.windowSize = 30,
    this.minEvents = 2,
  });

  final LlmRunner runner;

  /// Only the most recent live events are weighed, so the call stays a fixed
  /// size as a chat grows. Older facts are not re-evaluated.
  final int windowSize;

  /// Skip until at least this many live events exist — there is nothing to
  /// relate below it.
  final int minEvents;

  // Output field names, named once so the schema and the parser cannot drift.
  static const _keySupersedes = 'supersedes';
  static const _keyLinks = 'links';
  static const _keyEarlier = 'earlier';
  static const _keyLater = 'later';
  static const _keyFrom = 'from';
  static const _keyTo = 'to';

  static final SchemanticType<Map<String, dynamic>> _schema = _buildSchema();

  /// Weighs the recent live events and stamps supersessions and links onto them
  /// in place. Returns whether anything changed, so the caller knows to re-save
  /// the graph and rebuild the retrieval index.
  Future<bool> detect(MemoryGraph graph) async {
    final live = [
      for (final event in graph.events)
        if (event.supersededAt == null) event,
    ];
    if (live.length < minEvents) return false;
    final window = live.length > windowSize
        ? live.sublist(live.length - windowSize)
        : live;

    final numberToEvent = <int, StoryEvent>{};
    var number = 1;
    for (final event in window) {
      numberToEvent[number] = event;
      number++;
    }

    final Map<String, dynamic> raw;
    try {
      raw = await runner.completeStructured(
        _buildPrompt(numberToEvent),
        _schema,
      );
    } on Exception catch (error, stackTrace) {
      memoryLogger.warning(
        'Event-relation pass failed; relations left unchanged.',
        error,
        stackTrace,
      );
      return false;
    }

    final supersedesChanged = _applySupersedes(raw, numberToEvent);
    final linksChanged = _applyLinks(raw, numberToEvent);
    return supersedesChanged || linksChanged;
  }

  bool _applySupersedes(
    Map<String, dynamic> raw,
    Map<int, StoryEvent> numberToEvent,
  ) {
    final entries = raw[_keySupersedes];
    if (entries is! List) return false;
    var changed = false;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final earlier = entry[_keyEarlier];
      final later = entry[_keyLater];
      // The numbering is chronological, so a superseding fact must sit later.
      if (earlier is! int || later is! int || later <= earlier) continue;
      final earlierEvent = numberToEvent[earlier];
      final laterEvent = numberToEvent[later];
      if (earlierEvent == null || laterEvent == null) continue;
      if (earlierEvent.supersededAt != null) continue;
      earlierEvent.supersededAt = laterEvent.recordedAt;
      earlierEvent.supersededBy = laterEvent.id;
      changed = true;
    }
    return changed;
  }

  bool _applyLinks(Map<String, dynamic> raw, Map<int, StoryEvent> numberToEvent) {
    final entries = raw[_keyLinks];
    if (entries is! List) return false;
    var changed = false;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final from = entry[_keyFrom];
      final to = entry[_keyTo];
      if (from is! int || to is! int || from == to) continue;
      final fromEvent = numberToEvent[from];
      final toEvent = numberToEvent[to];
      if (fromEvent == null || toEvent == null) continue;
      if (fromEvent.linkedEventIds.contains(toEvent.id)) continue;
      fromEvent.linkedEventIds = [...fromEvent.linkedEventIds, toEvent.id];
      changed = true;
    }
    return changed;
  }

  static String _buildPrompt(Map<int, StoryEvent> numberToEvent) {
    final buffer = StringBuffer()
      ..writeln(
        'You maintain the memory of a roleplay story. Below are numbered facts '
        'in the order they happened.',
      )
      ..writeln()
      ..writeln('Find two kinds of relation between them:')
      ..writeln(
        '- "supersedes": a LATER fact makes an EARLIER one no longer true — a '
        'death, a destroyed place, a broken bond, a changed status. Give '
        '{"earlier", "later"} as fact numbers. Be strict: only when the earlier '
        'fact has genuinely stopped being true, not when it is merely added to.',
      )
      ..writeln(
        '- "links": one fact directly calls back to or is caused by another — a '
        'payoff, a consequence, a returning character or object. Give {"from", '
        '"to"} as fact numbers.',
      )
      ..writeln()
      ..writeln('Facts:');
    numberToEvent.forEach((number, event) {
      final prefix = event.contextualPrefix.isEmpty
          ? ''
          : '${event.contextualPrefix} ';
      buffer.writeln('$number. $prefix${event.text}');
    });
    return buffer.toString();
  }

  static SchemanticType<Map<String, dynamic>> _buildSchema() {
    final schema = <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[_keySupersedes, _keyLinks],
      'properties': <String, Object?>{
        _keySupersedes: <String, Object?>{
          'type': 'array',
          'items': _pairItem(_keyEarlier, _keyLater),
        },
        _keyLinks: <String, Object?>{
          'type': 'array',
          'items': _pairItem(_keyFrom, _keyTo),
        },
      },
    };
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );
  }

  static Map<String, Object?> _pairItem(String first, String second) => {
    'type': 'object',
    'additionalProperties': false,
    'required': <String>[first, second],
    'properties': <String, Object?>{
      first: <String, Object?>{'type': 'integer'},
      second: <String, Object?>{'type': 'integer'},
    },
  };
}
