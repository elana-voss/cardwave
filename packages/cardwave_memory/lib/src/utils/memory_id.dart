import 'package:uuid/uuid.dart';

// Minted locally instead of via the app's generateId: import_lint forbids a
// package importing app code, so these use package:uuid directly.

String newEventId() => 'event-${const Uuid().v4()}';

String newSceneId() => 'scene-${const Uuid().v4()}';

String newChapterId() => 'chapter-${const Uuid().v4()}';
