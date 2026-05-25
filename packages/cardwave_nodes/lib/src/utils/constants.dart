import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';

/// Per-turn additive decay (toward 0) for each emotion. Locked during
/// the NODES decisions walkthrough.
const Map<EmotionEnum, double> emotionDecayRates = {
  EmotionEnum.joy: 0.08,
  EmotionEnum.sadness: 0.05,
  EmotionEnum.anger: 0.10,
  EmotionEnum.fear: 0.10,
  EmotionEnum.trust: 0.03,
  EmotionEnum.disgust: 0.08,
  EmotionEnum.surprise: 0.30,
  EmotionEnum.anticipation: 0.05,
};

/// Per-turn additive decay (toward 0) for each physical state field.
/// Initial defaults — tune during integration.
const Map<PhysicalEnum, double> physicalDecayRates = {
  PhysicalEnum.tiredness: 0.05,
  PhysicalEnum.hunger: 0.04,
  PhysicalEnum.intoxication: 0.10,
  PhysicalEnum.arousal: 0.20,
  PhysicalEnum.pain: 0.08,
  PhysicalEnum.discomfort: 0.15,
};

/// Per-turn additive decay (toward 0) for each relationship field. Very
/// slow on purpose — relationships shift over many turns, not few.
/// `familiarity` defaults to 0 (knowing someone does not fade with time).
const Map<RelationshipEnum, double> relationshipDecayRates = {
  RelationshipEnum.trust: 0.005,
  RelationshipEnum.familiarity: 0.0,
  RelationshipEnum.attraction: 0.005,
  RelationshipEnum.respect: 0.003,
  RelationshipEnum.resentment: 0.005,
};

/// Resistance dampens deltas when the current value is high.
/// Formula: `appliedDelta = delta * (1 - currentValue * resistanceFactor)`.
/// At currentValue=1.0, deltas are reduced to 20% (when factor=0.8).
const double resistanceFactor = 0.8;

/// A shift of magnitude greater than [lockoutThreshold] in one turn
/// triggers a lockout on the opposite emotion (Plutchik pair), blocking
/// the opposite's upward movement for [lockoutDurationTurns] turns.
const double lockoutThreshold = 0.4;

/// Number of turns a lockout lasts. Decremented at the start of each turn.
const int lockoutDurationTurns = 3;

/// Pressure adds at most this much to a node's effective `triggerProb`
/// during quiet stretches. Resets when any node in the pool fires.
const double pressureCap = 0.3;

/// Amount added to a pool's pressure on every turn in which no node in
/// that pool fired. Capped at [pressureCap].
const double pressureIncrementPerTurn = 0.1;

/// Injection budget as fraction of the model's `max_context`. Fixed.
const double injectionBudgetFraction = 0.10;
