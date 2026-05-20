import 'package:cardwave_emotion/src/models/emotion_label_enum.dart';

/// The classifier's verdict for one text: the chosen [label] and the cosine
/// [score] that selected it. For a [EmotionLabelEnum.neutral] result, [score]
/// is the best below-threshold cosine.
class EmotionResult {
  const EmotionResult({required this.label, required this.score});

  final EmotionLabelEnum label;
  final double score;
}
