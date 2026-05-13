enum GroupActivationStrategyEnum {
  /// Scan the tail of the chat history for character names; fall through
  /// to weighted-random when nothing matches (e.g. during auto-chat).
  natural,

  /// Round-robin in the order characters were added.
  list,

  /// Talkativeness-weighted random, excluding the last speaker.
  random,
}
