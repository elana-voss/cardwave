import 'package:cardwave_nodes/src/models/character_state.dart';
import 'package:cardwave_nodes/src/models/event_log_entry.dart';
import 'package:cardwave_nodes/src/models/phase_enum.dart';
import 'package:cardwave_nodes/src/models/scene.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_state.g.dart';

/// The entire NODES per-chat state. One [SessionState] lives per chat.
/// Per-character state is keyed by character id in [characters];
/// everything else (scene, phase, goal, flags, eventLog, turn) is shared
/// across all participants in the chat.
@JsonSerializable(explicitToJson: true)
class SessionState {
  SessionState({
    Map<String, CharacterState>? characters,
    this.currentGoal = '',
    this.currentPhase = PhaseEnum.scene,
    Scene? currentScene,
    Map<String, Object?>? flags,
    List<EventLogEntry>? eventLog,
    this.turn = 0,
    List<String>? pendingDirectives,
  })  : characters = characters ?? {},
        currentScene = currentScene ?? Scene(),
        flags = flags ?? {},
        eventLog = eventLog ?? [],
        pendingDirectives = pendingDirectives ?? [];

  factory SessionState.fromJson(Map<String, dynamic> json) =>
      _$SessionStateFromJson(json);

  final Map<String, CharacterState> characters;
  String currentGoal;
  PhaseEnum currentPhase;
  Scene currentScene;
  final Map<String, Object?> flags;
  final List<EventLogEntry> eventLog;
  int turn;

  /// Short authorial directives the director wrote at the end of the
  /// previous turn (spec §6.2: "inject into the actor's prompt this
  /// turn"). The next prompt assembly reads and clears them; one
  /// turn's lifetime, no carryover.
  final List<String> pendingDirectives;

  Map<String, dynamic> toJson() => _$SessionStateToJson(this);
}
