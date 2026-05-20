import 'package:logging/logging.dart';

/// Package-wide logger. The extraction path logs failures here and leaves the
/// work provisional rather than crashing the chat turn.
final Logger memoryLogger = Logger('cardwave_memory');
