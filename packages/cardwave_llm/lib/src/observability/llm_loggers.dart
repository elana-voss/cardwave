import 'package:logging/logging.dart';

/// Per-subdomain Loggers. Call sites emit a typed `LlmLogEvent` as the message.
final Logger ttsLogger = Logger('cardwave.llm.tts');
final Logger imageLogger = Logger('cardwave.llm.image');
final Logger videoLogger = Logger('cardwave.llm.video');
final Logger toolsLogger = Logger('cardwave.llm.tools');
final Logger modelsLogger = Logger('cardwave.llm.models');
final Logger runnerLogger = Logger('cardwave.llm.runner');
final Logger providersLogger = Logger('cardwave.llm.providers');
