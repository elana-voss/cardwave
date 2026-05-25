import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/director/director_output_schema.dart';
import 'package:cardwave_nodes/src/director/director_output_validator.dart';
import 'package:cardwave_nodes/src/director/director_prompt_builder.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger(packageLoggerName);

/// Orchestrates one director call per turn: build prompt, ask the LLM
/// for a structured JSON response, parse it into [DirectorOutput],
/// validate it, retry on failure, and fall back to an empty
/// [DirectorOutput] (no-op turn) when the model keeps producing
/// rejected output.
///
/// [runner] is injected so consumers (and tests) supply their own
/// [LlmRunner]. The package never reads settings or resolves presets.
class DirectorRunner {
  const DirectorRunner({
    required this.runner,
    this.maxRetries = 2,
  });

  final LlmRunner runner;

  /// Number of additional attempts after the first call. Total calls
  /// per turn: `1 + maxRetries`.
  final int maxRetries;

  Future<DirectorOutput> run({
    required SessionState state,
    required String actorLastOutput,
    required String userInput,
  }) async {
    final prompt = buildDirectorPrompt(
      state: state,
      actorLastOutput: actorLastOutput,
      userInput: userInput,
    );

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final raw = await runner.completeStructured(
          prompt,
          directorOutputSchema,
        );
        final output = DirectorOutput.fromJson(raw);
        final errors = validateDirectorOutput(output);
        if (errors.isEmpty) return output;
        _logger.warning(
          'Director output failed validation on attempt ${attempt + 1}: '
          '${errors.length} error(s); first: ${errors.first}',
        );
      } on Exception catch (error, stackTrace) {
        _logger.warning(
          'Director call failed on attempt ${attempt + 1} via '
          '"${runner.modelName}"',
          error,
          stackTrace,
        );
      }
    }
    _logger.warning(
      'Director call exhausted retries; falling back to no-op for this turn.',
    );
    return DirectorOutput();
  }
}
