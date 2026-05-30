/// Why a [StateChangeRecord] was emitted. Lets the debug view filter
/// or color records by source (e.g. dim the noisy decay records to
/// emphasise director and node-firing entries).
enum StateChangeCategory {
  /// Per-turn passive decay toward 0 plus lockout countdown ticks.
  decay,

  /// Mutation applied by the director's structured output.
  director,

  /// Mutation applied by a node firing this turn.
  nodeFiring,
}

/// One mutation to session state, captured for the debug view's
/// state-change log (spec §10). Human-readable [description] is what
/// the panel renders; [turn] and [category] let the panel group and
/// filter.
class StateChangeRecord {
  const StateChangeRecord({
    required this.turn,
    required this.category,
    required this.description,
  });

  final int turn;
  final StateChangeCategory category;
  final String description;
}

/// Bounded ring buffer of [StateChangeRecord]s. The engine and the
/// director applier accept an optional log; callers (typically the
/// host's debug surface) hold one instance per chat and read its
/// [entries] when rendering.
///
/// Capped to keep long sessions from leaking memory. Oldest records
/// fall off when [maxEntries] is exceeded.
class StateChangeLog {
  StateChangeLog({this.maxEntries = 200});

  final int maxEntries;
  final List<StateChangeRecord> entries = [];

  void add(StateChangeRecord record) {
    entries.add(record);
    if (entries.length > maxEntries) {
      entries.removeRange(0, entries.length - maxEntries);
    }
  }
}

/// Smallest absolute value change worth recording. Below this, a delta
/// is rounding noise (decay against a value already at 0 etc.) and
/// would only clutter the debug panel. Used by both the firing engine
/// and the director applier so the threshold is shared.
const double stateChangeRecordEpsilon = 1e-6;

/// Records a numeric mutation when the change clears
/// [stateChangeRecordEpsilon]. No-op when [changeLog] is null. The
/// rendered description is `path: before -> after (note)` where the
/// `(note)` suffix only appears if [note] is non-null.
void recordValueChange({
  required StateChangeLog? changeLog,
  required StateChangeCategory category,
  required int turn,
  required String path,
  required double before,
  required double after,
  String? note,
}) {
  if (changeLog == null) return;
  if ((before - after).abs() < stateChangeRecordEpsilon) return;
  final suffix = note == null ? '' : ' ($note)';
  changeLog.add(StateChangeRecord(
    turn: turn,
    category: category,
    description: '$path: ${before.toStringAsFixed(2)} -> '
        '${after.toStringAsFixed(2)}$suffix',
  ));
}
