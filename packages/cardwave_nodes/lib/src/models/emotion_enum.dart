/// Plutchik's eight basic emotions. Each character tracks all eight as
/// numeric values in `character.<id>.emotion.<name>`.
enum EmotionEnum {
  joy,
  sadness,
  anger,
  fear,
  trust,
  disgust,
  surprise,
  anticipation;

  /// Plutchik pair. Used by lockout: a large shift to `this` blocks
  /// upward movement of `opposite` for [lockoutDurationTurns] turns.
  EmotionEnum get opposite => switch (this) {
        EmotionEnum.joy => EmotionEnum.sadness,
        EmotionEnum.sadness => EmotionEnum.joy,
        EmotionEnum.anger => EmotionEnum.fear,
        EmotionEnum.fear => EmotionEnum.anger,
        EmotionEnum.trust => EmotionEnum.disgust,
        EmotionEnum.disgust => EmotionEnum.trust,
        EmotionEnum.surprise => EmotionEnum.anticipation,
        EmotionEnum.anticipation => EmotionEnum.surprise,
      };
}
