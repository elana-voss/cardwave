// Top-level barrel — public API for the cardwave_emotion package.
// Files under src/ are private to this package (enforced by import_lint).
// Cross-package consumers MUST import this barrel, not src/ paths.

export 'src/engine/emotion_classifier.dart';
export 'src/models/emotion_descriptions.dart';
export 'src/models/emotion_label_enum.dart';
export 'src/models/emotion_result.dart';
