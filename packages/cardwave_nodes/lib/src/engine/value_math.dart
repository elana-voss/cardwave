import 'package:cardwave_nodes/src/models/tracked_value.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// What [applyDelta] reports back after mutating a [TrackedValue].
typedef DeltaOutcome = ({
  double appliedDelta,
  bool vetoedByLockout,
  bool shouldLockOpposite,
});

/// Applies [delta] to [value] in place. Pipeline:
/// 1. If lockout is active and the delta is upward (positive), veto: no
///    mutation, return `vetoedByLockout: true`.
/// 2. Else compute the resistance-damped delta:
///       applied = delta * (1 - currentValue * resistanceFactor)
/// 3. Report whether the raw delta's magnitude exceeded
///    [lockoutThreshold] so the caller can set a lockout on the
///    opposite field (the caller, not this function, decides what
///    "opposite" means — for emotions it's the Plutchik pair; for
///    physical and relationship fields there is no opposite in v1).
DeltaOutcome applyDelta(TrackedValue value, double delta) {
  if (value.lockoutTurnsRemaining > 0 && delta > 0) {
    return (
      appliedDelta: 0.0,
      vetoedByLockout: true,
      shouldLockOpposite: false,
    );
  }
  final damping = 1.0 - value.value * resistanceFactor;
  final applied = delta * damping;
  value.value = (value.value + applied).clamp(0.0, 1.0);
  return (
    appliedDelta: applied,
    vetoedByLockout: false,
    shouldLockOpposite: delta.abs() > lockoutThreshold,
  );
}

/// One-turn decay step. Subtracts [decayRate] from [value]'s current
/// value (floor at 0). Mutates in place. Lockout countdown is untouched.
void applyDecay(TrackedValue value, double decayRate) {
  value.value = (value.value - decayRate).clamp(0.0, 1.0);
}

/// Decrements the lockout countdown by 1, floor at 0. Call once per turn
/// at the start, before any deltas.
void tickLockout(TrackedValue value) {
  if (value.lockoutTurnsRemaining > 0) {
    value.lockoutTurnsRemaining -= 1;
  }
}

/// Sets the lockout countdown to [turns]. Call after [applyDelta] returns
/// `shouldLockOpposite: true` to lock the opposite field.
void setLockout(TrackedValue value, int turns) {
  value.lockoutTurnsRemaining = turns;
}
