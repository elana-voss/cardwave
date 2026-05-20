import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/src/models/emotion_descriptions.dart';
import 'package:cardwave_emotion/src/models/emotion_label_enum.dart';
import 'package:cardwave_emotion/src/models/emotion_result.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// One emotion description's label paired with its embedded vector.
typedef DescribedEmotion = ({EmotionLabelEnum label, Float32List vector});

/// Emotion classifier by embedding similarity. Embeds each emotion
/// description once (lazily) and, per input, returns the description with the
/// highest cosine — or [EmotionLabelEnum.neutral] when none clears the
/// threshold. Reuses the on-device [Embedder]; no second model or runtime.
class EmotionClassifier {
  EmotionClassifier(this._embedder);

  final Embedder _embedder;

  /// Symmetric setup: both the descriptions and the input embed as passages
  /// (no query prefix), so cosine compares like with like.
  static const EmbedTaskEnum _task = EmbedTaskEnum.passage;

  /// Best-cosine floor for a confident label; below it the text reads as
  /// [EmotionLabelEnum.neutral]. Starting value — the passage-to-passage
  /// cosine between a short utterance and an emotion description has not been
  /// measured against real chats yet, so calibrate this during integration.
  static const double _confidenceThreshold = 0.5;

  Future<List<DescribedEmotion>>? _describedFuture;

  /// Embeds every description once; the future is cached so concurrent callers
  /// share a single initialization.
  Future<List<DescribedEmotion>> _described() =>
      _describedFuture ??= _embedDescriptions();

  Future<List<DescribedEmotion>> _embedDescriptions() async {
    final vectors = await _embedder.embed(
      [for (final entry in emotionDescriptions) entry.description],
      task: _task,
    );
    // Zip the in-order vectors back onto their labels without indexing.
    final described = <DescribedEmotion>[];
    final labels = emotionDescriptions.iterator;
    for (final vector in vectors) {
      labels.moveNext();
      described.add((label: labels.current.label, vector: vector));
    }
    return described;
  }

  /// Classifies [text] into the closest emotion, or [EmotionLabelEnum.neutral]
  /// when the best cosine is below [_confidenceThreshold].
  Future<EmotionResult> classify(String text) async {
    final described = await _described();
    final input = await _embedder.embedOne(text, task: _task);

    var bestLabel = EmotionLabelEnum.neutral;
    var bestScore = double.negativeInfinity;
    for (final entry in described) {
      final score = cosineNormalized(input, entry.vector);
      if (score > bestScore) {
        bestScore = score;
        bestLabel = entry.label;
      }
    }

    final label = bestScore >= _confidenceThreshold
        ? bestLabel
        : EmotionLabelEnum.neutral;
    return EmotionResult(label: label, score: bestScore);
  }

  /// Classifies a user message and a character message. Embeds sequentially —
  /// the native engine must not run two inferences at once.
  Future<({EmotionResult user, EmotionResult character})> classifyPair(
    String userText,
    String characterText,
  ) async {
    final user = await classify(userText);
    final character = await classify(characterText);
    return (user: user, character: character);
  }
}
