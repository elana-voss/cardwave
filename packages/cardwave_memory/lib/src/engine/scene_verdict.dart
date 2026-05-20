/// The scene-boundary verdict the extraction call returns for a window.
sealed class SceneVerdict {
  const SceneVerdict();
}

/// The scene runs past this window — its events stay provisional.
class SceneContinues extends SceneVerdict {
  const SceneContinues();
}

/// The scene ends at [messageId] — mapped from the numbered cut the model
/// returned, never a raw id. [summary] is the one-line scene description used
/// later for chapter-level grouping.
class SceneEndsAt extends SceneVerdict {
  const SceneEndsAt({required this.messageId, required this.summary});

  final String messageId;
  final String summary;
}
