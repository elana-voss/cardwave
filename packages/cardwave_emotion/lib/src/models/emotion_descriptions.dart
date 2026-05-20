import 'package:cardwave_emotion/src/models/emotion_label_enum.dart';

/// One short, distinct sentence per emotion the classifier can match, paired
/// with its label.
///
/// [EmotionLabelEnum.neutral] is intentionally absent: it is the
/// below-threshold fallback, not a category to embed. Keep each line concrete
/// and distinct — close pairs (admiration vs approval vs gratitude) blur under
/// embedding cosine, so the wording carries the disambiguation.
const List<({EmotionLabelEnum label, String description})> emotionDescriptions =
    [
  (label: EmotionLabelEnum.admiration, description: 'respect and warm approval for someone or something impressive'),
  (label: EmotionLabelEnum.amusement, description: 'finding something funny or entertaining'),
  (label: EmotionLabelEnum.anger, description: 'a strong feeling of displeasure, hostility, or rage'),
  (label: EmotionLabelEnum.annoyance, description: 'mild irritation or being bothered by something'),
  (label: EmotionLabelEnum.approval, description: 'a favorable opinion of or agreement with something'),
  (label: EmotionLabelEnum.caring, description: 'concern, kindness, and tenderness toward someone'),
  (label: EmotionLabelEnum.confusion, description: 'being unable to understand or feeling uncertain'),
  (label: EmotionLabelEnum.curiosity, description: 'an eager desire to know or learn something'),
  (label: EmotionLabelEnum.desire, description: 'a strong wish or longing for something or someone'),
  (label: EmotionLabelEnum.disappointment, description: 'sadness from hopes or expectations going unmet'),
  (label: EmotionLabelEnum.disapproval, description: 'an unfavorable opinion of or objection to something'),
  (label: EmotionLabelEnum.disgust, description: 'strong revulsion or distaste'),
  (label: EmotionLabelEnum.embarrassment, description: 'feeling self-conscious, awkward, or ashamed'),
  (label: EmotionLabelEnum.excitement, description: 'feeling eager, thrilled, and full of energy'),
  (label: EmotionLabelEnum.fear, description: 'feeling afraid, anxious, or threatened by danger'),
  (label: EmotionLabelEnum.gratitude, description: 'feeling thankful and appreciative'),
  (label: EmotionLabelEnum.grief, description: 'deep sorrow, especially over a loss'),
  (label: EmotionLabelEnum.joy, description: 'great happiness, delight, and cheer'),
  (label: EmotionLabelEnum.love, description: 'deep affection and attachment toward someone'),
  (label: EmotionLabelEnum.nervousness, description: 'feeling anxious, worried, or on edge'),
  (label: EmotionLabelEnum.optimism, description: 'hopefulness and confidence about the future'),
  (label: EmotionLabelEnum.pride, description: "satisfaction in one's own achievements or qualities"),
  (label: EmotionLabelEnum.realization, description: 'suddenly understanding or becoming aware of something'),
  (label: EmotionLabelEnum.relief, description: 'reassurance and ease after distress has passed'),
  (label: EmotionLabelEnum.remorse, description: 'deep regret or guilt over a wrong'),
  (label: EmotionLabelEnum.sadness, description: 'feeling unhappy, sorrowful, or downhearted'),
  (label: EmotionLabelEnum.surprise, description: 'mild astonishment at something unexpected'),
];
