import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maps known strings to canned unit vectors so the classifier's
/// cosine/threshold logic is exercised without the native model. Each
/// described emotion gets its own basis direction; a test input shares the
/// direction of the emotion it should land on, and the "flat" input gets an
/// unused direction so its best cosine is 0 (below threshold → neutral).
///
/// Both overrides assert the embed task is `passage`, pinning the
/// symmetric-similarity contract: descriptions and input embed the same way.
class _FakeEmbedder extends Embedder {
  _FakeEmbedder(this._vectors);

  final Map<String, Float32List> _vectors;
  int embedCalls = 0;

  @override
  Future<List<Float32List>> embed(
    List<String> texts, {
    required EmbedTaskEnum task,
  }) async {
    expect(task, EmbedTaskEnum.passage, reason: 'descriptions embed as passages');
    embedCalls++;
    return texts.map(_vectorFor).toList();
  }

  @override
  Future<Float32List> embedOne(String text, {required EmbedTaskEnum task}) async {
    expect(task, EmbedTaskEnum.passage, reason: 'input embeds as a passage');
    return _vectorFor(text);
  }

  Float32List _vectorFor(String text) {
    final vector = _vectors[text];
    expect(vector, isNotNull, reason: 'fake has no vector for "$text"');
    return vector!;
  }
}

Float32List _basis(int index) => Float32List(embeddingsDim)..[index] = 1.0;

int _indexOfLabel(EmotionLabelEnum label) {
  var index = 0;
  for (final entry in emotionDescriptions) {
    if (entry.label == label) return index;
    index++;
  }
  return -1;
}

void main() {
  // VectFox triplets: happy/excited → joy, angry → anger, a flat fact → none.
  const happyText = 'I am so happy and excited!';
  const angerText = 'This makes me really angry and frustrated.';
  const flatText = 'The meeting is scheduled for 3 pm on Tuesday.';

  late Map<String, Float32List> vectors;

  setUp(() {
    vectors = {};
    var index = 0;
    for (final entry in emotionDescriptions) {
      vectors[entry.description] = _basis(index);
      index++;
    }
    vectors[happyText] = _basis(_indexOfLabel(EmotionLabelEnum.joy));
    vectors[angerText] = _basis(_indexOfLabel(EmotionLabelEnum.anger));
    // A direction no description uses → zero cosine with all → below threshold.
    vectors[flatText] = _basis(embeddingsDim - 1);
  });

  test('a happy, excited line lands in the joy cluster', () async {
    final classifier = EmotionClassifier(_FakeEmbedder(vectors));
    final result = await classifier.classify(happyText);
    expect(result.label, EmotionLabelEnum.joy);
    expect(result.score, greaterThanOrEqualTo(0.5));
  });

  test('an angry line lands in anger', () async {
    final classifier = EmotionClassifier(_FakeEmbedder(vectors));
    expect((await classifier.classify(angerText)).label, EmotionLabelEnum.anger);
  });

  test('a flat factual line falls below threshold and reads neutral', () async {
    final classifier = EmotionClassifier(_FakeEmbedder(vectors));
    expect((await classifier.classify(flatText)).label, EmotionLabelEnum.neutral);
  });

  test('classifyPair labels the user and the character separately', () async {
    final classifier = EmotionClassifier(_FakeEmbedder(vectors));
    final pair = await classifier.classifyPair(happyText, angerText);
    expect(pair.user.label, EmotionLabelEnum.joy);
    expect(pair.character.label, EmotionLabelEnum.anger);
  });

  test('descriptions are embedded once, then reused', () async {
    final fake = _FakeEmbedder(vectors);
    final classifier = EmotionClassifier(fake);
    await classifier.classify(happyText);
    await classifier.classify(angerText);
    await classifier.classifyPair(happyText, flatText);
    expect(fake.embedCalls, 1, reason: 'the 27 descriptions embed in one batch, once');
  });
}
