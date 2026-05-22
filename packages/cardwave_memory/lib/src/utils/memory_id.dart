import 'package:uuid/uuid.dart';

// Minted locally instead of via the app's generateId: import_lint forbids a
// package importing app code, so these use package:uuid directly.

String newEventId() => 'event-${const Uuid().v4()}';

String newFactId() => 'fact-${const Uuid().v4()}';

String newThreadId() => 'thread-${const Uuid().v4()}';
