import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyDelta', () {
    test('full effect at currentValue 0', () {
      final v = TrackedValue();
      final outcome = applyDelta(v, 0.30);
      expect(v.value, closeTo(0.30, 1e-9));
      expect(outcome.appliedDelta, closeTo(0.30, 1e-9));
      expect(outcome.vetoedByLockout, isFalse);
      expect(outcome.shouldLockOpposite, isFalse);
    });

    test('damps at high currentValue (resistanceFactor 0.8)', () {
      // currentValue 1.0, factor 0.8 → multiplier (1 - 0.8) = 0.2.
      final v = TrackedValue(value: 1.0);
      final outcome = applyDelta(v, 0.30);
      expect(outcome.appliedDelta, closeTo(0.30 * 0.2, 1e-9));
    });

    test('clamps at 1.0', () {
      final v = TrackedValue(value: 0.95);
      applyDelta(v, 0.50);
      expect(v.value, 1.0);
    });

    test('clamps at 0.0', () {
      final v = TrackedValue(value: 0.10);
      applyDelta(v, -0.50);
      expect(v.value, 0.0);
    });

    test('lockout vetoes upward delta (no mutation)', () {
      final v = TrackedValue(value: 0.40, lockoutTurnsRemaining: 2);
      final outcome = applyDelta(v, 0.30);
      expect(v.value, 0.40);
      expect(outcome.appliedDelta, 0.0);
      expect(outcome.vetoedByLockout, isTrue);
      expect(v.lockoutTurnsRemaining, 2);
    });

    test('lockout does NOT block downward delta', () {
      final v = TrackedValue(value: 0.50, lockoutTurnsRemaining: 2);
      final outcome = applyDelta(v, -0.20);
      expect(v.value, lessThan(0.50));
      expect(outcome.vetoedByLockout, isFalse);
    });

    test('large delta flags shouldLockOpposite', () {
      final v = TrackedValue();
      final outcome = applyDelta(v, 0.50);
      expect(outcome.shouldLockOpposite, isTrue);
    });

    test('small delta does not flag shouldLockOpposite', () {
      final v = TrackedValue();
      final outcome = applyDelta(v, 0.30);
      expect(outcome.shouldLockOpposite, isFalse);
    });

    test('shouldLockOpposite uses raw delta, not damped', () {
      // High currentValue dampens applied effect, but raw delta still
      // exceeds threshold → lockout still triggers.
      final v = TrackedValue(value: 0.9);
      final outcome = applyDelta(v, 0.50);
      expect(outcome.appliedDelta.abs(), lessThan(0.50));
      expect(outcome.shouldLockOpposite, isTrue);
    });
  });

  group('applyDecay', () {
    test('subtracts decay rate', () {
      final v = TrackedValue(value: 0.50);
      applyDecay(v, 0.10);
      expect(v.value, closeTo(0.40, 1e-9));
    });

    test('floors at 0', () {
      final v = TrackedValue(value: 0.05);
      applyDecay(v, 0.10);
      expect(v.value, 0.0);
    });

    test('preserves lockout countdown', () {
      final v = TrackedValue(value: 0.50, lockoutTurnsRemaining: 2);
      applyDecay(v, 0.10);
      expect(v.lockoutTurnsRemaining, 2);
    });
  });

  group('tickLockout', () {
    test('decrements by 1', () {
      final v = TrackedValue(lockoutTurnsRemaining: 3);
      tickLockout(v);
      expect(v.lockoutTurnsRemaining, 2);
    });

    test('floors at 0', () {
      final v = TrackedValue(lockoutTurnsRemaining: 0);
      tickLockout(v);
      expect(v.lockoutTurnsRemaining, 0);
    });

    test('preserves value', () {
      final v = TrackedValue(value: 0.40, lockoutTurnsRemaining: 2);
      tickLockout(v);
      expect(v.value, 0.40);
    });
  });

  group('setLockout', () {
    test('sets countdown', () {
      final v = TrackedValue();
      setLockout(v, lockoutDurationTurns);
      expect(v.lockoutTurnsRemaining, lockoutDurationTurns);
    });
  });

  group('EmotionEnum.opposite', () {
    test('Plutchik pairs', () {
      expect(EmotionEnum.joy.opposite, EmotionEnum.sadness);
      expect(EmotionEnum.sadness.opposite, EmotionEnum.joy);
      expect(EmotionEnum.anger.opposite, EmotionEnum.fear);
      expect(EmotionEnum.fear.opposite, EmotionEnum.anger);
      expect(EmotionEnum.trust.opposite, EmotionEnum.disgust);
      expect(EmotionEnum.disgust.opposite, EmotionEnum.trust);
      expect(EmotionEnum.surprise.opposite, EmotionEnum.anticipation);
      expect(EmotionEnum.anticipation.opposite, EmotionEnum.surprise);
    });

    test('opposite is involutive', () {
      for (final e in EmotionEnum.values) {
        expect(e.opposite.opposite, e);
      }
    });
  });

  group('end-to-end: anger spikes, fear locks out', () {
    test('large anger delta locks fear from rising for 3 turns', () {
      final anger = TrackedValue();
      final fear = TrackedValue();

      // Turn 1: anger jumps. Caller sets fear lockout because outcome
      // flagged shouldLockOpposite.
      final spike = applyDelta(anger, 0.60);
      expect(spike.shouldLockOpposite, isTrue);
      setLockout(fear, lockoutDurationTurns);
      expect(fear.lockoutTurnsRemaining, 3);

      // Turn 2: fear's upward delta blocked.
      tickLockout(fear);
      final blocked = applyDelta(fear, 0.30);
      expect(blocked.vetoedByLockout, isTrue);
      expect(fear.value, 0.0);

      // Turn 3: still blocked.
      tickLockout(fear);
      final blocked2 = applyDelta(fear, 0.30);
      expect(blocked2.vetoedByLockout, isTrue);

      // Turn 4: lockout counted down to 0, fear can rise again.
      tickLockout(fear);
      expect(fear.lockoutTurnsRemaining, 0);
      final allowed = applyDelta(fear, 0.30);
      expect(allowed.vetoedByLockout, isFalse);
      expect(fear.value, closeTo(0.30, 1e-9));
    });
  });
}
