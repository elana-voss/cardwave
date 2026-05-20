/// The 27 GoEmotions categories plus [neutral].
///
/// [neutral] is the fallback returned when no category clears the
/// confidence threshold. It carries no description on purpose — it is the
/// absence of a matched category, not a category with a meaning to embed.
enum EmotionLabelEnum {
  admiration,
  amusement,
  anger,
  annoyance,
  approval,
  caring,
  confusion,
  curiosity,
  desire,
  disappointment,
  disapproval,
  disgust,
  embarrassment,
  excitement,
  fear,
  gratitude,
  grief,
  joy,
  love,
  nervousness,
  optimism,
  pride,
  realization,
  relief,
  remorse,
  sadness,
  surprise,
  neutral,
}
