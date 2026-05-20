import 'package:cardwave_memory/src/models/story_event.dart';

/// In-memory hold for provisional events — the un-committed tail of the
/// current scene. Never persisted: it is rebuilt by re-extracting the saved
/// chat tail on resume.
class StagingBuffer {
  final List<StoryEvent> _events = [];

  List<StoryEvent> get events => List.unmodifiable(_events);
  bool get isEmpty => _events.isEmpty;
  int get length => _events.length;

  void add(StoryEvent event) => _events.add(event);

  /// Removes and returns staged events from the front up to and including the
  /// event that covers [boundaryMessageId] — the scene that just ended. If no
  /// staged event covers it, drains nothing: the events stay provisional until
  /// a window reports a cut that lands inside an event, rather than committing
  /// the next scene's opening by mistake.
  List<StoryEvent> drainThrough(String boundaryMessageId) {
    final boundary = _events.indexWhere(
      (event) => event.messageIds.contains(boundaryMessageId),
    );
    if (boundary == -1) return const [];
    final drained = _events.sublist(0, boundary + 1);
    _events.removeRange(0, boundary + 1);
    return drained;
  }

  void clear() => _events.clear();
}
